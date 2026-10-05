<#
.SYNOPSIS
    Club & Grub: test, export and smoke-check the Windows release build (one self-contained .exe).

.DESCRIPTION
    1. checks the Godot binary (4.7.2) and the Windows export templates,
    2. imports the project and fails on any import error or warning,
    3. runs the whole headless test suite (tests/run_tests.gd) and fails unless it passes,
    4. exports the "Windows Desktop" preset of export_presets.cfg in release mode to build\windows\ClubAndGrub.exe
       (game data embedded, no .pck or DLL next to it) and fails on any export error,
    5. starts the exported exe with the release smoke switch (-- --smoke=<seconds>) and fails unless it exits with
       code 0 and its log is clean. The smoke run gets its own APPDATA under build\windows\smoke, so it never reads
       or writes the user data of a real installation. It also passes a development switch (--autoplay) and
       checks that the release build ignores it.
    6. puts the licence texts next to the exe (build\windows\licenses\: CREDITS.md and every file of
       assets\licenses\, the same texts the game shows in Credits > Licences) and packs the release zip
       build\ClubAndGrub-<version>-windows.zip (the exe plus that folder).

    Every failure stops the script with a message and exit code 1. Godot runs share the lock directory
    build\.godot_lock with .tools/gd.sh, so the script can run while other tools use the project.

.PARAMETER Godot
    Godot 4.7.2 console binary. Default: $env:GODOT, else .tools\godot\Godot_v4.7.2-stable_win64_console.exe,
    else "godot" on the PATH.

.PARAMETER SmokeSeconds
    How long the exported game runs in the smoke check (default 4).

.PARAMETER HeadlessSmoke
    Run the smoke check without a window (build machines without a GPU). Default: windowed, which also proves
    that the renderer starts.

.PARAMETER SkipTests
    Skip step 3. For quick packaging experiments only; never for a build that leaves the machine.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
#>
[CmdletBinding()]
param(
    [string]$Godot = "",
    [ValidateRange(1, 120)][int]$SmokeSeconds = 4,
    [switch]$HeadlessSmoke,
    [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GodotVersion = "4.7.2"
$PresetName = "Windows Desktop"
$ExeName = "ClubAndGrub.exe"
$RunTimeoutSeconds = 600
$LockStaleMinutes = 12

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildDir = Join-Path $Root "build"
$OutDir = Join-Path $BuildDir "windows"
$LogDir = Join-Path $OutDir "logs"
$SmokeDir = Join-Path $OutDir "smoke"
$ExePath = Join-Path $OutDir $ExeName
$LicenseDir = Join-Path $OutDir "licenses"
$LockDir = Join-Path $BuildDir ".godot_lock"

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Stop-Build([string]$Text) {
    Write-Host ""
    Write-Host "BUILD FAILED: $Text" -ForegroundColor Red
    exit 1
}

# Quote one command-line argument the way the Windows C runtime parses it.
function ConvertTo-Argument([string]$Value) {
    if ($Value -notmatch '[\s"]') {
        return $Value
    }
    return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

# Run a program with a time limit; stdout and stderr go to "<LogBase>.out.txt" / ".err.txt".
# Returns @{ ExitCode; Output } where Output holds both streams.
function Invoke-Program([string]$Program, [string[]]$Arguments, [string]$LogBase, [int]$TimeoutSeconds) {
    $outFile = "$LogBase.out.txt"
    $errFile = "$LogBase.err.txt"
    $argLine = ($Arguments | ForEach-Object { ConvertTo-Argument $_ }) -join " "
    Write-Host "    $([IO.Path]::GetFileName($Program)) $argLine" -ForegroundColor DarkGray
    $proc = Start-Process -FilePath $Program -ArgumentList $argLine -WorkingDirectory $Root -NoNewWindow -PassThru `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    $null = $proc.Handle  # keeps the exit code readable after the process ended
    if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
        & taskkill.exe /T /F /PID $proc.Id 2>&1 | Out-Null
        Stop-Build "$([IO.Path]::GetFileName($Program)) did not finish within $TimeoutSeconds s (killed)"
    }
    $proc.WaitForExit()
    $text = ""
    foreach ($file in @($outFile, $errFile)) {
        if (Test-Path $file) {
            $text += [IO.File]::ReadAllText($file)
        }
    }
    return @{ ExitCode = $proc.ExitCode; Output = $text }
}

# Lines of Godot output that report a problem.
function Get-ProblemLines([string]$Text, [switch]$IncludeWarnings) {
    $pattern = if ($IncludeWarnings) { '(^|\s)(ERROR|SCRIPT ERROR|WARNING|USER ERROR|USER WARNING):' } `
        else { '(^|\s)(ERROR|SCRIPT ERROR|USER ERROR):' }
    return @($Text -split "`r?`n" | Where-Object { $_ -match $pattern })
}

function Enter-GodotLock {
    $waited = 0
    while ($true) {
        try {
            New-Item -ItemType Directory -Path $LockDir -ErrorAction Stop | Out-Null
            return
        } catch {
            $item = Get-Item -LiteralPath $LockDir -ErrorAction SilentlyContinue
            if ($null -ne $item -and $item.LastWriteTime -lt (Get-Date).AddMinutes(-$LockStaleMinutes)) {
                Write-Host "    removing stale Godot lock" -ForegroundColor Yellow
                Remove-Item -LiteralPath $LockDir -Recurse -Force -ErrorAction SilentlyContinue
                continue
            }
            if ($waited % 30 -eq 0) {
                Write-Host "    waiting for another Godot run to finish ..." -ForegroundColor DarkGray
            }
            Start-Sleep -Seconds 1
            $waited += 1
        }
    }
}

function Exit-GodotLock {
    Remove-Item -LiteralPath $LockDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Run Godot while holding the shared lock.
function Invoke-Godot([string[]]$Arguments, [string]$LogName) {
    Enter-GodotLock
    try {
        return Invoke-Program $script:GodotExe $Arguments (Join-Path $LogDir $LogName) $RunTimeoutSeconds
    } finally {
        Exit-GodotLock
    }
}

# --- 1. tools ---------------------------------------------------------------------------------------------------------
Write-Step "Checking Godot $GodotVersion and the export templates"
$candidates = @($Godot, $env:GODOT, (Join-Path $Root ".tools\godot\Godot_v$GodotVersion-stable_win64_console.exe"))
$script:GodotExe = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if (-not $script:GodotExe) {
    $onPath = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -eq $onPath) {
        Stop-Build "Godot $GodotVersion not found: pass -Godot <path>, set GODOT, or put godot on the PATH"
    }
    $script:GodotExe = $onPath.Source
}
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$versionRun = Invoke-Program $script:GodotExe @("--version") (Join-Path $LogDir "version") 60
$versionText = $versionRun.Output.Trim()
if (-not $versionText.StartsWith("$GodotVersion.stable")) {
    Stop-Build "$($script:GodotExe) is version '$versionText', this project needs $GodotVersion.stable"
}
Write-Host "    Godot $versionText ($($script:GodotExe))"
$templates = Join-Path $env:APPDATA "Godot\export_templates\$GodotVersion.stable"
$template = Join-Path $templates "windows_release_x86_64.exe"
if (-not (Test-Path -LiteralPath $template)) {
    Stop-Build "export template missing: $template (Editor > Manage Export Templates, or unpack the .tpz there)"
}
Write-Host "    templates: $templates"

# --- 2. import --------------------------------------------------------------------------------------------------------
Write-Step "Importing the project"
$import = Invoke-Godot @("--headless", "--path", $Root, "--import") "import"
$problems = @(Get-ProblemLines $import.Output -IncludeWarnings)
if ($import.ExitCode -ne 0 -or $problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    Stop-Build "the import reported $($problems.Count) problem(s) (exit code $($import.ExitCode)); see $LogDir\import.*.txt"
}
Write-Host "    clean import"

# --- 3. tests ---------------------------------------------------------------------------------------------------------
if ($SkipTests) {
    Write-Step "Skipping the test suite (-SkipTests): do not ship this build"
} else {
    Write-Step "Running the test suite"
    $tests = Invoke-Godot @("--headless", "--path", $Root, "-s", "res://tests/run_tests.gd") "tests"
    $summary = @($tests.Output -split "`r?`n" | Where-Object { $_ -match '^(TESTS|RESULT):' })
    $summary | ForEach-Object { Write-Host "    $_" }
    if ($tests.ExitCode -ne 0 -or -not ($tests.Output -match '(?m)^RESULT: PASS')) {
        $tests.Output -split "`r?`n" | Where-Object { $_ -match '^\s+(FAIL|- )' } | Select-Object -First 40 |
            ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        Stop-Build "the test suite failed (exit code $($tests.ExitCode)); see $LogDir\tests.*.txt"
    }
}

# --- 4. export --------------------------------------------------------------------------------------------------------
Write-Step "Exporting '$PresetName' (release) to $ExePath"
if (Test-Path -LiteralPath $OutDir) {
    Get-ChildItem -LiteralPath $OutDir -File | Remove-Item -Force
}
if (Test-Path -LiteralPath $LicenseDir) {
    Remove-Item -LiteralPath $LicenseDir -Recurse -Force
}
$export = Invoke-Godot @("--headless", "--path", $Root, "--export-release", $PresetName, $ExePath) "export"
# The first export of a checkout converts every scene to binary (.godot\exported\), and the editor process then
# reports the scripts it loaded for that as "leaked at exit" / "still in use at exit" while it shuts down, after the
# pack is written. Later exports reuse the converted scenes and print nothing. These two shutdown lines say nothing
# about the exported game (step 5 checks that), so they alone do not fail the build; every other line still does.
$exitLeakPattern = 'ObjectDB instances were leaked at exit|resources still in use at exit'
$exitLeaks = @(Get-ProblemLines $export.Output -IncludeWarnings | Where-Object { $_ -match $exitLeakPattern })
$exitLeaks | ForEach-Object { Write-Host "    ignored editor shutdown report: $($_.Trim())" -ForegroundColor DarkGray }
$problems = @(Get-ProblemLines $export.Output -IncludeWarnings | Where-Object { $_ -notmatch $exitLeakPattern })
if ($export.ExitCode -ne 0 -or $problems.Count -gt 0 -or -not (Test-Path -LiteralPath $ExePath)) {
    $problems | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    Stop-Build "the export failed (exit code $($export.ExitCode)); see $LogDir\export.*.txt"
}
$extra = @(Get-ChildItem -LiteralPath $OutDir -File | Where-Object { $_.Name -ne $ExeName })
if ($extra.Count -gt 0) {
    Stop-Build "the export wrote more than one file: $($extra.Name -join ', ') (expected a single $ExeName)"
}
$exe = Get-Item -LiteralPath $ExePath
Write-Host ("    {0} ({1:N1} MB), product {2} {3}" -f $exe.Name, ($exe.Length / 1MB), $exe.VersionInfo.ProductName,
    $exe.VersionInfo.ProductVersion)

# --- 5. smoke check of the exported exe -------------------------------------------------------------------------------
Write-Step "Smoke check: starting the exported game for $SmokeSeconds s"
if (Test-Path -LiteralPath $SmokeDir) {
    Remove-Item -LiteralPath $SmokeDir -Recurse -Force
}
$smokeAppData = Join-Path $SmokeDir "appdata"
New-Item -ItemType Directory -Force -Path $smokeAppData | Out-Null
$smokeLog = Join-Path $SmokeDir "smoke.log"
$smokeArgs = @("--log-file", $smokeLog)
if ($HeadlessSmoke) {
    $smokeArgs += "--headless"
}
# A development switch rides along: the release build must ignore it.
$smokeArgs += @("--", "--smoke=$SmokeSeconds", "--autoplay=w1_l1")
$realAppData = $env:APPDATA
try {
    $env:APPDATA = $smokeAppData
    $smoke = Invoke-Program $ExePath $smokeArgs (Join-Path $SmokeDir "console") ($SmokeSeconds + 60)
} finally {
    $env:APPDATA = $realAppData
}
if (-not (Test-Path -LiteralPath $smokeLog)) {
    Stop-Build "the exported game wrote no log (exit code $($smoke.ExitCode))"
}
$logText = [IO.File]::ReadAllText($smokeLog)
$problems = @(Get-ProblemLines $logText -IncludeWarnings)
$logText -split "`r?`n" | Where-Object { $_ -match '^(Smoke|Autoplay):' } | ForEach-Object { Write-Host "    $_" }
if ($smoke.ExitCode -ne 0 -or $problems.Count -gt 0) {
    $problems | Select-Object -First 40 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    Stop-Build "the exported game did not boot cleanly (exit code $($smoke.ExitCode)); see $smokeLog"
}
if ($logText -notmatch 'Smoke: ran [0-9.]+ s, 0 error\(s\), 0 warning\(s\) logged') {
    Stop-Build "the smoke check did not report a clean run; see $smokeLog"
}
if ($logText -notmatch '\(release build\)') {
    Stop-Build "the exported game is not a release build; see $smokeLog"
}
if ($logText -notmatch 'development switches are ignored by release builds') {
    Stop-Build "the release build did not reject the development switch --autoplay; see $smokeLog"
}
# The package holds exactly the shipped levels: every levels\*.lvl except the developer levels test_*.lvl.
$expectedLevels = @(Get-ChildItem -LiteralPath (Join-Path $Root "levels") -Filter "*.lvl" |
    Where-Object { -not $_.BaseName.StartsWith("test_") } | ForEach-Object { $_.BaseName } | Sort-Object)
$levelLine = [regex]::Match($logText, '(?m)^Smoke: levels (.*)$')
if (-not $levelLine.Success) {
    Stop-Build "the smoke check did not list the levels inside the build; see $smokeLog"
}
$packedLevels = @($levelLine.Groups[1].Value.Trim() -split ',' | Where-Object { $_ } | Sort-Object)
$testLevels = @($packedLevels | Where-Object { $_.StartsWith("test_") })
if ($testLevels.Count -gt 0) {
    Stop-Build "developer levels are inside the build: $($testLevels -join ', ')"
}
if (($packedLevels -join ',') -ne ($expectedLevels -join ',')) {
    Stop-Build "the build holds the levels '$($packedLevels -join ',')', expected '$($expectedLevels -join ',')'"
}
$campaignLine = [regex]::Match($logText, '(?m)^Smoke: campaign (.*)$')
Write-Host "    $($packedLevels.Count) levels inside, no developer level; campaign $($campaignLine.Groups[1].Value.Trim())"

# --- 6. licence texts and the release zip -----------------------------------------------------------------------------
Write-Step "Licence texts next to the exe and the release zip"
New-Item -ItemType Directory -Force -Path $LicenseDir | Out-Null
Copy-Item -LiteralPath (Join-Path $Root "CREDITS.md") -Destination $LicenseDir
$licenseSources = @(Get-ChildItem -LiteralPath (Join-Path $Root "assets\licenses") -File |
    Where-Object { $_.Extension -in @(".txt", ".md") })
foreach ($file in $licenseSources) {
    Copy-Item -LiteralPath $file.FullName -Destination $LicenseDir
}
foreach ($required in @("CREDITS.md", "README.md", "godot_engine.txt", "godot_third_party.txt",
        "googlefonts_pressstart2p.txt", "googlefonts_pixelifysans.txt", "cc0_1.0_legal_code.txt")) {
    if (-not (Test-Path -LiteralPath (Join-Path $LicenseDir $required))) {
        Stop-Build "licence text $required is missing from $LicenseDir"
    }
}
$version = [regex]::Match([IO.File]::ReadAllText((Join-Path $Root "project.godot")),
    '(?m)^config/version="([^"]+)"').Groups[1].Value
if (-not $version) {
    Stop-Build "no application/config/version in project.godot"
}
$ZipPath = Join-Path $BuildDir "ClubAndGrub-$version-windows.zip"
if (Test-Path -LiteralPath $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
}
# Packed with System.IO.Compression rather than Compress-Archive: Windows PowerShell 5.1's Compress-Archive writes
# "licenses\x.txt" entry names, which the zip format forbids (other unzip tools then create files with a backslash
# in their name). Every entry name here uses "/".
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$licenseFiles = @(Get-ChildItem -LiteralPath $LicenseDir -File | Sort-Object Name)
$zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $level = [System.IO.Compression.CompressionLevel]::Optimal
    $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $ExePath, $ExeName, $level)
    foreach ($file in $licenseFiles) {
        $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName,
            "licenses/$($file.Name)", $level)
    }
} finally {
    $zip.Dispose()
}
$zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
try {
    $entryNames = @($zip.Entries | ForEach-Object { $_.FullName })
} finally {
    $zip.Dispose()
}
if ($entryNames.Count -ne $licenseFiles.Count + 1 -or $entryNames -notcontains $ExeName -or
        @($entryNames | Where-Object { $_.Contains("\") }).Count -gt 0) {
    Stop-Build "the release zip does not hold exactly $ExeName and licenses/ ($($entryNames.Count) entries)"
}
Write-Host ("    {0} licence file(s) in {1}" -f (@(Get-ChildItem -LiteralPath $LicenseDir -File)).Count, $LicenseDir)
Write-Host ("    {0} ({1:N1} MB)" -f $ZipPath, ((Get-Item -LiteralPath $ZipPath).Length / 1MB))

$hash = (Get-FileHash -LiteralPath $ExePath -Algorithm SHA256).Hash
$zipHash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash
Write-Host ""
Write-Host "BUILD OK: $ExePath" -ForegroundColor Green
Write-Host "    SHA-256 $hash"
Write-Host "    release zip $ZipPath"
Write-Host "    SHA-256 $zipHash"
exit 0

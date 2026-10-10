<#
.SYNOPSIS
    Club & Grub: test, export and smoke-check the Windows release build (one self-contained .exe).

.DESCRIPTION
    1. checks the Godot binary (4.7.2) and the Windows export templates,
    2. imports the project and fails on any import error or warning,
    2b. runs tools\audit_assets.py (Python 3, standard library only) and fails on any asset without a row in
       docs\ASSET_MANIFEST.md, any licence that is not CC0 / OFL, any pack missing from the credits or the licence
       texts (PLAN.md P4.4: the audit is run by the build),
    3. runs the whole headless test suite (tests/run_tests.gd) and fails unless it passes,
    4. exports the "Windows Desktop" preset of export_presets.cfg in release mode to build\windows\ClubAndGrub.exe
       (game data embedded, no .pck or DLL next to it) and fails on any export error, when the exe does not carry
       the version of project.godot, or when the export changed export_presets.cfg (it is put back),
    5. starts the exported exe with the release smoke switch (-- --smoke=<seconds>) and fails unless it exits with
       code 0, its log is clean and it reports the version of project.godot. The script does not take the game's
       word for a clean log: it reads the log's own lines and fails on every WARNING and ERROR line (none is
       tolerated in a boot log), also one the game's counter did not see. The smoke run gets its own APPDATA
       under build\windows\smoke, so it never reads or writes the user data of a real installation. It also passes
       a development switch (--autoplay) and checks that the release build ignores it.
    6. reads the list of files packed inside the exe and lets tests\test_core_release_pack.gd judge it: no
       developer level, test, tool or recorder, no asset outside docs\ASSET_MANIFEST.md, no file the export filters
       do not allow, nothing the filters ship missing (the test gets the exe through CLUBANDGRUB_RELEASE_EXE),
    7. puts the licence texts next to the exe (build\windows\licenses\: CREDITS.md and every file of
       assets\licenses\, the same texts the game shows in Credits > Licences) and packs the release zip
       build\ClubAndGrub-<version>-windows.zip (the exe plus that folder); tools\audit_assets.py --shipped then
       proves that the folder and the zip hold every licence text byte for byte and nothing else.

    Every failure stops the script with a message and exit code 1. Godot runs take turns with .tools/gd.sh through
    the lock directory build\.godot_lock (the import and the export alone, the tests beside other runs), so the
    script can run while other tools use the project.

    NO RUN OF THIS SCRIPT WRITES INTO THE PLAYER'S OWN FOLDER. The game's user:// is %APPDATA%\ClubAndGrub, where an
    installed game keeps its saves and settings, and a Godot run of the project goes there by itself: a test run
    rotates the engine's log into logs\ and writes whatever a test puts into user://, and the editor (import,
    export) makes the folder and objectdb_snapshots\ in it when they are missing. So every Godot run of this script
    gets APPDATA pointed at the build's own folder, build\run_users\build_windows_<PID>\appdata (removed when the
    script ends), as the runs of .tools/gd.sh do. The export finds its templates there: the script copies the
    Windows release template (and version.txt) from the real %APPDATA%\Godot\export_templates into that folder
    first - about 110 MB, read only; the exe exported that way is byte for byte the one exported with the real
    APPDATA (measured for 2.0.0).

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

.PARAMETER OutputRoot
    Folder of the build output (default: build). The exe goes to <OutputRoot>\windows, the zip to
    <OutputRoot>\ClubAndGrub-<version>-windows.zip. Use another folder (for example build\trial) to try the script
    without replacing the release files in build\.

.PARAMETER CheckBootLog
    Build nothing: judge this boot log (the --log-file of a "-- --smoke=<seconds>" run) by the rules of step 5 -
    no WARNING or ERROR line, and the line "Smoke: ran ... 0 error(s), 0 warning(s) logged" - print the lines that
    fail it and exit with 0 (clean) or 1. tools\build_installer.ps1 judges the boot of its installed twin with it.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
#>
[CmdletBinding()]
param(
    [string]$Godot = "",
    [ValidateRange(1, 120)][int]$SmokeSeconds = 4,
    [switch]$HeadlessSmoke,
    [switch]$SkipTests,
    [string]$OutputRoot = "",
    [string]$CheckBootLog = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GodotVersion = "4.7.2"
$PresetName = "Windows Desktop"
$ExeName = "ClubAndGrub.exe"
$RunTimeoutSeconds = 600
# The whole default suite (about 1 750 tests) needs more than the import or the export.
$TestTimeoutSeconds = 1800
$LockStaleMinutes = 12
# An import or export waits for the Godot runs that started in the last minutes (they may still be loading), as
# .tools/gd.sh does.
$ReaderWaitMinutes = 3

# The WARNING and ERROR lines a boot log may hold without failing the build: none. (The export of step 4 has such a
# list, three editor shutdown lines; a line belongs here only with its reason, as there.)
$BootLogTolerated = @()

# Lines of Godot output that report a problem.
function Get-ProblemLines([string]$Text, [switch]$IncludeWarnings) {
    $pattern = if ($IncludeWarnings) { '(^|\s)(ERROR|SCRIPT ERROR|WARNING|USER ERROR|USER WARNING):' } `
        else { '(^|\s)(ERROR|SCRIPT ERROR|USER ERROR):' }
    return @($Text -split "`r?`n" | Where-Object { $_ -match $pattern })
}

# The WARNING and ERROR lines of a boot log that are not on $BootLogTolerated. The game's own count ("Smoke: ran ...
# 0 error(s), 0 warning(s) logged") starts when its autoloads are made and ends with its verdict: what the engine
# logs before the first script runs and while it shuts down is only here, in the lines.
function Get-BootLogProblems([string]$LogText) {
    $lines = @(Get-ProblemLines $LogText -IncludeWarnings)
    foreach ($tolerated in $BootLogTolerated) {
        $lines = @($lines | Where-Object { $_ -notmatch $tolerated })
    }
    return $lines
}

# Why a boot log is not the log of a clean boot ("" when it is): a problem line, or no clean verdict of the game.
function Get-BootLogFailure([string]$LogText) {
    $problems = @(Get-BootLogProblems $LogText)
    if ($problems.Count -gt 0) {
        return "the boot log holds $($problems.Count) WARNING / ERROR line(s)"
    }
    if ($LogText -notmatch 'Smoke: ran [0-9.]+ s, 0 error\(s\), 0 warning\(s\) logged') {
        return "the smoke check did not report a clean run"
    }
    return ""
}

if ($CheckBootLog) {
    if (-not (Test-Path -LiteralPath $CheckBootLog -PathType Leaf)) {
        Write-Host "BOOT LOG FAILED: $CheckBootLog is missing" -ForegroundColor Red
        exit 1
    }
    $checkedText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $CheckBootLog).Path)
    $checkedFailure = Get-BootLogFailure $checkedText
    if ($checkedFailure) {
        @(Get-BootLogProblems $checkedText) | Select-Object -First 40 |
            ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        Write-Host "BOOT LOG FAILED: $checkedFailure; see $CheckBootLog" -ForegroundColor Red
        exit 1
    }
    Write-Host "BOOT LOG OK: $CheckBootLog" -ForegroundColor Green
    exit 0
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildDir = Join-Path $Root "build"
if (-not $OutputRoot) { $OutputRoot = $BuildDir }
if (-not [IO.Path]::IsPathRooted($OutputRoot)) { $OutputRoot = Join-Path $Root $OutputRoot }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path
$OutDir = Join-Path $OutputRoot "windows"
$LogDir = Join-Path $OutDir "logs"
$SmokeDir = Join-Path $OutDir "smoke"
$ExePath = Join-Path $OutDir $ExeName
$LicenseDir = Join-Path $OutDir "licenses"
$LockDir = Join-Path $BuildDir ".godot_lock"
$ReadersDir = Join-Path $BuildDir ".godot_readers"
$PresetsPath = Join-Path $Root "export_presets.cfg"
# The folder of this build's own Godot runs (see the header): the test runs' saves and settings, and in appdata\ the
# APPDATA every Godot run of the script gets instead of the player's.
$RunUserName = "build_windows_$PID"
$RunUserDir = Join-Path $BuildDir "run_users\$RunUserName"
$RunAppData = Join-Path $RunUserDir "appdata"

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Remove-RunUser {
    Remove-Item -LiteralPath $RunUserDir -Recurse -Force -ErrorAction SilentlyContinue
}

function Stop-Build([string]$Text) {
    Remove-RunUser
    Write-Host ""
    Write-Host "BUILD FAILED: $Text" -ForegroundColor Red
    exit 1
}

# An error nobody caught must not leave the build's folder (and the copied export template) behind.
trap {
    if (Test-Path -LiteralPath variable:RunUserDir) { Remove-RunUser }
    break
}

# Quote one command-line argument the way the Windows C runtime parses it.
function ConvertTo-Argument([string]$Value) {
    if ($Value -notmatch '[\s"]') {
        return $Value
    }
    return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

# Run a program with a time limit; stdout and stderr go to "<LogBase>.out.txt" / ".err.txt".
# Returns @{ ExitCode; Output } where Output holds both streams. With $AppData the program is started with APPDATA
# pointed at that folder (made when missing): the engine and the game then keep their user data there.
function Invoke-Program([string]$Program, [string[]]$Arguments, [string]$LogBase, [int]$TimeoutSeconds,
        [string]$AppData = "") {
    $outFile = "$LogBase.out.txt"
    $errFile = "$LogBase.err.txt"
    $argLine = ($Arguments | ForEach-Object { ConvertTo-Argument $_ }) -join " "
    Write-Host "    $([IO.Path]::GetFileName($Program)) $argLine" -ForegroundColor DarkGray
    $realAppData = $env:APPDATA
    try {
        if ($AppData) {
            New-Item -ItemType Directory -Force -Path $AppData | Out-Null
            $env:APPDATA = $AppData
        }
        $proc = Start-Process -FilePath $Program -ArgumentList $argLine -WorkingDirectory $Root -NoNewWindow -PassThru `
            -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    } finally {
        $env:APPDATA = $realAppData
    }
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

# Run Godot alone (an import or an export, which write Godot's caches): holds the lock for the whole run, after the
# runs that started in the last minutes have had time to load.
function Invoke-Godot([string[]]$Arguments, [string]$LogName) {
    Enter-GodotLock
    try {
        while (Test-Path -LiteralPath $ReadersDir) {
            $recent = @(Get-ChildItem -LiteralPath $ReadersDir -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-$ReaderWaitMinutes) })
            if ($recent.Count -eq 0) { break }
            Start-Sleep -Seconds 1
        }
        return Invoke-Program $script:GodotExe $Arguments (Join-Path $LogDir $LogName) $RunTimeoutSeconds $RunAppData
    } finally {
        Exit-GodotLock
    }
}

# Run Godot beside other runs (tests only read the caches): registers as a reader, as ".tools/gd.sh test" does.
function Invoke-GodotShared([string[]]$Arguments, [string]$LogName, [int]$TimeoutSeconds) {
    New-Item -ItemType Directory -Force -Path $ReadersDir | Out-Null
    $marker = Join-Path $ReadersDir "build_windows_$PID"
    Enter-GodotLock
    try {
        Set-Content -LiteralPath $marker -Value "" -Encoding ASCII
    } finally {
        Exit-GodotLock
    }
    try {
        return Invoke-Program $script:GodotExe $Arguments (Join-Path $LogDir $LogName) $TimeoutSeconds $RunAppData
    } finally {
        Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
    }
}

# The test suite with its own user folder (saves and settings of the run; the engine's log and what a test writes
# to user:// go to appdata\ inside it), removed afterwards.
function Invoke-Tests([string[]]$TestArguments, [string]$LogName) {
    try {
        return Invoke-GodotShared (@("--headless", "--path", $Root, "-s", "res://tests/run_tests.gd", "--",
            "--user-dir=res://build/run_users/$RunUserName") + $TestArguments) $LogName $TestTimeoutSeconds
    } finally {
        Remove-RunUser
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
$versionRun = Invoke-Program $script:GodotExe @("--version") (Join-Path $LogDir "version") 60 $RunAppData
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

# --- 2b. asset and licence audit ---------------------------------------------------------------------------------------
Write-Step "Asset and licence audit (tools\audit_assets.py)"
$python = Join-Path $Root ".tools\venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    $onPath = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $onPath) {
        Stop-Build "Python 3 not found (.tools\venv\Scripts\python.exe or python on the PATH): the asset audit cannot run"
    }
    $python = $onPath.Source
}
$audit = Invoke-Program $python @((Join-Path $Root "tools\audit_assets.py")) (Join-Path $LogDir "audit") 300
@($audit.Output -split "`r?`n" | Where-Object { $_ -match '^(GAP |ASSET AUDIT:|    )' }) | Select-Object -First 60 |
    ForEach-Object { Write-Host "    $_" }
if ($audit.ExitCode -ne 0 -or $audit.Output -notmatch '(?m)^ASSET AUDIT: PASS') {
    Stop-Build "the asset and licence audit failed (exit code $($audit.ExitCode)); see $LogDir\audit.*.txt"
}

# --- 3. tests ---------------------------------------------------------------------------------------------------------
if ($SkipTests) {
    Write-Step "Skipping the test suite (-SkipTests): do not ship this build"
} else {
    Write-Step "Running the test suite"
    $tests = Invoke-Tests @() "tests"
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
# The export runs with the build's own APPDATA like every Godot run here (see the header), and the editor looks for
# the export templates under APPDATA: the Windows release template is copied there first (read from the real folder).
$ownTemplates = Join-Path $RunAppData "Godot\export_templates\$GodotVersion.stable"
New-Item -ItemType Directory -Force -Path $ownTemplates | Out-Null
foreach ($name in @("version.txt", "windows_release_x86_64.exe", "windows_release_x86_64_console.exe")) {
    if (Test-Path -LiteralPath (Join-Path $templates $name) -PathType Leaf) {
        Copy-Item -LiteralPath (Join-Path $templates $name) -Destination $ownTemplates
    }
}
$presetsBefore = [IO.File]::ReadAllBytes($PresetsPath)
try {
    $export = Invoke-Godot @("--headless", "--path", $Root, "--export-release", $PresetName, $ExePath) "export"
} finally {
    Remove-RunUser
}
# The editor may write the preset file back (the export path of this run, options in its own order): the file in
# the repository is the truth, so it is put back and the build stops.
$presetsAfter = [IO.File]::ReadAllBytes($PresetsPath)
if ([Convert]::ToBase64String($presetsBefore) -ne [Convert]::ToBase64String($presetsAfter)) {
    [IO.File]::WriteAllBytes($PresetsPath, $presetsBefore)
    Stop-Build "the export rewrote export_presets.cfg (restored); see $LogDir\export.*.txt"
}
# The first export of a checkout converts every scene to binary (.godot\exported\), and the editor process then
# reports the scripts it loaded for that as "leaked at exit" / "still in use at exit" while it shuts down, after the
# pack is written - and, where those scripts still held a texture, the headless renderer adds "<n> RID allocations of
# type '...DummyTexture...' were leaked at exit" (seen on the first export of a clean copy of the repository at the
# 2.0.0 release check: the build stopped there and passed when run again). Later exports reuse the converted scenes
# and print nothing. These three shutdown lines say nothing about the exported game (step 5 checks that), so they
# alone do not fail the build; every other line still does.
$exitLeakPattern = 'ObjectDB instances were leaked at exit|resources still in use at exit|RID allocations of type .* were leaked at exit'
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
$version = [regex]::Match([IO.File]::ReadAllText((Join-Path $Root "project.godot")),
    '(?m)^config/version="([^"]+)"').Groups[1].Value
if (-not $version) {
    Stop-Build "no application/config/version in project.godot"
}
$exe = Get-Item -LiteralPath $ExePath
Write-Host ("    {0} ({1:N1} MB), product {2} {3}" -f $exe.Name, ($exe.Length / 1MB), $exe.VersionInfo.ProductName,
    $exe.VersionInfo.ProductVersion)
if (-not ([string]$exe.VersionInfo.ProductVersion).StartsWith($version) -or
        -not ([string]$exe.VersionInfo.FileVersion).StartsWith($version)) {
    Stop-Build "the exe reports version '$($exe.VersionInfo.ProductVersion)' / '$($exe.VersionInfo.FileVersion)', project.godot says $version"
}

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
} else {
    # A real window proves the renderer starts; muted and off-screen so it never disturbs the desktop's user.
    $smokeArgs += @("--audio-driver", "Dummy", "--position", "30000,30000")
}
# A development switch rides along: the release build must ignore it.
$smokeArgs += @("--", "--smoke=$SmokeSeconds", "--autoplay=w1_l1")
$smoke = Invoke-Program $ExePath $smokeArgs (Join-Path $SmokeDir "console") ($SmokeSeconds + 60) $smokeAppData
if (-not (Test-Path -LiteralPath $smokeLog)) {
    Stop-Build "the exported game wrote no log (exit code $($smoke.ExitCode))"
}
$logText = [IO.File]::ReadAllText($smokeLog)
$logText -split "`r?`n" | Where-Object { $_ -match '^(Smoke|Autoplay):' } | ForEach-Object { Write-Host "    $_" }
# Neither the exit code nor the game's own count is taken on trust: the log's lines are read (Get-BootLogFailure).
$bootFailure = Get-BootLogFailure $logText
if ($smoke.ExitCode -ne 0 -or $bootFailure) {
    @(Get-BootLogProblems $logText) | Select-Object -First 40 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    if (-not $bootFailure) { $bootFailure = "no WARNING or ERROR line in its log" }
    Stop-Build "the exported game did not boot cleanly (exit code $($smoke.ExitCode); $bootFailure); see $smokeLog"
}
if ($logText -notmatch '\(release build\)') {
    Stop-Build "the exported game is not a release build; see $smokeLog"
}
if ($logText -notmatch ('(?m)^Smoke: .* ' + [regex]::Escape($version) + ' \(release build\)')) {
    Stop-Build "the exported game does not report version $version; see $smokeLog"
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

# --- 6. what is inside the exe ----------------------------------------------------------------------------------------
Write-Step "Checking the files packed inside the exe"
$realExeVariable = $env:CLUBANDGRUB_RELEASE_EXE
try {
    $env:CLUBANDGRUB_RELEASE_EXE = $ExePath
    $packCheck = Invoke-Tests @("--filter=core_release") "pack_check"
} finally {
    $env:CLUBANDGRUB_RELEASE_EXE = $realExeVariable
}
$packCheck.Output -split "`r?`n" | Where-Object { $_ -match '^\s+pack: |^(TESTS|RESULT):' } |
    ForEach-Object { Write-Host "    $($_.Trim())" }
if ($packCheck.ExitCode -ne 0 -or -not ($packCheck.Output -match '(?m)^RESULT: PASS') -or
        -not ($packCheck.Output -match '(?m)^\s+pack: .* file\(s\) inside')) {
    $packCheck.Output -split "`r?`n" | Where-Object { $_ -match '^\s+(FAIL|- )' } | Select-Object -First 40 |
        ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    Stop-Build "the exe holds files a release must not hold, or its file list could not be read; see $LogDir\pack_check.*.txt"
}

# --- 7. licence texts and the release zip -----------------------------------------------------------------------------
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
$ZipPath = Join-Path $OutputRoot "ClubAndGrub-$version-windows.zip"
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
# The licence texts as shipped, against the project's own (the audit's second check): the folder next to the exe and
# the licenses/ folder inside the zip hold CREDITS.md and every file of assets\licenses\ byte for byte, nothing else.
foreach ($shipped in @($LicenseDir, $ZipPath)) {
    $shippedCheck = Invoke-Program $python @((Join-Path $Root "tools\audit_assets.py"), "--shipped", $shipped) `
        (Join-Path $LogDir "audit_shipped") 300
    @($shippedCheck.Output -split "`r?`n" | Where-Object { $_ -match '^(GAP |LICENCE TEXTS SHIPPED:)' }) |
        Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
    if ($shippedCheck.ExitCode -ne 0 -or $shippedCheck.Output -notmatch '(?m)^LICENCE TEXTS SHIPPED: PASS') {
        Stop-Build "the licence texts in $shipped are not the project's (exit code $($shippedCheck.ExitCode)); see $LogDir\audit_shipped.*.txt"
    }
}
Write-Host ("    {0} licence file(s) in {1}" -f (@(Get-ChildItem -LiteralPath $LicenseDir -File)).Count, $LicenseDir)
Write-Host ("    {0} ({1:N1} MB)" -f $ZipPath, ((Get-Item -LiteralPath $ZipPath).Length / 1MB))

$hash = (Get-FileHash -LiteralPath $ExePath -Algorithm SHA256).Hash
$zipHash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash
Remove-RunUser
Write-Host ""
Write-Host "BUILD OK: $ExePath" -ForegroundColor Green
Write-Host "    SHA-256 $hash"
Write-Host "    release zip $ZipPath"
Write-Host "    SHA-256 $zipHash"
exit 0

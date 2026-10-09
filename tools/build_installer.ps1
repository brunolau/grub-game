<#
.SYNOPSIS
    Club & Grub: build the Windows installer (build\ClubAndGrub-<version>-setup.exe) with Inno Setup 7.

.DESCRIPTION
    1. runs tools\build_windows.ps1 (tests, release export, smoke check, licence texts) unless -SkipBuild,
    2. reads the version from project.godot (application/config/version),
    3. compiles installer\club_and_grub.iss with Inno Setup's ISCC and fails on any compiler error. This is the
       release installer; this script never runs it.
    4. with -TestInstall: compiles the same script a second time in its TEST MODE - a throwaway AppId (a new GUID
       per run), its own name, Start menu group and uninstall entry, no desktop shortcut, no code that closes a
       running game or asks about saved games - installs THAT one silently for the current user into
       <output root>\installer_test\app, checks the files, the uninstall entry and the Start menu shortcut, runs the
       installed game's smoke check with its own APPDATA, uninstalls it silently and checks that nothing is left.

    SAFE ON A MACHINE WHERE THE GAME IS INSTALLED. The test installer is another application for Windows, so step 4
    cannot upgrade, change or remove a real installation of Club & Grub, its Start menu entry, its desktop shortcut
    or its saves in %APPDATA%\ClubAndGrub. The script proves it on every run: it records the real installation
    (uninstall entries of the real AppId for this user and for all users, the installed files, the Start menu
    folders, the desktop shortcuts, the save and settings files with their hashes) before the test and compares
    after it; any difference fails the run. It uninstalls only the copy it installed itself (the uninstall entry of
    its own throwaway AppId, pointing into its own test folder). Play the game while it runs and the save files
    change: the run then reports that difference - repeat it without playing.

    Inno Setup is not part of the repository. Get it once (free, also for commercial use), portable inside the
    project:
        curl.exe -L -o is.exe https://github.com/jrsoftware/issrc/releases/download/is-7_1_0/innosetup-7.1.0-x64.exe
        .\is.exe /VERYSILENT /PORTABLE=1 /CURRENTUSER /NOICONS /DIR="$PWD\.tools\innosetup"

.PARAMETER Iscc
    Inno Setup compiler. Default: $env:ISCC, else .tools\innosetup\ISCC.exe, else an installed Inno Setup 7 / 6.

.PARAMETER OutputRoot
    Folder of the build output (default: build). The export is read from <OutputRoot>\windows, the installer is
    written to <OutputRoot>\ClubAndGrub-<version>-setup.exe, the test works in <OutputRoot>\installer_test. Use
    another folder (for example build\trial) to try the scripts without replacing the release files in build\.

.PARAMETER SkipBuild
    Package the existing <OutputRoot>\windows export instead of rebuilding it.

.PARAMETER TestInstall
    Install, smoke-check and uninstall a throwaway twin of the installer (step 4).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build_installer.ps1 -TestInstall
#>
[CmdletBinding()]
param(
    [string]$Iscc = "",
    [string]$OutputRoot = "",
    [switch]$SkipBuild,
    [switch]$TestInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ExeName = "ClubAndGrub.exe"
# The AppId of every released installer (installer\club_and_grub.iss). Step 4 only READS what belongs to it.
$RealAppId = "{1BE32CEC-8418-43E5-BEDD-2F34A2D0439C}"
$RealName = "Club & Grub"
$UserDataName = "ClubAndGrub"
$TestNamePrefix = "Club & Grub installer test "
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $OutputRoot) { $OutputRoot = Join-Path $Root "build" }
if (-not [IO.Path]::IsPathRooted($OutputRoot)) { $OutputRoot = Join-Path $Root $OutputRoot }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path
$ExportDir = Join-Path $OutputRoot "windows"
$Script = Join-Path $Root "installer\club_and_grub.iss"
$UninstallNodes = @("Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Stop-Build([string]$Text) {
    Write-Host ""
    Write-Host "INSTALLER FAILED: $Text" -ForegroundColor Red
    exit 1
}

function Find-Iscc {
    $candidates = @($Iscc, $env:ISCC, (Join-Path $Root ".tools\innosetup\ISCC.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 7\ISCC.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 7\ISCC.exe"), (Join-Path $env:ProgramFiles "Inno Setup 7\ISCC.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"))
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    Stop-Build "Inno Setup's ISCC.exe was not found. Install it as described at the top of this script."
}

# Compile installer\club_and_grub.iss with the given defines; returns the compiler's exit code.
function Invoke-Iscc([string]$Compiler, [string[]]$Defines, [string]$LogPath) {
    $arguments = @($Defines | ForEach-Object { "/D$_" }) + @("/Q", $Script)
    & $Compiler @arguments *> $LogPath
    $exitCode = $LASTEXITCODE
    Get-Content -LiteralPath $LogPath | Where-Object { $_ -match '(?i)error|warning' } |
        ForEach-Object { Write-Host "    $_" }
    return $exitCode
}

# The per-user uninstall entry of an AppId (the one a /CURRENTUSER install writes), or $null.
function Get-UserUninstallEntry([string]$AppId) {
    $key = "HKCU:\$($UninstallNodes[0])\$($AppId)_is1"
    if (Test-Path -LiteralPath $key) { return Get-ItemProperty -LiteralPath $key }
    return $null
}

function Get-FileLines([string]$Label, [string]$Folder, [switch]$Recurse, [switch]$Hash, [string[]]$Include) {
    $lines = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $Folder)) {
        $lines.Add("$Label|$Folder|absent")
        return $lines
    }
    $files = @(Get-ChildItem -LiteralPath $Folder -File -Recurse:$Recurse -ErrorAction SilentlyContinue | Sort-Object FullName)
    if ($Include) {
        $files = @($files | Where-Object { $name = $_.Name; @($Include | Where-Object { $name -like $_ }).Count -gt 0 })
    }
    $lines.Add("$Label|$Folder|$($files.Count) file(s)")
    foreach ($file in $files) {
        $line = "$Label|$($file.FullName)|$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"
        if ($Hash) { $line += "|" + (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
        $lines.Add($line)
    }
    return $lines
}

# Everything that belongs to a REAL installation of the game, read only: uninstall entries of the real AppId (this
# user and all users, both registry views) with every value, the installed files, the Start menu folders, the
# desktop shortcuts, and the save and settings files (with hashes). Step 4 compares two of these lists.
function Get-RealInstallState {
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($hive in @("HKCU:", "HKLM:")) {
        foreach ($node in $UninstallNodes) {
            $key = "$hive\$node\$($RealAppId)_is1"
            if (-not (Test-Path -LiteralPath $key)) {
                $lines.Add("registry|$key|absent")
                continue
            }
            $entry = Get-ItemProperty -LiteralPath $key
            foreach ($property in ($entry.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | Sort-Object Name)) {
                $lines.Add("registry|$key|$($property.Name)=$($property.Value)")
            }
            $location = $entry.PSObject.Properties["InstallLocation"]
            if ($location -and $location.Value) {
                foreach ($line in (Get-FileLines "installed" ([string]$location.Value).TrimEnd("\") -Recurse)) { $lines.Add($line) }
            }
        }
    }
    foreach ($menu in @((Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$RealName"),
            (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\$RealName"))) {
        foreach ($line in (Get-FileLines "start menu" $menu -Recurse)) { $lines.Add($line) }
    }
    foreach ($desktop in @([Environment]::GetFolderPath("DesktopDirectory"), [Environment]::GetFolderPath("CommonDesktopDirectory"))) {
        if ($desktop) {
            $shortcut = Join-Path $desktop "$RealName.lnk"
            if (Test-Path -LiteralPath $shortcut) {
                $item = Get-Item -LiteralPath $shortcut
                $lines.Add("desktop|$shortcut|$($item.Length)|$($item.LastWriteTimeUtc.Ticks)")
            } else {
                $lines.Add("desktop|$shortcut|absent")
            }
        }
    }
    foreach ($line in (Get-FileLines "saves" (Join-Path $env:APPDATA $UserDataName) -Hash -Include @("save*", "settings.cfg"))) {
        $lines.Add($line)
    }
    return $lines
}

# One line for the log: is the real game installed here?
function Get-RealInstallSummary {
    foreach ($hive in @("HKCU:", "HKLM:")) {
        foreach ($node in $UninstallNodes) {
            $key = "$hive\$node\$($RealAppId)_is1"
            if (Test-Path -LiteralPath $key) {
                $entry = Get-ItemProperty -LiteralPath $key
                $version = $entry.PSObject.Properties["DisplayVersion"]
                $location = $entry.PSObject.Properties["InstallLocation"]
                return "installed: version $(if ($version) { $version.Value }) in $(if ($location) { $location.Value }) ($hive)"
            }
        }
    }
    return "not installed on this machine"
}

# Remove the test copy this script installed: only through the uninstaller in its own folder, and only when the
# uninstall entry of the throwaway AppId points into that folder. Returns a problem text, or "".
function Remove-TestInstall([string]$TestAppId, [string]$Target, [string]$TestName) {
    if ($TestAppId -eq $RealAppId) { return "refusing to touch the real AppId" }
    $entry = Get-UserUninstallEntry $TestAppId
    $uninstaller = Join-Path $Target "unins000.exe"
    if ($entry) {
        $location = ([string]$entry.InstallLocation).TrimEnd("\")
        if ($location -ne $Target.TrimEnd("\") -or -not ([string]$entry.DisplayName).StartsWith($TestNamePrefix)) {
            return "the uninstall entry of $TestAppId is not this script's test copy ('$($entry.DisplayName)' in '$location'); nothing was removed"
        }
    }
    if (Test-Path -LiteralPath $uninstaller) {
        $uninstall = Start-Process -FilePath $uninstaller -Wait -PassThru -ArgumentList @(
            "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART")
        if ($uninstall.ExitCode -ne 0) { return "silent uninstall exit code $($uninstall.ExitCode)" }
        # The uninstaller finishes by deleting itself from a helper process: give it a moment.
        for ($i = 0; $i -lt 40 -and (Test-Path -LiteralPath $Target); $i++) { Start-Sleep -Milliseconds 500 }
    }
    if (Test-Path -LiteralPath $Target) {
        $left = @(Get-ChildItem -LiteralPath $Target -Recurse -File -ErrorAction SilentlyContinue)
        if ($left.Count -gt 0) { return "files are left in $Target after uninstall: $(($left | Select-Object -First 5 | ForEach-Object { $_.Name }) -join ', ')" }
        Remove-Item -LiteralPath $Target -Recurse -Force
    }
    if (Get-UserUninstallEntry $TestAppId) { return "the uninstall entry of the test copy ($TestAppId) is still registered" }
    $group = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$TestName"
    if (Test-Path -LiteralPath $group) { return "the Start menu folder of the test copy is still there: $group" }
    return ""
}

if (-not $SkipBuild) {
    Write-Step "Release build (tools\build_windows.ps1)"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build_windows.ps1") -OutputRoot $OutputRoot
    if ($LASTEXITCODE -ne 0) { Stop-Build "tools\build_windows.ps1 failed" }
}
$Exe = Join-Path $ExportDir $ExeName
if (-not (Test-Path -LiteralPath $Exe)) { Stop-Build "$Exe is missing; run tools\build_windows.ps1 first" }
if (-not (Test-Path -LiteralPath (Join-Path $ExportDir "licenses\CREDITS.md"))) {
    Stop-Build "$ExportDir\licenses is incomplete; run tools\build_windows.ps1 first"
}

$versionLine = Select-String -LiteralPath (Join-Path $Root "project.godot") -Pattern '^config/version="([^"]+)"' |
    Select-Object -First 1
if (-not $versionLine) { Stop-Build "project.godot has no config/version" }
$Version = $versionLine.Matches[0].Groups[1].Value
$Setup = Join-Path $OutputRoot "ClubAndGrub-$Version-setup.exe"
$exeVersion = [string](Get-Item -LiteralPath $Exe).VersionInfo.ProductVersion
if (-not $exeVersion.StartsWith($Version)) {
    Stop-Build "$Exe is version '$exeVersion', project.godot says $Version; run tools\build_windows.ps1 again"
}

Write-Step "Compile installer $Version"
$compiler = Find-Iscc
Write-Host "    $compiler"
if (Test-Path -LiteralPath $Setup) { Remove-Item -LiteralPath $Setup -Force }
$log = Join-Path $OutputRoot "installer_compile.log"
$compileExit = Invoke-Iscc $compiler @("AppVersion=$Version", "BuildDir=$ExportDir", "OutputDir=$OutputRoot") $log
if ($compileExit -ne 0 -or -not (Test-Path -LiteralPath $Setup)) { Stop-Build "ISCC exit code $compileExit (log: $log)" }
$signature = (Get-Item -LiteralPath $Setup).VersionInfo
if ([string]$signature.ProductName -ne $RealName -or -not ([string]$signature.FileVersion).StartsWith($Version)) {
    Stop-Build "the installer reports product '$($signature.ProductName)' version '$($signature.FileVersion)', expected '$RealName' $Version"
}
Write-Host ("    {0} ({1:N1} MB), product {2}, file version {3}" -f $Setup, ((Get-Item -LiteralPath $Setup).Length / 1MB),
    $signature.ProductName, $signature.FileVersion)

if ($TestInstall) {
    Write-Step "Test install of a throwaway twin, smoke check and uninstall"
    $testRoot = Join-Path $OutputRoot "installer_test"
    $target = Join-Path $testRoot "app"
    $marker = Join-Path $testRoot "test_install.json"
    New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

    # A run that died earlier left its own record: remove that test copy first (it is this script's).
    if (Test-Path -LiteralPath $marker) {
        $old = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
        Write-Host "    removing the test copy an interrupted run left behind ($($old.AppId))"
        $problem = Remove-TestInstall ([string]$old.AppId) ([string]$old.Target) ([string]$old.Name)
        if ($problem) { Stop-Build "cleaning up the earlier test copy: $problem" }
        Remove-Item -LiteralPath $marker -Force
    }
    if (Test-Path -LiteralPath $target) {
        if (@(Get-ChildItem -LiteralPath $target -Recurse -File).Count -gt 0) {
            Stop-Build "$target holds files of unknown origin; remove the folder yourself, then run again"
        }
        Remove-Item -LiteralPath $target -Recurse -Force
    }

    $testGuid = [guid]::NewGuid().ToString().ToUpper()
    $testAppId = "{$testGuid}"
    $testName = $TestNamePrefix + $testGuid.Substring(0, 8)
    $testSetup = Join-Path $testRoot "ClubAndGrub-$Version-setup-TEST-ONLY.exe"
    if ($testAppId -eq $RealAppId) { Stop-Build "the throwaway AppId equals the real one" }
    if (Get-UserUninstallEntry $testAppId) { Stop-Build "the throwaway AppId $testAppId is already registered" }
    if (Test-Path -LiteralPath $testSetup) { Remove-Item -LiteralPath $testSetup -Force }
    $testLog = Join-Path $testRoot "installer_compile.log"
    $compileExit = Invoke-Iscc $compiler @("AppVersion=$Version", "BuildDir=$ExportDir", "OutputDir=$testRoot",
        "TestAppId=$testGuid") $testLog
    if ($compileExit -ne 0 -or -not (Test-Path -LiteralPath $testSetup)) {
        Stop-Build "ISCC exit code $compileExit for the test installer (log: $testLog)"
    }
    $testProduct = [string](Get-Item -LiteralPath $testSetup).VersionInfo.ProductName
    if ($testProduct -ne $testName) { Stop-Build "the test installer names itself '$testProduct', expected '$testName'" }
    Write-Host "    test twin: $testName, AppId $testAppId"
    Write-Host "    real game (AppId $RealAppId): $(Get-RealInstallSummary)"

    $before = @(Get-RealInstallState)
    $failure = ""
    @{ AppId = $testAppId; Target = $target; Name = $testName } | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8
    try {
        $install = Start-Process -FilePath $testSetup -Wait -PassThru -ArgumentList @(
            "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/CURRENTUSER", "/NOCLOSEAPPLICATIONS",
            "/NORESTARTAPPLICATIONS", "/DIR=`"$target`"", "/LOG=`"$(Join-Path $testRoot 'install.log')`"")
        if ($install.ExitCode -ne 0) { throw "silent install exit code $($install.ExitCode)" }
        $installedExe = Join-Path $target $ExeName
        $entry = Get-UserUninstallEntry $testAppId
        if (-not (Test-Path -LiteralPath $installedExe)) { throw "the installed game is missing" }
        if (-not (Test-Path -LiteralPath (Join-Path $target "licenses\CREDITS.md"))) { throw "licences missing" }
        if (-not $entry -or $entry.DisplayVersion -ne $Version) { throw "no uninstall entry for version $Version" }
        if ([string]$entry.DisplayName -ne $testName) { throw "the uninstall entry is named '$($entry.DisplayName)'" }
        if ((Get-FileHash -LiteralPath $installedExe).Hash -ne (Get-FileHash -LiteralPath $Exe).Hash) {
            throw "the installed exe differs from $ExportDir"
        }
        $startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$testName\$testName.lnk"
        if (-not (Test-Path -LiteralPath $startMenu)) { throw "the Start menu shortcut is missing" }
        Write-Host "    installed: $installedExe, uninstall entry '$($entry.DisplayName)' $($entry.DisplayVersion), Start menu ok"

        # Smoke check of the installed game with its own APPDATA, so a player's saves are never read or written.
        $smokeData = Join-Path $testRoot "appdata"
        if (Test-Path -LiteralPath $smokeData) { Remove-Item -LiteralPath $smokeData -Recurse -Force }
        New-Item -ItemType Directory -Force $smokeData | Out-Null
        $smokeLog = Join-Path $testRoot "smoke.log"
        if (Test-Path -LiteralPath $smokeLog) { Remove-Item -LiteralPath $smokeLog -Force }
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $installedExe
        $info.Arguments = "--log-file `"$smokeLog`" --audio-driver Dummy --position 30000,30000 -- --smoke=4"
        $info.UseShellExecute = $false
        $info.EnvironmentVariables["APPDATA"] = $smokeData
        $game = [System.Diagnostics.Process]::Start($info)
        if (-not $game.WaitForExit(120000)) { $game.Kill(); throw "the installed game did not finish its smoke check" }
        $smokeText = Get-Content -LiteralPath $smokeLog -Raw
        if ($game.ExitCode -ne 0 -or $smokeText -notmatch "Smoke: ran .* 0 error\(s\), 0 warning\(s\)") {
            throw "the installed game's smoke check failed (exit $($game.ExitCode), log $smokeLog)"
        }
        if ($smokeText -notmatch [regex]::Escape("$RealName $Version (release build)")) {
            throw "the installed game does not report version $Version (log $smokeLog)"
        }
        Write-Host "    smoke: $(($smokeText -split "`n" | Where-Object { $_ -match '^Smoke: (Club|ran)' } | ForEach-Object { $_.Trim() }) -join '; ')"
        Remove-Item -LiteralPath $smokeData -Recurse -Force
    } catch {
        $failure = $_.Exception.Message
    }

    # Always take the test copy away again, also after a failed check.
    $problem = Remove-TestInstall $testAppId $target $testName
    if ($problem) {
        if ($failure) { $failure += "; " }
        $failure += $problem
    } else {
        Remove-Item -LiteralPath $marker -Force
        Write-Host "    uninstalled cleanly: no file, no uninstall entry, no Start menu folder of the test copy"
    }

    $after = @(Get-RealInstallState)
    $changes = @(Compare-Object -ReferenceObject $before -DifferenceObject $after)
    if ($changes.Count -gt 0) {
        $changes | Select-Object -First 20 | ForEach-Object { Write-Host "    $($_.SideIndicator) $($_.InputObject)" -ForegroundColor Red }
        if ($failure) { $failure += "; " }
        $failure += "the real installation or its saves changed during the test ($($changes.Count) difference(s) above; '<=' before, '=>' after)"
    } else {
        Write-Host "    real installation untouched: $($before.Count) recorded fact(s) (registry, files, Start menu, desktop, saves) are the same after the test"
    }
    if ($failure) { Stop-Build $failure }
    Remove-Item -LiteralPath $testSetup -Force
}

$hash = (Get-FileHash -LiteralPath $Setup -Algorithm SHA256).Hash
Write-Host ""
Write-Host "INSTALLER OK: $Setup" -ForegroundColor Green
Write-Host "    SHA-256 $hash"
exit 0

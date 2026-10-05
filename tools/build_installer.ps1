<#
.SYNOPSIS
    Club & Grub: build the Windows installer (build\ClubAndGrub-<version>-setup.exe) with Inno Setup 7.

.DESCRIPTION
    1. runs tools\build_windows.ps1 (tests, release export, smoke check, licence texts) unless -SkipBuild,
    2. reads the version from project.godot (application/config/version),
    3. compiles installer\club_and_grub.iss with Inno Setup's ISCC and fails on any compiler error,
    4. with -TestInstall: installs silently for the current user into build\installer_test, checks the files,
       runs the installed game's smoke check, uninstalls silently and checks that nothing is left behind
       (program folder, uninstall entry). Saved games in %APPDATA%\ClubAndGrub are never touched.

    Inno Setup is not part of the repository. Get it once (free, also for commercial use), portable inside the
    project:
        curl.exe -L -o is.exe https://github.com/jrsoftware/issrc/releases/download/is-7_1_0/innosetup-7.1.0-x64.exe
        .\is.exe /VERYSILENT /PORTABLE=1 /CURRENTUSER /NOICONS /DIR="$PWD\.tools\innosetup"

.PARAMETER Iscc
    Inno Setup compiler. Default: $env:ISCC, else .tools\innosetup\ISCC.exe, else an installed Inno Setup 7 / 6.

.PARAMETER SkipBuild
    Package the existing build\windows export instead of rebuilding it.

.PARAMETER TestInstall
    Install, smoke-check and uninstall the result (step 4).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build_installer.ps1 -TestInstall
#>
[CmdletBinding()]
param(
    [string]$Iscc = "",
    [switch]$SkipBuild,
    [switch]$TestInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ExeName = "ClubAndGrub.exe"
$AppId = "{1BE32CEC-8418-43E5-BEDD-2F34A2D0439C}"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildDir = Join-Path $Root "build"
$Script = Join-Path $Root "installer\club_and_grub.iss"

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

function Get-UninstallEntry {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($AppId)_is1"
    if (Test-Path -LiteralPath $key) { return Get-ItemProperty -LiteralPath $key }
    return $null
}

if (-not $SkipBuild) {
    Write-Step "Release build (tools\build_windows.ps1)"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build_windows.ps1")
    if ($LASTEXITCODE -ne 0) { Stop-Build "tools\build_windows.ps1 failed" }
}
$Exe = Join-Path $BuildDir "windows\$ExeName"
if (-not (Test-Path -LiteralPath $Exe)) { Stop-Build "$Exe is missing; run tools\build_windows.ps1 first" }
if (-not (Test-Path -LiteralPath (Join-Path $BuildDir "windows\licenses\CREDITS.md"))) {
    Stop-Build "build\windows\licenses is incomplete; run tools\build_windows.ps1 first"
}

$versionLine = Select-String -LiteralPath (Join-Path $Root "project.godot") -Pattern '^config/version="([^"]+)"' |
    Select-Object -First 1
if (-not $versionLine) { Stop-Build "project.godot has no config/version" }
$Version = $versionLine.Matches[0].Groups[1].Value
$Setup = Join-Path $BuildDir "ClubAndGrub-$Version-setup.exe"

Write-Step "Compile installer $Version"
$compiler = Find-Iscc
Write-Host "    $compiler"
if (Test-Path -LiteralPath $Setup) { Remove-Item -LiteralPath $Setup -Force }
$log = Join-Path $BuildDir "installer_compile.log"
& $compiler "/DAppVersion=$Version" "/Q" $Script *> $log
$compileExit = $LASTEXITCODE
Get-Content -LiteralPath $log | Where-Object { $_ -match '(?i)error|warning' } | ForEach-Object { Write-Host "    $_" }
if ($compileExit -ne 0 -or -not (Test-Path -LiteralPath $Setup)) { Stop-Build "ISCC exit code $compileExit (log: $log)" }
$signature = (Get-Item -LiteralPath $Setup).VersionInfo
Write-Host ("    {0} ({1:N1} MB), file version {2}" -f $Setup, ((Get-Item -LiteralPath $Setup).Length / 1MB),
    $signature.FileVersion)

if ($TestInstall) {
    Write-Step "Test install, smoke check and uninstall"
    if (Get-UninstallEntry) {
        Stop-Build "Club & Grub is already installed for this user; uninstall it before -TestInstall"
    }
    $target = Join-Path $BuildDir "installer_test"
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    $install = Start-Process -FilePath $Setup -Wait -PassThru -ArgumentList @(
        "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/CURRENTUSER", "/MERGETASKS=!desktopicon",
        "/DIR=`"$target`"", "/LOG=`"$(Join-Path $BuildDir 'installer_test_install.log')`"")
    if ($install.ExitCode -ne 0) { Stop-Build "silent install exit code $($install.ExitCode)" }
    $installedExe = Join-Path $target $ExeName
    $entry = Get-UninstallEntry
    if (-not (Test-Path -LiteralPath $installedExe)) { Stop-Build "the installed game is missing" }
    if (-not (Test-Path -LiteralPath (Join-Path $target "licenses\CREDITS.md"))) { Stop-Build "licences missing" }
    if (-not $entry -or $entry.DisplayVersion -ne $Version) { Stop-Build "no uninstall entry for version $Version" }
    if ((Get-FileHash -LiteralPath $installedExe).Hash -ne (Get-FileHash -LiteralPath $Exe).Hash) {
        Stop-Build "the installed exe differs from build\windows"
    }
    $startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Club & Grub\Club & Grub.lnk"
    if (-not (Test-Path -LiteralPath $startMenu)) { Stop-Build "the Start menu shortcut is missing" }
    Write-Host "    installed: $installedExe, uninstall entry '$($entry.DisplayName)' $($entry.DisplayVersion), Start menu ok"

    # Smoke check of the installed game with its own APPDATA, so a player's saves are never read or written.
    $smokeData = Join-Path $BuildDir "installer_test_appdata"
    if (Test-Path -LiteralPath $smokeData) { Remove-Item -LiteralPath $smokeData -Recurse -Force }
    New-Item -ItemType Directory -Force $smokeData | Out-Null
    $smokeLog = Join-Path $BuildDir "installer_test_smoke.log"
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $installedExe
    $info.Arguments = "--log-file `"$smokeLog`" -- --smoke=4"
    $info.UseShellExecute = $false
    $info.EnvironmentVariables["APPDATA"] = $smokeData
    $game = [System.Diagnostics.Process]::Start($info)
    if (-not $game.WaitForExit(120000)) { $game.Kill(); Stop-Build "the installed game did not finish its smoke check" }
    $smokeText = Get-Content -LiteralPath $smokeLog -Raw
    if ($game.ExitCode -ne 0 -or $smokeText -notmatch "Smoke: ran .* 0 error\(s\), 0 warning\(s\)") {
        Stop-Build "the installed game's smoke check failed (exit $($game.ExitCode), log $smokeLog)"
    }
    Write-Host "    smoke: $(($smokeText -split "`n" | Where-Object { $_ -match '^Smoke: ran' }) -join ' ')"

    $uninstaller = Join-Path $target "unins000.exe"
    $uninstall = Start-Process -FilePath $uninstaller -Wait -PassThru -ArgumentList @(
        "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART")
    if ($uninstall.ExitCode -ne 0) { Stop-Build "silent uninstall exit code $($uninstall.ExitCode)" }
    # The uninstaller finishes by deleting itself from a helper process: give it a moment.
    for ($i = 0; $i -lt 20 -and (Test-Path -LiteralPath $target); $i++) { Start-Sleep -Milliseconds 500 }
    if (Test-Path -LiteralPath $target) { Stop-Build "files are left in $target after uninstall" }
    if (Get-UninstallEntry) { Stop-Build "the uninstall entry is still registered" }
    if (Test-Path -LiteralPath (Split-Path $startMenu)) { Stop-Build "the Start menu folder is still there" }
    Remove-Item -LiteralPath $smokeData -Recurse -Force
    Write-Host "    uninstalled cleanly"
}

$hash = (Get-FileHash -LiteralPath $Setup -Algorithm SHA256).Hash
Write-Host ""
Write-Host "INSTALLER OK: $Setup" -ForegroundColor Green
Write-Host "    SHA-256 $hash"
exit 0

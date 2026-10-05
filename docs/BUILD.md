# BUILD.md - building Club & Grub for every platform

Exact steps to produce the release builds. All commands run from the project root. `godot` stands for the Godot
4.7.2 console binary (`.tools/godot/Godot_v4.7.2-stable_win64_console.exe` in this repository); inside this
repository prefer `bash .tools/gd.sh raw <arguments>`, which waits until no other Godot uses the project.

## 1. Prerequisites (every platform)

1. **Godot 4.7.2 stable, standard build** (not .NET). `godot --version` must print `4.7.2.stable...`.
2. **Export templates 4.7.2.stable**, unpacked to
   - Windows: `%APPDATA%\Godot\export_templates\4.7.2.stable\`
   - macOS: `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`
   - Linux: `~/.local/share/godot/export_templates/4.7.2.stable/`

   (Editor: *Editor > Manage Export Templates > Download and Install*, or *Install from File* with the `.tpz`.)
3. A clean import and a green test suite:

   ```
   godot --headless --path . --import
   godot --headless --path . -s res://tests/run_tests.gd        # must end with "RESULT: PASS"
   ```

   Godot exits with code 0 even when an export logs errors, so always read the log: a release log has no
   `ERROR:` and no `WARNING:` line (the Windows script below checks this for you).

## 2. The presets (`export_presets.cfg`)

| Preset | Output | Architectures | Signing in the file |
|---|---|---|---|
| `Windows Desktop` | `build/windows/ClubAndGrub.exe` - one file, game data embedded | x86_64 | off (optional Authenticode, 3.3) |
| `macOS` | `build/macos/ClubAndGrub.zip` (`.dmg` possible on a Mac) | universal (arm64 + x86_64) | ad-hoc, distribution type *Testing* |
| `Android` | `build/android/ClubAndGrub.apk` | arm64-v8a, armeabi-v7a | release keystore **placeholders** |
| `iOS` | `build/ios/ClubAndGrub.ipa` (on a Mac; elsewhere an Xcode project) | arm64 | team id **placeholder**, automatic signing |

Every preset exports all resources plus `levels/*.lvl`, `CREDITS.md` and `assets/licenses/*`, and excludes
`tests/*`, `tools/*`, `docs/*`, `build/*`, `levels/test_*.lvl`, the debug level (`scenes/core/debug_level.tscn`,
`scripts/core/debug_level.gd`) and every folder named `dev` (`*/dev/*`). `tests/test_core_release.gd` keeps the
four presets in line. To see exactly what a preset ships, export only the data and list the zip:

```
godot --headless --path . --export-pack "Android" build/export_check/Android.zip
```

Shared identity: application id `com.clubandgrub.game` (macOS, iOS, Android), name "Club & Grub", version from
`application/config/version` in `project.godot` (0.1.0; Windows shows it as 0.1.0.0). The icon is
`res://assets/icon.png` (256 x 256); Godot derives the `.ico`, `.icns` and the legacy Android launcher icon from it.
The iOS store icon (`assets/icon_1024.png`) and the Android adaptive layers (`assets/icon_android_*.png`) are
built from the hero sheet by `tools/make_app_icons.py` (run it again after the hero art changes).

### Placeholders to replace before a store release

| Preset | Option | Value in the file | Replace with |
|---|---|---|---|
| Android | `keystore/release` | `PLACEHOLDER_RELEASE_KEYSTORE_PATH` | path of the upload keystore, or env `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` |
| Android | `keystore/release_user` | `PLACEHOLDER_RELEASE_KEY_ALIAS` | key alias, or env `GODOT_ANDROID_KEYSTORE_RELEASE_USER` |
| Android | `keystore/release_password` | empty - **never commit it** | env `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` |
| iOS | `application/app_store_team_id` | `PLACEHOLDER_APPLE_TEAM_ID` | the 10-character Apple team id |
| macOS | `codesign/apple_team_id` | `PLACEHOLDER_APPLE_TEAM_ID` | the same team id (Developer ID signing) |
| macOS | `codesign/identity` | empty | `Developer ID Application: <Name> (<TEAMID>)` (3.2) |
| all | application id | `com.clubandgrub.game` | keep it if the publisher owns it; otherwise change it in all three presets and in `tests/test_core_release.gd` |
| Windows | `application/company_name`, `application/copyright` | `Club & Grub Team` | the publisher's legal name |

Environment variables always win over the file, so CI machines and release managers keep secrets out of the
repository. When a secret is typed into the editor's export dialog, Godot stores it in
`.godot/export_credentials.cfg`, which is never committed (`.gitignore`). With the placeholders in place an
Android release export fails on purpose ("Release keystore incorrectly configured").

## 3. Windows

### 3.1 One command

```
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
```

The script

1. checks the Godot version and the template `windows_release_x86_64.exe`;
2. imports the project and stops on any import error or warning;
3. runs the whole test suite and stops unless it reports `RESULT: PASS`;
4. exports the `Windows Desktop` preset in release mode to `build\windows\ClubAndGrub.exe`, stops on any `ERROR:` /
   `WARNING:` in the export log and checks that the exe is the only file written (no `.pck`, no DLL);
5. starts the exe for a smoke check (below) and stops unless it exits with code 0 and its log is clean;
6. prints the SHA-256 of the exe and exits with 0. Any failure prints `BUILD FAILED: ...` and exits with 1.

Options: `-Godot <path>` (else `$env:GODOT`, else `.tools\godot\...`, else `godot` on the PATH), `-SmokeSeconds <n>`
(default 4), `-HeadlessSmoke` (build machines without a GPU), `-SkipTests` (packaging experiments only - never
ship such a build). Logs: `build\windows\logs\` (import, tests, export) and `build\windows\smoke\smoke.log`.

### 3.2 The smoke check of a release build

Release builds act on no development command-line switch (`--autoplay`, `--inputs`, `--shots`, ... need a debug
build). The one switch they honour is the boot check:

```
build\windows\ClubAndGrub.exe --log-file build\windows\smoke\smoke.log -- --smoke=3
```

It runs the game normally for 3 s (0.1 .. 120), then quits through the normal shutdown, with exit code 0 only when
nothing logged an error or a warning. In an exported build it also logs an error for every development file it
finds inside the package. The log ends with lines such as

```
Smoke: Club & Grub 0.1.0 (release build), 9 level(s), screen 'title'
Smoke: ran 3.0 s, 0 error(s), 0 warning(s) logged
```

The script runs the exe with `APPDATA` pointed at `build\windows\smoke\appdata`, so the check never reads or writes
the settings and saves of a real installation, and it adds `--autoplay=w1_l1`, which the log must report as
ignored. The exe is a GUI program: it opens no console, so read the log file, not the terminal.

### 3.3 Manual export and optional code signing

```
godot --headless --path . --export-release "Windows Desktop" build/windows/ClubAndGrub.exe
```

Unsigned executables trigger SmartScreen warnings. To sign with Authenticode: install the Windows SDK, set the
editor setting *Export > Windows > Signtool* to `signtool.exe`, set `codesign/enable=true` in the preset and provide
the certificate through `GODOT_WINDOWS_CODESIGN_IDENTITY` (path of the `.pfx` or the certificate's SHA-1),
`GODOT_WINDOWS_CODESIGN_IDENTITY_TYPE` (0 = select automatically, 1 = PKCS#12 file, 2 = certificate store) and
`GODOT_WINDOWS_CODESIGN_PASSWORD`.

Graphics: the build uses the Compatibility renderer on OpenGL 3.3. ANGLE (OpenGL ES on Direct3D, for very old or
broken GPU drivers) is not shipped, because it needs two DLLs next to the exe; set `application/export_angle=1` if
that fallback matters more than a single file.

## 4. macOS

**Bundle name (Godot 4.7.2 workaround, applied):** the macOS export writes the executable name into `Info.plist`
without escaping it, and the project name contains `&`, which would make the bundle's `Info.plist` invalid XML.
`project.godot` therefore sets `config/name.macos="Club and Grub"` in `[application]`: the bundle is
`Club and Grub.app` with a valid `Info.plist`. Keep that override until the engine escapes the name.

### 4.1 Test build (any host)

```
godot --headless --path . --export-release "macOS" build/macos/ClubAndGrub.zip
```

The zip holds the universal `.app`, signed ad-hoc (built-in signer). On a Mac: unzip, then right-click the app >
*Open* (or `xattr -dr com.apple.quarantine "Club and Grub.app"`) the first time, because the build is neither
Developer-ID signed nor notarized.

### 4.2 Distribution build (Developer ID, outside the App Store)

1. Apple Developer Program membership; a *Developer ID Application* certificate in the keychain (Mac) or as a
   `.p12` file (any host).
2. In the preset: `export/distribution_type` = *Distribution*, `codesign/apple_team_id` = your team id,
   `codesign/identity` = `Developer ID Application: <Name> (<TEAMID>)`.
3. Signing: on a Mac choose *Xcode codesign*; on other hosts *rcodesign* (install `rcodesign` and set its path in
   the editor settings) with `GODOT_MACOS_CODESIGN_CERTIFICATE_FILE` / `GODOT_MACOS_CODESIGN_CERTIFICATE_PASSWORD`.
4. Notarization: *Xcode notarytool* (Mac) or *rcodesign* with an App Store Connect API key:
   `GODOT_MACOS_NOTARIZATION_API_UUID` (issuer id), `GODOT_MACOS_NOTARIZATION_API_KEY` (path of the `.p8`),
   `GODOT_MACOS_NOTARIZATION_API_KEY_ID`. (Apple-id notarization: `GODOT_MACOS_NOTARIZATION_APPLE_ID_NAME` /
   `..._PASSWORD`, an app-specific password.)
5. Export (`.dmg` needs a Mac; `.zip` works everywhere), then staple: `xcrun stapler staple "Club and Grub.app"`.

The Mac App Store additionally needs `codesign/entitlements/app_sandbox/enabled=true`, an installer identity, a
provisioning profile (`GODOT_MACOS_CODESIGN_PROVISIONING_PROFILE`) and distribution type *App Store* (Mac only).

## 5. Android

### 5.1 One-time setup

1. JDK 17 and the Android SDK with `platform-tools`, `build-tools;36.0.0` (any 35+ works; Godot falls back to the
   newest installed and says so) and `platforms;android-36`:

   ```
   sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-36" "cmdline-tools;latest"
   ```

2. Editor settings (*Editor > Editor Settings > Export > Android*): `Java SDK Path`, `Android SDK Path`. Godot
   creates the debug keystore itself.
3. An **upload keystore** for release builds, kept outside the repository and backed up:

   ```
   keytool -genkeypair -v -keystore clubandgrub-upload.jks -alias clubandgrub -keyalg RSA -keysize 4096 -validity 10000
   ```

### 5.2 Release APK (sideloading, testing)

```
set GODOT_ANDROID_KEYSTORE_RELEASE_PATH=C:\keys\clubandgrub-upload.jks
set GODOT_ANDROID_KEYSTORE_RELEASE_USER=clubandgrub
set GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<password>
godot --headless --path . --export-release "Android" build/android/ClubAndGrub.apk
adb install -r build/android/ClubAndGrub.apk
```

Verified on the development machine with a throwaway keystore: the preset produces a signed APK with
`lib/arm64-v8a` and `lib/armeabi-v7a`, package `com.clubandgrub.game`, min SDK 24, target SDK 36, landscape
(`userLandscape`), `isGame`, backup allowed, and exactly one permission (`VIBRATE`, for `GameInput.vibrate`).

### 5.3 Google Play (AAB)

Google Play needs an Android App Bundle, which Godot builds with Gradle from the Android build template:

1. `godot --headless --path . --install-android-build-template --export-release "Android" build/android/ClubAndGrub.apk`
   once per build machine; this creates the Gradle project in `android/build/` (ignored by git - commit it only if
   the team decides to customise it).
2. In the preset set `gradle_build/use_gradle_build=true` and `gradle_build/export_format=1` (AAB).
3. `godot --headless --path . --export-release "Android" build/android/ClubAndGrub.aab`.
4. Raise `version/code` in the preset for every upload (Play rejects a code it has seen).

Enrol in Play App Signing; the keystore above is then only the upload key.

## 6. iOS

1. A Mac with Xcode 16 or newer, an Apple Developer Program membership, the bundle id `com.clubandgrub.game`
   registered under *Certificates, Identifiers & Profiles*, and an app record in App Store Connect.
2. Replace `PLACEHOLDER_APPLE_TEAM_ID` (`application/app_store_team_id`). Signing is automatic; for manual signing
   set `GODOT_APPLE_PLATFORM_PROVISIONING_PROFILE_UUID_RELEASE` (or `..._SPECIFIER_RELEASE`).
3. Export on the Mac:

   ```
   godot --headless --path . --export-release "iOS" build/ios/ClubAndGrub.ipa
   ```

   Godot writes the Xcode project and runs `xcodebuild` to archive and export the `.ipa` (method *App Store*). On
   Windows or Linux the same command stops after writing the Xcode project (warning "`.ipa` can only be built on
   macOS"); copy `build/ios/` to a Mac and use *Product > Archive* in Xcode.
4. Upload with Xcode's Organizer or Transporter; test through TestFlight.

The preset already declares landscape only, full screen, hidden status bar, iPhone and iPad, iOS 15+, no camera,
no file sharing, and `ITSAppUsesNonExemptEncryption = false` (no export-compliance question per upload).

## 7. Release checklist

1. `application/config/version` raised in `project.godot`; Android `version/code` raised.
2. Import clean, `tests/run_tests.gd` green, level validator green.
3. Windows: `tools\build_windows.ps1` ends with `BUILD OK`.
4. Other platforms: export, install on the devices of `docs/PORTING.md` section 5, run the device checklist.
5. `CREDITS.md` and `assets/licenses/` are inside the package (they are, through the include filter).
6. Archive the exact build: the exe / apk / aab / ipa, its SHA-256, and the commit it was built from.

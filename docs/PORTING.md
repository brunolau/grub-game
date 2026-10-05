# PORTING.md - shipping Club & Grub on Android, iOS and macOS

Windows is the primary platform today. This document lists what the project already does for the other three
platforms, what is still missing before a store release, and how to test on devices. Build commands and signing
are in [BUILD.md](BUILD.md).

## 1. Already handled in the project

| Area | What is in place | Where |
|---|---|---|
| Rendering | Compatibility renderer (OpenGL ES 3.0 class) on every platform; nearest filtering, lossless textures (no ETC2 / ASTC / S3TC decisions needed), integer scaling | `project.godot`, ARCHITECTURE.md 2 |
| Screen shapes | 640 x 360 base picture scaled by whole numbers; wider or taller screens show more level (800 x 360 on a 20:9 phone, about 682 x 512 on a 4:3 tablet), never black bars | ARCHITECTURE.md 2 |
| Orientation | sensor landscape on phones and tablets (Android `userLandscape`, iOS landscape left / right), full screen, hidden status bar; Android immersive mode | `project.godot`, `export_presets.cfg` |
| Input | keyboard, gamepad and touch feed the same actions; the touch overlay appears when a touch device is used (`GameInput.wants_touch_controls()`); glyphs switch on `GameInput.device_changed`; Bluetooth / USB gamepads use Godot's standard controller layout (A / B / X / Y by position) | `scripts/core/game_input.gd`, ui module |
| Rebinding | every game action, keyboard and gamepad, saved in `settings.cfg` | `Settings.set_binding()` |
| Background / focus | gameplay pauses (pause menu shows), music and ambience halt in place and resume with the focus, effects are dropped, touch buttons are released, settings are written before the OS may kill the app; the simulation never catches up time spent in the background | `Flow`, `Audio.set_suspended()`, `GameInput`, `Sim` |
| Back button | Android back pauses running gameplay and acts as `ui_cancel` in menus; it never quits the app by surprise (`quit_on_go_back` off) | `Flow._notification` |
| Quitting | mobile builds never call `quit()`: "quit" returns to the title, the OS closes apps; desktop quits cleanly through `Flow.shutdown_and_quit()` | `Flow.quit_game()` |
| Persistence | `user://` is the app sandbox on phones; saves are written atomically with a backup; Android cloud backup is allowed (`user_data_backup/allow`) so progress follows the player to a new phone | `Save`, `Settings` |
| Haptics | `GameInput.vibrate()` (setting `controls/vibration`); Android `VIBRATE` permission declared | `export_presets.cfg` |
| Privacy | no network, no analytics, no ads, no accounts, no permission except vibration; iOS privacy manifest generated with "no data collected"; `ITSAppUsesNonExemptEncryption = false` | `export_presets.cfg` |
| Architectures | Android arm64-v8a + armeabi-v7a; iOS arm64; macOS universal (Apple Silicon + Intel) | `export_presets.cfg` |
| Development files | tests, tools, docs, test levels, debug level and `dev` folders are excluded from every preset; release builds ignore development switches | ARCHITECTURE.md 2, 9.2 |
| Battery | `Engine.max_fps` 0 with vsync; the clock stops while paused or in the background | ARCHITECTURE.md 11 |
| Licences | the full Godot MIT / third-party notices and both OFL font licences are readable in the game (Credits > Licences, look button or tap): the only compliant place on a phone, where no file ships next to the app | `scripts/ui/credits.gd`, `assets/licenses/` |
| Options | the touch section (buttons always shown, opacity, size, layout) appears where touch can be used: a touch screen, a mobile build, or touch buttons switched on | `OptionsPanel.touch_options_wanted()` |

## 2. Android - what remains

**Toolchain** (once per build machine): JDK 17, Android SDK (`platform-tools`, `build-tools` 35 or newer,
`platforms;android-36`), Godot editor settings for both paths, the Android build template for Gradle / AAB builds
(BUILD.md 5).

**Signing**: create the upload keystore, store it and its password in the team's secret store, provide them through
`GODOT_ANDROID_KEYSTORE_RELEASE_*`; enrol in Play App Signing.

**Project work**

1. Switch the preset to Gradle + AAB for Play (`gradle_build/use_gradle_build=true`, `export_format=1`); keep APK
   for sideloading.
2. Adaptive launcher icons: DONE. `launcher_icons/adaptive_foreground_432x432`, `adaptive_background_432x432` and
   `adaptive_monochrome_432x432` are `assets/icon_android_foreground.png` (the hero inside the 66 dp safe circle),
   `icon_android_background.png` (opaque sky and grass) and `icon_android_monochrome.png` (themed icons), built by
   `tools/make_app_icons.py` from the hero sheet with integer nearest-neighbour scaling only;
   `tests/test_core_release.gd` checks sizes, opacity and the safe zone. `main_192x192` stays `assets/icon.png`.
3. Verify 16 KB memory-page compatibility (required for new Play uploads targeting Android 15+): the Play Console
   pre-launch report flags it; locally `zipalign -c -P 16 -v 4 <apk>`.
4. Raise `version/code` for every upload; keep `version/name` empty (it follows the project version).
5. Measure the simulation on the low-end phone before the release: the budget is one tick <= 2 ms on 4 x Cortex-A53
   (ARCHITECTURE.md 11), and only desktop numbers exist so far (ARCHITECTURE.md 11.4: 132-272 us average per tick
   windowed on a Ryzen 9 7900X; a Cortex-A53 runs GDScript roughly 10-15x slower). If it is over, the remaining
   cost is the hero's tick and the item bursts of the boss defeats (ARCHITECTURE.md 11.4).
6. Decide whether to support Android TV / Chromebooks with a gamepad (`package/show_in_android_tv`, leanback banner);
   not planned now.

**Store metadata (Play Console)**: app name, short and full description, 512 x 512 icon, 1024 x 500 feature
graphic, phone and 7" / 10" tablet screenshots (landscape), category *Games > Platformer*, content rating
questionnaire (IARC; cartoon violence), Data safety form (no data collected or shared), privacy policy URL, target
audience and ads declaration (no ads), contact e-mail.

## 3. iOS - what remains

**Toolchain**: a Mac with Xcode 16 or newer (the export runs `xcodebuild`), Godot 4.7.2 and its templates on that
Mac, an Apple Developer Program membership.

**Signing**: replace `PLACEHOLDER_APPLE_TEAM_ID`; register `com.clubandgrub.game`; let Xcode manage certificates
and profiles (automatic signing) or supply provisioning profiles through the `GODOT_APPLE_PLATFORM_*` variables.

**Project work**

1. App icon: DONE for `icons/icon_1024x1024`: `assets/icon_1024.png`, 1024 x 1024, opaque (the App Store rejects
   transparency; the system rounds the corners), built by `tools/make_app_icons.py`. Dark and tinted variants are
   optional and still empty.
2. Launch screen: the storyboard uses `assets/splash.png` on the splash colour; check it on notched iPhones and
   iPads, or provide `storyboard/custom_image@2x` / `@3x`.
3. Renderer: the Compatibility renderer runs on Apple's OpenGL ES, which Apple deprecated. Measure on the oldest
   supported device; if Apple drops it or performance suffers, switch `rendering_method.mobile` to `mobile`
   (Metal) - the only custom shader is `scripts/core/transition_cover.gdshader`, which is renderer-neutral.
4. Audio session: Godot's default iOS category (`audio/general/ios/session_category`, *Ambient*) mixes with the
   player's music and follows the silent switch; keep it unless testing shows otherwise.
5. Safe area: the HUD and touch controls must stay inside `DisplayServer.get_display_safe_area()` (Dynamic Island,
   home indicator); this is the ui module's job, verify it on device.

**Store metadata (App Store Connect)**: name, subtitle, description, keywords, support and privacy policy URLs,
screenshots for 6.9" iPhone and 13" iPad (landscape), age rating questionnaire, App Privacy "Data Not Collected",
category *Games > Action / Platformer*, TestFlight test information.

## 4. macOS - what remains

**Bundle name**: the `&` in the project name would break the bundle's `Info.plist` (Godot 4.7.2 does not escape
the executable name); `project.godot` sets `config/name.macos="Club and Grub"` (BUILD.md 4). Done.

**Toolchain and signing**: a Developer ID Application certificate; signing with Xcode codesign (Mac) or rcodesign
(any host); notarization with an App Store Connect API key; `.dmg` packaging on a Mac (BUILD.md 4.2).

**Project work**

1. Icon: Godot builds the `.icns` from `assets/icon.png`; a 1024 x 1024 master gives crisp Retina icons.
2. Fullscreen: `video/fullscreen` uses the native macOS fullscreen space; check the menu-bar / notch area on
   MacBooks with a notch.
3. Gamepads: test Xbox, PlayStation and MFi controllers.
4. Cmd+Q and the red close button arrive as a close request and quit through `Flow.shutdown_and_quit()`;
   verify that settings are saved.
5. Distribution channel: direct download (Developer ID + notarization), Steam, or the Mac App Store (sandbox
   entitlement and App Store provisioning, BUILD.md 4.2).

## 5. Device-testing checklist (every mobile release)

Devices: one low-end Android phone (4 x Cortex-A53 class, 2 GB RAM, Android 7 / API 24 - the performance budget of
ARCHITECTURE.md 11), one current Android phone with a punch-hole display, one Android tablet, the oldest supported
iPhone (iOS 15), a current iPhone with Dynamic Island, an iPad; for macOS one Apple Silicon and one Intel Mac.

1. Install, first start, time to the title screen (< 5 s on the low-end phone), uninstall / reinstall.
2. Landscape both ways; rotating 180 degrees mid-level; the app never shows portrait.
3. Aspect ratios 16:9, 19.5:9 / 20:9, 4:3 (iPad) and a foldable if available: no black bars, nothing important
   off-screen, HUD and touch buttons inside the safe area.
4. Touch: every screen and menu fully usable by touch; buttons at least 56 art px; multi-touch (walk + jump +
   strike at once); touch overlay opacity and scale settings.
5. Gamepad: connect and disconnect a Bluetooth pad mid-level (glyphs switch, overlay hides / shows, no stuck
   direction); rebinding works and survives a restart.
6. Background: home button / gesture mid-level, app switcher, lock screen, incoming call, alarm, notification
   shade: the game is paused on return, the music continues where it stopped, no sound played while away, no
   held direction or button afterwards.
7. Back button (Android): pauses gameplay, closes menus, never loses progress.
8. Low-memory kill: background the app, open several heavy apps, return: the game restarts at the title with
   settings and progress intact.
9. Audio: silent switch (iOS), headphones plugged / unplugged, Bluetooth audio latency, volume sliders.
10. Haptics on / off.
11. Performance: 60 fps in the busiest level (boss fight, many enemies), CPU and GPU under 8 ms per frame, no
    hitch when a level loads; 30 minutes of play without thermal throttling hurting the frame rate.
12. Battery: one hour of play on the low-end phone; paused game drains no more than the home screen.
13. Locale: system language other than English, right-to-left system (layout must not mirror the game).
14. Save data: finish a level, kill the app, restart: unlocked levels and high score are kept; restore from an
    Android backup on a second device.
15. Store builds: install the exact signed AAB / IPA (internal testing track, TestFlight) and repeat 1, 6 and 8.

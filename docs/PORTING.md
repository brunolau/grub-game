# PORTING.md - shipping Club & Grub on Android, iOS and macOS

Windows is the release platform of 2.0.0 (exe, zip, installer). Android, iOS and macOS are kept "easy to port":
their export presets load and pack (BUILD.md 2.1), and this document lists what the project already does for them,
what 2.0 added, what is still missing before a store release, and how to test on devices. Build commands and
signing are in [BUILD.md](BUILD.md).

**State of 2.0.0** (what was done): on 2026-10-09 the three presets were loaded and packed headless on the Windows
build machine with the check of BUILD.md 2.1 - `Android`, `macOS` and `iOS` each: exit code 0, no `ERROR:` or
`WARNING:` line, a pack of 2 591 entries holding the same 1 368 project files as the Windows exe and no development
file, `export_presets.cfg` unchanged. **No Android, iOS or macOS build was exported or run for 2.0.0**: their
toolchains (JDK and Android SDK, a Mac with Xcode, signing identities) are not part of the project and nothing
outside the project is installed for a release. Everything below that says "verify on device" is therefore open,
and the device steps a person runs are in `docs/expansion/HUMAN_CHECKS.md`.

## 1. Already handled in the project

| Area | What is in place | Where |
|---|---|---|
| Rendering | Compatibility renderer (OpenGL ES 3.0 class) on every platform; nearest filtering, lossless textures (no ETC2 / ASTC / S3TC decisions needed), integer scaling | `project.godot`, ARCHITECTURE.md 2 |
| Screen shapes | 640 x 360 base picture scaled by whole numbers; wider or taller screens show more level (800 x 360 on a 20:9 phone, about 682 x 512 on a 4:3 tablet), never black bars | ARCHITECTURE.md 2 |
| Orientation | sensor landscape on phones and tablets (Android `userLandscape`, iOS landscape left / right), full screen, hidden status bar; Android immersive mode | `project.godot`, `export_presets.cfg` |
| Input | keyboard, gamepad and touch feed the same actions; the touch overlay appears when a touch device is used (`GameInput.wants_touch_controls()`); glyphs switch on `GameInput.device_changed`; Bluetooth / USB gamepads use Godot's standard controller layout (A / B / X / Y by position). 2.0: the new action `swap` (V, `;`, pad LB, a touch stone) | `scripts/core/game_input.gd`, ui module |
| Two to four players (2.0) | every player slot reads its own device (`InputSlot`): a half of a shared keyboard (three layouts; the default is P1 on W A S D, Space, Left Ctrl, E, Q and P2 on the numpad 8 4 5 6, Num 0, Num Enter, Num +, Num . - bound by physical key, so every keyboard layout and Num Lock state works), one gamepad per slot (by device id; rumble only on that slot's pad), or the touch overlay (one touch player). Keyboards seat two players; players three and four of versus use pads. The join screen has a key test for keyboards that drop key combinations | `scripts/core/input_slot.gd`, `GameInput` slots, DESIGN.md D.11 / E.9 |
| A pad that drops out (2.0) | `Input.joy_connection_changed` reaches `Flow.notify_pad_connection`: a pad seat lost during play pauses with "Reconnect, or continue alone"; the next pad that connects takes the oldest lost seat, whatever device id the system gives it; `continue_alone` lets the partner play on (co-op) or seats a bot (versus) | ARCHITECTURE.md 3.7, `Flow` |
| Rebinding | every game action, keyboard and gamepad, saved in `settings.cfg`; 2.0: one binding profile per player slot beside the single-player one (`[bindings_p1]`..`[bindings_p4]`) | `Settings.set_binding()`, `Settings.set_slot_binding()` |
| Background / focus | gameplay pauses (pause menu shows), music and ambience halt in place and resume with the focus, effects are dropped, touch buttons are released, settings are written before the OS may kill the app; the simulation never catches up time spent in the background | `Flow`, `Audio.set_suspended()`, `GameInput`, `Sim` |
| Back button | Android back pauses running gameplay and acts as `ui_cancel` in menus; it never quits the app by surprise (`quit_on_go_back` off) | `Flow._notification` |
| Quitting | mobile builds never call `quit()`: "quit" returns to the title, the OS closes apps; desktop quits cleanly through `Flow.shutdown_and_quit()` | `Flow.quit_game()` |
| Persistence | `user://` is the app sandbox on phones; saves are written atomically with a backup; Android cloud backup is allowed (`user_data_backup/allow`) so progress follows the player to a new phone. 2.0: save version 2 (progress per mode, book and difficulty); a version 1 save is migrated on load and copied untouched to `save.v1.json` before the first write, on every platform alike (plain files in `user://`, no platform code); `settings.cfg` keeps its version and format | `Save`, `Settings`, `tests/test_core_save_1_0.gd` |
| Haptics | `GameInput.vibrate()` (setting `controls/vibration`); Android `VIBRATE` permission declared | `export_presets.cfg` |
| Privacy | no network, no analytics, no ads, no accounts, no permission except vibration; iOS privacy manifest generated with "no data collected"; `ITSAppUsesNonExemptEncryption = false` | `export_presets.cfg` |
| Architectures | Android arm64-v8a + armeabi-v7a; iOS arm64; macOS universal (Apple Silicon + Intel) | `export_presets.cfg` |
| Development files | tests, tools, docs, test levels and their baked bot graphs, the debug level, `dev` folders, the level validator and the co-op gate search are excluded from every preset, with the same filters on all four (`tests/test_core_release.gd`, `tests/test_core_release_pack.gd`); release builds ignore development switches | ARCHITECTURE.md 2, 9.2, BUILD.md 2 |
| Battery | `Engine.max_fps` 0 with vsync; the clock stops while paused or in the background | ARCHITECTURE.md 11 |
| Licences | the full Godot MIT / third-party notices and both OFL font licences are readable in the game (Credits > Licences, look button or tap): the only compliant place on a phone, where no file ships next to the app | `scripts/ui/credits.gd`, `assets/licenses/` |
| Options | the touch section (buttons always shown, opacity, size, layout) appears where touch can be used: a touch screen, a mobile build, or touch buttons switched on | `OptionsPanel.touch_options_wanted()` |

### 1a. What 2.0 changes for a port

- **Content**: 78 level files instead of 15 (35 solo stages, their 35 co-op versions, 8 arenas) and more than
  twice the asset files (869 instead of 393). The packed data is about 79 MB as a zip (the Windows exe with the
  engine is 183 MB); a phone build is of that order. No texture or audio format decision changed: lossless textures,
  Ogg Vorbis music.
- **Co-op on a phone or tablet**: one touch player plus one gamepad player (the touch overlay serves one slot). The
  two-player "table mode" (mirrored touch clusters at both ends of a tablet) is a hidden prototype in 2.0 and is not
  reachable from the release menus (DESIGN.md D.11 [G37]).
- **Versus on a phone or tablet**: one touch player against bots, or with up to three pads.
- **Performance**: a party costs more than one hero - each extra hero adds about 100 us per tick on the desktop
  (docs/expansion/TECH_AUDIT.md 1). The budget of ARCHITECTURE.md 11 (one tick
  <= 2 ms on 4 x Cortex-A53) was not met by the desktop proxy numbers of 1.0 already and was **never measured on a
  device**; PLAN.md P4.2 asks for two-hero co-op inside the 1.0 budget class on that phone and four heroes on
  mobile only where the check passes (else a cap of two there). That measurement is open (section 2, item 5).
- **Screen**: the shared tribe camera frames two heroes inside the same 640 x 360 base picture; wider screens show
  more, as before. Versus arenas are one screen (20 x 12 cells) with a decorated frame on other shapes.
- **Store text and ratings**: local multiplayer only - still no network, no accounts, no data collected. "Number of
  players: 1-4, shared device" for the store forms.
- **Versions**: `application/config/version` is 2.0.0 for every platform (the presets' own version fields stay
  empty); the Android `version/code` is 2.

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
4. Raise `version/code` for every upload (it is 2 for 2.0.0); keep `version/name` empty (it follows the project
   version).
5. Measure the simulation on the low-end phone before the release: the budget is one tick <= 2 ms on 4 x Cortex-A53
   (ARCHITECTURE.md 11), and only desktop numbers exist so far (ARCHITECTURE.md 11.4: 132-272 us average per tick
   windowed on a Ryzen 9 7900X for 1.0 solo; a Cortex-A53 runs GDScript roughly 10-15x slower). If it is over, the
   remaining cost is the hero's tick and the item bursts of the boss defeats (ARCHITECTURE.md 11.4). For 2.0 measure
   a two-hero co-op stage of every world and a four-player arena as well (section 1a). **How**: the perf probe
   (`--perf`) is a development tool - a release build ignores it and no export carries it (`*/dev/*`, `tools/*`
   are excluded), so the measurement needs a private measuring export: a debug export from a copy of the Android preset whose
   exclude filter keeps `scripts/core/dev/*` and whose include filter adds the flow and route files it plays,
   started with the flow and `--perf` as user arguments (`command_line/extra_args`); outside the editor the probe
   writes `perf.json` to `user://screenshots/<out>/`, on Android the app's private files folder (read it with
   `adb shell run-as com.clubandgrub.game cat files/screenshots/<out>/perf.json`). **This was not run for 2.0.0**
   and is untested (no Android toolchain in the project); the steps for a person are in
   `docs/expansion/HUMAN_CHECKS.md`.
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
   direction); rebinding works and survives a restart. 2.0, with two players: pull the second player's pad during a
   co-op stage and during a versus round - the game pauses with "Reconnect, or continue alone", the pad takes its
   seat again when it returns (also when the system gives it a new id), "continue alone" leaves the partner in play
   (co-op) or seats a bot (versus), and no hero keeps a held direction.
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
    Android backup on a second device. 2.0: co-op and Book II progress are kept apart from solo Book I (Solo and
    Co-op, each book and difficulty has its own slot); a device that held a 1.0 build shows its progress under
    Solo > Book I after the update, and `save.v1.json` lies beside `save.json`.
15a. Two players (2.0): co-op with the touch player and one pad through one whole stage (the shared camera, the Egg
    Hatch, a gate that needs both); versus with the touch player and bots, and with two or more pads; touch buttons
    of the touch player stay inside the safe area and never cover the second hero's HUD panel (top right).
15. Store builds: install the exact signed AAB / IPA (internal testing track, TestFlight) and repeat 1, 6 and 8.

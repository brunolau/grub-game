# THIRD_PARTY - Club & Grub

Every third-party component of Club & Grub, its licence, what the licence requires of a game that is sold as a closed
binary and developed in a public repository, and where Club & Grub meets each requirement. Audit date: 2026-10-05
(Godot 4.7.2, export presets of `export_presets.cfg`). Player-facing credits: `CREDITS.md` (shipped; the in-game
credits roll is generated from it). Shipped licence texts: `assets/licenses/` (index: `assets/licenses/README.md`).

## 1. What a build contains

| Part | Content | Licence situation |
|---|---|---|
| Engine runtime | official Godot 4.7.2-stable export templates (Windows x86_64; macOS universal; Android arm64-v8a / armeabi-v7a; iOS arm64) | MIT + third-party notices (section 2.1) |
| Game data (PCK, embedded in the Windows .exe) | `export_filter = all_resources` plus `levels/*.lvl`, `CREDITS.md`, `assets/licenses/*`; minus `tests/`, `tools/`, `docs/`, `build/`, test levels, `*/dev/*`, the debug level, `resources/ui/*.py` | our own code, scenes and levels; third-party art, fonts and audio (sections 2.2-2.4) |
| Not bundled on Windows | ANGLE (`application/export_angle=0`), Direct3D 12 Agility SDK (`application/export_d3d12=0`) | if either is switched on later, add its notice (ANGLE BSD-3-clause, Microsoft Agility SDK licence) |

Checked on `build/release_check/pack_check.zip` (an export of the Windows preset, 1270 entries): `CREDITS.md` and all
of `assets/licenses/` are inside; no file from `docs/`, `tools/`, `tests/` or `build/` is.

## 2. Components

### 2.1 Engine

| Component | Author / holder | Licence | Obligation | Met by |
|---|---|---|---|---|
| Godot Engine 4.7.2-stable (official build ed1daf0bf) | Godot Engine contributors; Juan Linietsky, Ariel Manzur | MIT (Expat) | copyright notice and permission notice in all copies | full text in `assets/licenses/godot_engine.txt` (ships); copyright lines in the in-game credits ("Engine") |
| 102 third-party components compiled into Godot (FreeType, HarfBuzz, ICU, Graphite, libogg / libvorbis / libtheora, libpng, libjpeg-turbo, libwebp, zlib, Zstandard, Brotli, MiniZip, mbed TLS, ENet, wslay, SDL + hidapi, Jolt Physics, PCRE2, Basis Universal, astcenc, etcpak, Embree, Clipper2, ThorVG, msdfgen, glslang, SPIRV-Cross, Vulkan headers / VMA / volk, D3D12MA, DirectX headers, AccessKit, OpenXR loader, Android AOSP code, ProcessPhoenix, Swappy, metal-cpp, built-in fonts Open Sans / Noto Sans / Inter / JetBrains Mono / Vazirmatn / DroidSans, Godot logo, ...) | see the file | Expat / MIT, BSD-2-clause, BSD-3-clause, Zlib, Apache-2.0, FTL, MPL-2.0, OFL-1.1, CC-BY-4.0, CC0-1.0, Unicode, IJG, HarfBuzz, glslang, BSL-1.0, Unlicense, MIT-0, WOL, X11 | BSD / MIT / Zlib-with-notice: reproduce copyright and licence in the documentation of binary distributions; Apache-2.0: include the licence text; FTL: credit FreeType in the documentation; OFL / CC-BY: only if shown or shipped separately (they are only compiled into the binary) | `assets/licenses/godot_third_party.txt` (ships): every component with files, copyright lines and licence, then all 19 licence texts, generated from the engine itself (`Engine.get_copyright_info()`, `Engine.get_license_info()`); FreeType sentence in `godot_engine.txt` and in the in-game credits |

The Godot logo (CC-BY-4.0) is not shown: the boot splash is our own `assets/splash.png` (`boot_splash/image`). Using
the "Made with Godot" logo on a store page or trailer requires crediting it (Andrea Calabró, CC-BY-4.0).

### 2.2 Fonts (licence text must ship)

| Font | File | Author / holder | Source | Licence | Obligation | Met by |
|---|---|---|---|---|---|---|
| Press Start 2P | `assets/fonts/press_start_2p.ttf` (byte-identical to Google Fonts' `PressStart2P-Regular.ttf`) | CodeMan38 (Cody Boisclair); Copyright 2012 The Press Start 2P Project Authors | https://fonts.google.com/specimen/Press+Start+2P | SIL OFL 1.1, Reserved Font Name "Press Start 2P" | copyright notice + licence in every copy; never sell the font by itself; a modified font must not use the RFN; derivatives stay OFL | `assets/licenses/googlefonts_pressstart2p.txt` (OFL text, notice, author's FONTLOG) ships; notice in the in-game credits; font unmodified (renamed file only) and only bundled |
| Pixelify Sans | `assets/fonts/pixelify_sans.ttf` (byte-identical to `PixelifySans[wght].ttf`) | Stefie Justprince; Copyright 2021 The Pixelify Sans Project Authors | https://fonts.google.com/specimen/Pixelify+Sans | SIL OFL 1.1 | as above (no RFN) | `assets/licenses/googlefonts_pixelifysans.txt` ships; notice in the in-game credits |

Godot imports the TTFs as font resources; the font data is embedded unchanged, so the exported fonts are the
"Original Version" in the OFL's sense.

### 2.3 Art (CC0 1.0 - no obligation; credited with thanks)

| Pack | Author | Source | Used for | Changes |
|---|---|---|---|---|
| Superpowers Asset Packs - Prehistoric Platformer | Pixel-boy (Sparklin Labs) | https://github.com/sparklinlabs/superpowers-asset-packs/tree/master/prehistoric-platformer (commit e8674a03) | hero, enemies, bosses, NPCs, terrain, props, backgrounds, items, effects, HUD, bitmap fonts, logo, splash, app icons | re-cut, re-packed, mirrored, recoloured, composited, integer scaling |
| Explosion Animations Pack | ansimuz (Luis Zuno) | https://ansimuz.itch.io/explosion-animations-pack | `sprites/fx/explosion.png`, `explosion_big.png` | none |
| SunnyLand | ansimuz (Luis Zuno) | https://ansimuz.itch.io/sunny-land-pixel-game-art | `sprites/fx/hit_stars.png` | none |
| Free Pixel foods | ghostpixxells | https://ghostpixxells.itch.io/pixelfood | `sprites/items/giant_bonus.png` | 2x, outline added |
| 16x16 Food | ARoachIFoundOnMyPillow | https://opengameart.org/content/16x16-food | `sprites/items/food.png` 0-39, two pick-ups | 2x, re-packed |
| 16x16 RPG Items (DB32) | ARoachIFoundOnMyPillow | https://opengameart.org/content/16x16-rpg-items-db32 | `sprites/items/treasure.png`, three pick-ups | 2x, re-packed |
| Treasure Hunters | Pixel Frog | https://pixelfrog-assets.itch.io/treasure-hunters | `ui/touch_buttons.png`, `ui/touch_pause.png` | 2x, sandstone recolour, pressed row |

### 2.4 Audio (CC0 1.0 - no obligation; credited with thanks)

| Pack | Author | Source | Files |
|---|---|---|---|
| The Essential Retro Video Game Sound Effects Collection [512 sounds] | Juhani Junkala (SubspaceAudio) | https://opengameart.org/content/512-sound-effects-8-bit-style | 44 sfx |
| 12 Music Loops | Juhani Junkala (SubspaceAudio) | https://opengameart.org/content/12-music-loops | 5 music |
| 4 Chiptunes (Adventure) | Juhani Junkala (SubspaceAudio) | https://opengameart.org/content/4-chiptunes-adventure | 4 music |
| 5 Chiptunes (Action) | Juhani Junkala (SubspaceAudio) | https://opengameart.org/content/5-chiptunes-action | 5 music (WAV -> OGG) |
| 8bit Action Jingle & Mini Loop | MintoDog | https://opengameart.org/content/8bit-action-jingle-mini-loop | 5 jingles |
| Bonus Round - 8bit / 8-Bit Victory Loop | Wolfgang_ (Ted Kerr) | https://opengameart.org/content/bonus-round-8bit, https://opengameart.org/content/8-bit-victory-loop | 2 music (one WAV -> OGG) |
| Superpowers prehistoric-platformer sound effects | Pixel-boy (Sparklin Labs) | https://github.com/sparklinlabs/superpowers-asset-packs | 6 sfx |
| 8-bit Platformer SFX | MoxieCat | https://opengameart.org/content/8-bit-platformer-sfx-0 | 1 sfx |
| NES Sounds | Baŝto | https://opengameart.org/content/nes-sounds | 2 sfx |
| Fire Crackling | AntumDeluge | https://opengameart.org/content/fire-crackling | 1 loop |
| Ice breaking/shattering | IgnasD | https://opengameart.org/content/ice-breakingshattering | 1 sfx |
| Icy Heights (wind.ogg) | Écrivain | https://opengameart.org/content/icy-heights | 1 loop |
| 40 CC0 water / splash / slime SFX | rubberduck | https://opengameart.org/content/40-cc0-water-splash-slime-sfx | 1 loop |
| 80 CC0 creature SFX | rubberduck | https://opengameart.org/content/80-cc0-creature-sfx | 1 sfx |

### 2.5 Development tools (not distributed)

Python 3 with Pillow (HPND), NumPy (BSD-3-clause), SciPy (BSD-3-clause), pyloudnorm (MIT), soundfile (BSD-3-clause),
cffi (MIT), pycparser (BSD-3-clause), used by `docs/art/pipeline/` and `tools/*.py`; the Godot editor. None of them
is redistributed: the repository holds only our scripts, the virtual environment and binaries live in the ignored
`.tools/` folder. The reference clones in `.tools/ref` (`cyxx/blues`, no licence file; `missingno7/pre2_port`) and
the asset staging area `.tools/asset_candidates` are ignored too and never pushed.

## 3. What the shipped game must display or include

| # | Requirement | Status |
|---|---|---|
| 1 | Godot MIT copyright + permission notice with every copy | text ships in `assets/licenses/godot_engine.txt`; copyright lines shown in the credits roll; the full text is readable in the game (Credits > Licences, `scripts/ui/credits.gd`) and, in the Windows release zip, as `licenses/godot_engine.txt` next to the exe (`tools/build_windows.ps1` step 6) |
| 2 | Third-party notices of the engine (BSD / Apache / FTL / ...) | `assets/licenses/godot_third_party.txt` ships; readable in the game's licence view and as a file in the Windows release zip, like #1 |
| 3 | FreeType credit ("Portions of this software are copyright (c) <year> The FreeType Project (www.freetype.org). All rights reserved.") | in `godot_engine.txt` and in the in-game "Engine" credits line |
| 4 | OFL fonts: copyright notice + licence with every copy | notices in the in-game "Fonts" credits; licence texts ship in `assets/licenses/googlefonts_*.txt`, readable in the licence view and as files in the Windows release zip |
| 5 | CC0 art and audio | nothing required; every author is credited in the roll ("Art / Music / Sound" and "Asset packs") |
| 6 | Trademarks | the game, its icon and its store name must not use "Prehistorik" or "Titus" (the shipped game does not; `CREDITS.md` only states that none of their material is used). Keep store copy to a neutral description; "Made with Godot" text is allowed, the logo needs the CC-BY credit |

## 4. Provenance audit (2026-10-05)

- **Inventory.** `assets/` holds 391 non-`.import` files: 285 PNG, 79 audio, 2 TTF and 25 licence files before
  this audit (27 now with the two Godot files). 362 game files are recorded with their source in
  `docs/art/pipeline/registry.json`; the four platform icons are built by `tools/make_app_icons.py` from `hero.png`.
- **Art, pixel-exact rebuild.** The art pipeline was re-run in a sandbox (output redirected to a scratch folder,
  inputs the staged packs): 279 of 285 PNGs came out pixel-identical to `assets/`; `sprites/bosses/brute.png` and
  `brute_enraged.png` are the documented lossless 8 x 6 -> 7 x 6 re-pack of the rebuilt sheets (all 41 frames
  identical); the four icons rebuilt by `tools/make_app_icons.py` are pixel-identical. The pipeline only opens the
  Superpowers pack and the six item / UI / FX packs above, so every shipped image derives from CC0 sources only.
- **Art, window scan.** All 8 x 8 windows of the 285 shipped PNGs were hashed against 13 815 staged images of
  81 candidate packs: shared pixels only with the packs credited above (Superpowers 108 files, ansimuz SunnyLand,
  ghostpixxells, both ARoach packs); none with the rejected packs (CDmir cavemen, Pixel Adventure 1 / 2, Kenney,
  Kyrise, 7Soul, Admurin, demching and the rest). The scan skips low-colour windows and GIF files (the tier C pack
  mor19921 is GIF only), so it is a cross-check; the pixel-exact rebuild above is the proof.
- **Audio and fonts.** All 79 audio files and both fonts are SHA-256 identical to the staged downloads (the six WAV-only
  tracks to their recorded OGG transcodes).
- **Licence evidence.** Each pack's licence was captured from its source page on 2026-10-04 (OpenGameArt licence
  field, itch.io "Asset license" info panel and description, GitHub LICENSE / README) and is quoted in its
  `assets/licenses/<pack>.txt`.
- **Specific flags reviewed.**
  - CDmir "Cavemen Sprite Sheet" (pedal-copter "inspired by UGH!"): staged only, not used (no pixels in any shipped file).
  - ansimuz packs: CC0 is stated by the itch.io info panel ("Asset license Creative Commons Zero v1.0 Universal") and
    by `public-license.pdf` inside the archives ("licensed under the Creative Commons Zero (CC0) license ... no
    restrictions on use, modification, or redistribution"); both were read. The CC0 status does not rest on the PDF alone.
  - Pixel Adventure 2 (CC-BY 4.0 on OpenGameArt, CC0 but paid on itch.io): staged only, not used. Nothing from
    Pixel Adventure 1 either. The only Pixel Frog pack used is Treasure Hunters (CC0 on its itch.io page).
  - Press Start 2P: its FONTLOG says the glyph shapes follow Namco's 1980s arcade font ("Return of Ishtar", glyph
    bitmaps extracted by "QTQ"). Typeface designs are generally not protected by copyright (and any design right on a
    1986 typeface has expired); the TrueType font itself is the authors' OFL work and is used by many commercial
    games. Low risk; replacing it with Pixelify Sans or another OFL pixel face would remove it entirely (it is used for
    key caps, option values, world-map numbers and as the fallback of the bitmap HUD font).
  - AI generation: the itch.io pages of the ansimuz, Pixel Frog and ghostpixxells packs state "No generative AI was
    used"; the OpenGameArt uploads carry no AI tag, and the Superpowers pack dates from 2016-2019. Nothing indicates
    AI-generated or ripped material.
  - No share-alike, non-commercial or attribution-required (CC-BY) asset ships.
- **Code.** `scripts/**`, `tests/**`, `tools/**`, `docs/spec/reference_sim.py` and the pipeline scripts were compared
  with the reference clones (`blues` C sources, `pre2_port` Python): exact token runs of 12 and 20 tokens, identifier /
  number runs with punctuation removed (catches C -> GDScript transliteration), comment 6-grams, and prose / code
  runs in the docs. Findings: no copied function bodies or comments. Matches are short numeric game facts (the 32-entry
  input-state table, the 9-entry jump impulse table, camera speed curves) and generic Python boilerplate
  (`os.path.dirname(...)`, `argparse` main). A few identifiers coincide with names used in `pre2_port`
  (`_jump_body`, `glider_tilt`, `idle_timer`, `score_index`, `anim_num`, ...): they name the same game concepts; the
  bodies are independent GDScript written from `docs/spec/PHYSICS.md`.
- **Docs.** `docs/spec/GAMEPLAY.md` and `PHYSICS.md` cite reference functions as `[B:file:function]` / `[P:path]`
  without reproducing their code. The original game's on-screen easter-egg text is paraphrased, not quoted, in
  `docs/spec/GAMEPLAY.md` 1.6 (repository only, not shipped). The in-game Beginner-wall line "To enter you must be an
  expert eater!" (`locale/en.po`) echoes the original's "YOU MUST BE AN EXPERT EATER" picture; a short phrase, low risk.

## 5. Maintenance rules

- **Pipeline.** `CREDITS.md`, `assets/licenses/README.md` and `godot_engine.txt` / `godot_third_party.txt` are
  maintained by hand. `docs/art/pipeline/build_manifest.py` no longer writes the first two: it fails when a pack the
  assets come from is missing from them (by source URL and licence file) or an engine file is missing.
  `build_licenses.py` writes only the per-pack files and keeps an author's FONTLOG after the OFL text (it reproduces
  the shipped files, checked 2026-10-05); `build_all.py --clean` deletes everything under `assets/` except
  `assets/licenses/`.
- **Engine upgrade.** Regenerate `godot_engine.txt` and `godot_third_party.txt` from the new engine
  (a headless script printing `Engine.get_license_text()`, `Engine.get_copyright_info()`, `Engine.get_license_info()`),
  and update the version in the `CREDITS.md` engine line.
- **Desktop downloads.** Distribute the release zip, not the bare exe: `tools/build_windows.ps1` puts `CREDITS.md`
  and every file of `assets/licenses/` into `licenses/` next to `ClubAndGrub.exe` and packs
  `build/ClubAndGrub-<version>-windows.zip` (Godot's "Complying with licenses" accepts an accompanying file; the
  in-game licence view covers platforms without one).
- **New assets.** Only CC0 or OFL-style licences with saved evidence (`LICENSE_INFO.md` + saved page); add the row to
  `CREDITS.md` (author, source, licence, changes), the licence file to `assets/licenses/`, and the registry entry.
  A CC-BY asset additionally needs its attribution line in the credits roll and the licence link.

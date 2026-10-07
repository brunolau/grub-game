# Licences of the third-party components of Club & Grub

This folder ships inside every export (include filter `assets/licenses/*` of every preset in `export_presets.cfg`).
One text file per third-party source: it names the author, the source URL, the licence and what the game uses, and
quotes the licence wording captured from the source page on the download date (2026-10-04) together with the author's
own licence file where one was shipped. Human-readable credits: `CREDITS.md` in the project root (also shipped; the
in-game credits roll is generated from it). Repository-only overview with all obligations: `docs/THIRD_PARTY.md`.

## Engine

| File | Component | Licence | Obligation |
|---|---|---|---|
| `godot_engine.txt` | Godot Engine 4.7.2-stable (official build ed1daf0bf), Godot Engine contributors, Juan Linietsky, Ariel Manzur | MIT (Expat) | copyright and permission notice in every copy; FreeType credit line |
| `godot_third_party.txt` | the 102 third-party components compiled into Godot Engine (FreeType, HarfBuzz, ICU, libogg / libvorbis, libpng, zlib, Zstandard, mbed TLS, SDL, Jolt, ...) | Expat, BSD-2/3-clause, Zlib, Apache-2.0, FTL, MPL-2.0, OFL-1.1, Unicode, ... | reproduce the notices and licence texts with binary distributions |

Both files are generated from the engine's own data (`Engine.get_license_text()`, `Engine.get_copyright_info()`,
`Engine.get_license_info()` of the Godot 4.7.2 binary in `.tools/godot`). Regenerate them when the engine version changes.

## Fonts (tier B: copyright notice and licence text must ship)

| File | Font | Author | Licence |
|---|---|---|---|
| `googlefonts_pressstart2p.txt` | Press Start 2P (`fonts/press_start_2p.ttf`) | CodeMan38 (Cody Boisclair) / The Press Start 2P Project Authors | SIL Open Font License 1.1, Reserved Font Name "Press Start 2P" (file also holds the author's FONTLOG) |
| `googlefonts_pixelifysans.txt` | Pixelify Sans (`fonts/pixelify_sans.ttf`) | Stefie Justprince / The Pixelify Sans Project Authors | SIL Open Font License 1.1 |

## Art and audio (tier A: CC0 1.0, no obligation; credited with thanks)

`cc0_1.0_legal_code.txt` is the full Creative Commons Zero 1.0 legal code that the CC0 packs refer to.

| File | Pack | Author | Licence |
|---|---|---|---|
| `superpowers_prehistoric_platformer.txt` | Superpowers Asset Packs - Prehistoric Platformer | Pixel-boy (Sparklin Labs) | CC0 1.0 |
| `superpowers_rpg_battle_system.txt` | Superpowers Asset Packs - RPG Battle System (2.0) | Pixel-boy (Sparklin Labs) | CC0 1.0 |
| `superpowers_western_fps_2d.txt` | Superpowers Asset Packs - Western FPS 2D (2.0) | Pixel-boy (Sparklin Labs) | CC0 1.0 |
| `superpowers_asset_packs_audio.txt` | Superpowers Asset Packs - prehistoric-platformer sound effects | Pixel-boy (Sparklin Labs) | CC0 1.0 |
| `ansimuz_explosion_animations_pack.txt` | Explosion Animations Pack | ansimuz (Luis Zuno) | CC0 1.0 |
| `ansimuz_sunny_land.txt` | SunnyLand | ansimuz (Luis Zuno) | CC0 1.0 |
| `ansimuz_sunny_land_series.txt` | Sunny Land 2D Pixel Art Pack, OpenGameArt release (2.0: desert eagle) | ansimuz (Luis Zuno) | CC0 1.0 |
| `ghostpixxells_free_pixel_foods.txt` | Free Pixel foods | ghostpixxells | CC0 1.0 |
| `oga_aroach_16x16_food.txt` | 16x16 Food | ARoachIFoundOnMyPillow | CC0 1.0 |
| `oga_aroach_16x16_rpg_items_db32.txt` | 16x16 RPG Items (DB32) | ARoachIFoundOnMyPillow | CC0 1.0 |
| `pixelfrog_treasure_hunters.txt` | Treasure Hunters | Pixel Frog | CC0 1.0 |
| `juhani_junkala_12_music_loops.txt` | 12 Music Loops | Juhani Junkala (SubspaceAudio) | CC0 1.0 |
| `juhani_junkala_4_chiptunes_adventure.txt` | 4 Chiptunes (Adventure) / Chiptune Adventures | Juhani Junkala (SubspaceAudio) | CC0 1.0 |
| `juhani_junkala_5_chiptunes_action.txt` | 5 Chiptunes (Action) / Retro Game Music Pack | Juhani Junkala (SubspaceAudio) | CC0 1.0 |
| `juhani_junkala_512_retro_sfx.txt` | The Essential Retro Video Game Sound Effects Collection [512 sounds] | Juhani Junkala (SubspaceAudio) | CC0 1.0 |
| `mintodog_8bit_action_jingles.txt` | 8bit Action Jingle & Mini Loop | MintoDog | CC0 1.0 |
| `wolfgang_8bit_loops.txt` | Bonus Round - 8bit / 8-Bit Victory Loop | Wolfgang_ (Ted Kerr) | CC0 1.0 |
| `moxiecat_8bit_platformer_sfx.txt` | 8-bit Platformer SFX | MoxieCat | CC0 1.0 |
| `basto_nes_sounds.txt` | NES Sounds | Baŝto | CC0 1.0 |
| `antumdeluge_fire_crackling.txt` | Fire Crackling | AntumDeluge | CC0 1.0 |
| `ignasd_ice_shatters.txt` | Ice breaking/shattering | IgnasD | CC0 1.0 |
| `misc_cc0_level_themes.txt` | Icy Heights (only `wind.ogg` is used) | Écrivain | CC0 1.0 |
| `rubberduck_40_cc0_water_splash_slime_sfx.txt` | 40 CC0 water / splash / slime SFX | rubberduck | CC0 1.0 |
| `rubberduck_80_cc0_creature_sfx.txt` | 80 CC0 creature SFX | rubberduck | CC0 1.0 |
| `pixelboy_ninja_adventure.txt` | Ninja Adventure - Asset Pack (2.0) | Pixel-boy and AAA | CC0 1.0 |
| `wolfgang_8bit_themes.txt` | Desert Theme - 8bit Chiptune Theme (2.0) | Wolfgang_ (Ted Kerr) | CC0 1.0 |
| `tallbeard_abstraction_chiptune_loops.txt` | Music Loop Bundle: Free Chiptune Loops, album 'Three Red Hearts' (2.0) | Abstraction (Benjamin Burnes, Tallbeard Studios) | CC0 1.0 |
| `spring_spring_chiptunes.txt` | The War Over A Melon Field - Themes and Jingles (2.0) | Spring Spring (Julie Damsgaard) | CC0 1.0 |
| `celestialghost8_victory.txt` | Victory (2A03 fanfare) (2.0) | celestialghost8 | CC0 1.0 |
| `spring_spring_various_sfx.txt` | Various Sound Effects (2.0) | Spring Spring | CC0 1.0 |
| `ctske_8bit_sound_effects.txt` | 8-Bit Sound Effects (2.0) | ctske (Ctskelgysth Inauaruat) | CC0 1.0 |
| `kenney_interface_sounds.txt` | Interface Sounds (2.0) | Kenney (Kenney Vleugels) | CC0 1.0 |
| `kenney_rpg_audio.txt` | RPG Audio (2.0) | Kenney (Kenney Vleugels) | CC0 1.0 |
| `kronbits_200_free_sfx.txt` | 200 Free SFX (2.0) | Kronbits | CC0 1.0 |
| `kheetor_race_start_countdown.txt` | Race Start Countdown (2.0) | kheetor | CC0 1.0 |
| `expl0it3r_applause_hall.txt` | Applause in a large hall or church (2.0) | eXpl0it3r | CC0 1.0 |
| `qubodup_well_done.txt` | Well Done (2.0) | qubodup | CC0 1.0 |
| `artisticdude_swishes.txt` | Swishes Sound Pack (2.0) | artisticdude | CC0 1.0 |
| `bmaczero_bubble_sfx.txt` | Bubble Sound Effects (2.0) | BMacZero | CC0 1.0 |
| `jcpmcdonald_skippy_fish_water.txt` | Skippy Fish Water Sound Collection (2.0) | jcpmcdonald | CC0 1.0 |

Tier A = CC0 / public domain (no obligation). Tier B = copyright notice and licence text must ship with the game
(the two SIL OFL fonts; the engine notices above are of the same kind). No tier C (custom, unclear, non-commercial,
share-alike or attribution-required art / audio licence) asset is used.

`misc_cc0_level_themes.txt` also quotes the evidence of two other tracks from the same staging folder (iamoneabe,
enprogames); neither ships in the game.

The files marked 2.0 are written by `docs/art/expansion/pipeline/build_expansion.py` in the same format, with the
licence wording captured on 2026-10-04 / 2026-10-06 (staging); the 2.0 audio packs come with the audio owner's
hand-over (`.tools/asset_candidates/expansion/_handover/audio/`).

Keep this folder in every export. The pipeline scripts `docs/art/pipeline/build_licenses.py` and `build_manifest.py`
rewrite the pack files, this README and `CREDITS.md` from the staging area: carry the engine files and the edits of
2026-10-05 over (or update the scripts) before re-running them.

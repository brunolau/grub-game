"""Driver of the 2.0 ("The Far Shore") art pipeline, art-A part. Run with the project venv from any folder:

    .tools/venv/Scripts/python.exe docs/art/expansion/pipeline/build_expansion.py [--no-previews]

Order: the spear sheet first (the palette identity check covers every hero sheet), then the hero palettes, the co-op
objects and egg, the multiplayer UI, the Book II liquids and tar floors, the Book II objects (vine, bark board, geyser,
raft, rex pen, paintings), the versus art (cookpot, spawn pads, crown, stack pictures, Golden Drumstick), the co-op
skins (see-saw skins, Chomper's saddle); phase 2: the Far Shore map page, the painting slab / mural / pictures and
unlock icons (build_far_shore.py), the versus screen and HUD art (build_versus_ui.py: portraits, heads, sundial, hit
sparks, medals, scoreboard plate, results cave wall and painted heroes), the Feast Land D / E skins
(build_feast_skins.py), the world 6-9 object skins (build_world_objects.py), phase 3's custard floor and raft rails
(build_phase3_objects.py); then the art-B hand-over rows and staged
files, the audio hand-over rows, the provenance / licence checks, the licence files of the 2.0 packs, the 2.0 section
of docs/ASSET_MANIFEST.md, and the proof sheets in docs/art/expansion/. A PNG is written only when its bytes change
(no needless Godot re-imports).

Inputs : shipped assets/** (1.0), the staged CC0 packs under .tools/asset_candidates/ (not in git),
         .tools/asset_candidates/expansion/_handover/*registry*.json (art-B's rows for its files) and staged/ (files
         art-B made for art-A's folders), _handover/audio/*.json (the audio owner's rows)
Outputs: art-A's files under assets/ (sprites/player/hero_spear.png, hero_egg.png, palettes/*, sprites/objects/*,
         sprites/items/*, sprites/fx/projectile_spear.png, hit_stars_players.png, ui/*, tiles/common/*,
         tiles/feast/terrain_*.png, tiles/feast/props/*), registry_expansion.json,
         assets/licenses/<2.0 pack>.txt, the marked 2.0 block of docs/ASSET_MANIFEST.md, docs/art/expansion/*.png.
Tests  : test_art_expansion.py (phase 1) and test_art_phase2.py next to this script
         (python -m unittest discover -s docs/art/expansion/pipeline -p "test_*.py").
CREDITS.md, docs/THIRD_PARTY.md and assets/licenses/README.md are maintained by hand (as in 1.0): this script only
checks that every pack a 2.0 file comes from is credited there, and exits with status 1 when one is missing.
"""
import glob
import json
import os
import re
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.chdir(HERE)

import xcommon                                    # noqa: E402
from xcommon import ASSETS, CAND, EXP, REGISTRY, ROOT, save_registry    # noqa: E402

HANDOVER = os.path.join(EXP, "_handover")
AUDIO_HANDOVER = os.path.join(HANDOVER, "audio")
REG1 = os.path.join(ROOT, "docs", "art", "pipeline", "registry.json")

# files art-B staged for art-A to give a home under art-A's folders: staged path -> assets path
STAGED_IMPORTS = {
    "staged/arena/frame_jungle.png": "assets/ui/arena/frame_jungle.png",
    "staged/common/tar_floor.png": "assets/tiles/common/tar_floor.png",
}
# every arena side frame art-B stages (`staged/arena/frame_<biome>.png`) lives beside frame_jungle.png
for _p in glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", ".tools",
                                 "asset_candidates", "expansion", "_handover", "staged", "arena", "frame_*.png")):
    STAGED_IMPORTS.setdefault("staged/arena/" + os.path.basename(_p), "assets/ui/arena/" + os.path.basename(_p))
# a staged file without a "staged/..." row of its own takes the row of the shipped file it copies
STAGED_ROW_FROM = {"staged/common/tar_floor.png": "assets/tiles/swamp/tar_floor.png"}

# staging folder -> (title, author, source url, licence, licence file under assets/licenses/)
PACKS = {
    "superpowers-prehistoric-platformer": (
        "Superpowers Asset Packs - Prehistoric Platformer", "Pixel-boy (Sparklin Labs)",
        "https://github.com/sparklinlabs/superpowers-asset-packs/tree/master/prehistoric-platformer", "CC0 1.0",
        "superpowers_prehistoric_platformer.txt"),
    "superpowers-western-fps-2d": (
        "Superpowers Asset Packs - Western FPS 2D", "Pixel-boy (Sparklin Labs)",
        "https://github.com/sparklinlabs/superpowers-asset-packs/tree/master/western-fps-2d", "CC0 1.0",
        "superpowers_western_fps_2d.txt"),
    "superpowers-rpg-battle-system": (
        "Superpowers Asset Packs - RPG Battle System", "Pixel-boy (Sparklin Labs)",
        "https://github.com/sparklinlabs/superpowers-asset-packs/tree/master/rpg-battle-system", "CC0 1.0",
        "superpowers_rpg_battle_system.txt"),
    "superpowers-backgrounds": (
        "Superpowers Asset Packs - Backgrounds", "Pixel-boy (Sparklin Labs)",
        "https://github.com/sparklinlabs/superpowers-asset-packs/tree/master/backgrounds", "CC0 1.0",
        "superpowers_backgrounds.txt"),
    "pixelboy-ninja-adventure-full": (
        "Ninja Adventure - Asset Pack", "Pixel-boy and AAA",
        "https://pixel-boy.itch.io/ninja-adventure-asset-pack", "CC0 1.0", "pixelboy_ninja_adventure.txt"),
    "emceeflesher-rocky-desert-landscape": (
        "Rocky desert landscape (layered, looping)", "Emcee Flesher (edit of \"Mars background pixel art\" by "
        "Quantiset)", "https://opengameart.org/content/rocky-desert-landscape-layered-looping", "CC0 1.0",
        "emceeflesher_rocky_desert_landscape.txt"),
    "antumdeluge-cc0-award-icons": (
        "CC0 Award Icons", "AntumDeluge (OpenClipart Library, 7Soul1)", "https://opengameart.org/content/cc0-award-icons",
        "CC0 1.0", "antumdeluge_cc0_award_icons.txt"),
    "ansimuz-sunny-land-series": (
        "Sunny Land 2D Pixel Art Pack", "ansimuz (Luis Zuno)",
        "https://opengameart.org/content/sunny-land-2d-pixel-art-pack", "CC0 1.0", "ansimuz_sunny_land_series.txt"),
    "ansimuz_sunny-land": (                       # the 1.0 itch.io release (sprites/fx/hit_stars.png)
        "SunnyLand", "ansimuz (Luis Zuno)", "https://ansimuz.itch.io/sunny-land-pixel-game-art", "CC0 1.0",
        "ansimuz_sunny_land.txt"),
}
# packs whose licence file 1.0 wrote (docs/art/pipeline/build_licenses.py): kept as they are
PACKS_1_0 = {"superpowers-prehistoric-platformer", "ansimuz_sunny-land"}

# how a source string may name a staged pack other than by its folder name
PACK_ALIASES = {"sunny-land (ansimuz)": "ansimuz-sunny-land-series"}

GAPS = [
    "See-saw: the wood plank (lengths 3-6) and its mushroom-cap and ice-floe skins (same layout); other biomes use "
    "the wood plank.",
    "Drawn by the pipeline in the anchor palette (no pack has them): the pulley wheel and rope, the revive egg's oval, "
    "the petroglyph figures of the x2 tablet and the cave-painting glyphs, the vine coil, the geyser rim and jet, the "
    "raft's log ends, the cookpot's bowl and mouth, the spawn slab and the crown; everything else is recoloured / "
    "composited pack art.",
    "`hero_palettes.json` is reference data (shader contract, colour names, UI colours, pattern list). If "
    "`hero_palette.gd` (player-A) reads it at runtime, check that the export carries it (an `include_filter` entry "
    "by core-A); otherwise keep the few values it needs as constants. The LUT / atlas PNGs are ordinary textures.",
    "Arena thumbnails (`ui/arena/thumb_<arena id>.png`, 120 x 66) are not drawn: the arenas are DA's level files "
    "(still changing in phase 3) and ui-A's arena select draws a mini map of each file in its biome's colours.",
    "The arena side frames (`ui/arena/frame_<biome>.png`, ten with phase 3's canyon and sky) exist for screens wider "
    "than 20 cells (DESIGN E.5), but no script draws them yet (asked of world-B, wf9_art_to_world-B.txt).",
    "The versus corner panels are one arena row (32 px) tall: the 2x Ninja Adventure portrait (E.9) does not fit, so "
    "they get `ui/portrait_heads.png` (28 px heads painted from the 1.0 HUD head's silhouette); the Ninja portrait "
    "(`ui/portraits.png`) is for the lobby, the results and the join panel.",
    "Feast Land D / E use the shipped feast parallax (`backgrounds/feast`, outside art-A's and art-B's globs) with "
    "their own terrains and props (17.14).",
    "Belt icons crop the handle end of the longer weapons (club, spear) at the cell edge; the heads stay whole.",
    "The egg's hatch frames show the hero curled in the 1.0 spots (the pattern step is off for non-hero sheets).",
    "The cave-painting item (`sprites/items/painting.png`) shows one of six glyphs (index % 6) on its fragment; the "
    "painting's own picture is `ui/paintings.png` cell `index`, and its piece of the mural is the rect of "
    "`ui/mural.png` given in 17.13.",
    "Chomper's saddle: `sprites/objects/rex_saddle.png` is an overlay on the shipped rex sheets (same grid); the "
    "riders themselves are the hero sheets drawn by code.",
    "Phase 3: the railed raft's fence (`sprites/objects/raft_rails.png`) is an overlay that objects-B's raft.gd must "
    "draw over raft.png (closed / open towards the bank that stopped it, G45); until it does, a railed raft looks "
    "like a plain one. Feast Land E's custard ':' floor is `tiles/feast/syrup_floor.png` (world-A's biome-first "
    "lookup); every other feast + syrup level - the Sky Picnic arena - draws it too.",
]


# shipped 1.0 files that 2.0 code draws for a new purpose (manifest 17.15; objects-A wf8 #1)
REUSE_1_0 = [
    ("sprites/objects/chest.png", "`objects/container skin=chest` (objects-A): cell 0 closed, cells 1-3 opening once "
                                  "at 10 fps; the Mimic's disguise (sprites/enemies/mimic.png `idle`, art-B, 17.6) is "
                                  "built from the same cells, so a Mimic looks exactly like the chest (DESIGN A.5)"),
    ("sprites/items/giant_bonus.png", "Book II's `items/trophy` - the Great Roast of 9-3 Chieftains' Pyre - draws "
                                      "cell 0"),
    ("sprites/objects/platform_wood.png", "the layout copied by the 2.0 skins platform_driftwood.png and "
                                          "platform_cloud.png (17.3)"),
    ("ui/hud_lives_icon.png", "the head of the versus corner-panel portraits ui/portrait_heads.png (17.11)"),
    ("backgrounds/cave/layer0_wall.png", "recoloured into the versus results backdrop ui/cave_wall.png (17.11)"),
]


# ---------------------------------------------------------------------------------------------------- provenance
def _reg1():
    with open(REG1, encoding="utf-8") as f:
        return json.load(f)


def origin_packs(entry, reg1):
    """the staged packs a 2.0 file derives from: pack names in its source, plus the packs of every shipped 1.0 file
    it names (resolved through the 1.0 registry)"""
    src = entry.get("source", "")
    found = set(p for p in PACKS if p in src) | set(p for a, p in PACK_ALIASES.items() if a in src)
    for rel in reg1:
        short = rel[len("assets/"):]
        if short in src:
            s1 = reg1[rel].get("source", "")
            found |= set(p for p in PACKS if p in s1)
            if not any(p in s1 for p in PACKS):
                found.add("?1.0:" + short)
    if "drawn by the pipeline" in src or "petroglyph" in src or "hand-picked" in src or src.endswith(".py"):
        found.add("own")
    return sorted(found)


# ---------------------------------------------------------------------------------------------------- hand-over
def merge_handover(reg1):
    """art-B's rows: every *registry*.json in the hand-over folder; each file must exist; size re-measured"""
    problems = []
    rows = 0
    for path in sorted(glob.glob(os.path.join(HANDOVER, "*registry*.json"))):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for rel, e in data.items():
            if not rel.startswith("assets/"):
                continue
            fp = os.path.join(ROOT, *rel.split("/"))
            if not os.path.exists(fp):
                problems.append("hand-over row without a file: %s (%s)" % (rel, os.path.basename(path)))
                continue
            e = dict(e)
            if fp.endswith(".png"):
                with Image.open(fp) as im:
                    if list(im.size) != list(e.get("size", im.size)):
                        problems.append("%s: hand-over size %s, file %s (measured size used)" % (rel, e.get("size"),
                                                                                                list(im.size)))
                    e["size"] = list(im.size)
                    if max(im.size) > 2048:
                        problems.append("%s is %dx%d: over the 2048 px limit" % ((rel,) + im.size))
            e["owner"] = "art-B"
            e["section"] = "worlds"
            e.setdefault("license", "CC0 1.0")
            e["handover"] = os.path.basename(path)
            REGISTRY[rel] = e
            rows += 1
    return rows, problems


def import_staged():
    """files art-B staged for art-A's folders (STAGED_IMPORTS): copied byte for byte, with art-B's row from the
    hand-over registry that names the staged path"""
    import shutil
    rows = {}
    for path in sorted(glob.glob(os.path.join(HANDOVER, "*registry*.json"))):
        with open(path, encoding="utf-8") as f:
            for k, v in json.load(f).items():
                if k.startswith("staged/"):
                    rows[k] = (v, os.path.basename(path))
    problems = []
    for staged, rel in sorted(STAGED_IMPORTS.items()):
        src = os.path.join(HANDOVER, *staged.split("/"))
        if not os.path.exists(src):
            problems.append("staged file missing: %s" % staged)
            continue
        dst = os.path.join(ROOT, *rel.split("/"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(src, "rb") as f:
            data = f.read()
        if not os.path.exists(dst) or open(dst, "rb").read() != data:      # unchanged: keep the mtime
            shutil.copyfile(src, dst)
        row, reg = rows.get(staged, ({}, "-"))
        if not row and staged in STAGED_ROW_FROM and STAGED_ROW_FROM[staged] in REGISTRY:
            src_row = REGISTRY[STAGED_ROW_FROM[staged]]
            row, reg = dict(src_row), src_row.get("handover", "-")
            row["source"] = "byte copy of %s (art-B); %s" % (STAGED_ROW_FROM[staged][len("assets/"):],
                                                            src_row.get("source", ""))
            row["note"] = ("the ':' tar floor for `liquid = tar` on every biome (the layout of tiles/canyon/mud_floor.png: "
                           "0 top_left, 1 top, 2 top_right, 3 fill; drawn surface at art row 6, collision at row 12); "
                           "identical to the Tar Fen's own " + STAGED_ROW_FROM[staged][len("assets/"):])
        e = dict(row)
        with Image.open(dst) as im:
            e["size"] = list(im.size)
        e["note"] = (re.sub(r"^STAGED for [^:]+: ", "", e.get("note", "")) +
                     " (staged by art-B as `%s`, given this home by art-A)" % staged)
        e["owner"] = "art-B"
        e["section"] = "worlds"
        e.setdefault("license", "CC0 1.0")
        e["handover"] = reg
        REGISTRY[rel] = e
    return problems


def _sha256(path):
    import hashlib
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def merge_audio_handover():
    """the audio owner's rows (_handover/audio/*.json): every file must exist with the hand-over's sha256; returns
    (rows, problems, packs) where packs = the packs the rows name (title, author, url, licence file, folder)"""
    problems, packs, rows = [], {}, 0
    for path in sorted(glob.glob(os.path.join(AUDIO_HANDOVER, "*.json"))):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        packs.update(data.get("_meta", {}).get("packs", {}))
        for rel, e in data.items():
            if not rel.startswith("assets/"):
                continue
            fp = os.path.join(ROOT, *rel.split("/"))
            if not os.path.exists(fp):
                problems.append("audio hand-over row without a file: %s (%s)" % (rel, os.path.basename(path)))
                continue
            sha = _sha256(fp)
            if e.get("sha256") and e["sha256"] != sha:
                problems.append("%s: sha256 differs from the hand-over (%s)" % (rel, os.path.basename(path)))
            src = e.get("sources", [])
            row = {
                "owner": "audio", "section": "audio", "kind": e.get("kind"), "names": e.get("names", []),
                "role": e.get("role", ""), "bus": e.get("bus"), "loop": bool(e.get("loop")),
                "loop_region_frames": e.get("loop_region_frames"), "format": e.get("format"), "rate": e.get("rate"),
                "channels": e.get("channels"), "seconds": e.get("seconds"), "bytes": os.path.getsize(fp),
                "sha256": sha, "lufs_integrated": e.get("lufs_integrated"), "lufs_short": e.get("lufs_short"),
                "true_peak_dbtp": e.get("true_peak_dbtp"), "volume_db": e.get("volume_db"),
                "played_at": e.get("played_at"), "target": e.get("target"),
                "source": "; ".join("%s: %s" % (s["pack"].split("/")[-1], s["path"].split("/", 2)[-1]) for s in src),
                "audio_packs": sorted(set(s["pack"] for s in src)),
                "edits": e.get("edits", "-"), "license": e.get("licence", "CC0 1.0"),
                "handover": os.path.basename(path),
            }
            for s in src:
                if s["pack"] not in packs:
                    problems.append("%s: source pack %s has no _meta.packs entry" % (rel, s["pack"]))
            REGISTRY[rel] = row
            rows += 1
    return rows, problems, packs


def write_audio_licence(key, p, files):
    """assets/licenses/<pack>.txt for an audio pack new in 2.0 (the 1.0 files stay as they are)"""
    dst = os.path.join(ASSETS, "licenses", p["licence_file"])
    if p.get("in_1_0"):
        return dst
    folder = os.path.join(CAND, *p["folder"].split("/"))
    title = p["title"]
    parts = ["%s\n%s\n" % (title, "=" * len(title)),
             "Author: %s\nSource: %s\nLicence: %s (tier A)\nUsed in Club & Grub for: 2.0 (The Far Shore): %s. Per-file "
             "sources and edits: docs/ASSET_MANIFEST.md section 17\nStaging folder: .tools/asset_candidates/%s\n"
             % (p["author"], p["url"], p.get("license", "CC0 1.0"),
                ", ".join(sorted(f[len("assets/"):] for f in files)), p["folder"])]
    pages = p.get("pages", [])
    if len(pages) > 1 or p.get("note"):                 # a pack of several pages, or a licence choice to record
        parts[-1] += "".join("Page: %s - %s\n" % (pg["title"], pg["url"]) for pg in pages)
        if p.get("note"):
            parts[-1] += "Note: %s\n" % p["note"]
    info = os.path.join(folder, "LICENSE_INFO.md")
    if os.path.exists(info):
        with open(info, encoding="utf-8") as f:
            parts.append("---- Licence evidence recorded when the pack was downloaded ----\n\n" + evidence(f.read()))
    for own in ("License.txt", "LICENSE.txt", "license.txt"):
        fp = os.path.join(folder, own)
        if os.path.exists(fp):
            with open(fp, encoding="utf-8", errors="replace") as f:
                parts.append("---- %s (shipped by the author) ----\n\n%s\n" % (own, f.read().strip()))
            break
    parts.append("---- Licence ----\n\nCC0 1.0 Universal: the full legal code ships as cc0_1.0_legal_code.txt in this "
                 "folder.\n")
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(parts))
    return dst


def check_audio_credits(packs, uses):
    with open(os.path.join(ROOT, "CREDITS.md"), encoding="utf-8") as f:
        credits = f.read()
    with open(os.path.join(ASSETS, "licenses", "README.md"), encoding="utf-8") as f:
        lic_readme = f.read()
    with open(os.path.join(ROOT, "docs", "THIRD_PARTY.md"), encoding="utf-8") as f:
        third = f.read()
    missing = []
    for key in sorted(uses):
        p = packs.get(key)
        if p is None:
            missing.append("unknown audio pack %s" % key)
            continue
        if p.get("license", "CC0 1.0") != "CC0 1.0":
            missing.append("audio pack %s is %s, not CC0 1.0" % (key, p.get("license")))
        if p["url"] not in credits:
            missing.append("CREDITS.md lacks %s (%s)" % (p["title"], p["url"]))
        if p["url"] not in third:
            missing.append("docs/THIRD_PARTY.md lacks %s (%s)" % (p["title"], p["url"]))
        if p["licence_file"] not in lic_readme:
            missing.append("assets/licenses/README.md lacks %s" % p["licence_file"])
        if not os.path.exists(os.path.join(ASSETS, "licenses", p["licence_file"])):
            missing.append("assets/licenses/%s is missing" % p["licence_file"])
    return missing


def handover_notes():
    """the explanatory parts of art-B's hand-over documents (*HANDOVER*.md): the biome palette notes, paragraphs
    on body boxes / hit zones / drawing order, and the decisions and flags"""
    return _doc_notes(sorted(glob.glob(os.path.join(HANDOVER, "*HANDOVER*.md"))),
                      lambda sec: ("palette notes" in sec) or sec.startswith("decisions"),
                      ("Body boxes are", "Tusker hit zones", "Draw at y = 0", "Both atlases keep"))


def audio_notes():
    """the explanatory parts of the audio owner's batch documents (_handover/audio/AUDIO_BATCH*.md): the music
    budget and the decisions and flags of every batch (the staging folder is not versioned, the manifest is)"""
    return _doc_notes(sorted(glob.glob(os.path.join(AUDIO_HANDOVER, "AUDIO_BATCH*.md"))),
                      lambda sec: sec.startswith(("music budget", "decisions")), ())


def _doc_notes(paths, keep_section, keep_paragraphs):
    out = []
    for path in paths:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
        title = lines[0].lstrip("# ").strip() if lines else os.path.basename(path)
        sec = ""
        picked = []
        for ln in lines:
            if ln.startswith("## "):
                sec = ln[3:].lower()
                continue
            keep_sec = keep_section(sec)
            keep_par = bool(keep_paragraphs) and ln.startswith(keep_paragraphs)
            if (keep_sec and ln.strip()) or keep_par:
                picked.append(ln)
        if picked:
            out.append("*%s*" % title)
            out.append("")
            # blank line between blocks of different kinds and between paragraphs; tables and lists stay whole
            prev = None
            for ln in picked:
                kind = "table" if ln.startswith("|") else "list" if ln.startswith(("- ", "  ")) else "para"
                if prev is not None and (kind != prev or kind == "para"):
                    out.append("")
                out.append(ln)
                prev = kind
            out.append("")
    return out


def unregistered_new_files():
    """2.0 files under assets/ that no registry row describes (git: untracked), e.g. art-B files without a hand-over row"""
    import subprocess
    try:
        out = subprocess.check_output(["git", "-C", ROOT, "ls-files", "--others", "--exclude-standard", "assets"],
                                      text=True)
    except (OSError, subprocess.CalledProcessError):
        return []
    return [p for p in out.splitlines() if not p.endswith((".import", ".uid")) and p not in REGISTRY
            and not p.startswith("assets/licenses/")]


# ---------------------------------------------------------------------------------------------------- licences
def evidence(md):
    """the header and the licence / evidence sections of a scout LICENSE_INFO.md (1.0 build_licenses.py rule)"""
    keep = []
    on = True
    for ln in md.splitlines():
        if ln.startswith("## "):
            t = ln[3:].lower()
            on = t.startswith(("exact", "evidence", "licen", "notes / flags", "flags"))
        if on:
            keep.append(ln)
    return "\n".join(keep).strip() + "\n"


def staging_folder(pack):
    for d in glob.glob(os.path.join(CAND, "*", pack)):
        if os.path.isdir(d):
            return d
    return None


def write_licence(pack, use):
    title, author, url, lic, fname = PACKS[pack]
    dst = os.path.join(ASSETS, "licenses", fname)
    if pack in PACKS_1_0:
        return dst                                   # the 1.0 file already covers it
    folder = staging_folder(pack)
    parts = ["%s\n%s\n" % (title, "=" * len(title)),
             "Author: %s\nSource: %s\nLicence: %s (tier A)\nUsed in Club & Grub for: %s\nStaging folder: "
             ".tools/asset_candidates/%s\n" % (author, url, lic, use,
                                              os.path.relpath(folder, CAND).replace(os.sep, "/") if folder else pack)]
    if folder and os.path.exists(os.path.join(folder, "LICENSE_INFO.md")):
        with open(os.path.join(folder, "LICENSE_INFO.md"), encoding="utf-8") as f:
            parts.append("---- Licence evidence recorded when the pack was downloaded ----\n\n" + evidence(f.read()))
    # the author's own licence note, from the staging folder or art-B's hand-over evidence folder of the pack
    own_dirs = [folder] if folder else []
    own_dirs += [d for d in glob.glob(os.path.join(HANDOVER, "licenses", "*"))
                 if os.path.basename(d) in (fname[:-4], pack.replace("-", "_"))
                 or (pack == "ansimuz-sunny-land-series" and os.path.basename(d) == "ansimuz_sunny_land")]
    for d in own_dirs:
        found = False
        for own in ("public-license.txt", "License.txt", "LICENSE.txt"):
            for fp in glob.glob(os.path.join(d, "**", own), recursive=True)[:1]:
                with open(fp, encoding="utf-8", errors="replace") as f:
                    txt = f.read().strip()
                note = "shipped by the author"
                if "Music" in txt:
                    note += "; the bundled music is not used by Club & Grub"
                parts.append("---- %s (%s) ----\n\n%s\n" % (own, note, txt))
                found = True
                break
            if found:
                break
        if found:
            break
    parts.append("---- Licence ----\n\nCC0 1.0 Universal: the full legal code ships as cc0_1.0_legal_code.txt in this "
                 "folder.\n")
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(parts))
    return dst


def pack_uses(reg1):
    """pack -> the 2.0 files that derive from it; a 2.0 file built from another 2.0 file (drum_cap.png from
    drum.png, an arena frame from art-B's props) inherits that file's packs (resolved to a fixed point)"""
    rows = {rel: e for rel, e in REGISTRY.items() if rel.startswith("assets/") and e.get("owner") != "audio"}
    for e in rows.values():
        e["origin_packs"] = origin_packs(e, reg1)
    names = {rel: rel[len("assets/"):] for rel in rows}
    changed = True
    while changed:
        changed = False
        for rel, e in rows.items():
            src = e.get("source", "")
            got = set(e["origin_packs"])
            for other, short in names.items():
                if other != rel and short in src:
                    got |= set(rows[other]["origin_packs"])
            if got != set(e["origin_packs"]):
                e["origin_packs"] = sorted(got)
                changed = True
    uses = {}
    for rel, e in rows.items():
        for p in e["origin_packs"]:
            uses.setdefault(p, []).append(rel)
    return uses


def check_credits(uses):
    with open(os.path.join(ROOT, "CREDITS.md"), encoding="utf-8") as f:
        credits = f.read()
    with open(os.path.join(ASSETS, "licenses", "README.md"), encoding="utf-8") as f:
        lic_readme = f.read()
    with open(os.path.join(ROOT, "docs", "THIRD_PARTY.md"), encoding="utf-8") as f:
        third = f.read()
    missing = []
    for p, files in sorted(uses.items()):
        if p == "own":
            continue
        if p not in PACKS:
            missing.append("unknown source %s for %s" % (p, ", ".join(files)))
            continue
        title, author, url, lic, fname = PACKS[p]
        if url not in credits:
            missing.append("CREDITS.md lacks %s (%s)" % (title, url))
        if fname not in lic_readme:
            missing.append("assets/licenses/README.md lacks %s" % fname)
        if url not in third:
            missing.append("docs/THIRD_PARTY.md lacks %s (%s)" % (title, url))
        if not os.path.exists(os.path.join(ASSETS, "licenses", fname)):
            missing.append("assets/licenses/%s is missing" % fname)
    return missing


# ---------------------------------------------------------------------------------------------------- main
def main(previews=True):
    REGISTRY.clear()                                  # rebuilt from scratch every run (no stale rows)
    import build_hero_spear
    import build_hero_palettes
    import build_coop_objects
    import build_mp_ui
    import build_liquids
    import build_book2_objects
    import build_versus
    import build_coop_skins
    build_hero_spear.build()
    build_hero_palettes.build(write_previews=previews)
    build_coop_objects.build(build_hero_palettes.KEY)
    build_mp_ui.build(build_hero_palettes.PALETTES)
    build_liquids.build()
    build_book2_objects.build()
    build_versus.build()
    build_coop_skins.build()
    import build_far_shore
    import build_versus_ui
    import build_feast_skins
    import build_world_objects
    import build_phase3_objects
    build_far_shore.build()
    build_versus_ui.build()
    build_feast_skins.build()
    build_world_objects.build()
    build_phase3_objects.build()
    for k, e in REGISTRY.items():
        e.setdefault("owner", "art-A")
        if "/palettes/" in k:
            e.setdefault("section", "palettes")
    reg1 = _reg1()
    rows, problems = merge_handover(reg1)
    problems += import_staged()
    a_rows, a_problems, audio_packs = merge_audio_handover()
    problems += a_problems
    audio_uses = {}
    for k, e in REGISTRY.items():
        if e.get("owner") == "audio":
            for p in e["audio_packs"]:
                audio_uses.setdefault(p, []).append(k)
    for p, files in sorted(audio_uses.items()):
        if p in audio_packs:
            write_audio_licence(p, audio_packs[p], files)
    uses = pack_uses(reg1)
    for p, files in sorted(uses.items()):
        if p in PACKS:
            folders = {}
            for f in files:
                folders.setdefault(os.path.dirname(f)[len("assets/"):], []).append(
                    os.path.splitext(os.path.basename(f))[0])
            write_licence(p, "2.0 (The Far Shore): " + "; ".join(
                "%s/ %s" % (d, ", ".join(sorted(n)[:14]) + (" + %d more" % (len(n) - 14) if len(n) > 14 else ""))
                for d, n in sorted(folders.items())) + ". Per-file sources and edits: docs/ASSET_MANIFEST.md section 17")
    REGISTRY["_meta"] = {
        "packs": {p: {"title": PACKS[p][0], "author": PACKS[p][1], "license": PACKS[p][3],
                      "file": "assets/licenses/" + PACKS[p][4], "count": len(f)}
                  for p, f in sorted(uses.items()) if p in PACKS},
        "audio_packs": {p: {"title": audio_packs[p]["title"], "author": audio_packs[p]["author"],
                            "license": audio_packs[p].get("license", "CC0 1.0"),
                            "file": "assets/licenses/" + audio_packs[p]["licence_file"], "count": len(f),
                            "new": not audio_packs[p].get("in_1_0")}
                        for p, f in sorted(audio_uses.items()) if p in audio_packs},
        "gaps": GAPS,
        "reuse_1_0": REUSE_1_0,
        "handover_notes": handover_notes(),
        "audio_notes": audio_notes(),
    }
    # every PNG written by art-A: <= 2048 px a side
    for k, e in REGISTRY.items():
        if k.startswith("assets/") and "size" in e and max(e["size"]) > 2048:
            problems.append("%s is over 2048 px" % k)
    save_registry()
    import manifest_expansion
    manifest_expansion.replace_in(os.path.join(ROOT, "docs", "ASSET_MANIFEST.md"), manifest_expansion.section_lines())
    if previews:
        import build_previews
        import build_previews_b2
        import build_previews_p2
        build_previews.build()
        build_previews_b2.build()
        build_previews_p2.build()
        import build_previews_p3
        build_previews_p3.build()
    missing = check_credits(uses) + check_audio_credits(audio_packs, audio_uses)
    loose = unregistered_new_files()
    n_a = sum(1 for k, e in REGISTRY.items() if k.startswith("assets/") and e.get("owner") == "art-A")
    print("art-A files: %d; art-B hand-over rows: %d; audio hand-over rows: %d; packs: %s; audio packs: %d"
          % (n_a, rows, a_rows, ", ".join(sorted(uses)), len(audio_uses)))
    for p in problems:
        print("HAND-OVER:", p)
    for f in loose:
        print("NO ROW:", f)
    for m in missing:
        print("CREDITS CHECK:", m)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(previews="--no-previews" not in sys.argv))

"""Driver of the 2.0 ("The Far Shore") art pipeline, art-A part. Run with the project venv from any folder:

    .tools/venv/Scripts/python.exe docs/art/expansion/pipeline/build_expansion.py [--no-previews]

Order: the spear sheet first (the palette identity check covers every hero sheet), then the hero palettes, the co-op
objects and egg, the multiplayer UI, the art-B hand-over rows, the provenance / licence checks, the licence files of the
2.0 packs, the 2.0 section of docs/ASSET_MANIFEST.md, and the proof sheets in docs/art/expansion/.

Inputs : shipped assets/** (1.0), the staged CC0 packs under .tools/asset_candidates/ (not in git),
         .tools/asset_candidates/expansion/_handover/*registry*.json (art-B's rows for its files)
Outputs: art-A's files under assets/ (sprites/player/hero_spear.png, hero_egg.png, palettes/*, sprites/objects/*,
         sprites/items/weapon_spear.png, sprites/fx/projectile_spear.png, ui/*), registry_expansion.json,
         assets/licenses/<2.0 pack>.txt, the marked 2.0 block of docs/ASSET_MANIFEST.md, docs/art/expansion/*.png.
CREDITS.md, docs/THIRD_PARTY.md and assets/licenses/README.md are maintained by hand (as in 1.0): this script only
checks that every pack a 2.0 file comes from is credited there, and exits with status 1 when one is missing.
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.chdir(HERE)

import xcommon                                    # noqa: E402
from xcommon import ASSETS, CAND, EXP, REGISTRY, ROOT, save_registry    # noqa: E402

HANDOVER = os.path.join(EXP, "_handover")
REG1 = os.path.join(ROOT, "docs", "art", "pipeline", "registry.json")

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
}

# how a source string may name a staged pack other than by its folder name
PACK_ALIASES = {"sunny-land (ansimuz)": "ansimuz-sunny-land-series"}

GAPS = [
    "See-saw: only the wood plank (lengths 3-6). The mushroom see-saw of 6-2 and the ice floes of Floe Rink are "
    "phase-2 skins (recolours of `seesaw_plank.png`).",
    "The pulley wheel and rope, the revive egg's oval and the two petroglyph figures of the x2 tablet are drawn by the "
    "pipeline in the anchor palette (no pack has them); everything else is recoloured / composited pack art.",
    "`hero_palettes.json` is reference data (shader contract, colour names, UI colours, pattern list). If "
    "`hero_palette.gd` (player-A) reads it at runtime, check that the export carries it (an `include_filter` entry "
    "by core-A); otherwise keep the few values it needs as constants. The LUT / atlas PNGs are ordinary textures.",
    "No emote bubbles, versus corner portraits, crown, sundial or hit sparks per player yet (E.9; phase 2, P2.11).",
    "Belt icons crop the handle end of the longer weapons (club, spear) at the cell edge; the heads stay whole.",
    "The egg's hatch frames show the hero curled in the 1.0 spots (the pattern step is off for non-hero sheets).",
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
    if "drawn by the pipeline" in src or "petroglyph" in src:
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


def handover_notes():
    """the explanatory parts of art-B's hand-over documents (*HANDOVER*.md): the biome palette notes, paragraphs
    on body boxes / hit zones / drawing order, and the decisions and flags"""
    out = []
    for path in sorted(glob.glob(os.path.join(HANDOVER, "*HANDOVER*.md"))):
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
        title = lines[0].lstrip("# ").strip() if lines else os.path.basename(path)
        sec = ""
        picked = []
        for ln in lines:
            if ln.startswith("## "):
                sec = ln[3:].lower()
                continue
            keep_sec = ("palette notes" in sec) or sec.startswith("decisions")
            keep_par = ln.startswith(("Body boxes are", "Tusker hit zones", "Draw at y = 0", "Both atlases keep"))
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
    if pack == "superpowers-prehistoric-platformer":
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
    uses = {}
    for rel, e in REGISTRY.items():
        if not rel.startswith("assets/"):
            continue
        e["origin_packs"] = origin_packs(e, reg1)
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
    build_hero_spear.build()
    build_hero_palettes.build(write_previews=previews)
    build_coop_objects.build(build_hero_palettes.KEY)
    build_mp_ui.build(build_hero_palettes.PALETTES)
    for k, e in REGISTRY.items():
        e.setdefault("owner", "art-A")
        if "/palettes/" in k:
            e.setdefault("section", "palettes")
    reg1 = _reg1()
    rows, problems = merge_handover(reg1)
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
        "gaps": GAPS,
        "handover_notes": handover_notes(),
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
        build_previews.build()
    missing = check_credits(uses)
    loose = unregistered_new_files()
    n_a = sum(1 for k, e in REGISTRY.items() if k.startswith("assets/") and e.get("owner") == "art-A")
    print("art-A files: %d; art-B hand-over rows: %d; packs: %s" % (n_a, rows, ", ".join(sorted(uses))))
    for p in problems:
        print("HAND-OVER:", p)
    for f in loose:
        print("NO ROW:", f)
    for m in missing:
        print("CREDITS CHECK:", m)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(previews="--no-previews" not in sys.argv))

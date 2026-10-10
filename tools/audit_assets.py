#!/usr/bin/env python3
"""Asset and licence audit of Club & Grub (docs/expansion/PLAN.md P4.4). The build runs it; any gap fails it.

    python tools/audit_assets.py                  the audit (standard library only): exit 1 on any gap
    python tools/audit_assets.py --write-ledger   rewrite section 18 of docs/ASSET_MANIFEST.md from the registries
    python tools/audit_assets.py --audio          measure every track, loop and effect; exit 1 when a gate fails
                                                  (needs numpy, soundfile, pyloudnorm, scipy: the project venv)
    python tools/audit_assets.py --sheets DIR     contact sheets and style numbers of the 2.0 art (needs Pillow)
    python tools/audit_assets.py --shipped PATH   a built licence folder (build/windows/licenses) or a release zip:
                                                  exit 1 unless it holds CREDITS.md and every file of
                                                  assets/licenses/, byte for byte, and nothing else

    --root DIR    audit another project root (the tests build small ones)
    --no-git      do not compare the "Since" column with the tag v1.0.0
    --markdown    --audio: print the tables as Markdown (for the hand-over text)

What the audit proves (each line is a check; the code after it is the finding it reports):

  files      every file under assets/ (the .import files aside) has exactly one row in the file ledger, section 18
             of docs/ASSET_MANIFEST.md, and every row names a file that exists            ledger-missing / -orphan
  rows       every row names its source pack, author, licence, licence text, the source inside the pack and what
             was changed                                                                  row-incomplete
  licences   the licence is CC0 1.0 or the SIL Open Font License 1.1. Two other kinds of row exist and are fenced
             in: "licence text" (only under assets/licenses/) and "own work" (art or data drawn by a script of this
             repository that the row names; never a sound, a track or a font)             licence
  evidence   the licence text a row names ships in assets/licenses/, and its header (title, Author:, Licence:)
             says what the row says                                                       licence-file
             no pack licence text ships that no file uses                                 licence-orphan
  credits    every source pack is in CREDITS.md (source URL, a table row with the author and the licence),
             in docs/THIRD_PARTY.md (source URL) and in assets/licenses/README.md         credits / third-party /
                                                                                          licence-index
  roll       the in-game credits roll - scripts/ui/credits.gd builds it from CREDITS.md; parse_credits() below is
             the same parser - names every pack and every author under Art, Music, Sound or Fonts      credits-roll
  since      with git and the tag v1.0.0: every file added after the tag says "2.0", every other one "1.0", and no
             1.0 art, sound or font changed since                                          since / changed-1.0
  stray      no sound, track or font outside assets/, no image outside assets/, docs/ and installer/   stray-media
  imports    every .png / .ogg / .wav / .ttf has its .import file and no .import file is left behind  import-pair
  formats    only .png, .ogg (Vorbis), .wav and .ttf (and the licence texts and one .json), each with the content
             its name promises, no texture wider or higher than 2048 px                   format / texture-size
  table      every file scripts/core/audio_table.gd names exists, every sound file is named by it      audio-table
  fresh      section 18 is what --write-ledger writes from the registries of the art and audio pipelines
             (docs/art/pipeline/registry.json, credits.json, docs/art/expansion/pipeline/registry_expansion.json),
             so a hand-edited ledger cannot hide a file                                    ledger-stale

The audio gates of --audio are documented at AUDIO_GATES; tools/test_audit_assets.py tests every check above.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import struct
import subprocess
import sys

# No __pycache__ file under tools/: .tools/gd.sh takes any new file there that is not a known text type as a reason to
# re-import the project, and an import holds every Godot run of every terminal back.
sys.dont_write_bytecode = True

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MANIFEST = "docs/ASSET_MANIFEST.md"
CREDITS = "CREDITS.md"
THIRD_PARTY = "docs/THIRD_PARTY.md"
LICENCE_INDEX = "assets/licenses/README.md"
AUDIO_TABLE = "scripts/core/audio_table.gd"
REGISTRY_1 = "docs/art/pipeline/registry.json"
CREDITS_JSON = "docs/art/pipeline/credits.json"
REGISTRY_2 = "docs/art/expansion/pipeline/registry_expansion.json"
RELEASE_TAG = "v1.0.0"

LEDGER_BEGIN = "<!-- audit-ledger: generated by tools/audit_assets.py --write-ledger - begin -->"
LEDGER_END = "<!-- audit-ledger: end -->"
LEDGER_HEAD = ["File", "Since", "Pack", "Author", "Licence", "Licence text", "Source", "What was changed"]

CC0 = "CC0 1.0"
OFL = "SIL Open Font License 1.1"
ALLOWED_LICENCES = (CC0, OFL)
LICENCE_TEXT = "licence text"
OWN_WORK = "own work"
OWN_PACK = "Club & Grub (own work)"
OWN_AUTHOR = "Club & Grub Team"
OWN_LICENCE_TEXT = "`LICENSE` (project root)"

AUDIO_EXT = {".ogg", ".wav", ".mp3", ".flac", ".opus", ".aac", ".m4a", ".wma", ".aiff", ".mid", ".midi", ".mod",
             ".xm", ".it", ".s3m"}
FONT_EXT = {".ttf", ".otf", ".ttc", ".woff", ".woff2", ".pfb", ".pfa", ".fon"}
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg", ".tga", ".ico", ".icns", ".psd", ".xcf",
             ".aseprite", ".ase", ".exr", ".hdr", ".tif", ".tiff", ".dds", ".ktx"}
IMPORTED_EXT = {".png", ".ogg", ".wav", ".ttf"}
MAX_TEXTURE = 2048  # low-end Android GPUs (docs/ASSET_MANIFEST.md 14, docs/PORTING.md)

# Folders the stray-media walk does not enter: version control, Godot's cache, the unversioned tool folder (engine,
# venv, asset staging area, reference clones) and build output. They are the ignored folders of .gitignore.
SKIP_DIRS = {".git", ".godot", ".import", ".tools", "build", ".claude", ".vscode", ".idea", ".mono", "__pycache__"}
# Images outside assets/ may only be renders of the game's own assets.
DERIVED_IMAGE_DIRS = {
    "docs/": "documentation: screenshots, mock-ups and pipeline previews rendered from assets/",
    "installer/": "installer art built by tools/make_installer_art.py from assets/",
}

# Licence files that are not the evidence of one asset pack.
GENERAL_LICENCE_FILES = {
    "README.md": ("Club & Grub (index of this folder)", OWN_AUTHOR, "written for Club & Grub",
                  "index of the licence texts in this folder; maintained by hand"),
    "cc0_1.0_legal_code.txt": ("CC0 1.0 Universal legal code", "Creative Commons Corporation",
                               "https://creativecommons.org/publicdomain/zero/1.0/legalcode",
                               "none (the legal code the CC0 packs refer to, verbatim)"),
    "godot_engine.txt": ("Godot Engine 4.7.2", "Godot Engine contributors; Juan Linietsky, Ariel Manzur",
                         "https://godotengine.org/license (the engine's own Engine.get_license_text())",
                         "none (verbatim, under a four-line header)"),
    "godot_third_party.txt": ("Godot Engine 4.7.2 - third-party components", "the authors named in the file",
                              "the engine's own Engine.get_copyright_info() and Engine.get_license_info()",
                              "none (verbatim, under a short header)"),
}

# Files under assets/ that no pipeline registry knows: [licence files, source, what was changed].
EXTRA_FILES = {
    "icon_1024.png": (["superpowers_prehistoric_platformer.txt"],
                      "`sprites/player/hero.png` frame 48 (victory), built by `tools/make_app_icons.py`",
                      "the hero at 10x (nearest neighbour) on a sky, sun and grass tile drawn by the script in the "
                      "colours of ui/title_background.png; 1024 x 1024, opaque (iOS)"),
    "icon_android_foreground.png": (["superpowers_prehistoric_platformer.txt"],
                                    "`sprites/player/hero.png` frame 48 (victory), built by "
                                    "`tools/make_app_icons.py`",
                                    "the hero at 3x (nearest neighbour) inside the adaptive-icon safe zone, 432 x "
                                    "432 on transparency"),
    "icon_android_background.png": (["superpowers_prehistoric_platformer.txt"],
                                    "drawn by `tools/make_app_icons.py` in the colours of ui/title_background.png "
                                    "(the anchor pack's sky and jungle greens)",
                                    "sky, sun and grass tile at 3x, 432 x 432, opaque"),
    "icon_android_monochrome.png": (["superpowers_prehistoric_platformer.txt"],
                                    "`sprites/player/hero.png` frame 48 (victory), built by "
                                    "`tools/make_app_icons.py`",
                                    "the hero's silhouette as a white cut-out at 3x, 432 x 432 (Android 13 themed "
                                    "icons)"),
}

# 2.0 files that are entirely Club & Grub's own drawing: the script that draws them (longest prefix wins).
OWN_SCRIPTS = {
    "sprites/player/palettes/": "docs/art/expansion/pipeline/build_hero_palettes.py",
    "tiles/feast/props/": "docs/art/expansion/pipeline/build_feast_skins.py",
    "ui/sundial_rush.png": "docs/art/expansion/pipeline/build_versus_ui.py",
}
# 1.0 registry rows whose source text names no pack key.
PACKS_1_0_OVERRIDE = {"assets/splash.png": ["superpowers-prehistoric-platformer"]}
# Changes made to a 1.0 file after its registry row was written (docs/ASSET_MANIFEST.md 14, docs/THIRD_PARTY.md 4).
LATER_CHANGES = {
    "sprites/bosses/brute.png": "then re-packed without loss from 8 x 6 cells (2304 px wide) to 7 x 6 cells (2016 x "
                                "1056) to stay under the 2048 px texture limit; frames 0-40 unchanged",
    "sprites/bosses/brute_enraged.png": "then re-packed without loss from 8 x 6 cells (2304 px wide) to 7 x 6 cells "
                                        "(2016 x 1056) to stay under the 2048 px texture limit; frames 0-40 unchanged",
}

PLACEHOLDERS = {"", "-", "?", "??", "tbd", "todo", "unknown", "n/a", "none yet", "(none)"}


class Finding:
    def __init__(self, code: str, where: str, text: str):
        self.code, self.where, self.text = code, where, text

    def __str__(self) -> str:
        return "%-15s %s: %s" % (self.code, self.where, self.text)


class Pack:
    """One third-party source, as the header of its shipped licence text states it."""

    def __init__(self, file: str, title: str, author: str, licence: str, urls: list[str]):
        self.file, self.title, self.author, self.licence, self.urls = file, title, author, licence, urls


# ---------------------------------------------------------------------------------------------------------- reading
def read_text(root: str, rel: str) -> str:
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        return ""
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def asset_files(root: str) -> tuple[list[str], list[str]]:
    """(files, import files) under assets/, relative to assets/, with forward slashes."""
    files, imports = [], []
    base = os.path.join(root, "assets")
    for folder, _dirs, names in os.walk(base):
        for name in names:
            rel = os.path.relpath(os.path.join(folder, name), base).replace(os.sep, "/")
            (imports if name.endswith(".import") else files).append(rel)
    return sorted(files), sorted(imports)


def urls_of(text: str) -> list[str]:
    return [u.rstrip(".") for u in re.findall(r"https?://[^\s,;)\"'<>]+", text)]


def read_pack(root: str, name: str) -> Pack | None:
    """The header of assets/licenses/<name>: title line, 'Author:', 'Source:', 'Licence:'."""
    text = read_text(root, "assets/licenses/" + name)
    if not text:
        return None
    lines = text.split("\n")[:40]
    fields, pages = {}, []
    for line in lines[1:]:
        if line.startswith("----"):
            break  # the evidence quoted below the header is not the header
        match = re.match(r"^(Author|Source|Licence|Page): *(.*)$", line.strip())
        if match and match.group(1) == "Page":
            pages += urls_of(match.group(2))
        elif match and match.group(1) not in fields:
            fields[match.group(1)] = match.group(2).strip()
    if not {"Author", "Source", "Licence"} <= set(fields):
        return None
    licence = re.sub(r"\s*\(tier [A-C]\)\s*$", "", fields["Licence"])
    urls = list(dict.fromkeys(urls_of(fields["Source"]) + pages))
    return Pack(name, lines[0].strip(), fields["Author"], licence, urls)


def read_packs(root: str) -> dict[str, Pack]:
    packs = {}
    folder = os.path.join(root, "assets", "licenses")
    if os.path.isdir(folder):
        for name in sorted(os.listdir(folder)):
            if name.endswith(".txt") and name not in GENERAL_LICENCE_FILES:
                pack = read_pack(root, name)
                if pack is not None:
                    packs[name] = pack
    return packs


def split_row(line: str) -> list[str]:
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [cell.strip() for cell in line.split("|")]


def ledger_block(text: str) -> str | None:
    if LEDGER_BEGIN not in text or LEDGER_END not in text:
        return None
    return text[text.index(LEDGER_BEGIN):text.index(LEDGER_END) + len(LEDGER_END)]


def read_ledger(root: str) -> tuple[list[dict], list[Finding]]:
    """The rows of section 18 as dictionaries keyed by lower-case column names ("file" without its back-ticks)."""
    findings = []
    block = ledger_block(read_text(root, MANIFEST))
    if block is None:
        return [], [Finding("ledger-missing", MANIFEST, "no file ledger (the block between '%s' and '%s')"
                            % (LEDGER_BEGIN, LEDGER_END))]
    rows = []
    for line in block.split("\n"):
        if not line.startswith("|") or line.startswith("|---"):
            continue
        cells = split_row(line)
        if cells == LEDGER_HEAD:
            continue
        if len(cells) != len(LEDGER_HEAD):
            findings.append(Finding("row-incomplete", MANIFEST, "ledger row with %d cells instead of %d: %s"
                                    % (len(cells), len(LEDGER_HEAD), line[:80])))
            continue
        row = dict(zip(["file", "since", "pack", "author", "licence", "licence_text", "source", "changes"], cells))
        row["file"] = row["file"].strip("`")
        rows.append(row)
    return rows, findings


def split_list(cell: str) -> list[str]:
    return [part.strip() for part in cell.split(";") if part.strip()]


def licence_files_of(row: dict) -> list[str]:
    return [m for m in re.findall(r"`licenses/([^`]+)`", row["licence_text"])]


def kind_of(rel: str) -> str:
    ext = os.path.splitext(rel)[1].lower()
    if rel.startswith("licenses/"):
        return "licence"
    if rel.startswith("audio/music/"):
        return "music"
    if ext in AUDIO_EXT:
        return "sound"
    if ext in FONT_EXT:
        return "font"
    if ext in IMAGE_EXT:
        return "art"
    return "data"


# -------------------------------------------------------------------------------------- the credits roll's parser
def parse_credits(text: str) -> dict:
    """What scripts/ui/credits.gd parse_credits() reads out of CREDITS.md: the pack table of the first section
    whose heading starts with "Art", the bullet lines of "Required ...", and the suggested in-game wording of
    "Courtesy ..." split into roles (Art / Music / Sound) and names."""
    section = ""
    packs, fonts, wording = [], [], ""
    for raw in text.split("\n"):
        line = raw.strip()
        if line.startswith("## "):
            section = line[3:].lower()
            continue
        if line.startswith("# ") or not line:
            continue
        if section.startswith("art") and line.startswith("|") and not line.startswith("|---"):
            cells = split_row(line)
            if len(cells) >= 4 and cells[0] != "Pack":
                packs.append({"pack": cells[0], "author": cells[1], "source": cells[2], "licence": cells[3]})
        elif section.startswith("required") and line.startswith("- "):
            fonts.append(line[2:])
        elif section.startswith("courtesy") and line.startswith("Suggested in-game wording:"):
            parts = line.split('"')
            wording = parts[1] if len(parts) > 1 else ""
    roles = {}
    for match in re.finditer(r"([A-Z][a-z]+): (.*?)\.(?= [A-Z][a-z]+: |$)", wording):
        roles[match.group(1)] = [name.strip() for name in match.group(2).split(", ")]
    return {"packs": packs, "fonts": fonts, "roles": roles}


def primary_name(author: str) -> str:
    """'Juhani Junkala (SubspaceAudio)' -> 'Juhani Junkala'; 'CodeMan38 / The ... Authors' -> 'CodeMan38'."""
    return re.split(r" \(| / ", author, maxsplit=1)[0].strip()


def names_author(name: str, primary: str) -> bool:
    """True when the credited `name` is the author `primary` ('Pixel-boy and AAA' is not 'Pixel-boy')."""
    if not name.startswith(primary):
        return False
    rest = name[len(primary):]
    return rest == "" or (rest[0] in " (/," and not rest.startswith(" and "))


# ------------------------------------------------------------------------------------------------------- checks
def check_files(files: list[str], rows: list[dict]) -> list[Finding]:
    findings = []
    seen = {}
    for row in rows:
        seen[row["file"]] = seen.get(row["file"], 0) + 1
    present = set(files)
    for rel in files:
        if rel not in seen:
            findings.append(Finding("ledger-missing", "assets/" + rel, "no row in the file ledger (%s section 18)"
                                    % MANIFEST))
    for rel, count in sorted(seen.items()):
        if rel not in present:
            findings.append(Finding("ledger-orphan", "assets/" + rel, "the file ledger has a row, the file does "
                                    "not exist"))
        if count > 1:
            findings.append(Finding("ledger-orphan", "assets/" + rel, "%d rows in the file ledger" % count))
    return findings


def check_rows(root: str, rows: list[dict], packs: dict[str, Pack]) -> list[Finding]:
    findings = []
    for row in rows:
        rel = row["file"]
        where = "assets/" + rel
        kind = kind_of(rel)
        for column in ("since", "pack", "author", "licence", "licence_text", "source", "changes"):
            if row[column].strip().lower() in PLACEHOLDERS:
                findings.append(Finding("row-incomplete", where, "the ledger row has no '%s'" % column))
        if row["since"] not in ("1.0", "2.0"):
            findings.append(Finding("row-incomplete", where, "'Since' is '%s', not 1.0 or 2.0" % row["since"]))
        licence = row["licence"]
        if kind == "licence":
            if licence != LICENCE_TEXT:
                findings.append(Finding("licence", where, "a file of assets/licenses/ is a '%s' row, not '%s'"
                                        % (LICENCE_TEXT, licence)))
            continue
        if licence == LICENCE_TEXT:
            findings.append(Finding("licence", where, "'%s' rows exist only under assets/licenses/" % LICENCE_TEXT))
            continue
        if licence == OWN_WORK:
            if kind in ("music", "sound", "font"):
                findings.append(Finding("licence", where, "a %s cannot be '%s': name its source" % (kind, OWN_WORK)))
            scripts = [s for s in re.findall(r"`([^`]+\.py)`", row["source"])
                       if os.path.isfile(os.path.join(root, s))]
            if not scripts:
                findings.append(Finding("licence", where, "an '%s' row must name the script of this repository "
                                        "that draws the file (`path/to/script.py` in the Source cell)" % OWN_WORK))
            if row["pack"] != OWN_PACK or row["author"] != OWN_AUTHOR:
                findings.append(Finding("licence", where, "an '%s' row names '%s' / '%s'"
                                        % (OWN_WORK, OWN_PACK, OWN_AUTHOR)))
            continue
        for one in split_list(licence):
            if one not in ALLOWED_LICENCES:
                findings.append(Finding("licence", where, "licence '%s' is neither %s nor %s"
                                        % (one, CC0, OFL)))
        named = licence_files_of(row)
        if not named:
            findings.append(Finding("licence-file", where, "the row names no licence text (`licenses/<pack>.txt`)"))
            continue
        titles, authors, licences = [], [], []
        for name in named:
            pack = packs.get(name)
            if pack is None:
                findings.append(Finding("licence-file", where, "licence text assets/licenses/%s is missing or has "
                                        "no 'Author:' / 'Source:' / 'Licence:' header" % name))
                continue
            titles.append(pack.title)
            authors.append(pack.author)
            licences.append(pack.licence)
            if pack.licence not in ALLOWED_LICENCES:
                findings.append(Finding("licence", where, "assets/licenses/%s states the licence '%s'"
                                        % (name, pack.licence)))
        if len(titles) != len(named):
            continue
        if sorted(set(split_list(row["pack"]))) != sorted(set(titles)):
            findings.append(Finding("licence-file", where, "the row's pack '%s' is not what its licence text(s) "
                                    "say: '%s'" % (row["pack"], "; ".join(titles))))
        if sorted(set(split_list(row["author"]))) != sorted(set(authors)):
            findings.append(Finding("licence-file", where, "the row's author '%s' is not what its licence text(s) "
                                    "say: '%s'" % (row["author"], "; ".join(sorted(set(authors))))))
        if sorted(set(split_list(licence))) != sorted(set(licences)):
            findings.append(Finding("licence-file", where, "the row's licence '%s' is not what its licence text(s) "
                                    "say: '%s'" % (licence, "; ".join(sorted(set(licences))))))
    return findings


def packs_in_use(rows: list[dict]) -> dict[str, set[str]]:
    """licence file -> the kinds of file (art / music / sound / font / data) that come from that pack."""
    used = {}
    for row in rows:
        kind = kind_of(row["file"])
        if kind == "licence" or row["licence"] == OWN_WORK:
            continue
        for name in licence_files_of(row):
            used.setdefault(name, set()).add(kind)
    return used


def check_licence_folder(files: list[str], rows: list[dict]) -> list[Finding]:
    findings = []
    used = packs_in_use(rows)
    for rel in files:
        if not rel.startswith("licenses/"):
            continue
        name = rel[len("licenses/"):]
        if name in GENERAL_LICENCE_FILES or name in used:
            continue
        findings.append(Finding("licence-orphan", "assets/" + rel, "no file of the ledger comes from this pack: "
                                "the licence text ships for nothing (or a row forgot its pack)"))
    return findings


def check_licence_index(root: str, files: list[str]) -> list[Finding]:
    """Every file the tables of assets/licenses/README.md list exists (the other direction is check_credits)."""
    findings = []
    present = set(files)
    for line in read_text(root, LICENCE_INDEX).split("\n"):
        match = re.match(r"^\| *`([^`/]+\.(?:txt|md))` *\|", line)
        if match and "licenses/" + match.group(1) not in present:
            findings.append(Finding("licence-index", LICENCE_INDEX, "lists `%s`, which is not in assets/licenses/"
                                    % match.group(1)))
    return findings


ROLE_OF_KIND = {"art": "Art", "data": "Art", "music": "Music", "sound": "Sound"}


def check_credits(root: str, rows: list[dict], packs: dict[str, Pack]) -> list[Finding]:
    findings = []
    credits_text = read_text(root, CREDITS)
    third_text = read_text(root, THIRD_PARTY)
    index_text = read_text(root, LICENCE_INDEX)
    for rel, text in ((CREDITS, credits_text), (THIRD_PARTY, third_text), (LICENCE_INDEX, index_text)):
        if not text:
            findings.append(Finding("credits", rel, "the file is missing or empty"))
    roll = parse_credits(credits_text)
    for name, kinds in sorted(packs_in_use(rows).items()):
        pack = packs.get(name)
        if pack is None:
            continue  # check_rows reports the missing licence text
        where = "pack '%s' (assets/licenses/%s)" % (pack.title, name)
        if not pack.urls:
            findings.append(Finding("licence-file", where, "the licence text names no source URL"))
        for url in pack.urls:
            if url not in credits_text:
                findings.append(Finding("credits", where, "%s does not name the source %s" % (CREDITS, url)))
            if url not in third_text:
                findings.append(Finding("third-party", where, "%s does not name the source %s"
                                        % (THIRD_PARTY, url)))
        if "`%s`" % name not in index_text:
            findings.append(Finding("licence-index", where, "%s does not list `%s`" % (LICENCE_INDEX, name)))
        primary = primary_name(pack.author)
        table = [r for r in roll["packs"] if pack.urls and any(url in r["source"] for url in pack.urls)]
        if not table:
            findings.append(Finding("credits-roll", where, "no row of the pack table of %s names its source URL, so "
                                    "the in-game credits do not list the pack" % CREDITS))
        for entry in table:
            if primary not in entry["author"]:
                findings.append(Finding("credits", where, "the row '%s' of %s credits '%s', the licence text says "
                                        "'%s'" % (entry["pack"], CREDITS, entry["author"], pack.author)))
            if entry["licence"] != pack.licence:
                findings.append(Finding("credits", where, "the row '%s' of %s says '%s', the licence text says '%s'"
                                        % (entry["pack"], CREDITS, entry["licence"], pack.licence)))
        for kind in sorted(kinds):
            if kind == "font":
                if not any(pack.title in line and primary in line for line in roll["fonts"]):
                    findings.append(Finding("credits-roll", where, "no 'Required attribution' line of %s names the "
                                            "font and '%s', so the in-game credits do not show its notice"
                                            % (CREDITS, primary)))
                continue
            role = ROLE_OF_KIND[kind]
            if not any(names_author(credited, primary) for credited in roll["roles"].get(role, [])):
                findings.append(Finding("credits-roll", where, "the in-game wording of %s does not name '%s' "
                                        "under '%s:'" % (CREDITS, primary, role)))
    return findings


def git(root: str, *args: str) -> str | None:
    try:
        run = subprocess.run(["git", "-C", root] + list(args), capture_output=True, text=True, encoding="utf-8",
                             errors="replace", timeout=120)
    except (OSError, subprocess.SubprocessError):
        return None
    return run.stdout if run.returncode == 0 else None


def release_files(root: str) -> set[str] | None:
    """The files of assets/ at the 1.0.0 release (relative to assets/), or None without git or without the tag.

    None also when `root` is not the top of the repository git finds: a copy of the project unpacked inside another
    repository (a source archive in a work folder, the clean tree of the 2.0.0 release check under build/) would be
    measured against that repository's tag - its listing of "<copy>/assets" is empty, and every 1.0 file read as 2.0.
    """
    top = git(root, "rev-parse", "--show-toplevel")
    try:
        if top is None or not os.path.samefile(top.strip(), root):
            return None
    except OSError:
        return None
    if git(root, "rev-parse", "-q", "--verify", "refs/tags/" + RELEASE_TAG) is None:
        return None
    listing = git(root, "-c", "core.quotepath=off", "ls-tree", "-r", "--name-only", RELEASE_TAG, "--", "assets")
    if listing is None:
        return None
    return {line[len("assets/"):] for line in listing.splitlines() if line and not line.endswith(".import")}


def check_since(root: str, files: list[str], rows: list[dict]) -> tuple[list[Finding], str]:
    """Compare the ledger's 'Since' column with the tag v1.0.0. Returns (findings, a note for the summary)."""
    released = release_files(root)
    if released is None:
        return [], "not compared with %s (no git repository of its own or no such tag here)" % RELEASE_TAG
    findings = []
    since = {row["file"]: row["since"] for row in rows}
    present = set(files)
    for rel in files:
        expected = "1.0" if rel in released else "2.0"
        if rel in since and since[rel] != expected:
            findings.append(Finding("since", "assets/" + rel, "the ledger says %s, the tag %s says %s"
                                    % (since[rel], RELEASE_TAG, expected)))
    for rel in sorted(released - present):
        findings.append(Finding("changed-1.0", "assets/" + rel, "shipped in 1.0.0, no longer in assets/"))
    changed = git(root, "-c", "core.quotepath=off", "diff", "--name-only", RELEASE_TAG, "--", "assets") or ""
    for line in changed.splitlines():
        rel = line[len("assets/"):]
        if rel in released and rel in present and kind_of(rel) != "licence":
            findings.append(Finding("changed-1.0", line, "a 1.0 file differs from the %s release" % RELEASE_TAG))
    added = len(present - released)
    return findings, "%d files since %s, %d from 1.0" % (added, RELEASE_TAG, len(present & released))


def check_stray_media(root: str) -> list[Finding]:
    findings = []
    for folder, dirs, names in os.walk(root):
        rel_folder = os.path.relpath(folder, root).replace(os.sep, "/")
        if rel_folder == ".":
            rel_folder = ""
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS and d != "assets"]
        else:
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in names:
            rel = (rel_folder + "/" + name) if rel_folder else name
            ext = os.path.splitext(name)[1].lower()
            if ext in AUDIO_EXT or ext in FONT_EXT:
                findings.append(Finding("stray-media", rel, "a sound, track or font outside assets/ (no ledger row "
                                        "can cover it)"))
            elif ext in IMAGE_EXT and not any(rel.startswith(prefix) for prefix in DERIVED_IMAGE_DIRS):
                findings.append(Finding("stray-media", rel, "an image outside assets/, docs/ and installer/"))
    return findings


def check_imports(files: list[str], imports: list[str]) -> list[Finding]:
    findings = []
    present = set(files)
    imported = {name[:-len(".import")] for name in imports}
    for rel in sorted(imported - present):
        findings.append(Finding("import-pair", "assets/" + rel + ".import", "the .import file of a file that does "
                                "not exist"))
    for rel in files:
        if os.path.splitext(rel)[1].lower() in IMPORTED_EXT and rel not in imported:
            findings.append(Finding("import-pair", "assets/" + rel, "no .import file: the file was never imported "
                                    "(run 'bash .tools/gd.sh import' and commit it)"))
    return findings


def png_size(path: str) -> tuple[int, int] | None:
    with open(path, "rb") as handle:
        head = handle.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


def check_formats(root: str, files: list[str]) -> list[Finding]:
    findings = []
    for rel in files:
        path = os.path.join(root, "assets", rel)
        where = "assets/" + rel
        ext = os.path.splitext(rel)[1].lower()
        with open(path, "rb") as handle:
            head = handle.read(64)
        if rel.startswith("licenses/"):
            if ext not in (".txt", ".md"):
                findings.append(Finding("format", where, "assets/licenses/ holds .txt and .md only"))
        elif ext == ".png":
            size = png_size(path)
            if size is None:
                findings.append(Finding("format", where, "not a PNG file"))
            elif max(size) > MAX_TEXTURE:
                findings.append(Finding("texture-size", where, "%d x %d: above the %d px texture limit"
                                        % (size[0], size[1], MAX_TEXTURE)))
        elif ext == ".ogg":
            if head[:4] != b"OggS" or b"\x01vorbis" not in head:
                findings.append(Finding("format", where, "not an Ogg Vorbis file"))
        elif ext == ".wav":
            if head[:4] != b"RIFF" or head[8:12] != b"WAVE":
                findings.append(Finding("format", where, "not a RIFF WAVE file"))
        elif ext == ".ttf":
            if head[:4] not in (b"\x00\x01\x00\x00", b"true"):
                findings.append(Finding("format", where, "not a TrueType font"))
        elif ext == ".json":
            try:
                with open(path, encoding="utf-8") as handle:
                    json.load(handle)
            except (OSError, ValueError):
                findings.append(Finding("format", where, "not valid JSON"))
        else:
            findings.append(Finding("format", where, "'%s' is not a format the game ships (.png, .ogg, .wav, .ttf)"
                                    % ext))
    return findings


def read_audio_table(root: str) -> dict[str, dict]:
    """file name -> {"dir": "music" | "sfx", "db": volume_db, "loop": bool, "names": [Sfx constants]} from
    scripts/core/audio_table.gd (a file named by several rows keeps the first row's values)."""
    text = read_text(root, AUDIO_TABLE)
    table = {}
    for match in re.finditer(r"Sfx\.([A-Z0-9_]+): *\{([^{}]*)\}", text, re.S):
        name, body = match.group(1), match.group(2)
        loop = re.search(r'"loop": *true', body) is not None
        single = re.search(r'"file": *"([^"]+)", *"db": *(-?[0-9.]+)', body)
        if single:
            entry = table.setdefault(single.group(1), {"dir": "music", "db": float(single.group(2)), "loop": loop,
                                                       "names": []})
            entry["names"].append(name)
            continue
        many = re.search(r'"files":\s*\[([^\]]*)\],\s*"db":\s*\[([^\]]*)\]', body, re.S)
        if many:
            names = re.findall(r'"([^"]+)"', many.group(1))
            values = [float(v) for v in re.findall(r"-?[0-9.]+", many.group(2))]
            for index, file_name in enumerate(names):
                entry = table.setdefault(file_name, {"dir": "sfx", "db": values[index] if index < len(values)
                                                     else 0.0, "loop": loop, "names": []})
                entry["names"].append(name)
    return table


def check_audio_table(root: str, files: list[str]) -> list[Finding]:
    if not os.path.isfile(os.path.join(root, AUDIO_TABLE)):
        return []
    findings = []
    table = read_audio_table(root)
    present = set(files)
    named = set()
    for file_name, entry in sorted(table.items()):
        rel = "audio/%s/%s" % (entry["dir"], file_name)
        named.add(rel)
        if rel not in present:
            findings.append(Finding("audio-table", AUDIO_TABLE, "Sfx.%s names %s, which does not exist"
                                    % (entry["names"][0], "assets/" + rel)))
    for rel in files:
        if rel.startswith("audio/") and rel not in named:
            findings.append(Finding("audio-table", "assets/" + rel, "no row of %s plays this file" % AUDIO_TABLE))
    return findings


def check_ledger_fresh(root: str) -> list[Finding]:
    if not all(os.path.isfile(os.path.join(root, rel)) for rel in (REGISTRY_1, CREDITS_JSON, REGISTRY_2)):
        return []
    current = ledger_block(read_text(root, MANIFEST))
    wanted, problems = build_ledger(root)
    findings = [Finding("ledger-stale", "assets/" + rel, text) for rel, text in problems]
    if current is not None and current != wanted:
        have = {line for line in current.split("\n")}
        want = [line for line in wanted.split("\n") if line not in have]
        first = want[0][:100] if want else "(only removed lines)"
        findings.append(Finding("ledger-stale", MANIFEST, "section 18 is not what the registries give (%d line(s) "
                                "differ, first: %s): run tools/audit_assets.py --write-ledger" % (len(want), first)))
    return findings


def audit(root: str, use_git: bool = True) -> tuple[list[Finding], list[str]]:
    """Run every check. Returns (findings, summary lines)."""
    files, imports = asset_files(root)
    rows, findings = read_ledger(root)
    packs = read_packs(root)
    findings += check_files(files, rows)
    findings += check_rows(root, rows, packs)
    findings += check_licence_folder(files, rows)
    findings += check_licence_index(root, files)
    findings += check_credits(root, rows, packs)
    note = "not compared with %s (--no-git)" % RELEASE_TAG
    if use_git:
        since_findings, note = check_since(root, files, rows)
        findings += since_findings
    findings += check_stray_media(root)
    findings += check_imports(files, imports)
    findings += check_formats(root, files)
    findings += check_audio_table(root, files)
    findings += check_ledger_fresh(root)
    licences = {}
    for row in rows:
        licences[row["licence"]] = licences.get(row["licence"], 0) + 1
    summary = [
        "%d files under assets/ (%d .import files aside), %d ledger rows" % (len(files), len(imports), len(rows)),
        "licences: " + ", ".join("%s %d" % (k, v) for k, v in sorted(licences.items())),
        "%d source packs in use, %d licence texts shipped" % (
            len(packs_in_use(rows)), sum(1 for f in files if f.startswith("licenses/"))),
        note,
    ]
    return findings, summary


def check_shipped(root: str, target: str) -> tuple[list[Finding], int]:
    """The licence texts beside a built game: `target` is the licenses folder next to the exe or the release zip
    (its entries under licenses/). It must hold CREDITS.md and every file of assets/licenses/, byte for byte, and
    nothing else. Returns (findings, number of files that must ship)."""
    import zipfile

    def read(path: str) -> bytes:
        with open(path, "rb") as handle:
            return handle.read()

    wanted = {"CREDITS.md": read(os.path.join(root, CREDITS))}
    folder = os.path.join(root, "assets", "licenses")
    for name in sorted(os.listdir(folder)):
        if os.path.isfile(os.path.join(folder, name)):
            wanted[name] = read(os.path.join(folder, name))
    have = {}
    if os.path.isdir(target):
        for name in os.listdir(target):
            if os.path.isfile(os.path.join(target, name)):
                have[name] = read(os.path.join(target, name))
    elif os.path.isfile(target) and zipfile.is_zipfile(target):
        with zipfile.ZipFile(target) as archive:
            for entry in archive.namelist():
                if entry.startswith("licenses/") and not entry.endswith("/"):
                    have[entry[len("licenses/"):]] = archive.read(entry)
    else:
        return [Finding("shipped", target, "neither a folder nor a zip file")], len(wanted)
    findings = []
    for name in sorted(wanted):
        if name not in have:
            findings.append(Finding("shipped", target, "%s is missing" % name))
        elif have[name] != wanted[name]:
            findings.append(Finding("shipped", target, "%s differs from the project's file" % name))
    for name in sorted(set(have) - set(wanted)):
        findings.append(Finding("shipped", target, "%s is not a licence text of the project" % name))
    return findings, len(wanted)


# ---------------------------------------------------------------------------------------- writing the file ledger
def cell(text: str) -> str:
    return " ".join(str(text).replace("|", "/").split())


def pack_cells(names: list[str], packs: dict[str, Pack]) -> list[str]:
    """[Pack, Author, Licence, Licence text] of a row whose file comes from the licence files `names`."""
    known = [packs[n] for n in names if n in packs]
    unique = lambda values: "; ".join(dict.fromkeys(values))
    return [unique(p.title for p in known), unique(p.author for p in known), unique(p.licence for p in known),
            "; ".join("`licenses/%s`" % n for n in names)]


def own_script(rel: str) -> str:
    best = ""
    for prefix in OWN_SCRIPTS:
        if rel.startswith(prefix) and len(prefix) > len(best):
            best = prefix
    return OWN_SCRIPTS.get(best, "")


def build_ledger(root: str) -> tuple[str, list[tuple[str, str]]]:
    """Section 18 as text, from the registries. Also returns [(file, why)] for every file under assets/ that no
    registry knows: such a file gets no row, so the audit reports it."""
    with open(os.path.join(root, REGISTRY_1), encoding="utf-8") as handle:
        reg1 = json.load(handle)
    with open(os.path.join(root, CREDITS_JSON), encoding="utf-8") as handle:
        credits = json.load(handle)
    with open(os.path.join(root, REGISTRY_2), encoding="utf-8") as handle:
        reg2 = json.load(handle)
    packs = read_packs(root)
    file_of_key = {c["pack"]: os.path.basename(c["file"]) for c in credits}
    first_release = set(file_of_key.values()) | set(GENERAL_LICENCE_FILES)
    meta = reg2.get("_meta", {})
    for group in ("packs", "audio_packs"):
        for key, value in meta.get(group, {}).items():
            file_of_key.setdefault(key, os.path.basename(value["file"]))
    files, _imports = asset_files(root)
    rows, problems = [], []
    for rel in files:
        key = "assets/" + rel
        if rel.startswith("licenses/"):
            name = rel[len("licenses/"):]
            since = "1.0" if name in first_release else "2.0"
            if name in GENERAL_LICENCE_FILES:
                title, author, source, changes = GENERAL_LICENCE_FILES[name]
            elif name in packs:
                pack = packs[name]
                title, author = pack.title, pack.author
                source = " and ".join(pack.urls) or "-"
                changes = ("written by the asset pipeline: the licence wording and evidence recorded when the pack "
                           "was downloaded" + (", then the font's OFL text" if pack.licence == OFL else ""))
            else:
                problems.append((rel, "a licence text without an 'Author:' / 'Source:' / 'Licence:' header"))
                continue
            rows.append([rel, since, title, author, LICENCE_TEXT, "`%s`" % rel, source, changes])
            continue
        if rel in EXTRA_FILES:
            names, source, changes = EXTRA_FILES[rel]
            rows.append([rel, "1.0"] + pack_cells(names, packs) + [source, changes])
            continue
        if key in reg1:
            entry = reg1[key]
            source = entry.get("source", "")
            if entry.get("kind") in ("music", "sfx"):
                keys = [source.split("/", 1)[0]]
                changes = ("WAV transcoded to OGG Vorbis; renamed" if "/ogg_converted/" in source
                           else "none (byte-identical copy, renamed)")
            else:
                dump = json.dumps(entry, ensure_ascii=False)
                keys = PACKS_1_0_OVERRIDE.get(key) or [c["pack"] for c in credits if c["pack"] in dump]
                changes = "; ".join(part for part in (entry.get("edits", ""), LATER_CHANGES.get(rel, "")) if part)
                froms = sorted({e["from"] for e in entry.get("entries", []) if isinstance(e, dict) and "from" in e})
                if froms and not any(c["pack"] in source for c in credits):
                    source = "; ".join(froms)
            names = [file_of_key[k] for k in keys if k in file_of_key]
            if not names or len(names) != len(keys):
                problems.append((rel, "registry.json names no known pack in '%s'" % source[:60]))
                continue
            rows.append([rel, "1.0"] + pack_cells(names, packs) + [source, changes])
            continue
        if key in reg2:
            entry = reg2[key]
            origin = list(entry.get("origin_packs", [])) + list(entry.get("audio_packs", []))
            keys = [k for k in origin if k != "own"]
            source = entry.get("source", "")
            changes = entry.get("edits", "")
            if not keys and "own" in origin:
                script = own_script(rel)
                if not script:
                    problems.append((rel, "own work with no script in OWN_SCRIPTS of tools/audit_assets.py"))
                    continue
                rows.append([rel, "2.0", OWN_PACK, OWN_AUTHOR, OWN_WORK, OWN_LICENCE_TEXT,
                             "drawn by `%s`: %s" % (script, source),
                             changes or "none (made for Club & Grub; %s)" % entry.get("note", "data file")])
                continue
            names = [file_of_key[k] for k in keys if k in file_of_key]
            if not names or len(names) != len(keys):
                problems.append((rel, "registry_expansion.json names no known pack (%s)" % ", ".join(origin)))
                continue
            if "own" in origin:
                changes = (changes + "; " if changes else "") + "parts drawn by the art pipeline (Club & Grub's own)"
            rows.append([rel, "2.0"] + pack_cells(names, packs) + [source, changes])
            continue
        problems.append((rel, "in no registry (registry.json, registry_expansion.json) and not in EXTRA_FILES of "
                              "tools/audit_assets.py"))
    counts = {}
    for row in rows:
        counts[row[4]] = counts.get(row[4], 0) + 1
    out = [LEDGER_BEGIN, "## 18. File ledger: source, author, licence and changes of every file under assets/", ""]
    out.append("One row per file under `assets/` (the `.import` files aside): %d rows - %s. Written by "
               "`tools/audit_assets.py --write-ledger` from the pipeline registries (`docs/art/pipeline/"
               "registry.json`, `credits.json`, `docs/art/expansion/pipeline/registry_expansion.json`) and the "
               "headers of the licence texts in `assets/licenses/`; never edited by hand. `tools/audit_assets.py` "
               "(run by the build) fails when a file has no row, a row has no file, a cell is empty, a licence is "
               "not CC0 1.0 or the SIL Open Font License 1.1, a licence text is missing or says something else, or "
               "a pack is not in `CREDITS.md`, `docs/THIRD_PARTY.md` and the in-game credits."
               % (len(rows), ", ".join("%s %d" % (k, v) for k, v in sorted(counts.items()))))
    out.append("")
    out.append("*Since* = the release that first shipped the file. *Pack*, *Author* and *Licence* are the header "
               "of the licence text named beside them (several packs: joined with `;`); one licence text can cover "
               "several pages of one author under the title of the first (its `Page:` lines name them all, and "
               "`CREDITS.md` names each page). *Source* is the file "
               "inside the pack, in the pipeline's words (pack keys are the staging folder names). \"%s\" rows are "
               "Club & Grub's own drawings or data, made by the script the row names; \"%s\" rows are the legal "
               "texts themselves. Sizes, grids and animations: sections 3-13 and 17." % (OWN_WORK, LICENCE_TEXT))
    out.append("")
    out.append("| " + " | ".join(LEDGER_HEAD) + " |")
    out.append("|" + "|".join("---" for _ in LEDGER_HEAD) + "|")
    for row in rows:
        out.append("| `%s` | " % row[0] + " | ".join(cell(c) for c in row[1:]) + " |")
    out.append("")
    out.append(LEDGER_END)
    return "\n".join(out), problems


def write_ledger(root: str) -> int:
    block, problems = build_ledger(root)
    path = os.path.join(root, MANIFEST)
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    old = ledger_block(text)
    if old is not None:
        text = text.replace(old, block)
    else:
        text = text.rstrip("\n") + "\n\n" + block + "\n"
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("wrote section 18 of %s: %d rows" % (MANIFEST, block.count("\n| `")))
    for rel, why in problems:
        print("NO ROW for assets/%s: %s" % (rel, why))
    return 1 if problems else 0


# ----------------------------------------------------------------------------------------------------- audio
# Gates of --audio. A file that breaks one is an outlier. An outlier of a 1.0 file is the shipped baseline (1.0 audio
# is frozen: byte-identical to its published file); an outlier of a 2.0 file fails the run unless AUDIO_ACCEPTED
# gives the reason why no lossless edit (a trim or a gain) removes it.
AUDIO_GATES = {
    "played_peak": -1.0,          # dBTP at the table's volume_db: nothing above (the mix rule of 13.4)
    "music_target": -18.0,        # LUFS integrated at the table's volume_db ...
    "music_tolerance": 0.15,      # ... within this (the table rounds to 0.1 dB), unless the peak cap holds it lower
    "music_cap_slack": 2.0,       # a peak-capped track may sit this far under the target, not further
    "rates": (44100, 48000),      # Hz; the mixer resamples, 1.0 ships both
    "full_scale_share": 0.0030,   # share of samples at or over full scale: the worst 1.0 track has 0.0028
    "silence_floor": -60.0,       # dBFS: below this a sample is silence
    "loop_gap": 0.030,            # s of silence at the head plus the tail of a loop: a hole in the loop, unless the
                                  # track has rests at least that long inside (then it is the last beat's rest)
    "jingle_head": 0.050,         # s of silence before a jingle starts
    "sfx_head": 0.020,            # s of silence before an effect starts (heard as lag)
    "seam_jump_ratio": 2.0,       # sample jump across the loop point, in units of the track's own 99.9th-percentile
                                  # sample-to-sample step: above this the seam can click (worst 1.0 track: 1.5)
    "seam_step_low": -12.0,       # dB, level 50 ms after the loop point against 50 ms before it: under this the
                                  # loop was cut inside a sounding note
    "seam_step_high": 23.0,       # ... and above this the restart is a jump no 1.0 loop has (worst: +19.7) - tracks
                                  # that end on a rest are exempt (their last 50 ms are silence)
    "end_level": -6.0,            # dB, the last second against the whole track: under this a loop fades out
    "sfx_peak_floor": -18.0,      # dBFS: an effect whose own peak is lower (the quietest 1.0 effect: -14.4)
    "sfx_max_seconds": 3.0,       # one-shot effects (the two crowd beds aside)
}
LONG_EFFECTS = {"crowd_applause_a.ogg", "crowd_cheer_a.ogg"}
AUDIO_ACCEPTED = {
    ("audio/music/boss_idols_a.ogg", "full-scale"):
        "the published master (Spring Spring, 'Egyptian Fortress Boss', shipped byte-identical) is limited hard at "
        "full scale; no trim or gain undoes that. The table plays it 12 dB down (-10.3 dBTP), so nothing clips in "
        "the game. It is a line of the music listen-through.",
    ("audio/sfx/boulder_push_a.ogg", "head"):
        "the rumble (Kenney, shipped byte-identical) rises through -60 dBFS for 31 ms; Ogg Vorbis cannot be cut at "
        "the head without re-encoding, and four 1.0 effects start 30-77 ms in.",
}


def run_lengths(mask) -> "numpy.ndarray":
    """Lengths of the runs of True in a 1-D boolean array."""
    import numpy as np
    if not mask.any():
        return np.zeros(0, dtype=int)
    edges = np.diff(np.concatenate([[0], mask.astype(np.int8), [0]]))
    return np.nonzero(edges == -1)[0] - np.nonzero(edges == 1)[0]


def measure_audio(root: str) -> list[dict]:
    """One dictionary per sound file under assets/audio with everything --audio reports."""
    import numpy as np
    import soundfile
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import audio_loudness
    import pyloudnorm

    table = read_audio_table(root)
    since = {row["file"]: row["since"] for row in read_ledger(root)[0]}
    floor = 10.0 ** (AUDIO_GATES["silence_floor"] / 20.0)
    level = lambda part: 20.0 * np.log10(max(float(np.sqrt(np.mean(part ** 2))), 1e-9))
    results = []
    for kind in ("music", "sfx"):
        folder = os.path.join(root, "assets", "audio", kind)
        for name in sorted(os.listdir(folder)):
            if not name.endswith((".ogg", ".wav")):
                continue
            path = os.path.join(folder, name)
            info = soundfile.info(path)
            data, rate = soundfile.read(path, dtype="float64", always_2d=True)
            frames = data.shape[0]
            seconds = frames / rate
            entry = table.get(name, {"db": 0.0, "loop": False, "names": []})
            mono = np.max(np.abs(data), axis=1)
            loud = np.nonzero(mono > floor)[0]
            head = (loud[0] / rate) if loud.size else seconds
            tail = ((frames - 1 - loud[-1]) / rate) if loud.size else seconds
            rests = run_lengths(mono[loud[0]:loud[-1] + 1] <= floor) if loud.size else np.zeros(0, dtype=int)
            full = 0.9999 if name.endswith(".ogg") else 32767.0 / 32768.0
            tops = run_lengths(mono >= full)
            meter = pyloudnorm.Meter(rate)
            integrated = kind == "music" or entry["loop"]
            lufs = float(meter.integrated_loudness(data)) if integrated and frames >= int(0.4 * rate) else None
            result = {
                "kind": kind, "name": name, "since": since.get("audio/%s/%s" % (kind, name), "?"),
                "format": "%s %s" % (info.format, info.subtype), "rate": rate, "channels": data.shape[1],
                "kbps": os.path.getsize(path) * 8 / 1000.0 / seconds if seconds else 0.0,
                "seconds": seconds, "frames": frames,
                "peak": audio_loudness.sample_peak_db(data), "tp": audio_loudness.true_peak_db(data),
                "lufs": lufs, "db": entry["db"], "loop": bool(entry["loop"]), "names": entry["names"],
                "head": head, "tail": tail, "rest": (float(rests.max()) / rate) if rests.size else 0.0,
                "full_samples": int(tops.sum()), "full_share": float(tops.sum()) / frames if frames else 0.0,
                "full_longest": int(tops.max()) if tops.size else 0,
            }
            if entry["loop"] and frames > rate // 5:
                steps = np.abs(np.diff(data, axis=0))
                typical = float(np.percentile(steps, 99.9)) or 1e-9
                jump = float(np.max(np.abs(data[0] - data[-1])))
                window = int(0.05 * rate)
                result["seam_jump"] = jump
                result["seam_ratio"] = jump / typical
                result["seam_step"] = level(data[:window]) - level(data[-window:])
                result["end_level"] = level(data[-min(rate, frames):]) - level(data)
            results.append(result)
    return results


def audio_outliers(results: list[dict]) -> list[tuple[str, str, str]]:
    """[(file, gate, why)] for every gate of AUDIO_GATES a file breaks."""
    g = AUDIO_GATES
    out = []
    for r in results:
        name = "audio/%s/%s" % (r["kind"], r["name"])
        played_peak = r["tp"] + r["db"]
        add = lambda gate, why: out.append((name, gate, why))
        if not r["names"]:
            add("table", "no row of the audio table plays it")
        if played_peak > g["played_peak"] + 0.05:
            add("peak", "true peak %+.1f dBTP at volume_db %+.1f (above %+.1f)" % (played_peak, r["db"],
                                                                                   g["played_peak"]))
        if r["rate"] not in g["rates"] or r["channels"] not in (1, 2) or r["format"] not in (
                "OGG VORBIS", "WAV PCM_16") or (r["kind"] == "music" and r["format"] != "OGG VORBIS"):
            add("format", "%s, %d Hz, %d channel(s)" % (r["format"], r["rate"], r["channels"]))
        if r["full_share"] > g["full_scale_share"]:
            add("full-scale", "%.2f %% of the samples at or over full scale (%d, the longest run %d): clipped or "
                "limited hard at the source" % (100 * r["full_share"], r["full_samples"], r["full_longest"]))
        if r["kind"] == "music":
            played = r["lufs"] + r["db"]
            capped = played_peak >= g["played_peak"] - 0.45
            low = g["music_target"] - (g["music_cap_slack"] if capped else g["music_tolerance"])
            if played > g["music_target"] + g["music_tolerance"] or played < low:
                add("level", "plays at %+.1f LUFS (target %+.1f%s)" % (played, g["music_target"],
                                                                        ", peak-capped" if capped else ""))
        if r["loop"]:
            gap = r["head"] + r["tail"]
            if gap > g["loop_gap"] and gap > r["rest"] * 1.25:
                add("loop-gap", "%.0f ms of silence at the head and %.0f ms at the tail; the longest rest inside is "
                    "%.0f ms" % (r["head"] * 1000, r["tail"] * 1000, r["rest"] * 1000))
            if r.get("seam_ratio", 0.0) > g["seam_jump_ratio"]:
                add("seam-jump", "sample jump of %.4f across the loop point, %.1f times the track's own largest "
                    "steps" % (r["seam_jump"], r["seam_ratio"]))
            step = r.get("seam_step", 0.0)
            if step < g["seam_step_low"] or (step > g["seam_step_high"] and r["tail"] < 0.005):
                add("seam-step", "level step of %+.1f dB across the loop point" % step)
            if r["kind"] == "music" and r.get("end_level", 0.0) < g["end_level"]:
                add("end-level", "the last second is %+.1f dB against the whole track: a fade-out in a loop"
                    % r["end_level"])
        elif r["kind"] == "music":
            if r["head"] > g["jingle_head"]:
                add("head", "the jingle starts after %.0f ms of silence" % (r["head"] * 1000))
        else:
            if r["head"] > g["sfx_head"]:
                add("head", "the effect starts after %.0f ms of silence" % (r["head"] * 1000))
            if r["peak"] < g["sfx_peak_floor"]:
                add("low-peak", "peak %+.1f dBFS" % r["peak"])
            if r["seconds"] > g["sfx_max_seconds"] and r["name"] not in LONG_EFFECTS:
                add("long", "%.1f s long" % r["seconds"])
    return out


def print_audio(results: list[dict], markdown: bool) -> None:
    def table(head: list[str], rows: list[list[str]]) -> None:
        if markdown:
            print("| " + " | ".join(head) + " |")
            print("|" + "|".join("---" for _ in head) + "|")
            for row in rows:
                print("| " + " | ".join(row) + " |")
        else:
            widths = [max(len(head[i]), max((len(r[i]) for r in rows), default=0)) for i in range(len(head))]
            print("  ".join(head[i].ljust(widths[i]) for i in range(len(head))))
            for row in rows:
                print("  ".join(row[i].ljust(widths[i]) for i in range(len(head))))
        print("")

    music = [r for r in results if r["kind"] == "music"]
    loops = [r for r in results if r["kind"] == "sfx" and r["loop"]]
    effects = [r for r in results if r["kind"] == "sfx" and not r["loop"]]
    fmt = lambda r: "%s %s %s %.0fk" % ("ogg" if r["name"].endswith(".ogg") else "wav",
                                        "%.1f" % (r["rate"] / 1000.0), "mono" if r["channels"] == 1 else "stereo",
                                        r["kbps"])
    rows = []
    for r in music + loops:
        rows.append([
            r["name"], r["since"], "loop" if r["loop"] else "jingle", "%.2f" % r["seconds"], fmt(r),
            "%+.1f" % r["peak"], "%+.1f" % r["tp"], "%.2f%%/%d" % (100 * r["full_share"], r["full_longest"]),
            "%+.1f" % r["lufs"], "%+.1f" % r["db"], "%+.1f" % (r["lufs"] + r["db"]), "%+.1f" % (r["tp"] + r["db"]),
            "%.0f/%.0f" % (r["head"] * 1000, r["tail"] * 1000), "%.0f" % (r["rest"] * 1000),
            ("%.4f x%.2f" % (r["seam_jump"], r["seam_ratio"])) if "seam_jump" in r else "-",
            ("%+.1f" % r["seam_step"]) if "seam_step" in r else "-",
            ("%+.1f" % r["end_level"]) if "end_level" in r else "-",
        ])
    print("Music tracks and loops (%d): peak dBFS, true peak dBTP, share of samples at full scale / longest run, "
          "integrated LUFS, the table's volume_db, what it plays at (LUFS, dBTP), silence at head / tail (ms, under "
          "%.0f dBFS), longest rest inside (ms), sample jump across the loop point (x the track's own 99.9th-"
          "percentile step), level step across it (50 ms after / before, dB), last second against the whole track (dB)"
          % (len(rows), AUDIO_GATES["silence_floor"]))
    table(["file", "since", "kind", "s", "format", "peak", "TP", "full/run", "LUFS", "db", "plays LUFS", "plays TP",
           "head/tail", "rest", "seam jump", "seam step", "end"], rows)
    rows = []
    for r in effects:
        rows.append([r["name"], r["since"], "%.3f" % r["seconds"], fmt(r), "%+.1f" % r["peak"], "%+.1f" % r["tp"],
                     "%+.1f" % r["db"], "%+.1f" % (r["tp"] + r["db"]),
                     "%.0f/%.0f" % (r["head"] * 1000, r["tail"] * 1000)])
    print("Sound effects (%d): length s, peak dBFS, true peak dBTP, volume_db, plays at dBTP, silence at head / tail "
          "ms" % len(rows))
    table(["file", "since", "s", "format", "peak", "TP", "db", "plays TP", "head/tail"], rows)

    def spread(values: list[float]) -> str:
        values = sorted(values)
        return "%+.1f / %+.1f / %+.1f" % (values[0], values[len(values) // 2], values[-1])

    rows = []
    for label, group, key in (
            ("music: integrated LUFS", music, lambda r: r["lufs"]),
            ("music: true peak dBTP", music, lambda r: r["tp"]),
            ("music: plays at LUFS", music, lambda r: r["lufs"] + r["db"]),
            ("music: plays at dBTP", music, lambda r: r["tp"] + r["db"]),
            ("music: length s", music, lambda r: r["seconds"]),
            ("music: samples at full scale %", music, lambda r: 100 * r["full_share"]),
            ("loops: seam jump x own steps", [r for r in music if "seam_ratio" in r], lambda r: r["seam_ratio"]),
            ("loops: seam level step dB", [r for r in music if "seam_step" in r and r["tail"] < 0.005],
             lambda r: r["seam_step"]),
            ("loops: last second dB", [r for r in music if "end_level" in r], lambda r: r["end_level"]),
            ("effects: peak dBFS", effects, lambda r: r["peak"]),
            ("effects: length s", effects, lambda r: r["seconds"]),
            ("effects: volume_db", effects, lambda r: r["db"]),
            ("effects: plays at dBTP", effects, lambda r: r["tp"] + r["db"]),
            ("effects: silence at head ms", effects, lambda r: r["head"] * 1000)):
        cells = [label]
        for release in ("1.0", "2.0"):
            values = [key(r) for r in group if r["since"] == release]
            cells.append("%d: %s" % (len(values), spread(values)) if values else "-")
        rows.append(cells)
    print("2.0 against 1.0 (files: min / median / max):")
    table(["measure", "1.0", "2.0"], rows)


def run_audio(root: str, markdown: bool) -> int:
    results = measure_audio(root)
    print_audio(results, markdown)
    since = {"audio/%s/%s" % (r["kind"], r["name"]): r["since"] for r in results}
    failed = 0
    for name, gate, why in audio_outliers(results):
        if since[name] == "1.0":
            print("OUTLIER (1.0 baseline, frozen) %s [%s]: %s" % (name, gate, why))
        elif (name, gate) in AUDIO_ACCEPTED:
            print("OUTLIER (accepted) %s [%s]: %s - %s" % (name, gate, why, AUDIO_ACCEPTED[(name, gate)]))
        else:
            failed += 1
            print("OUTLIER %s [%s]: %s" % (name, gate, why))
    print("AUDIO AUDIT: %s (%d files, %d open outlier(s) in 2.0 files)" % ("FAIL" if failed else "PASS",
                                                                          len(results), failed))
    return 1 if failed else 0


# ------------------------------------------------------------------------------------------------- contact sheets
ANCHOR_OUTLINE = (39, 32, 24)  # #272018, the 2 px outline of the anchor pack (docs/ASSET_MANIFEST.md 1)
STYLE_TESTS = ".tools/asset_candidates/expansion/_style_tests/biome_all.png"  # 2 x 3 panels of 640 x 360
STYLE_PANELS = {"canyon": (0, 0), "swamp": (1, 0), "sky": (0, 1), "coast": (1, 1), "ruins": (0, 2),
                "mushroom": (1, 2)}
SHEET_WIDTH = 1280


def style_numbers(path: str) -> dict:
    """Numbers that describe the look of one PNG: pixel size (share of colour runs whose length is a multiple of
    2 / 3 / 4), outline (colour and thickness of the pixels that border transparency), palette (colours, soft
    alpha)."""
    import numpy as np
    from PIL import Image

    image = np.asarray(Image.open(path).convert("RGBA"))
    height, width = image.shape[:2]
    alpha = image[:, :, 3]
    opaque = alpha > 0
    packed = (image[:, :, 0].astype(np.uint32) << 24) | (image[:, :, 1].astype(np.uint32) << 16) | (
        image[:, :, 2].astype(np.uint32) << 8) | alpha
    count = int(opaque.sum())
    result = {"size": (width, height), "opaque": count, "colours": 0, "soft": 0.0, "even": 0.0, "third": 0.0,
              "fourth": 0.0, "runs": 0, "edge": 0, "anchor_edge": 0.0, "dark_edge": 0.0, "edge_colour": "-",
              "outline_px": 0.0}
    if count == 0:
        return result
    result["colours"] = int(np.unique(packed[alpha == 255]).size)
    result["soft"] = float(((alpha > 0) & (alpha < 255)).sum()) / count
    lengths, outline_runs = [], []
    luma = 0.299 * image[:, :, 0] + 0.587 * image[:, :, 1] + 0.114 * image[:, :, 2]
    for data, clear, dark in ((packed, opaque, luma < 70), (packed.T, opaque.T, (luma < 70).T)):
        for line, solid, shade in zip(data, clear, dark):
            if not solid.any():
                continue
            cuts = np.nonzero(line[1:] != line[:-1])[0] + 1
            starts = np.concatenate([[0], cuts])
            ends = np.concatenate([cuts, [line.size]])
            inner = (starts > 0) & (ends < line.size) & solid[starts]
            lengths.append((ends - starts)[inner])
            # a run that begins where transparency ends: an outline when it is dark
            first = inner & ~solid[np.maximum(starts - 1, 0)] & shade[starts]
            outline_runs.append((ends - starts)[first])
    lengths = np.concatenate(lengths) if lengths else np.zeros(0, dtype=int)
    outline_runs = np.concatenate(outline_runs) if outline_runs else np.zeros(0, dtype=int)
    if lengths.size:
        result["runs"] = int(lengths.size)
        result["even"] = float((lengths % 2 == 0).sum()) / lengths.size
        result["third"] = float((lengths % 3 == 0).sum()) / lengths.size
        result["fourth"] = float((lengths % 4 == 0).sum()) / lengths.size
    if outline_runs.size:
        result["outline_px"] = float(np.median(outline_runs))
    padded = np.pad(opaque, 1, constant_values=True)
    border = opaque & ~(padded[:-2, 1:-1] & padded[2:, 1:-1] & padded[1:-1, :-2] & padded[1:-1, 2:])
    edge = int(border.sum())
    result["edge"] = edge
    if edge:
        colours, counts = np.unique(packed[border] >> 8, return_counts=True)
        anchor = (ANCHOR_OUTLINE[0] << 16) | (ANCHOR_OUTLINE[1] << 8) | ANCHOR_OUTLINE[2]
        result["anchor_edge"] = float(counts[colours == anchor].sum()) / edge
        result["dark_edge"] = float((luma[border] < 70).sum()) / edge
        result["edge_colour"] = "#%06x" % int(colours[np.argmax(counts)])
    return result


def pixel_size(numbers: dict) -> str:
    """'1x', '2x', '3x', '4x' or 'mixed 1x+2x' from the run-length shares of style_numbers()."""
    if numbers["runs"] < 20:
        return "-"
    if numbers["fourth"] >= 0.97:
        return "4x"
    if numbers["third"] >= 0.97:
        return "3x"
    if numbers["even"] >= 0.97:
        return "2x"
    if numbers["even"] >= 0.72:
        return "mixed 1x+2x"
    return "1x"


def sheet_group(rel: str) -> str:
    parts = rel.split("/")
    if parts[0] == "tiles":
        return "tiles_" + parts[1] + ("_props" if len(parts) > 3 else "")
    if parts[0] == "backgrounds":
        return "backgrounds_" + parts[1]
    if parts[0] == "sprites":
        return "sprites_" + parts[1]
    if parts[0] == "ui":
        return "ui_arena" if len(parts) > 2 else "ui"
    return "other"


def run_sheets(root: str, out_dir: str) -> int:
    """Contact sheets of every PNG added since 1.0, each page under a band with a style-test panel and a 1.0
    reference, and a table of style numbers (2.0 files beside the 1.0 files of the same folder kind)."""
    from PIL import Image, ImageDraw

    os.makedirs(out_dir, exist_ok=True)
    rows, _ = read_ledger(root)
    since = {row["file"]: row["since"] for row in rows}
    files, _ = asset_files(root)
    pngs = [f for f in files if f.endswith(".png")]
    numbers = {f: style_numbers(os.path.join(root, "assets", f)) for f in pngs}
    with open(os.path.join(out_dir, "style_numbers.tsv"), "w", encoding="utf-8", newline="\n") as handle:
        handle.write("file\tsince\tgroup\twidth\theight\tpixel\teven\tfourth\tcolours\tsoft_alpha\tedge_px\t"
                     "anchor_edge\tdark_edge\tedge_colour\toutline_px\n")
        for f in pngs:
            n = numbers[f]
            handle.write("%s\t%s\t%s\t%d\t%d\t%s\t%.3f\t%.3f\t%d\t%.4f\t%d\t%.3f\t%.3f\t%s\t%.1f\n" % (
                f, since.get(f, "?"), sheet_group(f), n["size"][0], n["size"][1], pixel_size(n), n["even"],
                n["fourth"], n["colours"], n["soft"], n["edge"], n["anchor_edge"], n["dark_edge"], n["edge_colour"],
                n["outline_px"]))

    def median(values: list[float]) -> float:
        values = sorted(values)
        return values[len(values) // 2] if values else 0.0

    print("%-24s %-5s %5s  %-28s %8s %8s %8s %8s" % ("group", "since", "files", "pixel sizes", "colours",
                                                    "anchor", "dark", "outline"))
    groups = sorted({sheet_group(f) for f in pngs})
    for group in groups:
        for release in ("1.0", "2.0"):
            members = [f for f in pngs if sheet_group(f) == group and since.get(f) == release]
            if not members:
                continue
            sizes = {}
            for f in members:
                sizes[pixel_size(numbers[f])] = sizes.get(pixel_size(numbers[f]), 0) + 1
            print("%-24s %-5s %5d  %-28s %8d %7.0f%% %7.0f%% %7.1f" % (
                group, release, len(members), ", ".join("%s %d" % kv for kv in sorted(sizes.items())),
                median([numbers[f]["colours"] for f in members]),
                100 * median([numbers[f]["anchor_edge"] for f in members]),
                100 * median([numbers[f]["dark_edge"] for f in members]),
                median([numbers[f]["outline_px"] for f in members])))

    tests = None
    if os.path.isfile(os.path.join(root, STYLE_TESTS)):
        tests = Image.open(os.path.join(root, STYLE_TESTS)).convert("RGBA")
    mock = None
    if os.path.isfile(os.path.join(root, "docs/art/mock_jungle.png")):
        mock = Image.open(os.path.join(root, "docs/art/mock_jungle.png")).convert("RGBA")
        mock = mock.resize((mock.width // 4, mock.height // 4), Image.NEAREST)
    panel_names = list(STYLE_PANELS)

    def band(group: str, page: int) -> Image.Image:
        strip = Image.new("RGBA", (SHEET_WIDTH, 360), (40, 44, 52, 255))
        biome = group.split("_")[1] if group.startswith(("tiles_", "backgrounds_")) else ""
        names = [biome] if biome in STYLE_PANELS else [panel_names[(2 * page) % 6], panel_names[(2 * page + 1) % 6]]
        if biome == "swamp":
            names = ["swamp", "mushroom"]
        x = 0
        for name in names:
            if tests is not None:
                col, row = STYLE_PANELS[name]
                strip.alpha_composite(tests.crop((col * 640, row * 360, col * 640 + 640, row * 360 + 360)), (x, 0))
                x += 640
        if x < SHEET_WIDTH and mock is not None:
            strip.alpha_composite(mock.crop((0, 0, min(640, mock.width), 360)), (x, 0))
        return strip

    written = 0
    for group in groups:
        members = [f for f in pngs if sheet_group(f) == group and since.get(f) == "2.0"]
        if not members:
            continue
        placed, x, y, row_h, page = [], 8, 8, 0, []
        pages = []
        for f in members:
            image = Image.open(os.path.join(root, "assets", f)).convert("RGBA")
            scale = 1
            while image.width // scale > SHEET_WIDTH - 16:
                scale *= 2
            if scale > 1:
                image = image.resize((image.width // scale, image.height // scale), Image.NEAREST)
            if x + image.width + 8 > SHEET_WIDTH and x > 8:
                x, y, row_h = 8, y + row_h + 22, 0
            if y + image.height + 22 > 1040 and page:
                pages.append(page)
                page, x, y, row_h = [], 8, 8, 0
            n = numbers[f]
            label = "%s %dx%d %s%s" % (os.path.basename(f)[:-4], n["size"][0], n["size"][1], pixel_size(n),
                                       " (shown 1/%d)" % scale if scale > 1 else "")
            page.append((image, x, y, label))
            x += max(image.width, 6 * len(label) + 4) + 8
            row_h = max(row_h, image.height)
        if page:
            pages.append(page)
        for index, page in enumerate(pages):
            bottom = max(py + image.height + 22 for image, _px, py, _label in page)
            canvas = Image.new("RGBA", (SHEET_WIDTH, 360 + 8 + bottom), (104, 120, 140, 255))
            canvas.alpha_composite(band(group, index), (0, 0))
            draw = ImageDraw.Draw(canvas)
            for image, px, py, label in page:
                # a light and a dark half behind each picture show outlines and soft edges
                draw.rectangle([px, 368 + py, px + image.width - 1, 368 + py + image.height // 2], fill=(150, 170,
                                                                                                         190, 255))
                canvas.alpha_composite(image, (px, 368 + py))
                draw.text((px, 368 + py + image.height + 2), label, fill=(255, 255, 255, 255))
            name = "sheet_%s_%02d.png" % (group, index + 1)
            canvas.convert("RGB").save(os.path.join(out_dir, name))
            written += 1
    print("%d contact sheet page(s) and style_numbers.tsv in %s" % (written, out_dir))
    return 0


# ------------------------------------------------------------------------------------------------------------ main
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Asset and licence audit of Club & Grub.")
    parser.add_argument("--root", default=ROOT)
    parser.add_argument("--no-git", action="store_true")
    parser.add_argument("--write-ledger", action="store_true")
    parser.add_argument("--audio", action="store_true")
    parser.add_argument("--markdown", action="store_true")
    parser.add_argument("--sheets", metavar="DIR")
    parser.add_argument("--shipped", metavar="PATH")
    args = parser.parse_args(argv)
    root = os.path.abspath(args.root)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    if args.write_ledger:
        return write_ledger(root)
    if args.audio:
        return run_audio(root, args.markdown)
    if args.sheets:
        return run_sheets(root, args.sheets)
    if args.shipped:
        findings, count = check_shipped(root, args.shipped)
        for finding in findings:
            print("GAP " + str(finding))
        print("LICENCE TEXTS SHIPPED: %s (%d files expected in %s, %d gap(s))" % (
            "FAIL" if findings else "PASS", count, args.shipped, len(findings)))
        return 1 if findings else 0
    findings, summary = audit(root, use_git=not args.no_git)
    for finding in findings:
        print("GAP " + str(finding))
    for line in summary:
        print("    " + line)
    print("ASSET AUDIT: %s (%d gap(s))" % ("FAIL" if findings else "PASS", len(findings)))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())

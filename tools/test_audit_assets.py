"""Tests of tools/audit_assets.py: a small project that passes, then one gap at a time - each must be reported under
its code - and the real project, which must pass. Standard library only (the audio and style tests skip themselves
when numpy / soundfile / Pillow are missing). From the project root:

    python tools/test_audit_assets.py            (or: python -m unittest discover -s tools -p "test_audit_assets.py")
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import wave
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import audit_assets as A  # noqa: E402

FEAST_SCRIPT = "docs/art/expansion/pipeline/build_feast_skins.py"


def png_bytes(width: int = 4, height: int = 4) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    rows = b"".join(b"\x00" + b"\x27\x20\x18\xff" * width for _ in range(height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


def put(root: str, rel: str, data: bytes | str) -> None:
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if isinstance(data, str):
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(data)
    else:
        with open(path, "wb") as handle:
            handle.write(data)


def put_asset(root: str, rel: str, data: bytes) -> None:
    put(root, "assets/" + rel, data)
    if os.path.splitext(rel)[1] in A.IMPORTED_EXT:
        put(root, "assets/" + rel + ".import", "[remap]\n")


def wav_bytes() -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(44100)
        handle.writeframes(struct.pack("<h", 1000) * 441)
    return buffer.getvalue()


def licence_text(title: str, author: str, url: str, licence: str) -> str:
    return "%s\n%s\n\nAuthor: %s\nSource: %s\nLicence: %s\nUsed in Club & Grub for: things\n\n---- evidence ----\n" % (
        title, "=" * len(title), author, url, licence)


CREDITS_MD = """# Credits - Test

A test game. Nothing else.

## Art, fonts and audio

| Pack | Author | Source | Licence | Used for | Changes |
|---|---|---|---|---|---|
| Anchor Pack | Pixel Person (Studio) | https://example.org/anchor (commit 1) | CC0 1.0 | hero | re-packed |
| Tune Pack | Tuna | https://example.org/tunes | CC0 1.0 | music | none |
| Blip Pack | Blipper (B. Lip) | https://example.org/blips | CC0 1.0 | effects | trimmed |
| Font Pack | Fonty / The Font Authors | https://example.org/font | SIL Open Font License 1.1 | font.ttf | none |

## Required attribution (fonts, SIL Open Font License 1.1)

- "Font Pack" by Fonty - Copyright 2020 The Font Authors. Licensed under the SIL Open Font License, Version 1.1.

## Courtesy credits

Suggested in-game wording: "Art: Pixel Person / Studio (Anchor Pack). Music: Tuna. Sound: Blipper."

## Engine

Made with Godot Engine. More.
"""

THIRD_PARTY_MD = """# THIRD_PARTY
| Anchor Pack | https://example.org/anchor |
| Tune Pack | https://example.org/tunes |
| Blip Pack | https://example.org/blips |
| Font Pack | https://example.org/font |
"""

LICENCE_INDEX_MD = """# Licences
`godot_engine.txt` `godot_third_party.txt` `cc0_1.0_legal_code.txt`
`anchor_pack.txt` `tune_pack.txt` `blip_pack.txt` `font_pack.txt`
"""

AUDIO_TABLE_GD = """class_name AudioTable
const SFX: Dictionary = {
\tSfx.JUMP: {
\t\t"files": ["jump_a.wav"],
\t\t"db": [-3.0],
\t},
}
const MUSIC: Dictionary = {
\tSfx.MUSIC_THEME: {"file": "theme_a.ogg", "db": -6.0, "loop": true},
}
"""


def make_project(root: str) -> None:
    """A project the audit passes: five files from four packs and one own drawing, registries, ledger, credits."""
    put_asset(root, "sprites/hero.png", png_bytes())
    put_asset(root, "audio/music/theme_a.ogg", b"OggS" + bytes(24) + b"\x01vorbis" + bytes(40))
    put_asset(root, "audio/sfx/jump_a.wav", wav_bytes())
    put_asset(root, "fonts/font.ttf", b"\x00\x01\x00\x00" + bytes(32))
    put_asset(root, "tiles/feast/props/jelly.png", png_bytes())
    put(root, FEAST_SCRIPT, "# draws the jelly\n")
    put_asset(root, "licenses/anchor_pack.txt",
              licence_text("Anchor Pack", "Pixel Person (Studio)", "https://example.org/anchor", "CC0 1.0 (tier A)"))
    put_asset(root, "licenses/tune_pack.txt",
              licence_text("Tune Pack", "Tuna", "https://example.org/tunes", "CC0 1.0 (tier A)"))
    put_asset(root, "licenses/blip_pack.txt",
              licence_text("Blip Pack", "Blipper (B. Lip)", "https://example.org/blips", "CC0 1.0 (tier A)"))
    put_asset(root, "licenses/font_pack.txt",
              licence_text("Font Pack", "Fonty / The Font Authors", "https://example.org/font",
                           "SIL Open Font License 1.1 (tier B)"))
    for name in ("cc0_1.0_legal_code.txt", "godot_engine.txt", "godot_third_party.txt"):
        put_asset(root, "licenses/" + name, "legal text\n")
    put_asset(root, "licenses/README.md", LICENCE_INDEX_MD)
    put(root, "CREDITS.md", CREDITS_MD)
    put(root, "docs/THIRD_PARTY.md", THIRD_PARTY_MD)
    put(root, "scripts/core/audio_table.gd", AUDIO_TABLE_GD)
    put(root, A.REGISTRY_1, json.dumps({
        "assets/sprites/hero.png": {"kind": "actor", "source": "anchor-pack: hero.png", "edits": "re-packed"},
        "assets/audio/music/theme_a.ogg": {"kind": "music", "source": "tune-pack/theme.ogg"},
        "assets/fonts/font.ttf": {"kind": "ttf", "source": "font-pack: Font.ttf", "edits": "renamed"},
    }))
    put(root, A.CREDITS_JSON, json.dumps([
        {"pack": "anchor-pack", "file": "assets/licenses/anchor_pack.txt"},
        {"pack": "tune-pack", "file": "assets/licenses/tune_pack.txt"},
        {"pack": "font-pack", "file": "assets/licenses/font_pack.txt"},
    ]))
    put(root, A.REGISTRY_2, json.dumps({
        "_meta": {"packs": {}, "audio_packs": {"audio/blip-pack": {"file": "assets/licenses/blip_pack.txt"}}},
        "assets/audio/sfx/jump_a.wav": {"owner": "audio", "kind": "sfx", "audio_packs": ["audio/blip-pack"],
                                        "source": "blip-pack: jump.wav", "edits": "trimmed"},
        "assets/tiles/feast/props/jelly.png": {"owner": "art-A", "kind": "prop", "origin_packs": ["own"],
                                               "source": "drawn by the pipeline", "edits": "flat tones"},
    }))
    put(root, A.MANIFEST, "# ASSET_MANIFEST\n\nSections 1-17.\n")
    with contextlib.redirect_stdout(io.StringIO()):
        assert A.write_ledger(root) == 0


def codes(root: str, use_git: bool = False) -> list[str]:
    return sorted({finding.code for finding in A.audit(root, use_git=use_git)[0]})


def edit(root: str, rel: str, old: str, new: str) -> None:
    path = os.path.join(root, rel)
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    assert old in text, "%r is not in %s" % (old, rel)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text.replace(old, new))


def edit_ledger_row(root: str, file: str, column: int, value: str) -> None:
    """Replace one cell of the ledger row of `file` (and switch the freshness check off: the row is hand-made)."""
    path = os.path.join(root, A.MANIFEST)
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().split("\n")
    for index, line in enumerate(lines):
        if line.startswith("| `%s` |" % file):
            cells = A.split_row(line)
            cells[column] = value
            lines[index] = "| " + " | ".join(cells) + " |"
            break
    else:
        raise AssertionError("no ledger row for " + file)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))
    if os.path.exists(os.path.join(root, A.REGISTRY_2)):
        os.remove(os.path.join(root, A.REGISTRY_2))  # without the registries the ledger is taken as written


class TempProject(unittest.TestCase):
    def setUp(self) -> None:
        self.root = tempfile.mkdtemp(prefix="audit_assets_")
        self.addCleanup(shutil.rmtree, self.root, True)
        make_project(self.root)


class CleanProject(TempProject):
    def test_passes(self) -> None:
        findings, summary = A.audit(self.root, use_git=False)
        self.assertEqual([str(f) for f in findings], [])
        self.assertIn("13 files under assets/", summary[0])
        self.assertIn("4 source packs in use", summary[2])

    def test_ledger_rows(self) -> None:
        rows = {row["file"]: row for row in A.read_ledger(self.root)[0]}
        self.assertEqual(len(rows), 13)
        hero = rows["sprites/hero.png"]
        self.assertEqual((hero["since"], hero["pack"], hero["author"], hero["licence"], hero["changes"]),
                         ("1.0", "Anchor Pack", "Pixel Person (Studio)", "CC0 1.0", "re-packed"))
        self.assertEqual(rows["audio/music/theme_a.ogg"]["changes"], "none (byte-identical copy, renamed)")
        self.assertEqual(rows["audio/sfx/jump_a.wav"]["since"], "2.0")
        self.assertEqual(rows["fonts/font.ttf"]["licence"], A.OFL)
        own = rows["tiles/feast/props/jelly.png"]
        self.assertEqual((own["pack"], own["licence"]), (A.OWN_PACK, A.OWN_WORK))
        self.assertIn("`%s`" % FEAST_SCRIPT, own["source"])
        self.assertEqual(rows["licenses/blip_pack.txt"]["since"], "2.0")
        self.assertEqual(rows["licenses/anchor_pack.txt"]["licence"], A.LICENCE_TEXT)

    def test_command_line(self) -> None:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(A.main(["--root", self.root, "--no-git"]), 0)
        self.assertIn("ASSET AUDIT: PASS (0 gap(s))", out.getvalue())
        put_asset(self.root, "sprites/new.png", png_bytes())
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(A.main(["--root", self.root, "--no-git"]), 1)
        self.assertIn("GAP ledger-missing", out.getvalue())
        self.assertIn("ASSET AUDIT: FAIL", out.getvalue())


class FilesAndRows(TempProject):
    def test_file_without_row(self) -> None:
        put_asset(self.root, "sprites/new.png", png_bytes())
        self.assertIn("ledger-missing", codes(self.root))

    def test_write_ledger_gives_an_unknown_file_no_row(self) -> None:
        put_asset(self.root, "sprites/new.png", png_bytes())
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(A.write_ledger(self.root), 1)
        self.assertIn("NO ROW for assets/sprites/new.png", out.getvalue())
        self.assertIn("ledger-missing", codes(self.root))

    def test_row_without_file(self) -> None:
        os.remove(os.path.join(self.root, "assets/sprites/hero.png"))
        os.remove(os.path.join(self.root, "assets/sprites/hero.png.import"))
        self.assertIn("ledger-orphan", codes(self.root))

    def test_two_rows_for_one_file(self) -> None:
        path = os.path.join(self.root, A.MANIFEST)
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        row = [line for line in text.split("\n") if line.startswith("| `sprites/hero.png` |")][0]
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text.replace(row, row + "\n" + row))
        os.remove(os.path.join(self.root, A.REGISTRY_2))
        self.assertEqual(codes(self.root), ["ledger-orphan"])

    def test_no_ledger_at_all(self) -> None:
        put(self.root, A.MANIFEST, "# ASSET_MANIFEST\n")
        self.assertIn("ledger-missing", codes(self.root))

    def test_empty_cell(self) -> None:
        for column, value in ((7, "-"), (6, ""), (3, "?"), (1, "3.0")):
            with self.subTest(column=column):
                root = tempfile.mkdtemp(prefix="audit_assets_")
                self.addCleanup(shutil.rmtree, root, True)
                make_project(root)
                edit_ledger_row(root, "sprites/hero.png", column, value)
                self.assertIn("row-incomplete", codes(root))

    def test_hand_edited_ledger_is_stale(self) -> None:
        edit(self.root, A.MANIFEST, "| re-packed |", "| re-packed and blessed |")
        self.assertEqual(codes(self.root), ["ledger-stale"])


class Licences(TempProject):
    def test_other_licence_in_the_row(self) -> None:
        edit_ledger_row(self.root, "sprites/hero.png", 4, "CC-BY 4.0")
        self.assertEqual(codes(self.root), ["licence", "licence-file"])

    def test_other_licence_in_the_licence_text(self) -> None:
        edit(self.root, "assets/licenses/tune_pack.txt", "Licence: CC0 1.0 (tier A)", "Licence: CC-BY-SA 3.0 (tier C)")
        found = codes(self.root)
        self.assertIn("licence", found)       # the pack's own text says share-alike
        self.assertIn("licence-file", found)  # and the row no longer agrees with it

    def test_licence_text_missing(self) -> None:
        os.remove(os.path.join(self.root, "assets/licenses/blip_pack.txt"))
        found = codes(self.root)
        self.assertIn("licence-file", found)
        self.assertIn("ledger-orphan", found)

    def test_licence_text_without_header(self) -> None:
        put(self.root, "assets/licenses/blip_pack.txt", "some words, no header\n")
        self.assertIn("licence-file", codes(self.root))

    def test_author_differs_from_the_licence_text(self) -> None:
        edit_ledger_row(self.root, "audio/sfx/jump_a.wav", 3, "Somebody Else")
        self.assertEqual(codes(self.root), ["licence-file"])

    def test_row_names_no_licence_text(self) -> None:
        edit_ledger_row(self.root, "sprites/hero.png", 5, "see the pack")
        self.assertEqual(codes(self.root), ["licence-file", "licence-orphan"])  # and nobody uses the pack's text

    def test_licence_text_row_outside_the_licence_folder(self) -> None:
        edit_ledger_row(self.root, "sprites/hero.png", 4, A.LICENCE_TEXT)
        self.assertEqual(codes(self.root), ["licence"])

    def test_licence_file_must_be_a_licence_text_row(self) -> None:
        edit_ledger_row(self.root, "licenses/tune_pack.txt", 4, "CC0 1.0")
        self.assertEqual(codes(self.root), ["licence"])

    def test_sound_cannot_be_own_work(self) -> None:
        for column, value in ((2, A.OWN_PACK), (3, A.OWN_AUTHOR), (4, A.OWN_WORK), (5, A.OWN_LICENCE_TEXT),
                              (6, "made by `%s`" % FEAST_SCRIPT)):
            edit_ledger_row(self.root, "audio/sfx/jump_a.wav", column, value)
        self.assertIn("licence", codes(self.root))
        messages = [f.text for f in A.audit(self.root, use_git=False)[0] if f.code == "licence"]
        self.assertTrue(any("cannot be 'own work'" in text for text in messages), messages)

    def test_own_work_must_name_its_script(self) -> None:
        edit_ledger_row(self.root, "tiles/feast/props/jelly.png", 6, "drawn by hand")
        self.assertEqual(codes(self.root), ["licence"])

    def test_own_work_script_must_exist(self) -> None:
        os.remove(os.path.join(self.root, FEAST_SCRIPT))
        self.assertEqual(codes(self.root), ["licence"])

    def test_licence_text_nobody_uses(self) -> None:
        put_asset(self.root, "licenses/spare_pack.txt",
                  licence_text("Spare Pack", "Nobody", "https://example.org/spare", "CC0 1.0 (tier A)"))
        found = codes(self.root)
        self.assertIn("licence-orphan", found)


class Credits(TempProject):
    def test_source_missing_from_credits(self) -> None:
        edit(self.root, "CREDITS.md", "https://example.org/blips", "https://example.org/elsewhere")
        self.assertEqual(codes(self.root), ["credits", "credits-roll"])

    def test_source_missing_from_third_party(self) -> None:
        edit(self.root, "docs/THIRD_PARTY.md", "https://example.org/tunes", "(a tune pack)")
        self.assertEqual(codes(self.root), ["third-party"])

    def test_page_urls_of_the_licence_text_count(self) -> None:
        edit(self.root, "assets/licenses/tune_pack.txt", "Used in Club & Grub for: things\n",
             "Used in Club & Grub for: things\nPage: Second Tune - https://example.org/tunes-2\n")
        # the new page is in neither document, and the ledger row of the licence text names its pages
        self.assertEqual(codes(self.root), ["credits", "ledger-stale", "third-party"])

    def test_licence_index_missing(self) -> None:
        edit(self.root, "assets/licenses/README.md", "`tune_pack.txt`", "")
        self.assertEqual(codes(self.root), ["licence-index"])

    def test_credits_row_licence_differs(self) -> None:
        edit(self.root, "CREDITS.md", "| https://example.org/tunes | CC0 1.0 |",
             "| https://example.org/tunes | CC-BY 3.0 |")
        self.assertEqual(codes(self.root), ["credits"])

    def test_credits_row_author_differs(self) -> None:
        edit(self.root, "CREDITS.md", "| Tune Pack | Tuna |", "| Tune Pack | Salmon |")
        self.assertEqual(codes(self.root), ["credits"])

    def test_author_missing_from_the_roll(self) -> None:
        edit(self.root, "CREDITS.md", "Sound: Blipper.", "Sound: Somebody.")
        self.assertEqual(codes(self.root), ["credits-roll"])

    def test_author_under_the_wrong_role(self) -> None:
        edit(self.root, "CREDITS.md", "Music: Tuna. Sound: Blipper.", "Music: Blipper. Sound: Tuna.")
        self.assertEqual(codes(self.root), ["credits-roll"])

    def test_font_notice_missing(self) -> None:
        edit(self.root, "CREDITS.md", '- "Font Pack" by Fonty', '- "Another Font" by Somebody')
        self.assertEqual(codes(self.root), ["credits-roll"])

    def test_pack_row_missing_from_the_table(self) -> None:
        edit(self.root, "CREDITS.md",
             "| Tune Pack | Tuna | https://example.org/tunes | CC0 1.0 | music | none |\n", "")
        edit(self.root, "CREDITS.md", "A test game.", "A test game (music: https://example.org/tunes).")
        self.assertEqual(codes(self.root), ["credits-roll"])

    def test_parser_matches_the_roll(self) -> None:
        roll = A.parse_credits(CREDITS_MD)
        self.assertEqual(roll["roles"], {"Art": ["Pixel Person / Studio (Anchor Pack)"], "Music": ["Tuna"],
                                         "Sound": ["Blipper"]})
        self.assertEqual([p["pack"] for p in roll["packs"]], ["Anchor Pack", "Tune Pack", "Blip Pack", "Font Pack"])
        self.assertEqual(len(roll["fonts"]), 1)

    def test_names(self) -> None:
        self.assertEqual(A.primary_name("Juhani Junkala (SubspaceAudio)"), "Juhani Junkala")
        self.assertEqual(A.primary_name("CodeMan38 / The Press Start 2P Project Authors"), "CodeMan38")
        self.assertTrue(A.names_author("Pixel-boy / Sparklin Labs (Superpowers Asset Packs)", "Pixel-boy"))
        self.assertFalse(A.names_author("Pixel-boy and AAA (Ninja Adventure)", "Pixel-boy"))
        self.assertTrue(A.names_author("Pixel-boy and AAA (Ninja Adventure)", "Pixel-boy and AAA"))
        self.assertFalse(A.names_author("Kenneth", "Kenney"))


class StrayFilesImportsFormats(TempProject):
    def test_sound_outside_assets(self) -> None:
        put(self.root, "scripts/ui/click.wav", wav_bytes())
        self.assertEqual(codes(self.root), ["stray-media"])

    def test_font_outside_assets(self) -> None:
        put(self.root, "resources/ui/other.ttf", b"\x00\x01\x00\x00")
        self.assertEqual(codes(self.root), ["stray-media"])

    def test_image_outside_assets(self) -> None:
        put(self.root, "scenes/logo.png", png_bytes())
        self.assertEqual(codes(self.root), ["stray-media"])

    def test_renders_and_ignored_folders_are_fine(self) -> None:
        put(self.root, "docs/art/sheet.png", png_bytes())
        put(self.root, "installer/wizard.png", png_bytes())
        put(self.root, "build/anything/shot.png", png_bytes())
        put(self.root, ".tools/asset_candidates/pack/song.ogg", b"OggS")
        put(self.root, ".godot/imported/x.png", png_bytes())
        self.assertEqual(codes(self.root), [])

    def test_import_file_missing(self) -> None:
        os.remove(os.path.join(self.root, "assets/sprites/hero.png.import"))
        self.assertEqual(codes(self.root), ["import-pair"])

    def test_import_file_left_behind(self) -> None:
        put(self.root, "assets/sprites/gone.png.import", "[remap]\n")
        self.assertEqual(codes(self.root), ["import-pair"])

    def test_content_must_match_the_name(self) -> None:
        for rel, data in (("sprites/hero.png", b"GIF89a" + bytes(40)),
                          ("audio/music/theme_a.ogg", b"ID3" + bytes(80)),
                          ("audio/sfx/jump_a.wav", b"OggS" + bytes(80)),
                          ("fonts/font.ttf", b"wOFF" + bytes(40))):
            with self.subTest(rel=rel):
                root = tempfile.mkdtemp(prefix="audit_assets_")
                self.addCleanup(shutil.rmtree, root, True)
                make_project(root)
                put(root, "assets/" + rel, data)
                self.assertEqual(codes(root), ["format"])

    def test_other_formats_do_not_ship(self) -> None:
        put(self.root, "assets/audio/music/theme_b.mp3", b"ID3" + bytes(80))
        found = codes(self.root)
        self.assertIn("format", found)
        self.assertIn("ledger-missing", found)

    def test_texture_limit(self) -> None:
        put(self.root, "assets/sprites/hero.png", png_bytes(A.MAX_TEXTURE + 1, 1))
        self.assertEqual(codes(self.root), ["texture-size"])
        put(self.root, "assets/sprites/hero.png", png_bytes(A.MAX_TEXTURE, 1))
        self.assertEqual(codes(self.root), [])

    def test_audio_table_names_a_missing_file(self) -> None:
        edit(self.root, "scripts/core/audio_table.gd", '"files": ["jump_a.wav"]', '"files": ["jump_a.wav", "jump_b.wav"]')
        self.assertEqual(codes(self.root), ["audio-table"])

    def test_sound_the_table_does_not_play(self) -> None:
        edit(self.root, "scripts/core/audio_table.gd", '"file": "theme_a.ogg"', '"file": "other_a.ogg"')
        found = [f.text for f in A.audit(self.root, use_git=False)[0] if f.code == "audio-table"]
        self.assertEqual(len(found), 2)  # other_a.ogg does not exist, theme_a.ogg is played by no row

    def test_audio_table_parser(self) -> None:
        table = A.read_audio_table(self.root)
        self.assertEqual(table["jump_a.wav"], {"dir": "sfx", "db": -3.0, "loop": False, "names": ["JUMP"]})
        self.assertEqual(table["theme_a.ogg"], {"dir": "music", "db": -6.0, "loop": True, "names": ["MUSIC_THEME"]})


def has_git() -> bool:
    try:
        return subprocess.run(["git", "--version"], capture_output=True).returncode == 0
    except OSError:
        return False


@unittest.skipUnless(has_git(), "git is not installed")
class SinceTheRelease(TempProject):
    def git(self, *args: str) -> None:
        run = subprocess.run(["git", "-C", self.root, "-c", "user.name=t", "-c", "user.email=t@example.org",
                              "-c", "core.autocrlf=false", "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false"]
                             + list(args), capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)

    def release(self) -> None:
        """Tag the 1.0 files as v1.0.0: everything but the 2.0 files of the fixture."""
        self.git("init", "-q")
        self.git("add", "-A")
        self.git("rm", "-q", "--cached", "assets/audio/sfx/jump_a.wav", "assets/audio/sfx/jump_a.wav.import",
                 "assets/tiles/feast/props/jelly.png", "assets/tiles/feast/props/jelly.png.import",
                 "assets/licenses/blip_pack.txt")
        self.git("commit", "-q", "-m", "1.0.0")
        self.git("tag", A.RELEASE_TAG)

    def test_ledger_agrees_with_the_tag(self) -> None:
        self.release()
        findings, summary = A.audit(self.root, use_git=True)
        self.assertEqual([str(f) for f in findings], [])
        self.assertEqual(summary[3], "3 files since v1.0.0, 10 from 1.0")

    def test_without_a_tag_nothing_is_compared(self) -> None:
        findings, summary = A.audit(self.root, use_git=True)
        self.assertEqual(findings, [])
        self.assertIn("not compared with v1.0.0", summary[3])

    def test_new_file_must_say_2_0(self) -> None:
        self.release()
        edit_ledger_row(self.root, "audio/sfx/jump_a.wav", 1, "1.0")
        self.assertEqual(codes(self.root, use_git=True), ["since"])

    def test_released_file_must_say_1_0(self) -> None:
        self.release()
        edit_ledger_row(self.root, "sprites/hero.png", 1, "2.0")
        self.assertEqual(codes(self.root, use_git=True), ["since"])

    def test_released_art_must_not_change(self) -> None:
        self.release()
        put(self.root, "assets/sprites/hero.png", png_bytes(8, 8))
        self.assertEqual(codes(self.root, use_git=True), ["changed-1.0"])

    def test_released_licence_text_may_change(self) -> None:
        self.release()
        edit(self.root, "assets/licenses/README.md", "# Licences", "# Licences of 2.0")
        self.assertEqual(codes(self.root, use_git=True), [])

    def test_released_file_must_not_vanish(self) -> None:
        self.release()
        os.remove(os.path.join(self.root, "assets/fonts/font.ttf"))
        os.remove(os.path.join(self.root, "assets/fonts/font.ttf.import"))
        found = codes(self.root, use_git=True)
        self.assertIn("changed-1.0", found)
        self.assertIn("ledger-orphan", found)


class RealProject(unittest.TestCase):
    """The project this tool lives in passes its own audit."""

    def test_audit_passes(self) -> None:
        findings, summary = A.audit(A.ROOT)
        self.assertEqual([str(f) for f in findings], [], "\n".join(summary))

    def test_every_licence_is_cc0_or_ofl(self) -> None:
        rows, _ = A.read_ledger(A.ROOT)
        self.assertGreater(len(rows), 800)
        kinds = {row["licence"] for row in rows}
        self.assertEqual(kinds, {A.CC0, A.OFL, A.LICENCE_TEXT, A.OWN_WORK})
        for row in rows:
            if row["licence"] == A.OFL:
                self.assertTrue(row["file"].endswith(".ttf"), row["file"])
            if A.kind_of(row["file"]) in ("music", "sound"):
                self.assertEqual(row["licence"], A.CC0, row["file"])

    def test_the_roll_names_every_2_0_author(self) -> None:
        with open(os.path.join(A.ROOT, A.CREDITS), encoding="utf-8") as handle:
            roll = A.parse_credits(handle.read())
        rows, _ = A.read_ledger(A.ROOT)
        packs = A.read_packs(A.ROOT)
        wanted = {}
        for row in rows:
            kind = A.kind_of(row["file"])
            if row["since"] == "2.0" and kind in A.ROLE_OF_KIND and row["licence"] == A.CC0:
                for name in A.licence_files_of(row):
                    wanted.setdefault(A.ROLE_OF_KIND[kind], set()).add(A.primary_name(packs[name].author))
        self.assertEqual(set(wanted), {"Art", "Music", "Sound"})
        for role, authors in wanted.items():
            for author in sorted(authors):
                self.assertTrue(any(A.names_author(name, author) for name in roll["roles"][role]),
                                "%s is not credited under %s" % (author, role))
        self.assertGreaterEqual(len(roll["packs"]), 40)
        self.assertEqual(len(roll["fonts"]), 2)


def audio_modules() -> bool:
    try:
        import numpy  # noqa: F401
        import pyloudnorm  # noqa: F401
        import scipy  # noqa: F401
        import soundfile  # noqa: F401
    except ImportError:
        return False
    return True


@unittest.skipUnless(audio_modules(), "numpy / soundfile / pyloudnorm / scipy are not installed")
class AudioGates(unittest.TestCase):
    """Synthetic sounds: one clean loop and one clean effect, then one fault each."""

    @classmethod
    def setUpClass(cls) -> None:
        import numpy as np
        import soundfile

        cls.root = tempfile.mkdtemp(prefix="audit_audio_")
        rate = 44100
        os.makedirs(os.path.join(cls.root, "assets/audio/music"))
        os.makedirs(os.path.join(cls.root, "assets/audio/sfx"))

        def tone(seconds: float, level: float = 0.25, hz: float = 220.0):
            t = np.arange(int(seconds * rate)) / rate
            return level * np.sin(2 * np.pi * hz * t)

        def ogg(name: str, data) -> None:
            soundfile.write(os.path.join(cls.root, "assets/audio/music", name), data, rate, format="OGG",
                            subtype="VORBIS")

        def wav(name: str, data) -> None:
            soundfile.write(os.path.join(cls.root, "assets/audio/sfx", name), data, rate, subtype="PCM_16")

        silence = np.zeros(int(0.2 * rate))
        ogg("clean_a.ogg", tone(4.0))                                   # whole periods: a seamless loop
        ogg("gap_a.ogg", np.concatenate([tone(4.0), silence]))          # 200 ms of nothing before it restarts
        ogg("click_a.ogg", tone(4.0 + 0.25 / 220.0, 0.5))               # stops at the top of the wave
        ogg("fade_a.ogg", tone(8.0) * np.concatenate([np.ones(6 * rate), np.linspace(1.0, 0.05, 2 * rate)]))
        ogg("late_jingle_a.ogg", np.concatenate([silence, tone(2.0)]))
        ogg("loud_a.ogg", tone(4.0))                                    # played 6 dB too loud by its row
        wav("clean_a.wav", tone(0.3, 0.5, 880.0))
        wav("late_a.wav", np.concatenate([silence, tone(0.3, 0.5, 880.0)]))
        wav("quiet_a.wav", tone(0.3, 0.02, 880.0))
        wav("hot_a.wav", np.sign(tone(0.3, 1.0, 880.0)))                # a square wave at full scale
        wav("orphan_a.wav", tone(0.3, 0.5, 880.0))                      # no row plays it
        wav("long_a.wav", tone(4.0, 0.5, 880.0))

        def table(db: dict) -> None:
            lines = ["const SFX: Dictionary = {"]
            for name in ("clean_a.wav", "late_a.wav", "quiet_a.wav", "hot_a.wav", "long_a.wav"):
                lines.append('\tSfx.%s: {"files": ["%s"], "db": [%.1f]},' % (name[:-6].upper(), name,
                                                                             db.get(name, -3.0)))
            lines += ["}", "const MUSIC: Dictionary = {"]
            for name in ("clean_a.ogg", "gap_a.ogg", "click_a.ogg", "fade_a.ogg", "late_jingle_a.ogg", "loud_a.ogg"):
                lines.append('\tSfx.MUSIC_%s: {"file": "%s", "db": %.1f, "loop": %s},' % (
                    name[:-6].upper(), name, db.get(name, 0.0), "false" if "jingle" in name else "true"))
            lines.append("}")
            put(cls.root, A.AUDIO_TABLE, "\n".join(lines) + "\n")

        table({})
        with contextlib.redirect_stdout(io.StringIO()):
            first = A.measure_audio(cls.root)
        gains = {r["name"]: round(A.AUDIO_GATES["music_target"] - r["lufs"], 1) for r in first if r["kind"] == "music"}
        gains["loud_a.ogg"] += 6.0
        gains["hot_a.wav"] = 0.0
        table(gains)
        cls.results = A.measure_audio(cls.root)
        cls.outliers = {}
        for name, gate, _why in A.audio_outliers(cls.results):
            cls.outliers.setdefault(os.path.basename(name), set()).add(gate)

    @classmethod
    def tearDownClass(cls) -> None:
        shutil.rmtree(cls.root, True)

    def test_clean_files_pass(self) -> None:
        self.assertNotIn("clean_a.ogg", self.outliers)
        self.assertNotIn("clean_a.wav", self.outliers)

    def test_measures(self) -> None:
        by_name = {r["name"]: r for r in self.results}
        clean = by_name["clean_a.ogg"]
        self.assertAlmostEqual(clean["seconds"], 4.0, places=3)
        self.assertAlmostEqual(clean["peak"], -12.0, delta=0.3)       # a sine at 0.25
        self.assertAlmostEqual(clean["lufs"] + clean["db"], -18.0, delta=0.1)
        self.assertLess(clean["seam_ratio"], 1.5)
        self.assertLess(clean["head"] + clean["tail"], 0.005)
        self.assertAlmostEqual(by_name["gap_a.ogg"]["tail"], 0.2, delta=0.04)  # the codec rings into the gap
        self.assertAlmostEqual(by_name["late_a.wav"]["head"], 0.2, delta=0.001)
        self.assertGreater(by_name["click_a.ogg"]["seam_ratio"], 10.0)
        self.assertAlmostEqual(by_name["quiet_a.wav"]["peak"], -34.0, delta=0.2)
        self.assertGreater(by_name["hot_a.wav"]["full_share"], 0.9)
        self.assertEqual(by_name["hot_a.wav"]["format"], "WAV PCM_16")
        self.assertEqual(clean["format"], "OGG VORBIS")

    def test_each_fault_is_an_outlier(self) -> None:
        self.assertEqual(self.outliers.get("gap_a.ogg"), {"loop-gap"})
        self.assertEqual(self.outliers.get("click_a.ogg"), {"seam-jump"})
        self.assertEqual(self.outliers.get("fade_a.ogg"), {"end-level", "seam-step"})  # and it restarts 26 dB up
        self.assertEqual(self.outliers.get("late_jingle_a.ogg"), {"head"})
        self.assertEqual(self.outliers.get("loud_a.ogg"), {"level"})
        self.assertEqual(self.outliers.get("late_a.wav"), {"head"})
        self.assertEqual(self.outliers.get("quiet_a.wav"), {"low-peak"})
        self.assertEqual(self.outliers.get("hot_a.wav"), {"peak", "full-scale"})
        self.assertEqual(self.outliers.get("orphan_a.wav"), {"table"})
        self.assertEqual(self.outliers.get("long_a.wav"), {"long"})

    def test_run_fails_on_an_open_outlier(self) -> None:
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(A.run_audio(self.root, False), 1)
        self.assertIn("AUDIO AUDIT: FAIL", out.getvalue())


def has_pillow() -> bool:
    try:
        import numpy  # noqa: F401
        from PIL import Image  # noqa: F401
    except ImportError:
        return False
    return True


@unittest.skipUnless(has_pillow(), "Pillow / numpy are not installed")
class StyleNumbers(unittest.TestCase):
    def setUp(self) -> None:
        self.folder = tempfile.mkdtemp(prefix="audit_style_")
        self.addCleanup(shutil.rmtree, self.folder, True)

    def sprite(self, scale: int, outline: tuple) -> dict:
        import random
        from PIL import Image

        random.seed(7)
        small = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
        for x in range(4, 36):
            for y in range(4, 36):
                edge = x in (4, 5, 34, 35) or y in (4, 5, 34, 35)
                small.putpixel((x, y), outline + (255,) if edge else (random.choice((200, 120, 60)), 90, 40, 255))
        path = os.path.join(self.folder, "sprite_%d.png" % scale)
        small.resize((40 * scale, 40 * scale), Image.NEAREST).save(path)
        return A.style_numbers(path)

    def test_pixel_size(self) -> None:
        self.assertEqual(A.pixel_size(self.sprite(1, A.ANCHOR_OUTLINE)), "1x")
        self.assertEqual(A.pixel_size(self.sprite(2, A.ANCHOR_OUTLINE)), "2x")
        self.assertEqual(A.pixel_size(self.sprite(4, A.ANCHOR_OUTLINE)), "4x")

    def test_outline(self) -> None:
        anchor = self.sprite(1, A.ANCHOR_OUTLINE)
        self.assertEqual(anchor["anchor_edge"], 1.0)
        self.assertEqual(anchor["edge_colour"], "#272018")
        self.assertEqual(anchor["outline_px"], 2.0)
        self.assertEqual(self.sprite(2, A.ANCHOR_OUTLINE)["outline_px"], 4.0)
        other = self.sprite(1, (20, 60, 50))
        self.assertEqual(other["anchor_edge"], 0.0)
        self.assertEqual(other["dark_edge"], 1.0)
        self.assertEqual(other["soft"], 0.0)


if __name__ == "__main__":
    unittest.main(verbosity=1)

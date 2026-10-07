"""Consistency tests of the lead designer's documents (docs/spec/**, docs/LEVEL_DESIGN.md, docs/expansion/**).

They pin the decisions written into the specs after gate G1 and phase 2 (DESIGN.md "Appendix: G1 and phase-2
resolutions") against the code that implements them, the phase-3 briefs (DESIGN.md A.6) against GAMEPLAY 13.2, the
music table (LEVEL_DESIGN 15.2) against `Sfx` and the level files, and the request files addressed to the lead
designer against their replies. Standard library only, read-only. Run from the project root:

    python -m unittest discover -s docs/spec -p "test_*.py" -v

A failure means the docs and the code (or a level file) drifted: a *(tune)* value changed in code without its
DESIGN.md / PHYSICS.md record (PLAN.md 2.5), or a designer left a binding brief number.
"""
import glob
import os
import re
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def _read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


DESIGN = _read("docs/expansion/DESIGN.md")
PLAN = _read("docs/expansion/PLAN.md")
PHYSICS = _read("docs/spec/PHYSICS.md")
GAMEPLAY = _read("docs/spec/GAMEPLAY.md")
LEVEL_DESIGN = _read("docs/LEVEL_DESIGN.md")

APPENDIX_C = PHYSICS[PHYSICS.index("## Appendix C - Party and Book II rules"):PHYSICS.index("## Verification log")]
GAMEPLAY_13 = GAMEPLAY[GAMEPLAY.index("## 13. Expansion 2.0"):GAMEPLAY.index("## 14. Items still")]
LEVEL_DESIGN_15 = LEVEL_DESIGN[LEVEL_DESIGN.index("## 15. Co-op and Book II"):]


def _section(text, start, end_pattern=r"\n#{2,4} "):
    """The text from the heading `start` up to the next heading of the given levels."""
    i = text.index(start)
    m = re.compile(end_pattern).search(text, i + len(start))
    return text[i:m.start() if m else len(text)]


def _gd_consts(rel):
    """`const NAME: type = <int literal>` of a GDScript file, as ints (expressions are skipped)."""
    out = {}
    for m in re.finditer(r"^const (\w+)\s*:\s*int\s*=\s*(-?\d+)\b", _read(rel), re.M):
        out[m.group(1)] = int(m.group(2))
    return out


def _table_rows(text, header_start):
    """Rows (lists of stripped cells) of the first markdown table whose header line starts with `header_start`."""
    i = text.index(header_start)
    rows = []
    for line in text[i:].splitlines()[2:]:
        if not line.startswith("|"):
            break
        rows.append([c.strip() for c in line.strip().strip("|").split("|")])
    return rows


class ClassicLayout(unittest.TestCase):
    """[G12] P1 strikes with Left Ctrl in the classic one-keyboard layout, in the code and in every document."""

    def test_the_code_binds_p1_strike_to_ctrl(self):
        src = _read("scripts/core/input_slot.gd")
        m = re.search(r'&"attack":\s*\[\[(\w+)\]', src[src.index("_LEFT_KEYS"):])
        self.assertIsNotNone(m)
        self.assertEqual(m.group(1), "KEY_CTRL")

    def test_the_docs_say_left_ctrl_and_never_left_shift_for_p1(self):
        d11 = _section(DESIGN, "### D.11")
        self.assertIn("strike **Left Ctrl**", d11)
        self.assertIn("little finger on Left Ctrl / Num Enter", d11)
        self.assertIn("Space / Left Ctrl", _section(DESIGN, "### E.9"))
        self.assertIn("strike Left Ctrl", _section(GAMEPLAY_13, "#### 13.9.1"))
        for name, text in (("DESIGN", DESIGN), ("GAMEPLAY 13", GAMEPLAY_13), ("LEVEL_DESIGN 15", LEVEL_DESIGN_15)):
            for bad in ("strike Left Shift", "on Left Shift /", "Space / Left Shift"):
                self.assertNotIn(bad, text, "%s still names Left Shift as P1's strike" % name)


class KeeperHalls(unittest.TestCase):
    """[G4] keeper and Guard halls are 4 rows high everywhere."""

    PATTERN = re.compile(r"3[- ]rows?(?:-high)?\s+(?:high\s+)?halls?|halls?\s+(?:exactly\s+)?\**3 rows|"
                         r"3-row(?:-high)? hall|in a hall \*\*3 rows|halls?\b[^.|;]{0,40}\b3[- ]rows?[- ]high")

    def test_the_constant_is_four(self):
        self.assertEqual(_gd_consts("scripts/core/party_tuning.gd")["KEEPER_HALL_ROWS"], 4)

    def test_no_document_says_three_rows(self):
        for name, text in (("DESIGN", DESIGN), ("GAMEPLAY 13", GAMEPLAY_13), ("LEVEL_DESIGN 15", LEVEL_DESIGN_15)):
            hits = [line for line in text.splitlines() if self.PATTERN.search(line)]
            self.assertEqual(hits, [], "%s: a hall of 3 rows" % name)
        self.assertIn("**4 rows high**", _section(DESIGN, "### D.5"))
        self.assertIn("**4 rows high**", _section(GAMEPLAY_13, "#### 13.9.7"))


class EggIsNoSpringboard(unittest.TestCase):
    """[G1] the hatch bounce is -64 with or without UP; the Shoulder Hop needs an active partner."""

    def test_the_specs(self):
        c12 = _section(APPENDIX_C, "### C.12")
        self.assertIn("bounces **-64**", c12)
        self.assertIn("**whether UP is held\n  or not**", c12)
        self.assertNotIn("-224 with UP, else -64) and hatches", c12)
        c10 = _section(APPENDIX_C, "### C.10")
        self.assertIn("if A holds UP and B is **active**", c10)
        self.assertIn("- **Active**:", c10)
        self.assertIn("**An egg is no springboard** [G1]", _section(DESIGN, "### D.3"))
        self.assertIn("**An egg is no springboard** [G1]", _section(GAMEPLAY_13, "#### 13.9.2"))

    def test_the_bounce_constant(self):
        self.assertEqual(_gd_consts("scripts/core/tuning.gd")["BOUNCE_YVEL"], -64)
        self.assertEqual(_gd_consts("scripts/core/party_tuning.gd")["HATCH_POP_YVEL"], -64)

    def test_the_active_rule_exists_in_code(self):
        self.assertRegex(_read("scripts/world/party_driver.gd"), r"func is_active\(")


class FlowerPot(unittest.TestCase):
    """[G6] the pot spring reaches 6 rows from its root; the open question is closed."""

    def test_every_document_says_six_rows(self):
        self.assertIn("reaches 6 rows from the floor it takes root on", _section(DESIGN, "### D.5"))
        self.assertIn("It reaches 6 rows from the floor it takes root on", _section(GAMEPLAY_13, "#### 13.9.7"))
        self.assertIn("A flower pot reaches 6 rows from the floor it takes root on", LEVEL_DESIGN_15)
        self.assertIn("**It reaches 6 rows from the floor it takes root on**", LEVEL_DESIGN_15)
        self.assertNotIn("Open: a stronger pot spring", LEVEL_DESIGN)
        self.assertNotIn("lead designer to confirm", LEVEL_DESIGN)


class ConstantsMatchCode(unittest.TestCase):
    """The numbers the specs quote equal the constants that implement them (PLAN 2.5: tuning lives in one place and a
    change is recorded in DESIGN.md first). Each row: (spec text that must be present, file, {constant: value})."""

    ROWS = [
        ("| Leash | 121 B / 73 E |", "scripts/core/party_tuning.gd",
         {"LEASH_EGG_TICKS_BEGINNER": 121, "LEASH_EGG_TICKS_EXPERT": 73}),
        ("| Hatch | hearts 2 B / 1 E; shield 44; pop -64;", "scripts/core/party_tuning.gd",
         {"HATCH_HEARTS_BEGINNER": 2, "HATCH_HEARTS_EXPERT": 1, "HATCH_BLINK_TICKS": 44, "HATCH_POP_YVEL": -64}),
        ("| Egg | box 24 x 24; drift 2 (6 beyond 64 px); nudge 1; offset (-24, -48); Expert return 243 at 6 px/tick",
         "scripts/core/party_tuning.gd",
         {"EGG_BOX_W": 24, "EGG_BOX_H": 24, "EGG_DRIFT_PX": 2, "EGG_DRIFT_FAST_PX": 6, "EGG_DRIFT_FAR_PX": 64,
          "EGG_NUDGE_PX": 1, "EGG_OFFSET_X": -24, "EGG_OFFSET_Y": -48, "EGG_RETURN_TICKS_EXPERT": 243,
          "EGG_RETURN_SPEED_PX": 6}),
        ("| Voluntary egg | 24 |", "scripts/core/party_tuning.gd", {"VOLUNTARY_EGG_HOLD_TICKS": 24}),
        ("| Totem | head 35 / rest 34 px; foot reach 16 px; jump-off 16 over the carry; impulses `>> 1`; drop lock 12",
         "scripts/core/party_tuning.gd",
         {"TOTEM_HEAD_PX": 35, "TOTEM_REST_PX": 34, "TOTEM_FOOT_REACH_PX": 16, "TOTEM_JUMP_OFF_YVEL": -16,
          "TOTEM_CARRIER_JUMP_SHIFT": 1, "TOTEM_DROP_LOCK_TICKS": 12}),
        ("| Brace | 16 px apart, heavy dazed 44 |", "scripts/core/party_tuning.gd",
         {"BRACE_GAP_PX": 16, "BRACE_DAZE_TICKS": 44}),
        ("| Curl | 66 ticks, box 24 x 20", "scripts/core/party_tuning.gd",
         {"CURL_MAX_TICKS": 66, "CURL_BOX_W": 24, "CURL_BOX_H": 20}),
        ("| Bat | line +/-144, -128; lob +/-32, -240; grounder +/-96 for 32 ticks", "scripts/core/party_tuning.gd",
         {"BAT_LINE_DRIVE_XVEL": 144, "BAT_LINE_DRIVE_YVEL": -128, "BAT_LOB_XVEL": 32, "BAT_LOB_YVEL": -240,
          "BAT_GROUNDER_XVEL": 96, "BAT_GROUNDER_TICKS": 32}),
        ("| Respawn spread | 24 per slot |", "scripts/core/party_tuning.gd", {"RESPAWN_SPREAD_PX": 24}),
        ("| Lee | 64 px downwind, 16 px vertical", "scripts/world/party_driver.gd",
         {"LEE_REACH_PX": 64, "LEE_DY_PX": 16}),
        ("| Squash / stomp immunity | 8 / 30;", "scripts/core/versus_tuning.gd", {"STOMP_SQUASH_TICKS": 8}),
        ("| Spawn shield / respawn | 48 / 48 |", "scripts/core/versus_tuning.gd", {"SPAWN_SHIELD_TICKS": 48}),
        ("knock-down above 128", "scripts/core/versus_tuning.gd", {"BALL_KNOCKDOWN_SPEED_EXCL": 128}),
    ]
    # Numbers GAMEPLAY 13 / LEVEL_DESIGN 15 quote for the co-op rules (spec text, file, constants).
    GAMEPLAY_ROWS = [
        ("**24 ticks on Beginner, 12 on\n  Expert**", "scripts/core/party_tuning.gd",
         {"WINDOW_TICKS_BEGINNER": 24, "WINDOW_TICKS_EXPERT": 12, "WINDOW_SOLO_MARGIN_TICKS": 4}),
        ("three blips 8 ticks apart", "scripts/core/party_tuning.gd",
         {"COUNT_IN_BEEPS": 3, "COUNT_IN_SPACING_TICKS": 8}),
        ("dazes** it 14 ticks (Beginner) / 12 (Expert)", "scripts/core/party_tuning.gd",
         {"DAZE_TICKS_BEGINNER": 14, "DAZE_TICKS_EXPERT": 12, "DAZE_ALERT_PX": 48}),
        ("a head bounce dazes it 22 ticks", "scripts/enemies/enemy_tuning.gd", {"MIMIC_DAZE_TICKS": 22}),
        ("sticky for `TARGET_HOLD_TICKS` = 22", "scripts/core/party_tuning.gd", {"TARGET_HOLD_TICKS": 22}),
        ("| Boost ledges | 7 tiles | 8 tiles |", "scripts/core/party_tuning.gd",
         {"BOOST_LEDGE_TILES_BEGINNER": 7, "BOOST_LEDGE_TILES_EXPERT": 8}),
    ]

    def _check(self, doc, rows):
        for text, rel, consts in rows:
            self.assertIn(text, doc, "the spec no longer says: %r" % text)
            have = _gd_consts(rel)
            for name, value in consts.items():
                self.assertIn(name, have, "%s: no int constant %s" % (rel, name))
                self.assertEqual(have[name], value, "%s.%s is %s, the spec says %s (%r)"
                                 % (rel, name, have[name], value, text))

    def test_physics_appendix_c(self):
        self._check(APPENDIX_C, self.ROWS)

    def test_gameplay_13(self):
        self._check(GAMEPLAY_13, self.GAMEPLAY_ROWS)


def _music_table():
    """LEVEL_DESIGN 15.2's binding music table: stage id -> context."""
    out = {}
    for row in _table_rows(LEVEL_DESIGN_15, "| Stage | `music` | Stage | `music` |"):
        for ids, ctx in ((row[0], row[1]), (row[2], row[3])):
            for level_id in re.findall(r"`(\w+)`", ids):
                out[level_id] = ctx.strip("`")
    return out


class MusicTable(unittest.TestCase):
    """[G26] the music context of every Book II stage."""

    BOOK2 = ["w5_l1", "w5_l2", "w5_l2b", "w6_l1", "w6_l2", "w6_l2b", "w7_l1", "w7_l2", "w7_l2b", "w8_l1", "w8_l2",
             "w8_l2b", "w9_l1", "w9_l1b", "w9_l2", "w9_l2b", "w9_l3", "bonus_d", "bonus_e", "ending_b"]

    def test_the_table_covers_book_ii_and_names_real_contexts(self):
        table = _music_table()
        self.assertEqual(sorted(table), sorted(self.BOOK2))
        contexts = set(re.findall(r'^const MUSIC_\w+: StringName = &"(\w+)"', _read("scripts/core/sfx.gd"), re.M))
        for level_id, ctx in table.items():
            self.assertIn(ctx, contexts, "%s: no Sfx music context %s" % (level_id, ctx))

    def test_existing_book_ii_files_use_it(self):
        table = _music_table()
        for path in sorted(glob.glob(os.path.join(ROOT, "levels", "*.lvl"))):
            base = os.path.basename(path)[:-4]
            solo = base[:-5] if base.endswith("_coop") else base
            if solo not in table:
                continue
            m = re.search(r"^music\s*=\s*(\w+)", _read(os.path.relpath(path, ROOT)), re.M)
            self.assertIsNotNone(m, "%s sets no music" % base)
            self.assertEqual(m.group(1), table[solo], "%s: music %s, LEVEL_DESIGN 15.2 says %s"
                             % (base, m.group(1), table[solo]))


def _book2_stages():
    """GAMEPLAY 13.2: id -> (difficulty, painting)."""
    out = {}
    for row in _table_rows(GAMEPLAY_13, "| # | Id | Name | Kind, order, links |"):
        out[row[1].strip("`")] = (int(row[5]), int(row[6]))
    return out


def _brief_frame():
    """DESIGN A.6's frame table: id -> dict of its columns."""
    a6 = _section(DESIGN, "### A.6", r"\n### ")
    out = {}
    for row in _table_rows(a6, "| Stage | By | Size"):
        level_id = re.match(r"`(\w+)` (.+)", row[0])
        out[level_id.group(1)] = {"name": level_id.group(2), "by": row[1], "music": row[5], "codes": row[8]}
    return out, a6


class PhaseThreeBriefs(unittest.TestCase):
    """DESIGN A.6: a brief for every stage of worlds 6-9, Feast Land E and the ending, consistent with GAMEPLAY 13.2,
    the music table and the level codes already taken."""

    IDS = ["w6_l1", "w6_l2", "w6_l2b", "w7_l1", "w7_l2", "w7_l2b", "bonus_e", "w8_l1", "w8_l2", "w8_l2b", "w9_l1",
           "w9_l1b", "w9_l2", "w9_l2b", "w9_l3", "ending_b"]
    OWNER = {"w6": "D6", "w7": "D7", "bonus_e": "D7", "w8": "D8", "w9": "D9", "ending_b": "D9"}

    def test_every_stage_has_a_frame_row_by_its_designer(self):
        frame, _a6 = _brief_frame()
        self.assertEqual(list(frame), self.IDS)
        for level_id, row in frame.items():
            owner = self.OWNER.get(level_id, self.OWNER.get(level_id[:2]))
            self.assertEqual(row["by"], owner, level_id)

    def test_music_equals_the_binding_table(self):
        frame, _a6 = _brief_frame()
        table = _music_table()
        for level_id, row in frame.items():
            self.assertEqual(row["music"], table[level_id], level_id)

    def test_difficulty_and_painting_equal_gameplay_13_2(self):
        frame, a6 = _brief_frame()
        stages = _book2_stages()
        for level_id, row in frame.items():
            name = row["name"]
            i = a6.index("%s**" % name, a6.index("**World 6"))
            head = a6[i:i + 160].replace("\n", " ")
            diff, painting = stages[level_id]
            self.assertRegex(head, r"difficulty %d\b" % diff, level_id)
            self.assertRegex(head, r"painting %d\b" % painting, level_id)

    def test_codes_are_well_formed_and_unique(self):
        frame, _a6 = _brief_frame()
        taken = {}
        for path in glob.glob(os.path.join(ROOT, "levels", "*.lvl")):
            base = os.path.basename(path)[:-4]
            for code in re.findall(r'^password_\w+\s*=\s*"(\w*)"', _read(os.path.relpath(path, ROOT)), re.M):
                if code:
                    taken.setdefault(code, set()).add(base)
        seen = set()
        for level_id, row in frame.items():
            for code in [c.strip() for c in row["codes"].split("/")]:
                if code == "-":
                    continue
                self.assertRegex(code, r"^[0-9A-Z]{4}$", level_id)
                self.assertNotIn(code, seen, "%s: code %s twice in A.6" % (level_id, code))
                seen.add(code)
                owners = taken.get(code, set()) - {level_id}
                self.assertEqual(owners, set(), "%s: code %s is taken by %s" % (level_id, code, owners))


class ResolutionMarkers(unittest.TestCase):
    """Every [Gn] marker the documents use has its row in DESIGN.md's appendix, and every row is used."""

    def test_markers_and_rows(self):
        appendix = DESIGN[DESIGN.index("## Appendix: G1 and phase-2 resolutions"):]
        rows = set(re.findall(r"^\| (G\d+) \|", appendix, re.M))
        self.assertEqual(rows, {"G%d" % n for n in range(1, len(rows) + 1)})
        body = DESIGN[:DESIGN.index("## Appendix: G1 and phase-2 resolutions")]
        used = set()
        for text in (body, PHYSICS, GAMEPLAY, LEVEL_DESIGN):
            used |= set(re.findall(r"\[(G\d+)(?: / G\d+)?\]", text))
            used |= set(re.findall(r"\[G\d+ / (G\d+)\]", text))
        self.assertEqual(used - rows, set(), "markers without a row")
        self.assertEqual(rows - used, set(), "rows no document refers to")


class Hygiene(unittest.TestCase):
    def test_the_documents_are_plain_ascii(self):
        for rel in ("docs/expansion/DESIGN.md", "docs/expansion/PLAN.md", "docs/spec/PHYSICS.md",
                    "docs/spec/GAMEPLAY.md", "docs/LEVEL_DESIGN.md"):
            text = _read(rel)
            bad = sorted({c for c in text if ord(c) > 126 or (ord(c) < 32 and c not in "\n\t")})
            self.assertEqual(bad, [], rel)


REQUESTS = os.path.join(ROOT, "build", "engine_requests")


@unittest.skipUnless(os.path.isdir(REQUESTS), "no build/engine_requests in this checkout")
class RequestsAnswered(unittest.TestCase):
    """Every request file addressed to the lead designer ends with a lead-designer reply after its last request."""

    HEADER = re.compile(r"^\[?(?:wf\d+ )?[\w-]+ -> lead[ _-]designer\b", re.M | re.I)

    def test_every_request_has_a_reply(self):
        files = [f for f in glob.glob(os.path.join(REQUESTS, "*.txt"))
                 if re.search(r"_to_lead[-_]designer", os.path.basename(f))]
        self.assertTrue(files)
        for path in files:
            with open(path, encoding="utf-8") as f:
                text = f.read()
            headers = [m.start() for m in self.HEADER.finditer(text)]
            replies = [m.start() for m in re.finditer(r"^REPLY lead designer", text, re.M)]
            self.assertTrue(replies, "%s: no reply" % os.path.basename(path))
            if headers:
                self.assertGreater(replies[-1], headers[-1], "%s: a request after the last reply"
                                   % os.path.basename(path))


if __name__ == "__main__":
    unittest.main()

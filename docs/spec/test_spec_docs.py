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
        self.assertIn("if A or B is **idle**: no head contact at all - A passes through, as heroes do, UP held or not",
                      c10)
        self.assertIn("**Shoulder Hop** if A holds UP and B is **active**", c10)
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
        ("| Brace | 16 px apart, heavy dazed 44 (hurt only then [G57]) |", "scripts/core/party_tuning.gd",
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



# ---------------------------------------------------------------------------------------------------------------------
# Phase-3 rulings (DESIGN.md G33-G56, 2026-10-08)
# ---------------------------------------------------------------------------------------------------------------------

def _pending(case, done, what):
    """A ruling whose code change belongs to another owner: skipped (with the request named) until the code has it,
    asserted from then on. `done` is the condition the owner's change makes true."""
    if not done:
        case.skipTest("pending owner change: " + what)


class IdlePartner(unittest.TestCase):
    """[G33] the orchestrator's idle-partner rule: 243 ticks, counted by no co-op rule, no duo move on an idle hero."""

    def test_every_document_states_the_rule(self):
        d3 = _section(DESIGN, "### D.3")
        self.assertIn("**The idle partner** [G33]", d3)
        self.assertIn("**243 ticks** (10 s)", d3)
        self.assertIn("counts for **no co-op rule**", d3)
        self.assertIn("no Shoulder Hop, no Totem Ride", d3)
        c10 = _section(APPENDIX_C, "### C.10")
        self.assertIn("- **Idle** [G33]", c10)
        self.assertIn("capped at 243 (`IDLE_TICKS`, 10 s)", c10)
        self.assertIn("or K or R is no longer active", c10)
        self.assertIn("**The idle partner** [G33]", _section(GAMEPLAY_13, "#### 13.9.2"))
        self.assertIn("#### 15.7.9 The idle partner (phase 3) [G33]", LEVEL_DESIGN_15)
        self.assertIn("| Idle | 243 ticks without input of his own", _section(APPENDIX_C, "### C.16"))

    def test_no_document_keeps_the_idle_totem_ride(self):
        stale = ("a Totem Ride starts on an idle carrier", "Totem Ride on an idle partner still starts",
                 "carries a Totem Ride\n  without", "whom he\ncan ride", "riding his idle partner")
        for name, text in (("DESIGN", DESIGN[:DESIGN.index("## Appendix: G1 and phase-2 resolutions")]),
                           ("PHYSICS C", APPENDIX_C), ("GAMEPLAY 13", GAMEPLAY_13), ("LEVEL_DESIGN 15", LEVEL_DESIGN_15)):
            for bad in stale:
                self.assertNotIn(bad, text, "%s still says %r" % (name, bad))

    def test_the_code_has_the_shared_query_at_243(self):
        src = _read("scripts/base/player_base.gd")
        self.assertRegex(src, r"func is_idle\(")
        self.assertRegex(src, r"func counts_for_coop\(")
        self.assertEqual(_gd_consts("scripts/base/player_base.gd").get("IDLE_TICKS"), 243)
        party = _gd_consts("scripts/core/party_tuning.gd")
        if "IDLE_TICKS" in party:
            self.assertEqual(party["IDLE_TICKS"], 243)

    def test_the_totem_ride_needs_an_active_carrier_in_code(self):
        src = _read("scripts/world/party_driver.gd")
        head = src[src.index("func _head_contacts"):] if "func _head_contacts" in src else ""
        old_rule = re.search(r"elif a\.holds_up\(\) and not is_active\(b\)", head) is not None
        _pending(self, head and not old_rule,
                 "party / world-A: no Totem Ride on an idle carrier (wf9_lead_design_to_party.txt #1)")
        self.assertNotRegex(head, r"elif a\.holds_up\(\) and not is_active\(b\)")
        self.assertRegex(head, r"\bb\.idle\b", "an idle partner's head must be passed through (G33)")


class BoostLedgeOneHeight(unittest.TestCase):
    """[G28] [G39] boost ledges are 8 rows on both difficulties, in every document and in PartyTuning."""

    def test_the_documents(self):
        self.assertIn("| Boost ledges | 8 tiles [G39] | 8 tiles |", _section(GAMEPLAY_13, "#### 13.9.10"))
        self.assertIn("| Boost ledges | 8 tiles [G28] [G39] | 8 tiles |", _section(DESIGN, "### D.11"))
        self.assertIn("an 8-tile Shoulder Hop ledge with a rolled-vine gift [G28]", _section(DESIGN, "### D.10"))
        for name, text in (("DESIGN", DESIGN), ("GAMEPLAY 13", GAMEPLAY_13)):
            self.assertNotIn("| Boost ledges | 7 tiles", text, name)
            self.assertNotIn("a 7-tile Shoulder Hop ledge", text, name)

    def test_the_constant(self):
        consts = _gd_consts("scripts/core/party_tuning.gd")
        self.assertEqual(consts["BOOST_LEDGE_TILES_EXPERT"], 8)
        _pending(self, consts["BOOST_LEDGE_TILES_BEGINNER"] != 7,
                 "core-A: PartyTuning.BOOST_LEDGE_TILES_BEGINNER = 8 (wf9_lead_design_to_core_a.txt #1)")
        self.assertEqual(consts["BOOST_LEDGE_TILES_BEGINNER"], 8)


class BossCoopForms(unittest.TestCase):
    """[G34] co-op forms by actions; slot-bound twin rules are not capped by the solo minimum."""

    def test_the_rule_and_every_boss(self):
        b0 = _section(DESIGN, "### B.0")
        self.assertIn("**one rule that one player cannot satisfy** [G34]", b0)
        self.assertIn("counts only **active** heroes", b0)
        self.assertIn("an idle hatched partner\n  placed anywhere he could be hatched", b0)
        self.assertIn("by **two different heroes**", _section(DESIGN, "### B.2"))
        self.assertIn("by **two different heroes**", _section(DESIGN, "### B.3"))
        self.assertIn("**by the other hero**", _section(DESIGN, "### B.4"))
        self.assertIn("a hero **other than the pilot**", _section(DESIGN, "### B.5"))
        self.assertIn("an **active** hero\n  other than the smasher", _section(DESIGN, "### B.6"))
        g136 = _section(GAMEPLAY_13, "### 13.6", r"\n### ")
        for text in ("one rule one\n  player cannot satisfy [G34]", "not capped\n  by the measured solo minimum of 10 [G34]",
                     "not capped by the measured solo minimum of 20 [G34]", "**by the other hero**",
                     "a hero other than the pilot strikes its tail", "the nearer active hero"):
            self.assertIn(text, g136)
        self.assertIn("is exempt\n  from the `solo_min - 4` cap", _section(GAMEPLAY_13, "#### 13.9.3"))
        self.assertIn("plus an idle hatched partner placed anywhere he could be hatched (G33)", PLAN)

    def test_the_boss_code_is_slot_bound_where_built(self):
        # Built at G2: Old Mangrove's twin (_twin_half by slot), Inkjaw's flinch slots, the Roc's pilot.
        self.assertIn("_flinch_slot[0] != _flinch_slot[1]", _read("scripts/bosses/squid.gd"))
        self.assertRegex(_read("scripts/bosses/mangrove.gd"), r"func _twin_half\(")
        self.assertRegex(_read("scripts/bosses/roc.gd"), r"slot == _pilot\.slot")


class WeakPointsClearOfTheHud(unittest.TestCase):
    """[G35] the HUD band (ui's fight HUD), the 24 logical px clearance and the arena changes it made."""

    def test_the_rule(self):
        b0 = _section(DESIGN, "### B.0").replace("\n  ", " ")
        self.assertIn("(`Hud.band_rects`)", b0)
        self.assertIn("**55 px** under the view's top, **72 px** in the boss bar's columns", b0)
        self.assertIn("at most 105 px (88 px in the bar's columns) over the floor's top", b0)
        g136 = _section(GAMEPLAY_13, "### 13.6", r"\n### ").replace("\n  ", " ")
        self.assertIn("its top at least 24 px below the band over its columns: 55 px under the view's top, 72 px in "
                      "the bar's columns", g136)
        self.assertIn("**Weak points\n  clear of the HUD** [G35]", _section(LEVEL_DESIGN_15, "### 15.6"))

    def test_the_hud_has_the_band_and_the_clearance(self):
        hud = _read("scripts/ui/hud.gd")
        self.assertRegex(hud, r"static func weak_point_problem\(")
        self.assertRegex(hud, r"func band_rects\(")
        m = re.search(r"^const WEAK_POINT_CLEARANCE: float = ([\d.]+)(\s*\*\s*Tuning\.ART_SCALE)?", hud, re.M)
        self.assertIsNotNone(m)
        art = float(m.group(1)) * (_gd_consts("scripts/core/tuning.gd")["ART_SCALE"] if m.group(2) else 1)
        _pending(self, art != 24.0,
                 "ui: WEAK_POINT_CLEARANCE 48 art px = 24 logical px (reply in wf9_ui_to_lead-designer.txt)")
        self.assertEqual(art, 48.0)

    def test_the_arenas_that_changed(self):
        for name, text in (("DESIGN", DESIGN[:DESIGN.index("## Appendix: G1 and phase-2 resolutions")]),
                           ("GAMEPLAY 13", GAMEPLAY_13)):
            self.assertNotIn("altar 6 tiles up", text, name)
            self.assertNotRegex(text, r"ledges(?: on the left)? at\s+rows 7 and 4", name)
            self.assertNotRegex(text, r"rows 8 and 6", name)
        self.assertIn("ledges on the left at rows 7 and 5, the upper one ending at col 5 [G35]",
                      _section(GAMEPLAY_13, "### 13.6", r"\n### ").replace("\n", " "))
        self.assertIn("root ledges at rows 7 and 5 (the upper one ending at col 5)",
                      _section(DESIGN, "### A.6").replace("\n  ", " "))
        self.assertIn("ledges on the left at rows 7 and 5, the upper one ending at col 5",
                      _section(DESIGN, "### B.2").replace("\n  ", " "))
        self.assertIn("altar 3 tiles up", _section(DESIGN, "### B.6"))

    def test_the_geometry_of_the_built_bosses(self):
        # Weak rectangles relative to the feet point (y up is negative): their top must be at most 105 px over the
        # floor of an 11-row lock (55 px under the view's top), 88 px in the boss bar's columns (72 px), where the
        # centred Roc on its nest is. Tusker / Inkjaw are measured from their feet on the floor or the water surface;
        # the Roc's head band from its feet on the nest (row 8: 32 px over the floor); the Twin Idols' open jaws (the
        # Colossus head, in the walls) from their feet on the floor.
        tusker = re.search(r"TUSKER_HEAD: Rect2i = Rect2i\((-?\d+), (-?\d+),", _read("scripts/bosses/tusker.gd"))
        self.assertLessEqual(-int(tusker.group(2)), 105)
        squid = re.search(r"SQUID_HEAD: Rect2i = Rect2i\((-?\d+), (-?\d+),", _read("scripts/bosses/squid.gd"))
        self.assertLessEqual(-int(squid.group(2)) + 16, 105)
        roc = re.search(r"HEAD_BAND: Rect2i = Rect2i\((-?\d+), (-?\d+),", _read("scripts/bosses/roc.gd"))
        self.assertLessEqual(-int(roc.group(2)) + 32, 88)
        spit = re.search(r"COLOSSUS_HEAD_SPIT: Rect2i = Rect2i\((-?\d+), (-?\d+),",
                         _read("scripts/enemies/enemy_tuning.gd"))
        self.assertLessEqual(-int(spit.group(2)), 105)
        mangrove = _gd_consts("scripts/bosses/mangrove.gd")
        face = re.search(r"MANGROVE_FACE: Rect2i = Rect2i\((-?\d+), (-?\d+),", _read("scripts/bosses/mangrove.gd"))
        top = mangrove["MANGROVE_FACE_RISE"] - int(face.group(2))
        _pending(self, top <= 105, "enemies-B: Old Mangrove's face at most 105 px over the floor (face rise <= 70; "
                 "wf9_lead_design_to_enemies_b.txt #2) - now %d px" % top)
        self.assertLessEqual(top, 105)


class BondsAndCuts(unittest.TestCase):
    """[G36] bonded-pair placement; [G37] cut 2 applied, cut 3 conditional."""

    def test_bonded_pairs(self):
        self.assertIn("**never where one thrown special\n  hits two members in one throw**", LEVEL_DESIGN_15)
        self.assertIn("- **Bonds** (every \"bonded ... pairs\" below) [G36]", _section(DESIGN, "### A.6"))
        self.assertIn("is a\n   build error, not a short window [G36]", _section(DESIGN, "### D.8"))

    def test_cut_list(self):
        self.assertIn("**APPLIED at the start of phase 3**", PLAN)
        self.assertIn("built only once the four remaining launch arenas are done", PLAN)
        self.assertNotIn("tablet table mode on a 9-10 inch tablet", PLAN)
        self.assertIn("hidden from the release menus [G37]", _section(DESIGN, "### D.11"))
        for name, text in (("DESIGN", DESIGN), ("GAMEPLAY 13", GAMEPLAY_13)):
            self.assertNotIn("get **table mode**", text, name)
            self.assertNotIn("two on a tablet in table mode", text, name)
            self.assertNotIn("get the experimental **table mode**", text, name)


class RisingCameraAndLee(unittest.TestCase):
    """[G41] the lee gap; [G42] the footing follow of the rising scroll."""

    def test_the_specs(self):
        c8 = _section(APPENDIX_C, "### C.8")
        self.assertIn("- **Footing follow** [G42]", c8)
        self.assertIn("[G42]", _section(LEVEL_DESIGN_15, "### 15.5"))
        self.assertIn("a croucher\n  is never idle [G41]", _section(APPENDIX_C, "### C.6"))
        # [G55] supersedes G41's gate kind: the lee is a comfort; a gate there is a Brace corridor, a line drive or a hall.
        self.assertIn("| ~~Lee gap~~ | **retired as a gate kind** [G55]", LEVEL_DESIGN_15)
        self.assertIn("a co-op lee is a comfort, not a gate [G55]", LEVEL_DESIGN_15)
        self.assertIn("never a gate - the first hero crosses unsheltered [G55]", _section(APPENDIX_C, "### C.6"))
        self.assertIn("**Superseded by [G55]**: the lee is no gate.", DESIGN)
        self.assertNotIn("else build the fallback, a Brace corridor", LEVEL_DESIGN_15)

    def test_the_footing_follow_is_built_and_the_docs_say_so(self):
        # world-A built G42 in phase 3: the docs no longer keep G32's "every jump lands higher" as a building rule.
        cam = _read("scripts/world/level_camera.gd")
        self.assertRegex(cam, r"var footing_mode: bool")
        self.assertRegex(cam, r"func _note_footing\(")
        self.assertRegex(_read("scripts/world/level.gd"), r"footing_mode = rising")
        self.assertRegex(_read("tests/test_world_book2.gd"), r"func test_the_rising_view_follows_the_footing_not_a_jump")
        c8 = _section(APPENDIX_C, "### C.8")
        self.assertIn("built in phase 3 by world-A: `LevelCamera.footing_mode`", c8)
        self.assertNotIn("Until it is built", c8)
        self.assertIn("never ask a hero to step down more than 2 rows", _section(LEVEL_DESIGN_15, "### 15.5"))
        self.assertNotIn("until the footing follow is built", LEVEL_DESIGN_15)
        self.assertIn("**engine change, built in phase 3 by world-A**", DESIGN)
        self.assertNotIn("Until world-A confirms it, G32 stays", DESIGN)
        self.assertIn("never a jump's apex, so a jump in place lands in view [G42]", GAMEPLAY_13.replace("\n  ", " "))


def _meta(level_id):
    """The [meta] keys of a level file (first value wins)."""
    text = _read("levels/%s.lvl" % level_id)
    out = {}
    in_meta = False
    for line in text.splitlines():
        if line.startswith("["):
            in_meta = line.strip() == "[meta]"
            continue
        m = re.match(r"^(\w+)\s*=\s*(.*?)\s*$", line) if in_meta else None
        if m:
            out.setdefault(m.group(1), m.group(2).strip('"'))
    return out


class BossObjectsAndHumanOnlyArenas(unittest.TestCase):
    """[G49] a boss's own objects are no gate; [G50] arena meta `bots` is cut 4's switch."""

    def test_the_docs(self):
        self.assertIn("A boss's own objects are no gate mechanism [G49]", LEVEL_DESIGN_15)
        self.assertIn("are no gate and carry no tablet [G49]", _section(DESIGN, "### D.8"))
        self.assertIn("| `bots` | a subset of `modes`, or `none` | every mode of `modes` |", LEVEL_DESIGN_15)
        self.assertIn("PLAN cut 4\n  [G50]", _section(LEVEL_DESIGN_15, "### 15.8"))
        self.assertIn("arena meta `bots` leaves the mode out (DESIGN.md G50", PLAN)

    def test_the_colossus_coop_hall_has_its_chains_and_no_tablet(self):
        path = os.path.join(ROOT, "levels", "w4_l2b_coop.lvl")
        _pending(self, os.path.exists(path), "DB3: levels/w4_l2b_coop.lvl (waits for world-B's validator rule G49, "
                 "wf9_db3_to_world_b.txt)")
        text = _read("levels/w4_l2b_coop.lvl")
        self.assertGreaterEqual(len(re.findall(r"^objects/plate\b", text, re.M)), 2, "the visor's two chain plates")
        self.assertNotRegex(text, r"(?m)^objects/x2_tablet\b", "a boss stage's co-op form is its gate: no dummy tablet")

    def test_arena_bots_lists_are_subsets_of_modes(self):
        for path in sorted(glob.glob(os.path.join(ROOT, "levels", "arena_*.lvl"))):
            level_id = os.path.basename(path)[:-4]
            meta = _meta(level_id)
            if "bots" not in meta:
                continue
            modes = set(m.strip() for m in meta.get("modes", "").split(",") if m.strip())
            bots = meta["bots"].strip()
            if bots == "none":
                continue
            self.assertEqual(set(m.strip() for m in bots.split(",")) - modes, set(),
                             "%s: `bots` names a mode outside `modes` [G50]" % level_id)


class PendingOwnerChanges(unittest.TestCase):
    """Phase-3 rulings whose code belongs to an owner who has not built them yet: skipped with the request named
    until the owner's file carries the change, asserted from then on (so the gate table shows what is open)."""

    def test_g33_traits_count_only_active_heroes(self):
        # Until the shell faces the nearer ACTIVE hero, the shell keeper halls are open on the engine (D8's replays):
        # the docs must say so and keep the "a replay wins over a bounded refusal" rule.
        self.assertIn("**A refusal is bounded; a replay wins.**", _section(LEVEL_DESIGN_15, "#### 15.7.6"))
        self.assertIn("are **open on the engine** until `coop_traits.gd`", DESIGN)
        src = _read("scripts/enemies/coop_traits.gd")
        _pending(self, "nearest_coop_hero" in src or "counts_for_coop" in src,
                 "enemies-A (no owner this phase): coop_traits.gd still counts idle heroes - shell bait, lone, "
                 "count-ins (wf9_lead_design_to_enemies_a.txt #1, wf9_party_to_enemies-A.txt)")
        shell = src[src.index("SHELL"):] if "SHELL" in src else src
        self.assertRegex(shell, r"nearest_coop_hero|counts_for_coop")

    def test_g47_the_daze_is_slot_bound(self):
        src = _read("scripts/enemies/coop_traits.gd")
        _pending(self, "G47" in src, "enemies-A (no owner this phase): the daze is not slot-bound yet "
                 "(wf9_lead_design_to_enemies_a.txt #2)")
        self.assertRegex(src, r"slot")

    def test_g45_a_railed_raft_opens_at_the_bank(self):
        src = _read("scripts/objects/raft.gd")
        _pending(self, "G45" in src, "objects-B (no owner this phase): rails open towards a bank; the ride test "
                 "covers the whole fence (wf9_lead_design_to_objects_b.txt)")
        self.assertRegex(src, r"bank")

    def test_g53_an_idle_hero_blocks_no_mover(self):
        self.assertIn("**blocks no mover** [G53]", _section(APPENDIX_C, "### C.10"))
        self.assertIn("an idle body is no doorstop [G53]", GAMEPLAY_13)
        self.assertIn("- **No doorstops** [G53]", LEVEL_DESIGN_15)
        src = _read("scripts/objects/rising_column.gd")
        blocked = src[src.index("func _blocked_below"):] if "func _blocked_below" in src else src
        _pending(self, "counts_for_coop" in blocked or "G53" in src,
                 "objects-A (party): a plate door / slab / boulder does not wait for an idle hero "
                 "(wf9_lead_design_to_party.txt #2)")
        self.assertRegex(src, r"counts_for_coop|G53")

    def test_g54_a_head_is_never_a_step_into_rock(self):
        self.assertIn("- **A head is never a step into rock** [G54]", _section(APPENDIX_C, "### C.10"))
        built = [rel for rel in ("scripts/world/party_driver.gd", "scripts/base/player_base.gd",
                                 "scripts/player/player.gd", "scripts/bosses/chieftain.gd") if "G54" in _read(rel)]
        _pending(self, built != [], "party / player-A and enemies-C: no head lifts a hero into rock "
                 "(wf9_lead_design_to_party.txt #3, wf9_lead_design_to_enemies_c.txt #5)")

    def test_g52_inkjaw_drops_its_key_item_over_an_island(self):
        src = _read("scripts/bosses/squid.gd")
        _pending(self, re.search(r"func _drop_origin\(", src) is not None,
                 "enemies-B: Inkjaw's _drop_origin over the nearest island, a sunk key item back on ground "
                 "(wf9_lead_design_to_enemies_b.txt #3)")
        self.assertIn("[G52]", _section(DESIGN, "### B.0"))

    def test_g56_the_brutes_leaps_are_no_weak_point(self):
        # [G56] no weak point after a lethal blow (every boss); the co-op Brute's 1.0 high jump leaves the den's view:
        # no counted hit from take-off to landing, so G35 holds.
        self.assertIn("all - in both poses it is no weak point [G56]", _section(DESIGN, "### B.7"))
        b0 = _section(DESIGN, "### B.0")
        self.assertIn("**cannot be struck**", b0)
        self.assertIn("A boss after its lethal blow (the death leap or fall) has no weak", b0)
        self.assertIn("so it is no weak point there [G56]. (Every boss: no weak point after its lethal blow.)",
                      GAMEPLAY_13.replace("\n  ", " "))
        src = _read("scripts/bosses/brute.gd")
        test = _read("tests/test_enemies_brute.gd")
        _pending(self, "G56" in src, "enemies-C: the Brute's head rect is empty while DYING (every form) and, in the "
                 "co-op form, in the high jump (no counted hit there); test_enemies_brute pins both poses "
                 "(wf9_db2_to_enemies_c.txt #1 / #2, wf9_lead_design_to_enemies_c.txt #6 / #7)")
        self.assertRegex(test, r"(?s)DYING.*weak_point_problem|weak_point_problem.*DYING")
        self.assertRegex(test, r"(?s)JUMP.*weak_point_problem|weak_point_problem.*JUMP")

    def test_g46_the_roc_cruises_over_one_runway_half(self):
        # Built by enemies-C in phase 3 (roc.gd, test_enemies_roc.gd); DESIGN G46 says so.
        src = _read("scripts/bosses/roc.gd")
        self.assertIn("G46", src)
        self.assertRegex(_read("tests/test_enemies_roc.gd"), r"(?s)cruise.*weak_point_problem|weak_point_problem.*cruise")
        self.assertIn("Built in phase 3 by enemies-C (`roc.gd`", DESIGN)


def _arena_geometry_from_file(level_id):
    """Rows of an arena file's tiles reduced to collision: solid '#', one-way '-', liquid '~', else '.'."""
    text = _read("levels/%s.lvl" % level_id)
    legend = {}
    in_legend = False
    for line in text.splitlines():
        if line.startswith("["):
            in_legend = line.strip() == "[legend]"
            continue
        m = re.match(r"^(\S)\s*=\s*.*?\btile=(\S)", line) if in_legend else None
        if m:
            legend[m.group(1)] = m.group(2)
    tiles = text[text.index("[tiles]") + len("[tiles]"):]
    tiles = tiles[:tiles.index("\n[")]
    rows = [r for r in tiles.splitlines()[1:] if r.strip()]
    return [_reduce("".join(legend.get(c, c) for c in r)) for r in rows]


def _reduce(row):
    out = []
    for c in row:
        if c in "#%?*":
            out.append("#")
        elif c in "-=":
            out.append("-")
        elif c == "~":
            out.append("~")
        else:
            out.append(".")
    return "".join(out)


def _arena_sketch(name):
    """E.5's sketch of an arena (the code block after its bold name) reduced like the file."""
    e5 = _section(DESIGN, "### E.5", r"\n### ")
    i = e5.index("\n**%s** (" % name)
    block = e5[e5.index("```", i) + 3:]
    block = block[:block.index("```")]
    rows = []
    for line in block.splitlines():
        m = re.match(r"^row\s+\d+\s+(\S{20})", line)
        if m:
            rows.append(_reduce(m.group(1).replace("G", ".")))
    return rows


class ArenasAsBuilt(unittest.TestCase):
    """[G31] [G43] E.5 draws the arenas DA built at G2: the sketch's collision equals the level file's."""

    ARENAS = {"Totem Ring": "arena_totem_ring", "Cinder Pit": "arena_cinder_pit", "Echo Hollow": "arena_echo_hollow",
              "Coconut Cove": "arena_coconut_cove", "Sky Picnic": "arena_sky_picnic",
              "Colossus Hall": "arena_colossus_hall", "Floe Rink": "arena_floe_rink",
              "Tar Pulleys": "arena_tar_pulleys"}

    def test_sketches_equal_the_files(self):
        for name, level_id in self.ARENAS.items():
            sketch = _arena_sketch(name)
            built = _arena_geometry_from_file(level_id)
            self.assertEqual(len(sketch), 12, name)
            self.assertEqual(sketch, built, "%s: E.5 and levels/%s.lvl differ (update the sketch) [G43]"
                             % (name, level_id))

    def test_floe_rink_has_no_see_saw_while_bots_cannot_ride_one(self):
        # [G51] the fixed floes; a see-saw may return only with both ends over standable ground.
        text = _read("levels/arena_floe_rink.lvl")
        self.assertNotRegex(text, r"(?m)^objects/seesaw\b")
        self.assertIn("[G51]", _section(DESIGN, "### E.5", r"\n### "))

    def test_colossus_hall_modes(self):
        row = [r for r in _table_rows(_section(DESIGN, "### E.5", r"\n### "), "| # | Arena |") if "Colossus Hall" in r[1]][0]
        self.assertIn("no Hot Rock, no Clubball", row[6])
        path = os.path.join(ROOT, "levels", "arena_colossus_hall.lvl")
        if os.path.exists(path):
            m = re.search(r"^modes\s*=\s*(\S+)", _read("levels/arena_colossus_hall.lvl"), re.M)
            if m:
                self.assertEqual(set(m.group(1).split(",")) - {"grub_stack", "last_caveman"}, set(),
                                 "Colossus Hall offers a mode G43 excludes")


# ---------------------------------------------------------------------------------------------------------------------
# The G3 follow-up round (DESIGN.md G57-G62, 2026-10-08, build/engine_requests/wf10_lead_design_to_*.txt)
# ---------------------------------------------------------------------------------------------------------------------

def _po_entries(rel):
    """msgid -> msgstr of a .po file (single-line entries, as the level locale files are written)."""
    out = {}
    msgid = None
    for line in _read(rel).splitlines():
        m = re.match(r'^msgid "(.*)"$', line)
        if m:
            msgid = m.group(1)
            continue
        m = re.match(r'^msgstr "(.*)"$', line)
        if m and msgid:
            out[msgid] = m.group(1)
            msgid = None
    return out


class HeavyKeepersAndOneHitPerStrike(unittest.TestCase):
    """[G57] a heavy is hurt only while brace-dazed; in co-op files one strike hurts a given enemy once."""

    def test_the_documents(self):
        self.assertIn("it can be **damaged only while so dazed**", _section(DESIGN, "### D.6"))
        self.assertIn("**One hit per strike** [G57]", _section(DESIGN, "### D.6"))
        self.assertIn("the only time anyone can hurt a heavy [G57]", _section(DESIGN, "### D.4"))
        c10 = _section(APPENDIX_C, "### C.10")
        self.assertIn("**A heavy takes damage only during that daze** [G57]", c10)
        self.assertIn("- **One hit per strike** (co-op files only) [G57]", c10)
        self.assertIn("it is **damaged only while so dazed**", _section(GAMEPLAY_13, "#### 13.9.5"))
        self.assertIn("**One hit per strike** [G57]", _section(GAMEPLAY_13, "#### 13.9.4"))
        self.assertIn("**The brace is the only way to hurt it** [G57]", _section(LEVEL_DESIGN_15, "#### 15.7.3"))
        self.assertIn("- **`hp` counts strikes in co-op files** [G57]", _section(LEVEL_DESIGN_15, "#### 15.7.5"))
        for name, text in (("DESIGN", DESIGN), ("GAMEPLAY 13", GAMEPLAY_13)):
            self.assertNotIn("| `heavy` (heavy) | front hits glance", text, name)
            self.assertNotIn("| `heavy` | front hits glance", text, name)

    def test_the_code(self):
        sources = "".join(_read(rel) for rel in ("scripts/base/enemy_base.gd", "scripts/enemies/coop_traits.gd"))
        _pending(self, "G57" in sources, "enemies-A: a heavy glances unless brace-dazed; one hit per strike in co-op "
                 "files (wf10_lead_design_to_enemies_a.txt #1)")
        self.assertRegex(sources, r"(?i)brace")


class IdleWarningAndPlateSigns(unittest.TestCase):
    """[G58] held keys count every tick; the "Zzz soon" bubble from tick 170; plate signs say crouch; 243 stays."""

    PLATE_SIGNS = {
        "locale/levels/en/coop_b1.po": ["SIGN_COOP_W1_PLATES", "SIGN_COOP_W2_HATCH"],
        "locale/levels/en/coop_b2.po": ["SIGN_COOP_W2_LIFT", "SIGN_COOP_W3_CAVE"],
        "locale/levels/en/coop_b3.po": ["SIGN_COOP_W4_PLATES", "SIGN_COOP_W4_VISOR"],
        "locale/levels/en/w5.po": ["SIGN_W5_COOP_PLATES", "SIGN_W5_COOP_SANDGATE"],
        "locale/levels/en/w7.po": ["SIGN_W7_COOP_PLATES", "SIGN_W7_COOP_SEAGATE"],
        "locale/levels/en/w8.po": ["SIGN_W8_COOP_STAIRS", "SIGN_W8_COOP_ROOMS"],
    }

    def test_the_documents(self):
        d3 = _section(DESIGN, "### D.3")
        self.assertIn("**A held key is input on every tick it is held** [G58]", d3)
        self.assertIn("From his **170th** quiet tick a **\"Zzz soon\"\n  warning bubble**", d3)
        self.assertIn("**\"Crouch on\n  a plate to hold it\"** [G58]", d3)
        c10 = _section(APPENDIX_C, "### C.10")
        self.assertIn("**A held flag is input on every tick it is held**", c10)
        self.assertIn("`input_idle_ticks >= 170` (`IDLE_WARN_TICKS`)", c10)
        self.assertIn("\"Zzz soon\" bubble from 170, Zzz from 243 [G58]", _section(APPENDIX_C, "### C.16"))
        self.assertIn("**a held key counts on every tick it is held** [G58]", _section(GAMEPLAY_13, "#### 13.9.2"))
        self.assertIn("- **Plate signs say \"crouch\"** [G58]", _section(LEVEL_DESIGN_15, "### 15.6"))
        self.assertIn("- **The warning** [G58]", _section(LEVEL_DESIGN_15, "#### 15.7.9"))

    def test_held_keys_count_every_tick_in_code(self):
        src = _read("scripts/base/player_base.gd")
        body = src[src.index("func note_own_input"):]
        body = body[:body.index("\nfunc ")]
        self.assertRegex(body, r"if flags != 0:\s*\n\s*input_idle_ticks = 0")
        self.assertEqual(_gd_consts("scripts/base/player_base.gd").get("IDLE_TICKS"), 243)

    def test_the_warning_bubble_in_code(self):
        party = _gd_consts("scripts/core/party_tuning.gd")
        src = _read("scripts/player/hero_party.gd")
        _pending(self, "IDLE_WARN" in src or "G58" in src, "party: the \"Zzz soon\" bubble from the 170th quiet tick "
                 "(wf10_lead_design_to_party.txt #1)")
        if "IDLE_WARN_TICKS" in party:
            self.assertEqual(party["IDLE_WARN_TICKS"], 170)
        self.assertEqual(party.get("IDLE_TICKS", 243), 243)

    def test_plate_signs_say_crouch(self):
        stale = []
        for rel, keys in self.PLATE_SIGNS.items():
            entries = _po_entries(rel)
            for key in keys:
                self.assertIn(key, entries, "%s: %s is gone - update this table" % (rel, key))
                if "rouch" not in entries[key]:
                    stale.append(key)
        _pending(self, not stale, "the locale owners: plate signs still without \"crouch\": %s "
                 "(wf10_lead_design_to_designers.txt #1)" % ", ".join(stale))


class RefusalsNameTheirEvidence(unittest.TestCase):
    """[G59] refused = exhaustive, or bounded with every probe of the gate's kind; else unproven."""

    def test_the_documents(self):
        ld = _section(LEVEL_DESIGN_15, "#### 15.7.6")
        self.assertIn("**\"Refused\" names its evidence** [G59]", ld)
        for verdict in ("| **refused (exhaustive)** |", "| **refused (bounded)** |", "| **unproven** |", "| **open** |"):
            self.assertIn(verdict, ld)
        for probe in ("**hop-over**", "**charge-under**", "**idle-bait**", "**thrown-special**", "**plates**"):
            self.assertIn(probe, ld)
        self.assertIn("**\"Refused\" names its evidence** [G59]", _section(DESIGN, "### D.8"))
        self.assertIn("**A refusal names its evidence**", PLAN)
        self.assertIn("at least **660 resting points, uncached**", ld)


class CutThreeApplied(unittest.TestCase):
    """[G60] 8 arenas, the painting ladder, Echo Hollow, Floe Rink and Tar Pulleys as decided."""

    LADDER = [("patterns", 5), ("loincloths", 10), ("variants", 15), ("spear_party", 20), ("gold", 25), ("mural", 30)]

    def test_the_documents(self):
        self.assertIn("### E.5 Arenas: 8 single screens (cut 3 applied [G60])", DESIGN)
        self.assertIn("**APPLIED after G3**", PLAN)
        for text in (_section(DESIGN, "### C.9"), _section(GAMEPLAY_13, "### 13.7")):
            flat = text.replace("\n  ", " ")
            self.assertIn("5 = four loincloth patterns for P1-P4", flat)
            self.assertIn("20 = variant Spear Party", flat)
            self.assertIn("25 = the golden loincloth palette", flat)
            self.assertNotIn("Mesa Rodeo arena;", flat)
            self.assertNotIn("20 = Cloud Top", flat)
        self.assertIn("Eight single-screen arenas", _section(GAMEPLAY_13, "#### 13.10.9"))
        self.assertNotIn("Ten single-screen arenas", GAMEPLAY_13)
        self.assertIn("- **The 8 arenas of 2.0** [G37] [G60]", _section(LEVEL_DESIGN_15, "### 15.8"))

    def test_the_arena_files(self):
        for cut in ("arena_mesa_rodeo", "arena_cloud_top"):
            self.assertFalse(os.path.exists(os.path.join(ROOT, "levels", cut + ".lvl")), "%s is cut [G60]" % cut)
        self.assertEqual(_meta("arena_floe_rink").get("modes"), "grub_stack", "Floe Rink ships Grub Stack only")
        echo = _read("levels/arena_echo_hollow.lvl")
        self.assertNotIn("regrow", _meta("arena_echo_hollow"), "Echo Hollow's regrowing walls are dropped")
        self.assertNotRegex(echo, r"(?m)^enemies/", "Echo Hollow's dangler springboard is dropped")
        tar = _meta("arena_tar_pulleys")
        if tar.get("bots", "") != "none":
            # Bots only on green pulley links (core-B): the modes it names must be a subset of its modes.
            modes = set(tar.get("modes", "").split(","))
            self.assertEqual(set(tar.get("bots", tar.get("modes", "")).split(",")) - modes, set())

    def test_the_reward_table_in_code(self):
        table = _read("scripts/core/unlock_table.gd")
        _pending(self, "arena_mesa_rodeo" not in table and "arena_cloud_top" not in table,
                 "core-A: the painting ladder of G60 (wf10_lead_design_to_core_a.txt #1)")
        rewards = table[table.index("const REWARDS"):]
        ids = re.findall(r'\{"id": &"(\w+)"', rewards[:rewards.index("\n]")])
        self.assertEqual(ids, [r for r, _n in self.LADDER])
        self.assertNotIn("arena_", rewards[:rewards.index("\n]")])

    def test_the_pattern_tags(self):
        data = _read("assets/sprites/player/palettes/hero_palettes.json")
        tags = dict(re.findall(r'"name"\s*:\s*"(\w+)"[^}]*?"unlock"\s*:\s*"(\w+)"', data))
        _pending(self, tags.get("checks") == "paintings_5", "art-A: checks, dots, tiger, pinstripes tagged "
                 "paintings_5 (wf10_lead_design_to_art_a.txt #1)")
        for name in ("checks", "dots", "tiger", "pinstripes"):
            self.assertEqual(tags.get(name), "paintings_5", name)
        for name in ("diamonds", "waves", "sash", "trim"):
            self.assertEqual(tags.get(name), "paintings_10", name)


class CoopBossBalance(unittest.TestCase):
    """[G61] every co-op fight 45-90 s on its recorded routes, at most 6 hurts on Expert; the baseline table."""

    def test_the_documents(self):
        b0 = _section(DESIGN, "### B.0").replace("\n  ", " ")
        self.assertIn("lasts **45-90 s** (1 093-2 185 ticks)", b0)
        self.assertIn("costs **at most 6 hurts** on its Expert route", b0)
        rows = _table_rows(_section(DESIGN, "### B.0"), "| Co-op form (stage) |")
        self.assertEqual([r[0].split(" (")[0] for r in rows],
                         ["Brute", "visor Colossus", "Tusker", "Old Mangrove", "Inkjaw", "Twin Idols", "Storm Roc",
                          "Rival Chieftains"])
        self.assertIn("**Balance** [G61]", _section(GAMEPLAY_13, "### 13.6", r"\n### "))
        self.assertIn("| Co-op boss fights | 45-90 s", _section(GAMEPLAY_13, "### 13.11"))


class DeviationsReviewed(unittest.TestCase):
    """[G62] the four deviations accepted; Chomper two seats is no gate kind; the files carry the gates named."""

    def test_the_documents(self):
        appendix = DESIGN[DESIGN.index("## Appendix: G1 and phase-2 resolutions"):]
        row = [line for line in appendix.splitlines() if line.startswith("| G62 |")][0]
        self.assertIn("**all four accepted**", row)
        for gate in ("'cliff'", "'root'", "'dune'", "'seagate'"):
            self.assertIn(gate, row)
        self.assertIn("~~Chomper two-seat stretch~~", _section(DESIGN, "### D.8"))
        self.assertIn("| ~~Chomper two seats~~ | **retired as a gate kind** [G62]", LEVEL_DESIGN_15)
        d10 = _section(DESIGN, "### D.10")
        for gate in ("('root'", "('dune'", "('seagate')"):
            self.assertIn(gate, d10)

    def test_the_files(self):
        for level_id, gate in (("w4_l1_coop", "cliff"), ("w6_l1_coop", "root"), ("w7_l1_coop", "dune"),
                               ("w7_l2_coop", "seagate")):
            self.assertRegex(_read("levels/%s.lvl" % level_id), r"(?m)^objects/x2_tablet .*\bgate=%s\b" % gate)
        self.assertNotRegex(_read("levels/w7_l1_coop.lvl"), r"(?m)^objects/(mount|rex_pen)\b")
        self.assertRegex(_read("levels/w6_l1_coop.lvl"), r"(?m)^objects/mount .*\bwild\b")


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

    HEADER = re.compile(r"^\[?(?:wf\d+ )?[\w-]+(?: \([^)]*\))? -> lead[ _-]design(?:er)?\b", re.M | re.I)

    def test_every_request_has_a_reply(self):
        files = [f for f in glob.glob(os.path.join(REQUESTS, "*.txt"))
                 if re.search(r"_to_lead[-_]design(?:er)?\.txt$", os.path.basename(f))]
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

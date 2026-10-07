"""Tests of art-A's phase-2 art (PLAN P2.11): the Far Shore map page, the Cave Painting slab / mural / pictures /
unlock icons, the versus who-is-who and screen art, the hit sparks, the Feast Land D / E skins, the world 6-9 object
skins and the staged arena frames - each against its registry row and the contract the game code reads (cell
layouts, colour rows in UiPlayers order, the ids of PlayerRun / Save, ui-B's sundial frames). Run with the project
venv from the project root:

    .tools/venv/Scripts/python.exe -m unittest discover -s docs/art/expansion/pipeline -p "test_*.py" -v

Read-only: nothing under assets/ or docs/ is written (builders are only called in memory).
"""
import json
import os
import re
import sys
import unittest

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
ASSETS = os.path.join(ROOT, "assets")
HANDOVER = os.path.join(ROOT, ".tools", "asset_candidates", "expansion", "_handover")

with open(os.path.join(HERE, "registry_expansion.json"), encoding="utf-8") as _f:
    REG = json.load(_f)
ROWS = {k: v for k, v in REG.items() if k.startswith("assets/")}
OUTLINE = (0x27, 0x20, 0x18)
with open(os.path.join(ASSETS, "sprites", "player", "palettes", "hero_palettes.json"), encoding="utf-8") as _f:
    PAL = json.load(_f)["palettes"]


def img(rel):
    return np.array(Image.open(os.path.join(ROOT, *rel.split("/"))).convert("RGBA"))


def cells(rel):
    e = ROWS[rel]
    a = img(rel)
    fw, fh = e["frame"]
    gc, gr = e["grid"]
    return [a[r * fh:(r + 1) * fh, c * fw:(c + 1) * fw] for r in range(gr) for c in range(gc)]


def colour_set(a):
    px = a[a[..., 3] > 0][:, :3]
    return {tuple(int(v) for v in c) for c in np.unique(px, axis=0)} if len(px) else set()


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def source(rel):
    with open(os.path.join(ROOT, *rel.split("/")), encoding="utf-8") as f:
        return f.read()


def ui_colour_order():
    """UiPlayers.PALETTE_COLOURS keys in declaration order (scripts/ui/ui_players.gd)"""
    text = source("scripts/ui/ui_players.gd")
    block = text[text.index("const PALETTE_COLOURS"):]
    block = block[:block.index("}")]
    return re.findall(r'&"([a-z]+)":', block)


def gd_ids(rel, const):
    text = source(rel)
    block = text[text.index("const %s" % const):]
    block = block[:block.index("\n]")]
    return re.findall(r'"id": &"([a-z_]+)"', block)


# ---------------------------------------------------------------------------------------------------- map page
class FarShoreMap(unittest.TestCase):
    REL = "assets/ui/world_map_far_shore.png"

    def test_page_is_the_1_0_size_and_opaque(self):
        a = img(self.REL)
        self.assertEqual(a.shape[:2], (360, 1280))
        self.assertEqual(int(a[..., 3].min()), 255)

    def test_sky_and_sea_are_the_1_0_maps(self):
        """away from every island the page is pixel for pixel the 1.0 map's sky and sea (the same pieces)"""
        import build_far_shore
        bare = np.array(build_far_shore.sky_and_sea())
        a = img(self.REL)
        for x0, y0, x1, y1 in ((0, 290, 1280, 360), (300, 0, 900, 60)):
            np.testing.assert_array_equal(a[y0:y1, x0:x1], bare[y0:y1, x0:x1], err_msg=str((x0, y0)))

    def test_every_book_two_stop_stands_on_land(self):
        import build_far_shore
        bare = np.array(build_far_shore.sky_and_sea())
        a = img(self.REL)
        mk = ROWS[self.REL]["markers"]
        want = ["%d-%d" % k for k in ((5, 1), (5, 2), (6, 1), (6, 2), (7, 1), (7, 2), (8, 1), (8, 2), (9, 1), (9, 2),
                                      (9, 3))]
        self.assertEqual(sorted(mk), want)
        for name, (x, y) in mk.items():
            patch = a[y - 2:y + 3, x - 2:x + 3]
            self.assertFalse((patch == bare[y - 2:y + 3, x - 2:x + 3]).all(), "%s is on the bare sea / sky" % name)
            self.assertTrue(12 <= x <= 1268 and y + 24 <= 360, name)
        pts = [tuple(v) for v in mk.values()]
        for i in range(len(pts)):
            for j in range(i + 1, len(pts)):
                self.assertGreaterEqual(np.hypot(pts[i][0] - pts[j][0], pts[i][1] - pts[j][1]), 56, (pts[i], pts[j]))

    def test_the_sea_under_the_islands_stays_free_for_the_screen_slab(self):
        mk = ROWS[self.REL]["markers"]
        self.assertLessEqual(max(y for _, y in mk.values()), 238)

    def test_the_registry_markers_are_what_the_builder_places(self):
        import build_far_shore
        build_far_shore.build_map(write=False)
        self.assertEqual({"%d-%d" % k: list(v) for k, v in build_far_shore.MARKERS.items()},
                         ROWS[self.REL]["markers"])

    def test_the_page_is_what_the_builder_makes(self):
        import build_far_shore
        np.testing.assert_array_equal(img(self.REL), np.array(build_far_shore.build_map(write=False)))

    def test_the_mesa_rises_out_of_its_island(self):
        """the mesa is cut out of art-B's layer above its base: every column of its foot ends behind the island
        (no straight bottom edge floating over the sea)"""
        import build_far_shore as b
        mesa = np.array(b.mesa_piece())
        isle = np.array(b.island("mesa"))
        ox, oy = b.MESA_ON_ISLE
        last = mesa.shape[0] - 1
        feet = np.nonzero(mesa[last, :, 3])[0]
        self.assertGreater(len(feet), 100)
        for c in feet:
            ix, iy = c + ox, last + oy
            self.assertTrue(0 <= ix < isle.shape[1] and 0 <= iy < isle.shape[0] and isle[iy, ix, 3] > 0,
                            "mesa column %d ends in front of the sea" % c)

    def test_the_coral_stacks_have_no_cut_flank(self):
        """the coral group behind 7's isle is cut out of a wider rock group: its left flank slopes down to the foam
        (no rock in the cut column, the rock top falling at most 2 rows per column towards it)"""
        import build_far_shore as b
        piece = np.array(b.slope_left(b.rocks("coast", True).crop((b.COAST_CUT, 0, 214, 52)), b.COAST_SLOPE,
                                      *b.COAST_ROCK_ROWS))
        rock = hexrgb(b.ROCK_SKINS["coast"][b.I_GREY])
        is_rock = np.all(piece[..., :3] == rock, axis=-1) & (piece[..., 3] > 0)
        self.assertFalse(is_rock[:, 0].any())
        tops = [int(np.nonzero(is_rock[:, c])[0].min()) for c in range(1, b.COAST_SLOPE + 1)
                if is_rock[:, c].any()]
        self.assertGreater(len(tops), b.COAST_SLOPE - 2)
        for t0, t1 in zip(tops, tops[1:]):
            self.assertTrue(0 <= t0 - t1 <= 2, tops)


# ---------------------------------------------------------------------------------------------------- paintings
PIGMENTS = {hexrgb(h) for h in ("#b64e13", "#793a15", "#3f2a1c", "#fef8e8", "#c98a2b", "#8c5a1c")}


class Paintings(unittest.TestCase):
    def test_mural_pieces_tile_the_mural_and_each_shows_paint(self):
        e = ROWS["assets/ui/mural.png"]
        pw, ph = e["pieces"]["size"]
        gc, gr = e["pieces"]["grid"]
        self.assertEqual([pw * gc, ph * gr], e["size"])
        self.assertEqual(gc * gr, 30)
        a = img("assets/ui/mural.png")
        self.assertEqual(int(a[..., 3].min()), 255)
        for i in range(30):
            px, py = (i % gc) * pw, (i // gc) * ph
            piece = a[py:py + ph, px:px + pw, :3].reshape(-1, 3)
            painted = sum(1 for c in piece if tuple(int(v) for v in c) in PIGMENTS)
            self.assertGreaterEqual(painted, 12, "mural piece %d shows almost no painting" % i)

    def test_slab_sockets_hold_the_pieces_and_the_carved_marks(self):
        e = ROWS["assets/ui/painting_slab.png"]
        me = ROWS["assets/ui/mural.png"]
        pw, ph = me["pieces"]["size"]
        mx, my = e["mural_at"]
        sw, sh = e["size"]
        self.assertTrue(mx + 6 * pw <= sw and my + 5 * ph <= sh)
        slab = img("assets/ui/painting_slab.png")
        area = slab[my:my + 5 * ph, mx:mx + 6 * pw, :3].reshape(-1, 3)
        self.assertFalse(any(tuple(int(v) for v in c) in PIGMENTS - {hexrgb("#fef8e8")} for c in area),
                         "empty sockets show no paint")
        icons = img("assets/ui/unlock_icons.png")
        for k, (ix, iy) in enumerate(e["icons"]):
            locked = icons[0:24, k * 24:k * 24 + 24]
            m = locked[..., 3] > 0
            np.testing.assert_array_equal(slab[iy:iy + 24, ix:ix + 24][m], locked[m], err_msg="mark %d" % k)
            self.assertTrue(ix + 24 <= sw and iy + 24 <= sh)
        px, py, pw_, ph_ = e["plate"]
        self.assertTrue(px + pw_ <= sw and py + ph_ <= sh)

    def test_unlock_icons_follow_the_save_rewards(self):
        text = source("scripts/core/save.gd")
        block = text[text.index("const UNLOCK_PAINTINGS"):]
        block = block[:block.index("}")]
        order = re.findall(r"^\s+UNLOCK_([A-Z_]+):", block, re.M)
        names = {m.group(1): m.group(2) for m in re.finditer(r'const UNLOCK_([A-Z_]+): StringName = &"([a-z_]+)"',
                                                               text)}
        self.assertEqual(ROWS["assets/ui/unlock_icons.png"]["columns"], [names[o] for o in order])
        cs = cells("assets/ui/unlock_icons.png")
        for k in range(6):
            self.assertFalse(np.array_equal(cs[k], cs[6 + k]), k)
            self.assertIn(hexrgb("#f3aa39"), colour_set(cs[6 + k]), "unlocked %d has the gold ring" % k)

    def test_thirty_painting_pictures_ochre_on_transparent(self):
        e = ROWS["assets/ui/paintings.png"]
        self.assertEqual(e["frame"], [32, 32])
        self.assertEqual(e["grid"], [30, 1])
        self.assertEqual([t["index"] for t in e["themes"]], list(range(30)))
        cs = cells("assets/ui/paintings.png")
        seen = set()
        for i, c in enumerate(cs):
            self.assertEqual(int(c[0, :, 3].max()) + int(c[:, 0, 3].max()), 0, "%d: transparent ground" % i)
            self.assertGreaterEqual(int((c[..., 3] > 0).sum()), 20, i)
            self.assertTrue(colour_set(c) <= PIGMENTS, "%d: pigments only" % i)
            key = c.tobytes()
            self.assertNotIn(key, seen, "%d repeats another picture" % i)
            seen.add(key)


# ---------------------------------------------------------------------------------------------------- versus
class VersusPictures(unittest.TestCase):
    def test_colour_rows_follow_ui_players(self):
        order = ui_colour_order()
        self.assertEqual(order, ["yellow", "blue", "pink", "green", "white", "gold"])
        for rel in ("assets/ui/portraits.png", "assets/ui/portrait_heads.png", "assets/ui/versus_plate.png",
                    "assets/ui/cave_paint_heroes.png", "assets/sprites/fx/hit_stars_players.png"):
            self.assertEqual(ROWS[rel]["rows"], order, rel)

    def test_portraits_wear_their_colour_with_three_expressions(self):
        for rel in ("assets/ui/portraits.png", "assets/ui/portrait_heads.png"):
            e = ROWS[rel]
            self.assertEqual(e["columns"], ["normal", "ouch", "cheer"])
            cs = cells(rel)
            for r, name in enumerate(e["rows"]):
                row = cs[r * 3:r * 3 + 3]
                for c in row:
                    cols = colour_set(c)
                    self.assertIn(hexrgb(PAL[name]["cloth"]), cols, "%s %s: loincloth" % (rel, name))
                    self.assertIn(hexrgb(PAL[name]["outline"]), cols, "%s %s: outline" % (rel, name))
                    self.assertIn(hexrgb(PAL[name]["skin"]), cols, "%s %s: the hero's skin" % (rel, name))
                    self.assertEqual(int(c[-1, :, 3].max()), 255, "%s: the bust stands on the cell bottom" % rel)
                self.assertFalse(np.array_equal(row[0], row[1]) or np.array_equal(row[0], row[2]), name)

    def test_heads_fit_the_32_px_versus_panels(self):
        text = source("scripts/ui/hud_versus.gd")
        panel_h = float(re.search(r"const PANEL_H: float = ([0-9.]+)", text).group(1))
        pad = float(re.search(r"const PAD: float = ([0-9.]+)", text).group(1))
        self.assertLessEqual(ROWS["assets/ui/portrait_heads.png"]["frame"][1], panel_h - pad)

    def test_portraits_are_integer_2x_ninja_art(self):
        for c in cells("assets/ui/portraits.png"):
            a = c[..., 3] > 0
            ys, xs = np.nonzero(a)
            sub = c[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            self.assertEqual(sub.shape[0] % 2, 0)
            np.testing.assert_array_equal(sub[0::2], sub[1::2])            # every row doubled

    def test_sundial_is_ui_bs_dial_atlas(self):
        text = source("scripts/ui/hud_atlas.gd")
        frames = int(re.search(r"const DIAL_FRAMES: int = (\d+)", text).group(1))
        cell = re.search(r'\[&"dial", "[^"]*", Vector2i\((\d+), (\d+)\), (\d+)\]', text)
        e = ROWS["assets/ui/sundial.png"]
        gc, gr = e["grid"]
        self.assertEqual(gc * gr, frames)
        self.assertEqual(e["frame"], [int(cell.group(1)), int(cell.group(2))])
        self.assertEqual(ROWS["assets/ui/sundial_rush.png"]["frame"], e["frame"])
        cs = cells("assets/ui/sundial.png")
        shadow = [int(np.all(c[..., :3] == hexrgb("#a08664"), axis=2).sum()) for c in cs]
        self.assertEqual(shadow[0], 0, "round start: no shadow")
        self.assertTrue(all(b >= a for a, b in zip(shadow, shadow[1:])), "the shadow only grows")
        rush = img("assets/ui/sundial_rush.png")
        self.assertIn(hexrgb("#ff6b5a"), colour_set(rush))
        w = rush.shape[0]
        self.assertEqual(int(rush[w // 2 - 4:w // 2 + 4, w // 2 - 4:w // 2 + 4, 3].max()), 0, "the rim only")
        rush_hex = re.search(r'const COL_RUSH: Color = Color\("([0-9a-f]{6})"\)', text).group(1)
        self.assertEqual(hexrgb(rush_hex), hexrgb("#ff6b5a"))

    def test_hit_sparks_keep_the_hit_stars_layout(self):
        src = img("assets/sprites/fx/hit_stars.png")
        out = img("assets/sprites/fx/hit_stars_players.png")
        h = src.shape[0]
        self.assertEqual(out.shape[0], h * 6)
        for r, name in enumerate(ROWS["assets/sprites/fx/hit_stars_players.png"]["rows"]):
            np.testing.assert_array_equal(out[r * h:(r + 1) * h, ..., 3], src[..., 3], err_msg=name)
        self.assertEqual(ROWS["assets/sprites/fx/hit_stars_players.png"]["frame"], [40, 41])

    def test_medals_follow_player_run(self):
        coop = gd_ids("scripts/core/player_run.gd", "COOP_MEDALS")
        versus = gd_ids("scripts/core/player_run.gd", "VERSUS_AWARDS")
        e = ROWS["assets/ui/medals.png"]
        self.assertEqual(e["ids"], ["coop_" + i for i in coop] + versus)
        cs = cells("assets/ui/medals.png")
        self.assertEqual(len(cs), len(e["ids"]))
        for i, c in enumerate(cs):
            self.assertIn(OUTLINE, colour_set(c), i)
            self.assertGreaterEqual(int(np.all(c[..., :3] == hexrgb("#793a15"), axis=2).sum()), 10,
                                    "%s has an emblem" % e["ids"][i])

    def test_plates_and_painted_heroes(self):
        for r, (name, c) in enumerate(zip(ROWS["assets/ui/versus_plate.png"]["rows"],
                                          cells("assets/ui/versus_plate.png"))):
            self.assertIn(hexrgb(PAL[name]["cloth"]), colour_set(c), name)
        hero = img("assets/sprites/player/hero.png")
        e = ROWS["assets/ui/cave_paint_heroes.png"]
        frames = [48, 49, 0]
        for k, c in enumerate(cells("assets/ui/cave_paint_heroes.png")):
            f = frames[k % 3]
            h = hero[(f // 8) * 112:(f // 8 + 1) * 112, (f % 8) * 176:(f % 8 + 1) * 176]
            self.assertFalse(((c[..., 3] > 0) & (h[..., 3] == 0)).any(), "painted inside the hero's silhouette")
        self.assertEqual(e["pivot"], [88, 96])
        wall = img("assets/ui/cave_wall.png")
        self.assertEqual(wall.shape[:2], (360, 640))
        self.assertEqual(int(wall[..., 3].min()), 255)

    def test_tags_and_arrows_have_a_row_per_colour_and_keep_phase_one_cells(self):
        order = ui_colour_order()
        tags = cells("assets/ui/player_tags.png")
        self.assertEqual(len(tags), 4 * (1 + len(order)))
        slot_default = ["yellow", "blue", "pink", "green"]
        for k in range(4):
            np.testing.assert_array_equal(tags[k], tags[(1 + order.index(slot_default[k])) * 4 + k])
        for c, name in enumerate(order):
            fill = hexrgb(PAL[name]["cloth"])
            for k in range(4):
                self.assertIn(fill, colour_set(tags[(1 + c) * 4 + k]), "%s P%d" % (name, k + 1))
        arrows = cells("assets/ui/player_arrows.png")
        self.assertEqual(len(arrows), 4 * len(order))
        for c, name in enumerate(order):
            for side in range(4):
                self.assertIn(hexrgb(PAL[name]["cloth"]), colour_set(arrows[c * 4 + side]), name)


# ---------------------------------------------------------------------------------------------------- feast
class FeastSkins(unittest.TestCase):
    def test_terrains_keep_the_atlas_layout_and_collision(self):
        for rel, src in (("assets/tiles/feast/terrain_honeycomb.png", "assets/tiles/cave/terrain_stone.png"),
                         ("assets/tiles/feast/terrain_pudding.png", "assets/tiles/ice/terrain.png")):
            a, b = img(rel), img(src)
            self.assertEqual(a.shape, b.shape)
            np.testing.assert_array_equal(a[..., 3], b[..., 3], err_msg=rel)
            out_a = np.all(b[..., :3] == OUTLINE, axis=2) & (b[..., 3] > 0)
            self.assertTrue(np.all(a[out_a][:, :3] == OUTLINE), "%s keeps the outline" % rel)
            self.assertEqual(ROWS[rel]["tiles"], "TERRAIN_TILES")

    def test_the_honeycomb_repeats_every_32_px(self):
        """the comb is a function of (x % 32, y % 32): fill tiles 9 (fill) and its neighbours join seamlessly"""
        a = img("assets/tiles/feast/terrain_honeycomb.png")
        wax, honey = hexrgb("#ffe680"), hexrgb("#e8951c")
        fill = a[32:64, 32:64]
        self.assertGreater(int(np.all(fill[..., :3] == wax, axis=2).sum()), 60, "the fill tile shows comb walls")
        self.assertGreater(int(np.all(fill[..., :3] == honey, axis=2).sum()), 60, "and honey cells")
        left = a[32:64, 32:33, :3]
        right = a[32:64, 63:64, :3]
        both = np.all(left == wax, axis=2) | np.all(right == wax, axis=2)
        self.assertGreater(int(both.sum()), 0)

    def test_the_game_finds_every_feast_prop(self):
        props = [k for k in ROWS if k.startswith("assets/tiles/feast/props/")]
        self.assertGreaterEqual(len(props), 8)
        text = source("scripts/world/level_validator.gd")
        self.assertIn("props/", text)
        for k in props:
            e = ROWS[k]
            w, h = e["size"]
            self.assertTrue(0 <= e["pivot"][0] <= w and e["pivot"][1] in (0, h), k)
            self.assertLessEqual(max(w, h), 96, k)


# ---------------------------------------------------------------------------------------------------- world objects
class WorldObjects(unittest.TestCase):
    def test_a_file_built_from_another_2_0_file_credits_its_packs(self):
        """origin packs resolve through other 2.0 files too (build_expansion.pack_uses), so CREDITS / THIRD_PARTY
        are checked against every pack a picture really comes from"""
        for child, parents in (("sprites/objects/drum_cap.png", ("sprites/objects/drum.png",
                                                                 "tiles/swamp/props/glowcap_big.png")),
                               ("sprites/objects/platform_driftwood.png", ("tiles/coast/props/driftwood_log.png",)),
                               ("ui/world_map_far_shore.png", ("backgrounds/canyon/layer2_mesas.png",
                                                               "backgrounds/canyon/layer1_far_spires.png"))):
            got = set(ROWS["assets/" + child]["origin_packs"])
            for p in parents:
                self.assertLessEqual(set(ROWS["assets/" + p]["origin_packs"]) - {"own"}, got, (child, p))

    def test_platform_skins_have_the_platform_layout(self):
        wood = img("assets/sprites/objects/platform_wood.png")
        for n in ("platform_cloud", "platform_driftwood"):
            rel = "assets/sprites/objects/%s.png" % n
            a = img(rel)
            self.assertEqual(a.shape, wood.shape, n)
            self.assertEqual(ROWS[rel]["pivot"], [48, 0], n)
            top = np.nonzero((a[..., 3] > 0).any(axis=1))[0].min()
            self.assertLessEqual(int(top), 1, "%s: the standing surface is the top row" % n)
            self.assertGreaterEqual(int((a[top + 1, :, 3] > 0).sum()), 80, n)
        np.testing.assert_array_equal(img("assets/sprites/objects/platform_driftwood.png")[..., 3], wood[..., 3])

    def test_cap_spring_and_drums_keep_their_layouts(self):
        for n, base in (("spring_cap", "spring"), ("drum_cap", "drum")):
            a = img("assets/sprites/objects/%s.png" % n)
            b = img("assets/sprites/objects/%s.png" % base)
            np.testing.assert_array_equal(a[..., 3], b[..., 3], err_msg=n)
        cs = cells("assets/sprites/objects/drum_cap.png")

        def lum(c):
            px = c[c[..., 3] > 0][:, :3].astype(float)
            return float((0.299 * px[:, 0] + 0.587 * px[:, 1] + 0.114 * px[:, 2]).mean())
        self.assertGreater(min(lum(cs[3]), lum(cs[4])), max(lum(cs[0]), lum(cs[1]), lum(cs[2])),
                           "lit frames read brighter")

    def test_coconut_rolls_in_quarter_turns(self):
        e = ROWS["assets/sprites/objects/coconut.png"]
        self.assertEqual((e["frame"], e["grid"], e["pivot"]), ([32, 32], [4, 2], [16, 16]))
        text = source("scripts/objects/coconut.gd")
        self.assertIn("res://assets/sprites/objects/coconut.png", text)
        self.assertEqual(int(re.search(r"const OWN_SHEET_COLUMNS: int = (\d+)", text).group(1)), e["grid"][0])
        cs = cells("assets/sprites/objects/coconut.png")
        for row in (0, 1):
            first = cs[row * 4][1:31, 1:31]
            for k in range(1, 4):
                np.testing.assert_array_equal(cs[row * 4 + k][1:31, 1:31], np.rot90(first, -k), err_msg=str(k))
        self.assertIn(hexrgb("#ffe94f"), colour_set(cs[4]), "the golden row")

    def test_staged_arena_frames_are_byte_copies(self):
        import glob
        staged = glob.glob(os.path.join(HANDOVER, "staged", "arena", "frame_*.png"))
        if not staged:
            self.skipTest("staging area not present")
        for p in staged:
            dst = os.path.join(ASSETS, "ui", "arena", os.path.basename(p))
            with open(p, "rb") as f1, open(dst, "rb") as f2:
                self.assertEqual(f1.read(), f2.read(), os.path.basename(p))
            self.assertIn("assets/ui/arena/" + os.path.basename(p), ROWS)


# ---------------------------------------------------------------------------------------------------- manifest
class ManifestPhase2(unittest.TestCase):
    def test_phase_two_sections_and_rows(self):
        with open(os.path.join(ROOT, "docs", "ASSET_MANIFEST.md"), encoding="utf-8") as f:
            text = f.read()
        for head in ("### 17.11 Versus art", "### 17.13 The Far Shore map page and the Cave Paintings",
                     "### 17.14 Feast Land D / E skins", "### 17.15 2.0 uses of shipped 1.0 files"):
            self.assertIn(head, text)
        self.assertLess(text.index("### 17.12 Audio"), text.index("### 17.13 The Far Shore"))
        for rel in ("ui/world_map_far_shore.png", "ui/mural.png", "ui/painting_slab.png", "ui/paintings.png",
                    "ui/medals.png", "ui/sundial.png", "tiles/feast/terrain_honeycomb.png",
                    "sprites/objects/drum_cap.png"):
            self.assertIn("`%s`" % rel, text)

    def test_third_party_names_only_shipped_files(self):
        """docs/THIRD_PARTY.md 2.3 / 2.4 are kept by hand: every file they name (braces expanded, a short path matched
        as the tail of a shipped path) exists under assets/ - a withdrawn file must leave the lists"""
        import fnmatch
        shipped = []
        for root, _, files in os.walk(ASSETS):
            for f in files:
                if not f.endswith(".import"):
                    shipped.append(os.path.relpath(os.path.join(root, f), ASSETS).replace(os.sep, "/"))

        def expand(p):
            m = re.search(r"\{([^}]*)\}", p)
            if not m:
                return [p]
            return [q for alt in m.group(1).split(",") for q in expand(p[:m.start()] + alt + p[m.end():])]
        with open(os.path.join(ROOT, "docs", "THIRD_PARTY.md"), encoding="utf-8") as f:
            text = f.read()
        lists = text[text.index("### 2.3"):text.index("### 2.5")]
        named = [q for tok in re.findall(r"`([^`]+)`", lists) if re.search(r"\.(png|ogg|wav)$|\*$", tok)
                 for q in expand(tok)]
        self.assertGreater(len(named), 60)
        for q in named:
            self.assertTrue(any(fnmatch.fnmatch(s, q) or fnmatch.fnmatch(s, "*/" + q) for s in shipped),
                            "THIRD_PARTY names %s, which does not ship" % q)

    def test_every_audio_batch_keeps_its_decisions_in_the_manifest(self):
        """the audio owner's batch notes live in the unversioned staging folder: the manifest (17.12) carries the
        music budget and the decisions and flags of every batch"""
        with open(os.path.join(ROOT, "docs", "ASSET_MANIFEST.md"), encoding="utf-8") as f:
            text = f.read()
        a, b = text.index("### 17.12 Audio"), text.index("### 17.13 The Far Shore")
        sec = text[a:b]
        import glob
        docs = sorted(glob.glob(os.path.join(HANDOVER, "audio", "AUDIO_BATCH*.md")))
        if not docs:
            self.skipTest("no audio hand-over in this checkout (.tools/ is not versioned)")
        for path in docs:
            with open(path, encoding="utf-8") as f:
                lines = f.read().splitlines()
            self.assertIn("*%s*" % lines[0].lstrip("# ").strip(), sec, path)
            first = next(ln for ln in lines[lines.index("## Decisions and flags") + 1:] if ln.strip())
            self.assertIn(first, sec, path)


if __name__ == "__main__":
    unittest.main()

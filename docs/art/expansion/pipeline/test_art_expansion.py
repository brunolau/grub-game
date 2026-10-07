"""Tests of the 2.0 art pipeline (art-A): the files under assets/ against their registry rows and the contracts the
game code reads (strip layouts, rows per biome, pivots, seat lines), the hand-over merge (art-B, audio), the manifest
section and the licence / credit bookkeeping. Run with the project venv from the project root:

    .tools/venv/Scripts/python.exe -m unittest discover -s docs/art/expansion/pipeline -p "test_*.py" -v

Read-only: nothing under assets/ or docs/ is written (the image builders are called in memory only).
"""
import glob
import hashlib
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


def level_biomes():
    """LevelData.BIOMES as the game declares it (scripts/world/level_data.gd)"""
    with open(os.path.join(ROOT, "scripts", "world", "level_data.gd"), encoding="utf-8") as f:
        text = f.read()
    m = re.search(r"const BIOMES: Array\[String\] = \[(.*?)\]", text, re.S)
    return re.findall(r'"([a-z_]+)"', m.group(1))


def art_a(prefix=""):
    return sorted(k for k, v in ROWS.items() if v.get("owner", "art-A") == "art-A" and k.startswith(prefix))


# ---------------------------------------------------------------------------------------------------- registry
class RegistryRows(unittest.TestCase):
    def test_every_row_has_its_file_and_its_size(self):
        for rel, e in ROWS.items():
            path = os.path.join(ROOT, *rel.split("/"))
            self.assertTrue(os.path.exists(path), rel)
            if rel.endswith(".png"):
                with Image.open(path) as im:
                    self.assertEqual(list(im.size), e["size"], rel)
                    self.assertLessEqual(max(im.size), 2048, rel)

    def test_art_a_sheets_are_uniform_grids_with_the_pivot_in_the_cell(self):
        for rel in art_a():
            e = ROWS[rel]
            if not rel.endswith(".png") or "frame" not in e:
                continue
            fw, fh = e["frame"]
            gc, gr = e["grid"]
            self.assertEqual([fw * gc, fh * gr], e["size"], rel)
            if "pivot" in e:
                self.assertTrue(0 <= e["pivot"][0] <= fw and 0 <= e["pivot"][1] <= fh, rel)
            for name, an in e.get("anims", {}).items():
                self.assertTrue(all(0 <= f < gc * gr for f in an["frames"]), "%s %s" % (rel, name))

    def test_every_art_a_row_says_where_it_comes_from_and_is_cc0(self):
        for rel in art_a():
            e = ROWS[rel]
            self.assertEqual(e.get("license"), "CC0 1.0", rel)
            self.assertTrue(e.get("source"), rel)
            if e.get("kind") != "data":
                self.assertTrue(e.get("edits"), rel)
            if rel.endswith(".png"):
                self.assertTrue(e.get("note"), rel)

    def test_phase_one_files_are_registered(self):
        for rel in ("tiles/common/tar.png", "tiles/common/honey.png", "tiles/common/syrup.png",
                    "tiles/common/tar_floor.png", "tiles/common/honey_floor.png", "tiles/common/syrup_floor.png",
                    "tiles/common/water_floor.png", "tiles/common/lava_floor.png", "tiles/common/ice_water_floor.png",
                    "sprites/objects/vine.png", "sprites/objects/bark_board.png", "sprites/objects/geyser.png",
                    "sprites/objects/raft.png", "sprites/objects/rex_pen.png", "sprites/objects/rex_saddle.png",
                    "sprites/objects/seesaw_plank_mushroom.png", "sprites/objects/seesaw_plank_floe.png",
                    "sprites/objects/cookpot.png", "sprites/objects/spawn_point.png", "sprites/items/painting.png",
                    "sprites/items/golden_drumstick.png", "ui/crown.png", "ui/stack_food.png", "ui/emotes.png"):
            self.assertIn("assets/" + rel, ROWS, rel)
            if rel != "tiles/common/tar_floor.png":
                self.assertEqual(ROWS["assets/" + rel].get("owner", "art-A"), "art-A", rel)


# ---------------------------------------------------------------------------------------------------- liquids
class Liquids(unittest.TestCase):
    def test_new_liquid_strips_have_the_water_strip_layout(self):
        water = img("assets/tiles/common/water.png")
        for n in ("tar", "honey", "syrup"):
            a = img("assets/tiles/common/%s.png" % n)
            self.assertEqual(a.shape, water.shape, n)
            np.testing.assert_array_equal(a[..., 3], water[..., 3], err_msg=n)        # exact swap: same alpha
            self.assertTrue(colour_set(a).isdisjoint(colour_set(water)), n)

    def test_the_game_finds_every_liquid_strip(self):
        with open(os.path.join(ROOT, "scripts", "world", "level_data.gd"), encoding="utf-8") as f:
            text = f.read()
        liquids = re.findall(r'"([a-z_]+)"', re.search(r"const LIQUIDS: Array\[String\] = \[(.*?)\]", text).group(1))
        for n in liquids:
            self.assertTrue(os.path.exists(os.path.join(ASSETS, "tiles", "common", n + ".png")), n)
            self.assertTrue(os.path.exists(os.path.join(ASSETS, "tiles", "common", n + "_floor.png")), n + "_floor")

    def test_tar_floor_strips_follow_the_mud_floor_layout(self):
        mud = img("assets/tiles/canyon/mud_floor.png")
        for n in ("tar", "honey", "syrup", "water", "lava", "ice_water"):
            rel = "assets/tiles/common/%s_floor.png" % n
            a = img(rel)
            self.assertEqual(a.shape, mud.shape, n)
            self.assertEqual(ROWS[rel]["grid"], [4, 1])
            for t in range(3):
                tile = a[:, t * 32:t * 32 + 32]
                self.assertEqual(int(tile[0:6, :, 3].max()), 0, "%s tile %d: the 6 rows over the surface" % (n, t))
                self.assertGreater(int((tile[6, :, 3] > 0).sum()), 20, "%s tile %d: surface line on row 6" % (n, t))
                self.assertEqual(int(tile[12:, 6:26, 3].min()), 255, "%s tile %d: solid goo under the feet" % (n, t))
            self.assertEqual(int(a[:, 96:128, 3].min()), 255, "%s fill tile is solid" % n)

    def test_tar_floor_is_the_tar_fens(self):
        with open(os.path.join(ASSETS, "tiles", "common", "tar_floor.png"), "rb") as f1,                 open(os.path.join(ASSETS, "tiles", "swamp", "tar_floor.png"), "rb") as f2:
            self.assertEqual(f1.read(), f2.read())
        self.assertEqual(ROWS["assets/tiles/common/tar_floor.png"]["owner"], "art-B")

    def test_tar_is_art_bs_tar_fen_ramp(self):
        swamp = colour_set(img("assets/tiles/swamp/tar_floor.png"))
        tar = img("assets/tiles/common/tar.png")
        self.assertIn((0xa8, 0x92, 0xc4), colour_set(tar) & swamp, "the fen's violet sheen")
        staged = os.path.join(HANDOVER, "staged", "common", "tar.png")
        if os.path.exists(staged):                                   # art-B's candidate for this very file
            np.testing.assert_array_equal(tar, np.array(Image.open(staged).convert("RGBA")))

    def test_files_are_what_the_pipeline_builds(self):
        import build_liquids
        for n in ("tar", "honey", "syrup"):
            np.testing.assert_array_equal(np.array(build_liquids.liquid_strip(n)),
                                          img("assets/tiles/common/%s.png" % n), err_msg=n)
        for n in build_liquids.BUILT_FLOORS:
            np.testing.assert_array_equal(np.array(build_liquids.floor_strip(n)),
                                          img("assets/tiles/common/%s_floor.png" % n), err_msg=n)


# ---------------------------------------------------------------------------------------------------- Book II objects
class BookTwoObjects(unittest.TestCase):
    def test_biome_rows_follow_level_data(self):
        biomes = level_biomes()
        for rel in ("assets/sprites/objects/vine.png", "assets/sprites/objects/bark_board.png"):
            self.assertEqual(ROWS[rel]["rows"], biomes, rel)
            self.assertEqual(ROWS[rel]["grid"][1], len(biomes), rel)

    def test_vine_pieces_join_without_a_step(self):
        cs = cells("assets/sprites/objects/vine.png")
        for r in range(11):
            top, a, b, tip = cs[r * 8:r * 8 + 4]

            def span(c, y):
                xs = np.nonzero(c[y, :, 3])[0]
                return (int(xs.min()), int(xs.max())) if len(xs) else None
            for upper, lower in ((top, a), (a, b), (b, a), (a, a), (b, b), (a, tip), (b, tip)):
                s0, s1 = span(upper, 31), span(lower, 0)
                self.assertIsNotNone(s0)
                self.assertIsNotNone(s1)
                self.assertLessEqual(abs((s0[0] + s0[1]) - (s1[0] + s1[1])) / 2.0, 2.0, "row %d" % r)
            stem = [np.nonzero(a[y, :, 3])[0].mean() for y in range(32)]
            self.assertLess(abs(float(np.mean(stem)) - 15.5), 2.5, "row %d: the stem hangs at the cell centre" % r)

    def test_rolled_vine_hangs_from_the_anchor_point(self):
        cs = cells("assets/sprites/objects/vine.png")
        for r in range(11):
            for k in (4, 5, 6, 7):
                c = cs[r * 8 + k]
                self.assertGreater(int((c[0, 12:21, 3] > 0).sum()), 0, "row %d col %d: tied at the top" % (r, k))
            self.assertGreater((cs[r * 8 + 6][..., 3] > 0)[24:].sum(), (cs[r * 8 + 4][..., 3] > 0)[28:].sum(),
                               "the unrolling end drops")

    def test_bark_board_leaves_the_wall_edge_visible(self):
        for i, c in enumerate(cells("assets/sprites/objects/bark_board.png")):
            ys, xs = np.nonzero(c[..., 3])
            self.assertTrue(xs.min() >= 3 and xs.max() <= 28 and ys.min() >= 1 and ys.max() <= 30, i)
            self.assertIn((0x33, 0x22, 0x13), colour_set(c), i)                # the wood platform's outline

    def test_geyser_columns_reach_the_launch_apex_and_the_deadly_box(self):
        e = ROWS["assets/sprites/objects/geyser.png"]
        self.assertEqual(e["rows"], ["mud", "blowhole", "steam", "soda", "tar", "lava"])
        cs = cells("assets/sprites/objects/geyser.png")
        H = e["frame"][1]
        mouth = H - 10
        for r, name in enumerate(e["rows"]):
            idle = cs[r * 8]
            ys, xs = np.nonzero(idle[..., 3])
            self.assertTrue(ys.min() >= H - 16 and ys.max() == H - 1, "%s idle vent sits on the floor" % name)
            self.assertLessEqual(xs.max() - xs.min() + 1, 50, "%s vent is 24 logical px" % name)
            full = cs[r * 8 + 5]
            top = int(np.nonzero(full[..., 3].any(axis=1))[0].min())
            want = 128 if name in ("tar", "lava") else 210
            self.assertLessEqual(mouth - top, want + 34, name)
            self.assertGreaterEqual(mouth - top, want - 4, name)
            if name != "steam":
                mid_row = full[mouth - want // 2]
                width = int((mid_row[:, 3] > 0).sum())
                self.assertTrue(30 <= width <= 60, "%s jet width %d" % (name, width))

    def test_raft_ride_surface_is_the_top_row(self):
        e = ROWS["assets/sprites/objects/raft.png"]
        self.assertEqual(e["pivot"], [64, 0])
        for i, (c, w) in enumerate(zip(cells("assets/sprites/objects/raft.png"), (96, 128, 96, 128))):
            xs = np.nonzero(c[0, :, 3])[0]
            self.assertGreaterEqual(len(xs), w - 20, i)
            self.assertLess(abs((xs.min() + xs.max()) / 2.0 - 63.5), 2.5, "raft %d is centred" % i)
            body = np.nonzero(c[..., 3].any(axis=1))[0]
            self.assertGreaterEqual(body.max(), 15, "raft %d is 16 art px deep" % i)

    def test_painting_found_before_row_is_an_outline_only(self):
        cs = cells("assets/sprites/items/painting.png")
        ghost = colour_set(np.concatenate([c.reshape(-1, 4) for c in cs[6:]])[None])
        self.assertEqual(len(ghost), 1)
        for c in cs[:6]:
            self.assertIn(OUTLINE, colour_set(c))
            self.assertIn((0xb6, 0x4e, 0x13), colour_set(c))                   # the ochre glyph

    def test_rex_saddle_overlays_the_rex_and_carries_the_driver_at_the_saddle_height(self):
        e = ROWS["assets/sprites/objects/rex_saddle.png"]
        rex = img("assets/sprites/enemies/rex.png")
        self.assertEqual(e["size"], [rex.shape[1], rex.shape[0]])
        fw, fh = e["frame"]
        cs = cells("assets/sprites/objects/rex_saddle.png")
        for f, c in enumerate(cs):
            if f in (19, 20, 21, 22, 23):
                self.assertEqual(int(c[..., 3].max()), 0, f)
                self.assertIsNone(e["seat_dy"][f])
                continue
            self.assertGreater(int(c[..., 3].max()), 0, f)
            r = rex[(f // 8) * fh:(f // 8 + 1) * fh, (f % 8) * fw:(f % 8 + 1) * fw]
            for x in range(fw):
                col = np.nonzero(r[:, x, 3])[0]
                sad = np.nonzero(c[:, x, 3])[0]
                if len(sad) and len(col):
                    below = sad[sad > col.min() + 6 + abs(e["seat_dy"][f])]
                    self.assertTrue(all(r[y, x, 3] for y in below), "frame %d col %d: strap off the body" % (f, x))
        top = int(np.nonzero(cs[0][..., 3].any(axis=1))[0].min())
        self.assertTrue(e["pivot"][1] - 52 - 2 <= top <= e["pivot"][1] - 52, "driver line = SADDLE_PX 26")

    def test_seesaw_skins_keep_the_plank_layout(self):
        base = img("assets/sprites/objects/seesaw_plank.png")
        for n in ("mushroom", "floe"):
            a = img("assets/sprites/objects/seesaw_plank_%s.png" % n)
            np.testing.assert_array_equal(a[..., 3], base[..., 3], err_msg=n)
            self.assertEqual(ROWS["assets/sprites/objects/seesaw_plank_%s.png" % n]["pivot"],
                             ROWS["assets/sprites/objects/seesaw_plank.png"]["pivot"])


# ---------------------------------------------------------------------------------------------------- versus
class Versus(unittest.TestCase):
    def test_cookpot_front_frames_cover_only_the_back_frames(self):
        e = ROWS["assets/sprites/objects/cookpot.png"]
        n = e["grid"][0]
        cs = cells("assets/sprites/objects/cookpot.png")
        for i in range(n):
            back, front = cs[i][..., 3] > 0, cs[n + i][..., 3] > 0
            self.assertFalse((front & ~back).any(), "frame %d: front pixels outside the back frame" % i)
            if i < 8:
                rows = np.nonzero(front.any(axis=1))[0]
                self.assertGreaterEqual(rows.min(), e["frame"][1] - 40, "frame %d: the banker's head stays free" % i)
        self.assertEqual(e["anims"]["lid"]["frames"], [8, 9])

    def test_spawn_point_lights_in_the_slot_colours(self):
        with open(os.path.join(ASSETS, "sprites", "player", "palettes", "hero_palettes.json"), encoding="utf-8") as f:
            pal = json.load(f)
        cs = cells("assets/sprites/objects/spawn_point.png")
        self.assertEqual(len(cs), 8)
        for k, name in ((1, "yellow"), (2, "blue"), (3, "pink"), (4, "green"), (6, "white"), (7, "gold")):
            cloth = pal["palettes"][name]["cloth"].lstrip("#")
            self.assertIn(tuple(int(cloth[i:i + 2], 16) for i in (0, 2, 4)), colour_set(cs[k]), name)

    def test_crown_and_stack_pictures_use_the_anchor_outline(self):
        for rel in ("assets/ui/crown.png", "assets/ui/stack_food.png", "assets/sprites/items/golden_drumstick.png"):
            for i, c in enumerate(cells(rel)):
                cs = colour_set(c)
                self.assertIn(OUTLINE, cs, "%s %d" % (rel, i))
                self.assertNotIn((0, 0x0c, 0), cs, "%s %d: the RPG outline is swapped" % (rel, i))
        self.assertIn((0xff, 0x3f, 0x44), colour_set(cells("assets/ui/crown.png")[0]), "the red gem")
        self.assertEqual(ROWS["assets/ui/stack_food.png"]["grid"], [6, 1])

    def test_emotes_are_four_outlined_bubbles_with_the_tail_at_the_pivot(self):
        e = ROWS["assets/ui/emotes.png"]
        self.assertEqual(e["grid"], [4, 1])
        for i, c in enumerate(cells("assets/ui/emotes.png")):
            self.assertIn(OUTLINE, colour_set(c), i)
            rows = np.nonzero(c[..., 3].any(axis=1))[0]
            self.assertEqual(int(rows.max()) + 1, e["pivot"][1], "%d: the tail's tip is the pivot row" % i)
            self.assertTrue(c[rows.max(), e["pivot"][0] - 1:e["pivot"][0] + 1, 3].any(), i)
        self.assertIn((0xe0, 0x39, 0x4c), colour_set(cells("assets/ui/emotes.png")[2]), "the red heart")

    def test_staged_arena_frame_is_byte_identical(self):
        src = os.path.join(HANDOVER, "staged", "arena", "frame_jungle.png")
        if not os.path.exists(src):
            self.skipTest("staging area not present")
        with open(src, "rb") as f1, open(os.path.join(ASSETS, "ui", "arena", "frame_jungle.png"), "rb") as f2:
            self.assertEqual(f1.read(), f2.read())


# ---------------------------------------------------------------------------------------------------- hand-over
class HandOver(unittest.TestCase):
    def test_audio_rows_match_their_files(self):
        audio = {k: v for k, v in ROWS.items() if v.get("owner") == "audio"}
        self.assertGreater(len(audio), 0)
        for rel, e in audio.items():
            with open(os.path.join(ROOT, *rel.split("/")), "rb") as f:
                self.assertEqual(hashlib.sha256(f.read()).hexdigest(), e["sha256"], rel)
            self.assertEqual(e["license"], "CC0 1.0", rel)
            self.assertTrue(e["names"] and e["audio_packs"], rel)

    def test_art_b_rows_are_merged(self):
        b = [k for k, v in ROWS.items() if v.get("owner") == "art-B"]
        for path in glob.glob(os.path.join(HANDOVER, "*registry*.json")):
            with open(path, encoding="utf-8") as f:
                for k in json.load(f):
                    if k.startswith("assets/") and os.path.exists(os.path.join(ROOT, *k.split("/"))):
                        self.assertIn(k, b, k)

    def test_every_pack_is_credited_and_licensed(self):
        with open(os.path.join(ROOT, "CREDITS.md"), encoding="utf-8") as f:
            credits = f.read()
        with open(os.path.join(ROOT, "docs", "THIRD_PARTY.md"), encoding="utf-8") as f:
            third = f.read()
        with open(os.path.join(ASSETS, "licenses", "README.md"), encoding="utf-8") as f:
            readme = f.read()
        meta = REG["_meta"]
        for p in list(meta["packs"].values()) + list(meta.get("audio_packs", {}).values()):
            lic = p["file"][len("assets/licenses/"):]
            self.assertTrue(os.path.exists(os.path.join(ASSETS, "licenses", lic)), lic)
            self.assertIn(lic, readme, lic)
            self.assertEqual(p["license"], "CC0 1.0", p["title"])
            with open(os.path.join(ASSETS, "licenses", lic), encoding="utf-8") as f:
                self.assertIn("CC0", f.read(), lic)
        import build_expansion
        for key, p in meta["packs"].items():
            url = build_expansion.PACKS[key][2]
            self.assertIn(url, credits, key)
            self.assertIn(url, third, key)

    def test_credits_wording_keeps_the_three_roles(self):
        with open(os.path.join(ROOT, "CREDITS.md"), encoding="utf-8") as f:
            text = f.read()
        wording = text[text.index("Suggested in-game wording:"):].split("\n")[0].split('"')[1]
        self.assertEqual(re.findall(r"([A-Z][a-z]+): ", wording), ["Art", "Music", "Sound"])


# ---------------------------------------------------------------------------------------------------- manifest
class Manifest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(os.path.join(ROOT, "docs", "ASSET_MANIFEST.md"), encoding="utf-8") as f:
            text = f.read()
        import manifest_expansion as me
        cls.section = text[text.index(me.BEGIN):text.index(me.END)]

    def test_every_registry_file_has_its_row(self):
        for rel in ROWS:
            self.assertIn("`%s`" % rel[len("assets/"):], self.section, rel)

    def test_section_numbers_the_code_cites_stay(self):
        for head in ("### 17.1 Hero colours", "### 17.5 UI", "### 17.6 Worlds and creatures", "### 17.7 Edit log",
                     "### 17.9 Known gaps", "### 17.10 Book II liquids", "### 17.11 Versus art", "### 17.12 Audio"):
            self.assertIn(head, self.section, head)


if __name__ == "__main__":
    unittest.main()

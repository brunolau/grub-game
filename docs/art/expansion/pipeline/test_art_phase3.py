"""Tests of the phase-3 art (PLAN 6, what the Book II content still needed; art-A and art-B areas):

  * art-A files (build_phase3_objects.py): Pudding Lagoon's custard ':' floor and the railed raft's fence - each
    against its registry row and the contract the game code reads (WorldTileSet.tar_floor_image's lookup order, the
    ':' strip layout of 17.10, raft.png's pivot);
  * the merge: art-B's phase-3 rows (islands, home beach) are in the manifest and the staged Mesa Rodeo / Cloud Top
    frames are imported byte for byte; CREDITS / THIRD_PARTY name the phase-3 files.

Run with the project venv from the project root:

    .tools/venv/Scripts/python.exe -m unittest discover -s docs/art/expansion/pipeline -p "test_*.py" -v

Read-only: nothing under assets/ or docs/ is written (builders are only called in memory).
"""
import io
import json
import os
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
ISLES = ("isle_mesa", "isle_mangrove", "isle_stacks", "isle_idols", "isle_spire")


def img(rel):
    with Image.open(os.path.join(ROOT, *rel.split("/"))) as im:
        return np.array(im.convert("RGBA"))


def text(rel):
    with open(os.path.join(ROOT, *rel.split("/")), encoding="utf-8") as f:
        return f.read()


def colour_set(a):
    px = a[a[..., 3] > 0][:, :3]
    return {tuple(int(v) for v in c) for c in np.unique(px, axis=0)} if len(px) else set()


class CustardFloor(unittest.TestCase):
    REL = "assets/tiles/feast/syrup_floor.png"

    def test_row_and_layout(self):
        e = ROWS[self.REL]
        self.assertEqual(e["owner"], "art-A")
        self.assertEqual(e["section"], "feast")
        self.assertEqual((e["frame"], e["grid"]), ([32, 32], [4, 1]))
        self.assertEqual((e["surface_drawn_row"], e["surface_collision_row"]), (6, 12))
        self.assertEqual(img(self.REL).shape, (32, 128, 4))

    def test_same_alpha_as_every_tar_floor_skin(self):
        # the ':' look must keep the geometry of the berry-syrup floor it replaces in a feast-biome level
        a, b = img(self.REL), img("assets/tiles/common/syrup_floor.png")
        self.assertTrue(((a[..., 3] > 0) == (b[..., 3] > 0)).all())
        for i in range(3):                      # the drawn surface line: nothing above art row 6 in the surface tiles
            self.assertFalse((a[:6, i * 32:(i + 1) * 32, 3] > 0).any(), i)
        self.assertTrue((a[:, 96:, 3] == 255).all(), "the fill tile is opaque")

    def test_reads_as_custard_not_as_the_deadly_syrup(self):
        a = img(self.REL)
        syrup = colour_set(img("assets/tiles/common/syrup.png"))
        self.assertFalse(colour_set(a) & syrup, "a wading floor must not share colours with the deadly syrup")
        body = a[20:30, 96:128, :3].reshape(-1, 3).mean(axis=0)
        r, g, b = body
        self.assertTrue(r > g > b and r > 180 and b < 120, "custard: warm yellow-orange, got %s" % body)
        # darker than the solid pudding terrain's custard body, so the slow floor never reads as solid pudding
        pud = img("assets/tiles/feast/terrain_pudding.png")[32:64, 32:64, :3].reshape(-1, 3).mean(axis=0)
        self.assertLess(body.sum(), pud.sum() - 40)

    def test_world_a_finds_it_first(self):
        # WorldTileSet.tar_floor_image: tiles/<biome>/<liquid>_floor.png before tiles/common/<liquid>_floor.png
        src = text("scripts/world/world_tile_set.gd")
        i_biome = src.index('candidates.append("%s%s/%s_floor.png" % [LevelData.TERRAIN_DIR, biome, liquid])')
        i_common = src.index('candidates.append("%scommon/%s_floor.png" % [LevelData.TERRAIN_DIR, liquid])')
        self.assertLess(i_biome, i_common)

    def test_rebuild_matches(self):
        import build_phase3_objects as B
        saved = B.save
        out = {}
        try:
            B.save = lambda im, rel, **m: out.__setitem__(rel, im)
            B.build()
        finally:
            B.save = saved
        for rel, im in out.items():
            buf = io.BytesIO()
            im.save(buf, format="PNG", optimize=True)
            with Image.open(os.path.join(ASSETS, *rel.split("/"))) as f:
                disk = np.array(f.convert("RGBA"))
            self.assertTrue((np.array(im.convert("RGBA")) == disk).all(), rel)


class RaftRails(unittest.TestCase):
    REL = "assets/sprites/objects/raft_rails.png"

    def cells(self):
        a = img(self.REL)
        return {(r, c): a[r * 32:(r + 1) * 32, c * 128:(c + 1) * 128] for r in range(2) for c in range(3)}

    def test_row_and_layout(self):
        e = ROWS[self.REL]
        self.assertEqual((e["frame"], e["grid"], e["pivot"]), ([128, 32], [3, 2], [64, 26]))
        self.assertEqual(e["rows"], ["width 3", "width 4"])
        self.assertEqual(e["columns"], ["closed", "open_left", "open_right"])
        self.assertEqual(img(self.REL).shape, (64, 384, 4))
        # raft.png's pivot is the deck's top centre (64, 0): the fence cell lines up with it
        self.assertEqual(ROWS["assets/sprites/objects/raft.png"]["pivot"], [64, 0])

    def test_posts_stand_on_the_deck_and_fit_the_raft(self):
        for (r, c), a in self.cells().items():
            on = a[..., 3] > 0
            self.assertTrue(on.any(), (r, c))
            self.assertFalse(on[29:].any(), "nothing more than 2 px under the deck line (%d, %d)" % (r, c))
            xs = np.nonzero(on.any(axis=0))[0]
            lo, hi = (16, 112) if r == 0 else (0, 128)      # raft.png: width 3 spans x 16-111, width 4 the cell
            self.assertGreaterEqual(xs.min(), lo - 4, (r, c))
            self.assertLessEqual(xs.max(), hi + 4, (r, c))

    def test_closed_is_symmetric_and_open_states_mirror(self):
        cs = self.cells()
        for r in (0, 1):
            closed = cs[(r, 0)]
            # shapes (alpha) mirror; the colours do not quite (every post is lit from the left)
            self.assertTrue((closed[:, ::-1, 3] == closed[..., 3]).all(), "the closed fence is symmetric (row %d)" % r)
            left, right = cs[(r, 1)], cs[(r, 2)]
            self.assertTrue((left[:, ::-1, 3] == right[..., 3]).all(), "open_left mirrors open_right (row %d)" % r)
            self.assertFalse((left == closed).all())
            # opening towards the left removes the left gate post: the left quarter holds less fence
            q = 32
            self.assertLess((left[:, :q, 3] > 0).sum(), (closed[:, :q, 3] > 0).sum())
            self.assertEqual((left[:, -q:, 3] > 0).sum(), (closed[:, -q:, 3] > 0).sum())

    def test_colours_are_the_raft_s(self):
        raft = colour_set(img("assets/sprites/objects/raft.png"))
        self.assertTrue(colour_set(img(self.REL)) <= raft, colour_set(img(self.REL)) - raft)


class Merge(unittest.TestCase):
    def test_art_b_phase3_rows_merged(self):
        for n in ISLES + ("feast_spit", "feast_table"):
            k = "assets/tiles/coast/props/%s.png" % n
            self.assertIn(k, REG, k)
            self.assertEqual(REG[k]["owner"], "art-B")
            with Image.open(os.path.join(ROOT, *k.split("/"))) as im:
                self.assertEqual(REG[k]["size"], list(im.size), k)

    def test_unlockable_arena_frames_imported(self):
        for f in ("canyon", "sky"):
            staged = os.path.join(HANDOVER, "staged", "arena", "frame_%s.png" % f)
            shipped = os.path.join(ASSETS, "ui", "arena", "frame_%s.png" % f)
            with open(staged, "rb") as a, open(shipped, "rb") as b:
                self.assertEqual(a.read(), b.read(), f)

    def test_manifest_lists_the_phase3_files(self):
        man = text("docs/ASSET_MANIFEST.md")
        for rel in ("tiles/feast/syrup_floor.png", "sprites/objects/raft_rails.png", "ui/arena/frame_canyon.png",
                    "ui/arena/frame_sky.png") + tuple("tiles/coast/props/%s.png" % n
                                                       for n in ISLES + ("feast_spit", "feast_table")):
            self.assertIn("`%s`" % rel, man, rel)

    def test_credits_name_the_phase3_uses(self):
        cr, tp = text("CREDITS.md"), text("docs/THIRD_PARTY.md")
        self.assertIn("islands and the home beach", cr)
        self.assertIn("raft_rails.png", tp)
        self.assertIn("isle_spire", tp)
        self.assertIn("frame_{canyon,sky}", tp)


if __name__ == "__main__":
    unittest.main()

"""Proof sheet of the phase-3 art (docs/art/expansion/phase3_art.png, never shipped): The Long Raft Home's five
islands and home beach with the railed raft, Old Mangrove's bark-grained trunk wall, the Roc's feathers and gust loop,
the railed raft's three states, Pudding Lagoon's custard floor beside the deadly syrup, and the two unlockable arenas
with their side frames. Composed from the files under assets/ (and art-B's mocks of the same files), so a sheet that
looks right is also a check of their cells and pivots.
"""
import os

import numpy as np
from PIL import Image

from xcommon import EXP, asset, canvas, label, load, over, save_doc, scale

BG = (58, 66, 84, 255)
MOCKS = os.path.join(EXP, "_handover", "mocks")


def mock(name):
    return load(os.path.join(MOCKS, name))


def tile(a, i):
    return a.crop(((i % 8) * 32, (i // 8) * 32, (i % 8) * 32 + 32, (i // 8) * 32 + 32))


def rails_strip():
    """the width-4 raft with its fence closed, open left, open right; the width-3 raft closed (pivots aligned)"""
    raft, rails = asset("sprites/objects/raft.png"), asset("sprites/objects/raft_rails.png")
    sc = canvas(4 * 150, 80, (110, 190, 230, 255))
    water = asset("tiles/common/water.png")
    for x in range(0, sc.width, 32):
        sc = over(sc, water.crop((0, 0, 32, 32)), (x, 52))
    for k, (row, col) in enumerate(((1, 0), (1, 1), (1, 2), (0, 0))):
        x, y = 8 + k * 150, 50                                   # the raft's pivot: deck top centre at (x + 64, y)
        sc = over(sc, rails.crop((col * 128, row * 32, col * 128 + 128, row * 32 + 32)), (x, y - 26))
        sc = over(sc, raft.crop((0, row * 24, 128, row * 24 + 24)), (x, y))
    return sc


def custard_strip():
    """Pudding Lagoon: pudding banks, a custard ':' floor (wade) and the deadly syrup '~' side by side"""
    pud, cf, sy = (asset("tiles/feast/terrain_pudding.png"), asset("tiles/feast/syrup_floor.png"),
                   asset("tiles/common/syrup.png"))
    sc = canvas(14 * 32, 3 * 32, (255, 214, 232, 255))
    cols = ["pud0", "pud1", "c0", "c1", "c1", "c2", "pud1", "pud2", "s", "s", "s", "s", "pud0", "pud2"]
    for x, c in enumerate(cols):
        if c.startswith("pud"):
            sc = over(sc, tile(pud, int(c[3])), (x * 32, 32))
            sc = over(sc, tile(pud, 9), (x * 32, 64))
        elif c.startswith("c"):
            i = int(c[1])
            sc = over(sc, cf.crop((i * 32, 0, i * 32 + 32, 32)), (x * 32, 32))
            sc = over(sc, cf.crop((96, 0, 128, 32)), (x * 32, 64))
        else:
            sc = over(sc, sy.crop((0, 0, 32, 32)), (x * 32, 32))
            sc = over(sc, sy.crop((192, 0, 224, 32)), (x * 32, 64))
    return sc


def roc_strip():
    """the Roc's falling feathers (roc_parts 0-2), the gust loop (5-7) and the ground feathers (props/sky/feather_*)"""
    parts = asset("sprites/bosses/roc_parts.png")
    sc = canvas(560, 100, (58, 62, 88, 255))
    for i, k in enumerate((0, 1, 2)):
        sc = over(sc, parts.crop((k * 160 + 50, 20, k * 160 + 110, 88)), (i * 60, 10))
    for i, k in enumerate((5, 6, 7)):
        sc = over(sc, parts.crop((k * 160, 0, k * 160 + 160, 88)), (130 + i * 100, 6))
    for i, n in enumerate("abcd"):
        im = asset("tiles/sky/props/feather_%s.png" % n)
        sc = over(sc, im, (440 + (i % 2) * 58, 6 + (i // 2) * 46))
    return sc


def build():
    voyage = mock("mock_raft_home.png")
    wall = mock("mock_mangrove_wall.png")
    roc = scale(roc_strip(), 2)
    mesa, cloud = mock("arena_mesa_rodeo_wide.png"), mock("arena_cloud_top_wide.png")
    rails, custard = scale(rails_strip(), 2), scale(custard_strip(), 2)
    W = 1790
    rows = [("The Long Raft Home (ending_b): the five islands (props/coast/isle_*) on the water's surface row, the "
             "home beach (feast_spit, feast_table), the railed raft open towards the beach", [voyage.crop((0, 0, 1280, 360))]),
            ("", [voyage.crop((1280, 0, 2560, 360))]),
            ("Old Mangrove's chamber (w6_l2b): swamp/terrain_bark with bark grain; the Roc's feathers (falling, "
             "ground) and the gust loop (roc_parts 5-7)", [wall, roc]),
            ("objects/raft rails: raft_rails.png over raft.png - closed, open left, open right, width 3; Pudding "
             "Lagoon: custard ':' floor beside the deadly syrup '~'", [rails, custard]),
            ("Unlockable arenas (cut 3): Mesa Rodeo and Cloud Top with their side frames (frame_canyon, frame_sky)",
             [mesa, cloud])]
    H = sum(max(im.height for im in ims) + (22 if t else 6) for t, ims in rows) + 8
    sheet = canvas(W, H, BG)
    y = 4
    for t, ims in rows:
        if t:
            label(sheet, t, 6, y + 2)
            y += 18
        x = 6
        for im in ims:
            sheet = over(sheet, im, (x, y))
            x += im.width + 12
        y += max(im.height for im in ims) + 6
    save_doc(sheet, "phase3_art.png")
    return sheet


if __name__ == "__main__":
    build()

"""Seam test: paint a small map from tile indices (review tool, also used by the mock builder)."""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from common import *

def tile(atlas, i):
    return atlas.crop(((i % 8) * 32, (i // 8) * 32, (i % 8) * 32 + 32, (i // 8) * 32 + 32))

def paint(atlas, rows, bg=(120, 190, 230, 255)):
    h = len(rows); w = max(len(r) for r in rows)
    out = canvas(w * 32, h * 32, bg)
    for y, r in enumerate(rows):
        for x, v in enumerate(r):
            if v is not None and v >= 0:
                out.alpha_composite(tile(atlas, v), (x * 32, y * 32))
    return out

_ = -1
TEST = [
    [_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _],
    [_, _, _, 27, 28, 28, 29, _, _, _, _, _, _, _, _, 3, 4, _, _, _],
    [_, _, _, _, _, _, _, _, _, 5, 0, 1, 2, _, _, 8, 10, _, 7, _],
    [0, 1, 1, 2, _, _, 11, 12, 1, 19, 9, 9, 10, 38, 38, 8, 10, _, _, _],
    [8, 9, 23, 10, _, 0, 21, 22, 9, 9, 9, 15, 9, 1, 1, 9, 9, 1, 13, 14],
    [8, 9, 9, 10, _, 8, 9, 9, 9, 9, 23, 9, 9, 9, 9, 9, 9, 9, 24, 25],
    [16, 17, 26, 18, _, 16, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 18],
    [30, 31, 32, _, _, _, 33, _, 39, 39, _, 35, 36, 37, 35, _, _, _, _, _],
]
if __name__ == "__main__":
    ims = []
    for b in sys.argv[2:]:
        ims.append(paint(load(os.path.join(ASSETS, "tiles", *b.split("/"))), TEST))
    out = canvas(ims[0].width, sum(i.height for i in ims))
    y = 0
    for i in ims: out.alpha_composite(i, (0, y)); y += i.height
    scale(out, 2).save(sys.argv[1]); print(out.size)

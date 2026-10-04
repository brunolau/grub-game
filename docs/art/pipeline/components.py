"""Connected-component slicer used to find the irregular props inside tileset-1.png (review tool)."""
import os, sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from common import *

def components(im, region, gap=1):
    """Return bboxes (absolute px) of alpha islands inside region; islands closer than `gap` px are merged."""
    x0, y0, x1, y1 = region
    a = np.array(im.crop(region))[..., 3] > 0
    H, W = a.shape
    lab = np.zeros((H, W), np.int32); boxes = []
    cur = 0
    for sy in range(H):
        for sx in range(W):
            if a[sy, sx] and lab[sy, sx] == 0:
                cur += 1; stack = [(sy, sx)]; lab[sy, sx] = cur
                bx0 = bx1 = sx; by0 = by1 = sy
                while stack:
                    y, x = stack.pop()
                    bx0 = min(bx0, x); bx1 = max(bx1, x); by0 = min(by0, y); by1 = max(by1, y)
                    for dy in range(-gap, gap + 1):
                        for dx in range(-gap, gap + 1):
                            ny, nx = y + dy, x + dx
                            if 0 <= ny < H and 0 <= nx < W and a[ny, nx] and lab[ny, nx] == 0:
                                lab[ny, nx] = cur; stack.append((ny, nx))
                boxes.append((bx0 + x0, by0 + y0, bx1 + 1 + x0, by1 + 1 + y0))
    return boxes

if __name__ == "__main__":
    im = sp("background-elements/tileset-1.png")
    regions = [(0, 0, 928, 256), (640, 256, 928, 544)]
    allb = []
    for r in regions:
        allb += [b for b in components(im, r, gap=1) if (b[2] - b[0]) * (b[3] - b[1]) >= 30]
    allb.sort(key=lambda b: (b[1] // 32, b[0]))
    S = 2
    big = canvas(im.width, im.height, (70, 90, 120, 255)); big.alpha_composite(im)
    big = scale(big, S); d = ImageDraw.Draw(big)
    for i, b in enumerate(allb):
        d.rectangle((b[0] * S, b[1] * S, b[2] * S - 1, b[3] * S - 1), outline=(0, 255, 255, 255))
        d.text((b[0] * S + 2, b[1] * S + 1), str(i), fill=(255, 255, 0, 255))
        print(i, b, (b[2] - b[0], b[3] - b[1]))
    big.crop((0, 0, 928 * S, 256 * S)).save(os.path.join(os.environ["TEMP"], "cs", "comp_a.png"))
    big.crop((640 * S, 256 * S, 928 * S, 544 * S)).save(os.path.join(os.environ["TEMP"], "cs", "comp_b.png"))

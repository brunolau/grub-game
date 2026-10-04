"""Shared helpers for the Club & Grub asset pipeline.

The pipeline reads the staged candidate packs under .tools/asset_candidates and writes the
normalised game assets under assets/.  Every written file is recorded in REGISTRY, which
build_manifest.py turns into docs/ASSET_MANIFEST.md.

Rules enforced here: integer nearest-neighbour scaling only, RGBA output, palette-preserving
recolours (per unique colour, never per pixel filters).
"""
import colorsys
import json
import math
import os

import numpy as np
from PIL import Image

ROOT = r"C:\Users\klatt\Desktop\pre2"
CAND = os.path.join(ROOT, ".tools", "asset_candidates")
SP = os.path.join(CAND, "environment", "superpowers-prehistoric-platformer")
ITEMS = os.path.join(CAND, "items_ui_fx")
CHARS = os.path.join(CAND, "characters")
AUDIO = os.path.join(CAND, "audio")
ASSETS = os.path.join(ROOT, "assets")
REG_PATH = os.path.join(ROOT, "docs", "art", "pipeline", "registry.json")

ART_SCALE = 2          # art px per logical px (PHYSICS.md 15.3)
TILE = 32              # art px per tile (= 16 logical px)
VIEW = (640, 360)      # base viewport in art px (= 320 x 180 logical px)
FOOT = 16              # art px between the feet baseline and the bottom of an actor cell

OUTLINE = (59, 38, 30, 255)   # dark brown used by the anchor pack for outlines (measured below)

REGISTRY = {}


def load_registry():
    global REGISTRY
    if os.path.exists(REG_PATH):
        with open(REG_PATH, "r", encoding="utf-8") as f:
            REGISTRY.update(json.load(f))
    return REGISTRY


def save_registry():
    with open(REG_PATH, "w", encoding="utf-8") as f:
        json.dump(REGISTRY, f, indent=1, sort_keys=True)


def load(path):
    return Image.open(path).convert("RGBA")


def sp(rel):
    return load(os.path.join(SP, rel))


def save(im, rel, **meta):
    """Save an image under assets/ and register it.  rel uses forward slashes."""
    path = os.path.join(ASSETS, *rel.split("/"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    entry = {"size": list(im.size)}
    entry.update(meta)
    REGISTRY["assets/" + rel] = entry
    return path


def register(rel, **meta):
    REGISTRY["assets/" + rel] = meta


# ----------------------------------------------------------------------------- geometry
def grid_cells(im, cols, rows):
    cw, ch = im.width // cols, im.height // rows
    return [im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for r in range(rows) for c in range(cols)]


def flip(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def vflip(im):
    return im.transpose(Image.FLIP_TOP_BOTTOM)


def bbox(im):
    return im.getchannel("A").getbbox()


def trim(im):
    b = bbox(im)
    return im.crop(b) if b else im


def scale(im, n):
    return im.resize((im.width * n, im.height * n), Image.NEAREST)


def canvas(w, h, color=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), color)


def paste(dst, src, xy):
    dst.alpha_composite(src, (int(xy[0]), int(xy[1])))
    return dst


def under(dst, src, xy):
    """Composite src BEHIND dst (dst stays on top)."""
    back = canvas(dst.width, dst.height)
    x, y = int(xy[0]), int(xy[1])
    # alpha_composite needs the source fully inside: crop manually
    sx0, sy0 = max(0, -x), max(0, -y)
    sx1, sy1 = min(src.width, dst.width - x), min(src.height, dst.height - y)
    if sx1 > sx0 and sy1 > sy0:
        back.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))
    back.alpha_composite(dst)
    return back


def over(dst, src, xy):
    x, y = int(xy[0]), int(xy[1])
    sx0, sy0 = max(0, -x), max(0, -y)
    sx1, sy1 = min(src.width, dst.width - x), min(src.height, dst.height - y)
    out = dst.copy()
    if sx1 > sx0 and sy1 > sy0:
        out.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))
    return out


def pad_to(im, w, h, ax=0.5, ay=1.0):
    """Centre (ax) / bottom (ay) align im inside a w x h transparent canvas."""
    out = canvas(w, h)
    out.alpha_composite(im, (int(round((w - im.width) * ax)), int(round((h - im.height) * ay))))
    return out


def rotate_px(im, deg, pivot=None, up=8):
    """Rotate pixel art clockwise by deg around pivot (default: centre), palette preserving.

    Works like a cheap RotSprite: nearest-neighbour upscale, nearest rotate, point-sample back.
    Returns (image, pivot_in_result).
    """
    if pivot is None:
        pivot = (im.width / 2.0, im.height / 2.0)
    r = int(math.ceil(max(math.hypot(pivot[0], pivot[1]), math.hypot(im.width - pivot[0], pivot[1]),
                          math.hypot(pivot[0], im.height - pivot[1]),
                          math.hypot(im.width - pivot[0], im.height - pivot[1])))) + 2
    big = canvas(2 * r, 2 * r)
    big.alpha_composite(im, (int(round(r - pivot[0])), int(round(r - pivot[1]))))
    if deg % 90 == 0:
        out = big.rotate(-deg, Image.NEAREST)
    else:
        b = big.resize((big.width * up, big.height * up), Image.NEAREST)
        b = b.rotate(-deg, Image.NEAREST)
        a = np.array(b)
        out = Image.fromarray(a[up // 2::up, up // 2::up].copy(), "RGBA")
    return out, (r, r)


# ----------------------------------------------------------------------------- colour
def remap(im, fn):
    """Apply fn(r, g, b) -> (r, g, b) once per unique colour (alpha untouched)."""
    a = np.array(im)
    flat = a.reshape(-1, 4)
    cols, inv = np.unique(flat[:, :3], axis=0, return_inverse=True)
    new = np.array([fn(int(c[0]), int(c[1]), int(c[2])) for c in cols], dtype=np.uint8)
    flat[:, :3] = new[inv.reshape(-1)]
    return Image.fromarray(flat.reshape(a.shape), "RGBA")


def hsv_fn(dh=0.0, sm=1.0, vm=1.0, sa=0.0, va=0.0, hue_range=None, set_h=None):
    """Hue shift (dh in 0..1 turns), saturation / value multiply + add.  hue_range=(lo, hi) limits
    the change to colours whose hue lies in that range (degrees)."""
    def fn(r, g, b):
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        if hue_range is not None:
            hd = h * 360.0
            lo, hi = hue_range
            inside = (lo <= hd <= hi) if lo <= hi else (hd >= lo or hd <= hi)
            if not inside or s < 0.08:
                return (r, g, b)
        h2 = (set_h if set_h is not None else h + dh) % 1.0
        s2 = min(1.0, max(0.0, s * sm + sa))
        v2 = min(1.0, max(0.0, v * vm + va))
        r2, g2, b2 = colorsys.hsv_to_rgb(h2, s2, v2)
        return (int(round(r2 * 255)), int(round(g2 * 255)), int(round(b2 * 255)))
    return fn


def ramp_fn(ramp, lo=None, hi=None):
    """Gradient map: luminance -> colour ramp (list of RGB tuples, dark to light)."""
    def lum(r, g, b):
        return 0.299 * r + 0.587 * g + 0.114 * b
    def fn(r, g, b):
        l = lum(r, g, b)
        a, z = (0.0 if lo is None else lo), (255.0 if hi is None else hi)
        t = min(1.0, max(0.0, (l - a) / max(1e-6, z - a))) * (len(ramp) - 1)
        i = min(len(ramp) - 2, int(t)); f = t - i
        c0, c1 = ramp[i], ramp[i + 1]
        return tuple(int(round(c0[k] + (c1[k] - c0[k]) * f)) for k in range(3))
    return fn


def color_swap(im, mapping):
    """Exact colour replacement {(r,g,b): (r,g,b)}."""
    return remap(im, lambda r, g, b: mapping.get((r, g, b), (r, g, b)))


def tint_white(im, strength=1.0):
    """White silhouette (hit flash frame)."""
    a = np.array(im)
    m = a[..., 3] > 0
    a[m, :3] = (a[m, :3] * (1 - strength) + 255 * strength).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def outline(im, color=OUTLINE, width=1, diagonal=False):
    """Add an outer outline of the given width (canvas grows by width on every side)."""
    w = width
    src = canvas(im.width + 2 * w, im.height + 2 * w)
    src.alpha_composite(im, (w, w))
    a = np.array(src)
    solid = a[..., 3] > 0
    grown = solid.copy()
    for _ in range(w):
        g = grown.copy()
        g[1:, :] |= grown[:-1, :]; g[:-1, :] |= grown[1:, :]
        g[:, 1:] |= grown[:, :-1]; g[:, :-1] |= grown[:, 1:]
        if diagonal:
            g[1:, 1:] |= grown[:-1, :-1]; g[:-1, :-1] |= grown[1:, 1:]
            g[1:, :-1] |= grown[:-1, 1:]; g[:-1, 1:] |= grown[1:, :-1]
        grown = g
    edge = grown & ~solid
    a[edge] = color
    return Image.fromarray(a, "RGBA")


def palette(im, n=12):
    a = np.array(im).reshape(-1, 4)
    a = a[a[:, 3] > 0][:, :3]
    cols, cnt = np.unique(a, axis=0, return_counts=True)
    order = np.argsort(-cnt)[:n]
    return [("#%02x%02x%02x" % tuple(cols[i]), int(cnt[i])) for i in order]


# ----------------------------------------------------------------------------- sheets
def fit_cell(frames, pivots, below=FOOT, round_to=8, min_w=0, min_h=0):
    """Smallest symmetric cell (pivot at (w/2, h-below)) that holds every frame."""
    half = up = 0
    for im, (px, py) in zip(frames, pivots):
        b = bbox(im)
        if not b:
            continue
        half = max(half, px - b[0], b[2] - px)
        up = max(up, py - b[1])
        if b[3] - py > below:
            raise ValueError("frame reaches %d px below the baseline (limit %d)" % (b[3] - py, below))
    w = int(math.ceil(2 * half / round_to) * round_to)
    h = int(math.ceil((up + below) / round_to) * round_to)
    return max(w, min_w), max(h, min_h)


def pack(frames, pivots, cols=None, cell=None, below=FOOT, min_w=0, min_h=0):
    """Pack frames into a uniform grid; every frame's pivot lands on (cell_w/2, cell_h-below)."""
    cw, ch = cell if cell else fit_cell(frames, pivots, below, min_w=min_w, min_h=min_h)
    n = len(frames)
    cols = cols or min(n, 8)
    rows = int(math.ceil(n / cols))
    sheet = canvas(cols * cw, rows * ch)
    for i, (im, (px, py)) in enumerate(zip(frames, pivots)):
        ox = (i % cols) * cw + cw // 2 - int(px)
        oy = (i // cols) * ch + ch - below - int(py)
        tmp = canvas(cw, ch)
        tmp = over(tmp, im, (cw // 2 - int(px), ch - below - int(py)))
        b = bbox(im)
        if b:
            x0, y0 = b[0] + cw // 2 - int(px), b[1] + ch - below - int(py)
            x1, y1 = b[2] + cw // 2 - int(px), b[3] + ch - below - int(py)
            if x0 < 0 or y0 < 0 or x1 > cw or y1 > ch:
                print("  WARNING frame %d clipped: bbox (%d,%d,%d,%d) in cell %dx%d" % (i, x0, y0, x1, y1, cw, ch))
        sheet.alpha_composite(tmp, ((i % cols) * cw, (i // cols) * ch))
    return sheet, (cw, ch, cols, rows)


def strip(frames, cols=None):
    """Pack equally sized frames left to right / top to bottom."""
    cw, ch = frames[0].size
    cols = cols or len(frames)
    rows = int(math.ceil(len(frames) / cols))
    sheet = canvas(cols * cw, rows * ch)
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, ((i % cols) * cw, (i // cols) * ch))
    return sheet


def anim(frames, fps, loop=True):
    return {"frames": list(frames), "fps": fps, "loop": loop}

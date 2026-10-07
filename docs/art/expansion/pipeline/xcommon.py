"""Shared helpers of the 2.0 ("The Far Shore") art pipeline, art-A part (hero palettes, co-op objects, indicators).

Builds on the 1.0 pipeline helpers (docs/art/pipeline/common.py: nearest-neighbour only, palette-preserving recolours,
uniform sheets, pivots at the feet). Every file written under assets/ is recorded in registry_expansion.json next to
this script; build_expansion.py turns that registry into the 2.0 section of docs/ASSET_MANIFEST.md.

Sources are only: shipped CC0 game art under assets/ (Superpowers Prehistoric Platformer, via the 1.0 pipeline) and
the staged CC0 packs under .tools/asset_candidates/ (see their LICENSE_INFO.md). Run with the project venv:
    .tools/venv/Scripts/python.exe docs/art/expansion/pipeline/build_expansion.py
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "pipeline"))
from common import (canvas, paste, over, under, trim, bbox, scale, pad_to, rotate_px, outline, pack, strip, anim,  # noqa
                    grid_cells, flip, vflip, remap, ramp_fn, hsv_fn, load)

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
ASSETS = os.path.join(ROOT, "assets")
CAND = os.path.join(ROOT, ".tools", "asset_candidates")
AP = os.path.join(CAND, "environment", "superpowers-prehistoric-platformer")
EXP = os.path.join(CAND, "expansion")
WF = os.path.join(EXP, "superpowers-western-fps-2d")
DOCS = os.path.join(ROOT, "docs", "art", "expansion")
REG_PATH = os.path.join(HERE, "registry_expansion.json")

OUTLINE = (0x27, 0x20, 0x18)          # anchor outline #272018
CELL = (176, 112)                     # hero sheet cell (ASSET_MANIFEST 3)
GRID = (8, 7)

PACK_SP = "Superpowers Asset Packs - Prehistoric Platformer (Pixel-boy / Sparklin Labs), CC0 1.0"
PACK_WF = "Superpowers Asset Packs - Western FPS 2D (Pixel-boy / Sparklin Labs), CC0 1.0"

REGISTRY = {}


def load_registry():
    if os.path.exists(REG_PATH):
        with open(REG_PATH, encoding="utf-8") as f:
            REGISTRY.update(json.load(f))
    return REGISTRY


def save_registry():
    with open(REG_PATH, "w", encoding="utf-8", newline="\n") as f:
        json.dump(REGISTRY, f, indent=1, sort_keys=True)
        f.write("\n")


def save(im, rel, **meta):
    """Write a PNG under assets/ (RGBA unless the image is L / LA / RGB on purpose) and record it."""
    path = os.path.join(ASSETS, *rel.split("/"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)
    entry = {"size": list(im.size)}
    entry.update(meta)
    entry.setdefault("license", "CC0 1.0")
    REGISTRY["assets/" + rel] = entry
    return path


def save_doc(im, name):
    """Write a preview / proof sheet under docs/art/expansion/."""
    path = os.path.join(DOCS, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)
    return path


def asset(rel):
    return load(os.path.join(ASSETS, *rel.split("/")))


def ap(rel):
    return load(os.path.join(AP, *rel.split("/")))


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexs(c):
    return "#%02x%02x%02x" % tuple(int(v) for v in c[:3])


def swap(im, mapping):
    """Exact per-colour swap {(r,g,b): (r,g,b)} - lossless palette edit, alpha kept."""
    a = np.array(im.convert("RGBA"))
    out = a.copy()
    for src, dst in mapping.items():
        m = (a[..., 0] == src[0]) & (a[..., 1] == src[1]) & (a[..., 2] == src[2]) & (a[..., 3] > 0)
        out[m, 0], out[m, 1], out[m, 2] = dst[0], dst[1], dst[2]
    return Image.fromarray(out, "RGBA")


def gradient_map(im, ramp, keep=(OUTLINE,)):
    """Map every colour by luminance onto a ramp of hex colours (1.0 pipeline method); listed colours are kept."""
    keep = {tuple(k) for k in keep}
    stops = [rgb(c) for c in ramp]

    def fn(r, g, b):
        if (r, g, b) in keep:
            return (r, g, b)
        l = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
        t = l * (len(stops) - 1)
        i = min(int(t), len(stops) - 2)
        f = t - i
        # palette-preserving: snap to the nearer stop, no new in-between colours
        return stops[i] if f < 0.5 else stops[i + 1]
    return remap(im, fn)


def colours(im):
    a = np.array(im.convert("RGBA"))
    px = a[a[..., 3] > 0][:, :3]
    return {tuple(int(v) for v in c) for c in np.unique(px, axis=0)}


def cut(im, box):
    return im.crop(box)


def hstack(ims, gap=0, bg=(0, 0, 0, 0)):
    w = sum(i.width for i in ims) + gap * (len(ims) - 1)
    h = max(i.height for i in ims)
    out = Image.new("RGBA", (w, h), bg)
    x = 0
    for i in ims:
        out.alpha_composite(i, (x, 0))
        x += i.width + gap
    return out


def vstack(ims, gap=0, bg=(0, 0, 0, 0)):
    w = max(i.width for i in ims)
    h = sum(i.height for i in ims) + gap * (len(ims) - 1)
    out = Image.new("RGBA", (w, h), bg)
    y = 0
    for i in ims:
        out.alpha_composite(i, (0, y))
        y += i.height + gap
    return out


def font_text(img, s, x, y, scale_n=1, colour=None):
    """Shipped HUD bitmap font (assets/fonts/font_hud.png, 15 x 8 glyphs of 20 x 20, ASCII from 32)."""
    font = asset("fonts/font_hud.png")
    for ch in s:
        i = ord(ch) - 32
        g = font.crop(((i % 15) * 20, (i // 15) * 20, (i % 15) * 20 + 20, (i // 15) * 20 + 20))
        if colour is not None:
            g = tint_white(g, colour)
        if scale_n != 1:
            g = scale(g, scale_n)
        img.alpha_composite(g, (int(x), int(y)))
        x += 14 * scale_n
    return img


def tint_white(im, colour):
    """Recolour the light (fill) pixels of a white-on-dark-outline glyph / icon; dark outline kept."""
    a = np.array(im.convert("RGBA"))
    lum = a[..., :3].astype(int).sum(axis=2) / 3
    m = (a[..., 3] > 0) & (lum > 150)
    out = a.copy()
    out[m, 0], out[m, 1], out[m, 2] = colour[0], colour[1], colour[2]
    return Image.fromarray(out, "RGBA")


def checker(w, h, a=(200, 200, 200, 255), b=(230, 230, 230, 255), n=8):
    out = Image.new("RGBA", (w, h), a)
    px = out.load()
    for y in range(h):
        for x in range(w):
            if ((x // n) + (y // n)) % 2:
                px[x, y] = b
    return out


def label(img, text, x, y, fill=(255, 255, 255, 255)):
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        d.text((x + dx, y + dy), text, fill=(0, 0, 0, 255))
    d.text((x, y), text, fill=fill)
    return img

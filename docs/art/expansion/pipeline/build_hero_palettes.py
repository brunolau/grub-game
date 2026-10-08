"""Hero colours for P1-P4: 16 x 1 palette LUTs, the loincloth-pattern atlas and the proofs (DESIGN D.1, E.9, F.1).

Runtime contract (the shader is player-A's, PLAN P1.4 `hero_palette.gd`; this file is its executable reference):

  key LUT  `palettes/hero_lut_key.png` (16 x 1): the 1.0 colours the shader replaces (alpha 0 = unused entry).
  slot LUT `palettes/hero_lut_<colour>.png` (16 x 1): the replacement for each key entry, same order.
           `yellow` == key, so P1 with pattern 0 reproduces 1.0 exactly (asserted below on all five hero sheets).
  cloth    `palettes/hero_cloth.png` (8 x 7 windows of WIN, one per sheet cell): for every loincloth pixel of the
           window at WIN_ORIGIN inside its 176 x 112 cell: R = pattern bits 0-7, G = pattern bits 8-15, B = the cloth
           tone under it (1 main, 2 shadow), A = 255. Pattern k inks the pixel when bit k is set.
  fragment: c = sheet texel; i = index of c in the key LUT (exact RGB match) or none -> c unchanged.
           if i is a cloth entry (0 main, 1 shadow, 2 ink) and the texel lies in the cell's window:
               a = cloth texel; i = bit(pattern, a) ? 2 : (a.B == 2 ? 1 : 0)
           out = slot_lut[i] with the alpha of c.
  The cloth of all five hero sheets (club, axe, boomerang, hammer, spear) is pixel-identical, so one atlas serves all.
  Sprites that are not hero sheets (the revive egg) use the LUTs with the pattern step switched off.
"""
import json
import os

import numpy as np
from PIL import Image

import cvd
from backdrops import ALL as BIOMES, GROUND_Y, backdrop
from xcommon import (ASSETS, CELL, GRID, PACK_SP, REGISTRY, asset, hexs, label, rgb, save, save_doc, scale, vstack,
                     hstack)

OUT = "sprites/player/palettes/"

# ---------------------------------------------------------------------------------------------------- the LUT layout
ROLES = ["cloth", "cloth_shadow", "ink", "outline", "hair_a", "hair_b", "skin", "skin_shadow", "skin_dark", "cheek"]
KEY = {
    "cloth": "#ffe94f", "cloth_shadow": "#f3aa39", "ink": "#63513a",       # loincloth main / shadow / leopard spots
    "outline": "#272018", "hair_a": "#351f21", "hair_b": "#362022",        # 2 px outline (+ weapon outlines), hair
    "skin": "#ffa43a", "skin_shadow": "#f07731", "skin_dark": "#ec6c2f", "cheek": "#eb6439",
}
SKIN = {k: KEY[k] for k in ("skin", "skin_shadow", "skin_dark", "cheek")}

# Colour names, not slots: versus lets players pick (DESIGN E.8); the slot defaults are below.
# Chosen by a constrained search (CIEDE2000 between every pair of cloth colours, P1 yellow fixed, under normal vision
# and Machado 2009 protanopia / deuteranopia / tritanopia plus Vienot 1999 protan / deutan): light cloth with a dark
# pattern for yellow / blue, dark cloth with a light pattern for pink / green, so the pairs that share a lightness
# also differ in pattern. Outline + hair carry a very dark tint of the colour (Joe & Mac style silhouette cue).
PALETTES = {
    "yellow": dict(KEY),
    "blue":   dict(cloth="#8ae6ff", cloth_shadow="#3f9fe8", ink="#1b4a8c", outline="#142a55", hair_a="#1f3a70",
                   hair_b="#1f3a70", **SKIN),
    "pink":   dict(cloth="#c41f8f", cloth_shadow="#861465", ink="#ffa8de", outline="#3d0d33", hair_a="#5a1650",
                   hair_b="#5a1650", **SKIN),
    "green":  dict(cloth="#13893d", cloth_shadow="#0b5c35", ink="#a6ee7c", outline="#0e321d", hair_a="#17462a",
                   hair_b="#17462a", **SKIN),
    # P4 on jungle-green arenas (DESIGN E.9): bone white, cool grey shade, slate pattern
    "white":  dict(cloth="#f7f4ec", cloth_shadow="#b7bfd2", ink="#4c5a86", outline="#2c2c3a", hair_a="#3e3e52",
                   hair_b="#3e3e52", **SKIN),
    # unlock at 25 paintings (DESIGN C.9): metallic gold, sparkle pattern; counts as the yellow family in a lobby
    "gold":   dict(cloth="#ffc928", cloth_shadow="#c97d10", ink="#fff7c2", outline="#3f2508", hair_a="#5a360c",
                   hair_b="#5a360c", **SKIN),
}
SLOT_DEFAULT = {1: ("yellow", "spots"), 2: ("blue", "stripes"), 3: ("pink", "zigzag"), 4: ("green", "plain")}
ARENA_SWAPS = {"jungle": {"green": "white"}, "swamp": {"green": "white"}}   # filled by the biome check below

# ---------------------------------------------------------------------------------------------------- patterns
# Bits 0-3 are the slot defaults; bits 4-7 the four patterns that unlock at 5 paintings, bits 8-11 the four at 10
# (DESIGN C.9, the ladder after cut 3 [G60]).
# Each is a function of the pixel's position (lx, ly) from the top-left of that frame's cloth, the cloth size (w, h)
# and its distance to the cloth edge (edge), evaluated once per frame here and baked into the atlas.
PATTERNS = [
    ("spots", "the 1.0 leopard spots (the sheet's own ink pixels)"),
    ("plain", "no pattern"),
    ("stripes", "2 px bands every 5 px"),
    ("zigzag", "2 px zigzag band every 6 px, 8 px wavelength"),
    ("checks", "4 px checkerboard"),
    ("dots", "2 x 2 dots on a staggered 5 px grid"),
    ("tiger", "2 px diagonal stripes every 6 px"),
    ("pinstripes", "2 px vertical stripes every 5 px"),
    ("diamonds", "diamonds of radius 2 on an 8 px grid"),
    ("waves", "2 px rounded wave every 6 px"),
    ("sash", "one 5 px diagonal sash across the cloth"),
    ("trim", "2 px border along the cloth edge"),
]
PATTERN_INDEX = {n: i for i, (n, _) in enumerate(PATTERNS)}
_WAVE = [0, 0, 1, 2, 2, 2, 1, 0]


def pattern_ink(name, lx, ly, w, h, edge, spot):
    if name == "spots":
        return spot
    if name == "plain":
        return False
    if name == "stripes":
        return (ly + 1) % 5 < 2
    if name == "zigzag":
        t = lx % 8
        return (ly + (t if t < 4 else 8 - t)) % 6 < 2
    if name == "checks":
        return ((lx // 4) + (ly // 4)) % 2 == 0
    if name == "dots":
        return (ly % 5) in (1, 2) and ((lx + 2 * ((ly // 5) % 2)) % 5) in (1, 2)
    if name == "tiger":
        return (lx + ly) % 6 < 2
    if name == "pinstripes":
        return (lx + 1) % 5 < 2
    if name == "diamonds":
        return abs(lx % 8 - 4) + abs((ly + 2) % 8 - 4) <= 2
    if name == "waves":
        return (ly + _WAVE[lx % 8]) % 6 < 2
    if name == "sash":
        return abs((lx - (w - h) // 2) - ly) <= 2
    if name == "trim":
        return edge <= 1
    raise KeyError(name)


# ---------------------------------------------------------------------------------------------------- analysis
SHEETS = ["hero", "hero_axe", "hero_boomerang", "hero_hammer", "hero_spear"]


def cloth_classes(a):
    """per pixel: 0 none, 1 main, 2 shadow, 3 ink (spot)"""
    m = np.zeros(a.shape[:2], np.uint8)
    for i, role in enumerate(("cloth", "cloth_shadow", "ink")):
        c = rgb(KEY[role])
        m[(a[..., 0] == c[0]) & (a[..., 1] == c[1]) & (a[..., 2] == c[2]) & (a[..., 3] > 0)] = i + 1
    return m


def under_spot(m):
    """class beneath each spot pixel: the majority of main / shadow at the nearest ring that has any (ties -> main)"""
    out = m.copy()
    ys, xs = np.nonzero(m == 3)
    H, W = m.shape
    for y, x in zip(ys, xs):
        cls = 1
        for r in range(1, 8):
            win = m[max(0, y - r):min(H, y + r + 1), max(0, x - r):min(W, x + r + 1)]
            n1, n2 = int((win == 1).sum()), int((win == 2).sum())
            if n1 + n2:
                cls = 1 if n1 >= n2 else 2
                break
        out[y, x] = cls
    return out


def edge_distance(mask):
    """city-block distance (in px) from each cloth pixel to the nearest non-cloth pixel, minus 1 (border = 0)"""
    INF = 99
    d = np.where(mask, INF, 0).astype(np.int32)
    H, W = d.shape
    for _ in range(2):
        for y in range(H):
            for x in range(W):
                if d[y, x]:
                    up = d[y - 1, x] if y else 0
                    lf = d[y, x - 1] if x else 0
                    d[y, x] = min(d[y, x], up + 1, lf + 1)
        for y in range(H - 1, -1, -1):
            for x in range(W - 1, -1, -1):
                if d[y, x]:
                    dn = d[y + 1, x] if y < H - 1 else 0
                    rt = d[y, x + 1] if x < W - 1 else 0
                    d[y, x] = min(d[y, x], dn + 1, rt + 1)
    return np.where(mask, d - 1, -1)


def clean_isolated(ink, mask):
    """drop ink pixels with no inked 4-neighbour (single-pixel noise at the cloth's thin ends)"""
    out = ink.copy()
    H, W = ink.shape
    for y, x in zip(*np.nonzero(ink)):
        n = 0
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < H and 0 <= xx < W and ink[yy, xx]:
                n += 1
        if n == 0:
            out[y, x] = False
    return out


def cloth_window(classes):
    """union bounding box of the cloth over all cells, as (origin x, origin y, w, h) inside a cell"""
    x0 = y0 = 10 ** 6
    x1 = y1 = -1
    for f in range(GRID[0] * GRID[1]):
        cx, cy = (f % GRID[0]) * CELL[0], (f // GRID[0]) * CELL[1]
        sub = classes[cy:cy + CELL[1], cx:cx + CELL[0]]
        ys, xs = np.nonzero(sub)
        if len(xs):
            x0, x1 = min(x0, xs.min()), max(x1, xs.max())
            y0, y1 = min(y0, ys.min()), max(y1, ys.max())
    x0, y0 = int(x0) - 1, int(y0) - 1          # 1 px margin, then round the size up to even
    w, h = int(x1) + 2 - x0, int(y1) + 2 - y0
    return x0, y0, w + (w % 2), h + (h % 2)


def build_atlas(sheet):
    a = np.array(sheet)
    classes = cloth_classes(a)
    beneath = under_spot(classes)
    wx, wy, ww, wh = cloth_window(classes)
    atlas = np.zeros((wh * GRID[1], ww * GRID[0], 4), np.uint8)
    for f in range(GRID[0] * GRID[1]):
        cx, cy = (f % GRID[0]) * CELL[0], (f // GRID[0]) * CELL[1]
        cls = classes[cy + wy:cy + wy + wh, cx + wx:cx + wx + ww]
        bel = beneath[cy + wy:cy + wy + wh, cx + wx:cx + wx + ww]
        mask = cls > 0
        if not mask.any():
            continue
        ys, xs = np.nonzero(mask)
        ox, oy = xs.min(), ys.min()
        w, h = xs.max() - ox + 1, ys.max() - oy + 1
        edge = edge_distance(mask)
        bits = np.zeros(mask.shape, np.uint32)
        for k, (name, _) in enumerate(PATTERNS):
            ink = np.zeros(mask.shape, bool)
            for y, x in zip(ys, xs):
                ink[y, x] = pattern_ink(name, x - ox, y - oy, w, h, edge[y, x], cls[y, x] == 3)
            if name not in ("spots", "dots", "trim"):
                ink = clean_isolated(ink, mask)
            bits |= (ink.astype(np.uint32) << k)
        ax, ay = (f % GRID[0]) * ww, (f // GRID[0]) * wh
        blk = atlas[ay:ay + wh, ax:ax + ww]
        blk[..., 0] = np.where(mask, bits & 0xFF, 0)
        blk[..., 1] = np.where(mask, (bits >> 8) & 0xFF, 0)
        blk[..., 2] = np.where(mask, bel, 0)
        blk[..., 3] = np.where(mask, 255, 0)
    return Image.fromarray(atlas, "RGBA"), (wx, wy, ww, wh), classes


def ui_ramp(pal):
    """UI colours of a palette (tags, arrows, HUD frames): fill = the loincloth colour, so P1 / P2 stay light and P3 /
    P4 dark exactly like the heroes (the lightness split that keeps them apart under red-green CVD); light = the
    lighter of cloth and ink (white when the cloth is the light one); shade = cloth shadow; dark = the outline tint."""
    def lum(h):
        c = rgb(h)
        return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
    cloth, ink = pal["cloth"], pal["ink"]
    light = ink if lum(ink) > lum(cloth) else "#ffffff"
    return {"fill": rgb(cloth), "light": rgb(light), "shade": rgb(pal["cloth_shadow"]), "dark": rgb(pal["outline"])}


def lut_image(pal):
    im = Image.new("RGBA", (16, 1), (0, 0, 0, 0))
    for i, role in enumerate(ROLES):
        im.putpixel((i, 0), rgb(pal[role]) + (255,))
    return im


# ---------------------------------------------------------------------------------------------------- reference shader
class Palettes:
    """Reads the shipped files back and applies them exactly as the shader must."""

    def __init__(self):
        base = os.path.join(ASSETS, *OUT.split("/"))
        key = np.array(Image.open(os.path.join(base, "hero_lut_key.png")).convert("RGBA"))[0]
        self.key = [(tuple(int(v) for v in k[:3]), i) for i, k in enumerate(key) if k[3] > 0]
        self.luts = {}
        for name in PALETTES:
            self.luts[name] = np.array(Image.open(os.path.join(base, "hero_lut_%s.png" % name)).convert("RGBA"))[0]
        self.atlas = np.array(Image.open(os.path.join(base, "hero_cloth.png")).convert("RGBA"))
        meta = json.load(open(os.path.join(base, "hero_palettes.json"), encoding="utf-8"))
        self.win = meta["cloth_window"]

    def apply(self, img, colour, pattern=0, use_cloth=True):
        a = np.array(img.convert("RGBA"))
        out = a.copy()
        lut = self.luts[colour]
        H, W = a.shape[:2]
        idx = np.full((H, W), -1, np.int16)
        for c, i in self.key:
            m = (a[..., 0] == c[0]) & (a[..., 1] == c[1]) & (a[..., 2] == c[2]) & (a[..., 3] > 0)
            idx[m] = i
        if use_cloth:
            wx, wy, ww, wh = self.win["x"], self.win["y"], self.win["w"], self.win["h"]
            ys, xs = np.nonzero((idx >= 0) & (idx <= 2))
            for y, x in zip(ys, xs):
                col, row = x // CELL[0], y // CELL[1]
                lx, ly = x - col * CELL[0] - wx, y - row * CELL[1] - wy
                if 0 <= lx < ww and 0 <= ly < wh:
                    t = self.atlas[row * wh + ly, col * ww + lx]
                    if t[3]:
                        bits = int(t[0]) | (int(t[1]) << 8)
                        idx[y, x] = 2 if (bits >> pattern) & 1 else (1 if t[2] == 2 else 0)
        m = idx >= 0
        out[m, 0] = lut[idx[m], 0]
        out[m, 1] = lut[idx[m], 1]
        out[m, 2] = lut[idx[m], 2]
        return Image.fromarray(out, "RGBA")


def frame(sheet, f):
    cx, cy = (f % GRID[0]) * CELL[0], (f // GRID[0]) * CELL[1]
    return sheet.crop((cx, cy, cx + CELL[0], cy + CELL[1]))


# ---------------------------------------------------------------------------------------------------- checks
def cvd_report():
    """Minimum CIEDE2000 over every pair of the four slot colours (cloth main, cloth shadow, the cloth vs the skin)."""
    names = [SLOT_DEFAULT[s][0] for s in (1, 2, 3, 4)]
    sims = [("normal", "machado"), ("protan", "machado"), ("deutan", "machado"), ("tritan", "machado"),
            ("protan", "vienot"), ("deutan", "vienot")]
    rows = []
    worst = {}
    for role in ("cloth", "cloth_shadow"):
        for i in range(4):
            for j in range(i + 1, 4):
                a, b = PALETTES[names[i]][role], PALETTES[names[j]][role]
                ds = [cvd.de(rgb(a), rgb(b), k, m) for k, m in sims]
                rows.append((role, names[i], names[j], ds))
                worst[role] = min(worst.get(role, 99), min(ds))
    skin = []
    for n in list(PALETTES):
        ds = [cvd.de(rgb(PALETTES[n]["cloth"]), rgb(KEY["skin"]), k, m) for k, m in sims]
        skin.append((n, ds))
    extra = []
    for alt, base in (("white", "green"), ("gold", "yellow")):
        for n in names:
            if n == base:
                continue
            ds = [cvd.de(rgb(PALETTES[alt]["cloth"]), rgb(PALETTES[n]["cloth"]), k, m) for k, m in sims]
            extra.append((alt, n, ds))
    return sims, rows, worst, skin, extra


def biome_report():
    """Per biome: share of background pixels behind a standing hero within CIEDE2000 10 of each cloth colour."""
    res = {}
    for b in BIOMES:
        bg = np.array(backdrop(b))[GROUND_Y - 60:GROUND_Y, :, :3].reshape(-1, 3)
        cols, counts = np.unique(bg, axis=0, return_counts=True)
        lab = cvd.to_lab(cols)
        res[b] = {}
        for n in PALETTES:
            d = cvd.de2000(lab, cvd.to_lab(np.array(rgb(PALETTES[n]["cloth"]))))
            res[b][n] = float(counts[d < 10].sum() / counts.sum())
    return res


# ---------------------------------------------------------------------------------------------------- previews
BG = (58, 66, 84, 255)
SHOW = [(0, "idle"), (8, "walk"), (15, "jump"), (29, "attack"), (21, "crouch"), (24, "curl"), (37, "hurt"),
        (44, "climb"), (48, "victory"), (50, "glide")]


def hero_crop(img):
    return img.crop((40, 24, 136, 104))          # 96 x 80 around the feet point (88, 96)


def tile_bg(w, h, colour=BG):
    return Image.new("RGBA", (w, h), colour)


def preview_frames(P, sheets):
    rows = []
    for s in (1, 2, 3, 4):
        colour, pat = SLOT_DEFAULT[s]
        cells = []
        for f, _ in SHOW:
            t = tile_bg(96, 80)
            t.alpha_composite(hero_crop(P.apply(frame(sheets["hero"], f), colour, PATTERN_INDEX[pat])))
            cells.append(t)
        row = hstack(cells, 2, BG)
        rows.append(row)
    sheet = scale(vstack(rows, 2, BG), 2)
    head = tile_bg(sheet.width, 24)
    for k, (f, n) in enumerate(SHOW):
        label(head, "%s %d" % (n, f), 6 + k * 196, 6)
    out = vstack([head, sheet], 0, BG)
    for s in (1, 2, 3, 4):
        colour, pat = SLOT_DEFAULT[s]
        label(out, "P%d %s / %s" % (s, colour, pat), 4, 24 + (s - 1) * 164 + 4, (255, 255, 120, 255))
    return out


def preview_weapons(P, sheets):
    rows = []
    for s in (1, 2, 3, 4):
        colour, pat = SLOT_DEFAULT[s]
        cells = []
        for sh in SHEETS:
            if sh not in sheets:
                continue
            for f in (0, 29, 35):
                t = tile_bg(96, 80)
                t.alpha_composite(hero_crop(P.apply(frame(sheets[sh], f), colour, PATTERN_INDEX[pat])))
                cells.append(t)
        rows.append(hstack(cells, 2, BG))
    out = scale(vstack(rows, 2, BG), 2)
    for k, sh in enumerate(sh for sh in SHEETS if sh in sheets):
        label(out, sh, 6 + k * 3 * 196, 4)
    return out


def preview_cvd(P, sheets):
    walk = [0, 8, 15, 24, 48]                    # idle, walk, jump, curl, victory (all fit a 66 px column)
    group = []
    for f in walk:
        t = tile_bg(4 * 66, 80)
        for s in (1, 2, 3, 4):
            colour, pat = SLOT_DEFAULT[s]
            h = hero_crop(P.apply(frame(sheets["hero"], f), colour, PATTERN_INDEX[pat]))
            t.alpha_composite(h.crop((14, 0, 80, 80)), ((s - 1) * 66, 0))
        group.append(t)
    base = hstack(group, 6, BG)
    rows = []
    for kind, model, name in (("normal", "machado", "normal vision"), ("protan", "machado", "protanopia (Machado 2009)"),
                              ("deutan", "machado", "deuteranopia (Machado 2009)"),
                              ("tritan", "machado", "tritanopia (Machado 2009)"),
                              ("protan", "vienot", "protanopia (Vienot 1999)"),
                              ("deutan", "vienot", "deuteranopia (Vienot 1999)"), ("grey", None, "greyscale (luminance)")):
        if kind == "grey":
            g = base.convert("LA").convert("RGBA")
        else:
            g = cvd.simulate_image(base, kind, model)
        r = scale(g, 2)
        r = vstack([tile_bg(r.width, 20), r], 0, BG)
        label(r, name + "   (left to right in each group: P1 P2 P3 P4)", 6, 4)
        rows.append(r)
    return vstack(rows, 4, BG)


def preview_patterns(P, sheets):
    cols = []
    for colour in ("yellow", "blue", "pink", "green", "white", "gold"):
        cells = []
        for k, (name, _) in enumerate(PATTERNS):
            t = tile_bg(132, 62)
            for j, f in enumerate((0, 9, 24)):
                h = hero_crop(P.apply(frame(sheets["hero"], f), colour, k))
                t.alpha_composite(h.crop((24, 18, 68, 80)), (j * 44, 0))
            cells.append(t)
        cols.append(vstack(cells, 2, BG))
    body = scale(hstack(cols, 6, BG), 2)
    head = tile_bg(body.width, 22)
    for i, colour in enumerate(("yellow", "blue", "pink", "green", "white", "gold")):
        label(head, colour, 8 + i * 276, 5)
    out = vstack([head, body], 0, BG)
    for k, (name, _) in enumerate(PATTERNS):
        label(out, "%d %s" % (k, name), 4, 22 + k * 128 + 4, (255, 255, 120, 255))
    return out


def preview_walk_strip(P, sheets):
    """pattern stability over the walk + idle cycles (frames 0-13), 3x"""
    rows = []
    for colour, pat in (("blue", "stripes"), ("pink", "zigzag"), ("green", "checks"), ("yellow", "sash"),
                        ("white", "diamonds"), ("gold", "trim")):
        cells = []
        for f in range(14):
            t = tile_bg(52, 60)
            h = hero_crop(P.apply(frame(sheets["hero"], f), colour, PATTERN_INDEX[pat]))
            t.alpha_composite(h.crop((22, 20, 74, 80)))
            cells.append(t)
        r = hstack(cells, 2, BG)
        rows.append(r)
    out = scale(vstack(rows, 2, BG), 3)
    for i, (colour, pat) in enumerate((("blue", "stripes"), ("pink", "zigzag"), ("green", "checks"),
                                       ("yellow", "sash"), ("white", "diamonds"), ("gold", "trim"))):
        label(out, "%s / %s, frames 0-13 (idle, walk)" % (colour, pat), 4, i * 186 + 2, (255, 255, 120, 255))
    return out


def preview_biomes(P, sheets):
    panels = []
    for b in BIOMES:
        bg = backdrop(b, x0=200)
        slots = [(1, None), (2, None), (3, None), (4, None)]
        frames_ = [0, 8, 29, 14]
        for k, (s, _) in enumerate(slots):
            colour, pat = SLOT_DEFAULT[s]
            colour = ARENA_SWAPS.get(b, {}).get(colour, colour)
            h = P.apply(frame(sheets["hero"], frames_[k]), colour, PATTERN_INDEX[pat])
            bg.alpha_composite(h, (k * 112 - 40, GROUND_Y - 96))
        if b in ARENA_SWAPS:          # also the plain green on these, to show why it swaps
            h = P.apply(frame(sheets["hero"], 0), "green", PATTERN_INDEX["plain"])
            bg.alpha_composite(h, (410, GROUND_Y - 96))
            label(bg, "green (swapped out)", 450, GROUND_Y + 4)
        panel = bg.crop((0, GROUND_Y - 150, 600, GROUND_Y + 34))
        label(panel, b, 4, 4)
        panels.append(panel)
    rows = [hstack(panels[i:i + 2], 4, BG) for i in range(0, len(panels), 2)]
    return vstack(rows, 4, BG)


def preview_swatches():
    names = list(PALETTES)
    out = tile_bg(150 * len(names), 16 * 22 + 30)
    from PIL import ImageDraw
    d = ImageDraw.Draw(out)
    for c, n in enumerate(names):
        label(out, n, c * 150 + 6, 6)
        for i, role in enumerate(ROLES):
            y = 28 + i * 22
            d.rectangle((c * 150 + 6, y, c * 150 + 30, y + 18), fill=rgb(PALETTES[n][role]) + (255,))
            label(out, "%d %s" % (i, PALETTES[n][role]), c * 150 + 36, y + 3)
    for i, role in enumerate(ROLES):
        label(out, role, 6 + 150 * len(names) - 150 + 0, 0) if False else None
    return out


# ---------------------------------------------------------------------------------------------------- build
def build(write_previews=True):
    sheets = {}
    for s in SHEETS:
        p = os.path.join(ASSETS, "sprites", "player", s + ".png")
        if os.path.exists(p):
            sheets[s] = Image.open(p).convert("RGBA")
    atlas, (wx, wy, ww, wh), classes = build_atlas(sheets["hero"])
    for s, im in sheets.items():
        assert np.array_equal(cloth_classes(np.array(im)), classes), "cloth of %s differs from hero.png" % s
    # LUTs
    key = lut_image(KEY)
    save(key, OUT + "hero_lut_key.png", kind="lut", frame=[16, 1], grid=[1, 1],
         source="measured from sprites/player/hero.png (1.0)", edits="16 x 1 colour key, entries 0-9 used",
         note="the 1.0 hero colours the palette shader replaces (alpha 0 = unused entry)")
    for name, pal in PALETTES.items():
        save(lut_image(pal), OUT + "hero_lut_%s.png" % name, kind="lut", frame=[16, 1], grid=[1, 1],
             source="hand-picked ramp (see build_hero_palettes.py)", edits="16 x 1, same order as the key",
             note="hero colour '%s'%s" % (name, " (= key: the 1.0 look)" if name == "yellow" else ""))
    save(atlas, OUT + "hero_cloth.png", kind="data", frame=[ww, wh], grid=list(GRID),
         source="computed from the cloth pixels of sprites/player/hero.png",
         edits="per cloth pixel R/G = pattern bits, B = tone under the pixel (1 main, 2 shadow), A = 255",
         note="loincloth pattern atlas: one %d x %d window per hero cell at (%d, %d) of the 176 x 112 cell" % (ww, wh, wx, wy))
    meta = {
        "lut_roles": ROLES,
        "palettes": {n: {r: p[r] for r in ROLES} for n, p in PALETTES.items()},
        "slot_defaults": {"p%d" % s: {"colour": c, "pattern": p} for s, (c, p) in SLOT_DEFAULT.items()},
        "arena_swaps": ARENA_SWAPS,
        "patterns": [{"index": i, "name": n, "rule": d,
                      "unlock": "default" if i < 4 else ("paintings_5" if i < 8 else "paintings_10")}
                     for i, (n, d) in enumerate(PATTERNS)],
        "cloth_window": {"x": wx, "y": wy, "w": ww, "h": wh, "cell_w": CELL[0], "cell_h": CELL[1],
                         "columns": GRID[0], "rows": GRID[1]},
        "cloth_entries": [0, 1, 2],
        "ui_colours": {n: {k: hexs(v) for k, v in ui_ramp(p).items()} for n, p in PALETTES.items()},
        "shader": {
            "key_lut": "hero_lut_key.png", "slot_lut": "hero_lut_<colour>.png", "cloth_atlas": "hero_cloth.png",
            "match": "a texel whose RGB equals key entry i (all 8-bit channels equal; in a shader |d| < 0.5 / 255) "
                     "becomes slot_lut[i] with the texel's own alpha; key entries with alpha 0 are unused",
            "pattern": "for entries 0-2 (cloth, shadow, ink) inside the cell's cloth window: t = cloth texel at "
                       "(column * w + x - window.x, row * h + y - window.y); bits = t.r + 256 * t.g (bytes); "
                       "entry = bit(pattern) ? 2 : (t.b == 2 ? 1 : 0)",
            "sampling": "all three textures: filter nearest, no repeat, no mipmaps, read as raw bytes (no sRGB "
                        "conversion)",
            "non_hero_sheets": "hero_egg.png and any other sprite drawn in key colours: LUT only, pattern step off",
        },
    }
    path = os.path.join(ASSETS, *OUT.split("/"), "hero_palettes.json")
    text = json.dumps(meta, indent=1) + "\n"
    old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
    if old != text:                                  # unchanged: leave the file (and its mtime) alone
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    REGISTRY["assets/" + OUT + "hero_palettes.json"] = {
        "kind": "data", "license": "CC0 1.0", "source": "build_hero_palettes.py",
        "note": "colour names -> LUT roles (hex), slot defaults, arena swaps, pattern list, cloth window, UI colours"}
    # reference check: yellow + spots reproduces every 1.0 sheet exactly
    P = Palettes()
    for s, im in sheets.items():
        out = P.apply(im, "yellow", PATTERN_INDEX["spots"])
        assert np.array_equal(np.array(out), np.array(im)), "identity broken on %s" % s
    sims, rows, worst, skin, extra = cvd_report()
    biomes = biome_report()
    REGISTRY["assets/" + OUT + "hero_palettes.json"]["checks"] = {
        "identity": "yellow + spots == 1.0 on %s" % ", ".join(sorted(sheets)),
        "cvd_min_de2000": {k: round(v, 1) for k, v in worst.items()},
        "cvd_rows": [[r, a, b, [round(x, 1) for x in ds]] for r, a, b, ds in rows],
        "skin_rows": [[n, [round(x, 1) for x in ds]] for n, ds in skin],
        "alt_rows": [[a, n, [round(x, 1) for x in ds]] for a, n, ds in extra],
        "sims": ["%s/%s" % s for s in sims],
        "biome_camouflage": {b: {n: round(v, 3) for n, v in d.items()} for b, d in biomes.items()},
    }
    if write_previews:
        save_doc(preview_frames(P, sheets), "heroes_p1_p4_frames.png")
        save_doc(preview_weapons(P, sheets), "heroes_p1_p4_weapons.png")
        save_doc(preview_cvd(P, sheets), "heroes_cvd.png")
        save_doc(preview_patterns(P, sheets), "hero_patterns.png")
        save_doc(preview_walk_strip(P, sheets), "hero_patterns_walk.png")
        save_doc(preview_biomes(P, sheets), "heroes_biomes.png")
        save_doc(preview_swatches(), "hero_palette_swatches.png")
    return P, sheets


def print_report():
    data = REGISTRY["assets/" + OUT + "hero_palettes.json"]["checks"]
    print("sims:", data["sims"])
    for r, a, b, ds in data["cvd_rows"]:
        print("  %-13s %-6s %-6s %s" % (r, a, b, " ".join("%5.1f" % x for x in ds)))
    print("  min:", data["cvd_min_de2000"])
    for n, ds in data["skin_rows"]:
        print("  skin vs %-6s %s" % (n, " ".join("%5.1f" % x for x in ds)))
    for a, n, ds in data["alt_rows"]:
        print("  %-5s vs %-6s %s" % (a, n, " ".join("%5.1f" % x for x in ds)))
    print("biome camouflage share (bg pixels within dE 10 of the cloth):")
    for b, d in data["biome_camouflage"].items():
        print("  %-9s %s" % (b, " ".join("%s %.3f" % (n, v) for n, v in d.items())))


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()
    print_report()

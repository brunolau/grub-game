"""Co-op objects of DESIGN D.5 / F.1 (phase 1, PLAN P1.9 / P1.13): plate, drum, see-saw, heave boulder, pulley,
flower pot, x2 tablet, hero start, and the revive egg of D.3.

Sources: shipped 1.0 art under assets/ (all from the anchor pack, Superpowers Prehistoric Platformer, Pixel-boy, CC0)
and the anchor pack's own items; the two small shapes that no pack draws (the egg oval and the pulley wheel) are drawn
here in the anchor's palette and outline (2 px #272018, flat fill, one shade, one highlight).
Edits are palette-preserving recolours, crops, lossless 90 degree turns, pixel-art rotations with the outline rebuilt
(the 1.0 RotSprite-lite of docs/art/pipeline/common.py) and composites. Pivots: bottom-centre unless stated.
"""
import math
import os

import numpy as np
from PIL import Image

from xcommon import (AP, ASSETS, OUTLINE, asset, canvas, colours, gradient_map, hexs, pad_to, rgb, rotate_px, save,
                     strip, swap, trim, anim, outline, bbox)

SRC_SH = "shipped "
O4 = OUTLINE + (255,)


# ---------------------------------------------------------------------------------------------------- helpers
def ap_item(n):
    return Image.open(os.path.join(AP, "items", "%d.png" % n)).convert("RGBA")


def px_set(im, pts, col):
    a = np.array(im)
    for x, y in pts:
        if 0 <= x < a.shape[1] and 0 <= y < a.shape[0]:
            a[y, x] = col
    return Image.fromarray(a, "RGBA")


def rot_outlined(im, deg, pivot, dark=OUTLINE):
    """pixel-art rotation with the 2 px outline rebuilt (1.0 hero weapon method), any outline colour"""
    if deg % 90 == 0:
        return rotate_px(im, deg, pivot)
    a = np.array(im)
    d = (a[..., 0] == dark[0]) & (a[..., 1] == dark[1]) & (a[..., 2] == dark[2])
    core = a.copy()
    core[d] = 0
    rot, piv = rotate_px(Image.fromarray(core, "RGBA"), deg, pivot)
    return outline(rot, tuple(dark) + (255,), 2), (piv[0] + 2, piv[1] + 2)


def shape_mask(w, h, fn, ss=4):
    """rasterise an implicit shape fn(x, y) <= 0 (x, y in pixel centres) with 4 x 4 supersampling, >= 50 % coverage"""
    ys, xs = np.mgrid[0:h * ss, 0:w * ss]
    xs = (xs + 0.5) / ss
    ys = (ys + 0.5) / ss
    inside = fn(xs, ys) <= 0
    cov = inside.reshape(h, ss, w, ss).mean(axis=(1, 3))
    return cov >= 0.5


def grow(mask, n=1, diagonal=False):
    g = mask.copy()
    for _ in range(n):
        h = g.copy()
        h[1:, :] |= g[:-1, :]
        h[:-1, :] |= g[1:, :]
        h[:, 1:] |= g[:, :-1]
        h[:, :-1] |= g[:, 1:]
        if diagonal:
            h[1:, 1:] |= g[:-1, :-1]
            h[:-1, :-1] |= g[1:, 1:]
            h[1:, :-1] |= g[:-1, 1:]
            h[:-1, 1:] |= g[1:, :-1]
        g = h
    return g


def rim(mask, n):
    """the outer n-pixel ring of a mask (the image border counts as outside)"""
    p = np.pad(mask, n, constant_values=False)
    inner = ~grow(~p, n)
    return (p & ~inner)[n:-n, n:-n]


def paint(a, mask, col):
    a[mask] = tuple(col) + (255,) if len(col) == 3 else col


# ---------------------------------------------------------------------------------------------------- shared colours
STONE = None   # filled by _palettes()
OCHRE = rgb("#b64e13")          # the spear shaft / anchor rust: cave-paint ochre on stone
OCHRE_D = rgb("#793a15")
LIT = rgb("#ffe94f")            # lit marks (= the hero cloth yellow of the anchor)
LIT_W = rgb("#fffed9")


def hero_cell(sheet, f):
    cx, cy = (f % 8) * 176, (f // 8) * 112
    return sheet.crop((cx, cy, cx + 176, cy + 112))


# ---------------------------------------------------------------------------------------------------- plate
def build_plate():
    """objects/plate: stone slab cut from the carved block (rows 0-4 + 27-31, spiral left out), widened to 60 px;
    pips = how many heroes it needs (1 or 2). Pressed = the slab half as tall, its face lit."""
    blk = asset("sprites/objects/carved_block.png")              # 32 x 32, outline #271710
    a = np.array(blk)
    rows = list(range(0, 5)) + list(range(27, 32))              # 10 rows: top rim + bottom rim
    cols = list(range(0, 8)) + [8 + (i % 16) for i in range(44)] + list(range(24, 32))   # 60 columns
    slab_up = Image.fromarray(a[np.ix_(rows, cols)].copy(), "RGBA")
    prow = [0, 1, 2, 29, 30, 31]                                 # pressed: 6 rows (rim, top, face, shade, rim)
    slab_dn = Image.fromarray(a[np.ix_(prow, cols)].copy(), "RGBA")
    dark = tuple(int(v) for v in a[0, 16, :3])                  # #271710
    face = rgb("#9b8975")
    base_c = rgb("#846a52")
    W, H = 64, 14

    def base():
        im = canvas(W, H)
        b = np.array(im)
        b[H - 3:H, 0:W] = tuple(dark) + (255,)
        b[H - 2, 2:W - 2] = tuple(base_c) + (255,)
        return b

    PIP = [".dddd.",
           "dooood",
           "dooood",
           ".dddd."]

    def pip(b, x, y, lit):
        """a carved ochre pip, 6 x 4 (one per hero the plate needs)"""
        for dy, line in enumerate(PIP):
            for dx, ch in enumerate(line):
                if ch != ".":
                    b[y + dy, x + dx] = tuple(OCHRE_D if ch == "d" else OCHRE) + (255,)

    frames = []
    for count in (1, 2):
        xs = [29] if count == 1 else [20, 38]
        # up
        b = base()
        s = np.array(slab_up)
        top = H - 3 - 10 + 1                                    # slab bottom rim sits on the base
        m = s[..., 3] > 0
        b[top:top + 10, 2:62][m] = s[m]
        for x in xs:
            pip(b, x, top + 3, False)
        frames.append(Image.fromarray(b, "RGBA"))
        # pressed + lit, pressed unlit (for blinking timed plates)
        for lit in (True, False):
            b = base()
            s = np.array(slab_dn)
            if lit:
                fm = (s[..., 0] == face[0]) & (s[..., 1] == face[1]) & (s[..., 2] == face[2])
                s[fm, :3] = rgb("#f3aa39")
                hi = (s[..., 0] == 0xb3) & (s[..., 1] == 0xa8)
                s[hi, :3] = LIT
            top = H - 3 - 6 + 1
            m = s[..., 3] > 0
            b[top:top + 6, 2:62][m] = s[m]
            frames.append(Image.fromarray(b, "RGBA"))
    sheet = strip(frames)
    save(sheet, "sprites/objects/plate.png", kind="object", frame=[W, H], grid=[len(frames), 1], pivot=[W // 2, H],
         anims={"up_1": anim([0], 1, False), "pressed_1": anim([1], 1, False), "blink_1": anim([1, 2], 8),
                "up_2": anim([3], 1, False), "pressed_2": anim([4], 1, False), "blink_2": anim([4, 5], 8)},
         source=SRC_SH + "sprites/objects/carved_block.png (superpowers-prehistoric-platformer: tileset-1.png)",
         edits="slab = rows 0-4 + 27-31 of the carved block (spiral left out), middle columns repeated to 60 px; pressed "
               "slab = rows 0-2 + 29-31; base strip in the block's own dark / brown; 1 or 2 ochre pips (count); lit = "
               "face recoloured to the anchor's amber / yellow",
         note="`objects/plate` (D.5), 2 tiles wide. Frames 0-2 count=1: 0 up (surface 10 art px over the floor), 1 "
              "pressed + lit, 2 pressed unlit (timed plates blink 1 / 2 in the last second); frames 3-5 the same for "
              "count=2 (two pips). Pivot = floor line, bottom-centre", section="objects")
    return sheet


# ---------------------------------------------------------------------------------------------------- drum
def build_drum():
    """objects/drum: the shipped barrel with a stretched-hide top, rawhide lacing and a crest mask from the anchor's
    tileset icon strip; struck / rebound / lit frames."""
    bar = asset("sprites/objects/barrel.png")                     # 31 x 26
    crest_strip = Image.open(os.path.join(AP, "background-elements", "tileset-1.png")).convert("RGBA")
    crest = trim(crest_strip.crop((656, 536, 672, 560)))          # orange crest mask (16 px icon)
    hide, hide_s = rgb("#f4e49b"), rgb("#b3a178")
    lace = rgb("#fffed9")
    W, H = 40, 44

    def body(squash=0):
        b = bar.crop((0, 3, 31, 26))                              # drop the barrel lid rim
        if squash:
            b = b.resize((31 + 2 * squash, 23 - squash), Image.NEAREST)
        return b

    def head(w, dip):
        """hide ellipse w wide, 8 tall; dip = darker centre pressed in"""
        h = 9
        m = shape_mask(w, h, lambda x, y: ((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2 - 1)
        im = np.zeros((h, w, 4), np.uint8)
        paint(im, m, OUTLINE)
        inner = m & ~grow(~m, 1) & ~grow(~m, 2)
        paint(im, inner, hide)
        lower = inner & (np.mgrid[0:h, 0:w][0] >= h // 2 + 1)
        paint(im, lower, hide_s)
        if dip:
            ctr = shape_mask(w, h, lambda x, y: ((x - w / 2) / (w / 4)) ** 2 + ((y - h / 2) / 2.0) ** 2 - 1) & inner
            paint(im, ctr, hide_s)
        else:
            im[2, w // 2 - 4:w // 2 + 2] = tuple(LIT_W) + (255,)
        return Image.fromarray(im, "RGBA")

    def drum(squash=0, dip=False, lift=0, lit=False):
        f = canvas(W, H)
        b = body(squash)
        bx = (W - b.width) // 2
        by = H - b.height
        f.alpha_composite(b, (bx, by))
        # lacing: V cords from the hide rim down to the middle band
        a = np.array(f)
        for k in range(4):
            x0 = bx + 4 + k * 6 + squash
            for t in range(7):
                for xx in (x0 + t // 2, x0 + 6 - t // 2):
                    if 0 <= xx < W and a[by + 1 + t, xx, 3] > 0:
                        a[by + 1 + t, xx, :3] = lace
        f = Image.fromarray(a, "RGBA")
        c = crest
        if lit:      # by lightness: light -> white-yellow, mid -> yellow, dark (not the outline) -> amber
            def lum(k):
                return 0.299 * k[0] + 0.587 * k[1] + 0.114 * k[2]
            c = swap(c, {k: (LIT_W if lum(k) > 200 else LIT if lum(k) > 120 else rgb("#f3aa39"))
                         for k in colours(crest) if k != OUTLINE})
        f.alpha_composite(c, ((W - c.width) // 2, by + 8))
        hd = head(b.width, dip)
        f.alpha_composite(hd, (bx, by - 5 - lift))
        return f

    frames = [drum(), drum(squash=1, dip=True), drum(lift=1), drum(lit=True), drum(squash=1, dip=True, lit=True)]
    sheet = strip(frames)
    save(sheet, "sprites/objects/drum.png", kind="object", frame=[W, H], grid=[len(frames), 1], pivot=[W // 2, H],
         anims={"idle": anim([0], 1, False), "hit": anim([1, 2, 0], 16, False), "lit": anim([3], 1, False),
                "lit_hit": anim([4, 3], 16, False)},
         source=SRC_SH + "sprites/objects/barrel.png; superpowers-prehistoric-platformer: background-elements/tileset-1.png "
                         "(crest icon, 16 px strip at 656, 536)",
         edits="barrel lid rim cut, hide ellipse drawn in the barrel's own band colours, cream lacing over the staves, "
               "crest mask composited at 1x; struck = 1 px squash + pressed hide; lit = crest recoloured yellow",
         note="`objects/drum bond=<name>` (D.5): 0 idle, 1-2 struck (hit anim, then idle), 3 lit = struck and waiting "
              "for its bond partners inside the window, 4 struck while lit; 1 x 1.4 tiles", section="objects")
    return sheet


# ---------------------------------------------------------------------------------------------------- see-saw
SEESAW_PIVOT_H = 30        # art px from the floor to the plank underside at the fulcrum (15 logical)


def seesaw_plank(n_cells):
    """flat plank n cells long: the board rows of platform_wood (brackets left out) with bone knobs at both ends"""
    pw = asset("sprites/objects/platform_wood.png")                # 96 x 16, board rows 0-9
    a = np.array(pw)
    board = a[0:9, :, :].copy()
    board[8, 4:92] = a[9, 4:92] if a[9, 48, 3] else board[8, 4:92]
    L = n_cells * 32
    cols = list(range(0, 10)) + [10 + (i % 76) for i in range(L - 20)] + list(range(86, 96))
    plank = Image.fromarray(board[:, cols, :].copy(), "RGBA")
    # bottom outline
    p = np.array(plank)
    last = max(y for y in range(p.shape[0]) if p[y, L // 2, 3])
    p[last, 3:L - 3] = O4
    plank = Image.fromarray(p, "RGBA")
    bone = ap_item(15).rotate(90, Image.NEAREST, expand=True)   # 25 x 14, knob left
    knob = bone.crop((0, 0, 9, bone.height))                     # the knob end
    out = canvas(L, max(plank.height, knob.height) + 2)
    oy = (out.height - plank.height) // 2
    out.alpha_composite(plank, (0, oy))
    ky = (out.height - knob.height) // 2
    out.alpha_composite(knob, (0, ky))
    out.alpha_composite(knob.transpose(Image.FLIP_LEFT_RIGHT), (L - knob.width, ky))
    return out


def build_seesaw():
    lengths = (3, 4, 5, 6)
    CW, CH = 208, 88
    frames, tilts = [], {}
    for n in lengths:
        plank = seesaw_plank(n)
        half = n * 16
        full = math.degrees(math.asin(min(1.0, SEESAW_PIVOT_H / float(half))))
        tilts[n] = round(full, 1)
        for deg in (-full, -full / 2, 0.0, full / 2, full):   # negative = left end down (counter-clockwise)
            ctr = (plank.width / 2.0, plank.height / 2.0)
            if abs(deg) < 1e-6:
                rot, p = plank, (plank.width // 2, plank.height // 2)
            else:
                rot, p = rot_outlined(plank, deg, ctr)
            f = canvas(CW, CH)
            f.alpha_composite(rot, (CW // 2 - p[0], 36 - p[1]))
            frames.append(f)
    sheet = strip(frames, cols=5)
    plank_meta = {str(n): {"row": i, "rest_deg": tilts[n]} for i, n in enumerate(lengths)}
    save(sheet, "sprites/objects/seesaw_plank.png", kind="object", frame=[CW, CH], grid=[5, len(lengths)],
         pivot=[CW // 2, 40], lengths=plank_meta,
         source=SRC_SH + "sprites/objects/platform_wood.png (board rows); superpowers-prehistoric-platformer: items/15.png "
                         "(bone knob ends)",
         edits="board rows of the wood platform, middle columns repeated to len x 32 px, bottom outline closed, bone "
               "knobs at both ends; tilted copies rotated about the plank centre with the 2 px outline rebuilt",
         note="`objects/seesaw len=<cells>` plank (D.5): one row per len 3 / 4 / 5 / 6 cells, columns = left end down "
              "(rest), left half down, level, right half down, right end down (rest). Pivot (104, 40) = the plank's "
              "underside at its centre: put it on the fulcrum's top, %d art px over the floor (the turn centre is the "
              "plank centre, 4 px above). Rest angles (low end on the floor): %s"
              % (SEESAW_PIVOT_H, ", ".join("len %d = %.1f deg" % (n, tilts[n]) for n in lengths)), section="objects")
    # fulcrum: a dinosaur skull from the anchor's item set on a stone wedge
    skull = ap_item(58)                                          # 38 x 29 grey-brown dino skull (faces right)
    blk = asset("sprites/objects/carved_block.png")
    W, H = 48, SEESAW_PIVOT_H
    f = canvas(W, H)
    # wedge: carved-block stone cut to a trapezoid, 8 px wide at the top where the plank rests
    a = np.array(blk)
    tex = a[4:28, 4:28]
    wedge = np.zeros((H, W, 4), np.uint8)
    for y in range(H):
        half_w = 4 + int(round((W / 2 - 4) * y / float(H - 1)))
        x0, x1 = W // 2 - half_w, W // 2 + half_w
        wedge[y, x0:x1] = tex[y % tex.shape[0], np.arange(x0, x1) % tex.shape[1]]
    wm = wedge[..., 3] > 0
    wedge[rim(wm, 2)] = tuple(rgb("#271710")) + (255,)
    f.alpha_composite(Image.fromarray(wedge, "RGBA"))
    f.alpha_composite(skull, ((W - skull.width) // 2, H - skull.height))
    save(f, "sprites/objects/seesaw_pivot.png", kind="object", frame=[W, H], grid=[1, 1], pivot=[W // 2, H],
         source=SRC_SH + "sprites/objects/carved_block.png (stone wedge); superpowers-prehistoric-platformer: items/58.png "
                         "(dinosaur skull)",
         edits="stone texture of the carved block cut to a wedge with a 2 px #271710 rim; the skull composited at 1x "
               "in front",
         note="see-saw fulcrum: %d x %d, its top row is where the plank's underside rests (%d art px over the floor)"
              % (W, H, H), section="objects")
    return sheet, f


# ---------------------------------------------------------------------------------------------------- heave boulder
def build_boulder_heavy():
    """objects/boulder_heavy: the shipped boulder gradient-mapped to granite, the bottom flattened onto the floor, two
    ochre hand prints (push with two). Frames: idle, strain left / right (one hero alone: it rocks 1 px, never moves)."""
    b = asset("sprites/objects/boulder.png")                        # 64 x 64 round, outline #272018
    ramp = ["#3b3a40", "#5e5b63", "#7f7b80", "#a19b9a", "#c7c0b8"]
    g = gradient_map(b, ramp, keep=(OUTLINE,))
    a = np.array(g)
    H = 64
    cut = 58                                                        # flatten below this row
    a[cut + 2:, :, :] = 0
    row = a[cut]
    xs = np.nonzero(row[:, 3] > 0)[0]
    x0, x1 = int(xs.min()), int(xs.max())
    for y in (cut, cut + 1):
        a[y, x0:x1 + 1] = O4
    # rebuild the side outline just above the cut (the circle was narrowing there)
    for y in range(cut - 6, cut):
        r = np.nonzero(a[y, :, 3] > 0)[0]
        if len(r):
            a[y, r.min():r.min() + 2] = O4
            a[y, r.max() - 1:r.max() + 1] = O4
    # hand prints (cave paint): 7 x 9 px, palm + 4 fingers + thumb
    HAND = ["..o.o..",
            ".oo.o.o",
            ".oooooo",
            "ooooooo",
            ".oooooo",
            ".ooooo.",
            "..oooo.",
            "..ooo..",
            "......."]

    def hand(ax, ay, mirror):
        for yy, line in enumerate(HAND):
            for xx, ch in enumerate(line[::-1] if mirror else line):
                if ch == "o":
                    a[ay + yy, ax + xx] = tuple(OCHRE) + (255,)
    hand(19, 26, False)
    hand(37, 26, True)
    base = Image.fromarray(a, "RGBA")
    frames = [base]
    for dx in (-1, 1):
        f = canvas(64, H)
        f.alpha_composite(base, (dx, 0))
        frames.append(f)
    sheet = strip(frames)
    save(sheet, "sprites/objects/boulder_heavy.png", kind="object", frame=[64, H], grid=[3, 1], pivot=[32, H],
         anims={"idle": anim([0], 1, False), "strain": anim([1, 0, 2, 0], 16)},
         source=SRC_SH + "sprites/objects/boulder.png",
         edits="gradient map to granite greys (outline kept), bottom flattened at row 58 with the outline redrawn, two "
               "ochre hand prints painted on; strain frames shifted 1 px",
         note="`objects/boulder_heavy` (D.5), 2 x 2 tiles, flat bottom: slides 1 tile per 6 ticks while two heroes "
              "push one side (draw dust with fx/smoke.png); `strain` = one hero pushing alone", section="objects")
    return sheet


# ---------------------------------------------------------------------------------------------------- pulley
def build_pulley():
    """objects/pulley pieces on one 32 x 32 grid: wheel (4 turn frames), rope, rope knot, axle fork."""
    bar = asset("sprites/objects/barrel.png")
    wood, wood_d, wood_dd = rgb("#b97235"), rgb("#a14f27"), rgb("#89361b")
    band, band_d = rgb("#f4e49b"), rgb("#b3a178")
    hub = rgb("#453221")
    rope_l, rope_d = rgb("#f4e49b"), rgb("#b3a178")
    C = 32

    def wheel(phase):
        m = shape_mask(C, C, lambda x, y: (x - 16) ** 2 + (y - 16) ** 2 - 15.0 ** 2)
        a = np.zeros((C, C, 4), np.uint8)
        paint(a, m, OUTLINE)
        rim = m & ~grow(~m, 2)
        paint(a, rim, band)
        lower = rim & (np.mgrid[0:C, 0:C][0] > 18)
        paint(a, lower, band_d)
        groove = m & ~grow(~m, 4) & ~(m & ~grow(~m, 5))
        disc = m & ~grow(~m, 4)
        paint(a, disc, wood)
        paint(a, groove, OUTLINE)
        inner = m & ~grow(~m, 5)
        # spokes: 4, rotated by phase
        ys, xs = np.mgrid[0:C, 0:C]
        ang = np.degrees(np.arctan2(ys + 0.5 - 16, xs + 0.5 - 16))
        for k in range(4):
            th = phase + 90 * k
            d = (ang - th + 180) % 360 - 180
            r = np.hypot(xs + 0.5 - 16, ys + 0.5 - 16)
            spoke = inner & (np.abs(d) * np.pi / 180 * r <= 1.6)
            paint(a, spoke, wood_dd)
        shade = inner & ~(np.hypot(xs + 0.5 - 15, ys + 0.5 - 15) <= 9.5) & ((xs + ys) > 34)
        paint(a, shade & ~((a[..., :3] == wood_dd).all(axis=2)), wood_d)
        h = np.hypot(xs + 0.5 - 16, ys + 0.5 - 16) <= 3.2
        paint(a, h, OUTLINE)
        paint(a, np.hypot(xs + 0.5 - 16, ys + 0.5 - 16) <= 1.8, hub)
        a[15, 15] = tuple(band) + (255,)
        return Image.fromarray(a, "RGBA")

    def rope_tile():
        a = np.zeros((C, C, 4), np.uint8)
        for y in range(C):
            a[y, 14] = O4
            a[y, 17] = O4
            a[y, 15] = tuple(rope_l if (y // 2) % 2 == 0 else rope_d) + (255,)
            a[y, 16] = tuple(rope_d if (y // 2) % 2 == 0 else rope_l) + (255,)
        return Image.fromarray(a, "RGBA")

    def knot():
        a = np.array(rope_tile())
        a[18:, :] = 0
        K = ["..####..",
             ".#llld#.",
             "#llddll#",
             "#ldlldl#",
             ".#ddll#.",
             "..#dd#..",
             ".#l##l#.",
             "#l#..#l#",
             "#d#..#d#",
             ".#....#."]
        for yy, line in enumerate(K):
            for xx, ch in enumerate(line):
                c = {"#": OUTLINE, "l": rope_l, "d": rope_d}.get(ch)
                if c is not None:
                    a[16 + yy, 12 + xx] = tuple(c) + (255,)
        return Image.fromarray(a, "RGBA")

    def strap():
        """hanger: a wooden strap from a beam (cell top) down to the axle bolt at (16, 22), drawn in front of the wheel"""
        a = np.zeros((C, C, 4), np.uint8)
        a[0:21, 13:19] = O4
        a[0:20, 14:18] = tuple(wood_d) + (255,)
        a[0:20, 14] = tuple(wood) + (255,)
        a[19:26, 12:20] = O4
        a[20:25, 13:19] = tuple(hub) + (255,)
        a[21, 14:16] = tuple(band) + (255,)
        return Image.fromarray(a, "RGBA")

    frames = [wheel(p) for p in (0, 22.5, 45, 67.5)] + [rope_tile(), knot(), strap()]
    sheet = strip(frames)
    save(sheet, "sprites/objects/pulley.png", kind="object", frame=[C, C], grid=[len(frames), 1], pivot=[16, 16],
         anims={"turn": anim([0, 1, 2, 3], 12)},
         source="drawn by the pipeline in the colours of " + SRC_SH + "sprites/objects/barrel.png (wood, bands, hub)",
         edits="wheel = barrel-end disc: band rim, groove, 4 dark spokes turned 22.5 deg per frame, hub; rope = 2 px "
               "two-tone twist between 1 px outlines (tiles vertically every 32 px); knot = rope end tied to a "
               "platform; strap = wooden hanger from a beam to the axle bolt",
         note="`objects/pulley a= b=` (D.5) pieces, pivot = cell centre: 0-3 wheel `turn` (play forwards when side a "
              "sinks, backwards when b sinks), 4 rope (stack vertically, x 14-17 of the cell), 5 knot (rope enters at "
              "the top, ties onto the platform's top edge at the cell bottom), 6 hanger strap (its top row hangs from "
              "the beam; draw it over the wheel with the wheel's centre on its bolt at (16, 22), i.e. the wheel cell "
              "6 px lower). The rope runs over the wheel tops (cell rows 1-2) and down its left / right rims (cell "
              "x 1 / 30)", section="objects")
    return sheet


# ---------------------------------------------------------------------------------------------------- flower pot
def build_flower_pot():
    """objects/flower_pot: the village flower pot with its flower recoloured to the spring flower's oranges, so a
    player reads 'this becomes a spring'; tumble, smash and sprout frames that end on objects/spring frame 0."""
    pot = asset("tiles/village/props/flower_pot.png")              # 27 x 22: blue rose + leaves in a clay pot
    spring = asset("sprites/objects/spring.png").crop((0, 0, 64, 26))
    # blue petals -> spring oranges (exact swaps)
    pot = swap(pot, {rgb("#488396"): rgb("#ff7c31"), rgb("#3c5368"): rgb("#f8561f")})
    rest = [c for c in colours(pot) if c[2] > c[0] + 20 and c[2] > 90]
    if rest:
        pot = swap(pot, {c: rgb("#ffa544") for c in rest})
    W, H = 64, 32
    frames = []

    def put(im, x=None, y=None):
        f = canvas(W, H)
        f.alpha_composite(im, ((W - im.width) // 2 if x is None else x, H - im.height if y is None else y))
        return f
    frames.append(put(pot))
    sq = canvas(28, 28)
    sq.alpha_composite(pot, ((28 - pot.width) // 2, (28 - pot.height) // 2))
    for k in (1, 2, 3):
        r = sq.rotate(-90 * k, Image.NEAREST)
        frames.append(put(r, None, H - 28))
    # smash: the clay part splits into two shards thrown aside, soil and the flower left standing
    ca = np.array(pot)
    clay_rows = [y for y in range(ca.shape[0]) if any(tuple(ca[y, x, :3]) in (rgb("#9d4829"), rgb("#cc6b34"))
                                                      for x in range(ca.shape[1]) if ca[y, x, 3])]
    cy0 = min(clay_rows) if clay_rows else 12
    clay = pot.crop((0, cy0, pot.width, pot.height))
    top = pot.crop((0, 0, pot.width, cy0))
    left = clay.crop((0, 0, clay.width // 2, clay.height))
    right = clay.crop((clay.width // 2, 0, clay.width, clay.height))
    f = canvas(W, H)
    f.alpha_composite(rotate_px(left, -90)[0], (8, H - 14))
    f.alpha_composite(rotate_px(right, 90)[0], (W - 22, H - 14))
    f.alpha_composite(top, ((W - top.width) // 2, H - top.height - 1))
    frames.append(f)
    shards = f.copy()
    # sprout: the spring flower grows out of the soil (revealed bottom-up), the shards stay
    for k in (1, 2, 3):
        rows = int(round(spring.height * k / 3.0))
        g = canvas(W, H)
        sh = np.array(shards)
        if k < 3:
            g.alpha_composite(Image.fromarray(sh, "RGBA"))
        part = spring.crop((0, spring.height - rows, 64, spring.height))
        g.alpha_composite(part, (0, H - rows))
        frames.append(g)
    sheet = strip(frames)
    save(sheet, "sprites/objects/flower_pot.png", kind="object", frame=[W, H], grid=[len(frames), 1],
         pivot=[W // 2, H],
         anims={"idle": anim([0], 1, False), "tumble": anim([0, 1, 2, 3], 12), "smash": anim([4], 1, False),
                "sprout": anim([5, 6, 7], 12, False)},
         source=SRC_SH + "tiles/village/props/flower_pot.png; " + SRC_SH + "sprites/objects/spring.png (frame 0)",
         edits="blue rose recoloured to the spring flower's oranges (exact swaps); tumble = lossless 90 degree turns; "
               "smash = the clay cut into two shards turned aside; sprout = spring frame 0 revealed bottom-up",
         note="`objects/flower_pot` drop gift (D.5): 0 idle on the ledge, 1-3 + 0 tumble while it falls, 4 smash on "
              "landing, 5-7 sprout; frame 7 = objects/spring frame 0, swap to the spring there", section="objects")
    return sheet


# ---------------------------------------------------------------------------------------------------- x2 tablet
# Petroglyph caveman (2 px strokes, club raised in the outer hand, inner hand reaching across); the partner is the
# mirror image, so the two hold hands. Our own 14 x 19 pixel figure in cave-paint ochre.
PETROGLYPH = [
    "##............",
    "###...........",
    "###...####....",
    ".##..######...",
    ".##..######...",
    "..#..######...",
    "..##..####....",
    "...##..##.....",
    "....########..",
    "......####.###",
    "......####..##",
    "......####....",
    "......####....",
    ".....##..##...",
    ".....##..##...",
    "....##....##..",
    "....##....##..",
    "...##......##.",
    "...##......##.",
]


def petroglyph_pair():
    """mask of the two figures holding hands (28 x 19)"""
    h, w = len(PETROGLYPH), len(PETROGLYPH[0])
    m = np.zeros((h, 2 * w), bool)
    for y, line in enumerate(PETROGLYPH):
        for x, ch in enumerate(line):
            if ch == "#":
                m[y, x] = True
                m[y, 2 * w - 1 - x] = True
    return m


def build_x2_tablet():
    """objects/x2_tablet: the village stone tablet widened to 56 x 40, two petroglyph cavemen holding hands carved in
    ochre (engraved: a 1 px groove shadow below-right). 0 gate, 1 secret (a gem above the joined hands), 2 solved."""
    tab = asset("tiles/village/props/stone_tablet.png")            # 30 x 22, sandstone
    t = np.array(tab)
    W, H = 56, 40
    cx0, cx1, cy0, cy1 = 9, 21, 8, 14                             # 9-slice: corners, repeated middle band
    xs = list(range(0, cx0)) + [cx0 + (i % (cx1 - cx0)) for i in range(W - cx0 - (30 - cx1))] + list(range(cx1, 30))
    ys = list(range(0, cy0)) + [cy0 + (i % (cy1 - cy0)) for i in range(H - cy0 - (22 - cy1))] + list(range(cy1, 22))
    out = t[np.ix_(ys, xs)].copy()
    fill = rgb("#ebb678")
    groove = rgb("#b99f7c")
    solid = out[..., 3] > 0
    inner = solid & ~grow(~solid, 4)
    ry = np.mgrid[0:H, 0:W][0]
    carved = inner & ~((out[..., 0] == fill[0]) & (out[..., 1] == fill[1]) & (out[..., 2] == fill[2])) & (ry < H - 9)
    out[carved] = tuple(fill) + (255,)                              # the source's carved dashes left out
    fig = petroglyph_pair()
    fh, fw = fig.shape
    fx, fy = (W - fw) // 2, H - 8 - fh
    frames = []
    for kind in ("gate", "secret", "solved"):
        a = out.copy()
        col = LIT if kind == "solved" else OCHRE
        sh = np.zeros_like(fig)
        sh[1:, 1:] = fig[:-1, :-1]
        for yy in range(fh):
            for xx in range(fw):
                if sh[yy, xx] and not fig[yy, xx]:
                    a[fy + yy, fx + xx] = tuple(groove if kind != "solved" else rgb("#f3aa39")) + (255,)
                if fig[yy, xx]:
                    a[fy + yy, fx + xx] = tuple(col) + (255,)
        if kind == "secret":
            gem = ["..#..", ".#y#.", "#ywy#", ".#y#.", "..#.."]
            for yy, line in enumerate(gem):
                for xx, ch in enumerate(line):
                    c = {"#": OCHRE_D, "y": LIT, "w": LIT_W}.get(ch)
                    if c:
                        a[fy + 2 + yy, W // 2 - 3 + xx] = tuple(c) + (255,)
        frames.append(Image.fromarray(a, "RGBA"))
    s = strip(frames)
    save(s, "sprites/objects/x2_tablet.png", kind="object", frame=[W, H], grid=[3, 1], pivot=[W // 2, H],
         source=SRC_SH + "tiles/village/props/stone_tablet.png; petroglyph figures drawn by the pipeline",
         edits="tablet 9-sliced from 30 x 22 to 56 x 40, the source's carved dashes filled; two 14 x 19 petroglyph "
               "cavemen (2 px strokes, one mirrored, holding hands) painted in ochre with a 1 px groove shadow",
         note="`objects/x2_tablet gate=<name>` (D.5): diegetic co-op marker (`objects/sign` skin) beside every co-op "
              "gate (frame 0) and co-op secret (1, a gem above the joined hands); 2 = solved (marks lit). "
              "1.75 x 1.25 tiles", section="objects")
    return s


# ---------------------------------------------------------------------------------------------------- revive egg
def build_egg(palette_key):
    """sprites/player/hero_egg.png in the LUT KEY colours (cloth / shadow / ink / outline), so the hero palette shader
    paints it in the slot colour with the pattern step off. Drawn as an oval in the anchor style; the hatch frames show
    the hero's curl frame (24) rising out of the bottom half-shell."""
    cloth, shadow, ink = rgb(palette_key["cloth"]), rgb(palette_key["cloth_shadow"]), rgb(palette_key["ink"])
    hi = rgb("#ffffff")
    CW, CH = 64, 88
    FOOT = CH - 16
    EW, EH = 40, 48
    SPOTS = [(-8, -10, 4.0), (8, -2, 5.0), (-7, 8, 3.5), (8, 13, 3.0), (2, -16, 2.6), (-12, 0, 2.2)]

    def local(cx, cy, deg):
        a = math.radians(deg)
        ys, xs = np.mgrid[0:CH, 0:CW]
        dx, dy = xs + 0.5 - cx, ys + 0.5 - cy
        return dx * math.cos(a) + dy * math.sin(a), -dx * math.sin(a) + dy * math.cos(a)

    def egg_mask(cx, cy, deg, ox=0.0, oy=0.0):
        a = math.radians(deg)

        def fn(x, y):
            dx, dy = x - cx, y - cy
            u = dx * math.cos(a) + dy * math.sin(a) - ox
            v = -dx * math.sin(a) + dy * math.cos(a) - oy
            k = 1.0 + 0.16 * np.clip(-v / (EH / 2.0), -1, 1)          # narrower at the top
            return (u * k / (EW / 2.0)) ** 2 + (v / (EH / 2.0)) ** 2 - 1
        return shape_mask(CW, CH, fn)

    def zig_of(u):
        return np.abs(((u + 40) % 8) - 4) - 2

    def egg(deg=0.0, crack=0, half=None, dy=0):
        cx, cy = CW / 2.0, FOOT - EH / 2.0 + dy
        m = egg_mask(cx, cy, deg)
        a = np.zeros((CH, CW, 4), np.uint8)
        u, v = local(cx, cy, deg)
        paint(a, m, OUTLINE)
        inner = m & ~rim(m, 2)
        paint(a, inner, cloth)
        lit = egg_mask(cx, cy, deg, -3.0, -4.0)                       # the oval moved up-left: what stays lit
        sh_m = inner & ~lit
        paint(a, sh_m, shadow)
        for sx, sy, r in SPOTS:
            paint(a, inner & (np.hypot(u - sx, v - sy) <= r), ink)
        paint(a, inner & (np.hypot(u + 8, v + 14) <= 2.4), hi)
        paint(a, inner & (np.hypot(u + 12, v + 6) <= 1.1), hi)
        zig = zig_of(u)
        if crack:
            reach = -3 if crack == 1 else 99
            paint(a, inner & (np.abs(v - zig) <= 0.75) & (u < reach), OUTLINE)
        if half is not None:
            keep = (v > zig + 0.75) if half == "bottom" else (v < zig - 0.75)
            band = m & (np.abs(v - zig) <= 0.75)
            a[~(keep | band)] = 0
            a[band] = O4
        return Image.fromarray(a, "RGBA")

    hero = Image.open(os.path.join(ASSETS, "sprites", "player", "hero.png")).convert("RGBA")
    curl = trim(hero_cell(hero, 24))                                # curl / roll frame, in the hero's KEY colours
    frames = [egg(), egg(-10), egg(10), egg(dy=-2), egg(crack=1), egg(crack=2)]
    for rise, lift, tip, drift in ((8, 10, -20, -4), (16, 22, -40, -10)):
        f = canvas(CW, CH)
        f.alpha_composite(curl, ((CW - curl.width) // 2, FOOT - EH // 2 - curl.height // 2 - rise + 6))
        f.alpha_composite(egg(half="bottom"))
        top = egg(half="top")
        tb = bbox(top)
        tcut = top.crop(tb)
        r, p = rot_outlined(tcut, tip, (tcut.width / 2.0, tcut.height / 2.0))
        x = int(round(tb[0] + tcut.width / 2.0 - p[0] + drift))
        y = int(round(tb[1] + tcut.height / 2.0 - p[1] - lift))
        f.alpha_composite(r, (x, y))
        frames.append(f)
    s = strip(frames)
    save(s, "sprites/player/hero_egg.png", kind="actor", frame=[CW, CH], grid=[len(frames), 1], pivot=[CW // 2, FOOT],
         anims={"float": anim([0, 3], 4), "nudge": anim([1, 0, 2, 0], 12, False), "crack": anim([4, 5], 12, False),
                "hatch": anim([6, 7], 12, False)},
         lut="hero palette LUT, pattern step OFF",
         source="drawn by the pipeline in the hero LUT key colours; " + SRC_SH + "sprites/player/hero.png frame 24 "
                "(curl, rising out of the shell)",
         edits="oval narrowed at the top, 2 px #272018 outline, shade = the oval minus its copy moved up-left, six "
               "spots, two highlights; nudge = the oval drawn tilted 10 deg; crack = zigzag line; hatch = shell split "
               "along the zigzag, the top half turned away with the outline rebuilt, the curled hero rising",
         note="Egg Hatch revive egg (D.3), 20 x 24 logical, pivot = the egg's foot (cell_h - 16). Painted with the KEY "
              "colours of palettes/hero_lut_key.png (cloth, cloth shadow, ink, outline; the curled hero in its own key "
              "colours), so the hero palette shader turns it into the slot colour: run it with the loincloth-pattern "
              "step OFF. 0 float (alternate with 3, 2 px higher), 1 / 2 nudged left / right, 4-5 crack, 6-7 hatch "
              "(then show the hero)", section="player")
    return s


def build(palette_key):
    return {
        "plate": build_plate(),
        "drum": build_drum(),
        "seesaw": build_seesaw(),
        "boulder_heavy": build_boulder_heavy(),
        "pulley": build_pulley(),
        "flower_pot": build_flower_pot(),
        "x2_tablet": build_x2_tablet(),
        "egg": build_egg(palette_key),
    }


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    import build_hero_palettes as hp
    load_registry()
    build(hp.KEY)
    save_registry()

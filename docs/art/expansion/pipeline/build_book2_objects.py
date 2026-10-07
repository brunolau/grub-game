"""Book II objects of DESIGN C.2-C.5 for objects-B (PLAN P1.10 / P1.13): vine + rolled vine, bark board, geyser, raft.

Sources: shipped 1.0 art under assets/ (all from the anchor pack, Superpowers Prehistoric Platformer, Pixel-boy, CC0):
tiles/jungle/props/vine_a.png + vine_b.png, sprites/objects/platform_wood.png, tiles/feast/terrain_biscuit.png,
sprites/fx/splash_water.png, sprites/fx/particles_smoke.png, tiles/common/water.png / lava.png and the 2.0 tar strip;
the anchor pack's log item (items/4.png) for its colours. Shapes no pack draws (the vine coil, the geyser vent rim and
jet, the raft's log ends) are drawn here in the anchor's palette and outline. Edits: crops, exact colour swaps,
nearest-neighbour only, lossless 90 degree turns.

Skins follow the level's biome where the object has no `skin` parameter: one sheet row per biome, in the order of
LevelData.BIOMES (jungle, cave, ice, volcano, feast, village, canyon, swamp, coast, ruins, sky), so the row is
`LevelData.BIOMES.find(biome)`.
"""
import math
import os

import numpy as np
from PIL import Image

from xcommon import OUTLINE, asset, ap, canvas, colours, rgb, save, strip, swap, trim, anim, hexs
from build_coop_objects import grow, rim, paint, shape_mask

O4 = OUTLINE + (255,)
BIOMES = ["jungle", "cave", "ice", "volcano", "feast", "village", "canyon", "swamp", "coast", "ruins", "sky"]
SRC = "shipped "


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


# ---------------------------------------------------------------------------------------------------- vine
# the five greens of vine_a / vine_b, dark -> light by luminance, and their outline
VINE_GREENS = [rgb(h) for h in ("#65651f", "#709d2e", "#63aa16", "#7cbe24", "#8cd726")]
VINE_OUTLINE = rgb("#452b14")
# per biome: outline + 5 stops (dark -> light). jungle / village keep the shipped colours.
VINE_SKINS = {
    "jungle":  ("#452b14", ["#65651f", "#709d2e", "#63aa16", "#7cbe24", "#8cd726"]),
    "cave":    ("#2a1c33", ["#4b3a6b", "#5d4c86", "#6f62a6", "#8579c0", "#a39ce0"]),
    "ice":     ("#2c3d5f", ["#4f7f8f", "#5f9fae", "#7cbfcc", "#a8dde6", "#e0f6fa"]),
    "volcano": ("#2a140c", ["#5a2a1c", "#7a3a22", "#9b4a26", "#c0642c", "#e08a3a"]),
    "feast":   ("#4a0f18", ["#8a1c2a", "#b02a38", "#d43c48", "#ee6670", "#ff9aa2"]),
    "village": ("#452b14", ["#65651f", "#709d2e", "#63aa16", "#7cbe24", "#8cd726"]),
    "canyon":  ("#3d2a14", ["#6b5a24", "#857330", "#a08d3c", "#bba652", "#d6c470"]),
    "swamp":   ("#1c2a18", ["#2f4d2c", "#3c6236", "#4a7a40", "#5e9450", "#7cae66"]),
    "coast":   ("#14302a", ["#24584a", "#2e6e5a", "#3a886c", "#4ea380", "#6cc09a"]),
    "ruins":   ("#173a2c", ["#2f6a52", "#3a8264", "#479c78", "#5cb88e", "#7fd4aa"]),
    "sky":     ("#2e3d18", ["#5a8a2c", "#6ea436", "#86be42", "#a2d858", "#c4ee80"]),
}
VINE_LOOK = {"jungle": "shipped green", "cave": "violet cave roots", "ice": "frosted", "volcano": "charred thorn",
             "feast": "red liquorice", "village": "shipped green", "canyon": "dry desert vine",
             "swamp": "murky fen creeper", "coast": "sea-green creeper", "ruins": "jade temple ivy",
             "sky": "pale beanstalk green"}


def _shifted(im, rows, dx, h=32):
    """rows (y0, y1) of a vine prop moved dx px right into a 32 x h cell"""
    out = canvas(32, h)
    out.alpha_composite(im.crop((0, rows[0], im.width, rows[1])), (dx, 0))
    return out


def vine_pieces():
    """jungle pieces: top, segment a (plain), segment b (leaf), tip. vine_b = vine_a moved 7 px right plus three
    leaves, so vine_a pieces go in at x + 7 and vine_b pieces at x + 0: the stem's mean x is the cell centre."""
    va = asset("tiles/jungle/props/vine_a.png")       # 18 x 88
    vb = asset("tiles/jungle/props/vine_b.png")       # 32 x 96
    top = _shifted(vb, (0, 32), 0)                     # fringe that hugs the ledge + the left leaf
    seg_a = _shifted(va, (32, 64), 7)                  # rows 32-63 repeat (row 64 differs from row 32 by 2 px)
    seg_b = _shifted(vb, (32, 64), 0)                  # the same stem with the middle leaf
    tip = _shifted(va, (64, 88), 7)                    # the tapered end ...
    leaf = vb.crop((22, 81, 32, 92))                   # ... with vine_b's lower right leaf, hung on the stem's right
    ly = 6                                             # edge at the row where vine_b carries it (its stem side)
    t = np.array(tip)
    edge = max(int(np.nonzero(t[ly + 4, :, 3])[0].max()), int(np.nonzero(t[ly + 6, :, 3])[0].max()))
    tip.alpha_composite(leaf, (edge - 1, ly))
    return top, seg_a, seg_b, tip


def vine_coil(stage):
    """the rolled vine: loops of vine hanging from the anchor point like a coiled rope on a hook, drawn in the
    shipped vine colours (1 px outline per loop, 3 px stem). stage 0 = full coil (three loops), 1 = loosening (two
    loops, the end drops 8 px), 2 = nearly open (one loop, the end drops 16 px), 3 = the full coil nudged 1 px"""
    dark, mid, mid2, light = rgb("#65651f"), rgb("#709d2e"), rgb("#63aa16"), rgb("#8cd726")
    out = rgb("#452b14")
    C = 32
    a = np.zeros((C, C, 4), np.uint8)
    ys, xs = np.mgrid[0:C, 0:C]
    nud = 1 if stage == 3 else 0
    loops = {0: [(-3, 11, 11.5), (0, 10, 12.5), (3, 9, 13)], 1: [(-2, 10, 12), (2, 9, 12.5)], 2: [(0, 8, 11)],
             3: [(-3, 11, 11.5), (0, 10, 12.5), (3, 9, 13)]}[stage]
    drop = {0: 0, 1: 8, 2: 16, 3: 0}[stage]
    top = 4
    # the loose end first (behind the loops): it hangs from the front loop's bottom
    if drop:
        y0 = int(top + 2 * loops[-1][2] - 6)
        for y in range(y0, min(C, y0 + drop + 6)):
            x0 = 16 + nud + loops[-1][0] - 2
            a[y, x0 - 1:x0 + 4] = tuple(out) + (255,)
            a[y, x0:x0 + 3] = tuple(mid2) + (255,)
            a[y, x0] = tuple(light) + (255,)
    for dx, rx, ry in loops:                                        # back to front
        cx, cy = 16 + nud + dx, top + ry
        e = ((xs + 0.5 - cx) / rx) ** 2 + ((ys + 0.5 - cy) / ry) ** 2
        e_in = ((xs + 0.5 - cx) / (rx - 4)) ** 2 + ((ys + 0.5 - cy) / (ry - 4)) ** 2
        ring = (e <= 1.0) & (e_in > 1.0)
        core = (((xs + 0.5 - cx) / (rx - 1)) ** 2 + ((ys + 0.5 - cy) / (ry - 1)) ** 2 <= 1.0) & \
            ((((xs + 0.5 - cx) / (rx - 3)) ** 2 + ((ys + 0.5 - cy) / (ry - 3)) ** 2) > 1.0)
        paint(a, ring, out)
        paint(a, core, mid2)
        paint(a, core & (xs + 0.5 < cx) & (ys + 0.5 < cy + 2), light)          # lit left side
        paint(a, core & (xs + 0.5 > cx + 2) & (ys + 0.5 > cy), mid)            # shade lower right
        paint(a, core & (ys + 0.5 > cy + ry - 3), dark)
    # the hook / tie: a knot of stem at the anchor point
    paint(a, (np.abs(xs + 0.5 - (16.5 + nud)) <= 3) & (ys <= top + 2), out)
    paint(a, (np.abs(xs + 0.5 - (16.5 + nud)) <= 1.5) & (ys <= top + 1), mid2)
    a[0:2, 15 + nud] = tuple(light) + (255,)
    # a leaf on the front loop
    leaf = [".oo..",
            "oLLo.",
            "oLmLo",
            ".oLmo",
            "..oo."]
    lx, ly = int(16 + nud + loops[-1][0] + loops[-1][1] - 4), int(top + loops[-1][2] - 2)
    for dy, line in enumerate(leaf):
        for dx, ch in enumerate(line):
            c = {"o": out, "L": light, "m": mid}.get(ch)
            if c is not None and 0 <= lx + dx < C and 0 <= ly + dy < C:
                a[ly + dy, lx + dx] = tuple(c) + (255,)
    return Image.fromarray(a, "RGBA")


def vine_skin(im, biome):
    o, ramp = VINE_SKINS[biome]
    if biome in ("jungle", "village"):
        return im
    m = {VINE_OUTLINE: rgb(o)}
    for src, dst in zip(VINE_GREENS, ramp):
        m[src] = rgb(dst)
    known = set(m)
    extra = colours(im) - known
    for c in extra:                                    # any in-between green: nearest stop by luminance
        best = min(range(5), key=lambda i: abs(lum(VINE_GREENS[i]) - lum(c)))
        m[c] = rgb(ramp[best])
    return swap(im, m)


def build_vine():
    top, seg_a, seg_b, tip = vine_pieces()
    coils = [vine_coil(s) for s in (0, 1, 2, 3)]
    base = [top, seg_a, seg_b, tip] + coils
    frames = []
    for b in BIOMES:
        frames += [vine_skin(f, b) for f in base]
    sheet = strip(frames, cols=8)
    save(sheet, "sprites/objects/vine.png", kind="object", frame=[32, 32], grid=[8, len(BIOMES)], pivot=[16, 0],
         rows=BIOMES, anims={"coil_idle": anim([4, 7], 2), "unroll": anim([4, 5, 6], 12, False)},
         source=SRC + "tiles/jungle/props/vine_a.png + vine_b.png (superpowers-prehistoric-platformer: "
                       "background-elements/tileset-1.png); coil drawn by the pipeline in the vines' own colours",
         edits="top = vine_b rows 0-31; segment a = vine_a rows 32-63 moved 7 px right (vine_b is vine_a moved 7 px "
               "plus leaves), segment b = vine_b rows 32-63; tip = vine_a rows 64-87 + vine_b's lower leaf; the stem's "
               "mean x is the cell centre; coil = loops of the stem hanging from the anchor point like a rope on a hook (1 px outline, lit "
               "left) with a leaf; per-biome rows are exact swaps of the five greens and the outline",
         note="`objects/vine length=<cells> rolled=<bool>` (C.3, PHYSICS C.4): row = biome (LevelData.BIOMES order: "
              + ", ".join("%d %s (%s)" % (i, b, VINE_LOOK[b]) for i, b in enumerate(BIOMES)) +
              "). Columns: 0 top (the anchor cell: its top edge hangs from the ledge / ceiling), 1 segment a, 2 "
              "segment b (leaf; alternate a / b down the vine), 3 tip (the last cell); length 1 = column 0 only. "
              "Every piece is 32 x 32, pivot = top-centre (16, 0) = (vine_x, cell top): stack them every 32 art px. "
              "Rolled: 4 coil (hangs from the anchor point, 16 x 16 logical hittable box), 7 = 4 nudged 1 px (alternate "
              "4 / 7 as an idle wiggle), unroll = 4, 5, 6 over the 8 ticks while the code reveals the vine below "
              "from the top; then draw the normal pieces", section="objects")
    return sheet


# ---------------------------------------------------------------------------------------------------- bark board
WOOD = {"out": rgb("#332213"), "dark": rgb("#582d12"), "shadow": rgb("#63513a"), "wood_d": rgb("#7f3910"),
        "wood": rgb("#9d4829"), "rope": rgb("#f1b043")}
# per skin: wood_d, wood, dark (grain), rope; outline stays the platform's
BARK_SKINS = {
    "bark":      ("#7f3910", "#9d4829", "#582d12", "#f1b043"),
    "bleached":  ("#a08060", "#c4a47c", "#7a5c40", "#e8d8a8"),
    "driftwood": ("#76726a", "#9a968a", "#57534c", "#d8cfa8"),
    "fen":       ("#3e3320", "#55472c", "#2a2216", "#a8b060"),
    "frost":     ("#6a5a66", "#8c7c88", "#4c3e4a", "#e8f4fa"),
    "charred":   ("#4a261a", "#683626", "#2e1810", "#f08a3a"),
    "wafer":     ("#c47a34", "#e2a050", "#94561e", "#fff0c8"),
    "jade":      ("#5e5a2e", "#7a7a3a", "#3e3c1c", "#7fd4aa"),
}
BARK_BIOME = {"jungle": "bark", "cave": "bark", "ice": "frost", "volcano": "charred", "feast": "wafer",
              "village": "bark", "canyon": "bleached", "swamp": "fen", "coast": "driftwood", "ruins": "jade",
              "sky": "driftwood"}
OCHRE, OCHRE_D, LIT, LIT_W = rgb("#b64e13"), rgb("#793a15"), rgb("#ffe94f"), rgb("#fffed9")


def bark_board_base():
    """three vertical planks (the wood platform's board rows turned 90 degrees), two rope lashings, an ochre target"""
    pw = asset("sprites/objects/platform_wood.png")
    board = pw.crop((14, 0, 42, 10))                       # 28 x 10, no bindings
    plank = board.rotate(90, Image.NEAREST, expand=True)   # 10 x 28 (lossless)
    f = canvas(32, 32)
    x0, y0 = 3, 2
    for k in range(3):
        p = plank if k != 1 else plank.transpose(Image.FLIP_TOP_BOTTOM)   # grain varies plank to plank
        f.alpha_composite(p, (x0 + k * 8, y0))
    a = np.array(f)
    # lashings: 3-row rope bands with a 1 px outline above / below, across the three planks
    for yb in (6, 24):
        a[yb - 1, x0:x0 + 26] = tuple(WOOD["out"]) + (255,)
        a[yb + 2, x0:x0 + 26] = tuple(WOOD["out"]) + (255,)
        a[yb:yb + 2, x0 + 1:x0 + 25] = tuple(WOOD["rope"]) + (255,)
        for x in range(x0 + 3, x0 + 25, 4):
            a[yb + 1, x] = tuple(WOOD["wood_d"]) + (255,)
    return a


TARGET = ["..oooo..",
          ".oOOOOo.",
          "oOO..OOo",
          "oO.dd.Oo",
          "oO.dd.Oo",
          "oOO..OOo",
          ".oOOOOo.",
          "..oooo.."]


def bark_frame(a, kind):
    b = a.copy()
    ring = {"idle": OCHRE, "hit": LIT, "busy": OCHRE_D}[kind]
    ring_d = {"idle": OCHRE_D, "hit": rgb("#f3aa39"), "busy": rgb("#582d12")}[kind]
    dot = {"idle": OCHRE_D, "hit": LIT_W, "busy": rgb("#582d12")}[kind]
    tx, ty = 12, 11
    for dy, line in enumerate(TARGET):
        for dx, ch in enumerate(line):
            c = {"o": ring_d, "O": ring, "d": dot}.get(ch)
            if c is not None and b[ty + dy, tx + dx, 3]:
                b[ty + dy, tx + dx, :3] = c
    return Image.fromarray(b, "RGBA")


def bark_skin(im, name):
    wd, w, dk, rope = (rgb(h) for h in BARK_SKINS[name])
    return swap(im, {WOOD["wood_d"]: wd, WOOD["wood"]: w, WOOD["dark"]: dk, WOOD["rope"]: rope})


def build_bark_board():
    base = bark_board_base()
    frames = []
    for b in BIOMES:
        for kind in ("idle", "hit", "busy"):
            frames.append(bark_skin(bark_frame(base, kind), BARK_BIOME[b]))
    sheet = strip(frames, cols=3)
    save(sheet, "sprites/objects/bark_board.png", kind="object", frame=[32, 32], grid=[3, len(BIOMES)],
         pivot=[16, 32], rows=BIOMES, anims={"idle": anim([0], 1, False), "hit": anim([1, 0], 12, False),
                                             "busy": anim([2], 1, False)},
         source=SRC + "sprites/objects/platform_wood.png (board rows, superpowers-prehistoric-platformer: "
                       "background-elements/tileset-1.png)",
         edits="board rows 0-9 / columns 14-41 of the wood platform turned 90 degrees (lossless) into three planks "
               "(the middle one flipped), two rope lashings in the platform's binding colour, an 8 x 8 cave-paint "
               "target ring in ochre; per-biome rows = exact swaps of the wood and rope colours (" +
               ", ".join("%s: %s" % (k, "/".join(v)) for k, v in BARK_SKINS.items()) + ")",
         note="`objects/bark_board face=l|r` (C.2, PHYSICS C.3): drawn over its wall cell (fills x 3-28 / y 2-29 of "
              "the 32 x 32 cell; the wall tile's edge stays visible). Faces right (air on the right): flip_h for "
              "`face=l`. Row = biome (LevelData.BIOMES order; " +
              ", ".join("%s %s" % (b, BARK_BIOME[b]) for b in BIOMES) + "). Columns: 0 idle, 1 hit (target lit: the "
              "spear sticks, play `hit` = 1 then 0), 2 busy (a spear step sticks in it: target dark; a spear that "
              "hits now glances). The step itself is sprites/fx/projectile_spear.png frame 4", section="objects")
    return sheet


# ---------------------------------------------------------------------------------------------------- geyser
# skin: rim (outline, rock dark, rock, rock light), jet (body, mid, light, foam), steam = puffs instead of a jet
GEYSER_SKINS = {
    "mud":      dict(rim=("#272018", "#4a3020", "#6b4a2c", "#8c6a44"),
                     jet=("#9a6a3a", "#b6844a", "#d4a868", "#f2dcb0"), look="mud spout (canyon wallows, the fen)"),
    "blowhole": dict(rim=("#272018", "#3c4048", "#5a6068", "#7c848c"),
                     jet=("#328da6", "#4fa0b4", "#96c0c6", "#fff2e5"), look="sea blowhole (Coral Coast)"),
    "steam":    dict(rim=("#272018", "#5a5660", "#7c7884", "#a29ea8"),
                     jet=("#b4bac6", "#d2d8e2", "#eef2f8", "#ffffff"), look="steam vent (Sky Spire, Cloud Top)",
                     puffs=True),
    "soda":     dict(rim=("#4a0f18", "#c45675", "#f8adba", "#fff0ec"),
                     jet=("#d8507e", "#ec74a0", "#ffacc8", "#ffffff"), look="pink soda (Feast Land D)"),
    "tar":      dict(rim=("#140e1a", "#1e1628", "#2e2240", "#4a3a62"),
                     jet=("#1e1628", "#2e2240", "#4a3a62", "#a892c4"), look="deadly tar vent (`deadly`)"),
    "lava":     dict(rim=("#1a1016", "#302630", "#504156", "#7b6b80"),
                     jet=("#ce421a", "#f07824", "#ffb23c", "#ffec82"), look="deadly lava vent (`deadly`)"),
}
GEYSER_ORDER = ["mud", "blowhole", "steam", "soda", "tar", "lava"]
GW, GH = 64, 256
G_FLOOR = GH                 # the vent's floor line = the cell bottom
G_MOUTH = GH - 10            # the mouth's centre row
JET_LAUNCH = 210             # art px of a launching spout over the mouth: the -224 launch apex, 105 logical px
JET_DEADLY = 128             # art px of a deadly spout: the 24 x 64 logical deadly box
JET_HALF = (22.0, 16.0)      # half-width at the mouth / at the head: 44-48 art px = the 24 logical px vent box


def jet_height(name):
    return JET_DEADLY if name in ("tar", "lava") else JET_LAUNCH


def vent(sk, open_=False):
    o, d, m, l = (rgb(c) for c in sk["rim"])
    a = np.zeros((GH, GW, 4), np.uint8)
    rimm = shape_mask(GW, GH, lambda x, y: ((x - 32) / 24.0) ** 2 + ((y - (G_FLOOR - 1)) / 13.0) ** 2 - 1)
    rimm[G_FLOOR:, :] = False
    mouth = shape_mask(GW, GH, lambda x, y: ((x - 32) / 10.5) ** 2 + ((y - G_MOUTH) / 3.2) ** 2 - 1)
    paint(a, rimm, o)
    body = rimm & ~rim(rimm, 2)
    paint(a, body, m)
    ys, xs = np.mgrid[0:GH, 0:GW]
    paint(a, body & (ys >= G_FLOOR - 4), d)                       # foot in shade
    paint(a, body & (ys <= G_MOUTH - 1) & (xs < 32), l)            # lit upper left lip
    for px, py in ((14, G_FLOOR - 6), (47, G_FLOOR - 5), (22, G_FLOOR - 3)):   # a few pebbles on the rim
        if a[py, px, 3]:
            a[py, px:px + 2] = tuple(l) + (255,)
            a[py + 1, px:px + 2] = tuple(d) + (255,)
    paint(a, mouth, o)
    inner = mouth & ~rim(mouth, 1)
    paint(a, inner, rgb(sk["jet"][0]) if open_ else d)
    return a


def _jet_mask(top, phase):
    """a vertical jet from the mouth up to row `top`: wobbling edges, wider at the base, rounded head"""
    base_w, width = JET_HALF

    def fn(x, y):
        t = np.clip((G_MOUTH - y) / max(1.0, (G_MOUTH - top)), 0, 1)
        half = base_w + (width - base_w) * t + 2.2 * np.sin(y / 4.5 + phase) + 1.2 * np.sin(y / 2.3 + 2 * phase)
        inside = np.abs(x - 32 - 1.5 * np.sin(y / 11.0 + phase * 0.7)) - half
        head = ((x - 32) / (width + 2)) ** 2 + ((y - top - 6) / 8.0) ** 2 - 1
        return np.where(y < top + 6, head, np.where(y > G_MOUTH + 1, 1.0, inside))
    return shape_mask(GW, GH, fn)


def jet(a, sk, top, phase, broken=False):
    body, mid, light, foam = (rgb(c) for c in sk["jet"])
    m = _jet_mask(top, phase)
    ys, xs = np.mgrid[0:GH, 0:GW]
    if broken:                                                   # collapsing: rounded blobs with gaps
        m &= ((ys + int(phase * 3)) // 12) % 2 == 0
        m &= ~rim(m, 1) | (((ys + int(phase * 3)) % 12 > 1) & ((ys + int(phase * 3)) % 12 < 10))
    paint(a, m, body)
    edge = m & rim(m, 3)
    paint(a, edge & (xs < 32), mid)
    paint(a, edge & (xs >= 32), rgb(sk["rim"][1]) if sk.get("dark_edge") else body)
    for cx, f, per in ((26, 7.0, 1), (36, 6.0, 3), (31, 9.0, 4)):      # light streaks running up the column
        streak = m & (np.abs(xs - cx - np.round(1.5 * np.sin(ys / f + phase))) <= (1 if per == 1 else 0))
        if per > 1:
            streak &= (ys // 4) % per != 0
        paint(a, streak, light)
    head = m & (ys <= top + 8)
    paint(a, head, foam)
    paint(a, head & (ys > top + 4) & ((xs + ys) % 3 == 0), light)
    # foam flecks along both edges and droplets thrown off the sides: it reads as liquid, not as a pillar
    fleck = m & rim(m, 1) & (((ys + int(phase * 5)) % 7) == 0)
    paint(a, fleck, foam)
    if not broken:
        rng = np.random.RandomState(int(phase * 10) + 7)
        for _ in range(9):
            y = int(rng.randint(top + 12, G_MOUTH - 10))
            row = np.nonzero(m[y])[0]
            if not len(row):
                continue
            side = rng.randint(2)
            x = int(row.min() - 4 - rng.randint(4)) if side == 0 else int(row.max() + 2 + rng.randint(4))
            r = 1 + rng.randint(2)
            for yy in range(y - r, y + r + 1):
                for xx in range(x - r, x + r + 1):
                    if 0 <= xx < GW and (xx - x) ** 2 + (yy - y) ** 2 <= r * r + 0.5:
                        a[yy, xx] = tuple(light if (xx - x) + (yy - y) < 0 else mid) + (255,)


def splash_crown(a, sk, top, k):
    """the shipped water splash, recoloured to the jet, on the head of the jet"""
    sp = asset("sprites/fx/splash_water.png")
    fr = sp.crop((k * 45, 0, k * 45 + 45, 41))
    body, mid, light, foam = (rgb(c) for c in sk["jet"])
    cs = sorted(colours(fr), key=lum)
    m = {}
    for i, c in enumerate(cs):
        m[c] = [mid, light, foam][min(2, i * 3 // max(1, len(cs)))]
    fr = np.array(swap(fr, m))
    y0 = max(0, top - 30)
    sub = fr[:min(41, GH - y0)]
    msk = sub[..., 3] > 0
    a[y0:y0 + sub.shape[0], 9:9 + 45][msk] = sub[msk]


def puffs(a, sk, top, phase):
    """steam: a column of the shipped smoke particles recoloured to the steam greys, the big puff on top"""
    sm = asset("sprites/fx/particles_smoke.png")                    # 4 x (28 x 28)
    big = trim(asset("sprites/fx/smoke.png"))                       # 41 x 38 puff
    body, mid, light, foam = (rgb(c) for c in sk["jet"])

    def grey(b):
        cs = sorted(colours(b), key=lum)
        return swap(b, {c: [mid, light, foam][min(2, i * 3 // max(1, len(cs)))] for i, c in enumerate(cs)})
    balls = [grey(trim(sm.crop((k * 28, 0, k * 28 + 28, 28)))) for k in range(4)]
    balls = [b if b.width >= 14 else b.resize((b.width * 2, b.height * 2), Image.NEAREST) for b in balls]
    big = grey(big)
    im = Image.fromarray(a, "RGBA")
    y = G_MOUTH - 6
    i = 0
    while y > top + 20:
        b = balls[3] if i % 2 == 0 else balls[(i + int(phase)) % 3]
        for dx in (-9, 9):                                          # two puffs abreast: a 40 px wide column
            x = 32 + dx - b.width // 2 + int(round(3 * math.sin(i * 1.7 + phase + dx)))
            im.alpha_composite(b, (x, max(0, y - b.height // 2)))
        y -= 13
        i += 1
    im.alpha_composite(big, (32 - big.width // 2 + int(round(2 * math.sin(phase))), max(0, top)))
    a[:] = np.array(im)


BUBBLE_SETS = [[(27, 10, 3), (37, 15, 2), (31, 22, 2), (41, 8, 1), (23, 17, 1)],
               [(29, 14, 2), (36, 9, 3), (25, 6, 1), (39, 21, 2), (32, 26, 1)],
               [(26, 20, 2), (34, 12, 2), (40, 17, 1), (30, 6, 3), (22, 9, 1)]]


def bubbles(a, sk, phase):
    """the telegraph: a dome of liquid swelling in the mouth and bubbles rising up to 26 px"""
    body, mid, light, foam = (rgb(c) for c in sk["jet"])
    if not sk.get("puffs"):
        dome = shape_mask(GW, GH, lambda x, y: ((x - 32) / (9.0 + phase)) ** 2 +
                          ((y - G_MOUTH) / (4.0 + 1.5 * phase)) ** 2 - 1)
        dome[G_MOUTH + 1:, :] = False
        paint(a, dome, body)
        paint(a, dome & rim(dome, 1), mid)
        ys, xs = np.mgrid[0:GH, 0:GW]
        paint(a, dome & (ys == G_MOUTH - 2 - int(1.5 * phase)) & (np.abs(xs - 30) <= 2), foam)
    for x, dy, r in BUBBLE_SETS[phase]:
        y = G_MOUTH - dy
        for yy in range(y - r, y + r + 1):
            for xx in range(x - r, x + r + 1):
                d = math.hypot(xx - x, yy - y)
                if d <= r + 0.3:
                    a[yy, xx] = tuple(foam if d < r - 0.5 or r == 1 else light) + (255,)
    for x in range(23, 42, 3):                                       # the mouth seethes
        a[G_MOUTH - 1 - (x + phase) % 2, x] = tuple(light) + (255,)


def build_geyser():
    rows = []
    for name in GEYSER_ORDER:
        sk = GEYSER_SKINS[name]
        H = jet_height(name)
        fr = [vent(sk)]                                              # 0 idle
        for p in (0, 1, 2):                                          # 1-3 bubbling (telegraph)
            a = vent(sk, open_=True)
            if sk.get("puffs"):
                puffs(a, sk, G_MOUTH - 30 - 8 * p, p)
            bubbles(a, sk, p)
            fr.append(a)
        tops = [G_MOUTH - int(H * 0.4), G_MOUTH - H, G_MOUTH - H + 6, G_MOUTH - H + 24]
        for k, top in enumerate(tops):                               # 4 rise, 5-6 full, 7 collapse
            a = vent(sk, open_=True)
            if sk.get("puffs"):
                puffs(a, sk, top, k)
            else:
                jet(a, sk, top, phase=k * 1.6, broken=(k == 3))
                splash_crown(a, sk, top, k)
            fr.append(a)
        rows += [Image.fromarray(x, "RGBA") for x in fr]
    sheet = strip(rows, cols=8)
    save(sheet, "sprites/objects/geyser.png", kind="object", frame=[GW, GH], grid=[8, len(GEYSER_ORDER)],
         pivot=[GW // 2, GH], rows=GEYSER_ORDER,
         anims={"idle": anim([0], 1, False), "bubble": anim([1, 2, 3], 8),
                "spout": anim([4, 5, 6, 5, 6, 7], 12, False)},
         source=SRC + "sprites/fx/splash_water.png, sprites/fx/particles_smoke.png, sprites/fx/smoke.png "
                       "(superpowers-prehistoric-platformer: fx/effects); jet colours of tiles/common/water.png / "
                       "lava.png and the 2.0 tar.png; vent rim and jet drawn by the pipeline",
         edits="vent = an outlined rock rim (2 px #272018) with a dark mouth, lit upper left; jet = a wobbling column "
               "(44 px wide at the mouth, 32 at the head) in four liquid colours with light streaks and a foam head; "
               "crown = the shipped splash frames recoloured to the jet by luminance; steam = the shipped smoke "
               "particles and puff recoloured and stacked two abreast",
         note="`objects/geyser skin=mud|blowhole|steam|soda [deadly]` (C.4, PHYSICS C.6): row = skin (" +
              ", ".join("%d %s - %s" % (i, n, GEYSER_SKINS[n]["look"]) for i, n in enumerate(GEYSER_ORDER)) +
              "; a `deadly` geyser uses the tar row on tar levels and the lava row elsewhere). Columns: 0 idle vent, "
              "1-3 bubble (the 22-tick telegraph, loop), 4 spout rising, 5-6 full spout (loop), 7 collapsing "
              "(`spout` = 4, 5, 6, 5, 6, 7 over the 12 spout ticks). Pivot (32, 256) = the vent's floor point "
              "(anchor floor, bottom-centre). The rim is 48 x 14 art px, its mouth 21 x 7 around (32, 246). The jet "
              "is 44-48 art px (24 logical) wide; it reaches %d art px over the mouth (105 logical: the apex of the "
              "-224 launch, so a launched hero rides its head) in rows 0-3 and %d art px (64 logical, the deadly "
              "box) in the deadly rows 4-5; the vent box (24 x 16 logical) is the 48 x 32 art px above the floor "
              "around the pivot" % (JET_LAUNCH, JET_DEADLY), section="objects")
    return sheet


# ---------------------------------------------------------------------------------------------------- raft
LOG_OUT, LOG_BARK, LOG_BARK_D, LOG_RING, LOG_FACE = (rgb(h) for h in ("#272018", "#b64e13", "#793a15", "#d68428",
                                                                        "#f7bf3e"))


def log_end(d=14):
    """a cut log end in the colours of the anchor's log item (items/4.png): outline, face, two rings"""
    a = np.zeros((d, d, 4), np.uint8)
    c = (d - 1) / 2.0
    ys, xs = np.mgrid[0:d, 0:d]
    r = np.hypot(xs - c, ys - c)
    disc = r <= c + 0.3
    paint(a, disc, LOG_OUT)
    paint(a, r <= c - 1.7, LOG_BARK_D)
    paint(a, (r <= c - 1.7) & ((xs - c) + (ys - c) < 0), LOG_BARK)
    paint(a, r <= c - 3.0, LOG_FACE)
    paint(a, (np.abs(r - (c - 5.2)) <= 0.6), LOG_RING)
    paint(a, r <= 1.2, LOG_RING)
    return Image.fromarray(a, "RGBA")


def widen(row_img, W, keep_l=10, keep_r=10):
    a = np.array(row_img)
    w = a.shape[1]
    cols = list(range(keep_l)) + [keep_l + (i % (w - keep_l - keep_r)) for i in range(W - keep_l - keep_r)] + \
        list(range(w - keep_r, w))
    return Image.fromarray(a[:, cols].copy(), "RGBA")


def raft_log(width):
    """two logs lying lengthwise (the wood platform's board rows), the lower one a shade darker and set 2 px in,
    lashed by vertical rope bands every 32 px; a cut log end shows at each end of the lower log"""
    W = 32 * width
    pw = asset("sprites/objects/platform_wood.png")
    board = pw.crop((0, 0, 96, 10))
    deck = widen(board, W)                                          # board rows with the end bindings
    low = widen(board.transpose(Image.FLIP_TOP_BOTTOM), W - 4)      # the second log: grain flipped ...
    low = swap(low, {rgb("#9d4829"): rgb("#7f3910"), rgb("#7f3910"): rgb("#582d12"),   # ... and in shade
                     rgb("#f1b043"): rgb("#7f3910")})
    f = canvas(128, 24)
    x0 = (128 - W) // 2
    f.alpha_composite(low, (x0 + 2, 8))
    end = log_end(10)
    f.alpha_composite(end, (x0 + 1, 8))
    f.alpha_composite(end.transpose(Image.FLIP_LEFT_RIGHT), (x0 + W - 11, 8))
    f.alpha_composite(deck, (x0, 0))
    a = np.array(f)
    rope, rope_d = rgb("#f1b043"), rgb("#7f3910")
    for k in range(width):                                          # lashings across both logs
        x = x0 + 14 + k * 32
        a[1:17, x - 1] = O4
        a[1:17, x + 3] = O4
        a[1:17, x:x + 3] = tuple(rope) + (255,)
        for y in range(2, 17, 3):
            a[y, x + 1] = tuple(rope_d) + (255,)
    return Image.fromarray(a, "RGBA")


def raft_wafer(width):
    W = 32 * width
    bis = asset("tiles/feast/terrain_biscuit.png")
    t = [bis.crop(((i % 8) * 32, (i // 8) * 32, (i % 8) * 32 + 32, (i // 8) * 32 + 16)) for i in (27, 28, 29)]
    strip_ = canvas(W, 16)
    for k in range(width):
        strip_.alpha_composite(t[0] if k == 0 else t[2] if k == width - 1 else t[1], (k * 32, 0))
    a = np.array(strip_)
    cs = sorted(colours(strip_), key=lum)
    out_c = cs[0]
    groove = cs[1] if len(cs) > 1 else out_c
    # waffle grid: grooves every 6 px on the slab face (not on the outline rows / ends)
    solid = a[..., 3] > 0
    inner = solid & ~rim(solid, 3)
    ys, xs = np.mgrid[0:16, 0:W]
    grid = inner & (((xs - 2) % 6 == 0) | ((ys - 5) % 6 == 0)) & (ys >= 4)
    a[grid, :3] = groove
    f = canvas(128, 24)
    f.alpha_composite(Image.fromarray(a, "RGBA"), ((128 - W) // 2, 0))
    return f


def build_raft():
    frames = [raft_log(3), raft_log(4), raft_wafer(3), raft_wafer(4)]
    sheet = strip(frames, cols=1)
    save(sheet, "sprites/objects/raft.png", kind="object", frame=[128, 24], grid=[1, 4], pivot=[64, 0],
         rows=["log w3", "log w4", "wafer w3", "wafer w4"],
         source=SRC + "sprites/objects/platform_wood.png (deck with its rope bindings); " + SRC +
                "tiles/feast/terrain_biscuit.png tiles 27-29 (wafer); log ends drawn by the pipeline in the colours "
                "of superpowers-prehistoric-platformer: items/4.png",
         edits="log: the wood platform's board rows widened to 96 / 128 px (middle columns repeated, the end bindings "
               "kept) as the deck log over a second log (the same rows flipped, recoloured a shade darker, 2 px "
               "shorter each side) with a cut log end (outline + bark + face + rings in the log item's colours) at "
               "both ends, rope lashings every 32 px; wafer: the biscuit one-way tiles joined to 96 / 128 px with a "
               "waffle grid in the biscuit's own darker colour",
         note="`objects/raft width=3|4 skin=log|wafer` (C.5, PHYSICS C.7): row 0 log width 3, 1 log width 4, 2 wafer "
              "width 3, 3 wafer width 4 (the 96 px rafts are centred in the 128 px cell). Pivot (64, 0) = top-centre "
              "= the ride surface (the deck's top row, like platform_wood.png). The raft is 16 art px (8 logical) "
              "tall (the log skin's lower log, rows 8-17, sinks under the liquid's front layer). Dip 2 logical px "
              "per rider by moving the sprite", section="objects")
    return sheet


# ---------------------------------------------------------------------------------------------------- rex pen
def build_rex_pen():
    """objects/rex_pen: the village rope fence 9-sliced to 3 cells"""
    fence = np.array(asset("tiles/village/props/fence.png"))      # 62 x 28: three posts, sagging ropes
    # whole posts and whole rope spans only: post 1 | span | post 2 | span | post 2 | first span | post 3
    cols = list(range(0, 11)) + list(range(11, 25)) + list(range(25, 36)) + list(range(36, 50)) + \
        list(range(25, 36)) + list(range(11, 25)) + list(range(50, 62))
    W = len(cols)
    wide = Image.fromarray(fence[:, cols].copy(), "RGBA")
    f = canvas(112, 40)
    f.alpha_composite(wide, ((112 - W) // 2, 40 - 28))
    frames = [f]
    sheet = strip(frames)
    save(sheet, "sprites/objects/rex_pen.png", kind="object", frame=[112, 40], grid=[1, 1], pivot=[56, 40],
         source=SRC + "tiles/village/props/fence.png (superpowers-prehistoric-platformer: background-elements/"
                       "tileset-1.png)",
         edits="the rope fence lengthened from 3 to 4 posts by repeating whole posts and rope spans (62 -> 87 px), "
               "bottom-centred in a 112 x 40 cell",
         note="`objects/rex_pen name=` (C.8): Chomper's home marker, 87 art px (about 3 cells) wide, drawn BEHIND "
              "the rex. Pivot (56, "
              "40) = floor, bottom-centre on the pen's cell", section="objects")
    return sheet


# ---------------------------------------------------------------------------------------------------- paintings
# tablet colours (tiles/village/props/stone_tablet.png): outline, light, light 2, base, shade, dark
TAB = {k: rgb(v) for k, v in (("o", "#272018"), ("l", "#fef8e8"), ("l2", "#ffe79d"), ("b", "#ebb678"),
                               ("s", "#b99f7c"), ("d", "#70604a"))}
GHOST = rgb("#9aa6b8")
GLYPHS = {
    "hunter": ["....##......",
               "...####.....",
               "...####...#.",
               "....##...#..",
               "..######.#..",
               ".#.####.#...",
               "#..####.....",
               "...#..#.....",
               "..##..##....",
               "..#....#....",
               ".##....##..."],
    "rex":    [".......####.",
               "......######",
               "......##.##.",
               ".....####...",
               "#...#####...",
               ".#.######...",
               "..#######.#.",
               "...#####.#..",
               "....#..#....",
               "...##..##..."],
    "sun":    ["#....#....#.",
               ".#...#...#..",
               "...#####....",
               "..##...##...",
               "###.....###.",
               "..##...##...",
               "...#####....",
               ".#...#...#..",
               "#....#....#."],
    "hand":   ["..#.#.....",
               ".##.#.#...",
               ".######...",
               "#######...",
               ".######...",
               ".#####....",
               "..####....",
               "..###....."],
    "fish":   ["....####....",
               "..########.#",
               ".##.#######.",
               "##########..",
               ".#########.#",
               "..######...#",
               "....##......"],
    "spiral": [".######...",
               "#......#..",
               "#.####.#..",
               "#.#..#.#..",
               "#.#.##.#..",
               "#.#....#..",
               "#..####...",
               "#.........",
               ".#########"],
}
GLYPH_ORDER = ["hunter", "rex", "sun", "hand", "fish", "spiral"]


def shard_mask(variant):
    """an irregular broken stone fragment, 26 x 24, inside a 32 x 32 cell (bottom-centred)"""
    pts = [[(4, 8), (11, 3), (17, 5), (24, 2), (28, 9), (26, 16), (29, 23), (19, 30), (9, 29), (3, 22), (6, 15)],
           [(3, 6), (10, 4), (15, 2), (22, 5), (29, 4), (27, 13), (29, 21), (22, 29), (12, 30), (4, 25), (2, 15)]][
        variant % 2]
    from PIL import ImageDraw
    m = Image.new("L", (32, 32), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return np.array(m) > 0


def painting(i, found_before=False):
    name = GLYPH_ORDER[i]
    m = shard_mask(i)
    a = np.zeros((32, 32, 4), np.uint8)
    ys, xs = np.mgrid[0:32, 0:32]
    g = GLYPHS[name]
    gh, gw = len(g), len(g[0])
    gx, gy = 16 - gw // 2, 17 - gh // 2
    if found_before:
        # the "found before" look: only the fragment's outline and its glyph, in a cool grey, no fill
        paint(a, m & rim(m, 2), GHOST)
    else:
        paint(a, m, TAB["o"])
        body = m & ~rim(m, 2)
        paint(a, body, TAB["b"])
        paint(a, body & ((xs + ys) < 22), TAB["l2"])
        paint(a, body & ((xs + ys) < 15), TAB["l"])
        paint(a, body & ((xs - 16) * 0.6 + (ys - 16) > 9), TAB["s"])
        paint(a, body & rim(body, 1) & ((xs + ys) > 40), TAB["d"])
    for dy, line in enumerate(g):
        for dx, ch in enumerate(line):
            if ch == "#":
                x, y = gx + dx, gy + dy
                if found_before:
                    a[y, x] = tuple(GHOST) + (255,)
                else:
                    a[y, x] = tuple(OCHRE) + (255,)
                    if y + 1 < 32 and (dy + 1 >= gh or g[dy + 1][dx] != "#") and a[y + 1, x, 3]:
                        a[y + 1, x] = tuple(OCHRE_D) + (255,)      # the groove's shadow under each stroke
    return Image.fromarray(a, "RGBA")


def build_painting():
    frames = [painting(i) for i in range(6)] + [painting(i, True) for i in range(6)]
    sheet = strip(frames, cols=6)
    save(sheet, "sprites/items/painting.png", kind="item", frame=[32, 32], grid=[6, 2], pivot=[16, 32],
         rows=["new", "found before"], glyphs=GLYPH_ORDER,
         source="drawn by the pipeline in the colours of " + SRC + "tiles/village/props/stone_tablet.png (sandstone) "
                "and the anchor's cave-paint ochre (#b64e13 / #793a15, as the x2 tablet)",
         edits="a 26 x 28 broken sandstone fragment (2 px outline, lit upper left, shaded lower right) with a small "
               "cave-paint glyph in ochre and a 1 px groove shadow; row 1 = the same fragment as a grey outline "
               "with its glyph only",
         note="`items/painting index=0..29` (C.9), 16 x 16 logical, pivot (16, 32) bottom-centre (bob it like "
              "food). Column = index % 6: " + ", ".join("%d %s" % (i, n) for i, n in enumerate(GLYPH_ORDER)) +
              ". Row 0 = not found yet, row 1 = 'found before' (the profile already has it: grey outline, still "
              "collectible for the score)", section="items")
    return sheet


def build():
    return {"vine": build_vine(), "bark_board": build_bark_board(), "geyser": build_geyser(), "raft": build_raft(),
            "rex_pen": build_rex_pen(), "painting": build_painting()}


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()

"""Versus art for the Grub Stack slice (DESIGN E.3 / E.9 / F.1, GAMEPLAY 13.10.3; PLAN P2.7 / P2.9 pulled into phase
1): the cookpot, the spawn point, the crown, the stack pictures and the Golden Drumstick.

Sources: shipped 1.0 art (sprites/objects/pot.png, all from the anchor pack, Superpowers Prehistoric Platformer,
Pixel-boy, CC0), the anchor pack's own items and its fire-meat spit (background-elements/fire-meat.png), and one gem
of the Superpowers RPG Battle System (Pixel-boy, CC0) for the treasure picture. The crown and the cookpot's open mouth
are drawn here in the anchor's palette and outline. Edits: crops, 9-slice widening (middle columns / rows repeated),
exact colour swaps, composites; nearest-neighbour only, no scaling.
"""
import numpy as np
from PIL import Image

from xcommon import AP, EXP, OUTLINE, asset, canvas, colours, load, rgb, save, strip, swap, trim, anim
from build_coop_objects import grow, rim, paint, shape_mask
from build_hero_palettes import PALETTES, ui_ramp

import os

O4 = OUTLINE + (255,)
SLOT_COLOURS = ("yellow", "blue", "pink", "green")
LIT, LIT_W, AMBER, AMBER_D = rgb("#ffe94f"), rgb("#fffed9"), rgb("#f3aa39"), rgb("#c97d10")
OCHRE, OCHRE_D = rgb("#b64e13"), rgb("#793a15")
RB = os.path.join(EXP, "superpowers-rpg-battle-system")


def ap_item(n):
    return load(os.path.join(AP, "items", "%d.png" % n))


def fire_meat(k):
    return load(os.path.join(AP, "background-elements", "fire-meat.png")).crop((k * 84, 0, k * 84 + 84, 55))


# fire-meat.png colours: flames (yellow, orange, red-orange, ochre glow), logs, steam wisps
FM_FLAME = {rgb("#ffdb74"), rgb("#ffbc1d"), rgb("#ff6c1d"), rgb("#b3852b")}
FM_LOG = {rgb("#272018"), rgb("#aa5424"), rgb("#7f3910")}
FM_STEAM = {rgb("#82543b"), rgb("#ffdb74")}


def flames(k):
    """the spit's fire without the meat and the spit: flame colours of rows 37-52 and the log pile of rows 50-54,
    x 18-58 of frame k"""
    f = np.array(fire_meat(k))
    out = np.zeros_like(f)
    for y in range(37, 55):
        for x in range(18, 58):
            c = tuple(int(v) for v in f[y, x, :3])
            if f[y, x, 3] and ((c in FM_FLAME) or (y >= 50 and c in FM_LOG)):
                out[y, x] = f[y, x]
    return trim(Image.fromarray(out, "RGBA"))


def wisps(k):
    """the three steam wisps over the spit (rows 0-18)"""
    return trim(fire_meat(k).crop((26, 0, 60, 19)))


# ---------------------------------------------------------------------------------------------------- cookpot
CW, CH = 80, 72
POT_W = 64
FIRE_H = 7                   # embers / logs under the pot
BOWL_H = 24                  # rim top to pot bottom
POT_TOP = CH - FIRE_H - BOWL_H
P_OUT, P_BODY, P_SHADE, P_LIGHT = OUTLINE, rgb("#c35b27"), rgb("#893317"), rgb("#d9732d")   # the shipped pot.png
STEW = (rgb("#7f3910"), rgb("#aa5424"), rgb("#ffbc1d"), rgb("#ffdb74"))   # deep, stew, bubble, bubble light


def bowl_mask():
    """the cauldron's silhouette in the cell: a 4-row lip, then a bowl (an ellipse cut flat at the bottom)"""
    cx = CW / 2.0

    def fn(x, y):
        lip = (np.abs(x - cx) <= POT_W / 2.0 - 1) & (y >= POT_TOP) & (y < POT_TOP + 4)
        bowl = (((x - cx) / (POT_W / 2.0 - 2)) ** 2 + ((y - (POT_TOP + 4)) / (BOWL_H - 1.0)) ** 2 <= 1) & \
            (y >= POT_TOP + 4) & (y < POT_TOP + BOWL_H)
        return np.where(lip | bowl, -1.0, 1.0)
    return shape_mask(CW, CH, fn)


def pot_layer():
    """the pot in the colours of the shipped clay pot: 2 px outline, lit upper left, shaded right and bottom, a
    lighter lip band, two ring handles"""
    m = bowl_mask()
    a = np.zeros((CH, CW, 4), np.uint8)
    paint(a, m, P_OUT)
    body = m & ~rim(m, 2)
    paint(a, body, P_BODY)
    ys, xs = np.mgrid[0:CH, 0:CW]
    paint(a, body & ((xs - CW / 2.0) / 30.0 + (ys - POT_TOP - 6) / 18.0 > 0.75), P_SHADE)
    paint(a, body & (ys >= POT_TOP + BOWL_H - 4), P_SHADE)
    paint(a, body & ((xs - 20) ** 2 / 25.0 + (ys - POT_TOP - 9) ** 2 / 9.0 <= 1), P_LIGHT)   # highlight
    paint(a, body & (ys == POT_TOP + 2), P_LIGHT)                   # lip band: light top row ...
    paint(a, m & (ys == POT_TOP + 4) & (np.abs(xs - CW / 2.0) <= POT_W / 2.0 - 3), P_OUT)   # ... outline below
    for hx in (CW // 2 - POT_W // 2 - 3, CW // 2 + POT_W // 2 - 2):  # ring handles at both sides of the belly
        ring = (np.abs(np.hypot(xs + 0.5 - (hx + 2.5), ys + 0.5 - (POT_TOP + 10))) - 3.0) <= 0.9
        paint(a, ring & ~m, P_OUT)
    return a


BUBBLES = {"idle": [[(30, 6, 1)]] * 4,
           "bank": [[(12, 6, 1), (38, 5, 2), (26, 7, 1)], [(16, 5, 2), (42, 7, 1), (30, 4, 1)],
                    [(10, 5, 1), (34, 6, 2), (22, 5, 1)], [(18, 7, 1), (44, 5, 1), (28, 5, 2)]]}


def mouth(kind, k):
    """the open mouth seen from slightly above: lip ring and stew (bubbles while banking)"""
    w, h = POT_W - 6, 10
    a = np.zeros((h, w, 4), np.uint8)
    ring = shape_mask(w, h, lambda x, y: ((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2 - 1)
    inner = shape_mask(w, h, lambda x, y: ((x - w / 2) / (w / 2 - 3)) ** 2 + ((y - h / 2) / (h / 2 - 2)) ** 2 - 1)
    paint(a, ring, P_OUT)
    paint(a, ring & ~inner & ~rim(ring, 1), P_LIGHT)
    ys, xs = np.mgrid[0:h, 0:w]
    paint(a, inner, STEW[1])
    paint(a, inner & (ys <= 3), STEW[0])                            # the far wall's shadow on the stew
    for x, y, r in BUBBLES.get(kind, [[]] * 4)[k % 4]:
        for yy in range(y - r, y + r + 1):
            for xx in range(x - r - 1, x + r + 2):
                d = ((xx - x) / (r + 1.0)) ** 2 + ((yy - y) / max(1.0, r)) ** 2
                if d <= 1.05 and 0 <= yy < h and 0 <= xx < w and inner[yy, xx]:
                    a[yy, xx] = tuple(STEW[3] if d < 0.4 else STEW[2]) + (255,)
    return a


def cookpot_frames(kind, k):
    """kind: idle / bank / lid; k = animation step. Returns (back, front) 80 x 72 images"""
    back = canvas(CW, CH)
    front = canvas(CW, CH)
    fl = flames(k % 4)
    for im in (back, front):
        im.alpha_composite(fl, ((CW - fl.width) // 2, CH - fl.height))
    pot = pot_layer()
    mo = mouth(kind, k)
    my = POT_TOP - 4                                                # the mouth ellipse sits on the rim
    mx = (CW - mo.shape[1]) // 2
    ba = np.array(back)
    pm = pot[..., 3] > 0
    ba[pm] = pot[pm]
    sub = ba[my:my + mo.shape[0], mx:mx + mo.shape[1]]
    mm = mo[..., 3] > 0
    sub[mm] = mo[mm]
    fa = np.array(front)
    # front: the pot below the mouth's centre row + the near half of the lip ring (no stew)
    half = my + mo.shape[0] // 2
    fpot = pot.copy()
    fpot[:half] = 0
    fm = fpot[..., 3] > 0
    fa[fm] = fpot[fm]
    near = mo.copy()
    near[:mo.shape[0] // 2] = 0
    for c in STEW:
        near[(near[..., 0] == c[0]) & (near[..., 1] == c[1]) & (near[..., 2] == c[2])] = 0
    fsub = fa[my:my + mo.shape[0], mx:mx + mo.shape[1]]
    nm = near[..., 3] > 0
    fsub[nm] = near[nm]
    back = Image.fromarray(ba, "RGBA")
    front = Image.fromarray(fa, "RGBA")
    if kind == "bank":                                              # steam rises from the stew
        w = wisps(k % 4)
        back.alpha_composite(w, ((CW - w.width) // 2 + (k % 2) * 2 - 1, my - w.height - 1 - 2 * (k % 2)))
    if kind == "lid":                                               # a plank lid with the clay pot's knob
        p = np.array(asset("sprites/objects/pot.png"))
        knob = Image.fromarray(p[0:5, 5:12].copy(), "RGBA")
        lid_w = POT_W - 4
        pw = asset("sprites/objects/platform_wood.png").crop((0, 0, 96, 10))
        a = np.array(pw)
        cols = list(range(10)) + [10 + (i % 76) for i in range(lid_w - 20)] + list(range(86, 96))
        board = Image.fromarray(a[:, cols].copy(), "RGBA")
        lid = canvas(lid_w, 14)
        lid.alpha_composite(board, (0, 4))
        lid.alpha_composite(knob, ((lid_w - knob.width) // 2, 0))
        for im in (back, front):
            im.alpha_composite(lid, ((CW - lid_w) // 2, my - 6))
    return back, front


def build_cookpot():
    plan = [("idle", 0), ("idle", 1), ("idle", 2), ("idle", 3), ("bank", 0), ("bank", 1), ("bank", 2), ("bank", 3),
            ("lid", 0), ("lid", 2)]
    backs, fronts = [], []
    for kind, k in plan:
        b, f = cookpot_frames(kind, k)
        backs.append(b)
        fronts.append(f)
    sheet = strip(backs + fronts, cols=len(plan))
    save(sheet, "sprites/objects/cookpot.png", kind="object", frame=[CW, CH], grid=[len(plan), 2],
         pivot=[CW // 2, CH],
         anims={"idle": anim([0, 1, 2, 3], 8), "bank": anim([4, 5, 6, 7], 10), "lid": anim([8, 9], 8)},
         source="shipped sprites/objects/pot.png (superpowers-prehistoric-platformer: background-elements/"
                "tileset-1.png: its colours and its lid knob); shipped sprites/objects/platform_wood.png (the lid); "
                "superpowers-prehistoric-platformer: background-elements/fire-meat.png (flames, log pile, steam "
                "wisps); the cauldron and its mouth drawn by the pipeline in the pot's colours",
         edits="cauldron: a 64 x 24 bowl (lip band + an ellipse cut flat at the bottom, two ring handles) in the "
               "shipped clay pot's four colours (2 px outline, lit upper left, shaded right / bottom); mouth: an "
               "outlined ellipse ring over a stew of the anchor's browns with bubble rings; fire: only the flame and "
               "log colours of the spit's rows 37-54 (no meat, no spit), its four frames kept; steam: the spit's "
               "three wisps; lid: the wood platform's board rows widened to 60 px with the clay pot's knob on top",
         note="`objects/cookpot` (versus, E.3 / GAMEPLAY 13.10.3): 2 cells wide (the 64 px pot centred in an 80 px "
              "cell), pivot (40, 72) = floor, bottom-centre. Row 0 = BACK frames (draw behind the heroes), row 1 = "
              "FRONT frames (the same index, drawn in front: fire, the bowl below the rim and the near lip, so a "
              "crouching banker sits inside with head and shoulders over the rim, 31 art px above the floor). "
              "Columns: 0-3 idle (fire), 4-7 bank (stew bubbling, steam: while someone banks), 8-9 lid (Feast "
              "Rush: lids closed, no banking)", section="versus")
    return sheet


# ---------------------------------------------------------------------------------------------------- spawn point
SW, SH = 48, 16
SPIRAL = ["....oooo....",
          "..oo....oo..",
          ".o..oooo..o.",
          ".o.o....o.o.",
          ".o.o.oo.o.o.",
          ".o..o...o.o.",
          "..o....o..o.",
          "...oooo..o..",
          ".........o.."]


def spawn_slab():
    """a flat sandstone slab (the code stone's colours) lying on the floor, a cave-paint spiral on its face"""
    stone = asset("sprites/objects/code_stone.png")                 # 30 x 22 sandstone pebble
    cs = sorted(colours(stone), key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
    dark, mid, light = cs[1] if len(cs) > 2 else cs[0], rgb("#ebb678"), cs[-1]
    a = np.zeros((SH, SW, 4), np.uint8)
    slab = shape_mask(SW, SH, lambda x, y: ((x - SW / 2) / (SW / 2 - 1)) ** 2 + ((y - 9) / 7.0) ** 2 - 1)
    slab[SH - 1:, :] = False
    paint(a, slab, OUTLINE)
    body = slab & ~rim(slab, 2)
    paint(a, body, mid)
    ys, xs = np.mgrid[0:SH, 0:SW]
    paint(a, body & (ys >= 11), rgb("#b99f7c"))
    paint(a, body & (ys <= 4) & (xs < SW // 2), light)
    return a


def spawn_frame(fill, groove):
    a = spawn_slab()
    x0, y0 = (SW - len(SPIRAL[0])) // 2, 2
    for dy, line in enumerate(SPIRAL[:7]):
        for dx, ch in enumerate(line):
            if ch == "o" and a[y0 + dy, x0 + dx, 3]:
                a[y0 + dy, x0 + dx, :3] = fill
                if a[y0 + dy + 1, x0 + dx, 3] and SPIRAL[min(8, dy + 1)][dx] != "o":
                    a[y0 + dy + 1, x0 + dx, :3] = groove
    return Image.fromarray(a, "RGBA")


def build_spawn_point():
    frames = [spawn_frame(OCHRE, OCHRE_D)]
    for cname in SLOT_COLOURS:
        r = ui_ramp(PALETTES[cname])
        frames.append(spawn_frame(r["fill"], r["shade"]))
    frames.append(spawn_frame(LIT_W, LIT))
    for cname in ("white", "gold"):                                 # phase 2: the two other hero colours
        r = ui_ramp(PALETTES[cname])
        frames.append(spawn_frame(r["fill"], r["shade"]))
    sheet = strip(frames)
    save(sheet, "sprites/objects/spawn_point.png", kind="object", frame=[SW, SH], grid=[len(frames), 1],
         pivot=[SW // 2, SH],
         source="shipped sprites/objects/code_stone.png (colours) - the slab and the spiral drawn by the pipeline",
         edits="a flat 48 x 15 slab ellipse in the code stone's sandstone colours (2 px #272018 outline, lit upper "
               "left, shaded front) with a 12 x 7 cave-paint spiral in ochre; lit frames recolour the spiral to a "
               "hero colour's loincloth fill / shadow (hero_palettes ui ramp) or to the anchor's light yellow",
         note="`objects/spawn_point index=2..4` (arenas; `@` is spawn 1): a floor marker drawn behind the heroes, 3 x 1 "
              "cells, pivot (24, 16) = floor, bottom-centre on the spawn cell. 0 idle (ochre), 1-4 = the spawn "
              "about to be used by P1-P4 (the 48-tick respawn wait: show the respawning player's colour - 1 yellow, "
              "2 blue, 3 pink, 4 green), 5 neutral light (round start, every pad lit), 6 white, 7 gold (the two "
              "other hero colours, phase 2)", section="versus")
    return sheet


# ---------------------------------------------------------------------------------------------------- crown
def crown_image(spark=0):
    """a gold crown: a band with three points tipped by balls and a red gem, 2 px anchor outline, lit upper left"""
    W, H = 32, 24
    a = np.zeros((H, W, 4), np.uint8)
    ys, xs = np.mgrid[0:H, 0:W]
    shape = np.zeros((H, W), bool)
    band = (ys >= 15) & (ys <= 20) & (xs >= 5) & (xs <= 26)
    shape |= band
    for cx in (8, 16, 23):                                          # three points
        tip = 7 if cx == 16 else 9
        half = (ys - tip) * 0.55
        shape |= (ys >= tip) & (ys <= 15) & (np.abs(xs + 0.5 - (cx + 0.5)) <= half + 0.6)
        shape |= np.hypot(xs + 0.5 - (cx + 0.5), ys + 0.5 - (tip - 1.0)) <= 2.2   # ball tips
    outl = grow(shape, 2) & ~shape
    paint(a, outl, OUTLINE)
    paint(a, shape, LIT)
    paint(a, shape & ((xs >= 18) | (ys >= 19)), AMBER)                # shade right / bottom
    paint(a, shape & (ys == 20), AMBER_D)
    paint(a, band & (ys == 16) & (xs <= 14), LIT_W)                   # light on the band
    for cx in (8, 16, 23):
        tip = 7 if cx == 16 else 9
        a[tip - 2, cx] = tuple(LIT_W) + (255,)
    # gem in the band centre
    gem = [".oo.", "orRo", "oRRo", ".oo."]
    for dy, line in enumerate(gem):
        for dx, ch in enumerate(line):
            c = {"o": OUTLINE, "r": rgb("#ffffff"), "R": rgb("#ff3f44")}.get(ch)
            if c is not None:
                a[16 + dy, 14 + dx] = tuple(c) + (255,)
    for gx in (8, 22):                                              # two small studs
        a[17, gx:gx + 2] = tuple(OCHRE) + (255,)
        a[18, gx:gx + 2] = tuple(OCHRE_D) + (255,)
    if spark:
        sx, sy = (6, 3) if spark == 1 else (26, 5)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)):
            x, y = sx + dx, sy + dy
            if 0 <= x < W and 0 <= y < H and not a[y, x, 3]:
                a[y, x] = tuple(LIT_W if abs(dx) + abs(dy) <= 1 else LIT) + (255,)
    return Image.fromarray(a, "RGBA")


def build_crown():
    frames = [crown_image(0), crown_image(1), crown_image(2)]
    sheet = strip(frames)
    save(sheet, "ui/crown.png", kind="ui", frame=[32, 24], grid=[3, 1], pivot=[16, 22],
         anims={"shine": anim([0, 0, 0, 1, 0, 0, 2], 8)},
         source="drawn by the pipeline in the anchor's palette (yellow #ffe94f / amber #f3aa39 of the hero cloth and "
                "the drum, outline #272018), gem red of superpowers-rpg-battle-system: item/68.png",
         edits="band + three points with ball tips, 2 px outline, lit upper left, a red gem and two ochre studs; "
               "frames 1-2 add a 4-point sparkle at a tip",
         note="the crown on the Grub Stack leader (E.3 / E.9; ties: no crown), also for the HUD panel of the leader. "
              "Pivot (16, 22) = the crown's foot: put it on top of the leader's stack tower (or his head when the "
              "stack is empty). `shine` = 0 with a sparkle every few frames", section="versus")
    return sheet


# ---------------------------------------------------------------------------------------------------- stack pictures
GOLD = {rgb("#ffa756"): LIT, rgb("#ee7142"): AMBER}                # meat -> gold (bone and outline kept)


def golden_drumstick():
    return swap(ap_item(47), GOLD)


def build_stack_food():
    pics = [
        (ap_item(39), "1 unit: small food (an orange; superpowers-prehistoric-platformer items/39)"),
        (ap_item(47), "2 units: big food (meat on the bone; items/47)"),
        (load(os.path.join(RB, "item", "57.png")), "5 units: treasure (a gem; superpowers-rpg-battle-system "
                                                    "item/57, outline -> #272018)"),
        (ap_item(8), "10 units: giant bonus (the roast; items/8)"),
        (asset("sprites/objects/pot.png"), "banked units (the shipped clay pot) for the HUD"),
        (golden_drumstick(), "the Golden Drumstick (tie-break, HUD / results)"),
    ]
    W, H = 32, 28
    frames = []
    for im, _ in pics:
        im = trim(im)
        # every outline of a non-anchor pack -> the anchor outline
        dark = [c for c in colours(im) if sum(c) < 60]
        im = swap(im, {c: OUTLINE for c in dark})
        f = canvas(W, H)
        f.alpha_composite(im, ((W - im.width) // 2, H - im.height))
        frames.append(f)
    sheet = strip(frames)
    save(sheet, "ui/stack_food.png", kind="ui", frame=[W, H], grid=[len(frames), 1], pivot=[W // 2, H],
         source="superpowers-prehistoric-platformer: items/39.png, 47.png, 8.png; superpowers-rpg-battle-system: "
                "item/57.png; shipped sprites/objects/pot.png",
         edits="native 1x (the anchor's density, no scaling), bottom-centred in 32 x 28 cells; the RPG gem's outline "
               "#000c00 -> #272018; golden drumstick = the meat leg with its meat recoloured to the anchor's yellow / "
               "amber (bone and outline kept)",
         note="Grub Stack pictures (E.3: the stack shown as a wobbling tower on the head; above 8 pictures it "
              "regroups into 10s, 5s and 1s). Cells: " + "; ".join("%d %s" % (i, d) for i, (_, d) in enumerate(pics)) +
              ". Pivot (16, 28) = the picture's foot. Suggested tower (biggest at the bottom: 10s, 5s, 2s, 1s): the "
              "first picture's foot 4 art px below the head top (it sits on the hair), then one picture every 14 "
              "art px up (they overlap), the crown on top; 8 pictures stand about 70 logical px over the head", section="versus")
    item = canvas(40, 40)
    g = trim(golden_drumstick())
    item.alpha_composite(g, ((40 - g.width) // 2, 40 - g.height - 4))
    frames = [item]
    for k, (sx, sy) in enumerate(((8, 8), (30, 12))):
        f = item.copy()
        a = np.array(f)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)):
            x, y = sx + dx, sy + dy
            if not a[y, x, 3]:
                a[y, x] = tuple(LIT_W if abs(dx) + abs(dy) <= 1 else LIT) + (255,)
        frames.append(Image.fromarray(a, "RGBA"))
    s2 = strip(frames)
    save(s2, "sprites/items/golden_drumstick.png", kind="item", frame=[40, 40], grid=[3, 1], pivot=[20, 40],
         anims={"shine": anim([0, 1, 0, 2], 6)},
         source="superpowers-prehistoric-platformer: items/47.png",
         edits="meat recoloured to the anchor's yellow #ffe94f / amber #f3aa39 (exact swap; bone and outline kept), "
               "4 px above the cell foot (the food bob room); frames 1-2 add a sparkle",
         note="the Golden Drumstick (E.3 / GAMEPLAY 13.10.3): falls in the middle of the arena on a tie; first to grab "
              "it wins. Pivot (20, 40) bottom-centre like the food cells", section="items")
    return sheet, s2


def build():
    return {"cookpot": build_cookpot(), "spawn_point": build_spawn_point(), "crown": build_crown(),
            "stack_food": build_stack_food()}


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()

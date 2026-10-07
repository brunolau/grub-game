"""Proof sheets of the art-A 2.0 files (docs/art/expansion/*.png), composed only from the files under assets/.

coop_objects_frames.png  every frame of every new object / item / fx / UI sheet, labelled, 2x
coop_scene_canyon.png    plate, drums, see-saw, flower-pot gift, x2 tablet with P1-P4 on the world 5 kit, 2x
coop_scene_cave.png      heave boulder, pulley lifts, revive egg, stuck spear, tags, edge arrow + countdown, HUD belt
mp_indicators.png        tags, arrows, eggs and belt icons on every biome, then under protanopia / deuteranopia /
                         tritanopia (Machado 2009) and greyscale
eggs_p1_p4.png           the revive egg in the six palettes, every frame
"""
import json
import os

import numpy as np
from PIL import Image

import cvd
from backdrops import ALL as BIOMES, GROUND_Y, backdrop
from build_hero_palettes import PALETTES, PATTERN_INDEX, SLOT_DEFAULT, Palettes, frame, label
from xcommon import ASSETS, REGISTRY, asset, canvas, hstack, save_doc, scale, vstack

BG = (58, 66, 84, 255)
SLOTS = (1, 2, 3, 4)


def cells(rel):
    e = REGISTRY["assets/" + rel]
    im = asset(rel)
    fw, fh = e["frame"]
    gc, gr = e["grid"]
    return [im.crop((c * fw, r * fh, c * fw + fw, r * fh + fh)) for r in range(gr) for c in range(gc)]


def hero(P, sheets, slot, f, sheet="hero", colour=None, mirror=False):
    c, pat = SLOT_DEFAULT[slot]
    im = P.apply(frame(sheets[sheet], f), colour or c, PATTERN_INDEX[pat])
    return im.transpose(Image.FLIP_LEFT_RIGHT) if mirror else im


def put_hero(scene, im, x, feet_y):
    """hero cell pivot (88, 96) -> (x, feet_y)"""
    scene.alpha_composite(im, (x - 88, feet_y - 96))


def put(scene, im, x, bottom_y, pivot_x=None):
    px = im.width // 2 if pivot_x is None else pivot_x
    scene.alpha_composite(im, (int(x - px), int(bottom_y - im.height)))


# ---------------------------------------------------------------------------------------------------- frames sheet
def frames_sheet():
    from build_previews_b2 import PHASE1                         # those have their own sheet (book2_objects.png)
    rels = [k[len("assets/"):] for k in sorted(REGISTRY) if k.endswith(".png") and "/palettes/" not in k
            and REGISTRY[k].get("owner", "art-A") == "art-A" and k[len("assets/"):] not in PHASE1]
    blocks = []
    for rel in rels:
        cs = cells(rel)
        e0 = REGISTRY["assets/" + rel]
        fw, fh = e0["frame"]
        if fw * e0["grid"][0] > 1000:                   # big sheet (hero): show it whole at 1x
            im = asset(rel)
            t = Image.new("RGBA", im.size, (88, 98, 118, 255))
            t.alpha_composite(im)
            row = t
            S = 1
        else:
            S = 2
            row_cells = []
            for i, c in enumerate(cs):
                t = Image.new("RGBA", c.size, (88, 98, 118, 255) if i % 2 else (78, 88, 108, 255))
                t.alpha_composite(c)
                row_cells.append(scale(t, S))
            per = max(1, 1900 // (fw * S + 4))
            rows = [hstack(row_cells[i:i + per], 4, BG) for i in range(0, len(row_cells), per)]
            row = vstack(rows, 4, BG)
        head = Image.new("RGBA", (max(row.width, 600), 16), BG)
        e = REGISTRY["assets/" + rel]
        label(head, "%s  %dx%d, cell %dx%d, grid %dx%d" % (rel, e["size"][0], e["size"][1], e["frame"][0],
                                                         e["frame"][1], e["grid"][0], e["grid"][1]), 2, 2,
              (255, 255, 160, 255))
        blocks.append(vstack([head, row], 2, BG))
    return vstack(blocks, 10, BG)


# ---------------------------------------------------------------------------------------------------- scenes
def scene_canyon(P, sheets):
    sc = backdrop("canyon", x0=120)
    g = GROUND_Y
    tab = cells("sprites/objects/x2_tablet.png")
    put(sc, tab[0], 44, g)
    plate = cells("sprites/objects/plate.png")
    put(sc, plate[1], 120, g)                                    # count 1, pressed + lit, P2 on it
    put_hero(sc, hero(P, sheets, 2, 0), 120, g - 5)
    put(sc, plate[3], 196, g)                                    # count 2, up
    drum = cells("sprites/objects/drum.png")
    put(sc, drum[1], 254, g)                                     # struck
    put(sc, drum[3], 296, g)                                     # lit: waiting for its bond partner
    piv = asset("sprites/objects/seesaw_pivot.png")
    put(sc, piv, 392, g)
    plank = cells("sprites/objects/seesaw_plank.png")[1 * 5 + 0]  # len 4, left end down
    sc.alpha_composite(plank, (392 - 104, g - piv.height - 40))
    put_hero(sc, hero(P, sheets, 4, 21), 346, g - 4)             # P4 crouches on the low end
    put_hero(sc, hero(P, sheets, 1, 18), 440, g - 120)           # P1 falls onto the high end
    pot = cells("sprites/objects/flower_pot.png")
    put(sc, pot[0], 474, g - 64)
    put_hero(sc, hero(P, sheets, 3, 28, mirror=True), 530, g - 64)  # P3 clubs the pot off the ledge
    label(sc, "plate (count 1 pressed + lit / count 2 up), drums (struck / lit), see-saw len 4, flower-pot gift, x2 tablet", 6, 4)
    return sc


def scene_cave(P, sheets):
    sc = backdrop("cave", x0=60)
    g = GROUND_Y
    # heave boulder pushed by P1 + P2
    bh = cells("sprites/objects/boulder_heavy.png")
    put(sc, bh[0], 180, g)
    put_hero(sc, hero(P, sheets, 2, 9), 100, g)
    put_hero(sc, hero(P, sheets, 1, 11), 132, g)
    tags = cells("ui/player_tags.png")
    put(sc, tags[1], 98, g - 64)
    put(sc, tags[0], 134, g - 64)
    # pulley lifts: beam, hanger straps + wheels, one rope over both wheels, two platforms
    pul = cells("sprites/objects/pulley.png")
    beam = asset("sprites/objects/platform_wood.png")
    for bx in (232, 328):
        sc.alpha_composite(beam.crop((0, 0, 96, 10)), (bx, 20))
    wx = (268, 392)
    wy = 30 + 22                                                 # wheel centres: strap top at the beam bottom (30)
    for x in wx:
        sc.alpha_composite(pul[1], (x - 16, wy - 16))
    rope_h = pul[4].rotate(90, Image.NEAREST)
    for x in range(wx[0], wx[1], 32):
        sc.alpha_composite(rope_h.crop((0, 0, min(32, wx[1] - x), 32)), (x, wy - 15 - 15))
    for x in wx:
        sc.alpha_composite(pul[6], (x - 16, 30))
    lp_y, rp_y = g - 36, g - 132                                 # P3 rides the low lift; the high one waits
    for x, py in ((wx[0] - 15, lp_y), (wx[1] + 15, rp_y)):
        y = wy
        while y < py - 32:
            sc.alpha_composite(pul[4], (x - 16, y))
            y += 32
        sc.alpha_composite(pul[4].crop((0, 0, 32, max(0, py - 26 - y))), (x - 16, y))
        sc.alpha_composite(pul[5], (x - 16, py - 26))
        sc.alpha_composite(beam, (x - 48, py))
    put_hero(sc, hero(P, sheets, 3, 0), wx[0] - 15, lp_y)
    # spear stuck in the block face, P4 in an egg, edge arrow + countdown for P2 (off to the right)
    sp = cells("sprites/fx/projectile_spear.png")
    sc.alpha_composite(sp[4], (448 - 59, g - 44 - 28))
    egg = cells("sprites/player/hero_egg.png")
    e = P.apply(egg[0], "green", 0, use_cloth=False)
    put(sc, e, 520, g - 64 - 10 + 16, 32)
    arrows = cells("ui/player_arrows.png")
    stones = cells("ui/countdown_stones.png")
    sc.alpha_composite(arrows[1 * 4 + 1], (640 - 36, 150))
    sc.alpha_composite(stones[2], (640 - 70, 150))
    # HUD: P1 hearts + belt icon top-left, P2 mirrored top-right
    heart = asset("ui/hud_heart.png").crop((0, 0, 32, 32))
    belt = cells("ui/hud_belt.png")
    for i in range(3):
        sc.alpha_composite(heart, (270 + 34 * i - 200, 8))
        sc.alpha_composite(heart, (640 - 70 - 34 * i - 32 - 40 + 40, 8))
    sc.alpha_composite(belt[2], (176, 8))
    sc.alpha_composite(belt[4], (640 - 210, 8))
    label(sc, "heave boulder (two push), pulley lifts, stuck spear, P4 egg, P2 edge arrow + countdown, belt icons",
          6, 44)
    return sc


# ---------------------------------------------------------------------------------------------------- indicators
def indicator_strip(P, sheets):
    tags = cells("ui/player_tags.png")
    arrows = cells("ui/player_arrows.png")
    egg = cells("sprites/player/hero_egg.png")[0]
    panels = []
    for b in BIOMES:
        bg = backdrop(b, x0=300).crop((0, GROUND_Y - 120, 520, GROUND_Y + 8))   # feet at y 120
        for k, s in enumerate(SLOTS):
            c, pat = SLOT_DEFAULT[s]
            h = P.apply(frame(sheets["hero"], 0), c, PATTERN_INDEX[pat])
            bg.alpha_composite(h, (k * 64 - 64, 120 - 96))
            bg.alpha_composite(tags[k], (k * 64 + 8, 120 - 56 - 48 - 2))
            e = P.apply(egg, c, 0, use_cloth=False)
            bg.alpha_composite(e.crop((8, 20, 56, 88)), (270 + k * 46, 120 - 68 + 12 - 6))
            bg.alpha_composite(arrows[k * 4 + 2], (276 + k * 46 + 8, 4))
        label(bg, b, 4, 2)
        panels.append(bg)
    rows = [hstack(panels[i:i + 3], 4, BG) for i in range(0, len(panels), 3)]
    return vstack(rows, 4, BG)


def indicators_sheet(P, sheets):
    normal = indicator_strip(P, sheets)
    out = [normal]
    # CVD rows on three representative biomes
    sub = normal.crop((0, 0, normal.width, normal.height // 4 + 2))
    for kind, model, name in (("protan", "machado", "protanopia"), ("deutan", "machado", "deuteranopia"),
                              ("tritan", "machado", "tritanopia"), ("grey", None, "greyscale")):
        g = sub.convert("LA").convert("RGBA") if kind == "grey" else cvd.simulate_image(sub, kind, model)
        head = Image.new("RGBA", (g.width, 16), BG)
        label(head, name + " (Machado 2009) - first row of biomes" if model else name, 4, 2)
        out.append(vstack([head, g], 0, BG))
    return scale(vstack(out, 8, BG), 2)


def eggs_sheet(P):
    egg = cells("sprites/player/hero_egg.png")
    rows = []
    for c in PALETTES:
        r = [P.apply(f, c, 0, use_cloth=False) for f in egg]
        t = [Image.new("RGBA", f.size, (88, 98, 118, 255)) for f in r]
        for a, b in zip(t, r):
            a.alpha_composite(b)
        row = hstack(t, 2, BG)
        label(row, c, 2, 2)
        rows.append(row)
    body = vstack(rows, 2, BG)
    sims = [body]
    for kind, name in (("protan", "protanopia"), ("deutan", "deuteranopia")):
        g = cvd.simulate_image(body.crop((0, 0, body.width, (body.height // 6) * 4)), kind)
        head = Image.new("RGBA", (g.width, 14), BG)
        label(head, name + " (Machado 2009): P1-P4 defaults", 2, 1)
        sims.append(vstack([head, g], 0, BG))
    return scale(vstack(sims, 6, BG), 2)


def build():
    P = Palettes()
    sheets = {}
    for s in ("hero", "hero_axe", "hero_boomerang", "hero_hammer", "hero_spear"):
        sheets[s] = asset("sprites/player/%s.png" % s)
    save_doc(frames_sheet(), "coop_objects_frames.png")
    save_doc(scale(scene_canyon(P, sheets), 2), "coop_scene_canyon.png")
    save_doc(scale(scene_cave(P, sheets), 2), "coop_scene_cave.png")
    save_doc(indicators_sheet(P, sheets), "mp_indicators.png")
    save_doc(eggs_sheet(P), "eggs_p1_p4.png")


if __name__ == "__main__":
    from xcommon import load_registry
    load_registry()
    build()

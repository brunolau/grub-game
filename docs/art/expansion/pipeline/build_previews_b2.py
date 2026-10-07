"""Proof sheets of the phase-1 art-A files (docs/art/expansion/*.png), composed only from files under assets/.

book2_objects.png         the new Book II / versus / skin sheets frame by frame, labelled, 2x (big sheets 1x)
book2_scene_gulch.png     canyon: vines (canyon skin) with a climbing hero, a rolled vine, a bark board with a spear
                          step and a hero on it, a mud geyser launching a hero, a painting fragment, 2x
book2_scene_fen.png       Tar Fen: a tar pool with a log raft and two riders, tar floor with a wading hero, a deadly tar
                          vent, Chomper in his saddle with driver and gunner, the rex pen, 2x
liquids_tar_floor.png     every liquid strip and every tar floor on a matching ground, with a standing hero, 2x
versus_totem_ring.png     Grub Stack on the Totem Ring: cookpot with a banker, stack towers with the crown, lit spawn
                          pads, the Golden Drumstick, 2x
"""
import numpy as np
from PIL import Image

from backdrops import GROUND_Y, backdrop
from build_hero_palettes import PATTERN_INDEX, SLOT_DEFAULT, Palettes, frame, label
from xcommon import REGISTRY, asset, canvas, hstack, save_doc, scale, vstack

BG = (58, 66, 84, 255)
PHASE1 = ["sprites/objects/vine.png", "sprites/objects/bark_board.png", "sprites/objects/geyser.png",
          "sprites/objects/raft.png", "sprites/objects/rex_pen.png", "sprites/objects/rex_saddle.png",
          "sprites/objects/seesaw_plank_mushroom.png", "sprites/objects/seesaw_plank_floe.png",
          "sprites/objects/cookpot.png", "sprites/objects/spawn_point.png", "sprites/items/painting.png",
          "sprites/items/golden_drumstick.png", "ui/crown.png", "ui/stack_food.png", "ui/emotes.png",
          "tiles/common/tar.png", "tiles/common/honey.png", "tiles/common/syrup.png",
          "tiles/common/tar_floor.png", "tiles/common/honey_floor.png", "tiles/common/syrup_floor.png",
          "tiles/common/water_floor.png", "tiles/common/lava_floor.png", "tiles/common/ice_water_floor.png"]


def cells(rel):
    e = REGISTRY["assets/" + rel]
    im = asset(rel)
    fw, fh = e["frame"]
    gc, gr = e["grid"]
    return [im.crop((c * fw, r * fh, c * fw + fw, r * fh + fh)) for r in range(gr) for c in range(gc)]


def cell(rel, i):
    return cells(rel)[i]


def hero(P, sheets, slot, f, mirror=False, sheet="hero"):
    c, pat = SLOT_DEFAULT[slot]
    im = P.apply(frame(sheets[sheet], f), c, PATTERN_INDEX[pat])
    return im.transpose(Image.FLIP_LEFT_RIGHT) if mirror else im


def put_hero(sc, im, x, feet_y):
    sc.alpha_composite(im, (int(x) - 88, int(feet_y) - 96))


def put(sc, im, x, bottom, px=None):
    px = im.width // 2 if px is None else px
    sc.alpha_composite(im, (int(x - px), int(bottom - im.height)))


def terrain_tile(biome_atlas, i):
    a = asset("tiles/%s.png" % biome_atlas)
    return a.crop(((i % 8) * 32, (i // 8) * 32, (i % 8) * 32 + 32, (i // 8) * 32 + 32))


def biome_row(name):
    return ["jungle", "cave", "ice", "volcano", "feast", "village", "canyon", "swamp", "coast", "ruins",
            "sky"].index(name)


# ---------------------------------------------------------------------------------------------------- frames
def frames_sheet():
    blocks = []
    for rel in PHASE1:
        if "assets/" + rel not in REGISTRY:
            continue
        e = REGISTRY["assets/" + rel]
        cs = cells(rel)
        fw, fh = e["frame"]
        S = 1 if fh >= 160 or rel.endswith("rex_saddle.png") else 2
        if rel.endswith("rex_saddle.png"):                          # show the overlay on the rex it belongs to
            rex = asset("sprites/enemies/rex.png")
            base = [rex.crop(((i % 8) * 152, (i // 8) * 112, (i % 8) * 152 + 152, (i // 8) * 112 + 112))
                    for i in range(24)]
            cs = [b.copy() for b in base]
            for b, c in zip(cs, cells(rel)):
                b.alpha_composite(c)
        row_cells = []
        for i, c in enumerate(cs):
            t = Image.new("RGBA", c.size, (88, 98, 118, 255) if i % 2 else (78, 88, 108, 255))
            t.alpha_composite(c)
            row_cells.append(scale(t, S))
        per = max(1, 1800 // (fw * S + 4))
        if e.get("rows") and e["grid"][0] * (fw * S + 4) <= 1800:
            per = e["grid"][0]
        rows = [hstack(row_cells[i:i + per], 4, BG) for i in range(0, len(row_cells), per)]
        body = vstack(rows, 4, BG)
        head = Image.new("RGBA", (max(body.width, 700), 16), BG)
        label(head, "%s  %dx%d, cell %dx%d, grid %dx%d%s" % (rel, e["size"][0], e["size"][1], fw, fh, e["grid"][0],
                                                          e["grid"][1], ("  rows: " + ", ".join(e["rows"]))
                                                          if e.get("rows") else ""), 2, 2, (255, 255, 160, 255))
        blocks.append(vstack([head, body], 2, BG))
    return vstack(blocks, 10, BG)


# ---------------------------------------------------------------------------------------------------- scenes
def scene_gulch(P, sheets):
    sc = backdrop("canyon", x0=200)
    g = GROUND_Y
    vr = biome_row("canyon")
    vine = cells("sprites/objects/vine.png")

    def ledge(x0, x1, y):
        for x in range(x0, x1, 32):
            i = 0 if x == x0 else 2 if x + 32 >= x1 else 1
            sc.alpha_composite(terrain_tile("canyon/terrain", i), (x, y))
            sc.alpha_composite(terrain_tile("canyon/terrain", 16 if x == x0 else 18 if x + 32 >= x1 else 17),
                               (x, y + 32))
    # a ledge on the right; a 4-cell vine hangs from its left lip (anchor cell x 384-416, top = the ledge top)
    ledge(416, 640, 128)
    vx, vtop = 400, 128
    pieces = [vine[vr * 8 + 0], vine[vr * 8 + 1], vine[vr * 8 + 2], vine[vr * 8 + 3]]
    for k, pc in enumerate(pieces):
        sc.alpha_composite(pc, (vx - 16, vtop + 32 * k))
    put_hero(sc, hero(P, sheets, 1, 45), vx, vtop + 96)               # P1 climbing (frame 45)
    # a ledge on the left with a rolled vine at its right lip (anchor cell x 192-224, top 96)
    ledge(32, 192, 96)
    sc.alpha_composite(vine[vr * 8 + 4], (192, 96))
    # bark board in a mesa wall column (face right) with a spear step and P2 standing on it
    for y in range(g - 160, g, 32):
        sc.alpha_composite(terrain_tile("canyon/terrain_mesa", 10), (256, y))
    bark = cells("sprites/objects/bark_board.png")[vr * 3 + 2]
    by = g - 96
    sc.alpha_composite(bark, (256, by))
    spear = cells("sprites/fx/projectile_spear.png")[4].transpose(Image.FLIP_LEFT_RIGHT)   # thrown leftwards
    tip_x, tip_y = 72 - 1 - 60, 28                                       # frame 4 tip, mirrored
    sc.alpha_composite(spear, (288 - 6 - tip_x, by + 3 - tip_y))
    put_hero(sc, hero(P, sheets, 2, 0), 304, by)                         # the step's top = the board cell's top
    # mud geyser launching P3 to the jet's head, painting fragments on the ground
    gey = cells("sprites/objects/geyser.png")
    put(sc, gey[0 * 8 + 5], 560, g)
    put_hero(sc, hero(P, sheets, 3, 14), 560, g - 10 - 206)
    put(sc, cells("sprites/items/painting.png")[1], 96, g)
    put(sc, cells("sprites/items/painting.png")[7], 128, g)
    label(sc, "canyon vine (climb, rolled), bark board + spear step, mud geyser launch, painting new / found", 6, 4)
    return sc


def scene_fen(P, sheets):
    sc = backdrop("swamp", x0=100)
    bare = backdrop("swamp", x0=100, ground=False)
    g = GROUND_Y
    tar = asset("tiles/common/tar.png")
    tl = [tar.crop((i * 32, 0, i * 32 + 32, 32)) for i in range(8)]
    # tar pool x 160-352 (replace the ground there)
    for x in range(160, 352, 32):
        for y in (g, g + 32, g + 64):
            sc.paste(bare.crop((x, y, x + 32, y + 32)), (x, y))
    raft = cells("sprites/objects/raft.png")[0]
    sc.alpha_composite(raft, (256 - 64, g - 8))                        # floating: bottom 8 px under the pool top
    put_hero(sc, hero(P, sheets, 1, 0), 232, g - 8)
    put_hero(sc, hero(P, sheets, 2, 28), 284, g - 8)
    for k, x in enumerate(range(160, 352, 32)):
        sc.alpha_composite(tl[k % 6], (x, g))
        sc.alpha_composite(tl[6 if k != 3 else 7], (x, g + 32))
        sc.alpha_composite(tl[6], (x, g + 64))
    # tar floor x 0-128 with a wading hero (feet at the collision surface, 12 px under the cell top)
    fl = asset("tiles/common/tar_floor.png")
    ft = [fl.crop((i * 32, 0, i * 32 + 32, 32)) for i in range(4)]
    for k, x in enumerate(range(0, 128, 32)):
        sc.paste(bare.crop((x, g, x + 32, g + 32)), (x, g))
        sc.alpha_composite(ft[0 if k == 0 else 2 if k == 3 else 1], (x, g))
    put_hero(sc, hero(P, sheets, 3, 8), 64, g + 12)
    # deadly tar vent at the far right of the pool bank
    gey = cells("sprites/objects/geyser.png")
    put(sc, gey[4 * 8 + 5], 400, g)
    # Chomper on the raised ground with the saddle and two riders, his pen behind
    put(sc, asset("sprites/objects/rex_pen.png"), 512, g - 64)
    rx, ry = 512, g - 64
    rex = asset("sprites/enemies/rex.png").crop((0, 0, 152, 112))
    sad = asset("sprites/objects/rex_saddle.png").crop((0, 0, 152, 112))
    sc.alpha_composite(rex, (rx - 76, ry - 96))
    sc.alpha_composite(sad, (rx - 76, ry - 96))
    put_hero(sc, hero(P, sheets, 4, 21), rx - 28, ry - 52)
    put_hero(sc, hero(P, sheets, 2, 21), rx, ry - 52)
    label(sc, "tar pool + log raft, tar floor (wading), deadly tar vent, Chomper's saddle with driver + gunner, pen",
          6, 4)
    return sc


def liquids_sheet(P, sheets):
    pairs = [("tar", "swamp/terrain", "swamp"), ("honey", "feast/terrain", "feast"),
             ("syrup", "feast/terrain_icing", "feast"), ("water", "jungle/terrain", "jungle"),
             ("lava", "volcano/terrain", "volcano"), ("ice_water", "ice/terrain", "ice")]
    panels = []
    for liq, atlas, biome in pairs:
        W, H = 416, 160
        sc = Image.new("RGBA", (W, H), (120, 170, 220, 255))
        bd = backdrop(biome, x0=50).crop((0, 120, W, 120 + H))
        bare = backdrop(biome, x0=50, ground=False).crop((0, 120, W, 120 + H))
        sc.alpha_composite(bd)
        gy = 96
        for x in range(0, W, 32):
            sc.paste(bare.crop((x, gy, x + 32, gy + 64)), (x, gy))
            sc.alpha_composite(terrain_tile(atlas, 9), (x, gy + 32))
        fl = asset("tiles/common/%s_floor.png" % liq)
        ft = [fl.crop((i * 32, 0, i * 32 + 32, 32)) for i in range(4)]
        for x in range(0, 32 * 3, 32):
            sc.alpha_composite(terrain_tile(atlas, 1), (x, gy))
        for k, x in enumerate(range(96, 224, 32)):
            sc.alpha_composite(ft[0 if k == 0 else 2 if k == 3 else 1], (x, gy))
        sc.alpha_composite(ft[3], (128, gy + 32))
        sc.alpha_composite(terrain_tile(atlas, 1), (224, gy))
        put_hero(sc, hero(P, sheets, 1, 0), 160, gy + 12)
        strip_ = asset("tiles/common/%s.png" % liq)
        for k, x in enumerate(range(256, W, 32)):
            sc.alpha_composite(strip_.crop(((k % 6) * 32, 0, (k % 6) * 32 + 32, 32)), (x, gy))
            sc.alpha_composite(strip_.crop((6 * 32 if k % 3 else 7 * 32, 0, 6 * 32 + 32 if k % 3 else 8 * 32, 32)),
                               (x, gy + 32))
        label(sc, "%s: ':' floor on %s, `~` pool" % (liq, atlas), 4, 2)
        panels.append(sc)
    rows = [hstack(panels[i:i + 2], 4, BG) for i in range(0, len(panels), 2)]
    return vstack(rows, 4, BG)


def versus_scene(P, sheets):
    sc = backdrop("jungle", x0=0)
    g = GROUND_Y
    # the totem: carved stone column (ruins/terrain_carved) cols 288-352, 6 rows up from the floor, cookpot on top
    for k, y in enumerate(range(g - 192, g, 32)):
        sc.alpha_composite(terrain_tile("ruins/terrain_carved", 0 if k == 0 else 8), (288, y))
        sc.alpha_composite(terrain_tile("ruins/terrain_carved", 2 if k == 0 else 10), (320, y))
    pot = cells("sprites/objects/cookpot.png")
    top = g - 192
    put(sc, pot[5], 320, top)                                        # back, banking
    put_hero(sc, hero(P, sheets, 3, 21), 320, top)                   # P3 crouches in the pot
    put(sc, pot[10 + 5], 320, top)                                   # front
    # P1 with a tall stack and the crown, P2 with a small one
    food = cells("ui/stack_food.png")
    crown = cells("ui/crown.png")

    def tower(x, head_y, pics):
        y = head_y + 4
        for p in pics:
            put(sc, food[p], x, y)
            y -= 14
        put(sc, crown[1], x, y + 2)
    put_hero(sc, hero(P, sheets, 1, 0), 120, g)
    tower(120, g - 57, [3, 3, 2, 1, 1, 0, 0])
    put_hero(sc, hero(P, sheets, 2, 8, mirror=True), 500, g)
    y = g - 57 + 4
    for p in (1, 0, 0):
        put(sc, food[p], 500, y)
        y -= 14
    # spawn pads: P4's lit (respawning), one idle, one neutral; the Golden Drumstick
    sp = cells("sprites/objects/spawn_point.png")
    put(sc, sp[4], 210, g)
    put(sc, sp[0], 420, g)
    put(sc, sp[5], 590, g)
    put(sc, cells("sprites/items/golden_drumstick.png")[1], 250, g)
    label(sc, "Grub Stack: cookpot (P3 banking inside), stack towers + crown, spawn pads (P4 lit), Golden Drumstick",
          6, 4)
    return sc


def build():
    P = Palettes()
    sheets = {"hero": asset("sprites/player/hero.png")}
    save_doc(frames_sheet(), "book2_objects.png")
    save_doc(scale(scene_gulch(P, sheets), 2), "book2_scene_gulch.png")
    save_doc(scale(scene_fen(P, sheets), 2), "book2_scene_fen.png")
    save_doc(scale(liquids_sheet(P, sheets), 2), "liquids_tar_floor.png")
    save_doc(scale(versus_scene(P, sheets), 2), "versus_totem_ring.png")


if __name__ == "__main__":
    from xcommon import load_registry
    load_registry()
    build()

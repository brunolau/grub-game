"""Proof sheets of the phase-2 art (docs/art/expansion/, never shipped): the map page as the game shows it, the
paintings (slab, mural, pictures, unlock icons), the versus HUD / screens, the Feast Land D / E scenes and the world
6-9 object skins. Everything is composed from the files under assets/ exactly as their manifest rows describe (cells,
pivots, rows), so a sheet that looks right is also a check of those numbers.
"""
import numpy as np
from PIL import Image, ImageDraw

from backdrops import GROUND_Y, backdrop
from build_hero_palettes import PATTERN_INDEX, SLOT_DEFAULT, Palettes, frame, label
from build_previews_b2 import cells, put, put_hero, terrain_tile
from xcommon import REGISTRY, asset, canvas, hstack, save_doc, scale, vstack

BG = (58, 66, 84, 255)
# phase-2 files shown on these sheets (build_previews.py's frames sheet leaves them out)
PHASE2 = {"ui/world_map_far_shore.png", "ui/painting_slab.png", "ui/mural.png", "ui/paintings.png",
          "ui/unlock_icons.png", "ui/portraits.png", "ui/portrait_heads.png", "ui/sundial.png", "ui/sundial_rush.png", "ui/medals.png",
          "ui/versus_plate.png", "ui/cave_wall.png", "ui/cave_paint_heroes.png", "sprites/fx/hit_stars_players.png",
          "sprites/objects/platform_cloud.png", "sprites/objects/platform_driftwood.png",
          "sprites/objects/spring_cap.png", "sprites/objects/drum_cap.png", "sprites/objects/coconut.png",
          "ui/player_tags.png",
          "ui/player_arrows.png", "sprites/objects/spawn_point.png"}


def is_phase2(key):
    rel = key[len("assets/"):] if key.startswith("assets/") else key
    return rel in PHASE2 or rel.startswith("tiles/feast/")


COLOURS = ["yellow", "blue", "pink", "green", "white", "gold"]
INK, CREAM, GOLD = (39, 32, 24, 255), (255, 248, 220, 255), (255, 233, 79, 255)


def hero_c(P, sheet, colour, pattern, f, mirror=False):
    im = P.apply(frame(sheet, f), colour, PATTERN_INDEX[pattern])
    return im.transpose(Image.FLIP_LEFT_RIGHT) if mirror else im


# ---------------------------------------------------------------------------------------------------- map page
def map_page(P, sheet):
    """the Far Shore page with the route, the markers and number plates drawn the way world_map.gd draws them, P1 and
    P2 on 9-2, and the painting slab as screen UI in the lower-right corner of the right-hand view"""
    m = asset("ui/world_map_far_shore.png").copy()
    d = ImageDraw.Draw(m)
    mk = REGISTRY["assets/ui/world_map_far_shore.png"]["markers"]
    pts = [tuple(v) for _, v in sorted(mk.items())]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        n = max(1, int(np.hypot(bx - ax, by - ay) / 9))
        for k in range(1, n):
            x, y = round(ax + (bx - ax) * k / n), round(ay + (by - ay) * k / n)
            d.rectangle((x - 2, y - 2, x + 1, y + 1), fill=INK)
            d.rectangle((x - 1, y - 1, x, y), fill=CREAM)
    for name, (x, y) in sorted(mk.items()):
        d.ellipse((x - 10, y - 10, x + 10, y + 10), fill=INK)
        d.ellipse((x - 8, y - 8, x + 8, y + 8), fill=GOLD if name < "8" else CREAM)
        d.rectangle((x - 12, y + 12, x + 12, y + 24), fill=INK)
        d.text((x - 9, y + 12), name, fill=CREAM)
    x, y = mk["9-2"]
    m.alpha_composite(hero_c(P, sheet, "blue", "stripes", 0), (x - 30 - 88, y - 96))
    m.alpha_composite(hero_c(P, sheet, "yellow", "spots", 0), (x - 88, y - 96))
    view = m.crop((640, 0, 1280, 360))
    slab = slab_state(17, 3)
    view.alpha_composite(slab, (640 - slab.width - 8, 360 - slab.height - 8))
    label(m, "ui/world_map_far_shore.png with the 11 map stops (`markers`), route and plates drawn as world_map.gd", 6, 4)
    label(view, "the right-hand view: P1 + P2 on 9-2, the slab as screen UI (17 paintings, 3 rewards)", 6, 4)
    return vstack([m, hstack([view, m.crop((0, 0, 640, 360))], 4, BG)], 4, BG)


# ---------------------------------------------------------------------------------------------------- paintings
def slab_state(found, rewards):
    e = REGISTRY["assets/ui/painting_slab.png"]
    slab = asset("ui/painting_slab.png").copy()
    mural = asset("ui/mural.png")
    pw, ph = REGISTRY["assets/ui/mural.png"]["pieces"]["size"]
    mx, my = e["mural_at"]
    order = list(np.random.RandomState(4).permutation(30))[:found]
    for i in order:
        px, py = (i % 6) * pw, (i // 6) * ph
        slab.alpha_composite(mural.crop((px, py, px + pw, py + ph)), (mx + px, my + py))
    icons = asset("ui/unlock_icons.png")
    for k in range(rewards):
        ix, iy = e["icons"][k]
        slab.alpha_composite(icons.crop((k * 24, 24, k * 24 + 24, 48)), (ix, iy))
    px, py, pw_, ph_ = e["plate"]
    ImageDraw.Draw(slab).text((px + 8, py + 1), "%d/30" % found, fill=CREAM)
    return slab


def paintings_sheet():
    empty, part, full = slab_state(0, 0), slab_state(17, 3), slab_state(30, 6)
    row1 = hstack([scale(empty, 2), scale(part, 2), scale(full, 2)], 8, BG)
    mural = scale(asset("ui/mural.png"), 3)
    pics = asset("ui/paintings.png")
    stone = Image.new("RGBA", (10 * 36, 3 * 36), (235, 182, 120, 255))
    for i in range(30):
        stone.alpha_composite(pics.crop((i * 32, 0, i * 32 + 32, 32)), ((i % 10) * 36 + 2, (i // 10) * 36 + 2))
    row2 = hstack([mural, scale(stone, 2)], 8, BG)
    row3 = scale(asset("ui/unlock_icons.png"), 4)
    out = vstack([row1, row2, row3], 8, BG)
    label(out, "slab empty / 17 found + 3 rewards / complete; the mural at 3x; ui/paintings.png 0-29 on stone; unlock "
               "icons (locked, unlocked)", 6, 4)
    return out


# ---------------------------------------------------------------------------------------------------- versus
def versus_hud(P, sheet):
    """the Totem Ring backdrop with the four corner panels (heads, stack / pot counts, crown), the sundial with a
    shadow wedge, tags over two overlapping heroes (P4 in white: green arena swap), hit sparks in two colours"""
    sc = backdrop("jungle", x0=0)
    g = GROUND_Y
    heads = cells("ui/portrait_heads.png")                         # row = colour, column = expression
    food = cells("ui/stack_food.png")
    crown = cells("ui/crown.png")
    looks = [("yellow", "spots"), ("blue", "stripes"), ("pink", "zigzag"), ("white", "plain")]
    corners = [(8, 8, False), (640 - 148, 8, True), (8, 360 - 58, False), (640 - 148, 360 - 58, True)]
    stacks = [7, 3, 0, 5]
    for k, ((c, pat), (x, y, mir)) in enumerate(zip(looks, corners)):
        panel = Image.new("RGBA", (140, 50), (39, 32, 24, 200))
        expr = 2 if k == 0 else 1 if k == 2 else 0
        ci = COLOURS.index(c)
        hd = heads[ci * 3 + expr]
        panel.alpha_composite(hd if not mir else hd.transpose(Image.FLIP_LEFT_RIGHT),
                              (140 - 4 - hd.width if mir else 4, 50 - hd.height))
        fx = 10 if mir else 56
        panel.alpha_composite(food[3], (fx, 2))
        panel.alpha_composite(food[4], (fx + 40, 2))
        dd = ImageDraw.Draw(panel)
        dd.text((fx + 10, 32), str(stacks[k]), fill=CREAM)
        dd.text((fx + 50, 32), str(k), fill=CREAM)
        sc.alpha_composite(panel, (x, y))
        if k == 0:
            sc.alpha_composite(crown[0], (x + 8, y + 40))
    dial = cells("ui/sundial.png")
    dx, dy = 320 - 14, 4
    sc.alpha_composite(dial[19], (dx, dy))                           # 19 / 31 of the round has run
    ImageDraw.Draw(sc).text((dx + 32, dy + 8), "0:34", fill=CREAM)
    tags = asset("ui/player_tags.png")
    for k, (c, pat), x in ((0, looks[0], 250), (3, looks[3], 300)):
        put_hero(sc, hero_c(P, sheet, c, pat, 0 if k == 0 else 8, mirror=k == 3), x, g)
        row = 1 + COLOURS.index(c)
        cell = tags.crop((k * 32, row * 48, k * 32 + 32, row * 48 + 48))
        sc.alpha_composite(cell, (x - 16, g - 70 - 48))
    sp = asset("sprites/fx/hit_stars_players.png")
    for (c, x) in (("blue", 420), ("pink", 470)):
        r = COLOURS.index(c)
        sc.alpha_composite(sp.crop((3 * 40, r * 41, 4 * 40, r * 41 + 41)), (x - 20, g - 50))
    label(sc, "versus HUD: corner heads (P1 cheer + crown, P3 ouch), sundial 62 % run, tags by colour row (P4 white), "
              "hit sparks blue / pink", 6, 344)
    return sc


def versus_results(P, sheet):
    sc = asset("ui/cave_wall.png").copy()
    painted = asset("ui/cave_paint_heroes.png")
    portraits = asset("ui/portraits.png")
    medals = asset("ui/medals.png")
    plates = asset("ui/versus_plate.png")
    food = cells("ui/stack_food.png")
    looks = ["yellow", "blue", "pink", "white"]
    for k, c in enumerate(looks):
        ci = COLOURS.index(c)
        col = 0 if k == 0 else 2
        fig = painted.crop((col * 176, ci * 112, col * 176 + 176, ci * 112 + 112))
        x = 80 + k * 160
        sc.alpha_composite(fig, (x - 88, 150 - 96 - (12 if k == 0 else 0)))
        p = portraits.crop(((2 if k == 0 else 0) * 80, ci * 80, (2 if k == 0 else 0) * 80 + 80, ci * 80 + 80))
        sc.alpha_composite(p, (x - 40, 170))
        pl = plates.crop((0, ci * 16, 96, ci * 16 + 16))
        sc.alpha_composite(pl, (x - 48, 262))
        for w in range(3 if k == 0 else k % 2 + 1):
            put(sc, food[5], x - 24 + w * 16, 262 + 6 + 4)
        for j in range(2 if k else 3):
            idx = (k * 3 + j) % 19
            ribbon = Image.new("RGBA", (12, 14), tuple(np.array(asset("sprites/player/palettes/hero_lut_%s.png" % c))[0, 0]))
            sc.alpha_composite(ribbon, (x - 50 + j * 36 + 10, 300))
            sc.alpha_composite(medals.crop((idx * 32, 0, idx * 32 + 32, 32)), (x - 50 + j * 36, 306))
    label(sc, "results: cave wall + painted heroes (winner cheering), portraits, plates with drumsticks, medals on "
              "colour ribbons", 6, 4)
    return sc


def versus_sheet(P, sheet):
    top = hstack([versus_hud(P, sheet), versus_results(P, sheet)], 4, BG)
    pics = hstack([scale(asset("ui/portraits.png"), 1), scale(asset("ui/portrait_heads.png"), 2),
                   scale(asset("ui/sundial.png"), 2), scale(asset("ui/sundial_rush.png"), 2), scale(asset("ui/versus_plate.png"), 2),
                   scale(asset("ui/player_tags.png"), 1), scale(asset("ui/player_arrows.png"), 1)], 8, BG)
    bottom = vstack([pics, scale(asset("ui/medals.png"), 2), asset("sprites/fx/hit_stars_players.png"),
                     scale(asset("sprites/objects/spawn_point.png"), 2)], 8, BG)
    return vstack([top, bottom], 6, BG)


# ---------------------------------------------------------------------------------------------------- feast
def feast_scene(P, sheet, kind):
    sc = backdrop("feast", x0=40 if kind == "d" else 200, ground=False)
    g = GROUND_Y
    atlas = "feast/terrain_honeycomb" if kind == "d" else "feast/terrain_pudding"
    liq = "honey" if kind == "d" else "syrup"
    # ground left (x 0-224) and right (x 448-640), the liquid between, a raised block on the right
    for x in list(range(0, 224, 32)) + list(range(448, 640, 32)):
        t = 0 if x in (0, 448) else 2 if x in (192, 608) else 1
        sc.alpha_composite(terrain_tile(atlas, t), (x, g))
        sc.alpha_composite(terrain_tile(atlas, 9), (x, g + 32))
        sc.alpha_composite(terrain_tile(atlas, 9), (x, g + 64))
    strip_ = asset("tiles/common/%s.png" % liq)
    for k, x in enumerate(range(224, 448, 32)):
        sc.alpha_composite(strip_.crop(((k % 6) * 32, 0, (k % 6) * 32 + 32, 32)), (x, g))
        for y in (g + 32, g + 64):
            sc.alpha_composite(strip_.crop((6 * 32, 0, 7 * 32, 32)), (x, y))
    for i, t in enumerate([0, 1, 2]):
        sc.alpha_composite(terrain_tile(atlas, t), (512 + i * 32, g - 96))
        for r in (1, 2):
            sc.alpha_composite(terrain_tile(atlas, [8, 9, 10][i]), (512 + i * 32, g - 96 + 32 * r))
    props = lambda n: asset("tiles/feast/props/%s.png" % n)
    if kind == "d":
        fl = asset("tiles/common/honey_floor.png")
        for k, x in enumerate(range(64, 192, 32)):
            sc.alpha_composite(fl.crop(((0 if k == 0 else 2 if k == 3 else 1) * 32, 0, (0 if k == 0 else 2 if k == 3
                                                                                       else 1) * 32 + 32, 32)), (x, g))
        put_hero(sc, hero_c(P, sheet, "yellow", "spots", 8), 128, g + 12)
        gey = cells("sprites/objects/geyser.png")
        put(sc, gey[3 * 8 + 5], 480, g)
        put(sc, props("comb_chunk"), 30, g)
        put(sc, props("honey_pot"), 590, g)
        sc.alpha_composite(props("honey_drips_a"), (514, g - 96 + 96))
        sc.alpha_composite(props("honey_drips_b"), (560, g - 96 + 96))
        put(sc, props("jelly_pink"), 545, g - 96)
        label(sc, "Feast Land D Honey Falls: honeycomb terrain, honey ':' floor (wading), honey pool, soda geyser, "
                  "comb chunk, honey pot, drips, jelly", 6, 4)
    else:
        raft = cells("sprites/objects/raft.png")[3]
        sc.alpha_composite(raft, (336 - 64, g - 8))
        put_hero(sc, hero_c(P, sheet, "yellow", "spots", 0), 316, g - 8)
        put_hero(sc, hero_c(P, sheet, "blue", "stripes", 0, True), 356, g - 8)
        put(sc, props("pudding"), 60, g)
        put(sc, props("cherries"), 150, g)
        put(sc, props("cream_swirl"), 545, g - 96)
        put(sc, props("wafer_sticks"), 600, g - 96)
        put(sc, props("jelly_green"), 470, g)
        label(sc, "Feast Land E Pudding Lagoon: pudding terrain, syrup current, wafer raft, flan, cherries, cream, "
                  "wafer sticks, jelly", 6, 4)
    return sc


def feast_sheet(P, sheet):
    tiles = hstack([scale(asset("tiles/feast/terrain_honeycomb.png"), 2),
                    scale(asset("tiles/feast/terrain_pudding.png"), 2)], 8, BG)
    names = [k.split("/")[-1][:-4] for k in sorted(REGISTRY) if k.startswith("assets/tiles/feast/props/")]
    props = hstack([scale(asset("tiles/feast/props/%s.png" % n), 2) for n in names], 8, BG)
    return vstack([hstack([feast_scene(P, sheet, "d"), feast_scene(P, sheet, "e")], 4, BG), tiles, props], 6, BG)


# ---------------------------------------------------------------------------------------------------- world objects
def world_objects_sheet(P, sheet):
    out = []
    for biome, name in (("sky", "platform_cloud"), ("coast", "platform_driftwood")):
        sc = backdrop(biome, x0=0, ground=True).crop((0, 120, 320, 300))
        pl = asset("sprites/objects/%s.png" % name)
        sc.alpha_composite(pl, (112, 90))
        put_hero(sc, hero_c(P, sheet, "yellow", "spots", 0), 160, 90)
        label(sc, name, 4, 2)
        out.append(sc)
    dark = backdrop("swamp", x0=0, ground=True).crop((0, 120, 320, 300))
    shade = Image.new("RGBA", dark.size, (10, 12, 20, 150))
    dark.alpha_composite(shade)
    sp = cells("sprites/objects/spring_cap.png")
    dm = cells("sprites/objects/drum_cap.png")
    for k, f in enumerate(sp):
        put(dark, f, 40 + k * 60, 170)
    for k, f in enumerate(dm):
        put(dark, f, 30 + k * 50, 110)
    nut = cells("sprites/objects/coconut.png")
    for k, f in enumerate(nut):
        dark.alpha_composite(f, (210 + (k % 4) * 26, 4 + (k // 4) * 30))
    label(dark, "spring_cap 0-4, drum_cap 0-4 (3-4 lit) in the dark; coconut roll", 4, 2)
    out.append(dark)
    return scale(hstack(out, 4, BG), 2)


def build():
    P = Palettes()
    sheet = asset("sprites/player/hero.png")
    save_doc(map_page(P, sheet), "far_shore_map.png")
    save_doc(paintings_sheet(), "paintings_slab_mural.png")
    save_doc(versus_sheet(P, sheet), "versus_screens.png")
    save_doc(scale(feast_sheet(P, sheet), 1), "feast_d_e.png")
    save_doc(world_objects_sheet(P, sheet), "world_objects_p2.png")


if __name__ == "__main__":
    from xcommon import load_registry
    load_registry()
    build()

"""Mock gameplay screenshots (docs/art/mock_<biome>.png), composed only from the files under assets/.

Each mock is rendered at the base viewport (640 x 360 art px = 320 x 180 logical px) and saved 4x
nearest-neighbour.  A 2x copy is written to the temp folder for quick review.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *  # noqa

REG = json.load(open(REG_PATH, encoding="utf-8"))
OUT = os.path.join(ROOT, "docs", "art")
W, H = VIEW
COLS, ROWS = 20, 12                      # 12th row is cut by the 360 px viewport (11.25 rows visible)

# terrain atlas indices (see TERRAIN_TILES in build_tiles.py)
TL, T, TR, CAPL, CAPR, S45R, S45L, BLOCK = range(8)
L, FILL, R, GRL, GRH, GLH, GLL, INSET = range(8, 16)
BL, B, BR, U45R, U45L, UGRL, UGRH, FILLB = range(16, 24)
UGLH, UGLL, BB, OWL, OWM, OWR, HGL, HGM = range(24, 32)
HGR, HCAP, SMALL, BACK, BACKA, BACKB, SPIKE, SPIKEC = range(32, 40)


def A(rel):
    return load(os.path.join(ASSETS, *rel.split("/")))


def frame(rel, idx):
    m = REG["assets/" + rel]; fw, fh = m["frame"]; cols = m["grid"][0]
    im = A(rel)
    return im.crop(((idx % cols) * fw, (idx // cols) * fh, (idx % cols + 1) * fw, (idx // cols + 1) * fh)), m


def put_actor(scene, rel, idx, x, y, face=1):
    """Draw an actor frame with its pivot (feet) at scene position (x, y)."""
    f, m = frame(rel, idx)
    px, py = m["pivot"]
    if face < 0:
        f = flip(f); px = m["frame"][0] - px
    return over(scene, f, (x - px, y - py))


def put_prop(scene, rel, x, y, face=1, anchor="bottom"):
    im = A(rel)
    if face < 0:
        im = flip(im)
    if anchor == "bottom":
        return over(scene, im, (x - im.width // 2, y - im.height))
    if anchor == "top":
        return over(scene, im, (x - im.width // 2, y))
    return over(scene, im, (x, y))


def tile(atlas, i):
    return atlas.crop(((i % 8) * 32, (i // 8) * 32, (i % 8) * 32 + 32, (i // 8) * 32 + 32))


def auto(solid, overrides=None):
    """Boolean grid -> atlas indices (no slopes; add those through overrides)."""
    rows = len(solid); cols = len(solid[0])
    def s(x, y):
        if x < 0 or x >= cols:
            return True
        if y < 0:
            return False
        if y >= rows:
            return True
        return solid[y][x]
    out = [[-1] * cols for _ in range(rows)]
    for y in range(rows):
        for x in range(cols):
            if not solid[y][x]:
                continue
            up, dn, lf, rt = s(x, y - 1), s(x, y + 1), s(x - 1, y), s(x + 1, y)
            if not up:
                v = TL if not lf else (TR if not rt else T)
            elif not dn:
                v = BL if not lf else (BR if not rt else B)
            else:
                v = L if not lf else (R if not rt else (FILLB if (x * 7 + y * 13) % 11 == 0 else FILL))
            out[y][x] = v
    for (x, y), v in (overrides or {}).items():
        out[y][x] = v
    return out


def paint(scene, atlas, grid, oy=0):
    for y, row in enumerate(grid):
        for x, v in enumerate(row):
            if v is not None and v >= 0:
                scene.alpha_composite(tile(atlas, v), (x * 32, y * 32 + oy))


def grid_from(lines):
    return [[c == "#" for c in ln.ljust(COLS, ".")[:COLS]] for ln in lines]


def backdrop(biome, names, cam_x=260):
    scene = canvas(W, H, (0, 0, 0, 255))
    for n in names:
        rel = "backgrounds/%s/%s.png" % (biome, n)
        im = A(rel); f = REG["assets/" + rel]["scroll"]
        off = int(cam_x * f) % im.width
        strip_ = canvas(W, H)
        strip_ = over(strip_, im, (-off, 0)); strip_ = over(strip_, im, (im.width - off, 0))
        scene.alpha_composite(strip_)
    return scene


def text(scene, s, x, y):
    font = A("fonts/font_hud.png")
    for i, ch in enumerate(s):
        k = ord(ch) - 32
        g = font.crop(((k % 15) * 20, (k // 15) * 20, (k % 15) * 20 + 20, (k // 15) * 20 + 20))
        scene.alpha_composite(g, (x + i * 16, y))
    return scene


def hud(scene, lives=2, score="0012340", hearts=3, letters="GR..S", boss=None):
    scene.alpha_composite(A("ui/hud_lives_icon.png"), (8, 6))
    text(scene, "x%d" % lives, 58, 16)
    text(scene, score, 112, 16)
    hs = A("ui/hud_heart.png")
    for i in range(3):
        scene.alpha_composite(hs.crop((0 if i < hearts else 32, 0, 32 if i < hearts else 64, 32)), (270 + i * 34, 8))
    lt = A("sprites/items/letters.png")
    for i, ch in enumerate("GRUBS"):
        g = lt.crop((i * 40, 0, i * 40 + 40, 40))
        if letters[i] == ".":
            g = remap(g, lambda r, gg, b: (r, gg, b) if (r, gg, b) == (39, 32, 24) else (70, 58, 48))
            a = np.array(g); a[..., 3] = (a[..., 3] * 0.55).astype(np.uint8); g = Image.fromarray(a, "RGBA")
        scene.alpha_composite(g, (430 + i * 40, 4 + (2, 6, 0, 4, 1)[i]))
    if boss is not None:
        pip = A("ui/hud_boss_pip.png")
        for i in range(8):
            scene.alpha_composite(pip.crop((0 if i < boss else 16, 0, 16 if i < boss else 32, 16)), (10 + i * 18, H - 26))
    return scene


def food(scene, idx, x, y, rel="sprites/items/food.png"):
    f, m = frame(rel, idx)
    return over(scene, f, (x - m["pivot"][0], y - m["pivot"][1]))


def finish(scene, name):
    scale(scene, 4).save(os.path.join(OUT, "mock_%s.png" % name))
    scale(scene, 2).save(os.path.join(os.environ.get("TEMP", "."), "cs", "mock_%s_2x.png" % name))
    print("mock", name)


# ----------------------------------------------------------------------------- scenes
def jungle():
    sc = backdrop("jungle", ["layer0_sky", "layer1_far_hills", "layer2_hills", "layer3_forest"])
    atlas = A("tiles/jungle/terrain.png")
    lines = ["....................",
             "....................",
             "....................",
             "....................",
             "....................",
             "....................",
             "....................",
             "..............######",
             "####################",
             "####################",
             "####################",
             "####################"]
    g = auto(grid_from(lines), {(12, 7): GRL, (13, 7): GRH, (12, 8): UGRL, (13, 8): UGRH, (14, 7): T, (5, 9): INSET})
    # back props
    sc = put_prop(sc, "tiles/jungle/props/tree_trunk.png", 540, 7 * 32 + 4)
    sc = put_prop(sc, "tiles/jungle/props/tree_canopy_light.png", 540, 7 * 32 - 40)
    sc = put_prop(sc, "tiles/jungle/props/bush_big.png", 110, 8 * 32 + 4)
    sc = put_prop(sc, "tiles/jungle/props/vine_b.png", 610, 0, anchor="top")
    sc = put_prop(sc, "tiles/jungle/props/vine_a.png", 30, 40, anchor="top")
    paint(sc, atlas, g)
    for x, v in ((5, OWL), (6, OWM), (7, OWR)):
        sc.alpha_composite(tile(atlas, v), (x * 32, 5 * 32))
    f, m = frame("sprites/objects/checkpoint.png", 2); sc = over(sc, f, (20, 8 * 32 - 55 + 2))
    sc = put_prop(sc, "tiles/jungle/props/grass_a.png", 130, 8 * 32 + 3); sc = put_prop(sc, "tiles/jungle/props/flower.png", 250, 8 * 32 + 2)
    sc = put_prop(sc, "tiles/jungle/props/fern.png", 600, 7 * 32 + 3)
    sc = put_actor(sc, "sprites/enemies/turtle.png", 6, 335, 8 * 32)
    sc = put_actor(sc, "sprites/enemies/plant.png", 2, 490, 7 * 32, -1)
    sc = put_actor(sc, "sprites/enemies/pterodactyl.png", 1, 420, 150, -1)
    sc = put_actor(sc, "sprites/player/hero.png", 29, 190, 8 * 32)
    sc = food(sc, 27, 190, 5 * 32 - 6); sc = food(sc, 0, 222, 5 * 32 - 2); sc = food(sc, 21, 254, 5 * 32 - 6)
    sc = food(sc, 40, 310, 8 * 32 - 50); sc = food(sc, 0, 590, 7 * 32 - 50, "sprites/items/treasure.png")
    f, m = frame("sprites/fx/star_puff.png", 2); sc = over(sc, f, (285, 8 * 32 - 62))
    hud(sc)
    finish(sc, "jungle")


def cave():
    sc = backdrop("cave", ["layer0_wall", "layer1_rocks_far", "layer2_ceiling_near"])
    atlas = A("tiles/cave/terrain.png")
    lines = ["####################",
             "#####..........#####",
             "....................",
             "....................",
             "....................",
             "....................",
             "................####",
             "####............####",
             "####...####.....####",
             "########################"[:20],
             "####################",
             "####################"]
    solid = grid_from(lines)
    for x in range(4, 7):
        solid[9][x] = False; solid[10][x] = False
    g = auto(solid)
    water = A("tiles/common/water.png")
    for x in range(4, 7):
        sc.alpha_composite(water.crop(((x % 3) * 32, 0, (x % 3) * 32 + 32, 32)), (x * 32, 9 * 32 - 6))
        sc.alpha_composite(water.crop((6 * 32, 0, 7 * 32, 32)), (x * 32, 10 * 32 - 6))
        sc.alpha_composite(water.crop((6 * 32, 0, 7 * 32, 32)), (x * 32, 11 * 32 - 6))
    for x in range(15, 20):
        for y in range(2, 6):
            sc.alpha_composite(tile(atlas, BACKA if (x, y) == (16, 3) else BACKB if (x, y) == (18, 4) else BACK), (x * 32, y * 32))
    sc = put_prop(sc, "tiles/cave/props/cave_hole_b.png", 560, 6 * 32)
    paint(sc, atlas, g)
    for x, y in ((6, 2), (9, 2), (13, 2)):
        sc = put_prop(sc, "tiles/cave/props/stalactite.png", x * 32 + 16, 2 * 32 - 2, anchor="top")
    sc = put_prop(sc, "tiles/cave/props/crystal_violet_b.png", 310, 8 * 32 + 2); sc = put_prop(sc, "tiles/cave/props/crystal_cyan_a.png", 336, 8 * 32 + 2)
    sc = put_prop(sc, "tiles/cave/props/crystal_cyan_c.png", 610, 6 * 32 + 2)
    sc = put_prop(sc, "tiles/cave/props/skull_buried.png", 440, 9 * 32 + 2); sc = put_prop(sc, "tiles/cave/props/mushrooms.png", 40, 7 * 32 + 2)
    f, m = frame("sprites/objects/breakable_block_cave.png", 0); sc = over(sc, f, (12 * 32 - 3, 8 * 32))
    f, m = frame("sprites/objects/breakable_block_cave.png", 2); sc = over(sc, f, (13 * 32 - 3, 8 * 32))
    f, m = frame("sprites/enemies/bat.png", 13); b_ = bbox(f); sc = over(sc, f, (370 - m["pivot"][0], 2 * 32 - 2 - b_[1]))
    sc = put_actor(sc, "sprites/enemies/bat.png", 1, 250, 150)
    sc = put_actor(sc, "sprites/enemies/insect.png", 3, 540, 6 * 32, -1)
    sc = put_actor(sc, "sprites/enemies/lizard.png", 14, 300, 8 * 32, -1)
    sc = put_actor(sc, "sprites/player/hero.png", 15, 100, 7 * 32 - 30)
    for i, x in enumerate((150, 176, 204)):
        f, m = frame("sprites/items/bone.png", i); sc = over(sc, f, (x, 150 - i * 14))
    sc = food(sc, 3, 330, 8 * 32 - 56, "sprites/items/treasure.png"); sc = food(sc, 36, 590, 6 * 32 - 44)
    hud(sc, hearts=2, score="0048700", letters="G.U..")
    finish(sc, "cave")


def ice():
    sc = backdrop("ice", ["layer0_sky", "layer1_far_peaks", "layer2_ridges", "layer3_snow_forest"])
    atlas = A("tiles/ice/terrain.png"); rock = A("tiles/ice/terrain_rock.png")
    lines = ["....................",
             "....................",
             "....................",
             "....................",
             "....................",
             "######..............",
             "######..............",
             "######..............",
             "######......########",
             "######......########",
             "####################",
             "####################"]
    solid = grid_from(lines)
    g = auto(solid)
    # gentle slope down from the plateau (x 6..9) to the valley floor at row 10
    g[8][6] = GLH; g[8][7] = GLL; g[9][6] = UGLH; g[9][7] = UGLL
    g[9][8] = GLH; g[9][9] = GLL; g[10][8] = UGLH; g[10][9] = UGLL
    g[10][10] = T; g[10][11] = T; g[9][12] = L; g[8][12] = TL; g[10][12] = FILL; g[10][6] = FILL; g[10][7] = FILL
    sc = put_prop(sc, "tiles/ice/props/tree_trunk.png", 80, 5 * 32 + 4); sc = put_prop(sc, "tiles/ice/props/tree_canopy_dark.png", 80, 5 * 32 - 40)
    sc = put_prop(sc, "tiles/ice/props/dead_tree.png", 560, 8 * 32 + 4)
    paint(sc, atlas, g)
    sc.alpha_composite(tile(atlas, SPIKE), (10 * 32, 9 * 32)); sc.alpha_composite(tile(atlas, SPIKE), (11 * 32, 9 * 32))
    sc = put_prop(sc, "sprites/objects/platform_ice.png", 12 * 32 - 16, 6 * 32, anchor="top")
    sc = put_prop(sc, "tiles/ice/props/crystal_ice_b.png", 500, 8 * 32 + 2); sc = put_prop(sc, "tiles/ice/props/bush_big.png", 150, 5 * 32 + 3)
    sc = put_prop(sc, "tiles/ice/props/rock_big.png", 610, 8 * 32 + 3)
    sc = put_actor(sc, "sprites/enemies/mini_rex_b.png", 7, 450, 8 * 32, -1)
    sc = put_actor(sc, "sprites/enemies/turtle_b.png", 5, 250, 8 * 32 + 22, -1)
    sc = put_actor(sc, "sprites/enemies/pterodactyl_b.png", 7, 300, 110, -1)
    sc = put_actor(sc, "sprites/player/hero.png", 9, 130, 5 * 32)
    sc = food(sc, 19, 350, 6 * 32 - 8); sc = food(sc, 18, 390, 6 * 32 - 4); sc = food(sc, 8, 420, 8 * 32 - 60, "sprites/items/treasure.png")
    f, m = frame("sprites/items/pickups.png", 0); sc = over(sc, f, (560, 8 * 32 - 80))
    snow = A("sprites/fx/particles_snow.png")
    rng = np.random.RandomState(7)
    for _ in range(46):
        k = rng.randint(0, 6); x, y = rng.randint(0, W - 20), rng.randint(40, H - 20)
        sc = over(sc, snow.crop((k * 20, 0, k * 20 + 20, 20)), (x, y))
    hud(sc, lives=4, score="0183300", letters="GRU..")
    finish(sc, "ice")


def volcano():
    sc = backdrop("volcano", ["layer0_sky", "layer1_far_cones", "layer2_basalt", "layer3_burnt_forest"])
    atlas = A("tiles/volcano/terrain.png")
    lines = ["....................",
             "....................",
             "....................",
             "....................",
             "....................",
             "....................",
             "................####",
             "#####...........####",
             "#####....####...####",
             "#####....####...####",
             "####################",
             "####################"]
    solid = grid_from(lines)
    for x in (5, 6, 7, 8, 13, 14, 15):
        solid[10][x] = False; solid[11][x] = False
    g = auto(solid)
    lava = A("tiles/common/lava.png")
    for i, x in enumerate((5, 6, 7, 8, 13, 14, 15)):
        sc.alpha_composite(lava.crop(((i % 6) * 32, 0, (i % 6) * 32 + 32, 32)), (x * 32, 10 * 32 - 14))
        sc.alpha_composite(lava.crop((6 * 32, 0, 7 * 32, 32)), (x * 32, 11 * 32 - 14))
    sc = put_prop(sc, "tiles/volcano/props/dead_tree.png", 90, 7 * 32 + 4)
    paint(sc, atlas, g)
    sc = put_prop(sc, "sprites/objects/exit_totem.png", 0, 0, anchor="none") if False else sc
    f, m = frame("sprites/objects/exit_totem.png", 3); sc = over(sc, f, (590 - 20, 6 * 32 - 88 + 2))
    sc = put_prop(sc, "tiles/volcano/props/skull_ribs.png", 345, 8 * 32 + 3); sc = put_prop(sc, "tiles/volcano/props/tusk_b.png", 30, 7 * 32 + 2)
    sc = put_prop(sc, "sprites/objects/platform_stone.png", 6 * 32 + 16, 6 * 32, anchor="top")
    sc = put_actor(sc, "sprites/enemies/dragon.png", 6, 390, 8 * 32, -1)
    sc = put_actor(sc, "sprites/enemies/rival.png", 9, 545, 6 * 32, -1)
    sc = put_actor(sc, "sprites/enemies/dragon_b.png", 4, 250, 110, -1)
    sc = put_actor(sc, "sprites/player/hero.png", 36, 215, 6 * 32 - 26)
    for i, (x, y) in enumerate(((120, 60), (300, 40), (470, 90), (180, 200))):
        f, m = frame("sprites/fx/falling_ember.png", i % 2); sc = over(sc, f, (x, y))
    sc = food(sc, 43, 250, 6 * 32 - 4); sc = food(sc, 35, 330, 8 * 32 - 44)
    f, m = frame("sprites/items/pickups.png", 5); sc = over(sc, f, (400, 8 * 32 - 90))
    f, m = frame("sprites/fx/splash_lava.png", 2); sc = over(sc, f, (460, 10 * 32 - 44))
    hud(sc, lives=1, hearts=1, score="0975500", letters="GRUB.")
    finish(sc, "volcano")


def feast():
    sc = backdrop("feast", ["layer0_sky", "layer1_clouds", "layer2_scoops", "layer3_meadow"])
    atlas = A("tiles/feast/terrain.png"); icing = A("tiles/feast/terrain_icing.png"); bis = A("tiles/feast/terrain_biscuit.png")
    lines = ["....................",
             "....................",
             "....................",
             "....................",
             "....................",
             "....................",
             "....................",
             "......#####.........",
             "......#####.....####",
             "####..#####.....####",
             "####################",
             "####################"]
    g = auto(grid_from(lines))
    paint(sc, atlas, g)
    gi = auto(grid_from(["...................."] * 7 + ["......#####.........", "......#####.........", "......#####........."] + ["...................."] * 2))
    for y in range(7, 10):
        for x in range(6, 11):
            sc.alpha_composite(tile(icing, gi[y][x] if y < 9 else (L if x == 6 else R if x == 10 else FILL)), (x * 32, y * 32))
    for x, v in ((13, OWL), (14, OWM), (15, OWR)):
        sc.alpha_composite(tile(bis, v), (x * 32, 5 * 32))
    gb = A("sprites/items/giant_bonus.png")
    sc = over(sc, gb.crop((0, 0, 72, 72)), (30, 9 * 32 - 70)); sc = over(sc, gb.crop((2 * 72, 0, 3 * 72, 72)), (540, 8 * 32 - 70))
    k = 0
    for y in (6 * 32 - 6, 5 * 32 - 2):
        for x in range(200, 360, 34):
            sc = food(sc, (k * 5 + 16) % 40, x + 8, y - (k % 2) * 4); k += 1
    for x in range(430, 520, 34):
        sc = food(sc, (k * 3) % 40, x + 8, 5 * 32 - 4); k += 1
    sc = food(sc, 13, 300, 9 * 32 - 8, "sprites/items/treasure.png"); sc = food(sc, 9, 480, 10 * 32 - 40, "sprites/items/treasure.png")
    sc = put_actor(sc, "sprites/enemies/egg_kid.png", 19, 420, 110)
    sc = put_actor(sc, "sprites/player/hero.png", 48, 150, 9 * 32)
    f, m = frame("sprites/items/pickups.png", 10); sc = over(sc, f, (590 - 24, 5 * 32 - 60))
    hud(sc, lives=3, score="0260100", letters="GRUBS")
    finish(sc, "feast")


def boss_brute():
    sc = backdrop("cave", ["layer0_wall", "layer1_rocks_far", "layer2_ceiling_near"], cam_x=900)
    atlas = A("tiles/cave/terrain_stone.png")
    lines = ["####################", "...................."] + ["...................."] * 7 + ["####################"] * 3
    g = auto(grid_from(lines))
    paint(sc, atlas, g)
    sc = put_prop(sc, "tiles/cave/props/skull_ribs.png", 90, 9 * 32 + 3); sc = put_prop(sc, "tiles/cave/props/tusk_b.png", 610, 9 * 32 + 2)
    sc = put_prop(sc, "tiles/cave/props/bone_pile.png", 300, 9 * 32 + 2)
    sc = put_actor(sc, "sprites/bosses/brute.png", 22, 440, 9 * 32, -1)
    sc = put_actor(sc, "sprites/player/hero.png", 27, 170, 9 * 32)
    for i, (x, y) in enumerate(((250, 200), (290, 170), (330, 215))):
        f, m = frame("sprites/items/bone.png", i); sc = over(sc, f, (x, y))
    hud(sc, hearts=2, score="0312200", letters="GRU..", boss=6)
    finish(sc, "boss_brute")


def boss_colossus():
    sc = backdrop("volcano", ["shaft_layer0_wall", "shaft_layer1_rocks", "shaft_layer2_ceiling_near"], cam_x=300)
    atlas = A("tiles/volcano/terrain_obsidian.png")
    lines = ["####################"] + ["#.................##"] * 8 + ["####################"] * 3
    solid = grid_from(lines)
    g = auto(solid)
    paint(sc, atlas, g)
    f, m = frame("sprites/bosses/colossus.png", 6)
    sc = over(sc, f, (18 * 32 + 12 - m["pivot"][0], 9 * 32 - m["pivot"][1]))
    f, m = frame("sprites/fx/projectile_rock.png", 1); sc = over(sc, f, (300, 9 * 32 - 60))
    sc = put_prop(sc, "sprites/fx/projectile_stalactite.png", 180, 80)
    sc = put_actor(sc, "sprites/player/hero_axe.png", 27, 120, 9 * 32)
    f, m = frame("sprites/fx/projectile_axe.png", 1); sc = over(sc, f, (230, 9 * 32 - 96))
    lava = A("tiles/common/lava.png")
    hud(sc, hearts=3, score="1204400", letters="GRUBS", boss=5)
    finish(sc, "boss_colossus")


if __name__ == "__main__":
    os.makedirs(os.path.join(os.environ.get("TEMP", "."), "cs"), exist_ok=True)
    which = sys.argv[1:] or ["jungle", "cave", "ice", "volcano", "feast", "boss_brute", "boss_colossus"]
    for w in which:
        globals()[w]()

"""Collectibles, power-ups, FX, UI, fonts, icon and splash.

Sources
  * Superpowers "Prehistoric Platformer" (Pixel-boy, CC0): native items, FX, HUD, bitmap fonts
  * "16x16 Food" and "16x16 RPG Items (DB32)" by ARoachIFoundOnMyPillow (CC0): food / gems, integer 2x
  * "Free Pixel foods" by ghostpixxells (CC0): giant bonus food, integer 2x + 2 px dark outline
  * "Treasure Hunters" by Pixel Frog (CC0): carved-stone touch buttons, integer 2x, recoloured to sandstone
  * "Explosion Animations Pack" and "Sunny Land" FX by ansimuz (CC0)
  * Press Start 2P, Pixelify Sans (SIL OFL 1.1)
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *  # noqa
from build_tiles import ts, lum_ramp, FROST_ROCK

AR_FOOD = os.path.join(ITEMS, "oga_aroach_16x16-food", "food")
AR_ITEM = os.path.join(ITEMS, "oga_aroach_16x16-rpg-items-db32")
GHOST = os.path.join(ITEMS, "ghostpixxells_free-pixel-foods")
PF_UI = os.path.join(ITEMS, "pixelfrog_treasure-hunters", "Treasure Hunters", "Wood and Paper UI", "Sprites")
ANS_EXP = os.path.join(ITEMS, "ansimuz_explosion-animations-pack", "explosion pack 1", "Explosions pack")
ANS_SUN = os.path.join(ITEMS, "ansimuz_sunny-land", "Sunny-land-files", "Assets", "Misc")
DARK = (39, 32, 24)
S = "superpowers-prehistoric-platformer: "


def find(root, name):
    for d, _, files in os.walk(root):
        if name in files:
            return os.path.join(d, name)
    raise FileNotFoundError(name)


def cell(im, w, h, ax=0.5, ay=1.0):
    return pad_to(trim(im), w, h, ax, ay)


FOOD = [  # (name, displayed score, source pack, file)
    ("apple", 100, "ar", "apple_red"), ("banana", 100, "ar", "banana"), ("cherries", 100, "ar", "cherries"),
    ("strawberry", 100, "ar", "strawberry"), ("orange", 100, "ar", "orange"), ("carrot", 100, "ar", "carrot"),
    ("mushroom", 100, "ar", "mushroom"), ("grapes", 200, "ar", "grapes_purple"),
    ("pear", 200, "ar", "pear"), ("pineapple", 200, "ar", "pineapple"), ("watermelon_slice", 200, "ar", "watermelon_slice"),
    ("corn", 200, "ar", "corn"), ("bread_roll", 200, "ar", "breadroll"), ("cheese", 300, "ar", "cheese"),
    ("fried_egg", 300, "ar", "egg_fried"), ("cookie", 300, "ar", "cookie"),
    ("candy_cane", 300, "ar", "candy_cane"), ("lollipop", 300, "ar", "lollipop"), ("popsicle", 300, "ar", "popsicle"),
    ("ice_cream", 500, "ar", "icecream_vanilla"), ("cupcake", 500, "ar", "cupcake_vanilla"),
    ("doughnut", 500, "ar", "doughnut_pink_sprinkles"), ("french_fries", 500, "ar", "french_fries"), ("hotdog", 500, "ar", "hotdog"),
    ("pizza_slice", 600, "ar", "pizza_pepperoni_slice"), ("taco", 600, "ar", "taco"), ("popcorn", 600, "ar", "popcorn"),
    ("burger", 700, "ar", "burger"), ("sandwich", 700, "ar", "sandwich"), ("pancakes", 750, "ar", "pancakes"),
    ("waffle", 750, "ar", "waffle"), ("cake_slice", 800, "ar", "cake_slice_chocolate"),
    ("pie_slice", 800, "ar", "pie_cherry_slice"), ("drumstick", 800, "ar", "chicken_drumstick_cooked"),
    ("sushi", 800, "ar", "sushi_roll"), ("steak", 1000, "ar", "steak_grilled"), ("ham", 1000, "ar", "ham"),
    ("honey_pot", 1000, "ar", "honey_pot"), ("cake", 1000, "ar", "cake_whole_plain"), ("pizza", 1000, "ar", "pizza_pepperoni_whole"),
    ("roast", 1000, "sp", "items/8.png"), ("dino_egg", 300, "sp", "items/10.png"), ("honey_bun", 200, "sp", "items/11.png"),
    ("rib_slab", 800, "sp", "items/34.png"), ("rib_slab_rare", 800, "sp", "items/35.png"), ("meat_orange", 600, "sp", "items/47.png"),
    ("meat_blue", 600, "sp", "items/48.png"), ("berry_red", 200, "sp", "items/55.png"),
]
TREASURE = [
    ("ruby", 2000, "item_gem_ruby"), ("sapphire", 2000, "item_gem_sapphire"), ("emerald", 2000, "item_gem_emerald"),
    ("amethyst", 2000, "item_gem_amethyst"), ("amber", 2000, "item_gem_amber"), ("peridot", 2000, "item_gem_peridot"),
    ("quartz", 2000, "item_gem_quartz"), ("pearl", 2000, "item_pearl"),
    ("diamond", 5000, "item_gem_diamond_smooth"), ("rough_diamond", 5000, "item_gem_diamond_rough"),
    ("ring_red", 5000, "item_ring_gold_gem_red"), ("ring_blue", 5000, "item_ring_gold_gem_blue"),
    ("ring_green", 5000, "item_ring_gold_gem_green"), ("necklace", 8000, "item_pearl_necklace"),
    ("goblet", 8000, "item_goblet_empty"), ("orb", 8000, "item_orb"),
]
GIANT = [("giant_roast", 60000, "85_roastedchicken"), ("giant_burger", 20000, "15_burger"), ("giant_cake", 30000, "90_strawberrycake"),
         ("giant_donut", 10000, "34_donut"), ("giant_ice_cream", 10000, "57_icecream"), ("giant_pizza", 20000, "81_pizza"),
         ("giant_chocolate_cake", 30000, "30_chocolatecake")]


def ar2(folder, name):
    return scale(load(os.path.join(folder, name + ".png")), 2)


def build_items():
    I = "sprites/items/"
    # ---- food
    cells = []
    for name, score, pack, f in FOOD:
        im = ar2(AR_FOOD, f) if pack == "ar" else cell(sp(f), 32, 32)
        cells.append(pad_to(trim(im), 32, 32))
    save(strip(cells, cols=8), I + "food.png", kind="atlas", frame=[32, 32], grid=[8, 6], pivot=[16, 32],
         entries=[{"index": i, "name": n, "score": s} for i, (n, s, _, _) in enumerate(FOOD)],
         source="oga_aroach_16x16-food (indices 0-39, integer 2x) + superpowers-prehistoric-platformer items (40-47, native size)",
         edits="16 px icons scaled 2x nearest-neighbour; every sprite bottom-centred in a 32x32 cell",
         note="small food 100-500, bigger food 600-1000 (GAMEPLAY 3.2); bob 3 px (6 art px) when placed in the map")
    # ---- treasure
    cells = [pad_to(trim(ar2(AR_ITEM, f)), 32, 32) for _, _, f in TREASURE]
    save(strip(cells, cols=8), I + "treasure.png", kind="atlas", frame=[32, 32], grid=[8, 2], pivot=[16, 32],
         entries=[{"index": i, "name": n, "score": s} for i, (n, s, _) in enumerate(TREASURE)],
         source="oga_aroach_16x16-rpg-items-db32 (integer 2x)", edits="16 px icons scaled 2x; bottom-centred in 32x32 cells",
         note="treasures 2 000 / 5 000 / 8 000")
    # ---- giant bonuses
    cells = []
    for n, s, f in GIANT:
        im = outline(scale(trim(load(os.path.join(find(GHOST, f + ".png")))), 2), DARK + (255,), 2)
        cells.append(pad_to(im, 72, 72))
    save(strip(cells, cols=7), I + "giant_bonus.png", kind="atlas", frame=[72, 72], grid=[7, 1], pivot=[36, 72],
         entries=[{"index": i, "name": n, "score": s} for i, (n, s, _) in enumerate(GIANT)],
         source="ghostpixxells_free-pixel-foods (integer 2x)", edits="32 px sprites scaled 2x, 2 px dark outline added to match the anchor pack",
         note="giant bonuses that fall from the sky (GAMEPLAY 3.2 / 4.4)")
    # ---- pick-ups (specials)
    icons = ts()
    heart = scale(icons.crop((784, 544, 800, 560)), 2)
    skull = scale(icons.crop((800, 544, 816, 560)), 2)
    hero = grid_cells(sp("characters/playable/caverman.png"), 6, 7)[0].crop((22, 6, 68, 42))
    picks = [
        ("heart", "+1 heart", heart, S + "tileset-1.png icon strip (2x)"),
        ("one_up", "+1 life (hero head)", hero, S + "characters/playable/caverman.png (head crop)"),
        ("skull", "bad item: scatters all energy as bones", skull, S + "tileset-1.png icon strip (2x)"),
        ("kill_all", "chili: every on-screen enemy dies", ar2(AR_FOOD, "chili_pepper_red"), "oga_aroach_16x16-food (2x)"),
        ("grenade", "coconut bomb: on-screen enemies burst into bonus items", ar2(AR_FOOD, "coconut_whole"), "oga_aroach_16x16-food (2x)"),
        ("fire_starter", "torch: unlocks the exit totem (the original's lighter)", ar2(AR_ITEM, "item_torch"), "oga_aroach_16x16-rpg-items-db32 (2x)"),
        ("feast_bowl", "feast kit piece 1 of 3 (the original's fork)", sp("items/3.png"), S + "items/3.png"),
        ("feast_flint", "feast kit piece 2 of 3 (knife)", sp("items/2.png"), S + "items/2.png"),
        ("feast_log", "feast kit piece 3 of 3 (spoon)", sp("items/4.png"), S + "items/4.png"),
        ("trophy", "boss trophy: starts the ending", ar2(AR_ITEM, "item_goblet_empty"), "oga_aroach_16x16-rpg-items-db32 (2x)"),
        ("warp", "spiral staff: warp to / from a bonus stage", sp("items/19.png"), S + "items/19.png"),
        ("water_bucket", "washes off the flies (the original's tap)", ar2(AR_ITEM, "item_bucket_narrow_water"), "oga_aroach_16x16-rpg-items-db32 (2x)"),
        ("key", "spare key icon", sp("items/22.png"), S + "items/22.png"),
        ("marker_cross", "editor marker (not drawn in game)", scale(icons.crop((272, 544, 288, 560)), 2), S + "tileset-1.png icon strip (2x)"),
        ("amber_orb", "spare orb icon", scale(icons.crop((288, 544, 304, 560)), 2), S + "tileset-1.png icon strip (2x)"),
        ("flag_blue", "spare flag icon", scale(icons.crop((368, 544, 384, 560)), 2), S + "tileset-1.png icon strip (2x)"),
    ]
    save(strip([pad_to(trim(im), 48, 40) for _, _, im, _ in picks], cols=8), I + "pickups.png", kind="atlas", frame=[48, 40], grid=[8, 2],
         pivot=[24, 40], entries=[{"index": i, "name": n, "meaning": m, "from": src} for i, (n, m, _, src) in enumerate(picks)],
         source="mixed, see entries", edits="bottom-centred in 48x40 cells; 16 px icons scaled 2x", note="special pick-ups (GAMEPLAY 4.1)")
    # ---- bones (energy fragments)
    bone = pad_to(trim(sp("items/15.png")), 26, 26, 0.5, 0.5)
    save(strip([bone.rotate(-90 * k) for k in range(4)]), I + "bone.png", kind="item", frame=[26, 26], grid=[4, 1], pivot=[13, 13],
         anims={"spin": anim(range(4), 10)}, source=S + "items/15.png", edits="4 lossless 90 degree rotations",
         note="energy fragment: 6 bones = 1 heart (GAMEPLAY 4.2)")
    # ---- bonus letters G R U B S from the title font
    glyphs = title_glyphs()
    letters = [pad_to(glyphs[ch], 40, 40) for ch in "GRUBS"]
    save(strip(letters), I + "letters.png", kind="atlas", frame=[40, 40], grid=[5, 1], pivot=[20, 40],
         entries=[{"index": i, "name": "letter_" + ch} for i, ch in enumerate("GRUBS")], source=S + "title-font.png",
         edits="five glyphs re-packed", note="bonus word letters; the HUD shows the same sprites at half size or as dimmed placeholders")
    return glyphs


def title_glyphs():
    """Slice title-font.png (3 rows of 35 px stone glyphs: A-O / P-Z 0-3 / 4-9) by transparent column gaps.
    The digits 0 1 2 touch each other in the source and are split at fixed columns."""
    im = sp("title-font.png")
    a = np.array(im)[..., 3] > 0
    order = ["ABCDEFGHIJKLMNO", "PQRSTUVWXYZ0123", "456789"]
    bands = [(10, 45), (47, 82), (84, 119)]
    out = {}
    for (y0, y1), chars in zip(bands, order):
        cols = a[y0:y1].any(0)
        runs = []; start = None
        for x, v in enumerate(list(cols) + [False]):
            if v and start is None:
                start = x
            elif not v and start is not None:
                runs.append((start, x)); start = None
        fixed = []
        for r in runs:
            if r == (412, 500):
                fixed += [(412, 446), (447, 465), (466, 500)]
            else:
                fixed.append(r)
        assert len(fixed) == len(chars), (len(fixed), len(chars))
        for (x0, x1), ch in zip(fixed, chars):
            out[ch] = im.crop((x0, y0, x1, y1))
    return out


def build_fonts(glyphs):
    F = "fonts/"
    save(sp("font-20x20.png"), F + "font_hud.png", kind="font", frame=[20, 20], grid=[15, 8], source=S + "font-20x20.png", edits="none",
         charset="cells 0-94 = U+0020..U+007E (lower case is drawn as capitals); cell 95 unused; cells 96-119 = "
                 "C7 FC E9 E2 E4 E0 E5 E7 EA EB E8 EF EE EC C4 C5 C9 E6 C6 F4 F6 F2 FB F9 (code page 437 order)",
         note="white 16 px capitals with a 2 px dark outline; HUD text, score, pop-ups. Import as Godot 'Font Data (Image Font)', "
              "15 columns x 8 rows, or draw by cell")
    save(sp("font-number-40x40.png"), F + "font_digits_big.png", kind="font", frame=[40, 40], grid=[10, 1], source=S + "font-number-40x40.png",
         edits="none", charset="cells 0-9 = digits 0..9", note="stone digits for the tally score, countdowns, world numbers")
    chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    save(strip([pad_to(glyphs[c], 52, 36) for c in chars], cols=12), F + "font_title.png", kind="font", frame=[52, 36], grid=[12, 3],
         source=S + "title-font.png", edits="glyphs re-packed on a uniform 52x36 grid, bottom-centred (the source has variable spacing; glyph widths 18-49 px, height 35 px)",
         charset="cells 0-25 = A..Z, cells 26-35 = 0..9", note="carved-stone display capitals: logo, LEVEL COMPLETE, GAME OVER")
    dst = os.path.join(ASSETS, "fonts")
    shutil.copyfile(os.path.join(ITEMS, "googlefonts_pressstart2p", "PressStart2P-Regular.ttf"), os.path.join(dst, "press_start_2p.ttf"))
    shutil.copyfile(os.path.join(ITEMS, "googlefonts_pixelifysans", "PixelifySans[wght].ttf"), os.path.join(dst, "pixelify_sans.ttf"))
    register(F + "press_start_2p.ttf", kind="ttf", source="googlefonts_pressstart2p: PressStart2P-Regular.ttf", edits="renamed",
             note="8 px bitmap-style TTF (use at 8 / 16 / 24 px, antialiasing off). Latin, Latin Extended-A, Cyrillic: localisation fallback for font_hud")
    register(F + "pixelify_sans.ttf", kind="ttf", source="googlefonts_pixelifysans: PixelifySans[wght].ttf", edits="renamed",
             note="proportional pixel sans with lower case, variable weight 400-700 (use at 11 / 22 px, antialiasing off): menus, options, credits")


def build_fx():
    X = "sprites/fx/"
    save(sp("fx/effects/1.png"), X + "slash.png", kind="fx", frame=[33, 65], grid=[4, 1], pivot=[16, 32], anims={"slash": anim(range(4), 20, False)},
         source=S + "fx/effects/1.png", edits="none", note="swing arc (already baked into the hero attack frames; use for enemy / boss swings)")
    save(sp("fx/effects/2.png"), X + "poof.png", kind="fx", frame=[57, 56], grid=[9, 1], pivot=[28, 28], anims={"poof": anim(range(9), 16, False)},
         source=S + "fx/effects/2.png", edits="none", note="smoke poof: enemy defeated, item spawned from a hidden spot")
    star = sp("fx/effects/3.png")
    save(star, X + "star_puff.png", kind="fx", frame=[45, 41], grid=[5, 1], pivot=[22, 20], anims={"puff": anim(range(5), 16, False)},
         source=S + "fx/effects/3.png", edits="none", note="star puff shown on every club hit on scenery (GAMEPLAY 4.4), pick-up sparkle")
    wmap = ramp_fn([(60, 150, 180), (150, 210, 226), (240, 250, 252)], 180, 250)
    save(remap(star, wmap), X + "splash_water.png", kind="fx", frame=[45, 41], grid=[5, 1], pivot=[22, 41], anims={"splash": anim(range(5), 14, False)},
         source=S + "fx/effects/3.png", edits="star puff gradient-mapped to water colours", note="water splash")
    lmap = ramp_fn([(206, 66, 26), (250, 150, 40), (255, 236, 130)], 180, 250)
    save(remap(star, lmap), X + "splash_lava.png", kind="fx", frame=[45, 41], grid=[5, 1], pivot=[22, 41], anims={"splash": anim(range(5), 14, False)},
         source=S + "fx/effects/3.png", edits="star puff gradient-mapped to lava colours", note="lava splash")
    save(sp("fx/effects/4.png"), X + "ring.png", kind="fx", frame=[50, 52], grid=[6, 1], pivot=[25, 26], anims={"ring": anim(range(6), 18, False)},
         source=S + "fx/effects/4.png", edits="none", note="shock ring: head bounce, hard landing, boss stomp")
    sm = sp("fx/effects/smoke.png")
    save(sm, X + "smoke.png", kind="fx", frame=list(sm.size), grid=[1, 1], pivot=[sm.width // 2, sm.height // 2], source=S + "fx/effects/smoke.png",
         edits="none", note="single smoke ball: run / skid dust (scale and fade in a particle emitter)")
    # particles
    def pack_particles(prefix, n, out, note, cellsz):
        fr = [pad_to(trim(sp("fx/particles/%s-%d.png" % (prefix, i))), cellsz, cellsz, 0.5, 0.5) for i in range(1, n + 1)]
        save(strip(fr), X + out, kind="fx", frame=[cellsz, cellsz], grid=[n, 1], pivot=[cellsz // 2, cellsz // 2],
             source=S + "fx/particles/%s-*.png" % prefix, edits="re-packed on a uniform grid", note=note)
    pack_particles("rock-particle", 4, "debris_rock.png", "debris of breakable blocks / hidden spots: cave, volcano", 20)
    pack_particles("wood-particle", 5, "debris_wood.png", "debris: crates, barrels, jungle blocks", 20)
    pack_particles("snow-particle", 6, "particles_snow.png", "snowfall / blizzard flakes and ice chips", 20)
    pack_particles("leaf", 4, "particles_leaf.png", "drifting leaves (jungle ambience, debris)", 20)
    pack_particles("smoke-particle", 4, "particles_smoke.png", "smoke / ash particles (volcano ambience)", 28)
    pack_particles("rain", 2, "particles_rain.png", "rain streaks", 20)
    # explosions (ansimuz)
    b = load(os.path.join(ANS_EXP, "explosion-1-b", "spritesheet.png"))
    save(b, X + "explosion.png", kind="fx", frame=[64, 64], grid=[8, 1], pivot=[32, 32], anims={"explode": anim(range(8), 16, False)},
         source="ansimuz_explosion-animations-pack: explosion-1-b/spritesheet.png", edits="none", note="grenade / kill-all burst, breaking rocks")
    d = load(os.path.join(ANS_EXP, "explosion-1-d", "spritsheet.png"))
    save(d, X + "explosion_big.png", kind="fx", frame=[128, 128], grid=[12, 1], pivot=[64, 96], anims={"explode": anim(range(12), 16, False)},
         source="ansimuz_explosion-animations-pack: explosion-1-d/spritsheet.png", edits="none", note="boss defeat")
    e = load(os.path.join(ANS_SUN, "Sunnyland FX", "Spritesheets", "enemy-deadth.png"))
    save(e, X + "hit_stars.png", kind="fx", frame=[40, 41], grid=[6, 1], pivot=[20, 20], anims={"hit": anim(range(6), 16, False)},
         source="ansimuz_sunny-land: Misc/Sunnyland FX/Spritesheets/enemy-deadth.png", edits="none", note="club hit on an enemy (star burst)")


def stone_fn():
    base = ramp_fn([(39, 32, 24), (110, 78, 54), (160, 122, 86), (200, 164, 120), (234, 206, 160)], 40, 200)
    return base


def build_ui(glyphs):
    U = "ui/"
    icons = ts()
    # hearts: full / empty
    heart = scale(icons.crop((784, 544, 800, 560)), 2)
    a = np.array(heart); cols = sorted({tuple(c) for c in a.reshape(-1, 4)[:, :3].tolist()})
    def empty_fn(r, g, b):
        if (r, g, b) in ((0, 0, 0), DARK) or max(r, g, b) < 60:
            return (r, g, b)
        return (86, 60, 48) if (r + g + b) < 600 else (120, 90, 72)
    save(strip([heart, remap(heart, empty_fn)]), U + "hud_heart.png", kind="ui", frame=[32, 32], grid=[2, 1],
         entries=[{"index": 0, "name": "full"}, {"index": 1, "name": "empty"}], source=S + "tileset-1.png icon strip (2x)",
         edits="16 px icon scaled 2x; empty state = fill colours replaced by dark browns", note="energy: 3 heart slots (GAMEPLAY 2)")
    pips = [icons.crop((336, 544, 352, 560)), icons.crop((304, 544, 320, 560))]
    save(strip(pips), U + "hud_boss_pip.png", kind="ui", frame=[16, 16], grid=[2, 1], entries=[{"index": 0, "name": "full"}, {"index": 1, "name": "empty"}],
         source=S + "tileset-1.png icon strip", edits="two orb icons re-packed", note="boss energy: up to 8 pips, 10 art px apart")
    head = grid_cells(sp("characters/playable/caverman.png"), 6, 7)[0].crop((22, 6, 68, 42))
    save(pad_to(head, 48, 36), U + "hud_lives_icon.png", kind="ui", frame=[48, 36], grid=[1, 1], source=S + "characters/playable/caverman.png",
         edits="head crop", note="lives counter icon")
    # bars
    save(sp("hud/health-bar-top-1.png"), U + "bar_frame_wood.png", kind="ui", frame=[148, 32], grid=[1, 1], source=S + "hud/health-bar-top-1.png",
         edits="none", note="wooden bar frame; inner window 128x18 at (10, 7)")
    save(sp("hud/health-bar-top-2.png"), U + "bar_frame_bone.png", kind="ui", frame=[152, 37], grid=[1, 1], source=S + "hud/health-bar-top-2.png",
         edits="none", note="bone bar frame (boss bar alternative); inner window 128x18 at (12, 9)")
    save(sp("hud/health-bar-backgound.png"), U + "bar_back.png", kind="ui", frame=[128, 18], grid=[1, 1], source=S + "hud/health-bar-backgound.png",
         edits="none", note="bar background")
    fill = canvas(10, 18)
    fill.alpha_composite(sp("hud/bar-start.png"), (0, 0)); fill.alpha_composite(sp("hud/bar-middle.png"), (3, 0)); fill.alpha_composite(sp("hud/bar-end.png"), (7, 0))
    save(fill, U + "bar_fill.png", kind="ui", frame=[10, 18], grid=[1, 1], source=S + "hud/bar-start.png + bar-middle.png + bar-end.png",
         edits="three pieces joined", note="nine-patch: left 3 px cap, 4 px stretchable middle, right 3 px cap")
    # panel nine-patch
    L = sp("hud/inventory-left.png"); M = sp("hud/inventory-middle.png"); R = sp("hud/inventory-right.png")
    panel = canvas(48, 48)
    for (src, sx, dx) in ((L, 0, 0), (M, 24, 16), (R, 0, 32)):
        panel.alpha_composite(src.crop((sx, 0, sx + 16, 16)), (dx, 0))
        panel.alpha_composite(src.crop((sx, 24, sx + 16, 40)), (dx, 16))
        panel.alpha_composite(src.crop((sx, 48, sx + 16, 64)), (dx, 32))
    save(panel, U + "panel.png", kind="ui", frame=[48, 48], grid=[1, 1], source=S + "hud/inventory-left/middle/right.png",
         edits="re-cut into a 48x48 nine-patch", note="NinePatchRect, margins 16 px: menu and dialog panels")
    save(sp("hud/inventory-case.png"), U + "slot.png", kind="ui", frame=[49, 53], grid=[1, 1], source=S + "hud/inventory-case.png", edits="none",
         note="framed slot: weapon icon, level-select tile")
    # touch buttons (Pixel Frog carved stone, 2x, warm sandstone)
    order = [("left", 3), ("right", 4), ("up", 2), ("down", 1), ("a", 5), ("b", 6), ("x", 7), ("y", 8)]
    normal = []; pressed = []
    fn = stone_fn()
    for name, i in order:
        im = scale(load(os.path.join(PF_UI, "Mobile Buttons", "Mobile Buttons", "%d.png" % i)), 2)
        im = remap(im, fn)
        normal.append(im)
        p = canvas(im.width, im.height); p = over(p, remap(im, hsv_fn(vm=0.78)), (0, 3))
        pressed.append(p)
    # pause button: blank slot with two bars
    slot = scale(load(os.path.join(PF_UI, "Mobile Buttons", "Mobile Buttons", "5.png")), 2)
    save(strip(normal + pressed, cols=8), U + "touch_buttons.png", kind="ui", frame=[56, 56], grid=[8, 2],
         entries=[{"index": i, "name": n} for i, (n, _) in enumerate(order)] + [{"index": 8 + i, "name": n + "_pressed"} for i, (n, _) in enumerate(order)],
         source="pixelfrog_treasure-hunters: Wood and Paper UI/Sprites/Mobile Buttons/1-8.png",
         edits="integer 2x; gradient-mapped from blue-grey to warm sandstone; pressed row = darkened and moved 3 px down",
         note="touch overlay: left / right / down (crouch) on the left side, A = jump, B = strike, X = look, Y = spare; draw at 1x (56 px) or 2x on phones")
    # pause / menu icons from the icon strip (2x)
    names = [("arrow_up", 208), ("arrow_right", 224), ("arrow_down", 240), ("arrow_left", 256), ("cross", 272), ("exclaim", 416), ("question", 432),
             ("sword", 752), ("shield", 768), ("heart", 784), ("skull", 800), ("fruit", 816)]
    save(strip([scale(icons.crop((x, 544, x + 16, 560)), 2) for _, x in names], cols=12), U + "icons.png", kind="ui", frame=[32, 32], grid=[12, 1],
         entries=[{"index": i, "name": n} for i, (n, _) in enumerate(names)], source=S + "tileset-1.png icon strip (2x)", edits="16 px icons scaled 2x",
         note="menu / prompt icons")
    pb = canvas(56, 56)
    base = remap(scale(load(os.path.join(PF_UI, "Mobile Buttons", "Mobile Buttons", "7.png")), 2), fn)
    save(base, U + "touch_pause.png", kind="ui", frame=[56, 56], grid=[1, 1], source="pixelfrog_treasure-hunters: Mobile Buttons/7.png",
         edits="integer 2x, sandstone recolour", note="pause / menu button for the touch overlay (the X stone)")
    # logo
    def word(text, gap=2):
        gl = [glyphs[c] for c in text]
        w = sum(g.width for g in gl) + gap * (len(gl) - 1); h = max(g.height for g in gl)
        out = canvas(w, h); x = 0
        for g in gl:
            out.alpha_composite(g, (x, h - g.height)); x += g.width + gap
        return out
    w1 = word("CLUB"); w2 = word("GRUB")
    club = scale(sp("items/1.png"), 2)
    club_r, _ = rotate_px(club, 35)
    club_r = trim(club_r)
    meat = scale(sp("items/8.png"), 2)
    logo = canvas(w1.width + w2.width + 110, 100)
    logo.alpha_composite(w1, (0, 40)); logo = over(logo, club_r, (w1.width + 6, 4))
    logo.alpha_composite(w2, (w1.width + 78, 40)); logo = over(logo, meat, (w1.width + 78 + w2.width - 20, 0))
    logo = trim(logo)
    save(logo, U + "title_logo.png", kind="ui", frame=list(logo.size), grid=[1, 1], source=S + "title-font.png + items/1.png + items/8.png",
         edits="glyphs composed into the working title, club (2x, rotated) and roast (2x) added", note="title screen logo; draw at 1x or 2x")
    # splash + icon
    hero_sheet = load(os.path.join(ASSETS, "sprites", "player", "hero.png"))
    f48 = hero_sheet.crop((0, 6 * 112, 176, 7 * 112))     # victory frame 0 (club raised)
    bust = trim(f48)
    big = scale(bust, 3)
    icon = canvas(256, 256, (0, 0, 0, 0))
    # rounded sky tile background
    bgc = Image.new("RGBA", (256, 256), (255, 164, 58, 255))
    a = np.zeros((256, 256), np.uint8)
    yy, xx = np.mgrid[0:256, 0:256]
    r = 40
    inside = ((xx >= r) & (xx < 256 - r)) | ((yy >= r) & (yy < 256 - r))
    for cx, cy in ((r, r), (255 - r, r), (r, 255 - r), (255 - r, 255 - r)):
        inside |= (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r
    a[inside] = 255
    sky = scale(sp("background-elements/sky-2.png").crop((300, 300, 364, 364)), 4)
    icon.paste(sky, (0, 0)); icon.putalpha(Image.fromarray(a))
    grass = scale(ts().crop((320 + 32, 256 + 32, 320 + 64, 256 + 64)), 4)       # jungle top tile
    g2 = canvas(256, 256)
    for x in range(0, 256, 128):
        g2.alpha_composite(grass, (x, 196))
    g2.putalpha(Image.fromarray(np.minimum(np.array(g2)[..., 3], a)))
    icon.alpha_composite(g2)
    icon = over(icon, big, (128 - big.width // 2 + 8, 214 - big.height))
    save(icon, "icon.png", kind="ui", frame=[256, 256], grid=[1, 1], source=S + "hero victory frame (3x), sky-2.png (4x), jungle top tile (4x)",
         edits="composited on a rounded 256x256 tile", note="application icon")
    splash = Image.new("RGBA", (640, 360), (39, 32, 24, 255))
    l1 = canvas(w1.width + 60, 76); l1.alpha_composite(w1, (0, 40)); l1 = over(l1, club_r, (w1.width + 6, 4)); l1 = scale(trim(l1), 2)
    l2 = canvas(w2.width + 60, 76); l2.alpha_composite(w2, (0, 40)); l2 = over(l2, meat, (w2.width - 16, 0)); l2 = scale(trim(l2), 2)
    splash = over(splash, l1, (320 - l1.width // 2, 40))
    splash = over(splash, l2, (320 - l2.width // 2, 40 + l1.height + 14))
    save(splash, "splash.png", kind="ui", frame=[640, 360], grid=[1, 1], source="title font glyphs, club and roast (2x)",
         edits="composited on the outline colour #272018", note="boot splash (set as application/boot_splash/image, background colour #272018)")


if __name__ == "__main__":
    load_registry()
    glyphs = build_items()
    build_fonts(glyphs)
    build_fx()
    build_ui(glyphs)
    save_registry()
    print("items/ui/fx done")

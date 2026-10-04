"""Liquids, props, interactive objects and parallax backgrounds.

Sources: Superpowers "Prehistoric Platformer" (Pixel-boy, CC0) for everything in this file.
Edits: biome variants are palette recolours (per unique colour); parallax layers are cropped to the
640x360 viewport, pre-positioned vertically and made seamless by mirroring (image + mirrored image).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *  # noqa
from components import components
from props_def import PROPS
from build_tiles import ts, lum_ramp, OBSIDIAN, FROST_ROCK, CANDY

SRC_TS = "superpowers-prehistoric-platformer: background-elements/tileset-1.png"
DARK = (39, 32, 24)


# ----------------------------------------------------------------------------- recolours for props
def keep_dark(fn):
    def g(r, gg, b):
        if (r, gg, b) == DARK:
            return DARK
        return fn(r, gg, b)
    return g


def _hsv(r, g, b):
    return colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)


def _rgb(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, min(1, max(0, s)), min(1, max(0, v)))
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))


_SNOW = ramp_fn([(96, 128, 172), (150, 184, 216), (206, 226, 242), (250, 252, 255)], 40, 140)


def ice_prop(r, g, b):
    """greens -> snow ramp (by luminance), browns / tans -> frost-blue rock, near-whites kept."""
    h, s, v = _hsv(r, g, b); hd = h * 360
    if (r, g, b) == DARK:
        return (30, 36, 60)
    if s < 0.12:
        return (r, g, b)
    if 60 <= hd <= 175:                       # foliage -> snow
        return _SNOW(r, g, b)
    return _rgb(212 / 360, s * 0.55, min(1.0, v * 1.08))


def volcano_prop(r, g, b):
    """greens -> scorched ember tones, tans -> dark basalt."""
    h, s, v = _hsv(r, g, b); hd = h * 360
    if (r, g, b) == DARK or s < 0.10:
        return (r, g, b)
    if 60 <= hd <= 175:
        return _rgb(18 / 360, 0.75, 0.25 + 0.6 * v)
    return _rgb((hd - 6) / 360, min(1.0, s * 0.9), v * 0.62)


CAVE_ROCK = [(39, 32, 24), (60, 46, 80), (96, 74, 124), (134, 110, 164), (160, 160, 214), (206, 214, 240)]
_CAVE = ramp_fn(CAVE_ROCK, 20, 245)


def cave_prop(r, g, b):
    """tan rock -> violet cave rock (luminance ramp built from the cave terrain colours)."""
    if (r, g, b) == DARK:
        return (r, g, b)
    return _CAVE(r, g, b)


def crystal(hue):
    def fn(r, g, b):
        if (r, g, b) == DARK:
            return (28, 30, 60)
        h, s, v = _hsv(r, g, b)
        lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
        return _rgb(hue / 360, 0.75 - 0.6 * lum, 0.45 + 0.55 * lum)
    return fn


# ----------------------------------------------------------------------------- props
def largest_island(im):
    """Return im with everything except its largest 8-connected alpha island made transparent."""
    a = np.array(im); m = a[..., 3] > 0
    H, W = m.shape; lab = np.zeros((H, W), np.int32); sizes = {}; cur = 0
    for sy in range(H):
        for sx in range(W):
            if m[sy, sx] and lab[sy, sx] == 0:
                cur += 1; n = 0; stack = [(sy, sx)]; lab[sy, sx] = cur
                while stack:
                    y, x = stack.pop(); n += 1
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = y + dy, x + dx
                            if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and lab[ny, nx] == 0:
                                lab[ny, nx] = cur; stack.append((ny, nx))
                sizes[cur] = n
    best = max(sizes, key=sizes.get)
    a[lab != best] = 0
    return Image.fromarray(a, "RGBA")


def cut_prop(rect, mode):
    t = ts()
    im = t.crop(rect)
    if mode == "big":
        im = largest_island(im)
    return im.crop(bbox(im))


BIOME_PROPS = {
    "jungle": ["vine_a", "vine_b", "grass_a", "grass_b", "sprouts", "grass_strip_dark", "grass_strip_light", "bush_dark",
               "bush_light", "bush_big", "fern", "flower", "rock_grass", "mound_grass", "mound_leafy", "vine_branch",
               "moss_fringe", "tree_canopy_dark", "tree_canopy_light", "tree_trunk", "tree_trunk_small", "treetop_stack",
               "foliage_block", "foliage_clump", "rock_big", "boulders", "egg_nest", "egg_nest_broken", "skull_big",
               "root_arch", "leaf"],
    "cave": ["stalactite", "drips", "drip_cap", "boulders", "rock_big", "boulder_tan", "rocks_small", "pebble", "mushrooms",
             "skull_big", "skull_buried", "skull_ribs", "bone_big", "bone_pile", "tusk_a", "tusk_b", "tusk_c", "tusk_d",
             "cave_hole_a", "cave_hole_b", "cave_hole_c", "rock_ridge", "mound_brown", "mound_small", "twigs", "grave_cross",
             "gravestone", "critter_shadow", "root_arch", "cave_mouth"],
    "ice": ["stalactite", "boulders", "rock_big", "rocks_small", "bush_dark", "bush_big", "grass_a", "sprouts", "dead_tree",
            "tree_canopy_dark", "tree_trunk", "rock_ridge", "mound_brown", "skull_buried", "tusk_a", "tusk_b", "tusk_c",
            "cave_mouth", "fern"],
    "volcano": ["stalactite", "drips", "drip_cap", "boulders", "rock_big", "rocks_small", "dead_tree", "rock_ridge",
                "mound_brown", "mound_small", "skull_big", "skull_buried", "skull_ribs", "bone_big", "bone_pile", "tusk_a",
                "tusk_b", "twigs", "grave_cross", "gravestone", "cave_hole_c", "boulder_orange", "bush_dark", "grass_a"],
    "village": ["hut_bone", "hut_dome", "watchtower", "stone_house", "palisade", "fence", "flower_pot", "bench", "barrel",
                "crate", "sign_wood", "stone_tablet", "signpost", "clay_pot", "sand_block", "boulder_sand", "boulder_sand_small"],
}
BIOME_FN = {"jungle": None, "cave": None, "ice": ice_prop, "volcano": volcano_prop, "village": None}
KEEP_ORIGINAL = {"cave": {"skull_big", "skull_buried", "skull_ribs", "bone_big", "bone_pile", "tusk_a", "tusk_b", "tusk_c",
                          "tusk_d", "mushrooms", "cave_hole_a", "cave_hole_b", "cave_hole_c", "critter_shadow"},
                 "volcano": {"skull_big", "skull_buried", "skull_ribs", "bone_big", "bone_pile", "tusk_a", "tusk_b",
                             "boulder_orange"},
                 "ice": {"skull_buried"}}


def build_props():
    cut = {name: cut_prop(rect, mode) for name, rect, mode, grp in PROPS}
    for biome, names in BIOME_PROPS.items():
        fn = BIOME_FN[biome]
        if biome == "cave":
            fn = None
        for n in names:
            im = cut[n]
            edits = "cut out of the tileset"
            if fn and n not in KEEP_ORIGINAL.get(biome, ()):
                im = remap(im, fn); edits += "; palette recoloured for the %s biome" % biome
            elif biome == "cave" and n in ("boulders", "rock_big", "boulder_tan", "rocks_small", "pebble", "rock_ridge",
                                           "mound_brown", "mound_small", "stalactite", "drips", "drip_cap"):
                im = remap(im, cave_prop); edits += "; gradient-mapped to the violet cave rock"
            save(im, "tiles/%s/props/%s.png" % (biome, n), kind="prop", frame=list(im.size), grid=[1, 1],
                 pivot=[im.width // 2, im.height], source=SRC_TS, edits=edits)
    # crystals (cave + ice): recoloured ivory tusks
    for i, n in enumerate(["tusk_a", "tusk_b", "tusk_c", "tusk_d"]):
        for biome, hue in (("cave", 285), ("cave", 185), ("ice", 200)):
            im = remap(cut[n], crystal(hue))
            tag = {285: "violet", 185: "cyan", 200: "ice"}[hue]
            save(im, "tiles/%s/props/crystal_%s_%s.png" % (biome, tag, "abcd"[i]), kind="prop", frame=list(im.size), grid=[1, 1],
                 pivot=[im.width // 2, im.height], source=SRC_TS, edits="tusk prop gradient-mapped to a crystal ramp")
    # icicle and lava drip
    im = remap(vflip(vflip(cut["stalactite"])), crystal(200))
    save(im, "tiles/ice/props/icicle.png", kind="prop", frame=list(im.size), grid=[1, 1], pivot=[im.width // 2, 0],
         source=SRC_TS, edits="stalactite gradient-mapped to ice", note="hangs from the ceiling: pivot = top centre")
    return cut


# ----------------------------------------------------------------------------- liquids
WATER = (50, 141, 166)
LAVA_MAP = {(50, 141, 166): (206, 66, 26), (79, 160, 180): (240, 120, 36), (150, 192, 198): (255, 178, 60),
            (167, 201, 205): (255, 178, 60), (255, 246, 229): (255, 236, 130), (255, 242, 229): (255, 236, 130)}
ICEW_MAP = {(50, 141, 166): (44, 84, 150), (79, 160, 180): (70, 120, 180), (150, 192, 198): (150, 190, 226),
            (167, 201, 205): (150, 190, 226)}


def build_liquids():
    fxw = grid_cells(sp("fx/effects/water.png"), 6, 1)        # 32 x 9 surface frames
    body = canvas(32, 32, WATER + (255,))
    bubbles = ts().crop((752, 288, 784, 320))
    frames = []
    for k in range(6):
        f = canvas(32, 32)
        f.alpha_composite(canvas(32, 28, WATER + (255,)), (0, 4))
        f.alpha_composite(fxw[k], (0, 0))
        frames.append(f)
    frames += [body, bubbles]
    sheet = strip(frames, cols=8)
    meta = dict(kind="liquid", frame=[32, 32], grid=[8, 1],
                anims={"surface": anim(range(6), 8)},
                tiles_inline={"0-5": "animated surface (top of a pool; the top 4 px are air)", "6": "body, plain", "7": "body with bubbles"},
                source="superpowers-prehistoric-platformer: fx/effects/water.png + tileset-1.png water tile")
    save(sheet, "tiles/common/water.png", edits="surface frames composited over the body colour", note="deadly pit surface in jungle / cave", **meta)
    save(color_swap(sheet, LAVA_MAP), "tiles/common/lava.png", edits="water recoloured to lava (exact colour swap)", note="deadly; volcano biome", **meta)
    save(color_swap(sheet, ICEW_MAP), "tiles/common/ice_water.png", edits="water recoloured to deep cold blue", note="deadly; ice biome (leaper pits)", **meta)


# ----------------------------------------------------------------------------- interactive objects
def build_objects(cut):
    O = "sprites/objects/"
    S = "superpowers-prehistoric-platformer: "
    # spring (the original has none; optional extra) -----------------------------------------
    b = sp("background-elements/bumper.png")
    save(b, O + "spring.png", kind="object", frame=[64, 26], grid=[5, 1], pivot=[32, 26],
         anims={"idle": anim([0], 1, False), "bounce": anim([1, 2, 3, 4, 0], 16, False)},
         source=S + "background-elements/bumper.png", edits="none", note="optional spring pad (not in the original game)")
    # breakable block ------------------------------------------------------------------------
    fb = grid_cells(sp("background-elements/fragile-block.png"), 9, 1)[:8]
    def brk(fn, name, note):
        fr = [remap(f, fn) if fn else f for f in fb]
        save(strip(fr), O + name, kind="object", frame=[40, 44], grid=[8, 1], pivot=[19, 32],
             anims={"idle": anim([0], 1, False), "crack": anim([1, 2, 3], 1, False), "break": anim([4, 5, 6, 7], 14, False)},
             source=S + "background-elements/fragile-block.png", edits="last empty frame dropped" + ("; recoloured" if fn else ""),
             note=note + "; the solid block is the 32x32 area at x 3..35, y 0..32 of the cell")
    brk(None, "breakable_block.png", "breakable block (GAMEPLAY 4.4), dirt look for jungle / cave / volcano; crack frames = hit feedback")
    brk(keep_dark(lum_ramp(CAVE_ROCK)), "breakable_block_cave.png", "breakable block, violet cave rock look")
    brk(keep_dark(lum_ramp(FROST_ROCK)), "breakable_block_ice.png", "breakable block, ice look")
    brk(keep_dark(lum_ramp(OBSIDIAN)), "breakable_block_obsidian.png", "breakable block, obsidian look")
    # checkpoint campfire --------------------------------------------------------------------
    unlit = sp("background-elements/fire.png"); lit = grid_cells(sp("background-elements/fire-meat.png"), 4, 1)
    u = canvas(84, 55); u.alpha_composite(unlit, (0, 55 - unlit.height))
    save(strip([u] + lit), O + "checkpoint.png", kind="object", frame=[84, 55], grid=[5, 1], pivot=[42, 55],
         anims={"off": anim([0], 1, False), "on": anim([1, 2, 3, 4], 8)},
         source=S + "background-elements/fire.png + fire-meat.png", edits="unlit spit padded into the 84x55 cell of the lit frames",
         note="restart point (GAMEPLAY 7.6): off until touched, then on")
    # chest (100 000 point jackpot / treasure) -----------------------------------------------
    save(sp("items/chest.png"), O + "chest.png", kind="object", frame=[60, 36], grid=[4, 1], pivot=[24, 36],
         anims={"closed": anim([0], 1, False), "open": anim([1, 2, 3], 10, False)}, source=S + "items/chest.png", edits="none",
         note="jackpot chest dropped when the bonus word is completed")
    # platforms ------------------------------------------------------------------------------
    plank = pad_to(cut["wood_platform"], 96, 16, 0.5, 0.0)
    for name, fn, note in (("platform_wood.png", None, "moving / drop platform, jungle + cave"),
                           ("platform_ice.png", keep_dark(lum_ramp(FROST_ROCK)), "moving / drop platform, ice"),
                           ("platform_stone.png", keep_dark(lum_ramp(OBSIDIAN)), "moving / drop platform, volcano")):
        im = remap(plank, fn) if fn else plank
        save(im, O + name, kind="object", frame=[96, 16], grid=[1, 1], pivot=[48, 0], source=SRC_TS,
             edits="cut out, padded to 96x16" + ("; recoloured" if fn else ""), note=note + "; stand-on surface = top edge, 96 art px (48 logical) wide")
    hp = cut["wood_platform_hanging"]
    save(pad_to(hp, 64, 28, 0.5, 0.0), O + "platform_small.png", kind="object", frame=[64, 28], grid=[1, 1], pivot=[32, 0],
         source=SRC_TS, edits="cut out, padded to 64x28", note="small bracket platform (moving or static)")
    # ladders, sign, gate, boulder -----------------------------------------------------------
    for n, out, note in (("ladder_wood", "ladder_wood.png", "wooden ladder segment; stack copies vertically with a 2 px overlap"),
                         ("ladder_stone", "ladder_stone.png", "stone ladder segment"),
                         ("signpost", "signpost.png", "direction sign"), ("sign_wood", "sign_board.png", "hint board"),
                         ("stone_tablet", "code_stone.png", "collectible lore 'code stone' (GAMEPLAY 12.4)"),
                         ("root_arch", "gate_arch.png", "gate / door: stand in front and press Down (GAMEPLAY 7.5)"),
                         ("cave_hole_b", "gate_hole.png", "gate / secret passage opening"),
                         ("boulder_orange", "boulder.png", "rolling boulder / heavy projectile"),
                         ("barrel", "barrel.png", "breakable barrel (bonus container)"), ("crate", "crate.png", "breakable crate"),
                         ("clay_pot", "pot.png", "breakable pot"), ("carved_block", "carved_block.png", "carved stone block (totem piece)")):
        im = cut[n]
        save(im, O + out, kind="object", frame=list(im.size), grid=[1, 1], pivot=[im.width // 2, im.height], source=SRC_TS,
             edits="cut out of the tileset", note=note)
    # exit totem -----------------------------------------------------------------------------
    blk = cut["carved_block"]; flame = cut["fire_small"]; twigs = cut["twigs"]
    def totem(top):
        c = canvas(40, 88)
        c.alpha_composite(blk, (4, 56)); c.alpha_composite(blk, (4, 26))
        if top is not None:
            c.alpha_composite(top, (20 - top.width // 2, 28 - top.height))
        return c
    green = remap(flame, hsv_fn(dh=0.30, sm=1.0))
    fr = [totem(twigs), totem(flame), totem(flip(flame)), totem(green), totem(flip(green))]
    save(strip(fr), O + "exit_totem.png", kind="object", frame=[40, 88], grid=[5, 1], pivot=[20, 88],
         anims={"cold": anim([0], 1, False), "locked": anim([1, 2], 6), "open": anim([3, 4], 6)},
         source=SRC_TS + " (carved block, small fire, twigs)",
         edits="two carved blocks stacked, kindling / flame placed on top; green flame = hue shift; flicker = mirrored flame",
         note="level exit (the original's traffic light, GAMEPLAY 7.6): locked = red flame until the fire-starter is collected, open = green flame")
    # boss / hazard projectiles ---------------------------------------------------------------
    ball = pad_to(cut["stone_ball"], 22, 22, 0.5, 0.5)
    save(strip([ball.rotate(-90 * k) for k in range(4)]), "sprites/fx/projectile_rock.png", kind="fx", frame=[22, 22], grid=[4, 1],
         pivot=[11, 11], anims={"spin": anim(range(4), 12)}, source=SRC_TS, edits="4 lossless 90 degree rotations",
         note="rock spat by the Wall Colossus")
    st = remap(cut["stalactite"], keep_dark(lum_ramp(OBSIDIAN)))
    save(st, "sprites/fx/projectile_stalactite.png", kind="fx", frame=list(st.size), grid=[1, 1], pivot=[st.width // 2, st.height],
         source=SRC_TS, edits="recoloured to obsidian", note="ceiling drop of the Wall Colossus (the original's chandelier)")
    leaf = cut["leaf"]; ember = remap(leaf, lambda r, g, b: (r, g, b) if (r, g, b) == DARK else ramp_fn([(120, 30, 20), (230, 90, 30), (255, 200, 80)], 40, 200)(r, g, b))
    save(strip([leaf, flip(leaf)]), "sprites/fx/falling_leaf.png", kind="fx", frame=list(leaf.size), grid=[2, 1], pivot=[leaf.width // 2, leaf.height // 2],
         anims={"sway": anim([0, 1], 4)}, source=SRC_TS, edits="mirrored second frame", note="falling leaf hazard (GAMEPLAY 6.2)")
    save(strip([ember, flip(ember)]), "sprites/fx/falling_ember.png", kind="fx", frame=list(leaf.size), grid=[2, 1], pivot=[leaf.width // 2, leaf.height // 2],
         anims={"sway": anim([0, 1], 6)}, source=SRC_TS, edits="leaf gradient-mapped to ember colours, mirrored second frame",
         note="falling ember hazard in the volcano shaft")
    # hazards as sprites -----------------------------------------------------------------------
    bs = cut["bone_spikes"]
    save(pad_to(bs, 128, 32, 0.5, 1.0), O + "bone_spikes.png", kind="object", frame=[128, 32], grid=[1, 1], pivot=[64, 32], source=SRC_TS,
         edits="cut out, padded to 128x32", note="deadly spike bed, exactly 4 tiles wide (deadly from top and sides); can also be cut into four 32 px tiles")
    # glider -----------------------------------------------------------------------------------
    wing = sp("items/43.png")
    w = trim(wing)
    g = canvas(2 * w.width + 4, w.height + 6)
    g.alpha_composite(flip(w), (0, 0)); g.alpha_composite(w, (w.width + 4, 0))
    pole = sp("items/24.png")           # bamboo pole 9x37
    pr, piv = rotate_px(pole, 90)
    pr = trim(pr)
    gl = canvas(g.width, g.height + 10)
    gl.alpha_composite(g, (0, 0))
    gl = over(gl, pr, (g.width // 2 - pr.width // 2, g.height - 6))
    save(gl, O + "glider.png", kind="object", frame=list(gl.size), grid=[1, 1], pivot=[gl.width // 2, gl.height],
         source=S + "items/43.png (wing) + items/24.png (pole)", edits="wing mirrored into a pair, bamboo pole rotated 90 degrees and placed as the grip bar",
         note="hang-glider overlay: draw above the hero's 'glide' frames with its pivot at the hero's raised hands (about 50 art px above the feet)")
    icon = canvas(40, 40); small = wing
    icon.alpha_composite(small, (2, 3))
    save(icon, "sprites/items/glider_pickup.png", kind="item", frame=[40, 40], grid=[1, 1], pivot=[20, 40],
         source=S + "items/43.png", edits="padded to 40x40", note="hang-glider pick-up")


# ----------------------------------------------------------------------------- backgrounds
def seamless(im):
    out = canvas(im.width * 2, im.height)
    out.alpha_composite(im, (0, 0)); out.alpha_composite(flip(im), (im.width, 0))
    return out


def layer(rel, top, crop=None, fn=None, mirror=True, h=360):
    im = sp("background-elements/" + rel)
    if crop:
        im = im.crop(crop)
    if fn:
        im = remap(im, fn)
    out = canvas(im.width, h)
    out = over(out, im, (0, top))
    return seamless(out) if mirror else out


def flat(color):
    return lambda r, g, b: color


def build_backgrounds():
    Bg = "backgrounds/"
    S = "superpowers-prehistoric-platformer: background-elements/"

    def put(biome, name, im, factor, src, edits, note=""):
        save(im, Bg + "%s/%s.png" % (biome, name), kind="background", frame=list(im.size), grid=[1, 1], scroll=factor,
             source=S + src, edits=edits, note=note)

    E = "cropped / positioned on a 360 px high canvas, mirrored copy appended for a seamless 1600 px loop"
    # ---- jungle
    put("jungle", "layer0_sky", layer("sky-1.png", 0, (0, 60, 800, 420)), 0.0, "sky-1.png", E)
    put("jungle", "layer1_far_hills", layer("mountain-3.png", 120), 0.1, "mountain-3.png", E)
    put("jungle", "layer2_hills", layer("mountain-2.png", 168, fn=hsv_fn(dh=-0.06, sm=0.9, vm=0.92)), 0.25, "mountain-2.png", E + "; slight hue shift toward green")
    put("jungle", "layer3_forest", layer("forest-1.png", 178), 0.5, "forest-1.png", E)
    # ---- cave
    tex = sp("background-elements/rock-1.png")
    wall = canvas(720, 360)
    for i in range(3):
        for j in range(2):
            wall.alpha_composite(tex, (i * 240, j * 240 - 60))
    put("cave", "layer0_wall", remap(wall, ramp_fn([(30, 24, 44), (46, 38, 66), (58, 48, 82)], 60, 110)), 0.1, "rock-1.png",
        "tiled 3 x 2, gradient-mapped to dark violet (720 px loop)")
    r2 = sp("background-elements/rock-2.png")
    mid = canvas(800, 360)
    mid = over(mid, r2.crop((0, 0, 800, 200)), (0, -50)); mid = over(mid, r2.crop((0, 400, 800, 600)), (0, 230))
    put("cave", "layer1_rocks_far", seamless(remap(mid, ramp_fn([(54, 44, 80), (72, 60, 104), (92, 78, 128)], 100, 160))), 0.3, "rock-2.png",
        "ceiling and floor bands moved closer together, gradient-mapped to violet, mirrored for a seamless loop")
    near = canvas(800, 360); near = over(near, sp("background-elements/rock-3.png"), (0, -70))
    put("cave", "layer2_ceiling_near", seamless(remap(near, ramp_fn([(24, 18, 34), (34, 26, 48), (44, 34, 62)], 100, 160))), 0.6, "rock-3.png",
        "positioned at the top, gradient-mapped to near-black violet, mirrored for a seamless loop")
    # ---- ice
    put("ice", "layer0_sky", layer("sky-1.png", 0, (0, 60, 800, 420), fn=hsv_fn(sm=0.55, vm=1.0, dh=0.02)), 0.0, "sky-1.png", E + "; desaturated to a winter sky")
    put("ice", "layer1_far_peaks", layer("mountain-3.png", 96, fn=flat((214, 232, 248))), 0.1, "mountain-3.png", E + "; recoloured to snow white-blue")
    put("ice", "layer2_ridges", layer("mountain-1.png", 150, fn=ramp_fn([(96, 128, 170), (140, 172, 206), (188, 212, 234), (236, 244, 250)], 110, 200)), 0.25,
        "mountain-1.png", E + "; gradient-mapped to frosted rock")
    put("ice", "layer3_snow_forest", layer("forest-1.png", 190, fn=ramp_fn([(30, 44, 78), (52, 78, 122), (110, 150, 190), (196, 222, 240), (244, 250, 254)], 40, 160)), 0.5,
        "forest-1.png", E + "; gradient-mapped to a snow-covered forest")
    # ---- volcano (exterior, dusk)
    put("volcano", "layer0_sky", layer("sky-2.png", 0, (0, 150, 800, 510), fn=hsv_fn(dh=-0.025, sm=1.05, vm=0.82)), 0.0, "sky-2.png", E + "; darkened and pushed toward red")
    put("volcano", "layer1_far_cones", layer("mountain-3.png", 110, fn=flat((122, 44, 48))), 0.1, "mountain-3.png", E + "; recoloured to a dark red silhouette")
    put("volcano", "layer2_basalt", layer("mountain-1.png", 160, fn=ramp_fn([(48, 26, 34), (72, 34, 38), (104, 46, 40), (150, 70, 44)], 110, 200)), 0.25,
        "mountain-1.png", E + "; gradient-mapped to basalt")
    put("volcano", "layer3_burnt_forest", layer("forest-1.png", 196, fn=ramp_fn([(24, 16, 20), (44, 22, 24), (84, 30, 26), (150, 54, 28), (224, 110, 36)], 40, 160)), 0.5,
        "forest-1.png", E + "; gradient-mapped to a scorched, glowing forest")
    # ---- volcano interior (shaft / keep)
    put("volcano", "shaft_layer0_wall", remap(wall, ramp_fn([(40, 16, 20), (64, 24, 24), (86, 34, 28)], 60, 110)), 0.1, "rock-1.png",
        "tiled 3 x 2, gradient-mapped to dark red (720 px loop)", "interior set for Cinder Shaft / Obsidian Keep")
    put("volcano", "shaft_layer1_rocks", seamless(remap(mid, ramp_fn([(70, 28, 30), (104, 42, 34), (140, 60, 38)], 100, 160))), 0.3, "rock-2.png",
        "ceiling and floor bands moved closer together, gradient-mapped to hot rock, mirrored", "interior set")
    put("volcano", "shaft_layer2_ceiling_near", seamless(remap(near, ramp_fn([(26, 12, 16), (40, 16, 18), (54, 22, 22)], 100, 160))), 0.6, "rock-3.png",
        "gradient-mapped to near-black red, mirrored", "interior set")
    # ---- feast (bonus stages)
    put("feast", "layer0_sky", layer("sky-3.png", 0, (0, 0, 800, 360), fn=hsv_fn(set_h=0.93, sm=0.45, vm=1.0)), 0.0, "sky-3.png", E + "; hue set to candy pink")
    put("feast", "layer1_clouds", layer("cloud-1.png", 60, fn=hsv_fn(set_h=0.10, sm=1.6, vm=1.0)), 0.08, "cloud-1.png", E + "; tinted cream")
    put("feast", "layer2_scoops", layer("mountain-2.png", 170, fn=ramp_fn([(236, 150, 170), (250, 190, 200), (255, 222, 214), (255, 244, 232)], 150, 190)), 0.25,
        "mountain-2.png", E + "; gradient-mapped to strawberry ice-cream scoops")
    put("feast", "layer3_meadow", layer("grass-2.png", 250, fn=ramp_fn([(120, 190, 150), (160, 220, 170), (200, 240, 190)], 140, 180)), 0.5,
        "grass-2.png", E + "; gradient-mapped to mint")
    # ---- title / map backdrops
    t1 = sp("background-elements/background-2.png").crop((0, 120, 800, 480))
    save(t1.crop((80, 0, 720, 360)), "ui/title_background.png", kind="ui", frame=[640, 360], grid=[1, 1], source=S + "background-2.png",
         edits="cropped to 640x360", note="title screen / main menu backdrop")
    sea = canvas(1280, 360)
    sky = sp("background-elements/sky-1.png").crop((0, 60, 800, 420)); sea_im = sp("background-elements/sea-1.png"); isl = sp("background-elements/island-1.png")
    for x in (0, 800):
        sea.alpha_composite(sky.crop((0, 0, min(800, 1280 - x), 360)), (x, 0))
        sea.alpha_composite(sea_im.crop((0, 0, min(800, 1280 - x), 215)), (x, 150))
    sea = over(sea, isl, (60, 118)); sea = over(sea, flip(isl), (620, 150))
    save(sea, "ui/world_map_background.png", kind="ui", frame=[1280, 360], grid=[1, 1], source=S + "sky-1.png + sea-1.png + island-1.png",
         edits="sky, sea and island layers composited into a two-screen-wide panorama",
         note="world map backdrop (GAMEPLAY 11.1 step 6); place level markers on the islands")


if __name__ == "__main__":
    load_registry()
    cut = build_props()
    build_liquids()
    build_objects(cut)
    build_backgrounds()
    save_registry()
    print("env done")

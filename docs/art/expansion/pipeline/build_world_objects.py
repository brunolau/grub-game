"""Object skins for Book II worlds 6-9 asked by objects-A in phase 2 (wf8_objects_a_to_art_a.txt #1; DESIGN A.3):

    sprites/objects/platform_cloud.png      drop / crumbling clouds (9-1, 9-2; the `sky` default), platform layout
    sprites/objects/platform_driftwood.png  driftwood drop floes (7-2; the `coast` default), platform layout
    sprites/objects/spring_cap.png          a glowing mushroom-cap spring (6-2 Spore Hollow), spring.png layout
    sprites/objects/drum_cap.png            twin drums made of glowing caps (6-2 co-op), drum.png layout
    sprites/objects/coconut.png             the Clubball coconut and the golden one (objects-B's coconut.gd layout)

Sources (all CC0): shipped 1.0 objects (platform_wood.png, spring.png, drum.png - Superpowers Prehistoric Platformer,
Pixel-boy, via the 1.0 pipeline), the anchor pack's cloud-1.png tones, art-B's 2.0 palettes (tiles/coast/props/
driftwood_log.png, tiles/swamp/props/glowcap_big.png). Exact colour swaps keep each layout, alpha and pivot; the cloud is
drawn by the pipeline in the platform's outline box.
"""
import numpy as np
from PIL import Image

from xcommon import OUTLINE, asset, colours, rgb, save, swap, anim
from build_coop_objects import grow, rim, paint, shape_mask

# platform_wood.png -> sun-bleached driftwood (art-B's coast BLEACH ramp, tiles/coast/props/driftwood_log.png)
DRIFTWOOD = {"#332213": "#3e2c22", "#582d12": "#7a6049", "#63513a": "#876c53", "#7f3910": "#a18667",
             "#9d4829": "#ac9170", "#f1b043": "#d3bb98"}
# spring.png (an orange pad) -> a glowing teal mushroom cap (art-B's glowcap colours)
SPRING_CAP = {"#63513a": "#1e5b5f", "#ab542c": "#257273", "#f8561f": "#3ca8a1", "#ff7c31": "#44b6ad",
              "#ffa544": "#91eedb"}


def exact(src_rel, table):
    src = asset(src_rel)
    missing = [c for c in colours(src) if "#%02x%02x%02x" % c not in table and c != OUTLINE]
    assert not missing, "unmapped colours in %s: %s" % (src_rel, missing)
    return swap(src, {rgb(k): rgb(v) for k, v in table.items()})


def build_driftwood():
    im = exact("sprites/objects/platform_wood.png", DRIFTWOOD)
    save(im, "sprites/objects/platform_driftwood.png", kind="object", frame=[96, 16], grid=[1, 1], pivot=[48, 0],
         section="objects",
         source="shipped sprites/objects/platform_wood.png; the colours of art-B's tiles/coast/props/driftwood_log.png",
         edits="exact swaps of the six wood colours to the coast's sun-bleached driftwood ramp (outline #3e2c22, the "
               "bands' gold -> the pale #d3bb98)",
         note="driftwood drop floe (`objects/platform` default skin of the `coast` biome, 7-2 Sea Caves; objects-A "
              "platform_skin.gd): the layout of platform_wood.png, 96 x 16, pivot (48, 0) = top centre = the standing "
              "surface (box 48 x 8 logical)")
    return im


def cloud_platform():
    """a flat-topped storm-white cloud slab, bumpy underneath, in the platform's 96 x 16 box"""
    W, H = 96, 16
    a = np.zeros((H, W, 4), np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    m = (yy >= 1) & (yy <= 8) & (xx >= 3) & (xx <= W - 4)
    for cx, cy, r in ((8, 7, 6.5), (22, 9, 6.5), (37, 10, 5.5), (50, 9, 6.5), (64, 10, 5.5), (77, 9, 6.5),
                      (88, 7, 6.5)):
        m |= ((xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2 <= r * r) & (yy >= 1)
    m &= yy <= H - 2
    out = grow(m, 1) & ~m
    paint(a, out, rgb("#4e5372"))                    # the storm slate of the Far Shore's cloud (soft outline)
    paint(a, m, rgb("#e6fcff"))                       # cloud-1.png's three tones
    paint(a, m & (yy >= 9), rgb("#cbf3ff"))
    paint(a, m & rim(m, 1) & (yy >= 8), rgb("#9fb5cf"))
    paint(a, m & (yy <= 3) & ~rim(m, 1), rgb("#fcffff"))
    for x in range(10, W - 10, 13):                   # a few light puffs on the top edge
        a[1, x:x + 4] = rgb("#fcffff") + (255,)
    return Image.fromarray(a, "RGBA")


def build_cloud():
    im = cloud_platform()
    save(im, "sprites/objects/platform_cloud.png", kind="object", frame=[96, 16], grid=[1, 1], pivot=[48, 0],
         section="objects",
         source="drawn by the pipeline in the three tones of superpowers-prehistoric-platformer: background-elements/"
                "cloud-1.png (#fcffff, #e6fcff, #cbf3ff) with a slate outline",
         edits="a flat-topped cloud slab (top row = the standing surface) with seven round puffs underneath, lit top, "
               "blue-white underside, a soft #4e5372 outline (clouds do not take the brown outline)",
         note="drop / crumbling cloud (`objects/platform` default skin of the `sky` biome, 9-1 Cloudbreak Climb, 9-2 "
              "The Roc's Spire): the layout of platform_wood.png, 96 x 16, pivot (48, 0) = top centre = the standing "
              "surface (box 48 x 8 logical)")
    return im


def build_spring_cap():
    im = exact("sprites/objects/spring.png", SPRING_CAP)
    a = np.array(im)
    # a few glowing spots on the cap of every frame (only on the cap's main colour)
    main = np.all(a[..., :3] == rgb("#3ca8a1"), axis=2) & (a[..., 3] > 0)
    for f in range(5):
        for dx, dy in ((22, 0), (34, -2), (44, 1)):
            x0 = f * 64 + dx
            col = np.nonzero(main[:, x0])[0]
            if len(col):
                y = int(col.min()) + 2 + dy if int(col.min()) + 2 + dy > col.min() else int(col.min()) + 1
                for yy in range(y, y + 2):
                    for xx in range(x0, x0 + 3):
                        if main[yy, xx]:
                            a[yy, xx] = rgb("#e0fff6") + (255,)
    im = Image.fromarray(a, "RGBA")
    save(im, "sprites/objects/spring_cap.png", kind="object", frame=[64, 26], grid=[5, 1], pivot=[32, 26],
         section="objects", anims={"idle": anim([0], 1, False), "bounce": anim([1, 2, 3, 4, 0], 16, False)},
         source="shipped sprites/objects/spring.png; the glowcap teals of art-B's tiles/swamp/props/glowcap_big.png",
         edits="exact swaps of the five pad colours to the glowcap teals (its light -> #91eedb), three #e0fff6 glow "
               "spots on the cap in every frame",
         note="glowing mushroom-cap spring (6-2 Spore Hollow: 'caps are springs'; objects-A spring.gd): exactly the "
              "layout of spring.png - 5 cells of 64 x 26, pivot (32, 26), idle 0, bounce 1, 2, 3, 4, 0 @16 fps")
    return im


def drum_cap_table(src):
    """drum.png colours -> glowing caps: the barrel browns -> the stem's dark teals, the hide top -> the cap, the
    crest's amber (unlit frames) -> mid teal, the crest's yellows / whites (lit frames) -> glow white-cyan"""
    t = {"#272018": "#272018", "#000000": "#272018", "#453221": "#173a3c",
         "#89361b": "#1e5b5f", "#a14f27": "#257273", "#b97235": "#2b8383", "#ad612e": "#257273",
         "#b3a178": "#3ca8a1", "#f4e49b": "#75ddcd", "#fffed9": "#e0fff6",
         "#d56d1d": "#267576", "#ef9016": "#44b6ad", "#f3aa39": "#4bc1b6",
         "#f7bf21": "#c6fff2", "#ffe94f": "#ffffff", "#ffffff": "#ffffff"}
    missing = ["#%02x%02x%02x" % c for c in colours(src) if "#%02x%02x%02x" % c not in t]
    assert not missing, "unmapped drum colours: %s" % missing
    return {rgb(k): rgb(v) for k, v in t.items()}


def build_drum_cap():
    src = asset("sprites/objects/drum.png")
    im = swap(src, drum_cap_table(src))
    save(im, "sprites/objects/drum_cap.png", kind="object", frame=[40, 44], grid=[5, 1], pivot=[20, 44],
         section="objects",
         anims={"idle": anim([0], 1, False), "hit": anim([1, 2, 0], 16, False), "lit": anim([3], 1, False),
                "lit_hit": anim([4, 3], 16, False)},
         source="shipped sprites/objects/drum.png (the 2.0 drum); the glowcap teals of art-B's tiles/swamp/props/"
                "glowcap_big.png",
         edits="exact swaps: barrel browns -> the cap stem's dark teals, the hide top -> the cap's teal and its "
               "pale glow, the crest's amber (unlit) -> mid teal, its yellows (lit frames 3-4) -> #91eedb / #c6fff2 "
               "/ white (clearly brighter in the dark); outlines #272018",
         note="twin drums made of glowing caps (6-2 Spore Hollow co-op; objects-A drum.gd): exactly the layout of "
              "drum.png - 5 cells of 40 x 44, pivot (20, 44), 0 idle, 1-2 struck, 3 lit (waiting for its bond "
              "partners), 4 struck while lit")
    return im


COCONUT = {"#141b1b": "#272018", "#d3a2c0": "#6b3f22", "#f2eaf1": "#9a5e32"}
GOLDEN = {"#141b1b": "#272018", "#d3a2c0": "#f3aa39", "#f2eaf1": "#ffe94f"}


def coconut_frames(table, eye, light):
    """Ninja Adventure's nut (Items/Food/Nut.png, 15 x 15) recoloured, three dark 'eyes' and a highlight added at 1x,
    turned by 0 / 90 / 180 / 270 degrees (lossless) for the roll, then integer 2x, centred in 32 x 32"""
    import os
    from xcommon import EXP
    src = Image.open(os.path.join(EXP, "pixelboy-ninja-adventure-full", "Ninja Adventure - Asset Pack", "Items",
                                  "Food", "Nut.png")).convert("RGBA")
    a = np.array(swap(src, {rgb(k): rgb(v) for k, v in table.items()}))
    for x, y in ((6, 3), (9, 3), (7, 5)):                         # the three eyes of a coconut
        a[y, x] = rgb(eye) + (255,)
    for x, y in ((3, 6), (3, 7), (4, 5)):                         # a highlight on the upper left
        a[y, x] = rgb(light) + (255,)
    frames = []
    for k in range(4):
        r = np.rot90(a, -k).copy()                                # clockwise: the roll to the right
        im = Image.fromarray(r, "RGBA").resize((30, 30), Image.NEAREST)
        cell = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        cell.alpha_composite(im, (1, 1))
        frames.append(cell)
    return frames


def build_coconut():
    from xcommon import strip
    frames = coconut_frames(COCONUT, "#3e2516", "#b8794a") + coconut_frames(GOLDEN, "#c97d10", "#fffed9")
    sheet = strip(frames, cols=4)
    save(sheet, "sprites/objects/coconut.png", kind="object", frame=[32, 32], grid=[4, 2], pivot=[16, 16],
         section="versus", rows=["coconut", "golden"], anims={"roll": anim([0, 1, 2, 3], 12, True)},
         source="pixelboy-ninja-adventure-full: Items/Food/Nut.png (DESIGN F.1: the coconut)",
         edits="exact swaps to coconut browns (golden row: the anchor's yellow / amber), the ink #141b1b -> #272018; "
               "three dark eyes and a 3 px highlight added at 1x; frames turned by 0 / 90 / 180 / 270 degrees "
               "(lossless) for the roll; integer 2x, centred in 32 x 32",
         note="the Clubball coconut (`objects/coconut`, E.4, GAMEPLAY 13.10.6; objects-B coconut.gd): 32 x 32 cells "
              "(the 16 x 16 logical box), 4 x 2: row 0 the coconut, row 1 the golden coconut of a tie ('next goal "
              "wins'), columns = the roll (clockwise quarter turns: step one column per ROLL_STEP_PX rolled, "
              "backwards when it rolls left). Pivot (16, 16) = the centre")
    return sheet


def build():
    return {"driftwood": build_driftwood(), "cloud": build_cloud(), "spring_cap": build_spring_cap(),
            "drum_cap": build_drum_cap(), "coconut": build_coconut()}


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()

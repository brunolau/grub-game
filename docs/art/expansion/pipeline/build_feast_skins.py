"""Feast Land D (Honey Falls) and Feast Land E (Pudding Lagoon) skins (DESIGN A.2 / A.3 rows 18-19, F.1; PLAN P2.11):
two terrain atlases in the common 40-tile layout and a handful of `props/feast/<name>` pictures. The liquids (honey,
syrup), the honey / syrup tar floors, the soda geyser and the wafer raft were built in phase 1 (17.3, 17.10).

    tiles/feast/terrain_honeycomb.png  wax and honey: shipped cave/terrain_stone.png's stones become comb cells
    tiles/feast/terrain_pudding.png    custard under a caramel top: shipped ice/terrain.png's snow becomes caramel
    tiles/feast/props/*.png            honey drips, a honeycomb chunk, the honey pot, jelly cubes, a pudding with a
                                       cherry, cherry piles, a cream swirl, wafer sticks

Sources (all CC0): shipped 1.0 terrain atlases and sprites (Superpowers Prehistoric Platformer, Pixel-boy, via the 1.0
pipeline); Ninja Adventure (Pixel-boy and AAA) Items/Food/Honey.png at integer 2x; the anchor pack's items 31 (red
berry). Exact colour swaps (the 40-tile layout, collision and alpha are untouched), crops and composites.
"""
import os

import numpy as np
from PIL import Image

from xcommon import AP, EXP, OUTLINE, asset, canvas, colours, load, rgb, save, swap, trim, flip
from build_coop_objects import grow, rim, paint, shape_mask

NA = os.path.join(EXP, "pixelboy-ninja-adventure-full", "Ninja Adventure - Asset Pack")
O4 = OUTLINE + (255,)

# cave/terrain_stone.png colour -> honeycomb (wax walls, honey cells, a drip-lit top)
HONEYCOMB = {
    "#542e1b": "#6b3208", "#7d4c38": "#94470b", "#775239": "#94470b", "#926749": "#b85d0c",
    "#8e639f": "#b85d0c", "#a8825a": "#e8951c", "#b08b63": "#f0a526", "#bfa077": "#f7b733",
    "#dfbc8c": "#ffd25a", "#f6d7ad": "#fff0a8", "#eb9630": "#d97a10", "#f9b638": "#ffc93c", "#ffd74f": "#ffe680",
}
# ice/terrain.png colour -> pudding (custard body, caramel where the snow lay, chocolate back wall)
PUDDING = {
    "#2b364c": "#3b2016", "#2c3d5f": "#4e2a1a", "#414459": "#61351f", "#354c71": "#61351f", "#4954e5": "#e0a040",
    "#542e1b": "#542e1b", "#7b391b": "#7b391b", "#c95326": "#c95326", "#e2722f": "#e2722f",
    "#8a8ebf": "#e9b456", "#81c0d4": "#ffd77a", "#8cbddf": "#ffe08e", "#b3dcfa": "#a3561e", "#ffffff": "#d9822e",
}


def terrain_skin(src_rel, table):
    return terrain_skin_im(asset(src_rel), table)


def terrain_skin_im(src, table):
    """exact swaps of every colour of a terrain atlas (an unmapped colour is an error; colours already in the
    target palette - the comb cells - stay)"""
    targets = {rgb(v) for v in table.values()} | {rgb(h) for h in ("#f7b733", "#e8951c", "#c46a12", "#ffe680")}
    missing = [c for c in colours(src) if "#%02x%02x%02x" % c not in table and c != OUTLINE and c not in targets]
    assert not missing, "unmapped colours: %s" % missing
    return swap(src, {rgb(k): rgb(v) for k, v in table.items() if rgb(k) not in targets})


def comb_cells(im, body):
    """a honeycomb over every pixel of colour `body`: the Voronoi cells of an offset 16 x 16 grid (period 32 both
    ways, so the 32 px tiles still join), pale wax walls, honey inside lit at the top and shaded at the bottom"""
    a = np.array(im).copy()
    on = np.all(a[..., :3] == body, axis=2) & (a[..., 3] > 0)
    h, w = on.shape
    yy, xx = np.mgrid[0:h, 0:w]
    lx, ly = (xx % 32) + 0.5, (yy % 32) + 0.5
    centres = [(cx + dx, cy) for cy, off in ((0, 0), (16, 8), (32, 0)) for cx in range(-16, 49, 16)
               for dx in (off,)]
    d = np.stack([np.hypot(lx - cx, ly - cy) for cx, cy in centres])
    srt = np.sort(d, axis=0)
    near = np.argmin(d, axis=0)
    cy_near = np.array([c[1] for c in centres])[near]
    wall = (srt[1] - srt[0]) < 1.6
    rel = ly - cy_near                                    # position in the cell: < 0 upper half
    out = a.copy()
    out[on & ~wall & (rel < -3)] = rgb("#f7b733") + (255,)
    out[on & ~wall & (rel >= -3) & (rel < 3)] = rgb("#e8951c") + (255,)
    out[on & ~wall & (rel >= 3)] = rgb("#c46a12") + (255,)
    out[on & wall] = rgb("#ffe680") + (255,)
    return Image.fromarray(out, "RGBA")


def build_terrains():
    hc = comb_cells(asset("tiles/cave/terrain_stone.png"), rgb("#a8825a"))
    hc = terrain_skin_im(hc, HONEYCOMB)
    save(hc, "tiles/feast/terrain_honeycomb.png", kind="terrain", frame=[32, 32], grid=[8, 5], section="feast",
         tiles="TERRAIN_TILES",
         source="shipped tiles/cave/terrain_stone.png (1.0: superpowers-prehistoric-platformer tileset-1.png)",
         edits="the stone body colour (#a8825a) replaced by a honeycomb (Voronoi cells of an offset 16 px grid with "
               "a period of 32, so tiles still join: pale wax walls, honey lit at the top and shaded at the bottom of "
               "each cell); every other colour by exact swaps (the stones' rims -> dark wax and amber, the sandy top "
               "-> a lit honey crust, the outline kept); layout, alpha and collision untouched",
         note="`terrain_a = feast/terrain_honeycomb` (Feast Land D: Honey Falls, A.3: honeycomb walls full of "
              "spots): the 40-tile layout and collision of section 10.1. Pairs with `liquid = honey` (the honey ':' "
              "floor) and the soda geyser")
    pd = terrain_skin("tiles/ice/terrain.png", PUDDING)
    save(pd, "tiles/feast/terrain_pudding.png", kind="terrain", frame=[32, 32], grid=[8, 5], section="feast",
         tiles="TERRAIN_TILES",
         source="shipped tiles/ice/terrain.png (1.0: superpowers-prehistoric-platformer tileset-1.png recoloured)",
         edits="exact colour swaps: snow -> caramel (#d9822e, its blue shade -> #a3561e), ice -> custard yellows, "
               "the dark back wall -> chocolate; the spike / block browns kept; layout, alpha and collision untouched",
         note="`terrain_a = feast/terrain_pudding` (Feast Land E: Pudding Lagoon, A.3): custard islands under a "
              "caramel top in the 40-tile layout and collision of section 10.1. Pairs with `liquid = syrup` and the "
              "wafer raft (sprites/objects/raft.png rows 2-3)")
    return hc, pd


# ---------------------------------------------------------------------------------------------------- props
HONEY = (rgb("#fff0a8"), rgb("#ffc93c"), rgb("#e8951c"), rgb("#b85d0c"))   # light, base, shade, dark


def outlined(a):
    m = a[..., 3] > 0
    a[grow(m, 1) & ~m] = O4
    return a


def honey_drips(variant):
    """honey running off a ledge: a crust strip with 2-3 hanging drops (hangs from the cell top)"""
    W, H = 32, 24 if variant == 0 else 30
    a = np.zeros((H + 2, W + 2, 4), np.uint8)
    yy, xx = np.mgrid[0:H + 2, 0:W + 2]
    m = (yy >= 1) & (yy <= 4) & (xx >= 1) & (xx <= W)
    drops = [(7, 14, 3), (19, 20, 3.5), (27, 9, 2.5)] if variant == 0 else [(10, 26, 3.5), (24, 15, 3)]
    for cx, length, r in drops:
        m |= (np.abs(xx - cx) <= r * 0.6) & (yy <= length - r)
        m |= (xx - cx) ** 2 + (yy - (length - r)) ** 2 <= r * r
    paint(a, m, HONEY[1])
    paint(a, m & (xx > np.roll(xx, 0)) & ((xx % 32) > 0) & rim(m, 1) & (yy > 3), HONEY[2])
    for cx, length, r in drops:
        a[int(length - r) - 1:int(length - r) + 1, cx - 1] = HONEY[0] + (255,)       # a glint on every drop
    paint(a, m & (yy <= 2), HONEY[0])
    a = outlined(a)
    a[0, :] = 0                                                                     # flush with the ledge
    return trim(Image.fromarray(a[:, 1:-1], "RGBA"))


def comb_chunk():
    """a broken piece of comb: a 3 x 2 cluster of hexagonal cells (wax walls, honey inside)"""
    W, H = 40, 30
    a = np.zeros((H, W, 4), np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    cells = [(8, 9), (20, 9), (32, 9), (14, 20), (26, 20)]
    wall = np.zeros((H, W), bool)
    fill = np.zeros((H, W), bool)
    for cx, cy in cells:
        hexm = (np.abs(xx - cx) * 0.866 + np.abs(yy - cy) * 0.5 <= 6.2) & (np.abs(yy - cy) <= 6)
        inner = (np.abs(xx - cx) * 0.866 + np.abs(yy - cy) * 0.5 <= 4.2) & (np.abs(yy - cy) <= 4)
        wall |= hexm
        fill |= inner
    paint(a, wall, rgb("#f7d77a"))
    paint(a, wall & (yy > 18), rgb("#e0b450"))
    paint(a, fill, HONEY[2])
    paint(a, fill & ((xx + yy) % 7 == 0), HONEY[1])
    for cx, cy in cells:
        a[cy - 3, cx - 2:cx] = HONEY[0] + (255,)
    a = outlined(np.pad(a, ((1, 1), (1, 1), (0, 0))))
    return trim(Image.fromarray(a, "RGBA"))


def honey_pot():
    """Ninja Adventure's honey pot at integer 2x, its dark ink -> the anchor outline"""
    im = load(os.path.join(NA, "Items", "Food", "Honey.png"))
    dark = [c for c in colours(im) if sum(c) < 120]
    im = swap(im, {c: OUTLINE for c in dark})
    im = trim(im)
    return im.resize((im.width * 2, im.height * 2), Image.NEAREST)


JELLY = {"pink": (rgb("#ffd2e0"), rgb("#f27aa5"), rgb("#c4457a")), "green": (rgb("#d8ffb0"), rgb("#7ad84a"),
                                                                                rgb("#3f9a2c"))}


def jelly_cubes(flavour):
    """two stacked jelly cubes (wobbly squares, translucent-looking light corner)"""
    l, b, s = JELLY[flavour]
    W, H = 30, 30
    a = np.zeros((H + 2, W + 2, 4), np.uint8)
    yy, xx = np.mgrid[0:H + 2, 0:W + 2]
    for x0, y0, w in ((2, 14, 17), (13, 5, 14), (17, 18, 14)):
        m = (xx >= x0) & (xx < x0 + w) & (yy >= y0) & (yy < y0 + w - 2)
        m &= ~(((xx == x0) | (xx == x0 + w - 1)) & ((yy == y0) | (yy == y0 + w - 3)))
        paint(a, grow(m, 1) & ~m & (a[..., 3] == 0), OUTLINE)
        paint(a, m, b)
        paint(a, m & ((xx >= x0 + w - 4) | (yy >= y0 + w - 5)), s)
        paint(a, m & (xx <= x0 + 3) & (yy <= y0 + 3), l)
        paint(a, (xx == x0 + 2) & (yy >= y0 + 5) & (yy <= y0 + 7), l)
    return trim(Image.fromarray(a, "RGBA"))


def pudding():
    """a flan: custard body, caramel cap running down, a cherry (anchor item 31) on top, on a wafer plate"""
    W, H = 44, 40
    a = np.zeros((H, W, 4), np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    body = (yy >= 12) & (yy < H - 4) & (np.abs(xx + 0.5 - W / 2) <= 14 + (yy - 12) * 0.25)
    cap = (yy >= 10) & (yy < 18) & (np.abs(xx + 0.5 - W / 2) <= 15)
    for dx, dl in ((-10, 24), (-2, 21), (7, 26), (12, 20)):
        cap |= (np.abs(xx - (W // 2 + dx)) <= 1) & (yy < dl) & (yy >= 12)
    plate_m = (yy >= H - 5) & (yy < H - 1) & (np.abs(xx + 0.5 - W / 2) <= 20)
    paint(a, grow(body | cap | plate_m, 1) & ~(body | cap | plate_m), OUTLINE)
    paint(a, body, rgb("#ffd77a"))
    paint(a, body & (xx > W // 2 + 6), rgb("#e9b456"))
    paint(a, body & (xx < W // 2 - 10) & (yy > 18), rgb("#ffe9a8"))
    paint(a, cap, rgb("#a3561e"))
    paint(a, cap & (yy <= 11), rgb("#d9822e"))
    paint(a, plate_m, rgb("#f3a950"))
    paint(a, plate_m & (yy == H - 5), rgb("#ffe0a0"))
    cherry = trim(load(os.path.join(AP, "items", "31.png")))
    im = Image.fromarray(a, "RGBA")
    im.alpha_composite(cherry, ((W - cherry.width) // 2, 11 - cherry.height + 2))
    return trim(im)


def cherry_pile():
    """a pile of the anchor's red berries (items/31), 6 of them"""
    c = trim(load(os.path.join(AP, "items", "31.png")))
    w, h = c.size
    out = canvas(w * 3 + 4, h * 2 + 2)
    for x, y in ((0, h), (w + 1, h), (2 * w + 2, h), (w // 2 + 1, h // 2 + 1), (w + w // 2 + 2, h // 2 + 1),
                 (w + 1, 1)):
        out.alpha_composite(c, (x, y - 1))
    return trim(out)


def cream_swirl():
    """a whipped-cream swirl (three tiers and a tip), for the pudding islands' tops"""
    W, H = 26, 24
    a = np.zeros((H, W, 4), np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    m = np.zeros((H, W), bool)
    for cy, half in ((19, 11), (13, 8), (8, 5)):
        m |= ((xx + 0.5 - W / 2) / half) ** 2 + ((yy + 0.5 - cy) / 4.0) ** 2 <= 1
    m |= (np.abs(xx + 0.5 - W / 2 - (yy < 5) * 1.5) <= 1.6) & (yy >= 2) & (yy < 7)
    paint(a, grow(m, 1) & ~m, rgb("#8a7d70"))
    paint(a, m, rgb("#fffaf0"))
    for cy, half in ((19, 11), (13, 8), (8, 5)):
        band = m & (np.abs(yy - (cy + 2)) <= 0) & (np.abs(xx + 0.5 - W / 2) <= half - 1)
        paint(a, band, rgb("#e6dccc"))
    paint(a, m & (xx > W // 2 + 3) & (yy > 9), rgb("#efe6d8"))
    return trim(Image.fromarray(a, "RGBA"))


def wafer_sticks():
    """three wafer rolls stuck in the ground at angles, in the wafer raft's biscuit colours"""
    W, H = 30, 36
    a = np.zeros((H, W, 4), np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    for x0, lean, top in ((6, -0.25, 2), (14, 0.0, 0), (22, 0.3, 6)):
        cx = x0 + (H - yy) * lean
        m = (np.abs(xx + 0.5 - cx) <= 2.6) & (yy >= top)
        paint(a, grow(m, 1) & ~m & (a[..., 3] == 0), OUTLINE)
        paint(a, m, rgb("#f3a950"))
        paint(a, m & (xx + 0.5 > cx + 0.8), rgb("#c4762a"))
        paint(a, m & ((yy - top) % 5 == 0), rgb("#ffd890"))
        paint(a, m & (np.abs(xx + 0.5 - cx) <= 1.0) & (yy <= top + 1), rgb("#6e3a1e"))   # the hollow end
    return trim(Image.fromarray(a, "RGBA"))


PROPS = [
    ("honey_drips_a", lambda: honey_drips(0), "honey running off a ledge: crust and three drops (hang it from the "
                                              "cell top under a ledge, `layer=front`)"),
    ("honey_drips_b", lambda: honey_drips(1), "honey drips, two long drops"),
    ("comb_chunk", comb_chunk, "a broken piece of honeycomb (five hexagonal cells)"),
    ("honey_pot", honey_pot, "the honey pot (Ninja Adventure Items/Food/Honey.png at 2x)"),
    ("jelly_pink", lambda: jelly_cubes("pink"), "three pink jelly cubes"),
    ("jelly_green", lambda: jelly_cubes("green"), "three lime jelly cubes"),
    ("pudding", pudding, "a caramel flan with a cherry on a wafer plate"),
    ("cherries", cherry_pile, "a pile of six red berries (anchor item 31)"),
    ("cream_swirl", cream_swirl, "a whipped-cream swirl"),
    ("wafer_sticks", wafer_sticks, "three wafer rolls stuck in the ground"),
]


def build_props():
    out = {}
    for name, fn, use in PROPS:
        im = fn()
        hang = name.startswith("honey_drips")
        src = {"honey_pot": "pixelboy-ninja-adventure-full: Items/Food/Honey.png",
               "pudding": "drawn by the pipeline; superpowers-prehistoric-platformer: items/31.png (the cherry)",
               "cherries": "superpowers-prehistoric-platformer: items/31.png"}.get(
            name, "drawn by the pipeline in the colours of the honey liquid, the pudding terrain and the wafer raft")
        edits = {"honey_pot": "the dark ink -> #272018, integer 2x",
                 "cherries": "six copies composited into a pile (1x)"}.get(
            name, "flat tones with a lit and a shaded side, 1 px #272018 outline (cream: a soft grey-brown edge)")
        save(im, "tiles/feast/props/%s.png" % name, kind="prop", section="feast",
             pivot=[im.width // 2, 0] if hang else [im.width // 2, im.height],
             source=src, edits=edits,
             note="`props/feast/%s` (Feast Land D / E dressing, A.3): %s; %s" % (
                 name, use, "pivot = top-centre (it hangs)" if hang else "pivot = bottom-centre on the floor"))
        out[name] = im
    return out


def build():
    return {"terrains": build_terrains(), "props": build_props()}


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()

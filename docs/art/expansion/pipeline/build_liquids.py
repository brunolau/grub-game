"""Book II liquids and the tar floor (DESIGN C.4 / F.1, PHYSICS C.5, ARCHITECTURE 7.11): `liquid = tar | honey | syrup`.

tiles/common/<liquid>.png        the deadly `~` strip in the exact format of the 1.0 water / lava / ice_water strips
                                 (256 x 32, 8 x 1: 0-5 animated surface, top 4 art px air; 6 body; 7 body with bubbles):
                                 an exact colour swap of the shipped water strip, as 1.0 built lava.png.
tiles/common/<liquid>_floor.png  the look of the ':' tar floor in that skin (256 x 32, 8 x 1). Tiles 0-3 have the
                                 meaning of art-B's tiles/canyon/mud_floor.png (0 top_left, 1 top, 2 top_right, 3 fill);
                                 4-6 are the optional front lip, 7 a fill variant with bubbles.

Source of the floor: the surface tiles 0, 1, 2 and the fill 9 of the shipped feast/terrain.png (the anchor's yellow sand
set: flat 4-colour bands, the smoothest ground of the kit), the surface tiles moved down 6 art px like mud_floor.png,
then an exact 4-colour swap into the goo ramp plus glossy dashes and bubble rings in the ramp's own colours.

Surface geometry (the same in every skin and in mud_floor.png): the drawn surface line is art row 6 of the cell; the
collision surface of ':' is art row 12 (PROFILE_TAR = 6 logical px under the cell top). A hero on tar therefore stands
6 art px deep in the goo. Drawing tiles 4-6 in the FRONT layer over 0-2 hides those 6 px of his feet behind the surface
band (ankle-deep); without them he stands in front of the goo. Both read; the lip is world-A's choice.
"""
import numpy as np
from PIL import Image

from xcommon import asset, canvas, colours, rgb, save, strip, swap, anim

# water strip colours (docs/art/pipeline/build_env.py: WATER, LAVA_MAP keys)
W_BODY, W_MID, W_LIGHT, W_LIGHT2, W_FOAM = (50, 141, 166), (79, 160, 180), (150, 192, 198), (167, 201, 205), \
    (255, 242, 229)
# feast/terrain.png ground colours (outline, base, mid band, light band)
F_OUT, F_BASE, F_MID, F_LIGHT = rgb("#86491c"), rgb("#eb9630"), rgb("#f9b638"), rgb("#ffd74f")

# per skin: outline, body, mid, light, shine (dark -> light; the shine is the foam / gloss colour)
SKINS = {
    "tar":   dict(outline="#1a1320", body="#2a2033", mid="#3b2e4a", light="#54436a", shine="#9d8bb5",
                  look="black-violet tar (world 6 Tar Fen, the rising tar of 6-2b, the Tar Pulleys arena)"),
    "honey": dict(outline="#7a3f0c", body="#d18b14", mid="#e9a91f", light="#f8cf45", shine="#fff3b0",
                  look="amber honey (Feast Land D: Honey Falls)"),
    "syrup": dict(outline="#6e1f3e", body="#b8406e", mid="#d45f8a", light="#ee93b3", shine="#ffe3ee",
                  look="strawberry syrup (Feast Land E: Pudding Lagoon, the Sky Picnic syrup flood)"),
}

SURFACE_DRAWN_ROW = 6         # art row of the drawn surface line inside a ':' cell (= mud_floor.png)
SURFACE_COLLISION_ROW = 12    # art row of the collision surface (PROFILE_TAR, 6 logical px)
LIP_ROWS = 8                  # rows 6..13 of the surface tiles form the front lip


def skin(name):
    s = SKINS[name]
    return {k: rgb(v) for k, v in s.items() if k != "look"}


def liquid_strip(name):
    """the shipped water strip, exact colour swap (no new colours, the bubble rings follow the mid colour)"""
    k = skin(name)
    water = asset("tiles/common/water.png")
    unknown = colours(water) - {W_BODY, W_MID, W_LIGHT, W_LIGHT2, W_FOAM}
    assert not unknown, "water.png has colours the swap does not know: %s" % unknown
    return swap(water, {W_BODY: k["body"], W_MID: k["mid"], W_LIGHT: k["light"], W_LIGHT2: k["light"],
                        W_FOAM: k["shine"]})


def _tile(atlas, i):
    return atlas.crop(((i % 8) * 32, (i // 8) * 32, (i % 8) * 32 + 32, (i // 8) * 32 + 32))


def _lowered(t):
    """surface tile moved down SURFACE_DRAWN_ROW px; its lowest rows drop out (as mud_floor.png)"""
    out = canvas(32, 32)
    out.alpha_composite(t.crop((0, 0, 32, 32 - SURFACE_DRAWN_ROW)), (0, SURFACE_DRAWN_ROW))
    return out


def _gloss(a, k, row, xs):
    """short glossy dashes (2 px shine + 1 px light) on a surface row"""
    for x in xs:
        for dx in range(3):
            if a[row, x + dx, 3]:
                a[row, x + dx, :3] = k["shine"] if dx < 2 else k["light"]


RING = [".##.",
        "#..#",
        "#..#",
        ".##."]


def _ring(a, k, x, y, big=False):
    pat = RING if not big else [".###.", "#...#", "#...#", "#...#", ".###."]
    for dy, line in enumerate(pat):
        for dx, ch in enumerate(line):
            if ch == "#" and a[y + dy, x + dx, 3]:
                a[y + dy, x + dx, :3] = k["light"]


def floor_strip(name):
    k = skin(name)
    ter = asset("tiles/feast/terrain.png")
    unknown = set().union(*(colours(_tile(ter, i)) for i in (0, 1, 2, 9))) - {F_OUT, F_BASE, F_MID, F_LIGHT}
    assert not unknown, "feast/terrain.png ground tiles changed: %s" % unknown
    m = {F_OUT: k["outline"], F_BASE: k["body"], F_MID: k["mid"], F_LIGHT: k["light"]}
    tiles = []
    for i in (0, 1, 2):
        a = np.array(swap(_lowered(_tile(ter, i)), m))
        _gloss(a, k, SURFACE_DRAWN_ROW + 2, {0: [9, 21], 1: [3, 17, 27], 2: [5, 18]}[(0, 1, 2).index(i)])
        tiles.append(a)
    fill = np.array(swap(_tile(ter, 9), m))
    fill_plain = fill.copy()
    _ring(fill_plain, k, 21, 18)                                    # one faint ring: the goo is not a wall
    bub = fill.copy()
    _ring(bub, k, 6, 7, big=True)
    _ring(bub, k, 22, 19)
    _ring(bub, k, 15, 25)
    lips = []
    for a in tiles:
        lip = np.zeros_like(a)
        y0 = SURFACE_DRAWN_ROW
        lip[y0:y0 + LIP_ROWS] = a[y0:y0 + LIP_ROWS]
        # close the lip with a 1 px darker edge so it does not end in a hard cut against the hero's legs
        bottom = y0 + LIP_ROWS - 1
        solid = lip[bottom, :, 3] > 0
        lip[bottom, solid, :3] = k["mid"]
        lips.append(lip)
    frames = [Image.fromarray(x, "RGBA") for x in tiles + [fill_plain] + lips + [bub]]
    return strip(frames, cols=8)


def build():
    out = {}
    meta = dict(kind="liquid", frame=[32, 32], grid=[8, 1], anims={"surface": anim(range(6), 8)},
                tiles_inline={"0-5": "animated surface (top of a pool; the top 4 px are air)", "6": "body, plain",
                              "7": "body with bubbles"})
    for name in SKINS:
        s = SKINS[name]
        im = liquid_strip(name)
        save(im, "tiles/common/%s.png" % name, section="tiles",
             source="shipped tiles/common/water.png (superpowers-prehistoric-platformer: fx/effects/water.png + "
                    "tileset-1.png water tile)",
             edits="water recoloured to %s (exact colour swap: body %s, mid %s, light %s, foam -> gloss %s)"
                   % (name, s["body"], s["mid"], s["light"], s["shine"]),
             note="deadly `~` of `liquid = %s` (%s); same format as water.png (ASSET_MANIFEST 10.2): 0-5 surface "
                  "loop @8 fps (top 4 art px are air), 6 body, 7 body with bubbles" % (name, s["look"]),
             palette=[s["outline"], s["body"], s["mid"], s["light"], s["shine"]], **meta)
        out[name] = im
        fl = floor_strip(name)
        save(fl, "tiles/common/%s_floor.png" % name, section="tiles", kind="tiles", frame=[32, 32], grid=[8, 1],
             surface_drawn_row=SURFACE_DRAWN_ROW, surface_collision_row=SURFACE_COLLISION_ROW, lip_rows=LIP_ROWS,
             tiles_inline={"0": "top_left", "1": "top (repeatable)", "2": "top_right", "3": "fill (goo below the "
                           "surface row)", "4-6": "front lip of 0-2 (rows 6-13 only)", "7": "fill with bubbles"},
             source="shipped tiles/feast/terrain.png tiles 0, 1, 2, 9 (superpowers-prehistoric-platformer: "
                    "background-elements/tileset-1.png, yellow sand set)",
             edits="surface tiles moved down 6 art px (their lowest 6 rows drop out, as tiles/canyon/mud_floor.png); "
                   "exact 4-colour swap of the sand bands into the %s ramp (outline %s, body %s, mid %s, light %s); "
                   "glossy dashes (%s) under the surface line; bubble rings in the fill tiles; lip = rows 6-13 of "
                   "the surface tiles" % (name, s["outline"], s["body"], s["mid"], s["light"], s["shine"]),
             note="look of the ':' tar floor when `liquid = %s` (drawn by world-A). Tiles 0-3 = the layout of "
                  "tiles/canyon/mud_floor.png: 0 top_left, 1 top, 2 top_right (drawn surface line at art row %d; the "
                  "collision surface is art row %d, so a standing hero is 6 art px deep), 3 fill for cells under a "
                  "':' that should look like goo too; 4-6 optional FRONT-layer lip over 0-2 (rows %d-%d: the hero's "
                  "feet sink behind the surface band); 7 fill with bubbles (variant of 3)"
                  % (name, SURFACE_DRAWN_ROW, SURFACE_COLLISION_ROW, SURFACE_DRAWN_ROW,
                     SURFACE_DRAWN_ROW + LIP_ROWS - 1))
        out[name + "_floor"] = fl
    return out


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()

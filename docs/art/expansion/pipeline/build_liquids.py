"""Book II liquids and the tar floor (DESIGN C.4 / F.1, PHYSICS C.5, ARCHITECTURE 7.11): `liquid = tar | honey | syrup`.

tiles/common/<liquid>.png        the deadly `~` strip of tar, honey and syrup in the exact format of the 1.0 water /
                                 lava / ice_water strips (256 x 32, 8 x 1: 0-5 animated surface, top 4 art px air; 6 body;
                                 7 body with bubbles): an exact colour swap of the shipped water strip, as 1.0 built
                                 lava.png.
tiles/common/<liquid>_floor.png  the look of the ':' tar floor in the level's liquid skin, for all six liquids (128 x 32,
                                 tar = art-B's tiles/swamp/tar_floor.png imported byte for byte; the other five here;
                                 4 x 1, exactly the layout of art-B's tiles/canyon/mud_floor.png: 0 top_left, 1 top
                                 (repeatable), 2 top_right, 3 fill below the surface row) - world-A's request
                                 build/engine_requests/wf7_world_a_to_art_a.txt.

Source of the floor: the surface tiles 0, 1, 2 and the fill 9 of the shipped feast/terrain.png (the anchor's yellow sand
set: flat 4-colour bands, the smoothest ground of the kit), the surface tiles moved down 6 art px like mud_floor.png,
then an exact 4-colour swap into the skin's ramp plus glossy dashes and bubble rings in the ramp's own colours.

Surface geometry (the same in every skin and in mud_floor.png): the drawn surface line is art row 6 of the cell; the
collision surface of ':' is art row 12 (PROFILE_TAR = 6 logical px under the cell top), so a hero on tar stands 6 art
px deep in the goo, in front of it.
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
    # tar = art-B's Tar Fen ramp (tiles/swamp/tar_floor.png, the staged _handover/staged/common/tar.png candidate):
    # the `~` pool and every ':' skin of tar read as one material
    "tar":   dict(outline="#140e1a", body="#1e1628", mid="#2e2240", light="#6c5688", light2="#4a3a62",
                  shine="#a892c4",
                  look="black-violet tar (world 6 Tar Fen, the rising tar of 6-2b, the Tar Pulleys arena)"),
    # honey and syrup sit on the Feast Land terrains (sponge cake #eb9630 / #ffd74f, icing #f8adba): both are kept
    # clearly darker than those so a slow floor never reads as ordinary cake or icing
    "honey": dict(outline="#4f2507", body="#a5520d", mid="#c26c12", light="#df9424", shine="#ffe08a",
                  look="dark amber honey (Feast Land D: Honey Falls)"),
    "syrup": dict(outline="#551331", body="#9e2f5c", mid="#bd4673", light="#dc6f95", shine="#ffd0e0",
                  look="red berry syrup (Feast Land E: Pudding Lagoon, the Sky Picnic syrup flood)"),
}
# floor-only skins for the 1.0 liquids (their `~` strips are the shipped ones, untouched)
FLOOR_ONLY = {
    "water":     dict(outline="#2e1f14", body="#5a3e28", mid="#6e4c30", light="#86603c", shine="#9fc4cc",
                      look="wet mud with a water sheen (':' on water levels)"),
    "lava":      dict(outline="#1a1016", body="#3a2426", mid="#5a2e22", light="#ce421a", shine="#ffb23c",
                      look="cooling magma crust, glowing under the skin (':' on lava levels)"),
    "ice_water": dict(outline="#2c3d5f", body="#6e8eae", mid="#89aac6", light="#b3dcfa", shine="#ffffff",
                      look="grey-blue slush (':' on ice-water levels)"),
}
ALL_FLOORS = dict(SKINS, **FLOOR_ONLY)
# the tar floor is art-B's Tar Fen file (tiles/swamp/tar_floor.png, staged byte for byte as tiles/common/tar_floor.png
# and imported by build_expansion.py): the fen, where nearly all tar lies, and every other tar level look the same
BUILT_FLOORS = {k: v for k, v in ALL_FLOORS.items() if k != "tar"}

SURFACE_DRAWN_ROW = 6         # art row of the drawn surface line inside a ':' cell (= mud_floor.png)
SURFACE_COLLISION_ROW = 12    # art row of the collision surface (PROFILE_TAR, 6 logical px)


def skin(name):
    s = ALL_FLOORS[name]
    return {k: rgb(v) for k, v in s.items() if k != "look"}


def liquid_strip(name):
    """the shipped water strip, exact colour swap (no new colours, the bubble rings follow the mid colour)"""
    k = skin(name)
    water = asset("tiles/common/water.png")
    unknown = colours(water) - {W_BODY, W_MID, W_LIGHT, W_LIGHT2, W_FOAM}
    assert not unknown, "water.png has colours the swap does not know: %s" % unknown
    return swap(water, {W_BODY: k["body"], W_MID: k["mid"], W_LIGHT: k["light"], W_LIGHT2: k.get("light2", k["light"]),
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


def _ring(a, k, x, y, big=False):
    pat = [".##.", "#..#", "#..#", ".##."] if not big else [".###.", "#...#", "#...#", "#...#", ".###."]
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
    for j, i in enumerate((0, 1, 2)):
        a = np.array(swap(_lowered(_tile(ter, i)), m))
        _gloss(a, k, SURFACE_DRAWN_ROW + 2, [[9, 21], [3, 17, 27], [5, 18]][j])
        tiles.append(a)
    fill = np.array(swap(_tile(ter, 9), m))
    _ring(fill, k, 6, 7, big=True)                                  # a few bubbles: the goo is not a wall
    _ring(fill, k, 22, 19)
    _ring(fill, k, 13, 25)
    return strip([Image.fromarray(x, "RGBA") for x in tiles + [fill]], cols=4)


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
             edits="water recoloured to %s (exact colour swap: body %s, mid %s, light %s / %s, foam -> gloss %s)"
                   % (name, s["body"], s["mid"], s["light"], s.get("light2", s["light"]), s["shine"]) +
                   ("; the ramp of art-B's Tar Fen kit (tiles/swamp/tar_floor.png)" if name == "tar" else ""),
             note="deadly `~` of `liquid = %s` (%s); same format as water.png (ASSET_MANIFEST 10.2): 0-5 surface "
                  "loop @8 fps (top 4 art px are air), 6 body, 7 body with bubbles" % (name, s["look"]),
             palette=[s["outline"], s["body"], s["mid"], s["light"], s["shine"]], **meta)
        out[name] = im
    for name, s in BUILT_FLOORS.items():
        fl = floor_strip(name)
        save(fl, "tiles/common/%s_floor.png" % name, section="tiles", kind="tiles", frame=[32, 32], grid=[4, 1],
             surface_drawn_row=SURFACE_DRAWN_ROW, surface_collision_row=SURFACE_COLLISION_ROW,
             tiles_inline={"0": "top_left", "1": "top (repeatable)", "2": "top_right",
                           "3": "fill below the surface row (bubbles)"},
             palette=[s["outline"], s["body"], s["mid"], s["light"], s["shine"]],
             source="shipped tiles/feast/terrain.png tiles 0, 1, 2, 9 (superpowers-prehistoric-platformer: "
                    "background-elements/tileset-1.png, yellow sand set)",
             edits="surface tiles moved down 6 art px (their lowest 6 rows drop out, as tiles/canyon/mud_floor.png); "
                   "exact 4-colour swap of the sand bands into the %s ramp (outline %s, body %s, mid %s, light %s); "
                   "glossy dashes (%s) under the surface line; bubble rings in the fill tile"
                   % (name, s["outline"], s["body"], s["mid"], s["light"], s["shine"]),
             note="look of the ':' tar floor when `liquid = %s` (%s), drawn by world-A; the layout of "
                  "tiles/canyon/mud_floor.png: 0 top_left, 1 top (repeatable), 2 top_right, 3 fill below the surface "
                  "row. Drawn surface line at art row %d of the cell; the collision surface is art row %d (6 logical "
                  "px), so a standing hero is 6 art px deep in front of the goo"
                  % (name, s["look"], SURFACE_DRAWN_ROW, SURFACE_COLLISION_ROW))
        out[name + "_floor"] = fl
    return out


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()

"""Terrain atlases, liquids, hazards and props for every biome.

Source: tileset-1.png of the Superpowers "Prehistoric Platformer" pack (Pixel-boy, CC0).
The pack's terrain is modular 16 px artwork drawn as 32 px modules; here every terrain set is
re-cut into one uniform 8 x 5 atlas of 32 x 32 tiles with a fixed index meaning (TERRAIN_TILES).
Right-hand pieces that the pack does not contain are produced by mirroring the left-hand ones.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *  # noqa

TS = None
BLOCK = {"sand": (0, 256), "stone": (160, 256), "jungle": (320, 256), "grass": (480, 256),
         "pale": (0, 400), "cave": (160, 400), "volcano": (320, 400), "ice": (480, 400)}
BACKWALL = {"orange": (640, 384), "brown": (640, 432), "purple": (640, 480),
            "lightgreen": (688, 384), "green": (688, 432), "teal": (688, 480)}

# index -> (name, meaning, collision hint)
TERRAIN_TILES = [
    ("top_left", "ground surface, left outer corner", "solid"),
    ("top", "ground surface (repeatable)", "solid"),
    ("top_right", "ground surface, right outer corner", "solid"),
    ("cap_left", "alternate surface (2-tile pillar / ledge cap), left half with left edge", "solid"),
    ("cap_right", "alternate surface cap, right half with right edge", "solid"),
    ("slope45_up_right", "steep slope rising to the right: height 0 -> 16 logical px", "slope"),
    ("slope45_up_left", "steep slope rising to the left: height 16 -> 0 logical px", "slope"),
    ("block", "single framed block (breakable block / hidden-spot look)", "solid"),
    ("left", "left wall edge", "solid"),
    ("fill", "inner fill", "solid"),
    ("right", "right wall edge", "solid"),
    ("gentle_up_right_low", "gentle slope rising to the right, low half: height 0 -> 8 logical px", "slope"),
    ("gentle_up_right_high", "gentle slope rising to the right, high half: height 8 -> 16", "slope"),
    ("gentle_up_left_high", "gentle slope rising to the left, high half: height 16 -> 8", "slope"),
    ("gentle_up_left_low", "gentle slope rising to the left, low half: height 8 -> 0", "slope"),
    ("fill_inset", "fill with an inset panel (scenery; suggested look for hidden bonus spots)", "solid"),
    ("bottom_left", "underside, left outer corner", "solid"),
    ("bottom", "underside (repeatable)", "solid"),
    ("bottom_right", "underside, right outer corner", "solid"),
    ("under_slope45_right", "fill placed directly below slope45_up_right", "solid"),
    ("under_slope45_left", "fill placed directly below slope45_up_left", "solid"),
    ("under_gentle_right_low", "fill placed below gentle_up_right_low", "solid"),
    ("under_gentle_right_high", "fill placed below gentle_up_right_high", "solid"),
    ("fill_b", "inner fill, variant with detail", "solid"),
    ("under_gentle_left_high", "fill placed below gentle_up_left_high", "solid"),
    ("under_gentle_left_low", "fill placed below gentle_up_left_low", "solid"),
    ("bottom_b", "underside, variant", "solid"),
    ("oneway_left", "thin one-way platform, left end (upper 16 px of the cell)", "one-way"),
    ("oneway_mid", "thin one-way platform, middle (repeatable)", "one-way"),
    ("oneway_right", "thin one-way platform, right end", "one-way"),
    ("hang_left", "hanging fringe under a ledge, left end (upper 16 px, decor)", "decor"),
    ("hang_mid", "hanging fringe, middle (decor)", "decor"),
    ("hang_right", "hanging fringe, right end (decor)", "decor"),
    ("hang_cap", "hanging rounded cap (decor)", "decor"),
    ("small_block", "16 px block, bottom-left of the cell (decor / debris)", "decor"),
    ("back_fill", "background wall, plain (no collision, drawn behind actors)", "decor"),
    ("back_deco_a", "background wall with a star crack (decor)", "decor"),
    ("back_deco_b", "background wall with a crack and a hole (decor)", "decor"),
    ("spikes_floor", "floor spikes, deadly from the top (lower 16 px of the cell)", "hazard"),
    ("spikes_ceiling", "ceiling spikes, deadly from below (upper 16 px of the cell)", "hazard"),
]
SPIKES = {"brown": 304, "ice": 320, "tan": 336}   # y of the three spike rows (x 704 / 720 / 736 ... see below)


def ts():
    global TS
    if TS is None:
        TS = sp("background-elements/tileset-1.png")
    return TS


def spike_tile(kind):
    """32 x 32 tile with a 32 x 16 row of spikes at the bottom."""
    t = ts()
    if kind == "brown":
        a = t.crop((720, 304, 736, 320)); b = t.crop((736, 304, 752, 320))
    elif kind == "ice":
        a = t.crop((768, 320, 784, 336)); b = t.crop((784, 320, 800, 336))
    else:
        a = t.crop((768, 336, 784, 352)); b = t.crop((784, 336, 800, 352))
    out = canvas(32, 32)
    out.alpha_composite(a, (0, 16)); out.alpha_composite(b, (16, 16))
    return out


def back_tiles(color):
    x, y = BACKWALL[color]
    t = ts()
    plain16 = t.crop((x + 16, y, x + 32, y + 16))
    fill = canvas(32, 32)
    for i in range(2):
        for j in range(2):
            fill.alpha_composite(plain16, (i * 16, j * 16))
    a = fill.copy(); a.alpha_composite(t.crop((x + 32, y, x + 48, y + 16)), (8, 8))
    b = fill.copy(); b.alpha_composite(t.crop((x + 32, y + 16, x + 48, y + 32)), (0, 2))
    b.alpha_composite(t.crop((x + 32, y + 32, x + 48, y + 48)), (16, 14))
    return fill, a, b


def terrain_atlas(block, back, spikes, fn=None, back_fn=None, spike_fn=None):
    bx, by = BLOCK[block]
    t = ts()

    def c(x, y, w=32, h=32):
        return t.crop((bx + x, by + y, bx + x + w, by + y + h))

    def top16(im):                       # 16 px high piece -> upper half of a 32 px cell
        out = canvas(32, 32); out.alpha_composite(im, (0, 0)); return out

    F = {(i, j): c(i * 32, 32 + j * 32) for i in range(3) for j in range(3)}
    slope = c(64, 0); gentle_lo = c(96, 64); gentle_hi = c(128, 64)
    under_lo = c(96, 96); under_hi = c(128, 96)
    plat = c(0, 16, 64, 16); fringe = c(0, 128, 96, 16); cap = c(112, 128, 32, 16)
    small = canvas(32, 32); small.alpha_composite(c(0, 0, 16, 16), (0, 16))
    tiles = [
        F[0, 0], F[1, 0], flip(F[0, 0]), c(96, 32), c(128, 32), slope, flip(slope), c(128, 0),
        F[0, 1], F[1, 1], flip(F[0, 1]), gentle_lo, gentle_hi, flip(gentle_hi), flip(gentle_lo), c(96, 0),
        F[0, 2], F[1, 2], flip(F[0, 2]), F[2, 0], flip(F[2, 0]), under_lo, under_hi, F[2, 1],
        flip(under_hi), flip(under_lo), F[2, 2],
        top16(plat.crop((0, 0, 32, 16))), top16(plat.crop((16, 0, 48, 16))), top16(plat.crop((32, 0, 64, 16))),
        top16(fringe.crop((0, 0, 32, 16))), top16(fringe.crop((32, 0, 64, 16))),
        top16(fringe.crop((64, 0, 96, 16))), top16(cap), small,
    ]
    if fn:
        tiles = [remap(x, fn) for x in tiles]
    bt = list(back_tiles(back))
    if back_fn:
        bt = [remap(x, back_fn) for x in bt]
    sk = spike_tile(spikes)
    if spike_fn:
        sk = remap(sk, spike_fn)
    tiles += bt + [sk, vflip(sk)]
    assert len(tiles) == len(TERRAIN_TILES) == 40, len(tiles)
    return strip(tiles, cols=8)


def save_terrain(rel, block, back, spikes, source_note, edits="", **kw):
    atlas = terrain_atlas(block, back, spikes, **kw)
    save(atlas, rel, kind="terrain", frame=[32, 32], grid=[8, 5], tiles="TERRAIN_TILES",
         source="superpowers-prehistoric-platformer: background-elements/tileset-1.png (%s)" % source_note,
         edits="re-cut into the common 8x5 atlas of 32 px tiles; right-hand corners / edges / slopes mirrored from the "
               "left-hand art; one-way middle cut from the platform centre; back-wall and spike tiles appended" + (("; " + edits) if edits else ""))
    return atlas


# ----------------------------------------------------------------------------- recolour ramps
def lum_ramp(ramp, lo=20, hi=245):
    base = ramp_fn(ramp, lo, hi)
    def fn(r, g, b):
        if (r, g, b) == (39, 32, 24):
            return (39, 32, 24)
        return base(r, g, b)
    return fn


OBSIDIAN = [(39, 32, 24), (50, 40, 54), (74, 60, 80), (104, 88, 110), (140, 124, 144), (182, 170, 184)]
FROST_ROCK = [(39, 32, 24), (58, 74, 104), (86, 116, 150), (126, 160, 190), (176, 206, 226), (232, 244, 250)]
CANDY = [(39, 32, 24), (150, 60, 90), (214, 96, 128), (244, 150, 170), (252, 200, 206), (255, 240, 236)]


def build_terrain():
    T = "tiles/"
    out = {}
    out["jungle"] = save_terrain(T + "jungle/terrain.png", "jungle", "green", "tan", "dark-green jungle set")
    save_terrain(T + "jungle/terrain_grass.png", "grass", "lightgreen", "tan", "light-green grass set")
    out["cave"] = save_terrain(T + "cave/terrain.png", "cave", "purple", "brown", "purple cave-rock set")
    save_terrain(T + "cave/terrain_stone.png", "stone", "brown", "tan", "tan stone set")
    out["ice"] = save_terrain(T + "ice/terrain.png", "ice", "purple", "ice", "ice / snow set",
                              edits="back wall recoloured to frozen blue",
                              back_fn=lum_ramp([(39, 32, 24), (44, 62, 96), (60, 88, 128), (84, 120, 160), (120, 160, 196)]))
    save_terrain(T + "ice/terrain_rock.png", "stone", "purple", "ice", "tan stone set",
                 edits="gradient-mapped to frost-blue rock", fn=lum_ramp(FROST_ROCK),
                 back_fn=lum_ramp([(39, 32, 24), (44, 62, 96), (60, 88, 128), (84, 120, 160), (120, 160, 196)]))
    out["volcano"] = save_terrain(T + "volcano/terrain.png", "volcano", "brown", "brown", "orange volcanic set",
                                  edits="back wall darkened", back_fn=hsv_fn(vm=0.62, sm=1.05))
    save_terrain(T + "volcano/terrain_obsidian.png", "cave", "purple", "brown", "purple cave-rock set",
                 edits="gradient-mapped to obsidian for the fortress level", fn=lum_ramp(OBSIDIAN),
                 back_fn=lum_ramp([(39, 32, 24), (40, 32, 44), (56, 44, 60), (76, 62, 82), (100, 84, 104)]),
                 spike_fn=lum_ramp(OBSIDIAN))
    out["feast"] = save_terrain(T + "feast/terrain.png", "sand", "orange", "tan", "yellow sand set (reads as sponge cake / cheese)")
    save_terrain(T + "feast/terrain_icing.png", "ice", "orange", "tan", "ice / snow set",
                 edits="gradient-mapped to strawberry icing", fn=lum_ramp(CANDY), spike_fn=lum_ramp(CANDY))
    save_terrain(T + "feast/terrain_biscuit.png", "pale", "brown", "tan", "pale sand set (reads as biscuit)")
    return out


if __name__ == "__main__":
    load_registry()
    build_terrain()
    save_registry()
    print("tiles done")

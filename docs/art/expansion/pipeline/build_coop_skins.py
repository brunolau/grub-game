"""Remaining co-op object skins (PLAN P1.13): the see-saw's mushroom-cap and ice-floe planks (6-2 Spore Hollow, the
Floe Rink arena) and Chomper's saddle (DESIGN C.8 / F.1: "saddle strap pixel edit; second-seat composite").

Sources: the shipped 2.0 see-saw plank (sprites/objects/seesaw_plank.png, built from the anchor's wood platform and bone
item) and the shipped rex sheet (sprites/enemies/rex.png, anchor pack). Edits: exact colour swaps; the saddle is an
overlay drawn per frame in the anchor's leather / binding colours on the rex's own back line.
"""
import numpy as np
from PIL import Image

from xcommon import OUTLINE, asset, canvas, colours, rgb, save, strip, swap, anim

O4 = OUTLINE + (255,)

# ---------------------------------------------------------------------------------------------------- see-saw skins
# the plank's colours: platform board (outline-dark, dark wood, wood, binding) and the bone knobs
PLANK = {"dark": rgb("#332213"), "wood_d": rgb("#7f3910"), "wood": rgb("#9d4829"), "bind": rgb("#f1b043"),
         "bone_s": rgb("#b39760"), "bone_m": rgb("#f7bf3e"), "bone_l": rgb("#ffe288"), "white": rgb("#ffffff")}
SEESAW_SKINS = {
    # 6-2 Spore Hollow: a violet mushroom cap with pale spots; the bone knobs become pale stalk ends
    "mushroom": {"dark": "#3a1e46", "wood_d": "#7a3f8c", "wood": "#a05ab4", "bind": "#f0e0f8",
                 "bone_s": "#b8a890", "bone_m": "#e2d6c0", "bone_l": "#f4ecdc", "white": "#ffffff"},
    # Floe Rink: an ice floe (the ice terrain's blues), the knobs snow lumps
    "floe": {"dark": "#2c3d5f", "wood_d": "#81c0d4", "wood": "#b3dcfa", "bind": "#ffffff",
             "bone_s": "#81c0d4", "bone_m": "#b3dcfa", "bone_l": "#e6f4fc", "white": "#ffffff"},
}


def build_seesaw_skins():
    src = asset("sprites/objects/seesaw_plank.png")
    known = set(PLANK.values()) | {OUTLINE}
    extra = colours(src) - known
    assert not extra, "seesaw_plank.png has colours the skins do not map: %s" % extra
    out = {}
    for name, sk in SEESAW_SKINS.items():
        im = swap(src, {PLANK[k]: rgb(v) for k, v in sk.items()})
        save(im, "sprites/objects/seesaw_plank_%s.png" % name, kind="object", frame=[208, 88], grid=[5, 4],
             pivot=[104, 40],
             source="shipped 2.0 sprites/objects/seesaw_plank.png (shipped sprites/objects/platform_wood.png + "
                    "superpowers-prehistoric-platformer: items/15.png)",
             edits="exact colour swap of the wood plank (" + ", ".join("%s -> %s" % (k, v) for k, v in sk.items()) +
                   "); layout, pivots and rest angles unchanged",
             note="`objects/seesaw` %s skin: exactly the layout of seesaw_plank.png (rows = len 3 / 4 / 5 / 6, columns "
                  "= left end down ... right end down, pivot (104, 40) on the fulcrum). %s"
                  % (name, "6-2 Spore Hollow (swamp biome, mushroom cave)" if name == "mushroom" else
                     "Floe Rink arena (ice): the two see-saw floes"), section="objects")
        out[name] = im
    return out


# ---------------------------------------------------------------------------------------------------- rex saddle
REX_CELL = (152, 112)
REX_GRID = (8, 3)
REX_PIVOT = (76, 96)
LEATHER, LEATHER_L, LEATHER_D = rgb("#89361b"), rgb("#a14f27"), rgb("#5e2410")
STITCH, BAND, BAND_D = rgb("#f4e49b"), rgb("#f1b043"), rgb("#b3a178")
REF_X = 48                    # the column whose back line gives a frame's bob (behind the arms and the head)
NO_SADDLE = (19, 20, 21, 22, 23)   # hit and dead poses: the riders are thrown off, the mount bolts


def _top(cell, x):
    col = np.nonzero(cell[:, x, 3])[0]
    return int(col.min()) if len(col) else None


def saddle_shape(ref):
    """the saddle drawn on frame 0's back line: a blanket over the back (x 56-82), the driver's cushion on top of it
    (feet line at y 44 = 52 art px over the feet point: MountTuning.SADDLE_PX 26), a raised rear seat for the gunner
    14 logical px behind (x 34-57, its top on the same line), a belly strap with a buckle"""
    H, W = REX_CELL[1], REX_CELL[0]
    a = np.zeros((H, W, 4), np.uint8)
    seat_y = REX_PIVOT[1] - 52                                       # 44
    # blanket along the contour
    for x in range(56, 83):                                         # the back only, not the neck
        t = _top(ref, x)
        if t is None:
            continue
        y0 = max(seat_y, min(t - 2, seat_y + 1))                    # the cushion's top = the driver's feet line
        a[y0 - 1:t + 6, x] = O4
        a[y0:t + 5, x] = tuple(LEATHER) + (255,)
        a[y0, x] = tuple(LEATHER_L) + (255,)
        if x % 3 == 0:
            a[t + 3, x] = tuple(STITCH) + (255,)
    a[:, 55] = np.where(a[:, 56:57, 3] > 0, np.array(O4, np.uint8), a[:, 55])
    a[:, 83] = np.where(a[:, 82:83, 3] > 0, np.array(O4, np.uint8), a[:, 83])
    # rear seat: a stitched hide pad from the seat line down to the back
    for x in range(34, 58):
        t = _top(ref, x)
        if t is None:
            continue
        top = seat_y + (2 if x in (34, 35) else 0)
        a[top - 1:t + 3, x] = O4
        if x not in (34, 57):
            a[top:t + 2, x] = tuple(LEATHER_L if x < 40 else LEATHER) + (255,)
            a[top, x] = tuple(BAND) + (255,)
            a[top + 1, x] = tuple(BAND_D) + (255,)
            for y in range(top + 4, t + 1, 4):
                a[y, x] = tuple(LEATHER_D) + (255,)
    # belly strap (behind the arms) with a bone-coloured buckle
    sx = 66
    t = _top(ref, sx)
    for x in range(sx, sx + 4):
        a[t + 5:t + 21, x] = tuple(LEATHER) + (255,)
    a[t + 5:t + 21, sx - 1] = O4
    a[t + 5:t + 21, sx + 4] = O4
    a[t + 12:t + 16, sx - 1:sx + 5] = O4
    a[t + 13:t + 15, sx:sx + 4] = tuple(BAND) + (255,)
    # blanket and seat sit on and above the back; below the back line only on the rex's own body (the strap may
    # not hang into the air under the belly)
    body = ref[..., 3] > 0
    keep = body.copy()
    for x in range(W):
        tx = _top(ref, x)
        if tx is not None:
            keep[:tx + 6, x] = True
    a[~keep] = 0
    return a, seat_y


def build_rex_saddle():
    sheet = asset("sprites/enemies/rex.png")
    S = np.array(sheet)
    cw, ch = REX_CELL

    def cell(f):
        cx, cy = (f % REX_GRID[0]) * cw, (f // REX_GRID[0]) * ch
        return S[cy:cy + ch, cx:cx + cw]
    ref = cell(0)
    shape, seat_y = saddle_shape(ref)
    r0 = _top(ref, REF_X)
    frames, dys = [], []
    for f in range(REX_GRID[0] * REX_GRID[1]):
        c = cell(f)
        if f in NO_SADDLE or _top(c, REF_X) is None:
            frames.append(canvas(cw, ch))
            dys.append(None)
            continue
        dy = _top(c, REF_X) - r0
        shifted = np.zeros_like(shape)
        if dy < 0:
            shifted[:dy] = shape[-dy:]
        elif dy > 0:
            shifted[dy:] = shape[:-dy]
        else:
            shifted = shape.copy()
        # this frame's own body: below its back line the saddle stays on the rex (the bite poses lean)
        body = c[..., 3] > 0
        for x in range(cw):
            t = _top(c, x)
            limit = (t + 6 + abs(dy)) if t is not None else -1
            col = shifted[:, x]
            for y in np.nonzero(col[:, 3])[0]:
                if y > limit and not body[y, x]:
                    col[y] = 0
        frames.append(Image.fromarray(shifted, "RGBA"))
        dys.append(dy)
    out = strip(frames, cols=REX_GRID[0])
    save(out, "sprites/objects/rex_saddle.png", kind="object", frame=[cw, ch], grid=list(REX_GRID),
         pivot=list(REX_PIVOT), seat_dy=dys,
         source="drawn by the pipeline on the back line of shipped sprites/enemies/rex.png (frame 0), in the "
                "anchor's belt leather / binding colours (#89361b, #a14f27, #f4e49b, #f1b043, outline #272018)",
         edits="blanket following the rex's back (x 56-82), the driver's cushion line at 52 art px over the feet, a "
               "raised stitched rear seat for the gunner (x 34-57), a belly strap with a buckle; each frame = frame "
               "0's saddle moved by that frame's bob (the back line at x %d)" % REF_X,
         note="Chomper's saddle (`objects/mount kind=rex`, C.8, PHYSICS C.9): an OVERLAY with the grid, cells and "
              "pivot of sprites/enemies/rex.png (and rex_b.png): draw cell f over the rex's cell f, same position "
              "and flip. Driver's feet = the cushion line, 52 art px (SADDLE_PX 26) over the feet point; the rear "
              "seat's top is the same line 28 art px (14 logical) behind, for the gunner. `seat_dy` (per frame, art "
              "px; null = no saddle drawn) is how far the back bobs in that frame: add it / 2 to the riders' logical "
              "y if they should ride the bob. Frames 19-23 (hit, dead) are empty: the riders are thrown off and the "
              "mount bolts", section="objects")
    return out


def build():
    return {"seesaw": build_seesaw_skins(), "rex_saddle": build_rex_saddle()}


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()

"""The spear (DESIGN C.2, F.1 "hero_spear sheet + spear pick-up / projectile"): hero sheet, pick-up, projectile.

Source: the anchor pack's own spear, items/12.png (Superpowers Prehistoric Platformer, Pixel-boy, CC0).
The hero sheet is built by the 1.0 code path itself (docs/art/pipeline/build_sprites.py `hero_frames`, which rebuilds
the shipped hero.png / hero_axe.png pixel for pixel - checked below) with one more WEAPONS entry, so the spear sheet has
exactly the layout, poses, pivots and cloth pixels of the four 1.0 sheets. The spear is a thrown weapon like the axe:
the release frames of the attacks are bare-handed (spawn `fx/projectile_spear.png` there).
"""
import math
import os
import sys

import numpy as np
from PIL import Image

from xcommon import AP, ASSETS, OUTLINE, PACK_SP, save, scale, trim, canvas, pad_to, strip, anim, rotate_px, outline

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "pipeline"))
import build_sprites as bs1          # noqa: E402  (1.0 hero builder)
from common import pack as pack1     # noqa: E402

SPEAR = "items/12.png"               # 11 x 67, head up: stone tip rows 0-12, binding 13-16, shaft 17-66
GRIP = (5, 42)                       # balance point, two thirds down the shaft (club: (9, 31) of 37 px)
SRC = "superpowers-prehistoric-platformer: "


def spear():
    return Image.open(os.path.join(AP, *SPEAR.split("/"))).convert("RGBA")


def check_1x_builder():
    """The 1.0 builder must still rebuild the shipped club and axe sheets exactly (else the spear sheet would drift)."""
    for w, name in (("club", "hero.png"), ("axe", "hero_axe.png")):
        frames, pivots, _ = bs1.hero_frames(w)
        sheet, _ = pack1(frames, pivots, cols=8, cell=(176, 112))
        ref = np.array(Image.open(os.path.join(ASSETS, "sprites", "player", name)).convert("RGBA"))
        assert np.array_equal(np.array(sheet), ref), "1.0 hero builder no longer reproduces " + name


def rotated(im, deg, pivot):
    """weapon rotation of the 1.0 hero builder: rotate the core, rebuild the 2 px #272018 outline"""
    return bs1.weapon_sprite(im, deg, pivot)


def build_sheet():
    bs1.WEAPONS["spear"] = (SPEAR, GRIP, True)
    try:
        frames, pivots, anims = bs1.hero_frames("spear")
    finally:
        del bs1.WEAPONS["spear"]
    sheet, (cw, ch, cols, rows) = pack1(frames, pivots, cols=8, cell=(176, 112))
    save(sheet, "sprites/player/hero_spear.png", kind="actor", frame=[cw, ch], grid=[cols, rows], anims=anims,
         facing="right", pivot=[cw // 2, ch - 16], body_box_logical=[22, 28],
         source=SRC + "characters/playable/caverman.png + items/12.png + fx/effects/1.png",
         edits="the 1.0 hero builder (docs/art/pipeline/build_sprites.py hero_frames) with the spear as a fifth weapon: "
               "spear rotated about its balance point (5, 42), 2 px outline rebuilt, composited behind the body in "
               "idle / walk / jump / fall / crouch (carried on the shoulder) and the wind-up frames; thrown weapon: "
               "the release frames are bare-handed",
         note="weapon variant: spear (same 8 x 7 layout, pivots and cloth pixels as hero.png)",
         section="player")
    return sheet


def build_item():
    """pick-up: the spear planted in the ground at a slant (a 67 px weapon does not fit the 32 x 40 pick-up cell)"""
    rot, piv = rotated(spear(), 14, (5, 66))
    t = trim(rot)
    cell = (32, 72)
    out = pad_to(t, cell[0], cell[1], 0.5, 1.0)
    save(out, "sprites/items/weapon_spear.png", kind="item", frame=list(cell), grid=[1, 1], pivot=[16, 72],
         source=SRC + SPEAR, edits="rotated 14 degrees about the butt, 2 px outline rebuilt, bottom-centred in 32x72",
         note="weapon pick-up: spear (`items/weapon kind=spear`), planted in the ground; 1 x 2.25 tiles",
         section="items")
    return out


def build_projectile():
    """projectile_spear: flight frames by angle (flat, then nose-down while it drops) + stuck frames (tip hidden)."""
    s = spear()
    flat = s.rotate(-90, Image.NEAREST, expand=True)            # 67 x 11, tip to the right
    cell = (72, 56)
    cx, cy = cell[0] // 2, cell[1] // 2
    frames, tips = [], []

    def tip_of(f, deg):
        """the opaque pixel farthest along the flight direction"""
        al = np.array(f)[..., 3] > 0
        ys, xs = np.nonzero(al)
        a = math.radians(deg)
        k = int(np.argmax(xs * math.cos(a) + ys * math.sin(a)))
        return [int(xs[k]), int(ys[k])]

    for deg in (0, 15, 30, 45):
        if deg == 0:
            rot, p = flat, (flat.width // 2, flat.height // 2)
        else:
            rot, p = rotated(flat, deg, (flat.width / 2.0, flat.height / 2.0))
        f = canvas(*cell)
        f.alpha_composite(rot, (cx - p[0], cy - p[1]))
        frames.append(f)
        tips.append(tip_of(f, deg))
    # stuck: the first 9 px of the stone tip are inside the board; the shaft quivers about the embed point
    body = flat.crop((0, 0, flat.width - 9, flat.height))
    embed = (tips[0][0] + 1 - 9, cy)
    for k, deg in enumerate((0, -3, 3)):
        if deg == 0:
            rot, p = body, (body.width, body.height // 2)
        else:
            rot, p = rotated(body, deg, (body.width - 0.5, body.height / 2.0))
        f = canvas(*cell)
        f.alpha_composite(rot, (embed[0] - p[0], embed[1] - p[1]))
        frames.append(f)
        tips.append([embed[0] - 1, embed[1]])
    sheet = strip(frames)
    save(sheet, "sprites/fx/projectile_spear.png", kind="fx", frame=list(cell), grid=[len(frames), 1],
         pivot=[cx, cy], anims={"fly": anim([0], 1, False), "drop": anim([1, 2, 3], 1, False),
                                "stuck": anim([4], 1, False), "quiver": anim([5, 4, 6, 4], 16, False)},
         source=SRC + SPEAR,
         edits="90 degree lossless turn (tip right); 15 / 30 / 45 degree nose-down turns with the outline rebuilt; "
               "stuck frames: tip cropped 9 px (inside the board), +-3 degree quiver about the board face",
         note="thrown spear (`projectiles/hero_spear`, C.2): frame 0 = flat flight, 1-3 = pick by the flight angle "
              "while it drops (15 / 30 / 45 deg), 4 = stuck in a bark board (draw as the 16 px one-way step), 5-6 = "
              "quiver on impact. Faces right: flip_h for a throw to the left. Tip point per frame (cell px): %s" %
              " ".join("%d:(%d,%d)" % (i, t[0], t[1]) for i, t in enumerate(tips)),
         tips=tips, section="fx")
    return sheet


def build():
    check_1x_builder()
    return build_sheet(), build_item(), build_projectile()


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()

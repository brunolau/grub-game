"""Multiplayer HUD / indicator art (DESIGN C.1 rule 5, D.1, D.2, D.11, E.9): belt icon, P1-P4 tags and colour arrows,
edge arrows for a hero off the view, the stone countdown, and the hero-start markers.

Sources: shipped 1.0 art only (ui/icons.png arrows, fonts/font_hud.png, sprites/items/weapon_*.png,
sprites/objects/code_stone.png - all from the anchor pack, Superpowers Prehistoric Platformer, Pixel-boy, CC0) plus the
spear pick-up built by build_hero_spear.py. Player colours come from the hero palettes (build_hero_palettes.PALETTES):
the arrow fill is the loincloth colour, so P1 / P2 are light and P3 / P4 dark exactly like the heroes (the lightness
split that keeps the four apart under protanopia / deuteranopia, see hero_palettes.json "checks").
"""
import numpy as np
from PIL import Image

from xcommon import OUTLINE, asset, canvas, colours, rgb, save, strip, swap, trim, anim, font_text, tint_white
from build_coop_objects import rot_outlined, grow, rim
from build_hero_palettes import ui_ramp

O4 = OUTLINE + (255,)
SLOT_COLOURS = ("yellow", "blue", "pink", "green")


def icon(i):
    ic = asset("ui/icons.png")
    return ic.crop((i * 32, 0, i * 32 + 32, 32))


def colour_arrow(cell_index, ramp):
    """ui/icons.png arrow (peach fill, white light, black outline) in a player ramp; outline -> anchor #272018"""
    a = icon(cell_index)
    m = {}
    for c in colours(a):
        if c == (0, 0, 0):
            m[c] = OUTLINE
        elif c == (255, 255, 255):
            m[c] = ramp["light"]
        elif sum(c) > 600:
            m[c] = ramp["fill"]
        else:
            m[c] = ramp["shade"]
    return swap(a, m)


# ---------------------------------------------------------------------------------------------------- belt icon
def build_belt():
    """ui/hud_belt.png: what a Swap brings (C.1 rule 5): the weapon at 45 degrees tucked into a strip of belt."""
    leather, leather_l = rgb("#89361b"), rgb("#a14f27")
    stitch = rgb("#f4e49b")
    names = ["club", "hammer", "axe", "boomerang", "spear"]
    frames = []
    for n in names:
        w = trim(asset("sprites/items/weapon_%s.png" % n))
        r, _ = rot_outlined(w, 45, (w.width / 2.0, w.height / 2.0))
        r = trim(r)
        f = canvas(32, 32)
        a = np.array(f)
        a[19:27, :] = O4                                           # strap with 1 px outline rows
        a[20:26, :] = tuple(leather) + (255,)
        a[20, :] = tuple(leather_l) + (255,)
        for x in range(1, 32, 4):
            a[23, x] = tuple(stitch) + (255,)
        f = Image.fromarray(a, "RGBA")
        # head to the top-right corner, the handle may run off the bottom-left
        x = 31 - r.width if r.width > 29 else (32 - r.width) // 2 + 2      # 1 px margin at the top / right
        y = 1 if r.height > 29 else (32 - r.height) // 2 - 2
        f.alpha_composite(r.crop((max(0, -x), max(0, -y), r.width, r.height)), (max(0, x), max(0, y)))
        frames.append(f)
    s = strip(frames)
    save(s, "ui/hud_belt.png", kind="ui", frame=[32, 32], grid=[len(frames), 1],
         source="shipped sprites/items/weapon_club / hammer / axe / boomerang.png and the 2.0 weapon_spear.png",
         edits="each weapon rotated 45 degrees with the 2 px outline rebuilt, over a strip of stitched leather belt in "
               "the barrel's browns; the handle end may leave the cell",
         note="belt icon next to the hearts (C.1 rule 5, 16 x 16 logical): what a Swap brings. Cells: 0 club, "
              "1 hammer, 2 axe, 3 boomerang (= the swirling axe), 4 spear", section="ui")
    return s


# ---------------------------------------------------------------------------------------------------- tags + arrows
def build_tags(palettes):
    """ui/player_tags.png: 'P1'..'P4' (shipped HUD font, white) over a down arrow in the slot colour"""
    frames = []
    for k, cname in enumerate(SLOT_COLOURS):
        ramp = ui_ramp(palettes[cname])
        f = canvas(32, 48)
        tag = canvas(40, 20)
        font_text(tag, "P%d" % (k + 1), 0, 0)
        tag = trim(tag)
        f.alpha_composite(tag, ((32 - tag.width) // 2, 0))
        arrow = trim(colour_arrow(2, ramp))
        f.alpha_composite(arrow, ((32 - arrow.width) // 2, 48 - arrow.height))
        frames.append(f)
    s = strip(frames)
    save(s, "ui/player_tags.png", kind="ui", frame=[32, 48], grid=[4, 1], pivot=[16, 48],
         source="shipped fonts/font_hud.png + ui/icons.png cell 2 (arrow_down)",
         edits="'P1'..'P4' in the HUD font over the arrow recoloured to the slot's loincloth ramp (fill = cloth, "
               "light = the lighter of cloth / ink, shade = cloth shadow, outline #272018)",
         note="P1-P4 tag + colour arrow over a hero (D.1: at stage start and whenever heroes overlap; E.9 versus round "
              "start). Pivot = arrow tip: place it about 4 art px over the hero's head. Cells 0-3 = P1 yellow, P2 "
              "blue, P3 pink, P4 green (the slot defaults; a lobby colour choice re-tints with "
              "palettes/hero_palettes.json ui_colours)", section="ui")
    return s


def build_edge_arrows(palettes):
    """ui/player_arrows.png: per slot (rows) an arrow left / right / up / down for a hero off the view (D.2)"""
    order = [3, 1, 0, 2]                                           # icons.png: 0 up, 1 right, 2 down, 3 left
    frames = []
    for cname in SLOT_COLOURS:
        ramp = ui_ramp(palettes[cname])
        for i in order:
            frames.append(colour_arrow(i, ramp))
    s = strip(frames, cols=4)
    save(s, "ui/player_arrows.png", kind="ui", frame=[32, 32], grid=[4, 4], pivot=[16, 16],
         source="shipped ui/icons.png cells 0-3 (arrows)",
         edits="recoloured per slot like player_tags.png; outline -> #272018",
         note="edge arrows for a hero outside the view (D.2) and hit-direction cues: row = slot (P1-P4), column = "
              "left, right, up, down (cell = row * 4 + column). Show the stone countdown (countdown_stones.png) "
              "next to it", section="ui")
    return s


def blank_stone():
    """the code stone (30 x 22 sandstone pebble) with its carved dashes filled"""
    stone = asset("sprites/objects/code_stone.png")
    a = np.array(stone)
    fill = rgb("#ebb678")
    sol = a[..., 3] > 0
    inner = sol & ~rim(sol, 4)
    ry = np.mgrid[0:a.shape[0], 0:a.shape[1]][0]
    carved = inner & ~((a[..., 0] == fill[0]) & (a[..., 1] == fill[1]) & (a[..., 2] == fill[2])) & (ry < a.shape[0] - 6)
    a[carved] = tuple(fill) + (255,)
    return Image.fromarray(a, "RGBA")


def build_countdown():
    """ui/countdown_stones.png: the pebble with a carved digit 1-5 (D.2 'stone countdown')"""
    blank = blank_stone()
    carve, carve_d = rgb("#70604a"), rgb("#b99f7c")
    frames = []
    for d in range(1, 6):
        f = canvas(32, 32)
        f.alpha_composite(blank, (1, 32 - blank.height))
        g = canvas(20, 20)
        font_text(g, str(d), 0, 0)
        ga = np.array(g)
        light = (ga[..., 3] > 0) & (ga[..., :3].astype(int).sum(axis=2) > 450)
        dig = np.zeros_like(ga)
        dig[light] = tuple(carve) + (255,)
        sh = np.zeros(light.shape, bool)
        sh[1:, 1:] = light[:-1, :-1]
        dig[sh & ~light] = tuple(carve_d) + (255,)
        dg = trim(Image.fromarray(dig, "RGBA"))
        f.alpha_composite(dg, ((32 - dg.width) // 2 + 1, 32 - blank.height + (blank.height - dg.height) // 2))
        frames.append(f)
    s = strip(frames)
    save(s, "ui/countdown_stones.png", kind="ui", frame=[32, 32], grid=[5, 1], pivot=[16, 32],
         source="shipped sprites/objects/code_stone.png + fonts/font_hud.png digits",
         edits="the stone's carved dashes filled, a HUD-font digit carved in (dark fill + light groove)",
         note="stone countdown beside an edge arrow before a hero off the view turns into an egg (D.2: 5 s Beginner, "
              "3 s Expert). Cell = digit - 1 (0 = '1' ... 4 = '5')", section="ui")
    return s


def build_hero_start(palettes):
    """sprites/objects/hero_start.png: the slot's start marker (editor / preview, D.5 `objects/hero_start slot=n`)"""
    stone = blank_stone()
    frames = []
    for k, cname in enumerate(SLOT_COLOURS):
        ramp = ui_ramp(palettes[cname])
        f = canvas(32, 32)
        f.alpha_composite(stone, (1, 32 - stone.height))
        g = canvas(20, 20)
        font_text(g, str(k + 1), 0, 0)
        ga = np.array(g)
        light = (ga[..., 3] > 0) & (ga[..., :3].astype(int).sum(axis=2) > 450)
        ga[light, :3] = ramp["fill"]
        dark = (ga[..., 3] > 0) & ~light
        ga[dark, :3] = OUTLINE
        dg = trim(Image.fromarray(ga, "RGBA"))
        f.alpha_composite(dg, ((32 - dg.width) // 2 + 1, 32 - stone.height + (stone.height - dg.height) // 2 - 1))
        frames.append(f)
    s = strip(frames)
    save(s, "sprites/objects/hero_start.png", kind="object", frame=[32, 32], grid=[4, 1], pivot=[16, 32],
         source="shipped sprites/objects/code_stone.png + fonts/font_hud.png digits",
         edits="the stone's carved dashes filled; the slot digit in the HUD font, recoloured to the slot's "
               "loincloth colour, on the pebble",
         note="`objects/hero_start slot=n` marker (D.5; ignored in solo): cell = slot - 1. For the level preview / "
              "editor; the game need not draw it", section="objects")
    return s


def build(palettes):
    return {"belt": build_belt(), "tags": build_tags(palettes), "arrows": build_edge_arrows(palettes),
            "countdown": build_countdown(), "hero_start": build_hero_start(palettes)}


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    import build_hero_palettes as hp
    load_registry()
    build(hp.PALETTES)
    save_registry()

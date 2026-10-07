"""Versus screen and HUD art of phase 2 (DESIGN D.11, E.8, E.9; PLAN P2.11 art for ui-A's P2.8 screens and ui-B's
P2.9 HUD): who-is-who pictures in every hero colour, the round sundial, hit sparks in the attacker's colour, the award
medals, the scoreboard plate, the results cave wall and the heroes painted on it.

    ui/portraits.png            the Ninja Adventure caveman portrait (2x) per colour x expression (lobby, results)
    ui/portrait_heads.png       a small head per colour x expression (28 x 28: corner panels, bubbles)
    ui/sundial.png              the round sundial in 32 shadow steps (+ ui/sundial_rush.png, the Feast Rush rim)
    sprites/fx/hit_stars_players.png  the club-hit star burst in each hero colour (versus hits)
    ui/medals.png               the 6 co-op tally medals and the 13 versus awards (PlayerRun tables)
    ui/versus_plate.png         the scoreboard plate per colour (round wins as drumsticks on it)
    ui/cave_wall.png            the results backdrop: a torch-lit cave wall, 640 x 360
    ui/cave_paint_heroes.png    the heroes painted on that wall in victory poses, per colour

Sources (all CC0): Ninja Adventure (Pixel-boy and AAA) Actor/Character/Caveman/Faceset.png; the anchor pack Superpowers
Prehistoric Platformer (Pixel-boy) through shipped 1.0 files (ui/hud_lives_icon.png, sprites/fx/hit_stars.png's Sunny
Land star - ansimuz, sprites/objects/code_stone.png, pot.png, sprites/player/hero.png, backgrounds/cave/
layer0_wall.png, tiles/village/props/clay_pot.png); colours of palettes/hero_palettes.json. Exact swaps, crops, masks,
integer 2x for the Ninja art (DESIGN F.1); medals, dial and plate drawn by the pipeline in the anchor's palette.
"""
import os

import numpy as np
from PIL import Image

from xcommon import EXP, OUTLINE, asset, canvas, colours, load, rgb, save, strip, swap, trim, anim, flip
from build_coop_objects import grow, rim, paint, shape_mask
from build_hero_palettes import PALETTES, ui_ramp
from build_far_shore import reduce_mask

COLOURS = ["yellow", "blue", "pink", "green", "white", "gold"]          # UiPlayers.PALETTE_COLOURS order
EXPRESSIONS = ["normal", "ouch", "cheer"]
O4 = OUTLINE + (255,)
NA = os.path.join(EXP, "pixelboy-ninja-adventure-full", "Ninja Adventure - Asset Pack")
LIT, LIT_W, AMBER, AMBER_D = rgb("#ffe94f"), rgb("#fffed9"), rgb("#f3aa39"), rgb("#c97d10")
OCHRE, OCHRE_D = rgb("#b64e13"), rgb("#793a15")


def pal(name):
    return {k: rgb(v) for k, v in PALETTES[name].items()}


def flood_background(a, bg):
    """pixels of colour bg 4-connected to the picture's border (the faceset's dark square, not its eyes)"""
    h, w = a.shape[:2]
    is_bg = np.all(a[..., :3] == bg, axis=2)
    seen = np.zeros((h, w), bool)
    stack = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < h and 0 <= x < w and not seen[y, x] and is_bg[y, x]:
            seen[y, x] = True
            stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    return seen


# ---------------------------------------------------------------------------------------------------- portraits
F_BG, F_HAIR_D, F_GREY, F_RED, F_TRANS, F_SKIN, F_CLOTH = (rgb(h) for h in (
    "#141b1b", "#3b3643", "#4e484a", "#d14b34", "#d78b4a", "#ef914f", "#f1c471"))
EYES_N = [(12, 16), (13, 16), (12, 17), (13, 17), (17, 16), (18, 16), (17, 17), (18, 17)]   # faceset eye pixels
MOUTH_ROWS = (20, 21)


def faceset_expression(a, expr, ink):
    """redraw eyes and mouth of the faceset (1x) for an expression; ink = the eye / mouth colour"""
    if expr == "normal":
        return a
    skin = a[14, 15].copy()
    for x, y in EYES_N:
        a[y, x] = skin
    for y in MOUTH_ROWS:
        for x in range(9, 21):
            if np.all(a[y, x, :3] == ink):
                a[y, x] = skin
    def put(pts, col):
        for x, y in pts:
            a[y, x] = tuple(col) + (255,)
    if expr == "ouch":       # X eyes, a small round open mouth
        put([(11, 15), (13, 15), (12, 16), (11, 17), (13, 17), (17, 15), (19, 15), (18, 16), (17, 17), (19, 17)], ink)
        put([(14, 20), (15, 20), (13, 21), (16, 21), (14, 22), (15, 22)], ink)
        put([(14, 21), (15, 21)], rgb("#9c2a2a"))
    else:                    # cheer: happy arcs, a wide open grin with a tongue
        put([(11, 17), (12, 16), (13, 17), (17, 17), (18, 16), (19, 17)], ink)
        put([(x, 20) for x in range(10, 20)] + [(10, 21), (19, 21), (11, 22), (18, 22)] +
            [(x, 23) for x in range(12, 18)], ink)
        put([(x, 21) for x in range(11, 19)] + [(x, 22) for x in range(12, 18)], rgb("#9c2a2a"))
        put([(13, 22), (14, 22), (15, 22), (16, 22)], rgb("#e0394c"))
    return a


def portrait(colour, expr):
    """the Ninja Adventure caveman faceset in a hero colour: background cut away, skin -> the hero's skin ramp,
    tunic -> loincloth colour with ink spots, hair -> the palette's hair, a 1 px outline in the palette's outline
    colour (the slot's own outline), the expression redrawn, then integer 2x"""
    p = pal(colour)
    src = load(os.path.join(NA, "Actor", "Character", "Caveman", "Faceset.png"))
    a = np.array(src).copy()
    bg = flood_background(a, F_BG)
    a[bg] = 0
    ys = np.mgrid[0:a.shape[0], 0:a.shape[1]][0]
    is_c = lambda c: np.all(a[..., :3] == c, axis=2) & (a[..., 3] > 0)
    grey, hdark = is_c(F_GREY), is_c(F_HAIR_D)
    m = {}
    out = a.copy()
    out[is_c(F_SKIN), :3] = p["skin"]
    out[is_c(F_RED), :3] = p["skin_dark"]
    out[is_c(F_TRANS), :3] = p["cloth_shadow"]
    out[is_c(F_CLOTH), :3] = p["cloth"]
    out[(grey | hdark) & (ys < 12), :3] = p["hair_a"]
    out[(grey | hdark) & (ys >= 12), :3] = p["ink"]
    out[is_c(F_BG), :3] = p["outline"]                         # eyes, mouth, ear holes
    out = faceset_expression(out, expr, p["outline"])
    sol = out[..., 3] > 0
    edge = grow(sol, 1) & ~sol
    edge[-1:, :] = False                                       # the bust is cut at the bottom: no outline there
    out[edge] = tuple(p["outline"]) + (255,)
    im = Image.fromarray(out, "RGBA")
    im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
    cell = canvas(80, 80)
    cell.alpha_composite(im, ((80 - im.width) // 2, 80 - im.height))
    return cell


def build_portraits():
    frames = [portrait(c, e) for c in COLOURS for e in EXPRESSIONS]
    sheet = strip(frames, cols=len(EXPRESSIONS))
    save(sheet, "ui/portraits.png", kind="ui", frame=[80, 80], grid=[3, 6], pivot=[40, 80], section="versus",
         rows=COLOURS, columns=EXPRESSIONS,
         source="pixelboy-ninja-adventure-full: Actor/Character/Caveman/Faceset.png; colours of palettes/"
                "hero_palettes.json",
         edits="the faceset's dark square cut away (flood fill from the border; the eyes and ear holes stay), skin "
               "#ef914f / #d14b34 -> the hero's skin #ffa43a / #ec6c2f, the tunic #f1c471 -> the colour's loincloth "
               "(shadow for #d78b4a), its grey spots -> the colour's ink, the hair sprigs -> its hair, eyes and mouth "
               "-> its outline; ouch = X eyes and a small open mouth, cheer = happy arcs and an open grin (redrawn "
               "at 1x); a 1 px outline in the colour's outline (none along the cut bottom), then integer 2x (2 px "
               "outline, the anchor's weight), bottom-centred in 80 x 80",
         note="who-is-who portrait (E.9: 'the Ninja Adventure caveman portrait recoloured per player') for the "
              "versus lobby cards, the results columns and the co-op join panel. Row = the player's colour in "
              "UiPlayers.PALETTE_COLOURS order (0 yellow, 1 blue, 2 pink, 3 green, 4 white, 5 gold), column = "
              "expression (0 normal, 1 ouch: knocked out / lost the round, 2 cheer: won); cell = row * 3 + column. "
              "The bust (76 x 76) stands on the cell's bottom edge, pivot (40, 80)")
    return sheet


HW = 28                        # cell of a small head (fits hud_versus.gd's 32 px panels: PANEL_H 32, PAD 4)


def head(colour, expr):
    """a small who-is-who head: the 1.0 HUD head's silhouette (ui/hud_lives_icon.png) reduced 2:1 as a mask and
    painted flat in the hero's skin, the shaded side in skin_dark, a 1 px outline and the hair sprigs in the colour's
    outline / hair, 1 px eyes and mouth per expression, on a band of shoulders in the colour's loincloth"""
    p = pal(colour)
    src = np.array(asset("ui/hud_lives_icon.png"))
    sol = src[..., 3] > 0
    is_o = np.all(src[..., :3] == OUTLINE, axis=2) & sol
    is_s = np.all(src[..., :3] == rgb("#ec6c2f"), axis=2) & sol
    body = sol.copy()
    body[:7] = False                                               # the hair sprigs are drawn by hand below
    m = reduce_mask(body, 2, 0.5)                                  # 24 x 18
    shade = reduce_mask(is_s, 2, 0.5) & m
    h, w = m.shape
    a = np.zeros((HW, HW, 4), np.uint8)
    ox, oy = (HW - w) // 2, 5                                      # the head's top-left in the cell
    # shoulders: a band of loincloth under the chin (cut by the cell bottom, no outline there)
    yy, xx = np.mgrid[0:HW + 4, 0:HW]
    band = ((xx + 0.5 - HW / 2.0) / 12.5) ** 2 + ((yy + 0.5 - (HW + 3)) / 8.0) ** 2 <= 1
    bnd = np.zeros((HW + 4, HW, 4), np.uint8)
    paint(bnd, grow(band, 1) & ~band, p["outline"])
    paint(bnd, band, p["cloth"])
    paint(bnd, band & (xx >= HW // 2 + 4), p["cloth_shadow"])
    for sx, sy in ((8, HW - 2), (14, HW - 4), (19, HW - 2)):
        if band[sy, sx]:
            bnd[sy, sx] = tuple(p["ink"]) + (255,)
    a[:] = bnd[:HW]
    head_m = np.zeros((HW, HW), bool)
    head_m[oy:oy + h, ox:ox + w] = m
    sh = np.zeros((HW, HW), bool)
    sh[oy:oy + h, ox:ox + w] = shade
    paint(a, grow(head_m, 1) & ~head_m, p["outline"])
    paint(a, head_m, rgb("#ffa43a"))
    paint(a, sh, rgb("#ec6c2f"))
    # hair: two sprigs over the crown (the lives icon's, simplified)
    for x, y in ((ox + 11, oy - 1), (ox + 11, oy - 2), (ox + 12, oy - 3), (ox + 8, oy - 1), (ox + 7, oy - 2)):
        a[y, x] = tuple(p["hair_a"]) + (255,)
    ink = p["outline"]

    def put(pts, col):
        for x, y in pts:
            a[oy + y, ox + x] = tuple(col) + (255,)
    ex1, ex2, ey = 12, 15, 7                                       # eye and mouth places in the 24 x 18 head
    if expr == "normal":
        put([(ex1, ey), (ex1, ey + 1), (ex2, ey), (ex2, ey + 1)], ink)
        put([(12, 11), (13, 11), (14, 11), (15, 11), (16, 11)], ink)
    elif expr == "ouch":                                           # X eyes, one pixel further apart
        e1, e2 = ex1 - 1, ex2 + 1
        put([(e1 - 1, ey - 1), (e1 + 1, ey - 1), (e1, ey), (e1 - 1, ey + 1), (e1 + 1, ey + 1),
             (e2 - 1, ey - 1), (e2 + 1, ey - 1), (e2, ey), (e2 - 1, ey + 1), (e2 + 1, ey + 1)], ink)
        put([(13, 11), (14, 11), (13, 12), (14, 12)], rgb("#9c2a2a"))
        put([(12, 11), (15, 11), (12, 12), (15, 12)], ink)
    else:
        put([(ex1 - 1, ey + 1), (ex1, ey), (ex1 + 1, ey + 1), (ex2 - 1, ey + 1), (ex2, ey), (ex2 + 1, ey + 1)], ink)
        put([(x, 10) for x in range(11, 18)] + [(11, 11), (17, 11), (12, 12), (16, 12)], ink)
        put([(x, 11) for x in range(12, 17)] + [(13, 12), (14, 12), (15, 12)], rgb("#9c2a2a"))
    put([(9, 9), (10, 9)], rgb("#eb6439"))                         # a cheek
    return Image.fromarray(a, "RGBA")


def build_heads():
    frames = [head(c, e) for c in COLOURS for e in EXPRESSIONS]
    sheet = strip(frames, cols=len(EXPRESSIONS))
    save(sheet, "ui/portrait_heads.png", kind="ui", frame=[HW, HW], grid=[3, 6], pivot=[HW // 2, HW],
         section="versus", rows=COLOURS, columns=EXPRESSIONS,
         source="shipped ui/hud_lives_icon.png (superpowers-prehistoric-platformer hud: its silhouette); colours of "
                "palettes/hero_palettes.json",
         edits="the 1.0 lives head's silhouette (hair sprigs left out) reduced 2:1 as a mask (box filter + "
               "threshold) and painted flat: the hero's skin, its shaded side in skin_dark, a 1 px outline in the "
               "colour's outline, two hair sprigs in its hair, 1 px eyes / mouth per expression, a cheek; under the "
               "chin a band of shoulders in the colour's loincloth (shadow on the right, ink spots) cut by the cell",
         note="small who-is-who head (E.9: corner panels; bubbles for heroes above the view) that fits the 32 px "
              "versus panels: 28 x 28 cells, rows / columns as ui/portraits.png (row = colour 0 yellow ... 5 gold, "
              "column = 0 normal, 1 ouch, 2 cheer); pivot (14, 28) bottom-centre")
    return sheet


# ---------------------------------------------------------------------------------------------------- sundial
DW = 28                       # cell = the face (hud_versus.gd DIAL_PX 28, HudAtlas `dial` cells)
DIAL_FRAMES = 32              # HudAtlas.DIAL_FRAMES: frame f shows elapsed f / 31 of the round
STONE = {k: rgb(v) for k, v in (("l", "#fef8e8"), ("l2", "#ffe79d"), ("b", "#ebb678"), ("s", "#b99f7c"),
                                ("d", "#70604a"))}       # code_stone.png / stone_tablet.png
SHADOW, SHADOW_D = rgb("#a08664"), rgb("#7e6a4f")         # the gnomon's shadow on the sandstone
RUSH, RUSH_D = rgb("#ff6b5a"), rgb("#b32e22")


def dial_frame(f):
    """the stone face with the shadow swept clockwise from twelve over f / 31 of the dial (31 = all of it)"""
    a = np.zeros((DW, DW, 4), np.uint8)
    yy, xx = np.mgrid[0:DW, 0:DW]
    ox, oy = xx + 0.5 - DW / 2.0, yy + 0.5 - DW / 2.0
    r = np.hypot(ox, oy)
    ang = np.mod(np.arctan2(ox, -oy), 2 * np.pi)              # 0 at twelve, clockwise
    outer, rim_r = DW / 2.0 - 0.5, DW / 2.0 - 2.5
    elapsed = f / float(DIAL_FRAMES - 1)
    sweep = elapsed * 2 * np.pi
    paint(a, r <= outer, OUTLINE)
    face = r <= rim_r
    paint(a, face, STONE["b"])
    paint(a, face & (r > rim_r - 1.5) & (ang > 4.4), STONE["l2"])             # lit upper-left rim
    paint(a, face & (r > rim_r - 1.5) & (ang > 1.2) & (ang < 3.6), STONE["s"])  # shaded lower-right rim
    shade = face & ((ang < sweep) | (elapsed >= 1.0))
    paint(a, shade, SHADOW)
    paint(a, shade & (r > rim_r - 1.5), SHADOW_D)
    for h in range(12):                                                        # carved hour notches
        t = h * np.pi / 6
        for rr in ((rim_r - 3.0, rim_r - 2.0, rim_r - 1.0) if h % 3 == 0 else (rim_r - 2.0, rim_r - 1.0)):
            x = int(np.floor(DW / 2.0 + np.sin(t) * rr))
            y = int(np.floor(DW / 2.0 - np.cos(t) * rr))
            a[y, x] = STONE["d"] + (255,)
    if 0.0 < elapsed < 1.0:                                                    # the shadow's leading edge, carved
        for k in range(2, int(rim_r)):
            x = int(np.floor(DW / 2.0 + np.sin(sweep) * k))
            y = int(np.floor(DW / 2.0 - np.cos(sweep) * k))
            a[y, x] = STONE["d"] + (255,)
    for y in range(int(DW / 2.0 - rim_r + 3), DW // 2):                        # the bone gnomon to twelve
        a[y, DW // 2 - 1] = rgb("#f6efdd") + (255,)
        a[y, DW // 2] = rgb("#d8cdb4") + (255,)
    a[DW // 2 - 1:DW // 2 + 1, DW // 2 - 1:DW // 2 + 1] = AMBER + (255,)      # the bronze nub
    return Image.fromarray(a, "RGBA")


def rush_rim():
    a = np.zeros((DW, DW, 4), np.uint8)
    yy, xx = np.mgrid[0:DW, 0:DW]
    r = np.hypot(xx + 0.5 - DW / 2.0, yy + 0.5 - DW / 2.0)
    outer, rim_r = DW / 2.0 - 0.5, DW / 2.0 - 2.5
    paint(a, (r <= outer) & (r > rim_r), RUSH)
    paint(a, (r <= outer) & (r > outer - 0.9), RUSH_D)
    return Image.fromarray(a, "RGBA")


def build_sundial():
    frames = [dial_frame(f) for f in range(DIAL_FRAMES)]
    sheet = strip(frames, cols=8)
    save(sheet, "ui/sundial.png", kind="ui", frame=[DW, DW], grid=[8, DIAL_FRAMES // 8], pivot=[DW // 2, DW // 2],
         section="versus",
         source="drawn by the pipeline in the colours of shipped sprites/objects/code_stone.png (sandstone) and the "
                "anchor outline",
         edits="a 28 px stone face (1-2 px #272018 rim, lit upper-left / shaded lower-right edge, twelve carved hour "
               "notches with longer quarters, a bone gnomon to twelve on a bronze nub); the gnomon's shadow (two "
               "darker sandstones) swept clockwise from twelve, its leading edge carved",
         note="the round sundial (E.9; ui-B's HudAtlas `dial` group, hud_versus.gd DIAL_PX 28): 32 cells of 28 x 28 "
              "in 8 columns, cell f = the dial after f / 31 of the round has run (HudAtlas.dial_index(elapsed); 0 = "
              "round start, no shadow; 31 = the gong, all in shadow). Draw ui/sundial_rush.png over it in the Feast "
              "Rush. Pivot (14, 14) = the centre")
    rush = rush_rim()
    save(rush, "ui/sundial_rush.png", kind="ui", frame=[DW, DW], grid=[1, 1], pivot=[DW // 2, DW // 2],
         section="versus",
         source="drawn by the pipeline in hud_versus.gd's Feast Rush red (#ff6b5a)",
         edits="the dial's 2 px rim ring in #ff6b5a with a darker #b32e22 outer pixel; transparent inside",
         note="the Feast Rush overlay of the sundial (HudAtlas `dial_rush`): draw it over the current ui/sundial.png "
              "cell while the Feast Rush runs")
    return sheet


# ---------------------------------------------------------------------------------------------------- hit sparks
def build_hit_sparks():
    """sprites/fx/hit_stars.png's star burst recoloured into each hero colour: white body -> light, lavender
    shade -> fill, yellow core -> shade, purple rim -> dark; the black outline -> anchor outline"""
    src = asset("sprites/fx/hit_stars.png")
    rows = []
    for c in COLOURS:
        r = ui_ramp(PALETTES[c])
        m = {rgb("#ffffff"): r["light"] if c not in ("yellow", "white") else LIT_W, rgb("#ddd8e8"): r["fill"],
             rgb("#edbf5a"): r["shade"], rgb("#8e7da1"): r["dark"], (0, 0, 0): OUTLINE}
        if c == "white":
            m[rgb("#ddd8e8")] = rgb("#f7f4ec")
            m[rgb("#edbf5a")] = rgb("#b7bfd2")
        rows.append(swap(src, m))
    out = canvas(src.width, src.height * len(rows))
    for k, im in enumerate(rows):
        out.alpha_composite(im, (0, k * src.height))
    save(out, "sprites/fx/hit_stars_players.png", kind="fx", frame=[40, 41], grid=[6, len(COLOURS)], pivot=[20, 20],
         anims={"hit": anim([0, 1, 2, 3, 4, 5], 16, False)}, rows=COLOURS, section="fx",
         source="shipped sprites/fx/hit_stars.png (ansimuz Sunny Land star, as 1.0)",
         edits="exact swaps per colour (white -> the colour's light, lavender -> its loincloth, yellow core -> its "
               "shadow, purple rim -> its outline tint; black outline -> #272018); white uses its own greys",
         note="hit sparks in the attacker's colour (E.9): exactly the layout of fx/hit_stars.png (6 frames of 40 x 41, "
              "pivot (20, 20), `hit` 0-5 @16 fps once), one row per colour in UiPlayers.PALETTE_COLOURS order (0 "
              "yellow, 1 blue, 2 pink, 3 green, 4 white, 5 gold): frame f of a hit by a player wearing colour c = "
              "cell c * 6 + f")
    return out


# ---------------------------------------------------------------------------------------------------- awards
EMBLEMS = {
    "leaning_tower": ["....##..",
                      "...####.",
                      "...####.",
                      "..####..",
                      "..####..",
                      ".####...",
                      ".####...",
                      "####...."],
    "pickpocket": ["..#.#.....",
                   ".##.#.#...",
                   ".######.#.",
                   "#######.#.",
                   ".######...",
                   ".#####..##",
                   "..####.###",
                   "..###..##."],
    "glutton": [".......##.",
                "......####",
                ".....####.",
                "..######..",
                ".######...",
                "#######...",
                "######....",
                ".####....."],
    "butterfingers": ["..##......",
                      ".####.....",
                      ".####.....",
                      "..##......",
                      "..........",
                      ".#..#..#..",
                      "#.##.##.#.",
                      ".........."],
    "chain_gang": ["###.......",
                   "#.#.......",
                   "#####.....",
                   "..#.#.....",
                   "..#####...",
                   "....#.#...",
                   "....#####.",
                   "......#.#.",
                   "......###."],
    "clang_master": ["##......##",
                     "###....###",
                     ".###..###.",
                     "..##..##..",
                     "...####...",
                     "..##..##..",
                     ".##....##.",
                     "##......##"],
    "slugger": ["......###.",
                ".....####.",
                "....####..",
                "...###....",
                "..###.....",
                ".##....##.",
                "##....####",
                "......###."],
    "home_run": [".....###..",
                 "...##...#.",
                 "..#......#",
                 ".#.......#",
                 "#.....###.",
                 "#....####.",
                 ".....####.",
                 "......##.."],
    "hot_potato": ["..#..#..",
                   ".#..#...",
                   "..#..#..",
                   ".######.",
                   "########",
                   "########",
                   ".######.",
                   "..####.."],
    "lava_lover": ["...#....",
                   "..##..#.",
                   ".###.##.",
                   ".######.",
                   "########",
                   "########",
                   ".######.",
                   "..####.."],
    "head_case": ["#.#..#.#",
                  ".#....#.",
                  "#.####.#",
                  ".######.",
                  "########",
                  "##.##.##",
                  "########",
                  ".######."],
    "comeback_caveman": ["....##....",
                         "...####...",
                         "..######..",
                         ".########.",
                         "...####...",
                         "...####...",
                         "...####...",
                         "...####..."],
    "pacifist": ["...##...",
                 ".#.##.#.",
                 "########",
                 ".##..##.",
                 "########",
                 ".#.##.#.",
                 "...##...",
                 "...##..."],
    "most_food": ["....#...",
                  "...#....",
                  ".##.##..",
                  "#######.",
                  "#######.",
                  "#######.",
                  ".#####..",
                  "..#.#..."],
    "best_bounce_chain": [".#....#....#",
                          "#.#..#.#..#.",
                          "...##...##..",
                          "............",
                          "####.####.##",
                          ".##...##...#",
                          "####.####.##"],
    "hatchling": ["...##...",
                  "..####..",
                  ".######.",
                  ".##.#.#.",
                  "##.#.###",
                  "########",
                  "########",
                  ".######."],
    "strongman": ["..####..",
                  ".######.",
                  "########",
                  "##.#####",
                  "########",
                  "#####.##",
                  ".######.",
                  "..####.."],
    "clumsiest": ["....#....",
                  "...###...",
                  "..##.##..",
                  ".##...##.",
                  "##.....##",
                  ".........",
                  "#########",
                  ".#######."],
}
VERSUS_AWARDS = ["leaning_tower", "pickpocket", "glutton", "butterfingers", "chain_gang", "clang_master", "slugger",
                 "home_run", "hot_potato", "lava_lover", "head_case", "comeback_caveman", "pacifist"]
COOP_MEDALS = ["most_food", "best_bounce_chain", "hatchling", "slugger", "strongman", "clumsiest"]


def medal(emblem):
    """a gold medal disc (28 px in a 32 x 32 cell) with an engraved emblem; the ribbon is drawn by the screen in the
    winner's colour"""
    W = H = 32
    a = np.zeros((H, W, 4), np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    disc = shape_mask(W, H, lambda x, y: ((x - 16) / 13.5) ** 2 + ((y - 16) / 13.5) ** 2 - 1)
    paint(a, grow(disc, 1), OUTLINE)
    paint(a, disc, AMBER_D)
    inner = disc & ~rim(disc, 2)
    paint(a, inner, LIT)
    paint(a, inner & ((xx - 16) + (yy - 16) > 6), AMBER)                       # shaded lower right
    paint(a, inner & ((xx - 10) ** 2 + (yy - 10) ** 2 <= 5), LIT_W)          # glint upper left
    g = np.array([[ch == "#" for ch in line] for line in EMBLEMS[emblem]], bool)
    if max(g.shape) <= 10:                                                  # most emblems at double size
        g = np.repeat(np.repeat(g, 2, axis=0), 2, axis=1)
    gh, gw = g.shape
    x0, y0 = 16 - gw // 2, 16 - gh // 2
    for y in range(gh):
        for x in range(gw):
            if g[y, x]:
                a[y0 + y, x0 + x] = OCHRE_D + (255,)
                if y + 1 >= gh or not g[y + 1, x]:
                    a[y0 + y + 1, x0 + x] = LIT_W + (255,)                    # the engraving's light lip
    return Image.fromarray(a, "RGBA")


MEDAL_IDS = ["coop_" + e for e in COOP_MEDALS] + VERSUS_AWARDS


def build_medals():
    frames = [medal(e) for e in COOP_MEDALS] + [medal(e) for e in VERSUS_AWARDS]
    sheet = strip(frames)
    save(sheet, "ui/medals.png", kind="ui", frame=[32, 32], grid=[len(frames), 1], pivot=[16, 16], section="versus",
         ids=MEDAL_IDS,
         source="drawn by the pipeline in the anchor's gold (the hero cloth yellow #ffe94f / amber #f3aa39 / "
                "#c97d10, as ui/crown.png), outline #272018, emblem ochre #793a15",
         edits="a 28 px gold disc (2 px darker rim, lit upper left, shaded lower right, a glint) with an engraved "
               "emblem drawn by the pipeline (8-10 px glyphs at double size, the 12 px bounce arcs at 1x) with a light "
               "lip under every stroke",
         note="the medal discs of the co-op tally (D.11, PlayerRun.COOP_MEDALS order: cells 0-5 = " +
              ", ".join(COOP_MEDALS) + ") and of the versus awards (E.8, PlayerRun.VERSUS_AWARDS order: cells "
              "6-18 = " + ", ".join(VERSUS_AWARDS) + "); `ids` names every cell (co-op ones prefixed coop_). The "
              "screen draws the ribbon in the winner's colour and the disc over it; pivot (16, 16) = the disc's "
              "centre. Emblems: apple, bounce arcs, hatching egg, club and ball, boulder, banana peel; tilted food "
              "tower, grabbing hand, drumstick, dropped food, chain, crossed clubs, club and ball, ball arc, hot "
              "rock, flame, bonked head, up arrow, flower")
    return sheet


# ---------------------------------------------------------------------------------------------------- scoreboard plate
PW, PH = 96, 16


def plate(colour):
    """a clay plate (the shipped pot's colours) seen from slightly above, its rim painted in the player's colour"""
    r = ui_ramp(PALETTES[colour])
    a = np.zeros((PH, PW, 4), np.uint8)
    yy, xx = np.mgrid[0:PH, 0:PW]
    top = shape_mask(PW, PH, lambda x, y: ((x - PW / 2) / (PW / 2 - 1)) ** 2 + ((y - 6) / 5.5) ** 2 - 1)
    foot = (yy >= 10) & (yy < PH - 1) & (np.abs(xx + 0.5 - PW / 2) <= 24 - (yy - 10) * 1.5)
    body = top | foot
    paint(a, grow(body, 1) & ~body, OUTLINE)
    paint(a, body, rgb("#893317"))
    dish = top & ~rim(top, 3)
    paint(a, dish, rgb("#d9732d"))
    paint(a, dish & (yy <= 4), rgb("#c35b27"))                                     # the far inner wall in shade
    band = top & rim(top, 3)
    paint(a, band, r["fill"])                                                     # the painted rim band
    paint(a, band & (yy >= 7), r["shade"])
    paint(a, top & rim(top, 1), r["dark"])
    paint(a, band & ~rim(top, 2) & (yy <= 3) & (xx < PW // 2) & (xx > 12), r["light"])
    return Image.fromarray(a, "RGBA")


def build_plates():
    sheet = strip([plate(c) for c in COLOURS], cols=1)
    save(sheet, "ui/versus_plate.png", kind="ui", frame=[PW, PH], grid=[1, 6], pivot=[PW // 2, 6], section="versus",
         rows=COLOURS,
         source="drawn by the pipeline in the four colours of shipped sprites/objects/pot.png (clay) and the colour's "
                "UI ramp (palettes/hero_palettes.json)",
         edits="an oval clay plate seen from slightly above (the far inner wall in shade, a short tapered foot, 1 px "
               "#272018 outline) with its 3 px rim band painted in the colour (fill, shadow on the near side, dark "
               "edge, light glint)",
         note="the scoreboard plate (E.8 step 6: round wins as drumsticks thrown onto each player's plate): row = "
              "colour (UiPlayers.PALETTE_COLOURS order). Pivot (48, 6) = the middle of the plate's top: put the "
              "drumsticks (ui/stack_food.png cell 5, 32 x 28, pivot at their foot) on that line, 14-18 px apart; "
              "five fit")
    return sheet


# ---------------------------------------------------------------------------------------------------- cave wall
CAVE_RAMP = ["#2a1c18", "#3d2a20", "#55392a", "#6e4a33", "#8a5f3f", "#a8774d"]


def build_cave_wall():
    """backgrounds/cave/layer0_wall.png (the 1.0 cave wall) gradient-mapped to torch-lit sandstone, brighter in a
    wide oval behind the painted heroes; two torches of the village's clay-pot fire on the sides"""
    src = asset("backgrounds/cave/layer0_wall.png").crop((40, 0, 680, 360))
    cs = sorted(colours(src), key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
    a = np.array(src).copy()
    yy, xx = np.mgrid[0:360, 0:640]
    glow = ((xx - 320) / 330.0) ** 2 + ((yy - 170) / 210.0) ** 2           # < 1 inside the lit oval
    lift = np.where(glow < 0.45, 2, np.where(glow < 0.8, 1, 0))
    stops = [rgb(h) for h in CAVE_RAMP]
    idx = {c: min(3, int(round(i / max(1, len(cs) - 1) * 3))) for i, c in enumerate(cs)}
    out = np.zeros_like(a)
    for c, i in idx.items():
        m = np.all(a[..., :3] == c, axis=2)
        for lv in (0, 1, 2):
            mm = m & (lift == lv)
            out[mm, :3] = stops[min(len(stops) - 1, i + lv)]
    out[..., 3] = 255
    im = Image.fromarray(out, "RGBA")
    # two torch brackets with a flame (the cookpot's fire, frame 0)
    from build_versus import flames
    fl = flames(0)
    for tx in (36, 640 - 36):
        br = np.zeros((40, 12, 4), np.uint8)
        br[8:40, 4:8] = rgb("#5b4434") + (255,)
        br[8:40, 7] = rgb("#3b2c22") + (255,)
        br[4:10, 1:11] = rgb("#7f3910") + (255,)
        br[4, 1:11] = rgb("#aa5424") + (255,)
        m = br[..., 3] > 0
        br[grow(m, 1) & ~m] = O4
        b = Image.fromarray(br, "RGBA")
        im.alpha_composite(b, (tx - 6, 120))
        im.alpha_composite(fl, (tx - fl.width // 2, 124 - fl.height + 6))
    save(im, "ui/cave_wall.png", kind="ui", frame=[640, 360], grid=[1, 1], section="versus",
         source="shipped backgrounds/cave/layer0_wall.png (1.0 cave set); the flames of superpowers-prehistoric-"
                "platformer: background-elements/fire-meat.png (as the cookpot)",
         edits="the wall's 640 x 360 middle, its colours snapped by luminance rank onto a six-step torch-lit "
               "sandstone ramp, two steps lighter in a wide oval in the middle and one step on its edge (banded, "
               "no new colours); two torch brackets drawn by the pipeline with the cookpot's fire on them",
         note="the versus results backdrop (E.8 step 7: 'the heroes painted on a cave wall'): draw it behind the "
              "results (and the scoreboard if wanted), then ui/cave_paint_heroes.png figures in the lit oval, the "
              "ledge and the companion in front")
    return im


# ---------------------------------------------------------------------------------------------------- painted heroes
PAINT_FRAMES = [48, 49, 0]          # hero.png: victory a, victory b, idle


def painted(colour, frame, seed):
    """the hero frame as a cave painting: silhouette filled flat in the colour's loincloth pigment, a darker
    pigment stroke along the edge and for the inner lines (outline pixels), the skin areas left unpainted (rock
    shows through) except a thin contour, a few dry-brush gaps (deterministic)"""
    r = ui_ramp(PALETTES[colour])
    sheet = asset("sprites/player/hero.png")
    c = sheet.crop(((frame % 8) * 176, (frame // 8) * 112, (frame % 8 + 1) * 176, (frame // 8 + 1) * 112))
    a = np.array(c)
    sol = a[..., 3] > 0
    is_out = np.all(a[..., :3] == OUTLINE, axis=2) & sol
    rng = np.random.RandomState(seed)
    out = np.zeros_like(a)
    fill = sol & ~is_out
    out[fill] = tuple(r["fill"]) + (210,)
    out[is_out] = tuple(r["dark"]) + (240,)
    gaps = fill & (rng.rand(*sol.shape) < 0.05)
    out[gaps] = 0
    edge = sol & ~np.roll(sol, 1, 0) | sol & ~np.roll(sol, -1, 0) | sol & ~np.roll(sol, 1, 1) | sol & ~np.roll(sol, -1, 1)
    out[edge] = tuple(r["dark"]) + (240,)
    return Image.fromarray(out, "RGBA")


def build_painted_heroes():
    frames = []
    for k, c in enumerate(COLOURS):
        for j, f in enumerate(PAINT_FRAMES):
            frames.append(painted(c, f, k * 10 + j))
    sheet = strip(frames, cols=len(PAINT_FRAMES))
    save(sheet, "ui/cave_paint_heroes.png", kind="ui", frame=[176, 112], grid=[3, 6], pivot=[88, 96],
         section="versus", rows=COLOURS, columns=["victory_a", "victory_b", "stand"],
         anims={"cheer": anim([0, 1], 4)},
         source="shipped sprites/player/hero.png (frames 48, 49, 0); colours of palettes/hero_palettes.json",
         edits="the hero's silhouette painted flat in the colour's loincloth pigment (alpha 210: the wall shows "
               "through), its outline pixels and its edge in the colour's dark tint (alpha 240), about 5 % dry-brush "
               "gaps (deterministic noise)",
         note="the heroes painted on the cave wall in their colours (E.8 step 7) for the results over "
              "ui/cave_wall.png: the 176 x 112 cells, grid and pivot (88, 96) of hero.png. Row = colour "
              "(UiPlayers.PALETTE_COLOURS order), columns 0-1 victory (`cheer` loop: the winners), 2 standing (the "
              "others); cell = row * 3 + column")
    return sheet


def build():
    return {"portraits": build_portraits(), "heads": build_heads(), "sundial": build_sundial(),
            "sparks": build_hit_sparks(), "medals": build_medals(), "plates": build_plates(),
            "cave_wall": build_cave_wall(), "painted": build_painted_heroes()}


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()

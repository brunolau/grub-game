"""Book II's map page, the Cave Painting slab and mural, and the painting unlock icons (DESIGN A.1, C.9, F.1;
GAMEPLAY 13.7; PLAN P2.11 art for ui-A's P2.8 map page / unlocks screen and The Long Raft Home's last picture).

    ui/world_map_far_shore.png  1280 x 360, the second map page: the 1.0 sky and sea with the five Far Shore islands
    ui/painting_slab.png        the stone slab with 30 empty sockets (6 x 5), a count plate and six carved unlock marks
    ui/mural.png                the full mural: what the 30 sockets show once every painting is found (piece i = the
                                24 x 16 rect at column i % 6, row i / 6); also the picture that ends The Long Raft Home
    ui/unlock_icons.png         the six rewards of C.9 (row 0 carved = locked, row 1 painted = unlocked)

Sources (all CC0): the anchor pack Superpowers Prehistoric Platformer (Pixel-boy) - background-elements sky-1, sea-1,
island-1, cloud-1 (the 1.0 map's own pieces) and shipped 1.0 sprites; art-B's 2.0 world 5 / 6 files (canyon mesas and
spires, swamp canopies, the dead tree, the carved ruin blocks), which are themselves recolours of CC0 packs (17.6).
Everything is recoloured by exact swaps or palette-snapping gradient maps, cropped and composited at 1x
(nearest-neighbour). The mural's figures are the shipped sprites' silhouettes: the alpha mask reduced by an integer
factor (box filter + threshold, the way a cave painter simplifies a shape) and painted flat in cave pigments.
"""
import os

import numpy as np
from PIL import Image

from xcommon import AP, OUTLINE, asset, canvas, colours, load, rgb, save, strip, swap, trim, flip
from build_coop_objects import grow, rim, paint, shape_mask

W, H = 1280, 360
O4 = OUTLINE + (255,)
BG = os.path.join(AP, "background-elements")
SRC_AP = "superpowers-prehistoric-platformer: background-elements/"


def bg_el(name):
    return load(os.path.join(BG, name))


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def snap_map(im, ramp, keep=()):
    """palette-snapping gradient map: every colour goes to the ramp stop nearest its luminance rank among the
    image's own colours (darkest colour -> first stop, lightest -> last); listed colours are kept"""
    cs = sorted((c for c in colours(im) if c not in keep), key=lum)
    stops = [rgb(h) for h in ramp]
    m = {}
    for i, c in enumerate(cs):
        t = 0.0 if len(cs) == 1 else i / (len(cs) - 1.0)
        m[c] = stops[min(len(stops) - 1, int(round(t * (len(stops) - 1))))]
    return swap(im, m)


def drop_outline(im, to):
    """background-element style: the anchor outline of a prop becomes its darkest shade (map pieces have none)"""
    return swap(im, {OUTLINE: rgb(to)})


def mask_of(im):
    return np.array(im)[..., 3] > 0


def reduce_mask(m, n, thresh=0.45):
    """an alpha mask reduced n:1 (box filter + threshold): the silhouette a cave painter would make of it"""
    h, w = m.shape
    h2, w2 = (h + n - 1) // n, (w + n - 1) // n
    p = np.zeros((h2 * n, w2 * n), float)
    p[:h, :w] = m
    return p.reshape(h2, n, w2, n).mean(axis=(1, 3)) >= thresh


def crop_mask(m):
    ys, xs = np.nonzero(m)
    return m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


# ---------------------------------------------------------------------------------------------------- map page
# the 1.0 map: sky-1 (0, 60, 800, 420) and sea-1 at y 150, tiled at x 0 and 800 (docs/art/pipeline/build_env.py)
def sky_and_sea():
    sea = canvas(W, H)
    sky = bg_el("sky-1.png").crop((0, 60, 800, 420))
    sea_im = bg_el("sea-1.png")
    for x in (0, 800):
        sea.alpha_composite(sky.crop((0, 0, min(800, W - x), 360)), (x, 0))
        sea.alpha_composite(sea_im.crop((0, 0, min(800, W - x), 215)), (x, 150))
    return sea


ISLAND = (69, 0, 383, 112)          # island-1.png: the big island (314 x 112); its sand line is row 95-101
ROCKS = (475, 28, 689, 80)          # island-1.png: the two grey rocks
I_GREEN, I_GREEN_D, I_ROCK, I_SAND, I_SAND_Y, I_CAVE = (rgb(h) for h in (
    "#82c84d", "#6f9f5b", "#b46858", "#e79755", "#e7d463", "#5e6768"))
I_GREY, I_SAGE = rgb("#92969e"), rgb("#b8c198")

# per island: the island-1 colours -> the land's colours (exact swaps; foam and water kept)
ISLAND_SKINS = {
    "mesa": {I_GREEN: "#b7aa5c", I_GREEN_D: "#8c7d43", I_ROCK: "#b4513f", I_SAND: "#e08a4f", I_SAND_Y: "#f2c27c",
             I_CAVE: "#6e3428"},
    "delta": {I_GREEN: "#5a7a3e", I_GREEN_D: "#3f5a30", I_ROCK: "#4d3a2b", I_SAND: "#735944", I_SAND_Y: "#8d7358",
              I_CAVE: "#2f2620"},
    "coast": {I_GREEN: "#5fc08a", I_GREEN_D: "#3f8f6d", I_ROCK: "#e27d6d", I_SAND: "#f0c27c", I_SAND_Y: "#fbe3a3",
              I_CAVE: "#9c4f58"},
    "idol": {I_GREEN: "#57a84a", I_GREEN_D: "#3c7a45", I_ROCK: "#c9a46a", I_SAND: "#d99a5a", I_SAND_Y: "#e7d463",
             I_CAVE: "#5a6b55"},
}
# the grey rocks of island-1 as sea stacks (coral) and as the spire's foot (storm slate)
ROCK_SKINS = {"coast": {I_GREY: "#d9796a", I_SAGE: "#f0c27c"}, "spire": {I_GREY: "#525b78", I_SAGE: "#8a93ad"}}


def island(skin, mirror=False):
    im = bg_el("island-1.png").crop(ISLAND)
    im = swap(im, {k: rgb(v) for k, v in ISLAND_SKINS[skin].items()})
    return flip(im) if mirror else im


def rocks(skin, mirror=False):
    im = bg_el("island-1.png").crop(ROCKS)
    im = swap(im, {k: rgb(v) for k, v in ROCK_SKINS[skin].items()})
    return flip(im) if mirror else im


def _profile(a, x):
    """top row and bottom row of the island's column x (the outline a seam must match)"""
    col = np.nonzero(a[:, x, 3])[0]
    return (int(col.min()), int(col.max())) if len(col) else (999, -1)


def narrow_island(im, width):
    """the island made `width` px narrow by taking a slice out of its middle: the seam goes where the two columns
    that meet have the nearest outline (top and bottom rows) and the most equal colours, so the joint does not show"""
    a = np.array(im)
    w = a.shape[1]
    cut = w - width
    best = None
    for x0 in range(w // 4, w - w // 4 - cut):
        x1 = x0 + cut
        t0, b0 = _profile(a, x0 - 1)
        t1, b1 = _profile(a, x1)
        score = abs(t0 - t1) * 4 + abs(b0 - b1) * 4 + int(np.sum(np.any(a[:, x0 - 1] != a[:, x1], axis=1)))
        if best is None or score < best[0]:
            best = (score, x0, x1)
    _, x0, x1 = best
    return Image.fromarray(np.concatenate([a[:, :x0], a[:, x1:]], axis=1), "RGBA")


def extend_down(im, n):
    """every column that reaches the piece's bottom row continues n px further in that row's colour, so a piece cut
    out of a layer above its base (a straight bottom edge) stands on the island drawn over it instead of floating"""
    a = np.array(im)
    h, w = a.shape[:2]
    out = np.zeros((h + n, w, 4), np.uint8)
    out[:h] = a
    reach = a[h - 1, :, 3] > 0
    out[h:, reach] = a[h - 1, reach]
    return Image.fromarray(out, "RGBA")


def slope_left(im, k, top, bottom):
    """a piece cut out of a wider rock group gets a sloping left flank instead of the cut's vertical edge: in the k
    leftmost columns the rows top..bottom - 1 are cleared above a line from (k, top) down to (0, bottom); the foam
    and water rows under `bottom` stay"""
    a = np.array(im)
    for c in range(k):
        lim = top + (bottom - top) * (k - c) / float(k)
        for r in range(top, bottom):
            if r < lim:
                a[r, c] = 0
    return Image.fromarray(a, "RGBA")


def mesa_piece():
    """art-B's small canyon mesa (backgrounds/canyon/layer2_mesas.png x 400-522, rows 184-234: the mesa alone, above
    the layer's rock band) in the island's reds, its foot carried 30 px down (extend_down) so that the island drawn
    over it hides the cut: the mesa rises out of the island"""
    m = asset("backgrounds/canyon/layer2_mesas.png").crop((400, 184, 522, 234))
    return extend_down(snap_map(m, ["#6e3428", "#94402f", "#b4513f", "#c96a4e", "#e8a386"]), MESA_FOOT)


MESA_FOOT = 30
MESA_ISLE_AT, MESA_ON_ISLE = (6, 134), (74, -22)     # the mesa island on the page; the mesa relative to it
# the coral sea stacks behind 7's isle: the mirrored rock group cut at column 90 (the ridge between its two rocks),
# its cut flank sloped down to the foam over 16 columns (rock rows 20-44, foam from row 45)
COAST_CUT, COAST_SLOPE, COAST_ROCK_ROWS = 90, 16, (20, 45)


def spire_piece():
    """art-B's tallest far spire (backgrounds/canyon/layer1_far_spires.png x 95-240, rows 72-268) as storm slate"""
    s = asset("backgrounds/canyon/layer1_far_spires.png").crop((95, 72, 240, 268))
    return snap_map(s, ["#3a3f55", "#525b78", "#6c7590", "#8a93ad", "#a8b0c8"])


STORM = {rgb("#e6fcff"): rgb("#5d6283"), rgb("#cbf3ff"): rgb("#454a68"), rgb("#fcffff"): rgb("#7a7f9e")}


def storm_cloud(w, h, puffs):
    """a storm cloud: a union of round puffs (bumpy underside) filled with cloud-1.png's own three tones,
    recoloured to slate (the pack's shading kept inside a clean silhouette)"""
    tex = swap(bg_el("cloud-1.png").crop((0, 200, w, 200 + h)), STORM)
    t = np.array(tex)
    m = np.zeros((h, w), bool)
    ys, xs = np.mgrid[0:h, 0:w]
    for cx, cy, r in puffs:
        m |= (xs + 0.5 - cx) ** 2 + (ys + 0.5 - cy) ** 2 <= r * r
    out = np.zeros_like(t)
    out[m] = t[m]
    out[m & (out[..., 3] == 0)] = rgb("#454a68") + (255,)
    out[m, 3] = 255
    below = np.zeros_like(m)
    below[:-2] = m[2:]
    under = m & ~below                                      # the dark underside of every puff (2 px)
    under[:2] = False
    out[under] = rgb("#363a54") + (255,)
    return Image.fromarray(out, "RGBA")


BOLT = ["....##",
        "...##.",
        "..##..",
        ".#####",
        "...##.",
        "..##..",
        ".##...",
        "##....",
        "#....."]


def bolt():
    a = np.zeros((len(BOLT) + 2, len(BOLT[0]) + 2, 4), np.uint8)
    core = np.zeros(a.shape[:2], bool)
    for y, line in enumerate(BOLT):
        for x, ch in enumerate(line):
            core[y + 1, x + 1] = ch == "#"
    a[grow(core, 1) & ~core] = (255, 255, 255, 255)
    a[core] = rgb("#ffe94f") + (255,)
    return Image.fromarray(a, "RGBA")


def mangrove():
    """the giant mangrove of the tar delta: art-B's swamp dead tree on the mangrove trunk, crowned with murky
    canopies (anchor outlines turned into the darkest shade)"""
    out = canvas(150, 128)
    tree = drop_outline(asset("tiles/swamp/props/dead_tree.png"), "#1b1410")
    trunk = drop_outline(asset("tiles/swamp/props/mangrove_trunk.png"), "#1b1410")
    can = drop_outline(asset("tiles/swamp/props/canopy_murky.png"), "#141c12")
    moss = drop_outline(asset("tiles/swamp/props/canopy_moss.png"), "#141c12")
    out.alpha_composite(tree, (19, 26))
    out.alpha_composite(trunk, (36, 128 - trunk.height))
    out.alpha_composite(moss.crop((0, 0, 112, 52)), (0, 8))
    out.alpha_composite(can.crop((0, 0, 112, 56)), (38, 0))
    return trim(out)


SANDSTONE = (rgb("#f2d29b"), rgb("#d9ae6c"), rgb("#a87c45"), rgb("#6b4f2c"))     # light, base, shade, dark
JADE = (rgb("#a6ee7c"), rgb("#5fc08a"), rgb("#2b6a4d"), rgb("#173a2c"))


def temple_gate():
    """the idol isle's temple gate in background-element style (flat tones, no outline): two pillars, a stepped
    lintel and two jade idols on plinths before it; drawn by the pipeline in sandstone and jade"""
    gw, gh = 76, 58
    a = np.zeros((gh, gw, 4), np.uint8)
    L, B, S_, D = SANDSTONE

    def box(x0, y0, x1, y1):
        a[y0:y1, x0:x1] = B + (255,)
        a[y0:y1, x1 - 3:x1] = S_ + (255,)
        a[y0:y0 + 2, x0:x1 - 1] = L + (255,)
        a[y1 - 1:y1, x0:x1] = D + (255,)
    a[16:gh, 22:54] = rgb("#3a2f22") + (255,)     # the dark doorway
    box(10, 16, 22, gh)                     # pillars
    box(54, 16, 66, gh)
    for yb in range(24, gh, 9):             # block joints on the pillars
        a[yb, 10:22] = S_ + (255,)
        a[yb, 54:66] = S_ + (255,)
    box(4, 8, 72, 16)                       # lintel and its cap
    box(14, 2, 62, 8)
    for x in range(10, 66, 7):              # carved notches on the lintel
        a[11:13, x:x + 3] = D + (255,)
    a[16:18, 22:54] = D + (255,)
    # two idols (dino-head statues, jade) on plinths
    idol = ["..###.", ".#####", "##.###", "######", ".####.", "..##..", ".####.", "######"]
    for ox in (0, gw - 6):
        for y, line in enumerate(idol):
            for x, ch in enumerate(line):
                if ch == "#":
                    c = JADE[0] if y <= 1 else (JADE[1] if x < 3 else JADE[2])
                    a[gh - 14 + y, ox + x] = c + (255,)
        a[gh - 6:gh, ox:ox + 6] = S_ + (255,)
        a[gh - 6, ox:ox + 6] = L + (255,)
    return Image.fromarray(a, "RGBA")


CACTUS = ["..#..",
          "#.#..",
          "#.#.#",
          "###.#",
          "..###",
          "..#..",
          "..#.."]


def tiny_cactus():
    a = np.zeros((len(CACTUS), len(CACTUS[0]), 4), np.uint8)
    for y, line in enumerate(CACTUS):
        for x, ch in enumerate(line):
            if ch == "#":
                a[y, x] = rgb("#3f7a3a" if x <= 2 else "#2d5a2c") + (255,)
    return Image.fromarray(a, "RGBA")


def tar_pool(w, h):
    pool = shape_mask(w, h, lambda px, py: ((px - w / 2.0) / (w / 2.0 - 1)) ** 2 + ((py - h / 2.0) / (h / 2.0 - 0.3)) ** 2 - 1)
    pa = np.zeros((h, w, 4), np.uint8)
    paint(pa, pool, rgb("#1e1628"))
    py_, px_ = np.mgrid[0:h, 0:w]
    paint(pa, pool & (py_ <= h // 2 - 1) & (px_ > w // 6) & (px_ < w // 2), rgb("#4a3a62"))
    paint(pa, pool & (py_ == h // 2 - 1) & (px_ > w // 4) & (px_ < w // 4 + 5), rgb("#a892c4"))
    return Image.fromarray(pa, "RGBA")


# the map stops (map px, centre of the marker) of the 11 Book II campaign stops, by (world, stage) as world_map.gd's
# MARKERS: every marker stands on sand or grass, its number plate (12 px under the centre, 12 px tall) on the land or
# the foam, and two markers at least 56 px apart. Filled in by build_map() from the island places.
MARKERS = {}


def build_map(write=True):
    m = sky_and_sea()
    # home, far away on the left horizon: the small grey rock of island-1 (the way back)
    m.alpha_composite(bg_el("island-1.png").crop((0, 63, 33, 73)), (8, 146))
    # --- 5 Sunbaked Canyon: the red mesa
    x, y = MESA_ISLE_AT
    im = island("mesa")
    mesa = mesa_piece()
    m.alpha_composite(mesa, (x + MESA_ON_ISLE[0], y + MESA_ON_ISLE[1]))
    m.alpha_composite(im, (x, y))
    for cx, cy in ((x + 116, y + 60), (x + 236, y + 70), (x + 42, y + 84)):
        c = tiny_cactus()
        m.alpha_composite(c, (cx, cy - c.height))
    MARKERS[(5, 1)] = (x + 52, y + 92)
    MARKERS[(5, 2)] = (x + 214, y + 84)
    # --- 6 Tar Fen: the tar delta and the giant mangrove
    x, y = 300, 150
    im = narrow_island(island("delta", True), 236)
    mg = mangrove()
    m.alpha_composite(im, (x, y))
    m.alpha_composite(mg, (x + 70, y + 66 - mg.height))
    m.alpha_composite(tar_pool(48, 7), (x + 66, y + 86))
    m.alpha_composite(tar_pool(36, 6), (x + 186, y + 82))
    MARKERS[(6, 1)] = (x + 40, y + 76)
    MARKERS[(6, 2)] = (x + 168, y + 74)
    # --- 7 Coral Coast: sand isle with coral sea stacks behind it
    x, y = 562, 136
    m.alpha_composite(rocks("coast"), (x + 70, y + 46))
    m.alpha_composite(slope_left(rocks("coast", True).crop((COAST_CUT, 0, 214, 52)), COAST_SLOPE, *COAST_ROCK_ROWS),
                      (x - 26, y + 34))
    im = narrow_island(island("coast"), 214)
    m.alpha_composite(im, (x, y + 8))
    MARKERS[(7, 1)] = (x + 38, y + 98)
    MARKERS[(7, 2)] = (x + 156, y + 92)
    # --- 8 Idol Ruins: the idol isle behind its temple gate
    x, y = 786, 152
    im = narrow_island(island("idol", True), 230)
    gate = temple_gate()
    m.alpha_composite(gate, (x + 84, y + 46 - gate.height))
    m.alpha_composite(im, (x, y))
    MARKERS[(8, 1)] = (x + 46, y + 80)
    MARKERS[(8, 2)] = (x + 176, y + 78)
    # --- 9 Sky Spire: the spire into the storm cloud, on slate rocks
    x, y = 1030, 138
    sp = spire_piece()
    m.alpha_composite(sp, (x + 30, y + 62 - sp.height))
    m.alpha_composite(rocks("spire"), (x, y + 30))
    puffs = [(0, 20, 34), (40, 34, 30), (84, 44, 30), (130, 46, 32), (176, 40, 30), (214, 30, 30), (250, 12, 30),
             (100, 16, 34), (170, 12, 34), (60, 6, 30)]
    m.alpha_composite(storm_cloud(260, 80, puffs), (W - 260, 0))
    for bx, by in ((x + 26, 70), (x + 150, 78), (x + 196, 66)):
        m.alpha_composite(bolt(), (bx, by))
    MARKERS[(9, 1)] = (x + 34, y + 76)
    MARKERS[(9, 2)] = (x + 156, y + 78)
    MARKERS[(9, 3)] = (x + 104, y - 34)
    if not write:
        return m
    meta = {"markers": {"%d-%d" % k: list(v) for k, v in sorted(MARKERS.items())}}
    save(m, "ui/world_map_far_shore.png", kind="ui", frame=[W, H], grid=[1, 1], section="far_shore", **meta,
         source="shipped ui/world_map_background.png's own pieces (" + SRC_AP + "sky-1.png, sea-1.png, island-1.png, "
                "cloud-1.png); art-B's backgrounds/canyon/layer2_mesas.png, backgrounds/canyon/layer1_far_spires.png, "
                "tiles/swamp/props/dead_tree.png, tiles/swamp/props/mangrove_trunk.png, "
                "tiles/swamp/props/canopy_murky.png and tiles/swamp/props/canopy_moss.png",
         edits="the 1.0 sky and sea rebuilt exactly as the 1.0 map; four copies of island-1's big island (made "
               "narrower by a slice out of the middle at the best-matching seam, some mirrored) and its grey rocks, "
               "recoloured by exact swaps (mesa reds, fen bark and tar, coral and pale sand, jungle with sandstone, "
               "storm slate; the coral group's cut flank sloped down to its foam); on them a canyon mesa (its foot "
               "carried down behind the island) and the far spire (palette-snapping gradient maps), the swamp "
               "dead tree on the mangrove trunk under murky canopies (the giant mangrove), tar pools in the tar "
               "liquid's colours; drawn by the pipeline in background-element style (flat tones, no outline): three "
               "tiny cacti, the temple gate with two jade idols, the lightning bolts, and the storm cloud's silhouette "
               "(round puffs filled with cloud-1's own three tones in slate); every prop's anchor outline turned into "
               "its darkest shade",
         note="Book II's map page (A.1, ui-A P2.8): the second 1280 x 360 page, east of the home islands, drawn like "
              "world_map_background.png (SKY_COLOR / SEA_COLOR fill beyond it). Islands left to right: 5 the red mesa, "
              "6 the tar delta with the giant mangrove, 7 the coral coast with its sea stacks, 8 the idol isle with "
              "its temple gate, 9 the spire into the storm; the speck on the far-left horizon is home. `markers` (map "
              "px, by 'world-stage') = the 11 stops on sand or grass with their number plates clear (world_map.gd "
              "MARKERS_B2); every marker y is at most 238, so the sea under y 262 stays free for the painting slab "
              "that world_map.gd draws as screen UI in the lower-right corner")
    return m


# ---------------------------------------------------------------------------------------------------- mural
MW, MH = 144, 80                     # the mural
PW, PH = 24, 16                      # one piece (6 x 5)
SAND = {k: rgb(v) for k, v in (("o", "#272018"), ("l", "#fef8e8"), ("l2", "#ffe79d"), ("b", "#ebb678"),
                                ("s", "#b99f7c"), ("d", "#70604a"))}         # stone_tablet.png's colours
OCHRE, OCHRE_D = rgb("#b64e13"), rgb("#793a15")
CHAR = rgb("#3f2a1c")                # charcoal
YOCHRE, YOCHRE_D = rgb("#c98a2b"), rgb("#8c5a1c")    # yellow ochre
CHALK = rgb("#fef8e8")


def wall(w, h, seed=3):
    """painted sandstone: the tablet's base with lighter and darker flecks and a few cracks (deterministic)"""
    rng = np.random.RandomState(seed)
    a = np.zeros((h, w, 4), np.uint8)
    a[...] = SAND["b"] + (255,)
    r = rng.rand(h, w)
    a[r < 0.025] = SAND["l2"] + (255,)
    a[(r > 0.975)] = SAND["s"] + (255,)
    for _ in range(max(2, w * h // 2400)):                      # hairline cracks
        x, y = rng.randint(0, w), rng.randint(0, h)
        for _ in range(rng.randint(6, 16)):
            if 0 <= x < w and 0 <= y < h:
                a[y, x] = SAND["s"] + (255,)
            x += rng.choice([-1, 0, 1])
            y += 1
    return a


def silhouette(rel, frame, cell, n, flip_h=False):
    """a shipped sprite cell's silhouette reduced n:1"""
    sheet = asset(rel)
    fw, fh = cell
    cols = sheet.width // fw
    c = sheet.crop(((frame % cols) * fw, (frame // cols) * fh, (frame % cols + 1) * fw, (frame // cols + 1) * fh))
    m = crop_mask(mask_of(c))
    if flip_h:
        m = m[:, ::-1]
    return crop_mask(reduce_mask(m, n))


GLYPH_SUN = ["#....#....#",
             ".#...#...#.",
             "...#####...",
             "..##...##..",
             "###.....###",
             "..##...##..",
             "...#####...",
             ".#...#...#.",
             "#....#....#"]
GLYPH_HAND = ["..#.#.....",
              ".##.#.#...",
              ".######...",
              "#######...",
              ".######...",
              ".#####....",
              "..####....",
              "..###....."]
GLYPH_SPIRAL = [".######...",
                "#......#..",
                "#.####.#..",
                "#.#..#.#..",
                "#.#.##.#..",
                "#.#....#..",
                "#..####...",
                "#.........",
                ".#########"]
GLYPH_WAVE = ["..##....##....##....##..",
              ".#..#..#..#..#..#..#..#.",
              "#....##....##....##....#"]
GLYPH_FIRE = ["...#....",
              "..##..#.",
              ".###.##.",
              ".######.",
              "########",
              ".######.",
              "#.#..#.#",
              ".#.##.#."]
GLYPH_SQUID = ["..####..",
               ".######.",
               "########",
               "##.##.##",
               "########",
               ".######.",
               "#.#..#.#",
               "#.#..#.#",
               ".#.##.#.",
               "#..#..#."]
GLYPH_TREE = ["..######..",
              ".########.",
              "##########",
              ".########.",
              "...####...",
              "....##....",
              "....##....",
              "...####...",
              "..#.##.#..",
              ".#..##..#."]
GLYPH_IDOLS = ["###...###",
               "#.#...#.#",
               "###...###",
               ".#.....#.",
               "###...###",
               "###...###",
               "#.#...#.#"]
GLYPH_SPIRE = ["....#....",
               "...###...",
               "...###...",
               "..#####..",
               "..#####..",
               ".#######.",
               "#########"]
GLYPH_MESA = [".#######.",
              ".#######.",
              "#########",
              "#########"]
GLYPH_BOLT = ["..##", ".##.", "####", ".##.", "##..", "#..."]
GLYPH_FISH = ["....####....",            # = build_book2_objects.GLYPHS["fish"]
              "..########.#",
              ".##.#######.",
              "##########..",
              ".#########.#",
              "..######...#",
              "....##......"]


def glyph_mask(g):
    return np.array([[ch == "#" for ch in line] for line in g], bool)


def stamp(a, m, x, y, col, groove=None):
    """paint mask m at (x, y) into the mural array; groove = a darker 1 px shade under the strokes"""
    h, w = m.shape
    for yy in range(h):
        for xx in range(w):
            if m[yy, xx]:
                X, Y = x + xx, y + yy
                if 0 <= X < a.shape[1] and 0 <= Y < a.shape[0]:
                    a[Y, X] = tuple(col) + (255,)
    if groove is not None:
        for yy in range(h):
            for xx in range(w):
                if m[yy, xx] and (yy + 1 >= h or not m[yy + 1, xx]):
                    X, Y = x + xx, y + yy + 1
                    if 0 <= X < a.shape[1] and 0 <= Y < a.shape[0] and a[Y, X, :3].tolist() != list(col):
                        a[Y, X] = tuple(groove) + (255,)


def mural_figures():
    """the beasts of the story as silhouettes of their shipped sheets (reduced); the people are stick-figure
    glyphs in the style of the painting fragments (sprites/items/painting.png's hunter)"""
    return {
        "roc": silhouette("sprites/enemies/pterodactyl.png", 0, _cell_of("sprites/enemies/pterodactyl.png"), 3),
        "boar": silhouette("sprites/bosses/tusker.png", 0, _cell_of("sprites/bosses/tusker.png"), 9),
        "raft": crop_mask(reduce_mask(mask_of(asset("sprites/objects/raft.png").crop((0, 0, 128, 24))), 4)),
        "roast": crop_mask(reduce_mask(mask_of(trim(load(os.path.join(AP, "items", "8.png")))), 2)),
    }


GLYPH_HUNTER = ["....##......",            # = build_book2_objects.GLYPHS["hunter"]
                "...####.....",
                "...####...#.",
                "....##...#..",
                "..######.#..",
                ".#.####.#...",
                "#..####.....",
                "...#..#.....",
                "..##..##....",
                "..#....#....",
                ".##....##..."]
GLYPH_CLUBBER = ["........##.",
                 ".......####",
                 "..##...###.",
                 ".####.##...",
                 ".####.#....",
                 "..##.#.....",
                 ".#####.....",
                 "#.####.....",
                 "..####.....",
                 "..#..#.....",
                 ".##..##....",
                 ".#....#...."]
GLYPH_CHIEF = ["#.#.#....",
               ".###.....",
               ".###....#",
               "..#....#.",
               "#####.#..",
               "#.####...",
               "..###....",
               "..###....",
               "..#.#....",
               ".##.##...",
               ".#...#..."]
GLYPH_RIDER = ["#.#",
               ".#.",
               "###",
               ".#."]
GLYPH_SMALL = ["..#..",
               ".###.",
               "#.#.#",
               "..#..",
               ".#.#.",
               "#...#"]


def _cell_of(rel):
    """frame size of a shipped / handed-over sheet from the registries (falls back to the whole picture)"""
    import json
    for reg in (os.path.join(os.path.dirname(__file__), "registry_expansion.json"),
                os.path.join(os.path.dirname(__file__), "..", "..", "pipeline", "registry.json")):
        if os.path.exists(reg):
            with open(reg, encoding="utf-8") as f:
                data = json.load(f)
            e = data.get("assets/" + rel)
            if e and "frame" in e:
                return tuple(e["frame"])
    im = asset(rel)
    return im.size


def build_mural_image():
    """the story of Book II in three bands (read left to right, top to bottom)"""
    a = wall(MW, MH)
    F = mural_figures()
    hunter, clubber, chief = glyph_mask(GLYPH_HUNTER), glyph_mask(GLYPH_CLUBBER), glyph_mask(GLYPH_CHIEF)
    small = glyph_mask(GLYPH_SMALL)
    # -- top band: the sun over the homecoming feast; the Storm Roc carries the Great Roast off with the chieftains
    stamp(a, glyph_mask(GLYPH_SUN), 3, 3, YOCHRE, YOCHRE_D)
    roast = F["roast"]
    stamp(a, hunter, 16, 29 - hunter.shape[0], OCHRE, OCHRE_D)
    stamp(a, glyph_mask(GLYPH_FIRE), 31, 29 - 8, YOCHRE, YOCHRE_D)
    stamp(a, roast, 30, 29 - 8 - roast.shape[0] + 1, OCHRE, OCHRE_D)
    stamp(a, hunter[:, ::-1], 42, 29 - hunter.shape[0], CHAR)
    roc = F["roc"]
    rx, ry = 62, 2
    stamp(a, roc, rx, ry, CHAR)
    stamp(a, roast, rx + roc.shape[1] // 2 - roast.shape[1] // 2, ry + roc.shape[0] - 2, OCHRE, OCHRE_D)
    rider = glyph_mask(GLYPH_RIDER)
    stamp(a, rider, rx + roc.shape[1] // 2 - 5, max(0, ry - 1), OCHRE)
    stamp(a, rider, rx + roc.shape[1] // 2 + 2, max(0, ry - 1), OCHRE)
    stamp(a, glyph_mask(GLYPH_BOLT), rx + roc.shape[1] + 3, 5, CHAR)
    stamp(a, glyph_mask(GLYPH_BOLT), rx + roc.shape[1] + 9, 13, OCHRE)
    stamp(a, glyph_mask(GLYPH_HAND)[:, ::-1], MW - 13, 3, OCHRE, OCHRE_D)
    # -- middle band: the raft on the waves, then the five lands and their guardians
    raft = F["raft"]
    stamp(a, raft, 4, 50 - raft.shape[0], OCHRE, OCHRE_D)
    stamp(a, small, 8, 50 - raft.shape[0] - small.shape[0], CHAR)
    stamp(a, small[:, ::-1], 18, 50 - raft.shape[0] - small.shape[0], OCHRE)
    stamp(a, glyph_mask(GLYPH_WAVE)[:, :16], 2, 51, CHAR)
    stamp(a, glyph_mask(GLYPH_WAVE)[:, 4:20], 20, 51, CHAR)
    for k in range(10):                                      # the trail of crumbs: a wavy line of ochre dots
        x, y = 26 + k * 4, 38 + int(round(3 * np.sin(k * 0.9)))
        a[y:y + 2, x:x + 2] = OCHRE + (255,)
    bird = glyph_mask(["#...#", ".#.#.", "..#.."])          # birds fleeing the storm, rain under the cloud
    for bx, by in ((98, 22), (108, 27), (120, 19)):
        stamp(a, bird, bx, by, CHAR)
    for k in range(8):
        x, y = 127 + (k % 4) * 4 + (k // 4) * 2, 22 + (k // 4) * 5
        a[y:y + 2, x] = CHAR + (255,)
    stamp(a, glyph_mask(GLYPH_FISH), 52, 55, CHAR)           # a fish in the sea the raft crosses
    lands = [(GLYPH_MESA, F["boar"], (OCHRE, OCHRE_D)), (GLYPH_TREE, None, (CHAR, None)),
             (GLYPH_SQUID, None, (OCHRE, OCHRE_D)), (GLYPH_IDOLS, None, (OCHRE, OCHRE_D)),
             (GLYPH_SPIRE, None, (CHAR, None))]
    x = 70
    for g, guard, (col, groove) in lands:
        gm = glyph_mask(g)
        if guard is not None:
            stamp(a, guard, x, 50 - gm.shape[0] - guard.shape[0], CHAR)
            stamp(a, gm, x + (guard.shape[1] - gm.shape[1]) // 2, 50 - gm.shape[0], col, groove)
            x += max(guard.shape[1], gm.shape[1]) + 4
        else:
            stamp(a, gm, x, 50 - gm.shape[0], col, groove)
            x += gm.shape[1] + 4
    stamp(a, glyph_mask(GLYPH_BOLT), x - 6, 34, YOCHRE)
    stamp(a, glyph_mask(GLYPH_BOLT), x - 15, 31, CHAR)
    # -- bottom band: the last stand at the pyre (middle), the feast at home again (right)
    stamp(a, glyph_mask(GLYPH_SPIRAL), 4, 62, OCHRE, OCHRE_D)
    stamp(a, clubber, 28, 77 - clubber.shape[0], CHAR)
    stamp(a, glyph_mask(GLYPH_FIRE), 44, 77 - 8, YOCHRE, YOCHRE_D)
    stamp(a, chief, 56, 77 - chief.shape[0], OCHRE, OCHRE_D)
    stamp(a, chief[:, ::-1], 66, 77 - chief.shape[0], OCHRE, OCHRE_D)
    stamp(a, hunter, 90, 77 - hunter.shape[0], CHAR)
    stamp(a, roast, 104, 77 - roast.shape[0], OCHRE, OCHRE_D)
    stamp(a, hunter[:, ::-1], 118, 77 - hunter.shape[0], OCHRE, OCHRE_D)
    stamp(a, glyph_mask(GLYPH_HAND), MW - 11, MH - 9, CHALK)
    return Image.fromarray(a, "RGBA")


def piece_rect(i):
    """the mural piece of painting i (mural px): column i % 6, row i // 6"""
    return ((i % 6) * PW, (i // 6) * PH, PW, PH)


# ---------------------------------------------------------------------------------------------------- slab
SW, SH = 220, 104
MURAL_AT = (8, 12)                   # the mural area inside the slab
PLATE = (160, 8, 52, 14)             # the count plate (x, y, w, h)
ICON = 24
ICONS_AT = [(162 + (k % 2) * 26, 26 + (k // 2) * 25) for k in range(6)]


def slab_shape():
    def fn(x, y):
        corner = (np.minimum(x, SW - 1 - x) + np.minimum(y, SH - 1 - y)) < 6       # chipped corners
        return np.where(~corner, -1.0, 1.0)
    return shape_mask(SW, SH, fn)


def build_slab_image(icons_locked):
    m = slab_shape()
    a = np.zeros((SH, SW, 4), np.uint8)
    paint(a, m, SAND["o"])
    body = m & ~rim(m, 2)
    w = wall(SW, SH, 11)
    a[body] = w[body]
    ys, xs = np.mgrid[0:SH, 0:SW]
    bevel = body & rim(body, 2)
    paint(a, bevel & ((xs < 5) | (ys < 5)), SAND["l"])                    # lit top / left bevel
    paint(a, bevel & ((xs >= SW - 5) | (ys >= SH - 5)), SAND["s"])        # shaded bottom / right bevel
    # the mural area: recessed (a dark groove round it), empty sockets in the tablet's shade
    mx, my = MURAL_AT
    paint(a, (xs >= mx - 2) & (xs < mx + MW + 2) & (ys >= my - 2) & (ys < my + MH + 2), SAND["d"])
    paint(a, (xs >= mx - 1) & (xs < mx + MW + 1) & (ys >= my - 1) & (ys < my + MH + 1), SAND["o"])
    for i in range(30):
        px, py, pw, ph = piece_rect(i)
        x0, y0 = mx + px, my + py
        sock = (xs >= x0) & (xs < x0 + pw) & (ys >= y0) & (ys < y0 + ph)
        paint(a, sock, SAND["s"])
        paint(a, sock & ((xs == x0) | (ys == y0)), SAND["d"])                 # the shadowed rim of a socket
        paint(a, sock & ((xs == x0 + pw - 1) | (ys == y0 + ph - 1)), SAND["b"])
        r = np.random.RandomState(100 + i)                                     # a chisel scratch in each
        sx, sy = x0 + 4 + r.randint(0, 12), y0 + 4 + r.randint(0, 7)
        for k in range(5):
            a[sy + (k % 2), sx + k] = SAND["d"] + (255,)
    # the count plate
    px, py, pw, ph = PLATE
    plate = (xs >= px) & (xs < px + pw) & (ys >= py) & (ys < py + ph)
    paint(a, plate, SAND["o"])
    paint(a, plate & ~rim(plate, 1), SAND["d"])
    paint(a, plate & ~rim(plate, 1) & (ys == py + 1), SAND["o"])
    # the six unlock marks, carved
    for k, (ix, iy) in enumerate(ICONS_AT):
        ic = np.array(icons_locked[k])
        icm = ic[..., 3] > 0
        sub = a[iy:iy + ICON, ix:ix + ICON]
        sub[icm] = ic[icm]
    return Image.fromarray(a, "RGBA")


# ---------------------------------------------------------------------------------------------------- unlock icons
UNLOCK_ORDER = ["mesa_rodeo", "loincloths", "variants", "cloud_top", "spear_party", "mural"]
GLYPH_CLOTH = ["##########",
               "#.##.###.#",
               "##########",
               ".###.##.#.",
               ".########.",
               "..#.##.#..",
               "..#.#..#..",
               ".#..#...#."]
GLYPH_SPRING = ["#########",
                "....##...",
                "..##.....",
                "....##...",
                "..##.....",
                "....##...",
                "#########"]
GLYPH_CLOUD = ["....####....",
               "..########..",
               ".##########.",
               "############",
               ".##########.",
               "...#.##.#..."]


def unlock_masks():
    rex = silhouette("sprites/enemies/rex.png", 0, (152, 112), 6)
    spear = crop_mask(reduce_mask(mask_of(trim(asset("sprites/items/weapon_spear.png"))), 3))
    sp = np.zeros((spear.shape[0], spear.shape[0]), bool)                 # the spear leaned 45 degrees
    for y in range(spear.shape[0]):
        for x in range(spear.shape[1]):
            if spear[y, x]:
                X = spear.shape[0] - 1 - y + x - spear.shape[1] // 2
                if 0 <= X < sp.shape[1]:
                    sp[y, X] = True
    return [rex, glyph_mask(GLYPH_CLOTH), glyph_mask(GLYPH_SPRING), glyph_mask(GLYPH_CLOUD), crop_mask(sp),
            glyph_mask(GLYPH_HAND)]


def unlock_icon(k, lit):
    m = unlock_masks()[k]
    a = np.zeros((ICON, ICON, 4), np.uint8)
    disc = shape_mask(ICON, ICON, lambda x, y: ((x - 11.5) / 11.5) ** 2 + ((y - 11.5) / 11.5) ** 2 - 1)
    if lit:
        paint(a, disc, SAND["o"])
        paint(a, disc & ~rim(disc, 1), SAND["l2"])
        paint(a, disc & ~rim(disc, 1) & rim(disc & ~rim(disc, 1), 1), rgb("#f3aa39"))   # a gold ring
    else:
        paint(a, disc & rim(disc, 1), SAND["d"])
        paint(a, disc & ~rim(disc, 1), SAND["s"])
    h, w = m.shape
    x0, y0 = (ICON - w) // 2, (ICON - h) // 2
    if lit:
        col, groove = (rgb("#c97d10"), OCHRE_D) if UNLOCK_ORDER[k] == "spear_party" else (OCHRE, OCHRE_D)
        stamp(a, m, x0, y0, col, groove)
    else:
        stamp(a, m, x0, y0, SAND["d"])
    return Image.fromarray(a, "RGBA")


def build_unlock_icons():
    locked = [unlock_icon(k, False) for k in range(6)]
    lit = [unlock_icon(k, True) for k in range(6)]
    sheet = strip(locked + lit, cols=6)
    save(sheet, "ui/unlock_icons.png", kind="ui", frame=[ICON, ICON], grid=[6, 2], section="far_shore",
         columns=UNLOCK_ORDER,
         source="silhouettes of shipped sprites/enemies/rex.png and sprites/items/weapon_spear.png; glyphs drawn by "
                "the pipeline; the colours of shipped tiles/village/props/stone_tablet.png and the cave-paint ochre",
         edits="the rex and the spear reduced 6:1 / 3:1 to silhouettes (the spear leaned 45 degrees by a pixel "
               "shear), the other four drawn as 6-10 px glyphs; row 0 carved into the slab's shade (locked), row 1 "
               "painted in ochre on a light disc with a gold ring (unlocked; the spear in gold)",
         note="the six rewards of the Cave Paintings (C.9, Save.UNLOCK_*), column = reward: 0 mesa_rodeo (5 "
              "paintings), 1 loincloths (10), 2 variants (15), 3 cloud_top (20), 4 spear_party (25), 5 mural (30). "
              "Row 0 = locked (carved; the slab already shows these), row 1 = unlocked: draw cell 6 + k over the "
              "slab's mark k (painting_slab.png `icons`) once Save.is_unlocked(reward); also for the unlocks screen "
              "and the versus menu")
    return locked, lit


def build_slab_and_mural():
    locked, _ = build_unlock_icons()
    mural = build_mural_image()
    save(mural, "ui/mural.png", kind="ui", frame=[MW, MH], grid=[1, 1], section="far_shore",
         pieces={"size": [PW, PH], "grid": [6, 5], "order": "painting i = column i % 6, row i // 6"},
         source="silhouettes of shipped sprites/player/hero.png (victory 48, strike 28), sprites/enemies/"
                "pterodactyl.png, rival.png, rex.png, sprites/bosses/tusker.png (art-B), sprites/objects/raft.png; "
                "superpowers-prehistoric-platformer: items/8.png (the roast); glyphs drawn by the pipeline (as "
                "sprites/items/painting.png); the sandstone of shipped tiles/village/props/stone_tablet.png",
         edits="every figure is a shipped sprite's alpha mask reduced 2:1 to 6:1 (box filter + threshold), painted "
               "flat in ochre (#b64e13 with a 1 px #793a15 groove) or charcoal (#3f2a1c), with chalk hand prints, on "
               "a flecked and cracked sandstone ground (deterministic noise in the tablet's five colours)",
         note="the Cave Painting mural (C.9): the story of Book II painted on the slab - the homecoming feast, the "
              "Storm Roc carrying off the Great Roast with Gorm and Gulla, the raft, the five lands and their "
              "guardians, the last stand at the pyre and the feast at home. 30 pieces of 24 x 16 (`pieces`): painting "
              "i shows the rect (i % 6 * 24, i / 6 * 16, 24, 16) in the slab's socket i once found. The whole mural "
              "is the last picture of The Long Raft Home when all 30 are found (draw it at an integer scale, 2x = "
              "288 x 160 or 3x = 432 x 240, ideally inside painting_slab.png at the same scale)")
    slab = build_slab_image(locked)
    sockets = []
    for i in range(30):
        px, py, pw, ph = piece_rect(i)
        sockets.append([MURAL_AT[0] + px, MURAL_AT[1] + py])
    save(slab, "ui/painting_slab.png", kind="ui", frame=[SW, SH], grid=[1, 1], section="far_shore",
         mural_at=list(MURAL_AT), plate=list(PLATE), icons=[list(p) for p in ICONS_AT],
         source="drawn by the pipeline in the colours of shipped tiles/village/props/stone_tablet.png; the unlock "
                "marks of ui/unlock_icons.png row 0",
         edits="a 220 x 104 sandstone slab (2 px #272018 outline, chipped corners, lit top-left / shaded bottom-right "
               "bevel, flecks and cracks), a recessed 144 x 80 mural area of 30 empty sockets (shaded rims, a chisel "
               "scratch each), a dark count plate and the six carved unlock marks",
         note="the Cave Painting slab (A.1 / C.9): screen UI in the lower-right corner of the Far Shore map page "
              "(world_map.gd) and on the unlocks screen. Socket of painting i: `mural_at` + (i % 6 * 24, i / 6 * 16), 24 x 16 "
              "- draw the same rect of ui/mural.png there when Save.has_painting(i). `plate` = the count plate (x, y, "
              "w, h) for '17/30' in the small font; `icons` = the top-left of the six 24 x 24 unlock marks (reward "
              "order of ui/unlock_icons.png): draw that sheet's row-1 cell over a mark when the reward is open")
    return slab, mural



# ---------------------------------------------------------------------------------------------------- the 30 pictures
GLYPH_COMB = [".##.##.",
              "#..#..#",
              "#..#..#",
              ".##.##.",
              "#..#..#",
              "#..#..#",
              ".##.##."]
GLYPH_CHERRIES = ["....#...",
                  "...#.#..",
                  "..#...#.",
                  ".##..##.",
                  "####.###",
                  "####.###",
                  ".##...#."]
GLYPH_MUSHROOM = ["..######..",
                  ".########.",
                  "##.####.##",
                  "##########",
                  "....##....",
                  "....##....",
                  "...####..."]
GLYPH_STEPS = [".......###",
               ".......###",
               "....######",
               "....######",
               ".#########",
               "##########"]
GLYPH_MAMMOTH = ["....######....",
                 "..##########..",
                 ".############.",
                 "##############",
                 "#.###########.",
                 "#.###########.",
                 "#..##.....##..",
                 "...##.....##..",
                 "...##.....##.."]
GLYPH_VINE = ["#.#",
              ".#.",
              "#..",
              ".#.",
              "..#",
              ".#.",
              "#.#",
              ".#."]
# painting index -> (figure, suggested place); 0-19 are the Book II levels in campaign order (A.2 rows 1-20), 20-29
# the Book I co-op secrets (1-1, 1-2, 2-1, 2-2, 3-1, 3-1b, 3-2, 4-1, 4-2, Way Home) - only a suggestion of a theme
PAINTINGS = [
    ("raft", "w5_l1 Red Mesa Trail: the raft landing"), ("snake", "w5_l2 Rattlesnake Gulch"),
    ("boar", "w5_l2b Tusker's Wallow"), ("rex", "w6_l1 Bubbling Fen: Chomper"), ("mushroom", "w6_l2 Spore Hollow"),
    ("tree", "w6_l2b Heart of the Mangrove"), ("fish", "w7_l1 Shell Beach"), ("wave", "w7_l2 Sea Caves"),
    ("squid", "w7_l2b Squid Grotto"), ("steps", "w8_l1 Overgrown Steps"), ("idol", "w8_l2 Hall of Idols"),
    ("idols", "w8_l2b Idol Court"), ("vine_cloud", "w9_l1 Cloudbreak Climb"), ("bolt", "w9_l1b Thunderhead Glide"),
    ("spire", "w9_l2 The Roc's Spire"), ("roc", "w9_l2b Storm Nest"), ("chiefs", "w9_l3 Chieftains' Pyre"),
    ("comb", "bonus_d Honey Falls"), ("cherries", "bonus_e Pudding Lagoon"), ("roast", "ending_b The Long Raft Home"),
    ("hunters", "w1_l1 co-op"), ("sun", "w1_l2 co-op"), ("hand", "w2_l1 co-op"), ("spiral", "w2_l2 co-op"),
    ("ptero", "w3_l1 co-op"), ("turtle", "w3_l1b co-op"), ("dino", "w3_l2 co-op"), ("mammoth", "w4_l1 co-op"),
    ("bat", "w4_l2 co-op"), ("hut", "ending co-op: the Way Home"),
]


def painting_figure(name):
    """the 32 x 32 picture of one Cave Painting: (mask, pigment) layers"""
    sil = lambda rel, n, f=0: silhouette(rel, f, _cell_of(rel), n)
    G = glyph_mask
    if name == "raft":
        r = crop_mask(reduce_mask(mask_of(asset("sprites/objects/raft.png").crop((0, 0, 128, 24))), 5))
        s = G(GLYPH_SMALL)
        return [(r, 4, 30 - r.shape[0], OCHRE), (s, 8, 30 - r.shape[0] - 6, OCHRE), (s[:, ::-1], 18, 30 - r.shape[0]
                                                                                      - 6, OCHRE)]
    single = {
        "snake": lambda: sil("sprites/enemies/snake.png", 5), "boar": lambda: sil("sprites/bosses/tusker.png", 7),
        "rex": lambda: sil("sprites/enemies/rex.png", 5), "mushroom": lambda: G(GLYPH_MUSHROOM),
        "tree": lambda: G(GLYPH_TREE), "fish": lambda: G(GLYPH_FISH), "squid": lambda: G(GLYPH_SQUID),
        "steps": lambda: G(GLYPH_STEPS), "idol": lambda: G(GLYPH_IDOLS)[:, :3],
        "idols": lambda: G(GLYPH_IDOLS), "bolt": lambda: G(GLYPH_BOLT), "spire": lambda: G(GLYPH_SPIRE),
        "roc": lambda: sil("sprites/enemies/pterodactyl.png", 5), "comb": lambda: G(GLYPH_COMB),
        "cherries": lambda: G(GLYPH_CHERRIES), "sun": lambda: G(GLYPH_SUN), "hand": lambda: G(GLYPH_HAND),
        "spiral": lambda: G(GLYPH_SPIRAL), "ptero": lambda: sil("sprites/enemies/pterodactyl.png", 5, 8),
        "turtle": lambda: sil("sprites/enemies/turtle.png", 3), "dino": lambda: sil("sprites/enemies/mini_rex.png", 4),
        "mammoth": lambda: G(GLYPH_MAMMOTH), "bat": lambda: sil("sprites/enemies/bat.png", 3),
        "hut": lambda: crop_mask(reduce_mask(mask_of(asset("tiles/village/props/hut_dome.png")), 8)),
        "roast": lambda: crop_mask(reduce_mask(mask_of(trim(load(os.path.join(AP, "items", "8.png")))), 2)),
        "wave": lambda: G(GLYPH_WAVE)[:, :20],
    }
    if name in single:
        m = single[name]()
        if max(m.shape) <= 14:                                      # small glyphs at double size (a mask, not art)
            m = np.repeat(np.repeat(m, 2, axis=0), 2, axis=1)
        return [(m, (32 - m.shape[1]) // 2, 30 - m.shape[0], OCHRE)]
    if name == "vine_cloud":
        c, v = G(GLYPH_CLOUD), G(GLYPH_VINE)
        return [(c, 10, 2, OCHRE), (v, 15, 8, OCHRE), (v, 15, 16, OCHRE), (G(GLYPH_SMALL), 13, 24, YOCHRE)]
    if name == "chiefs":
        ch = G(GLYPH_CHIEF)
        return [(ch, 4, 30 - ch.shape[0], OCHRE), (ch[:, ::-1], 18, 30 - ch.shape[0], OCHRE),
                (G(GLYPH_FIRE), 12, 30 - 8, YOCHRE)]
    if name == "hunters":
        h = G(GLYPH_HUNTER)
        return [(h, 2, 30 - h.shape[0], OCHRE), (h[:, ::-1], 18, 30 - h.shape[0], OCHRE)]
    raise KeyError(name)


def painting_picture(name):
    a = np.zeros((32, 32, 4), np.uint8)
    for m, x, y, col in painting_figure(name):
        groove = OCHRE_D if col == OCHRE else YOCHRE_D
        stamp(a, m, max(0, x), max(0, y), col, groove)
    return Image.fromarray(a, "RGBA")


def build_paintings():
    frames = [painting_picture(n) for n, _ in PAINTINGS]
    sheet = strip(frames)
    save(sheet, "ui/paintings.png", kind="ui", frame=[32, 32], grid=[30, 1], section="far_shore",
         themes=[{"index": i, "figure": n, "suggested_for": w} for i, (n, w) in enumerate(PAINTINGS)],
         source="silhouettes of shipped sprites (enemies/snake, rex, pterodactyl, turtle, mini_rex, bat; bosses/tusker, "
                "objects/raft; tiles/village/props/hut_dome) and superpowers-prehistoric-platformer: items/8.png "
                "(the roast); glyphs drawn by the pipeline (as sprites/items/painting.png and ui/mural.png)",
         edits="every figure is a shipped sprite's alpha mask reduced 2:1 to 8:1 (box filter + threshold) or a glyph "
               "drawn by the pipeline (glyphs of 14 px or less drawn at double size), painted flat in ochre #b64e13 (yellow ochre #c98a2b for fire and the climber) with a 1 px "
               "darker groove under every stroke; transparent ground",
         note="the 30 Cave Paintings as pictures (C.9; ui-A's slab, unlocks screen and mural): cell = painting index "
              "0..29, 32 x 32, ochre on transparent - draw them on stone. `themes` gives each index the level whose "
              "story it suits (0-19 the Book II levels in campaign order, 20-29 the Book I co-op secrets); the "
              "designers' index choice wins. ui/mural.png is the alternative where the 30 pieces assemble one picture")
    return sheet


def build():
    return {"map": build_map(), "slab_mural": build_slab_and_mural(), "paintings": build_paintings()}


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()

"""Phase 3 art of art-A's areas (PLAN 6: what the Book II content still needs; DESIGN A.6):

    tiles/feast/syrup_floor.png       the ':' floor of Feast Land E (Pudding Lagoon, `liquid = syrup`, biome feast):
                                      CUSTARD - "custard floors (':', the tar rules in pudding skin)". World-A's
                                      WorldTileSet.tar_floor_image looks for tiles/<biome>/<liquid>_floor.png first, so
                                      a feast-biome syrup level draws this instead of tiles/common/syrup_floor.png (the
                                      berry syrup), and a wading floor no longer looks like the deadly syrup `~`.
    sprites/objects/raft_rails.png    the fence of a railed raft (`objects/raft rails`, The Long Raft Home: nobody
                                      leaves it, P-C.7) and its open states at the home beach (G45: a raft stopped by a
                                      bank opens its fence towards it) - an overlay on raft.png.

Sources (all CC0): shipped 1.0 tiles/feast/terrain.png (via build_liquids.floor_strip, the recipe of every ':' skin);
the raft's own colours (sprites/objects/raft.png, art-A phase 1); posts and ropes drawn by the pipeline in the anchor
palette. Exact colour swaps / pixel drawing only.
"""
import numpy as np
from PIL import Image

from xcommon import OUTLINE, rgb, save, strip
import build_liquids

# --------------------------------------------------------------------------------------------------- custard floor
# A deep baked custard with a caramel rim: darker and more orange than the pudding terrain's pale custard body
# (feast/terrain_pudding #ffd77a / #ffe08e) so the slow floor never reads as solid pudding, and nothing like the
# deadly berry syrup (#9e2f5c) beside it.
CUSTARD = dict(outline="#7b391b", body="#d98a2e", mid="#e9a640", light="#f7c55e", shine="#fff0c0",
               look="baked custard under a caramel rim (Feast Land E: Pudding Lagoon's custard floors)")


def build_custard_floor():
    build_liquids.ALL_FLOORS["custard"] = CUSTARD
    try:
        im = build_liquids.floor_strip("custard")
    finally:
        del build_liquids.ALL_FLOORS["custard"]
    s = CUSTARD
    save(im, "tiles/feast/syrup_floor.png", section="feast", kind="tiles", frame=[32, 32], grid=[4, 1],
         surface_drawn_row=build_liquids.SURFACE_DRAWN_ROW, surface_collision_row=build_liquids.SURFACE_COLLISION_ROW,
         tiles_inline={"0": "top_left", "1": "top (repeatable)", "2": "top_right",
                       "3": "fill below the surface row (bubbles)"},
         palette=[s["outline"], s["body"], s["mid"], s["light"], s["shine"]],
         source="shipped tiles/feast/terrain.png tiles 0, 1, 2, 9 (superpowers-prehistoric-platformer: "
                "background-elements/tileset-1.png, yellow sand set) - the recipe of every ':' skin (build_liquids.py)",
         edits="surface tiles moved down 6 art px (as tiles/canyon/mud_floor.png); exact 4-colour swap of the sand "
               "bands into a custard ramp (caramel outline %s, body %s, mid %s, light %s); glossy dashes (%s) under "
               "the surface line; bubble rings in the fill tile" % (s["outline"], s["body"], s["mid"], s["light"],
                                                                     s["shine"]),
         note="the ':' floor of a FEAST-biome level with `liquid = syrup` (Feast Land E: Pudding Lagoon - DESIGN A.6 "
              "'custard floors, the tar rules in pudding skin'): WorldTileSet.tar_floor_image takes "
              "tiles/<biome>/<liquid>_floor.png before tiles/common/<liquid>_floor.png, so it replaces the berry-syrup "
              "floor there (and in the Sky Picnic arena, feast + syrup); same layout and surface rows as every ':' "
              "skin (17.10): 0 top_left, 1 top, 2 top_right, 3 fill; drawn surface art row 6, collision row 12")
    return im


# --------------------------------------------------------------------------------------------------- raft rails
RAFT_OUT, RAFT_WOOD, RAFT_DARK, RAFT_LIGHT = rgb("#332213"), rgb("#7f3910"), rgb("#582d12"), rgb("#9d4829")
ROPE, ROPE_SHADE = rgb("#f1b043"), rgb("#d68428")
RAILS_CELL = (128, 32)
RAILS_DECK_ROW = 26           # the raft's ride surface (raft.png pivot row 0) lies on this row of a rails cell
# post x (left edge, 4 px wide) per raft width; the first and last are the end (gate) posts
POSTS = {3: [20, 62, 104], 4: [4, 42, 82, 120]}
TOP_ROPE, LOW_ROPE = 7, 16    # rope rows at the posts (they sag 1-2 px between posts)
STATES = ["closed", "open_left", "open_right"]


def _post(a, x, top=4):
    for y in range(top, RAILS_DECK_ROW + 3):
        a[y, x] = RAFT_OUT + (255,)
        a[y, x + 1] = RAFT_LIGHT + (255,)
        a[y, x + 2] = RAFT_WOOD + (255,)
        a[y, x + 3] = RAFT_OUT + (255,)
    a[top - 1, x:x + 4] = RAFT_OUT + (255,)
    a[top, x + 1:x + 3] = ROPE + (255,)                  # a lashing cap on each post
    a[RAILS_DECK_ROW, x + 1:x + 3] = RAFT_DARK + (255,)


def _rope(a, x0, x1, row, sag=2):
    """a 2 px rope with a 1 px outline above and below from x0 to x1, sagging `sag` px in the middle"""
    n = max(1, x1 - x0)
    for x in range(x0, x1 + 1):
        t = (x - x0) / n
        y = row + int(round(sag * 4 * t * (1 - t)))
        if a[y, x, 3] and tuple(a[y, x, :3]) != RAFT_OUT:
            continue
        a[y - 1, x] = RAFT_OUT + (255,)
        a[y, x] = ROPE + (255,)
        a[y + 1, x] = ROPE_SHADE + (255,)
        a[y + 2, x] = RAFT_OUT + (255,)


def _hanging(a, x, row, side):
    """a loose rope end hanging down from a post towards the deck (the opened gate)"""
    for k, y in enumerate(range(row, RAILS_DECK_ROW - 1)):
        xx = x + side * min(k // 3, 3)
        a[y, xx - 1] = RAFT_OUT + (255,)
        a[y, xx] = ROPE + (255,)
        a[y, xx + 1] = RAFT_OUT + (255,)
    a[RAILS_DECK_ROW - 1, x + side * 3 - 1:x + side * 3 + 2] = RAFT_OUT + (255,)


def rails_cell(width, state):
    w, h = RAILS_CELL
    a = np.zeros((h, w, 4), np.uint8)
    posts = list(POSTS[width])
    open_left, open_right = state == "open_left", state == "open_right"
    shown = posts[1:] if open_left else (posts[:-1] if open_right else posts)
    for row in (TOP_ROPE, LOW_ROPE):
        for p, q in zip(shown, shown[1:]):
            _rope(a, p + 3, q, row + 1)
    for p in shown:
        _post(a, p)
    if open_left:                                        # the left gate rope hangs from the first post left
        _hanging(a, shown[0] - 1, TOP_ROPE + 2, -1)
        _hanging(a, shown[0] - 1, LOW_ROPE + 2, -1)
    if open_right:
        _hanging(a, shown[-1] + 4, TOP_ROPE + 2, 1)
        _hanging(a, shown[-1] + 4, LOW_ROPE + 2, 1)
    return Image.fromarray(a, "RGBA")


def build_raft_rails():
    cells = [rails_cell(width, st) for width in (3, 4) for st in STATES]
    sheet = strip(cells, cols=3)
    save(sheet, "sprites/objects/raft_rails.png", kind="object", frame=list(RAILS_CELL), grid=[3, 2],
         pivot=[64, RAILS_DECK_ROW], section="objects", rows=["width 3", "width 4"], columns=STATES,
         source="drawn by the pipeline in the colours of sprites/objects/raft.png (log outline #332213, wood #7f3910 / "
                "#9d4829 / #582d12, rope binding #f1b043 / #d68428)",
         edits="4 px log posts (outline, lit left side, a rope lashing cap) standing on the deck line, two 2 px ropes "
               "(outlined, sagging 1-2 px between posts) at 7 and 16 px over the deck; an open state drops the gate "
               "post on that side and lets both ropes hang from the last post",
         note="the fence of a railed raft (`objects/raft rails`, The Long Raft Home: riders are fenced to the raft, "
              "PHYSICS C.7) drawn OVER raft.png and BEHIND the riders: 128 x 32 cells, row = raft width (0: width 3, "
              "1: width 4), column = state (0 closed; 1 open towards the left bank, 2 open towards the right bank - the "
              "fence opens over a bank that stopped the raft, G45). Pivot (64, 26) = the raft's pivot (raft.png (64, "
              "0), the deck's top centre): draw a cell with its pivot on the raft's pivot; the rider dip (RAFT_DIP_PX) "
              "moves it with the deck")
    return sheet


def build():
    build_custard_floor()
    build_raft_rails()


if __name__ == "__main__":
    from xcommon import load_registry, save_registry
    load_registry()
    build()
    save_registry()

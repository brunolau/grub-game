"""Hero, enemies, bosses and NPC sheets.

Source: Superpowers "Prehistoric Platformer" pack by Pixel-boy / Sparklin Labs (CC0).
Edits made here (all documented in docs/ASSET_MANIFEST.md):
  * every sheet re-packed on a uniform grid, facing RIGHT, pivot = (cell_w/2, cell_h-16)
  * hero: the pack's own club / hammer / axe / boomerang item sprites are composited behind the
    body (carried on the shoulder, swung in the attack frames, slash arc from fx/effects/1.png)
  * hero: crouch-, air- and overhead-attack plus victory poses are built from existing frames
  * bosses: integer 2x upscale; the Wall Colossus is a gradient-mapped, cropped T-rex
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *  # noqa

OUT_DARK = (39, 32, 24)       # #272018 outline colour of the pack


# ----------------------------------------------------------------------------- weapons
def clean_weapon(im):
    return im


def weapon_sprite(im, deg, grip):
    """Rotate a weapon about its grip.  The 2 px outline is rebuilt after rotating so it stays solid."""
    a = np.array(im)
    dark = (a[..., 0] == OUT_DARK[0]) & (a[..., 1] == OUT_DARK[1]) & (a[..., 2] == OUT_DARK[2])
    core = a.copy(); core[dark] = 0
    core = Image.fromarray(core, "RGBA")
    rot, piv = rotate_px(core, deg, grip)
    if deg % 90 == 0:
        rot, piv = rotate_px(im, deg, grip)
        return rot, piv
    out = outline(rot, OUT_DARK + (255,), 2)
    return out, (piv[0] + 2, piv[1] + 2)


WEAPONS = {
    # name: (item file, grip point in the unrotated sprite (head up), thrown?)
    "club": ("items/1.png", (9, 31), False),
    "hammer": ("items/13.png", (9, 27), False),
    "axe": ("items/14.png", (8, 27), True),
    "boomerang": ("items/20.png", (9, 22), True),
}


def hero_frames(weapon):
    src = grid_cells(sp("characters/playable/caverman.png"), 6, 7)
    wim = sp(WEAPONS[weapon][0]); grip = WEAPONS[weapon][1]; thrown = WEAPONS[weapon][2]
    fx = grid_cells(sp("fx/effects/1.png"), 4, 1)
    PIV = (44, 65)

    def held(frame, xy, deg):
        rot, piv = weapon_sprite(wim, deg, grip)
        return under(frame, rot, (xy[0] - piv[0], xy[1] - piv[1]))

    def big(cell):
        out = canvas(200, 120)
        return over(out, cell, (60, 30))

    def B(p):            # source cell coords -> working canvas coords
        return (p[0] + 60, p[1] + 30)

    def carry(i):
        b = bbox(src[i]); dx, dy = b[0] - 21, b[1] - 8
        return held(big(src[i]), B((34 + dx, 40 + dy)), -50)

    def bare(i):
        return big(src[i])

    def swing(i, xy, deg, sw=None, sw_off=(14, -36), sw_rot=0, release=False):
        f = big(src[i])
        if thrown and release:
            return f
        f = held(f, B(xy), deg)
        if sw is not None and not thrown:
            s = fx[sw]
            if sw_rot:
                s, _ = rotate_px(s, sw_rot)
                f = under(f, s, B((xy[0] + sw_off[0], xy[1] + sw_off[1])))
            else:
                f = under(f, s, B((xy[0] + sw_off[0], xy[1] + sw_off[1])))
        return f

    frames = []; anims = {}

    def add(name, fl, fps, loop=True):
        anims[name] = anim(range(len(frames), len(frames) + len(fl)), fps, loop)
        frames.extend(fl)

    add("idle", [carry(i) for i in range(0, 6)], 8)
    add("walk", [carry(i) for i in range(6, 14)], 12)
    add("jump", [carry(i) for i in (14, 15, 16)], 10, False)
    add("fall", [carry(i) for i in (17, 18, 19)], 10)
    add("land", [carry(20)], 1, False)
    add("crouch", [carry(24)], 1, False)
    add("crawl", [carry(24), carry(20)], 6)
    add("roll", [bare(i) for i in (21, 22, 23)], 14)
    add("attack", [swing(25, (20, 30), -40), swing(26, (80, 27), 25),
                   swing(27, (87, 45), 95, 1, (11, -36), release=True), swing(28, (87, 44), 118, 2, (10, -30), release=True)], 16, False)
    add("attack_up", [swing(25, (20, 30), -40), swing(26, (80, 27), 2, 1, (-52, -78), -90, release=True)], 12, False)
    add("attack_crouch", [swing(24, (24, 40), -45), swing(24, (66, 52), 100, 2, (12, -40), release=True)], 12, False)
    add("attack_air", [swing(14, (22, 42), -40), swing(12, (70, 41), 100, 1, (14, -36), release=True)], 12, False)
    add("hurt", [bare(29), bare(30)], 8)
    add("death", [bare(i) for i in (31, 32, 33, 34, 35)], 8, False)
    add("climb", [bare(i) for i in (36, 37, 38, 39)], 6)
    v0 = held(big(src[25]), B((20, 30)), -12)
    v1 = canvas(200, 120); v1 = over(v1, v0, (0, -4))
    add("victory", [v0, v1], 4)
    add("glide", [bare(17), bare(18)], 4)
    pivots = [B(PIV)] * len(frames)
    return frames, pivots, anims


def build_hero():
    info = {}
    for weapon in WEAPONS:
        frames, pivots, anims = hero_frames(weapon)
        sheet, (cw, ch, cols, rows) = pack(frames, pivots, cols=8, cell=(176, 112))
        name = "sprites/player/hero.png" if weapon == "club" else "sprites/player/hero_%s.png" % weapon
        save(sheet, name, kind="actor", frame=[cw, ch], grid=[cols, rows], anims=anims, facing="right",
             pivot=[cw // 2, ch - FOOT], body_box_art=[44, 56], body_box_logical=[22, 28],
             source="superpowers-prehistoric-platformer: characters/playable/caverman.png + %s + fx/effects/1.png" % WEAPONS[weapon][0],
             edits="re-packed 97x71 cells into 176x112; %s composited behind the body in idle/walk/jump/fall/crouch "
                   "(carried on the shoulder) and in the attack frames; attack_up / attack_crouch / attack_air / victory "
                   "assembled from existing poses; slash arc added%s" % (weapon, " (thrown weapon: release frames are bare-handed)" if WEAPONS[weapon][2] else ""),
             note="weapon variant: %s" % weapon)
        info[weapon] = (cw, ch, cols, rows)
    # weapon pick-ups and projectiles
    for weapon, (f, grip, thrown) in WEAPONS.items():
        im = sp(f)
        icon = pad_to(im, 32, 40, 0.5, 1.0) if im.height <= 40 else im
        save(icon, "sprites/items/weapon_%s.png" % weapon, kind="item", frame=list(icon.size), grid=[1, 1],
             pivot=[icon.width // 2, icon.height], source="superpowers-prehistoric-platformer: " + f,
             edits="padded to %dx%d" % icon.size, note="weapon pick-up: %s" % weapon)
        if thrown:
            t = trim(im); s = max(t.size) + (max(t.size) % 2)
            base = pad_to(t, s, s, 0.5, 0.5)
            spin = [base.rotate(-90 * k, Image.NEAREST) for k in range(4)]
            save(strip(spin), "sprites/fx/projectile_%s.png" % weapon, kind="fx", frame=[s, s], grid=[4, 1],
                 anims={"spin": anim(range(4), 16)}, pivot=[s // 2, s // 2],
                 source="superpowers-prehistoric-platformer: " + f, edits="4 lossless 90 degree rotations",
                 note="thrown %s projectile" % weapon)
    return info


# ----------------------------------------------------------------------------- generic actors
def build_actor(rel_out, src_rel, cols, rows, pivot, anims_spec, flip_src=False, variants=None, scale_n=1,
                note="", extra_edits="", transform=None, below=FOOT, cell_cols=8, kind="actor", facing="right"):
    """anims_spec: list of (name, [src frame indices], fps, loop)."""
    outs = []
    variants = variants or [("", src_rel)]
    for suffix, rel in variants:
        cells = grid_cells(sp(rel), cols, rows)
        cw0 = cells[0].width
        if flip_src:
            cells = [flip(c) for c in cells]
        piv = (cw0 - 1 - pivot[0], pivot[1]) if flip_src else pivot
        frames = []; anims = {}
        for name, idxs, fps, loop in anims_spec:
            anims[name] = anim(range(len(frames), len(frames) + len(idxs)), fps, loop)
            for i in idxs:
                if isinstance(i, tuple):          # ("vflip", n): upside-down copy re-anchored on the baseline
                    t = vflip(trim(cells[i[1]]))
                    f = canvas(cells[0].width, cells[0].height)
                    f = over(f, t, (int(piv[0]) - t.width // 2, int(piv[1]) - t.height))
                else:
                    f = cells[i]
                if transform:
                    f = transform(f, name, i)
                frames.append(f)
        pivs = [piv] * len(frames)
        if scale_n > 1:
            frames = [scale(f, scale_n) for f in frames]
            pivs = [(piv[0] * scale_n, piv[1] * scale_n)] * len(frames)
        sheet, (cw, ch, c, r) = pack(frames, pivs, cols=min(cell_cols, len(frames)), below=below * scale_n)
        # body box from the first idle frame
        b = bbox(frames[0]); bw, bh = b[2] - b[0], b[3] - b[1]
        out = rel_out.replace(".png", suffix + ".png")
        edits = "re-packed on a uniform %dx%d grid" % (cw, ch)
        if flip_src:
            edits += "; mirrored to face right"
        if scale_n > 1:
            edits += "; integer %dx nearest-neighbour upscale" % scale_n
        if extra_edits:
            edits += "; " + extra_edits
        save(sheet, out, kind=kind, frame=[cw, ch], grid=[c, r], anims=anims, facing=facing,
             pivot=[cw // 2, ch - below * scale_n], body_box_art=[bw, bh],
             body_box_logical=[int(round(bw / ART_SCALE)), int(round(bh / ART_SCALE))],
             source="superpowers-prehistoric-platformer: " + rel, edits=edits, note=note)
        outs.append(out)
    return outs


HUMAN = [  # layout shared by lion / egg-shell / girl sheets (6 x 7 cells, 37 used)
    ("idle", [0, 1, 2, 3, 4, 5], 8, True),
    ("walk", [6, 7, 8, 9, 10, 11, 12, 13], 12, True),
    ("jump", [14, 15, 16], 10, False),
    ("land", [17], 1, False),
    ("roll", [18, 19, 20], 14, True),
    ("crouch", [21], 1, False),
    ("attack", [22, 23, 24, 25], 12, False),
    ("hurt", [26, 27], 8, True),
    ("death", [28, 29, 30, 31, 32], 8, False),
    ("climb", [33, 34, 35, 36], 6, True),
]
HERO_LAYOUT = [  # caverman-2 sheet (6 x 7 cells, 40 used)
    ("idle", [0, 1, 2, 3, 4, 5], 8, True),
    ("walk", [6, 7, 8, 9, 10, 11, 12, 13], 12, True),
    ("jump", [14, 15, 16], 10, False),
    ("fall", [17, 18, 19], 10, True),
    ("land", [20], 1, False),
    ("roll", [21, 22, 23], 14, True),
    ("crouch", [24], 1, False),
    ("attack", [25, 26, 27, 28], 12, False),
    ("hurt", [29, 30], 8, True),
    ("death", [31, 32, 33, 34, 35], 8, False),
]


def build_enemies():
    E = "sprites/enemies/"
    build_actor(E + "turtle.png", "monsters/turtle-1.png", 6, 4, (31, 38), [
        ("idle", [0, 1, 2, 3], 6, True), ("walk", [5, 6, 7, 8, 9, 10], 8, True),
        ("hit", [11, 12, 13, 14, 15, 16], 12, False), ("dead", [17, 18, 19, 20, 21], 8, False)],
        flip_src=True, variants=[("", "monsters/turtle-1.png"), ("_b", "monsters/turtle-2.png")],
        note="Walker (ground patroller, archetype 9)")
    build_actor(E + "mini_rex.png", "monsters/mini-tyrannosaurus-1.png", 6, 4, (30, 62), [
        ("idle", [0, 1, 2, 3, 4, 5], 8, True), ("walk", [6, 7, 8, 9, 10], 10, True),
        ("attack", [11, 12, 13], 10, False), ("hit", [14, 15], 8, False),
        ("dizzy", [16, 17, 18, 19], 8, True), ("dead", [20, 21], 4, False)],
        variants=[("", "monsters/mini-tyrannosaurus-1.png"), ("_b", "monsters/mini-tyrannosaurus-2.png")],
        note="Hopper (archetype 8); jump = sheet frame 7 held, land = idle")
    build_actor(E + "lizard.png", "monsters/lizard-1.png", 6, 4, (38, 51), [
        ("idle", [0, 1, 2, 3, 4, 5], 8, True), ("hop", [6, 7, 8, 9, 10, 11], 10, True),
        ("attack", [12, 13, 14, 13], 10, False), ("hit", [15, 16], 8, False),
        ("dizzy", [17, 18, 19, 20], 8, True), ("dead", [21], 1, False)],
        variants=[("", "monsters/lizard-1.png"), ("_b", "monsters/lizard-2.png")],
        note="Digger (burrower, archetype 10): reveal bottom-up with a clip rect; also a second Hopper skin")
    build_actor(E + "dragon.png", "monsters/dragon-1.png", 4, 4, (40, 62), [
        ("idle", [0, 1, 2], 8, True), ("glide", [3, 4], 8, True), ("attack", [5, 6, 7, 8], 10, False),
        ("hit", [9, 10, 11], 8, False), ("fall", [12, 13, 14], 10, True), ("dead", [15], 1, False)],
        variants=[("", "monsters/dragon-1.png"), ("_b", "monsters/dragon-2.png")],
        note="Leaper (arc leaper, archetype 11): leap = sheet frames 7-8 (stretched lunge of attack), glide = glide")
    build_actor(E + "insect.png", "monsters/insect-1.png", 5, 2, (41, 69), [
        ("idle", [0, 5], 2, True), ("walk", [0, 1, 2], 10, True), ("fly", [3, 4], 12, True),
        ("dead", [6, 7, 8, 9], 8, False), ("hang", [("vflip", 0)], 1, False)],
        variants=[("", "monsters/insect-1.png"), ("_b", "monsters/insect-2.png")],
        extra_edits="hang frame = idle frame flipped vertically",
        note="Lurker (ceiling dropper -> chaser, archetype 3): hang, then walk; Stinger (sentry diver, archetype 5) with fly")
    build_actor(E + "bat.png", "monsters/bat-1.png", 7, 2, (25, 50), [
        ("fly", [0, 1, 2, 3], 10, True), ("screech", [5], 1, False), ("swoop", [6, 7], 8, True),
        ("angry", [8, 9], 8, True), ("fall", [10, 11, 12], 8, True), ("dead", [13], 1, False),
        ("hang", [("vflip", 2)], 1, False)], extra_edits="hang frame = squat frame flipped vertically",
        variants=[("", "monsters/bat-1.png"), ("_b", "monsters/bat-2.png")], facing="front",
        note="Dangler (yo-yo, archetype 2) and Swinger (pendulum, archetype 4) with hang (thread attaches at the top centre of the sprite); air Patroller with fly")
    build_actor(E + "pterodactyl.png", "monsters/pterodactyl-1.png", 4, 4, (70, 98), [
        ("fly", [0, 1, 2, 3], 8, True), ("perch", [4], 1, False), ("rise", [5, 6], 8, True),
        ("dive", [7, 8], 10, True), ("screech", [9, 10], 8, True), ("hit", [11, 12, 13, 14], 10, False),
        ("dead", [15], 1, False)],
        variants=[("", "monsters/pterodactyl-1.png"), ("_b", "monsters/pterodactyl-2.png")],
        note="Harrier (clever flyer, archetype 6) with fly; Dart (kamikaze diver, archetype 7) with dive")
    build_actor(E + "plant.png", "monsters/plant-1.png", 6, 4, (50, 85), [
        ("idle", [0, 1, 2, 3, 4, 5], 8, True), ("windup", [6, 7, 8], 10, False), ("bite", [9, 10, 11], 10, False),
        ("hit", [12, 13, 14], 8, False), ("recover", [15, 16, 17, 18, 19, 20], 10, False),
        ("dead", [21, 22, 23], 6, False)],
        variants=[("", "monsters/plant-1.png"), ("_b", "monsters/plant-2.png")],
        note="stationary snapper hazard (the original's 'red snake' role); bite reaches 84 art px forward")
    build_actor(E + "egg_kid.png", "characters/playable/egg-shell.png", 6, 7, (48, 65), HUMAN,
                variants=[("", "characters/playable/egg-shell.png"), ("_b", "characters/playable/egg-shell-2.png")],
                note="Dropper (sky dropper, archetype 0): falls with roll (egg), lands with land, then walk")
    build_actor(E + "rival.png", "characters/playable/caverman-2.png", 6, 7, (44, 65), HERO_LAYOUT,
                note="Charger (edge rusher, archetype 12): rival caveman, walk at 16-20 fps for the rush")
    build_actor(E + "rex.png", "monsters/tyrannosaurus-1.png", 6, 4, (77, 100), [
        ("idle", [0, 1, 2, 3, 4, 5], 8, True), ("walk", [6, 7, 8, 9, 10, 11, 12, 13], 12, True),
        ("attack", [14, 15, 16, 17, 18], 10, False), ("hit", [19, 20], 8, False), ("dead", [21, 22, 23], 6, False)],
        flip_src=True, variants=[("", "monsters/tyrannosaurus-1.png"), ("_b", "monsters/tyrannosaurus-2.png")],
        note="heavy Charger (archetype 12) / mid-boss; 1x size")


# ----------------------------------------------------------------------------- bosses
def build_bosses():
    Bd = "sprites/bosses/"
    # --- the Brute: lion-pelt chieftain at 2x
    brute = HUMAN[:9] + [("taunt", [22, 0, 22, 0], 6, True), ("pound", [21, 17, 21, 17], 8, True)]
    build_actor(Bd + "brute.png", "characters/playable/lion.png", 6, 7, (48, 72), brute, scale_n=2,
                variants=[("", "characters/playable/lion.png")], kind="boss", cell_cols=8,
                note="BOSS 1 'the Brute' (gorilla archetype, GAMEPLAY 6.1). Head = top 30 logical px of the body box (weak point); "
                     "taunt = chest beating, roll = leap, pound = ground pound, attack = punch",
                extra_edits="taunt and pound loops assembled from existing frames")
    build_actor(Bd + "brute_enraged.png", "characters/playable/lion-2.png", 6, 7, (48, 72), brute, scale_n=2,
                variants=[("", "characters/playable/lion-2.png")], kind="boss", cell_cols=8,
                note="palette variant of the Brute for the tougher second encounter / low-health phase",
                extra_edits="taunt and pound loops assembled from existing frames")

    # --- the Wall Colossus: petrified T-rex fused into the right-hand wall, faces LEFT
    cells = grid_cells(sp("monsters/tyrannosaurus-2.png"), 6, 4)
    STONE = [(39, 32, 24), (58, 47, 66), (92, 77, 102), (128, 112, 138), (170, 158, 176), (216, 210, 220)]
    RAGE = [(39, 32, 24), (92, 30, 28), (150, 46, 30), (204, 82, 34), (242, 150, 50), (255, 226, 130)]
    DEAD = [(39, 32, 24), (48, 42, 50), (70, 64, 74), (92, 86, 96), (118, 112, 120), (150, 146, 152)]
    CUT = 104                              # cell x where the body disappears into the wall
    rim_src = load(os.path.join(ASSETS, "tiles", "volcano", "terrain_obsidian.png")).crop((0, 32, 32, 64))   # tile 8 = left wall edge

    def stone(frame, ramp):
        f = remap(frame, ramp_fn(ramp, 20, 245))
        a = np.array(f); src = np.array(frame)
        dark = (src[..., 0] == 39) & (src[..., 1] == 32) & (src[..., 2] == 24)
        a[dark, :3] = OUT_DARK
        a[:, CUT:, 3] = 0
        return Image.fromarray(a, "RGBA")

    spec = [("idle", [0, 1, 2, 3, 4, 5], 6, True, STONE), ("spit", [14, 15, 15, 14], 8, False, STONE),
            ("slam", [17, 18], 6, False, STONE), ("hurt", [19, 20], 8, True, STONE),
            ("rage", [14, 15], 8, True, RAGE), ("broken", [23], 1, False, DEAD)]
    frames = []; anims = {}
    for name, idxs, fps, loop, ramp in spec:
        anims[name] = anim(range(len(frames), len(frames) + len(idxs)), fps, loop)
        for i in idxs:
            src = cells[i]
            f = stone(src, ramp)
            cell = canvas(130, 112)
            cell = over(cell, f, (0, 4))
            for k in range(-1, 4):
                cell = over(cell, rim_src, (CUT - 6, k * 32 + 4 - 8))
            frames.append(scale(cell, 2))
    sheet = strip(frames, cols=6)
    save(sheet, Bd + "colossus.png", kind="boss", frame=[260, 224], grid=[6, (len(frames) + 5) // 6], anims=anims,
         facing="left", pivot=[260, 208],
         body_box_art=[208, 190], body_box_logical=[104, 95],
         source="superpowers-prehistoric-platformer: monsters/tyrannosaurus-2.png + assets/tiles/volcano/terrain_obsidian.png (tile 8)",
         edits="luminance gradient-mapped to stone / lava-glow / dead ramps (outline kept), body cropped at the wall line, "
               "wall rim column added from the obsidian left-edge tile, integer 2x upscale; NOT mirrored: it faces left",
         note="BOSS 2 'the Wall Colossus' (minotaur archetype, GAMEPLAY 6.3). Pivot = bottom-RIGHT corner of the cell "
              "(put it on the arena's right wall, floor level). Head rectangles per pose are listed below the table")


def build_npc():
    build_actor("sprites/npc/companion.png", "characters/playable/girl.png", 6, 7, (46, 68), HUMAN, kind="npc",
                note="tally / game-over companion (GAMEPLAY 3.7): idle = waiting, hurt = crying on game over, attack = catching items")
    # village folk for the ending stage (idle loops only)
    for name, cols, rows, n, fps in (("elder", 5, 1, 5, 5), ("warrior", 6, 1, 6, 5), ("kid", 6, 1, 6, 5)):
        src = {"elder": "characters/npc/old-man.png", "warrior": "characters/npc/warrior.png", "kid": "characters/npc/boy-1.png"}[name]
        im = sp(src); cells = grid_cells(im, cols, rows)[:n]
        b = bbox(cells[0]); px = (b[0] + b[2]) // 2; py = max(bbox(c)[3] for c in cells)
        sheet, (cw, ch, c, r) = pack(cells, [(px, py)] * n, cols=n)
        save(sheet, "sprites/npc/%s.png" % name, kind="npc", frame=[cw, ch], grid=[c, r], anims={"idle": anim(range(n), fps)},
             facing="right" if name != "elder" else "front", pivot=[cw // 2, ch - FOOT],
             source="superpowers-prehistoric-platformer: " + src, edits="re-packed on a uniform grid",
             note="villager for the ending stage / title screen")


if __name__ == "__main__":
    load_registry()
    build_hero()
    build_enemies()
    build_bosses()
    build_npc()
    save_registry()
    print("sprites done:", len([k for k in REGISTRY if "/sprites/" in k]))

"""Biome backdrops (640 x 360, the game's art viewport) for the readability previews - never shipped.

1.0 biomes: the shipped parallax layers + the shipped terrain atlas. 2.0 biomes: the shipped art-B kit when it exists
(assets/backgrounds/<biome>/, assets/tiles/<biome>/terrain.png), otherwise the scout's style-test recipe
(.tools/asset_candidates/expansion/_style_tests/biome_tests.py: gradient-mapped shipped terrain + staged CC0 parallax).
"""
import glob
import importlib.util
import os

from PIL import Image

from xcommon import ASSETS, EXP, load

W, H = 640, 360
GROUND_Y = H - 96          # feet line of the previews (3 terrain rows below)

OLD = {
    "jungle": ("jungle", ["layer0_sky", "layer1_far_hills", "layer2_hills", "layer3_forest"], "jungle/terrain_grass.png"),
    "cave": ("cave", ["layer0_wall", "layer1_rocks_far", "layer2_ceiling_near"], "cave/terrain.png"),
    "ice": ("ice", ["layer0_sky", "layer1_far_peaks", "layer2_ridges", "layer3_snow_forest"], "ice/terrain.png"),
    "volcano": ("volcano", ["layer0_sky", "layer1_far_cones", "layer2_basalt", "layer3_burnt_forest"], "volcano/terrain.png"),
    "feast": ("feast", ["layer0_sky", "layer1_clouds", "layer2_scoops", "layer3_meadow"], "feast/terrain.png"),
}
# 2.0 biome -> style-test name
NEW = {"canyon": "canyon", "swamp": "swamp", "coast": "coral", "ruins": "temple", "sky": "sky", "mushroom": "mushroom"}

_bt = None


def _biome_tests():
    global _bt
    if _bt is None:
        path = os.path.join(EXP, "_style_tests", "biome_tests.py")
        spec = importlib.util.spec_from_file_location("biome_tests", path)
        _bt = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_bt)
    return _bt


def _tile(atlas, idx):
    return atlas.crop(((idx % 8) * 32, (idx // 8) * 32, (idx % 8) * 32 + 32, (idx // 8) * 32 + 32))


def _ground(out, atlas):
    gy = GROUND_Y
    for x in range(0, W, 32):
        out.alpha_composite(_tile(atlas, 1), (x, gy))
        out.alpha_composite(_tile(atlas, 9 if (x // 32) % 3 else 23), (x, gy + 32))
        out.alpha_composite(_tile(atlas, 9), (x, gy + 64))
    for i, t in enumerate([0, 1, 1, 2]):
        out.alpha_composite(_tile(atlas, t), (448 + i * 32, gy - 64))
        out.alpha_composite(_tile(atlas, [8, 9, 9, 10][i]), (448 + i * 32, gy - 32))
    return out


def backdrop(name, x0=0, ground=True):
    """640 x 360 parallax of a biome; ground=False leaves out the terrain (scenes that cut holes into the ground
    composite their own tiles over the bare backdrop)"""
    out = Image.new("RGBA", (W, H), (120, 170, 220, 255))
    if name in OLD:
        folder, layers, terr = OLD[name]
        for i, l in enumerate(layers):
            im = load(os.path.join(ASSETS, "backgrounds", folder, l + ".png"))
            sx = (x0 * (i + 1) // 4) % max(1, im.width - W)
            out.alpha_composite(im.crop((sx, 0, sx + W, H)))
        return _ground(out, load(os.path.join(ASSETS, "tiles", terr))) if ground else out
    shipped = sorted(glob.glob(os.path.join(ASSETS, "backgrounds", name, "layer*.png")))   # the main set only
    terr = os.path.join(ASSETS, "tiles", name, "terrain.png")
    if shipped and os.path.exists(terr):
        for l in shipped:
            im = load(l)
            out.alpha_composite(im.crop((0, 0, min(W, im.width), H)))
        return _ground(out, load(terr)) if ground else out
    bt = _biome_tests()
    b = bt.BIOMES[NEW[name]]
    path, y0, y1, tint = b["sky"]
    sky = bt.band(path, y0, y1, tint)
    sky = sky.resize((W, int(sky.size[1] * W / sky.size[0])), Image.NEAREST)
    out.alpha_composite(sky.crop((0, 0, W, min(H, sky.size[1]))), (0, 0))
    atlas = bt.gmap(Image.open(os.path.join(ASSETS, "tiles", b["src"])), b["ramp"])
    return _ground(out, atlas)


ALL = list(OLD) + list(NEW)

"""Build the platform app icons from the hero art (development tool, not exported).

    .tools/venv/Scripts/python.exe tools/make_app_icons.py

Writes, next to assets/icon.png:
  assets/icon_1024.png               1024 x 1024, opaque (iOS App Store / home screen; the system rounds the corners)
  assets/icon_android_foreground.png 432 x 432, the hero on transparency inside the adaptive-icon safe zone
  assets/icon_android_background.png 432 x 432, opaque sky and grass
  assets/icon_android_monochrome.png 432 x 432, the hero as a white cut-out (Android 13 themed icons)

Everything is drawn on the hero's own pixel grid (one cell of sprites/player/hero.png = one art pixel) and enlarged
by an integer factor with nearest-neighbour sampling only, so the icons stay as crisp as the game. The pose is the
victory frame (club raised), the same as assets/icon.png.
"""

from __future__ import annotations

import math
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERO_SHEET = os.path.join(ROOT, "assets", "sprites", "player", "hero.png")
CELL_W, CELL_H, COLUMNS = 176, 112, 8
FRAME = 48  # victory pose, club raised (ASSET_MANIFEST 3)

# Palette: the sky and jungle greens of ui/title_background.png, a warm sun behind the hero's head (his orange needs
# a cool sky to stand out), the art's ink outline (ASSET_MANIFEST 1).
INK = (39, 32, 24)
SKY_HIGH = (98, 181, 214)
SKY = (104, 192, 226)
SKY_LOW = (119, 217, 255)
SUN = (255, 233, 79)
SUN_HALO = (255, 241, 207)
GRASS_LIGHT = (143, 222, 93)
GRASS = (79, 173, 45)
GRASS_DARK = (51, 147, 58)
GRASS_DEEP = (44, 115, 66)
WHITE = (255, 255, 255, 255)

ANDROID_SIZE = 432
# Adaptive icons: 108 dp layers, of which a 66 dp circle is never masked away.
ANDROID_SAFE_RADIUS = ANDROID_SIZE * 66 / 108 / 2


def hero_frame() -> Image.Image:
    sheet = Image.open(HERO_SHEET).convert("RGBA")
    x, y = (FRAME % COLUMNS) * CELL_W, (FRAME // COLUMNS) * CELL_H
    cell = sheet.crop((x, y, x + CELL_W, y + CELL_H))
    return cell.crop(cell.getbbox())


def dither(x: int, y: int) -> bool:
    return (x + y) % 2 == 0


def background(grid: int, ground_y: int, sun: tuple[float, float], sun_r: float) -> Image.Image:
    """Sky with a pixel sun and a grass strip from `ground_y` down, `grid` x `grid` art pixels."""
    img = Image.new("RGB", (grid, grid), SKY)
    px = img.load()
    halo_r = sun_r * 1.25
    band = ground_y / 3.0
    for y in range(grid):
        for x in range(grid):
            # Three sky bands, lighter towards the horizon, with a dithered seam.
            level = y / band
            edge = level - math.floor(level)
            step = math.floor(level) + (1 if edge > 0.92 and dither(x, y) else 0)
            color = (SKY_HIGH, SKY, SKY_LOW, SKY_LOW)[min(step, 3)]
            d = math.hypot(x + 0.5 - sun[0], y + 0.5 - sun[1])
            if d < sun_r - 0.5 or (d < sun_r + 0.5 and dither(x, y)):
                color = SUN
            elif d < halo_r - 0.5 or (d < halo_r + 0.5 and dither(x, y)):
                color = SUN_HALO
            px[x, y] = color
    for x in range(grid):
        # A blade every few columns pokes one pixel above the grass line.
        blade = x % 6 == 2 or x % 13 == 7
        top = ground_y - (1 if blade else 0)
        for y in range(max(top, 0), grid):
            depth = y - ground_y
            if y == top:
                color = INK
            elif depth <= 0:
                color = GRASS_LIGHT if blade else INK
            elif depth == 1:
                color = GRASS_LIGHT
            elif depth < 6:
                color = GRASS if not (depth == 4 and x % 4 == 1) else GRASS_DARK
            elif depth < 7 or (depth < 8 and dither(x, y)):
                color = GRASS_DARK
            elif depth < 12 or (depth < 13 and dither(x, y)):
                color = GRASS_DARK if not (depth == 9 and x % 5 == 3) else GRASS_DEEP
            else:
                color = GRASS_DEEP
            px[x, y] = color
    return img


def enlarge(img: Image.Image, factor: int) -> Image.Image:
    return img.resize((img.width * factor, img.height * factor), Image.NEAREST)


def opaque_points(img: Image.Image):
    alpha = img.getchannel("A").load()
    for y in range(img.height):
        for x in range(img.width):
            if alpha[x, y] > 0:
                yield x, y


def ios_icon(hero: Image.Image) -> Image.Image:
    size, scale = 1024, 10
    grid = math.ceil(size / scale)  # 103 art pixels, cropped to 1024 below
    left = (grid - hero.width) // 2
    feet = 85
    top = feet - hero.height
    art = background(grid, feet - 2, (left + hero.width * 0.62, top + hero.height * 0.36), hero.height * 0.34)
    art = art.convert("RGBA")
    art.alpha_composite(hero, (left, top))
    big = enlarge(art, scale)
    crop = (big.width - size) // 2
    return big.crop((crop, crop, crop + size, crop + size)).convert("RGB")


def android_layers(hero: Image.Image) -> tuple[Image.Image, Image.Image, Image.Image]:
    scale = 3
    grid = ANDROID_SIZE // scale  # 144 art pixels
    centre = grid / 2
    # Place the hero so that his farthest opaque pixel is as close to the centre as possible (safe zone).
    best = None
    for dx in range(-6, 7):
        for dy in range(-6, 7):
            left = round(centre - hero.width / 2) + dx
            top = round(centre - hero.height / 2) + dy
            reach = max(
                math.hypot((left + x + 0.5) - centre, (top + y + 0.5) - centre) for x, y in opaque_points(hero)
            )
            if best is None or reach < best[0]:
                best = (reach, left, top)
    reach, left, top = best
    if reach * scale > ANDROID_SAFE_RADIUS:
        sys.exit("hero does not fit the adaptive-icon safe zone: %.1f > %.1f px" % (reach * scale, ANDROID_SAFE_RADIUS))
    feet = top + hero.height
    back = background(grid, feet - 2, (left + hero.width * 0.62, top + hero.height * 0.36), hero.height * 0.34)
    fore = Image.new("RGBA", (grid, grid), (0, 0, 0, 0))
    fore.alpha_composite(hero, (left, top))
    mono = Image.new("RGBA", (grid, grid), (0, 0, 0, 0))
    mono_px = mono.load()
    hero_px = hero.load()
    for x, y in opaque_points(hero):
        r, g, b, _a = hero_px[x, y]
        # The dark outline becomes the gaps between the shapes, so the silhouette keeps its drawing.
        if r + g + b > 130:
            mono_px[left + x, top + y] = WHITE
    print("android: hero reach %.1f px of %.1f px safe radius" % (reach * scale, ANDROID_SAFE_RADIUS))
    return enlarge(fore, scale), enlarge(back, scale), enlarge(mono, scale)


def main() -> None:
    hero = hero_frame()
    out = os.path.join(ROOT, "assets")
    ios_icon(hero).save(os.path.join(out, "icon_1024.png"), optimize=True)
    fore, back, mono = android_layers(hero)
    fore.save(os.path.join(out, "icon_android_foreground.png"), optimize=True)
    back.convert("RGB").save(os.path.join(out, "icon_android_background.png"), optimize=True)
    mono.save(os.path.join(out, "icon_android_monochrome.png"), optimize=True)
    print("wrote icon_1024.png, icon_android_foreground.png, icon_android_background.png, icon_android_monochrome.png")


if __name__ == "__main__":
    main()

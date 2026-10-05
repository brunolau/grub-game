"""Build the Windows installer art from the game's own sprites (run from the project root).

    .tools/venv/Scripts/python.exe tools/make_installer_art.py

Writes into installer/:
  club_and_grub.ico          setup + uninstaller icon (256, 128, 64, 48, 32, 16 px)
  wizard_large_<n>x.png      left wizard panel, 202 x 386 (Inno Setup 7's area at 100 % DPI) times n = 1, 2, 3
  wizard_small_<n>x.png      top-right wizard image, 58 x 58 times n = 1, 2, 3
Setup picks the file that best matches the DPI. Pixel art is only scaled by whole numbers (nearest neighbour);
the icon pictures below 256 px are box-filtered.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "installer"

HERO_CELL = (176, 112)  # assets/sprites/player/hero.png, 8 x 7 cells, frame 0 = idle
FOOD_CELL = 32  # assets/sprites/items/food.png, 16 px icons at 2x
TILE = 32  # assets/tiles/*/terrain*.png, 8 x 5 atlas (index 1 = top, 9 = fill)
LARGE = (202, 386)
SMALL = (58, 58)
SCALES = (1, 2, 3)


def _icon() -> None:
    icon = Image.open(ROOT / "assets/icon.png").convert("RGBA")
    sizes = [(s, s) for s in (256, 128, 64, 48, 32, 16)]
    icon.save(OUT / "club_and_grub.ico", sizes=sizes)


def _food(index: int) -> Image.Image:
    sheet = Image.open(ROOT / "assets/sprites/items/food.png").convert("RGBA")
    cols = sheet.width // FOOD_CELL
    x, y = (index % cols) * FOOD_CELL, (index // cols) * FOOD_CELL
    return sheet.crop((x, y, x + FOOD_CELL, y + FOOD_CELL))


def _tile(index: int) -> Image.Image:
    atlas = Image.open(ROOT / "assets/tiles/jungle/terrain_grass.png").convert("RGBA")
    x, y = (index % 8) * TILE, (index // 8) * TILE
    return atlas.crop((x, y, x + TILE, y + TILE))


def _large() -> Image.Image:
    # The jungle parallax set (sky, far hills, hills, forest), sliced to the panel and resting on grass.
    ground_rows = 2
    ground_y = LARGE[1] - ground_rows * TILE + 8
    panel = Image.new("RGBA", LARGE)
    for layer in ("layer0_sky", "layer1_far_hills", "layer2_hills", "layer3_forest"):
        image = Image.open(ROOT / f"assets/backgrounds/jungle/{layer}.png").convert("RGBA")
        # Bottom of the backdrop at the grass line, as in a level.
        top = image.height - ground_y - 24
        panel.alpha_composite(image.crop((200, top, 200 + LARGE[0], top + LARGE[1])))
    for col in range(-(-LARGE[0] // TILE)):
        panel.alpha_composite(_tile(1), (col * TILE, ground_y))  # top
        panel.alpha_composite(_tile(9), (col * TILE, ground_y + TILE))  # fill
    hero = Image.open(ROOT / "assets/sprites/player/hero.png").convert("RGBA").crop((0, 0, *HERO_CELL))
    body = hero.crop(hero.getbbox())
    # The grass top has a few transparent pixels above the walking line; feet sit on the line.
    feet_y = ground_y + 6
    panel.alpha_composite(body, ((LARGE[0] - body.width) // 2, feet_y - body.height))
    # A little arc of food above the hero.
    for i, (dx, dy) in enumerate([(-52, -150), (-18, -176), (18, -176), (52, -150)]):
        item = _food((3, 9, 17, 25)[i])
        panel.alpha_composite(item, (LARGE[0] // 2 + dx - FOOD_CELL // 2, feet_y + dy))
    return panel.convert("RGB")


def _small(scale: int) -> Image.Image:
    icon = Image.open(ROOT / "assets/icon.png").convert("RGBA")
    return icon.resize((SMALL[0] * scale, SMALL[1] * scale), Image.Resampling.BOX).convert("RGB")


def main() -> None:
    OUT.mkdir(exist_ok=True)
    _icon()
    for stale in list(OUT.glob("wizard_*.png")):
        stale.unlink()
    large = _large()
    for scale in SCALES:
        size = (LARGE[0] * scale, LARGE[1] * scale)
        large.resize(size, Image.Resampling.NEAREST).save(OUT / f"wizard_large_{scale}x.png")
        _small(scale).save(OUT / f"wizard_small_{scale}x.png")
    print("installer art written to", OUT)


if __name__ == "__main__":
    main()

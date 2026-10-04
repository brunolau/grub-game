"""Generate the BMFont descriptions of the three bitmap fonts (docs/ASSET_MANIFEST.md section 12).

Owner: ui module. The glyph pictures stay where the art pipeline put them (assets/fonts/*.png); this script only
measures every cell and writes a text .fnt next to itself, which Godot imports as a FontFile:

    .tools/venv/Scripts/python.exe resources/ui/make_bitmap_fonts.py

Run it again whenever one of the font sheets changes. Glyph boxes are measured from the alpha channel, so the
fonts are proportional; digits keep one common advance so that counters do not jitter.
"""

import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "fonts"))
PAGE_PREFIX = "../../assets/fonts/"

# Code page 437 order of the accented cells 96..119 of font_hud.png (manifest section 12).
HUD_ACCENTS = [
    0xC7, 0xFC, 0xE9, 0xE2, 0xE4, 0xE0, 0xE5, 0xE7, 0xEA, 0xEB, 0xE8, 0xEF,
    0xEE, 0xEC, 0xC4, 0xC5, 0xC9, 0xE6, 0xC6, 0xF4, 0xF6, 0xF2, 0xFB, 0xF9,
]


def measure(image, cell_w, cell_h, index, columns):
    """Bounding box (left, top, right, bottom) of the glyph inside its cell, or None for an empty cell."""
    cx = (index % columns) * cell_w
    cy = (index // columns) * cell_h
    return image.getchannel("A").crop((cx, cy, cx + cell_w, cy + cell_h)).getbbox()


def build(name, sheet, cell_w, cell_h, columns, cells, base, spacing, space_advance, digit_advance):
    """Write <name>.fnt. `cells` maps a Unicode code point to its cell index."""
    image = Image.open(os.path.join(FONT_DIR, sheet)).convert("RGBA")
    lines = []
    for code in sorted(cells):
        index = cells[code]
        box = measure(image, cell_w, cell_h, index, columns)
        if box is None:
            continue
        left, top, right, bottom = box
        width = right - left
        advance = width + spacing
        x_offset = 0
        if digit_advance and ord("0") <= code <= ord("9"):
            advance = digit_advance
            x_offset = (digit_advance - spacing - width) // 2
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15"
            % (
                code,
                (index % columns) * cell_w + left,
                (index // columns) * cell_h + top,
                width,
                bottom - top,
                x_offset,
                top,
                advance,
            )
        )
    lines.append(
        "char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15" % space_advance
    )
    header = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 '
        "padding=0,0,0,0 spacing=0,0 outline=0" % (name, cell_h),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 redChnl=0 "
        "greenChnl=0 blueChnl=0" % (cell_h, base, image.size[0], image.size[1]),
        'page id=0 file="%s%s"' % (PAGE_PREFIX, sheet),
        "chars count=%d" % len(lines),
    ]
    path = os.path.join(HERE, name + ".fnt")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(header + lines) + "\n")
    print("%s: %d glyphs" % (path, len(lines)))


def main():
    hud = {}
    for index in range(1, 95):
        hud[32 + index] = index
    for offset, code in enumerate(HUD_ACCENTS):
        hud[code] = 96 + offset
    build("font_hud", "font_hud.png", 20, 20, 15, hud, 16, 2, 10, 16)

    title = {}
    for offset in range(26):
        title[ord("A") + offset] = offset
        title[ord("a") + offset] = offset
    for offset in range(10):
        title[ord("0") + offset] = 26 + offset
    build("font_title", "font_title.png", 52, 36, 12, title, 36, 0, 18, 0)

    digits = {ord("0") + offset: offset for offset in range(10)}
    build("font_digits_big", "font_digits_big.png", 40, 40, 10, digits, 38, 0, 18, 34)


if __name__ == "__main__":
    main()

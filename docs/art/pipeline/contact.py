"""Contact-sheet helper used while reviewing candidate art (not used by the game)."""
import sys, os
from PIL import Image, ImageDraw

def sheet(paths, out, scale=1, bg=(90, 110, 140, 255), maxw=1800, pad=6, label=True, thumb=None):
    ims = []
    for p in paths:
        try:
            im = Image.open(p).convert("RGBA")
        except Exception as e:
            print("ERR", p, e); continue
        if thumb:
            im.thumbnail(thumb, Image.NEAREST)
        if scale != 1:
            im = im.resize((int(im.width * scale), int(im.height * scale)), Image.NEAREST)
        ims.append((p, im))
    x = y = pad; rowh = 0; pos = []
    W = 0
    for p, im in ims:
        if x + im.width + pad > maxw and x > pad:
            x = pad; y += rowh + pad + (12 if label else 0); rowh = 0
        pos.append((x, y))
        x += im.width + pad; rowh = max(rowh, im.height); W = max(W, x)
    H = y + rowh + pad + (12 if label else 0)
    canvas = Image.new("RGBA", (max(W, 64), H), bg)
    d = ImageDraw.Draw(canvas)
    for (p, im), (x, y) in zip(ims, pos):
        canvas.alpha_composite(im, (x, y))
        if label:
            d.text((x, y + im.height), os.path.basename(p)[:40] + " %dx%d" % (im.width // max(scale,1) if scale>=1 else im.width, im.height // max(scale,1) if scale>=1 else im.height), fill=(255, 255, 255, 255))
    canvas.save(out)
    print(out, canvas.size)

if __name__ == "__main__":
    out = sys.argv[1]; scale = float(sys.argv[2]); paths = sys.argv[3:]
    sheet(paths, out, scale if scale < 1 else int(scale))

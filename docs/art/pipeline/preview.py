"""Preview helper: draw a sheet on a flat background with its cell grid (review only)."""
import sys, os, json
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from common import ROOT, REG_PATH

def preview(rel, out, scale=1, grid=True, bg=(88, 150, 200, 255), crop=None):
    reg = json.load(open(REG_PATH, encoding="utf-8"))
    im = Image.open(os.path.join(ROOT, rel)).convert("RGBA")
    meta = reg.get(rel.replace("\\", "/"), {})
    b = Image.new("RGBA", im.size, bg); b.alpha_composite(im)
    if crop: b = b.crop(crop)
    b = b.resize((b.width * scale, b.height * scale), Image.NEAREST)
    if grid and "frame" in meta and not crop:
        d = ImageDraw.Draw(b); fw, fh = meta["frame"]
        for x in range(0, im.width + 1, fw): d.line((x * scale, 0, x * scale, b.height), fill=(0, 255, 255, 255))
        for y in range(0, im.height + 1, fh): d.line((0, y * scale, b.width, y * scale), fill=(0, 255, 255, 255))
        n = 0
        for y in range(0, im.height, fh):
            for x in range(0, im.width, fw):
                d.text((x * scale + 3, y * scale + 2), str(n), fill=(255, 255, 0, 255)); n += 1
        py = meta.get("pivot", [0, 0])[1]
        for y in range(0, im.height, fh):
            d.line((0, (y + py) * scale, b.width, (y + py) * scale), fill=(255, 0, 0, 120))
    b.save(out); print(out, b.size)

if __name__ == "__main__":
    preview(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 1)

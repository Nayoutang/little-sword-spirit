import json
import sys
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
out = root / "art/ui/battle"
out.mkdir(parents=True, exist_ok=True)
image = Image.open(source).convert("RGBA")
image.save(out / "atlas-source-v1.png")
# Observed grid boundaries in the inspected generated atlas.
w, h = image.size
rows = [0, round(h * 430 / 1088), round(h * 822 / 1088), h]
names = ["gather", "guard", "waves", "thrust", "frame", "deck", "discard", "intent", "button", "hud", "speech", "shield"]
for index, name in enumerate(names):
    col, row = index % 4, index // 4
    box = (round(w * col / 4) + 10, rows[row] + 10, round(w * (col + 1) / 4) - 10, rows[row + 1] - 10)
    cell = image.crop(box)
    alpha = cell.getchannel("A").point(lambda a: 255 if a > 100 else 0)
    bbox = alpha.getbbox()
    if bbox:
        cell = cell.crop(bbox)
    cell.save(out / (name + ".png"))
    print(name, cell.size)
(out / "manifest.json").write_text(json.dumps({"tool": "built-in imagegen", "reference": "art/concepts/battle-ui-target-v1.png", "source": str(source), "normalization": "Inspected grid sliced with transparent gutters. Originals retained.", "assets": names}, ensure_ascii=False, indent=2), encoding="utf-8")

"""Deterministic normalization/QA of generated art; no AI editing or repainting."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
records = []
for path in sorted((ROOT / "art/cards").rglob("*.png")):
    image = Image.open(path).convert("RGBA")
    if image.size != (512, 442):
        image.thumbnail((496, 426), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (512, 442))
        canvas.alpha_composite(image, ((512 - image.width) // 2, (442 - image.height) // 2))
        canvas.save(path)
        image = canvas
    alpha = image.getchannel("A")
    records.append({"path": path.relative_to(ROOT).as_posix(), "size": list(image.size),
                    "alpha_extrema": list(alpha.getextrema()), "bbox": alpha.getbbox(),
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    import_path = Path(str(path) + ".import")
    if import_path.exists():
        data = import_path.read_text(encoding="utf-8")
        import_path.write_text(data.replace("mipmaps/generate=false", "mipmaps/generate=true"), encoding="utf-8")

portrait_path = ROOT / "art/effects/brilliance_ink_figure_v1.png"
if portrait_path.exists():
    portrait = Image.open(portrait_path).convert("RGBA")
    if portrait.width > 1600 or portrait.height > 1100:
        portrait.thumbnail((1600, 1100), Image.Resampling.LANCZOS)
        portrait.save(portrait_path)
    import_path = Path(str(portrait_path) + ".import")
    if import_path.exists():
        data = import_path.read_text(encoding="utf-8")
        import_path.write_text(data.replace("mipmaps/generate=false", "mipmaps/generate=true"), encoding="utf-8")

report_path = ROOT / "art/cards/raster-qa.json"
report_path.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
font = ImageFont.truetype("C:/Windows/Fonts/simkai.ttf", 18)
columns, cw, ch = 6, 224, 228
sheet = Image.new("RGB", (columns * cw, ((len(records) + columns - 1) // columns) * ch), "#e8e2d2")
draw = ImageDraw.Draw(sheet)
for index, record in enumerate(records):
    image = Image.open(ROOT / record["path"]).convert("RGBA")
    image.thumbnail((208, 182), Image.Resampling.LANCZOS)
    x, y = index % columns * cw, index // columns * ch
    sheet.paste(image, (x + (cw - image.width) // 2, y + 8), image)
    label = Path(record["path"]).stem.removesuffix("_v1")
    draw.text((x + 6, y + 194), label, font=font, fill="#203b36")
sheet.save(ROOT / "art/previews/card-covers-contact-v1.png")
print(json.dumps({"normalized_generated_covers": len(records), "unique_hashes": len({r['sha256'] for r in records}),
                  "all_have_transparent_edges": all(r["alpha_extrema"][0] == 0 and r["alpha_extrema"][1] > 0 for r in records)}, ensure_ascii=False))

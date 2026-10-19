"""Normalize only the 2026-10-19 card family; retain generated sources."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
manifest_path = ROOT / 'art/cards/build-routes-20261019.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
sheet = Image.new('RGB', (960, 960), '#e8e2d2')
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype('C:/Windows/Fonts/simkai.ttf', 23)
report = []
for index, asset in enumerate(manifest['assets']):
    source = ROOT / asset['source']
    original = Image.open(source).convert('RGBA')
    assert original.getchannel('A').getextrema()[0] == 0, source
    image = original.copy()
    image.thumbnail((496, 426), Image.Resampling.LANCZOS)
    output = Image.new('RGBA', (512, 442))
    output.alpha_composite(image, ((512-image.width)//2, (442-image.height)//2))
    target = ROOT / asset['runtime']
    output.save(target)
    import_file = Path(str(target) + '.import')
    if import_file.exists():
        settings = import_file.read_text(encoding='utf-8')
        import_file.write_text(settings.replace('mipmaps/generate=false',
                                               'mipmaps/generate=true'), encoding='utf-8')
    alpha = output.getchannel('A')
    report.append({'id': asset['id'], 'path': asset['runtime'],
                   'size': list(output.size), 'source_size': list(original.size),
                   'alpha_extrema': list(alpha.getextrema()), 'bbox': alpha.getbbox(),
                   'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    output.thumbnail((300, 270), Image.Resampling.LANCZOS)
    x, y = index % 3 * 320, index // 3 * 320
    sheet.paste(output, (x+(320-output.width)//2, y+8), output)
    draw.text((x+25, y+282), f"{asset['id']}  {asset['name']}", font=font, fill='#203b36')
(ROOT / 'art/cards/build-routes-raster-qa.json').write_text(
    json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
sheet.save(ROOT / 'art/previews/build-routes-covers-v1.jpg', quality=94)
assert len({entry['sha256'] for entry in report}) == 9
print('9 unique 512x442 covers normalized; alpha checked.')

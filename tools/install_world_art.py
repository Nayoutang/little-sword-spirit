"""Slice the verified relic atlas and normalize the sword-tomb background."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
IDS = ['old_scabbard', 'whetstone_chip', 'green_tassel', 'lovers_knot',
       'half_jade', 'heart_mirror', 'blade_inscription', 'wine_gourd',
       'peace_charm', 'bronze_bell', 'old_umbrella', 'letter_envelope', 'broken_string']
NAMES = ['旧剑鞘', '磨剑石片', '青色剑穗', '同心结', '半块玉佩', '护心镜',
         '剑铭', '酒葫芦', '平安符', '铜铃', '旧伞', '信笺', '断弦']
atlas = Image.open(ROOT / 'art/relics/sources/relic_atlas_source_v1.png').convert('RGBA')
assert atlas.getchannel('A').getextrema() == (0, 255)
sheet = Image.new('RGB', (1000, 1000), '#eee4ce')
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype('C:/Windows/Fonts/simkai.ttf', 24)
records = []
for i, (slug, name) in enumerate(zip(IDS, NAMES)):
    x, y = i % 4, i // 4
    cell = atlas.crop((round(x*atlas.width/4), round(y*atlas.height/4),
                       round((x+1)*atlas.width/4), round((y+1)*atlas.height/4)))
    bbox = cell.getchannel('A').getbbox()
    assert bbox, slug
    icon = cell.crop(bbox)
    icon.thumbnail((224, 224), Image.Resampling.LANCZOS)
    out = Image.new('RGBA', (256, 256))
    out.alpha_composite(icon, ((256-icon.width)//2, (256-icon.height)//2))
    target = ROOT / f'art/relics/{slug}_v1.png'
    out.save(target)
    thumb = out.resize((200, 200), Image.Resampling.LANCZOS)
    sheet.paste(thumb, (x*250+25, y*250+4), thumb)
    draw.text((x*250+25, y*250+212), name, font=font, fill='#253e35')
    records.append({'id': slug, 'name': name, 'path': target.relative_to(ROOT).as_posix(),
                    'size': list(out.size), 'atlas_bbox': bbox,
                    'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
sheet.save(ROOT / 'art/previews/relic-icons-v1.jpg', quality=94)
(ROOT / 'art/relics/raster-qa.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
background = Image.open(ROOT / 'art/backgrounds/sources/ch3_sword_tomb_battle_source_v1.png').convert('RGB')
background.resize((1920,1080), Image.Resampling.LANCZOS).save(ROOT / 'art/backgrounds/ch3_sword_tomb_battle_v1.png')
print('13 relic icons and 1920x1080 battle background normalized.')

from pathlib import Path
from PIL import Image, ImageOps, ImageDraw
import json, hashlib, shutil
ROOT=Path.cwd()
SRC=Path(r'C:/Users/Du/.codex/generated_images/01a148b7-ff4d-7383-9345-19be3231e5c0')
items=[
('ch3_opening_dawn','3e7ffe29-7dce-4d3e-acca-3b19566146a9','story','清晨解下紫线，桌上平放带鞘剑'),
('ch3_sword_tomb','b4b20733-c19e-499c-996d-ae1a0fa4cc99','story','山谷缠线群剑，小墨倾听，远方戏台'),
('ch3_old_sword_letter','1a86418c-bcdc-4ab7-84a8-53ebdd0c0bc1','story','无紫线的旧剑，布条绑信与剑谱，小墨解下'),
('ch3_tomb_departure','c283ac0a-f3fd-4293-aa0f-c79378924326','story','背身出谷不回头，怀抱信件，身后剑鸣'),
('ch3_final_thread','d68b0293-c0d4-493f-ad59-5707080866ce','story','戏台最后紫线断裂，戏先生垂首看空手，小墨持剑'),
('ch3_lamplit_letter','04437d83-d9b8-4cd0-b249-4c969c8dfbe2','story','家中夜灯下拆信，小墨克制微笑，桌上完整带鞘剑'),
('puppeteer','440e3ad4-159b-4a88-9113-ca8ed4f35d6e','enemy','人类戏先生，黑发黑白长衫紫袖，双手操细线，无面具无剑'),
('bound_spirit','bcb817ab-68ff-4e3d-a0ff-8433558e8345','enemy','被牵剑灵，银灰长发，灰白破衣，持直剑，被紫线牵住手腕肩部'),
('scroll_jiesi','0577917e-9fe3-45c9-a5f4-e560b70834a2','scroll','旧纸水墨图，剑断紫线，青色气流托起一张卡牌'),
('scroll_shoujian','2b966e95-b9a2-4503-91c2-7d1057380363','scroll','旧纸水墨图，收鞘直剑，两人并肩，剑灵出剑，青色守护弧')]
records=[]
for name,ident,kind,prompt in items:
    folder=ROOT/('art/enemies/chapter_three' if kind=='enemy' else 'art/story/chapter_three')
    folder.mkdir(parents=True,exist_ok=True)
    source=folder/'sources'/f'{name}_source_v1.png'
    source.parent.mkdir(exist_ok=True)
    shutil.copy2(SRC/f'exec-{ident}.png',source)
    im=Image.open(source).convert('RGBA' if kind!='story' else 'RGB')
    if kind=='story':
        im=ImageOps.fit(im,(1920,1080),method=Image.Resampling.LANCZOS)
    else:
        im=im.crop(im.getchannel('A').getbbox())
        bounds=(672,800) if kind=='enemy' else (720,800)
        im.thumbnail(bounds,Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(768,896))
        pos=((768-im.width)//2,848-im.height) if kind=='enemy' else ((768-im.width)//2,(896-im.height)//2)
        canvas.alpha_composite(im,pos)
        im=canvas
        assert im.getpixel((0,0))[3]==0
    out=folder/f'{name}{"_sprite" if kind=="enemy" else ""}_v1.png'
    im.save(out)
    records.append(dict(id=name,kind=kind,path=out.relative_to(ROOT).as_posix(),source=source.relative_to(ROOT).as_posix(),generation_id=ident,prompt_subject=prompt,size=list(im.size),alpha_extrema=list(im.getchannel('A').getextrema()) if kind!='story' else None,sha256=hashlib.sha256(out.read_bytes()).hexdigest(),status='normalized; pending in-engine review',source_tool='built-in imagegen',date='2026-10-17',pivot='bottom center, baseline y=848' if kind=='enemy' else 'center',collision='none; presentation only'))
manifest=dict(common_prompt='Chinese fantasy painterly illustration matching chapter two references. Preserve Xiaomo brown hair, amber eyes, white teal gold hanfu; preserve puppeteer rooftop identity. No UI, captions, borders or watermark. Story 16:9 with lower dialogue-safe area; items and enemies true transparent alpha.',references=['art/story/chapter_two/ch2_opening_window_v1.png','art/story/chapter_two/ch2_ending_rooftop_v1.png','art/enemies/ink_swordsman_sprite_v1.png','art/enemies/chapter_two/thread_master_sprite_v1.png','art/story/chapter_two/scroll_duansi_v1.png'],provenance='AI-generated with built-in imagegen; existing project assets used as references; no external stock assets.',assets=records)
(ROOT/'art/story/chapter_three/asset_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
# Native aspect previews, deterministic resize only.
sheet=Image.new('RGB',(960,270*4),(35,38,43)); d=ImageDraw.Draw(sheet)
for i,record in enumerate(records):
    im=Image.open(ROOT/record['path']).convert('RGBA'); im.thumbnail((472,240))
    x=(i%2)*480+(480-im.width)//2; y=(i//2)*270
    if y+270>sheet.height:
        larger=Image.new('RGB',(960,y+270),(35,38,43)); larger.paste(sheet,(0,0)); sheet=larger; d=ImageDraw.Draw(sheet)
    sheet.paste(im,(x,y),im); d.text(((i%2)*480+8,y+244),record['id'],fill='white')
preview=ROOT/'art/previews/chapter-three-assets-v1.png'; sheet.save(preview)
print('Normalized 10 chapter-three assets and refreshed manifest/contact sheet.')

"""Validate PNGs and build transparent sheets and review animations."""
import json
import math
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops

root=Path(__file__).resolve().parent
report=json.loads((root/'validation.json').read_text())
all_frames={}
checks={}
for kind,spec in report['actions'].items():
    paths=sorted((root/kind/'frames').glob(f'{kind}_*.png'))
    assert len(paths)==spec['count'],(kind,len(paths))
    frames=[Image.open(p).convert('RGBA') for p in paths]
    all_frames[kind]=frames
    boxes=[]
    for frame in frames:
        assert frame.size==(512,512)
        box=frame.getchannel('A').getbbox()
        assert box and box[0]>0 and box[1]>0 and box[2]<512 and box[3]<512,(kind,box)
        assert frame.getchannel('A').getextrema()==(0,255)
        boxes.append(box)
    assert any(ImageChops.difference(frames[0],f).getbbox(alpha_only=False) for f in frames[1:]),kind
    sheet=Image.new('RGBA',(512*4,512*math.ceil(len(frames)/4)))
    reviews=[]
    for i,frame in enumerate(frames):
        sheet.paste(frame,(i%4*512,i//4*512))
        bg=Image.new('RGBA',(512,512),'#24252b')
        bg.alpha_composite(frame)
        reviews.append(bg.convert('RGB'))
    sheet.save(root/kind/f'{kind}_sheet.png')
    timing=[round((i+1)*1000/24)-round(i*1000/24) for i in range(len(frames))]
    reviews[0].save(root/kind/f'{kind}_preview.webp',save_all=True,append_images=reviews[1:],duration=timing,loop=0,lossless=True)
    # GIFs are review-only. Hold the terminal jump pose before replaying it.
    gif_frames=[im.resize((384,384),Image.Resampling.LANCZOS) for im in reviews]
    gif_timing=[round((i+1)*100/24)*10-round(i*100/24)*10 for i in range(len(frames))]
    if not spec['loop']:
        gif_timing[-1]+=500
    gif_frames[0].save(root/kind/f'{kind}_preview.gif',save_all=True,append_images=gif_frames[1:],duration=gif_timing,loop=0)
    checks[kind]={'count':len(frames),'rgba':True,'all_inside_canvas':True,'alpha_bounds':boxes,'sheet_columns':4,'sheet_rows':math.ceil(len(frames)/4)}

assert ImageChops.difference(all_frames['jump'][-1],all_frames['fall'][0]).getbbox(alpha_only=False) is None,'Rendered jump/fall seam mismatch'
contact=Image.new('RGB',(1024,3*280),'#24252b')
draw=ImageDraw.Draw(contact)
for row,(kind,frames) in enumerate(all_frames.items()):
    for col,index in enumerate([0,len(frames)//4,len(frames)//2,3*len(frames)//4]):
        bg=Image.new('RGBA',(512,512),'#24252b')
        bg.alpha_composite(frames[index])
        contact.paste(bg.convert('RGB').resize((256,256)),(col*256,row*280+24))
        draw.text((col*256+8,row*280+7),f'{kind.upper()} / {index+1}',fill='white')
contact.save(root/'movement_contact.png')
combined=[]
for i in range(48):
    panel=Image.new('RGB',(960,344),'#24252b')
    draw=ImageDraw.Draw(panel)
    for column,kind in enumerate(['run','jump','fall']):
        sequence=all_frames[kind]
        index=min(i%24,11) if kind=='jump' else i%16
        bg=Image.new('RGBA',(512,512),'#24252b')
        bg.alpha_composite(sequence[index])
        panel.paste(bg.convert('RGB').resize((320,320),Image.Resampling.LANCZOS),(column*320,24))
        draw.text((column*320+16,9),kind.upper(),fill='white')
    combined.append(panel)
combined[0].save(root/'movement_preview.gif',save_all=True,append_images=combined[1:],duration=[round((i+1)*100/24)*10-round(i*100/24)*10 for i in range(48)],loop=0)
report['png_validation']=checks
report['jump_to_fall_pixels_identical']=True
(root/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('Verified 44 RGBA frames; all within 512x512; jump-to-fall pixels match.')

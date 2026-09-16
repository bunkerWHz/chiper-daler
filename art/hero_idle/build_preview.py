"""Build review media and verify the exported PNG sequence with Pillow."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageChops

root = Path(__file__).resolve().parent
paths = sorted((root / 'frames').glob('idle_*.png'))
assert len(paths) == 24
frames = [Image.open(p).convert('RGBA') for p in paths]
for frame in frames:
    assert frame.size == (512, 512)
    box = frame.getchannel('A').getbbox()
    assert box and box[0] > 0 and box[1] > 0 and box[2] < 512 and box[3] < 512, box
assert ImageChops.difference(frames[0], frames[12]).getbbox(alpha_only=False)
sheet = Image.new('RGBA', (512 * 6, 512 * 4))
for i, frame in enumerate(frames):
    sheet.paste(frame, (i % 6 * 512, i // 6 * 512))
sheet.save(root / 'idle_sheet.png')
previews = []
for frame in frames:
    bg = Image.new('RGBA', frame.size, '#24252b')
    bg.alpha_composite(frame)
    previews.append(bg.convert('RGB'))
previews[0].save(root / 'idle_preview.webp', save_all=True, append_images=previews[1:], duration=[83,83,84]*8, loop=0, lossless=True)
previews[0].save(root / 'idle_preview.gif', save_all=True, append_images=previews[1:], duration=[80,80,90]*8, loop=0)
contact = Image.new('RGB', (1024, 544), '#24252b')
draw = ImageDraw.Draw(contact)
for j, i in enumerate([0,6,12,18]):
    contact.paste(previews[i].resize((256,256)), (j*256, 24))
    draw.text((j*256+12, 7), f'{i/12:.1f} sec', fill='white')
    # Enlarged upper body provides a useful seam inspection.
    contact.paste(previews[i].crop((120,180,392,452)).resize((256,256)), (j*256, 288))
contact.save(root / 'idle_contact.png')
report = json.loads((root/'validation.json').read_text())
report['png_validation'] = {'count':24,'rgba':True,'all_inside_frame':True,'motion_present':True}
(root/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))

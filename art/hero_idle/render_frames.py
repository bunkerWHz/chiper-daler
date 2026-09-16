"""Run inside Hero_Idle.blend to re-export its 24 unique sprite frames."""
import bpy
from pathlib import Path

scene = bpy.context.scene
out = Path(bpy.data.filepath).parent / 'frames'
out.mkdir(exist_ok=True)
previous_frame, previous_path = scene.frame_current, scene.render.filepath
try:
    for i in range(24):
        scene.frame_set(1 + 2 * i)
        scene.render.filepath = str(out / f'idle_{i:02d}.png')
        bpy.ops.render.render(write_still=True)
finally:
    scene.frame_set(previous_frame)
    scene.render.filepath = previous_path

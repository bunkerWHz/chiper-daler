"""Run in Hero_Movement.blend. Optional JOB_START/JOB_END render a bounded batch."""
import bpy
import json
from pathlib import Path

out=Path(bpy.data.filepath).parent
spec=json.loads((out/'validation.json').read_text())['actions']
jobs=[(kind,i) for kind,s in spec.items() for i in range(s['count'])]
scene=bpy.context.scene
rig=bpy.data.objects['Armature']
previous_action=rig.animation_data.action
previous_frame,previous_path=scene.frame_current,scene.render.filepath
completed=[]
try:
    for kind,i in jobs[globals().get('JOB_START',0):globals().get('JOB_END',len(jobs))]:
        rig.animation_data.action=bpy.data.actions[spec[kind]['action']]
        scene.frame_set(i+1)
        scene.render.filepath=str(out/kind/'frames'/f'{kind}_{i:02d}.png')
        bpy.ops.render.render(write_still=True)
        completed.append([kind,i])
finally:
    rig.animation_data.action=previous_action
    scene.frame_set(previous_frame)
    scene.render.filepath=previous_path
result={'completed':completed}

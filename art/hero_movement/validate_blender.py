"""Check evaluated movement geometry in the saved Blender scene."""
import bpy,json,math
from pathlib import Path

path=Path(bpy.data.filepath).parent/'validation.json'
report=json.loads(path.read_text())
rig=bpy.data.objects['Armature']
scene=bpy.context.scene
rig.animation_data.action=bpy.data.actions['Hero_Run_Unarmed']
contacts=[]
for frame in range(1,17):
    scene.frame_set(frame)
    for i,name in enumerate(['leg_right','leg_left']):
        phase=((frame-1)/16+0.5*i)%1
        if phase<0.42:
            obj=bpy.data.objects[name].evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh=obj.to_mesh()
            bottom=min((obj.matrix_world @ v.co).z for v in mesh.vertices)
            obj.to_mesh_clear()
            contacts.append(abs(bottom+2.49748))
scale_error=0
for kind,spec in report['actions'].items():
    rig.animation_data.action=bpy.data.actions[spec['action']]
    for frame in range(1,spec['count']+1):
        scene.frame_set(frame)
        for bone in rig.pose.bones:
            assert all(math.isfinite(v) for row in bone.matrix for v in row)
            scale_error=max(scale_error,max(abs(v-1) for v in bone.scale))
report['max_bone_scale_error']=scale_error
report['max_run_contact_mesh_height_error']=max(contacts)
report['max_run_contact_mesh_height_error_pixels']=max(contacts)*512/5.6
assert scale_error<0.0001
assert report['max_run_contact_mesh_height_error_pixels']<1
path.write_text(json.dumps(report,indent=2),encoding='utf-8')
rig.animation_data.action=bpy.data.actions['Hero_Run_Unarmed']
scene.frame_set(1)
result={k:v for k,v in report.items() if k.startswith('max_')}

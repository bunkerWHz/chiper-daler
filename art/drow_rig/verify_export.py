import bpy, json
from pathlib import Path
p=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(p/'Drow_Rig.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
assert len(rigs)==1
custom_shapes={p.custom_shape for p in rigs[0].pose.bones if p.custom_shape}
meshes=[o for o in meshes if o not in custom_shapes]
assert len(rigs[0].data.bones)==33
assert not bpy.data.actions
skinned=[o for o in meshes if any(m.type=='ARMATURE' and m.object==rigs[0] for m in o.modifiers)]
rigid=[o for o in meshes if o.parent==rigs[0] and o.parent_type=='BONE' and o.parent_bone in rigs[0].data.bones]
assert len(skinned)+len(rigid)==len(meshes),[(o.name,o.parent_type,o.parent_bone) for o in meshes if o not in skinned and o not in rigid]
assert all(len(v.groups)>0 for o in skinned for v in o.data.vertices)
report={'reimport_ok':True,'meshes':len(meshes),'bones':len(rigs[0].data.bones),'animations':len(bpy.data.actions),'skinned_meshes':len(skinned),'rigid_bone_attachments':len(rigid)}
(p/'export_validation.json').write_text(json.dumps(report,indent=2))
print(report)

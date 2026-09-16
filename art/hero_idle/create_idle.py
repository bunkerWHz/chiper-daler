"""Run in the original CutOutAnim.blend using Blender Python. Creates a separate file."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Quaternion

OUT = Path(r'C:/Users/bunkerWHz/Documents/chiper-daler/art/hero_idle')
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'frames').mkdir(exist_ok=True)
rig = bpy.data.objects['Armature']
scene = bpy.context.scene
assert not rig.animation_data or not rig.animation_data.action, 'Do not replace an existing action'
source = bpy.data.filepath
for img in bpy.data.images:
    if img.source == 'FILE' and not img.packed_file:
        img.pack()
rig.animation_data_create()
action = bpy.data.actions.new('Hero_Idle_Unarmed')
action.use_fake_user = True
rig.animation_data.action = action
scene.render.fps = 24
scene.frame_start, scene.frame_end = 1, 48
scene.frame_preview_start, scene.frame_preview_end = 1, 48
rest_pelvis = rig.data.bones['Bone.010'].matrix_local.copy()
animated = ['Bone', 'Bone.001', 'Bone.003', 'Bone.004', 'Bone.005', 'Bone.007', 'Bone.008', 'Bone.009', 'Bone.010']
for name in animated:
    rig.pose.bones[name].rotation_mode = 'QUATERNION'
def rotate(name, degrees):
    bone = rig.pose.bones[name]
    axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector((1, 0, 0))
    bone.rotation_quaternion = Quaternion(axis, math.radians(degrees))
for frame in range(1, 50):
    phase = 2 * math.pi * (frame - 1) / 48
    breath = (1 - math.cos(phase)) / 2
    rotate('Bone', 0.45 * math.sin(phase))
    rig.pose.bones['Bone'].location = rig.data.bones['Bone'].matrix_local.to_3x3().inverted() @ Vector((0, 0, 0.026 * breath))
    rotate('Bone.001', -0.65 * math.sin(phase - 0.35))
    rotate('Bone.003', 1.6 * math.sin(phase - 0.4))
    rotate('Bone.004', -1.2 * math.sin(phase - 0.7))
    rotate('Bone.005', 0.55 * math.sin(phase - 0.9))
    rotate('Bone.007', -1.3 * math.sin(phase - 0.3))
    rotate('Bone.008', 1.0 * math.sin(phase - 0.6))
    rotate('Bone.009', -0.5 * math.sin(phase - 0.9))
    bpy.context.view_layer.update()
    # Cancel parent motion on the pelvis: all leg vertices remain planted.
    rig.pose.bones['Bone.010'].matrix = rest_pelvis
    bpy.context.view_layer.update()
    for name in animated:
        bone = rig.pose.bones[name]
        for prop in ('location', 'rotation_quaternion', 'scale'):
            bone.keyframe_insert(data_path=prop, frame=frame, group=name)

# Separate orthographic sprite camera; original camera remains available.
cam_data = bpy.data.cameras.new('Hero_SpriteCamera')
cam = bpy.data.objects.new('Hero_SpriteCamera', cam_data)
scene.collection.objects.link(cam)
cam.location = (12, 0.12, 0)
cam.rotation_euler = Vector((-1, 0, 0)).to_track_quat('-Z', 'Y').to_euler()
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 5.6
scene.camera = cam
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
# Preserve original materials; flat copies retain painted colours in renders.
for obj in [o for o in scene.objects if o.type == 'MESH']:
    for slot in obj.material_slots:
        mat = slot.material.copy()
        mat.name = slot.material.name + '_Sprite'
        slot.material = mat
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        tex = next(n for n in nodes if n.type == 'TEX_IMAGE')
        output = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
        emission = nodes.new('ShaderNodeEmission')
        transparent = nodes.new('ShaderNodeBsdfTransparent')
        mix = nodes.new('ShaderNodeMixShader')
        links.new(tex.outputs['Color'], emission.inputs['Color'])
        links.new(tex.outputs['Alpha'], mix.inputs[0])
        links.new(transparent.outputs[0], mix.inputs[1])
        links.new(emission.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], output.inputs['Surface'])

# Validate loop closure and actual deformed leg vertices, not only bone positions.
def vertices(name):
    obj = bpy.data.objects[name].evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = obj.to_mesh()
    points = [obj.matrix_world @ v.co for v in mesh.vertices]
    obj.to_mesh_clear()
    return points
scene.frame_set(1)
reference = {n: vertices(n) for n in ('leg_left', 'leg_right')}
start = {b.name: b.matrix.copy() for b in rig.pose.bones}
max_drift = 0
for f in range(1, 50):
    scene.frame_set(f)
    for n, points in reference.items():
        max_drift = max(max_drift, max((a-b).length for a,b in zip(points, vertices(n))))
loop_error = max(abs(b.matrix[i][j]-start[b.name][i][j]) for b in rig.pose.bones for i in range(4) for j in range(4))
assert max_drift < 1e-5, max_drift
assert loop_error < 1e-5, loop_error
report = {'source':source,'action':action.name,'blender_fps':24,'playback_frames':[1,48],'closing_key':49,'export_fps':12,'export_frames':24,'frame_size':[512,512],'max_leg_vertex_drift':max_drift,'loop_matrix_error':loop_error,'textures_packed':True}
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
scene.frame_set(1)
scene.render.filepath = str(OUT/'frames'/'idle_')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Hero_Idle.blend'))
result = report

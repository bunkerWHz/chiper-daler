"""Run in the existing Hero_Idle scene. Adds actions and saves a separate blend."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Matrix

OUT = Path(r'C:/Users/bunkerWHz/Documents/chiper-daler/art/hero_movement')
OUT.mkdir(parents=True, exist_ok=True)
rig = bpy.data.objects['Armature']
scene = bpy.context.scene
bpy.data.objects['arm_left'].location.x = -2.672689437866211
bpy.data.objects['arm_right'].location.x = -0.42
assert 'Hero_Idle_Unarmed' in bpy.data.actions
assert not any(n in bpy.data.actions for n in ('Hero_Run_Unarmed','Hero_Jump_Unarmed','Hero_Fall_Unarmed'))
rest = {b.name:b.matrix_local.copy() for b in rig.data.bones}
legs = [('Bone.012','Bone.013','Bone.014'), ('Bone.016','Bone.017','Bone.018')]
specs = {'run':{'count':16,'loop':True}, 'jump':{'count':12,'loop':False}, 'fall':{'count':16,'loop':True}}

def direction_angle(v):
    return math.atan2(v.z, v.y)

def orient(name, head, direction=None, degrees=0):
    b = rig.data.bones[name]
    angle = math.radians(degrees) if direction is None else direction_angle(direction)-direction_angle(b.tail_local-b.head_local)
    matrix = Matrix.Rotation(angle, 4, 'X') @ rest[name]
    matrix.translation = head
    rig.pose.bones[name].matrix = matrix
    bpy.context.view_layer.update()

def upper(name, angle):
    # Absolute planar angle, measured from +Y toward +Z.
    head = rig.pose.bones[name].head.copy()
    orient(name, head, Vector((0,math.cos(math.radians(angle)),math.sin(math.radians(angle)))))

def solve_leg(index, target, foot_degrees=0):
    thigh, shin, foot = legs[index]
    hip = rig.pose.bones[thigh].head.copy()
    a, b = rig.data.bones[thigh].length, rig.data.bones[shin].length
    delta = target-hip
    distance = min(delta.length, a+b-0.008)
    unit = delta.normalized()
    along = (a*a-b*b+distance*distance)/(2*distance)
    height = math.sqrt(max(0,a*a-along*along))
    # Forward knee bend; no IK flips or longitudinal bone scaling.
    knee = hip+unit*along+Vector((0,-unit.z,unit.y))*height
    ankle = hip+unit*distance
    orient(thigh,hip,knee-hip)
    orient(shin,knee,ankle-knee)
    orient(foot,ankle,degrees=foot_degrees)

def base(z, lean):
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
        bone.rotation_mode = 'QUATERNION'
    root = rig.pose.bones['Bone']
    orient('Bone',rest['Bone'].translation+Vector((0,0,z)),degrees=lean)
    pelvis = rest['Bone.010'].copy()
    pelvis.translation += Vector((0,0,z))
    rig.pose.bones['Bone.010'].matrix = pelvis
    bpy.context.view_layer.update()
    orient('Bone.001',rig.pose.bones['Bone.001'].head.copy(),degrees=lean*0.25)

def hands(back_angle,front_angle,elbow=55):
    for shoulder, forearm, wrist, angle in [('Bone.003','Bone.004','Bone.005',back_angle),('Bone.007','Bone.008','Bone.009',front_angle)]:
        upper(shoulder,-90+angle)
        upper(forearm,-90+angle*0.55+elbow)
        orient(wrist,rig.pose.bones[wrist].head.copy(),degrees=angle*0.25-12)

def run_pose(t):
    base(-0.21+0.055*math.cos(4*math.pi*t),-8+1.2*math.cos(4*math.pi*t))
    for i,(thigh,shin,foot) in enumerate(legs):
        p=(t+0.5*i)%1
        hip=rig.pose.bones[thigh].head.copy()
        if p<0.42:
            u=p/0.42
            y=0.57-1.15*u
            z=-2.13
            tilt=-8*u
        else:
            u=(p-0.42)/0.58
            y=-0.58+1.15*(u*u*(3-2*u))
            z=-2.13+0.62*math.sin(math.pi*u)
            tilt=-25*math.sin(math.pi*u)
        target=Vector((hip.x,hip.y+y,z))
        solve_leg(i,target,tilt)
        if p<0.42:
            # Correct the contact ankle using the evaluated cutout, whose two
            # boot silhouettes have different offsets from their ankle bones.
            obj=bpy.data.objects['leg_right' if i==0 else 'leg_left']
            for correction in range(3):
                evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
                mesh=evaluated.to_mesh()
                bottom=min((evaluated.matrix_world @ v.co).z for v in mesh.vertices)
                evaluated.to_mesh_clear()
                target.z+=-2.49748-bottom
                solve_leg(i,target,tilt)
    swing=math.cos(2*math.pi*t)
    hands(-24*swing,24*swing,32)

def blend(a,b,t):
    return [x+(y-x)*t for x,y in zip(a,b)]

# z, lean, rear ankle Y/Z, front ankle Y/Z, rear arm, front arm, elbow bend
fall_start=[-0.05,-3,-0.48,-1.86,0.65,-2.03,-24,25,38]
jump_keys=[
    (0.0,[-0.12,-4,-0.64,-2.12,0.64,-2.12,-8,8,35]),
    (0.18,[-0.29,-9,-0.64,-2.12,0.64,-2.12,-32,-12,42]),
    (0.42,[0.02,-5,-0.58,-2.13,0.66,-1.86,20,45,48]),
    (0.70,[-0.03,-4,-0.58,-1.69,0.76,-1.80,6,40,45]),
    (1.0,fall_start),
]

def air_pose(values):
    z,lean,by,bz,fy,fz,ba,fa,elbow=values
    base(z,lean)
    for i,(y,h) in enumerate(((by,bz),(fy,fz))):
        solve_leg(i,Vector((0,y,h)),-8 if i==0 else 3)
    hands(ba,fa,elbow)

def jump_pose(t):
    for (ta,a),(tb,b) in zip(jump_keys,jump_keys[1:]):
        if t<=tb:
            u=(t-ta)/(tb-ta)
            air_pose(blend(a,b,u*u*(3-2*u)))
            return

def fall_pose(t):
    s=math.sin(2*math.pi*t)
    values=fall_start.copy()
    values[1]+=0.8*s
    values[3]+=0.025*s
    values[5]-=0.025*s
    values[6]+=2*s
    values[7]-=2*s
    air_pose(values)

report={'frame_size':[512,512],'fps':24,'source':bpy.data.filepath,'actions':{}}
for kind,spec in specs.items():
    action=bpy.data.actions.new('Hero_'+kind.title()+'_Unarmed')
    action.use_fake_user=True
    rig.animation_data.action=action
    count=spec['count']
    end=count+1 if spec['loop'] else count
    for frame in range(1,end+1):
        scene.frame_set(frame)
        t=(frame-1)/(count if spec['loop'] else count-1)
        {'run':run_pose,'jump':jump_pose,'fall':fall_pose}[kind](t)
        for bone in rig.pose.bones:
            for prop in ('location','rotation_quaternion','scale'):
                bone.keyframe_insert(data_path=prop,frame=frame,group=bone.name)
    scene.frame_set(1)
    first={b.name:b.matrix.copy() for b in rig.pose.bones}
    scene.frame_set(end)
    error=max(abs(b.matrix[i][j]-first[b.name][i][j]) for b in rig.pose.bones for i in range(4) for j in range(4))
    if spec['loop']:
        assert error<1e-5,(kind,error)
    report['actions'][kind]={'action':action.name,'count':count,'loop':spec['loop'],'loop_matrix_error':error if spec['loop'] else None,'seconds':count/24}
    action['playback_end']=count
    action['loop']=spec['loop']
    (OUT/kind/'frames').mkdir(parents=True,exist_ok=True)

# Exact jump-to-fall transition, independent of the game movement curve.
rig.animation_data.action=bpy.data.actions['Hero_Jump_Unarmed']
scene.frame_set(12)
last={b.name:b.matrix.copy() for b in rig.pose.bones}
rig.animation_data.action=bpy.data.actions['Hero_Fall_Unarmed']
scene.frame_set(1)
report['jump_to_fall_matrix_error']=max(abs(b.matrix[i][j]-last[b.name][i][j]) for b in rig.pose.bones for i in range(4) for j in range(4))
assert report['jump_to_fall_matrix_error']<1e-5
(OUT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
rig.animation_data.action=bpy.data.actions['Hero_Run_Unarmed']
scene.frame_start,scene.frame_end=1,16
scene.frame_preview_start,scene.frame_preview_end=1,16
scene.frame_set(1)
scene.render.filepath=str(OUT/'run'/'frames'/'run_')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Hero_Movement.blend'))
result=report

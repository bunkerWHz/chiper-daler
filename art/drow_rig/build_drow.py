"""Build a stylized reference-inspired Drow and a deforming FK game rig.
Run in an isolated Blender background process; never edits an existing scene.
"""
import bpy, math, json, os, bmesh
from mathutils import Vector
from pathlib import Path
OUT = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
def mat(name,color,metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=.78; p.inputs['Metallic'].default_value=metal
    return m
cloth=mat('Midnight violet cloth',(.047,.043,.067)); trim=mat('Worn pewter edging',(.17,.16,.18)); leather=mat('Warm charcoal leather',(.10,.067,.061)); skin=mat('Ash lavender skin',(.43,.40,.48)); hair=mat('Silver white hair',(.70,.72,.76)); dark=mat('Ink',(.009,.008,.015)); eye=mat('Ivory eyes',(.81,.82,.78)); metal=mat('Buckle',(.29,.24,.19),.65)
parts=[]; weights={}
def mesh(name,vs,fs,m,bone):
    data=bpy.data.meshes.new(name); data.from_pydata(vs,[],fs); data.update()
    o=bpy.data.objects.new(name,data); scene.collection.objects.link(o); o.data.materials.append(m)
    for p in data.polygons:p.use_smooth=True
    parts.append(o); weights[o.name]=bone
    return o
def uv(name,loc,scale,m,bone,segments=24,rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(m)
    for p in o.data.polygons:p.use_smooth=True
    parts.append(o); weights[o.name]=bone
    return o
def tube(name,rows,m,bone,n=16,axis='Z'):
    vs=[]
    for c,a,b in rows:
        for i in range(n):
            t=2*math.pi*i/n
            vs.append((c[0]+(0 if axis=='X' else a*math.cos(t)),c[1]+(a*math.cos(t) if axis=='X' else b*math.sin(t)),c[2]+(b*math.sin(t) if axis=='X' else 0)))
    fs=[]
    for j in range(len(rows)-1):
        for i in range(n): fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    fs.extend([tuple(reversed(range(n))),tuple((len(rows)-1)*n+i for i in range(n))])
    return mesh(name,vs,fs,m,bone)
def stroke(name,points,r,m,bone):
    c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.bevel_depth=r; c.bevel_resolution=2; c.resolution_u=12
    s=c.splines.new('BEZIER'); s.bezier_points.add(len(points)-1)
    for p,co in zip(s.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c);scene.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
    o=bpy.context.object;o.data.materials.append(m);parts.append(o);weights[o.name]=bone
    return o
def plate(name,points,m,bone,thick=.016):
    o=mesh(name,points,[tuple(range(len(points)))],m,bone)
    sol=o.modifiers.new('Cloth thickness','SOLIDIFY');sol.thickness=thick
    be=o.modifiers.new('Soft edges','BEVEL');be.width=.009;be.segments=2
    bpy.context.view_layer.objects.active=o
    for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
# Proportions derived from the front reference, height about 2.15 m.
tube('Tailored tunic',[((0,0,z),x,y) for z,x,y in [( .84,.18,.12),(.98,.185,.13),(1.10,.15,.105),(1.22,.17,.12),(1.34,.22,.135),(1.40,.25,.12),(1.44,.20,.10)]],cloth,'TORSO',24)
uv('Neck',(0,0,1.48),(.09,.085,.13),skin,'neck')
uv('Face',(0,-.012,1.77),(.235,.186,.30),skin,'head',32,24)
# Open hood, sewn from the facial opening to the back dome.
outline=[(-.25,1.45),(-.30,1.53),(-.31,1.66),(-.285,1.82),(-.25,1.98),(-.16,2.10),(0,2.18),(.16,2.10),(.25,1.98),(.285,1.82),(.31,1.66),(.30,1.53),(.25,1.45)]
vs=[]
for fac,y in [(1,-.10),(1.12,.01),(1.03,.17),(.78,.29),(.30,.34),(.02,.35)]:
    for x,z in outline:vs.append((x*fac,y,1.78+(z-1.78)*fac))
n=len(outline);fs=[(j*n+i,j*n+i+1,(j+1)*n+i+1,(j+1)*n+i) for j in range(5) for i in range(n-1)]
hood=mesh('Sculpted open hood',vs,fs,cloth,'head')
mod=hood.modifiers.new('Hood lining','SOLIDIFY');mod.thickness=.027;bpy.context.view_layer.objects.active=hood;bpy.ops.object.modifier_apply(modifier=mod.name)
stroke('Hood silver seam',[(x,-.118,z) for x,z in outline],.012,trim,'head')
stroke('Hood inner dark piping',[(x*.95,-.128,1.78+(z-1.78)*.95) for x,z in outline],.011,dark,'head')
for s,side in [(1,'L'),(-1,'R')]:
    # Elf ears, recessed inner ear, eyes and brows.
    plate('Pointed ear.'+side,[(s*.20,-.015,1.77),(s*.43,.015,1.90),(s*.33,-.04,1.74),(s*.25,-.07,1.69)],skin,'head',.045)
    plate('Ear inset.'+side,[(s*.26,-.048,1.77),(s*.385,-.013,1.864),(s*.315,-.066,1.765)],trim,'head',.009)
    uv('Eye outline.'+side,(s*.105,-.179,1.80),(.098,.030,.066),dark,'head')
    white=uv('Eye white.'+side,(s*.105,-.201,1.799),(.081,.018,.050),eye,'head')
    for v in white.data.vertices:
        if v.co.z>0:v.co.z=min(v.co.z,.026+s*v.co.x*.22)
    uv('Pupil.'+side,(s*.097,-.219,1.80),(.032,.011,.043),dark,'head',16,12)
    stroke('Angry brow.'+side,[(s*.029,-.205,1.846),(s*.11,-.203,1.878),(s*.191,-.160,1.881)],.015,dark,'head')
    # Long silver locks made of tapered volumetric sections.
    tube('Silver sidelock.'+side,[((s*x,y,z),a,b) for x,y,z,a,b in [(.20,-.09,1.97,.045,.027),(.223,-.155,1.83,.045,.03),(.218,-.168,1.66,.038,.027),(.22,-.175,1.49,.027,.020),(.24,-.18,1.36,.002,.002)]],hair,'head',12)
    stroke('Hair strand.'+side,[(s*.219,-.187,1.83),(s*.216,-.198,1.64),(s*.23,-.199,1.46)],.003,trim,'head')
    plate('Shoulder mantle.'+side,[(s*.02,-.133,1.32),(s*.27,-.13,1.39),(s*.40,-.035,1.48),(s*.24,.08,1.44),(s*.07,.04,1.48)],cloth,'chest')
    stroke('Mantle border.'+side,[(s*.02,-.149,1.32),(s*.26,-.145,1.39),(s*.39,-.05,1.48)],.014,trim,'chest')
    tube('Sleeve.'+side,[((s*x,0,1.40),a,b) for x,a,b in [(.20,.085,.083),(.30,.087,.078),(.43,.065,.065),(.50,.062,.063),(.55,.059,.06),(.65,.054,.055),(.71,.05,.055)]],cloth,'ARM.'+side,16,'X')
    tube('Bracer.'+side,[((s*x,-.002,1.40),a,b) for x,a,b in [(.62,.071,.080),(.65,.073,.079),(.77,.055,.06),(.79,.056,.06)]],leather,'forearm.'+side,16,'X')
    uv('Gloved palm.'+side,(s*.84,-.005,1.40),(.095,.052,.043),leather,'hand.'+side)
    for j in range(4):
        yy=-.044+j*.029;length=[.10,.125,.112,.085][j]
        tube('Finger%d.%s'%(j,side),[((s*.88,yy,1.4),.015,.016),((s*(.91+length*.5),yy,1.402),.014,.014),((s*(.91+length),yy,1.401),.009,.009)],leather,'finger%d.%s'%(j,side),8,'X')
    stroke('Thumb.'+side,[(s*.82,-.04,1.39),(s*.85,-.10,1.365),(s*.895,-.115,1.36)],.023,leather,'thumb.'+side)
    tube('Trouser.'+side,[((s*x,0,z),a,b) for x,z,a,b in [(.12,.91,.115,.104),(.145,.78,.103,.091),(.164,.64,.081,.078),(.171,.56,.073,.073),(.174,.51,.073,.07),(.176,.39,.07,.067),(.18,.24,.062,.065)]],cloth,'LEG.'+side)
    tube('Boot shaft.'+side,[((s*.18,.005,z),a,b) for z,a,b in [(.075,.082,.095),(.16,.075,.084),(.29,.083,.079),(.36,.089,.086)]],leather,'shin.'+side)
    tube('Folded boot cuff.'+side,[((s*.18,.005,z),a,b) for z,a,b in [(.30,.106,.095),(.32,.099,.092),(.405,.091,.087)]],leather,'shin.'+side)
    uv('Boot foot.'+side,(s*.19,-.071,.067),(.108,.177,.067),leather,'foot.'+side)
    uv('Boot sole.'+side,(s*.19,-.071,.027),(.11,.178,.023),dark,'foot.'+side)
    plate('Skirt side panel.'+side,[(s*.06,-.13,.96),(s*.18,-.086,.97),(s*.285,-.10,.72),(s*.24,-.157,.69),(s*.12,-.181,.73)],cloth,'skirt.'+side)
    stroke('Skirt hem.'+side,[(s*.12,-.191,.73),(s*.24,-.17,.69),(s*.285,-.112,.72)],.013,trim,'skirt.'+side)
uv('Small nose',(0,-.201,1.711),(.027,.046,.025),skin,'head',16,12)
stroke('Mouth', [(-.052,-.180,1.631),(0,-.199,1.641),(.052,-.180,1.631)],.005,dark,'head')
plate('Pointed front tabard',[(-.065,-.147,.98),(.065,-.147,.98),(.091,-.19,.728),(0,-.202,.645),(-.091,-.19,.728)],cloth,'tabard')
plate('Back skirt panel',[(-.18,.12,.96),(-.25,.15,.72),(0,.18,.68),(.25,.15,.72),(.18,.12,.96)],cloth,'pelvis')
stroke('Tabard edge',[(-.065,-.16,.96),(-.091,-.205,.728),(0,-.216,.645),(.091,-.205,.728),(.065,-.16,.96)],.012,trim,'tabard')
tube('Leather belt',[((0,0,z),.185,.14) for z in [.968,1.023]],leather,'pelvis',32)
bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=8,location=(0,-.154,.996),rotation=(math.pi/2,0,0),major_radius=.047,minor_radius=.012)
o=bpy.context.object;o.name='Round belt buckle';o.data.materials.append(metal);parts.append(o);weights[o.name]='pelvis'
# FK skeleton; hands have separate finger controls, cloth has auxiliary bones.
bpy.ops.object.select_all(action='DESELECT')
ad=bpy.data.armatures.new('Drow skeleton');rig=bpy.data.objects.new('Drow_Rig',ad);scene.collection.objects.link(rig);rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
def bone(name,h,t,parent=None):
    b=ad.edit_bones.new(name);b.head=h;b.tail=t
    if parent:b.parent=ad.edit_bones[parent]
bone('root',(0,0,0),(0,0,.18))
bone('pelvis',(0,0,.88),(0,0,1.04),'root');bone('spine',(0,0,1.04),(0,0,1.24),'pelvis');bone('chest',(0,0,1.24),(0,0,1.43),'spine');bone('neck',(0,0,1.43),(0,0,1.55),'chest');bone('head',(0,0,1.55),(0,0,1.99),'neck')
bone('tabard',(0,-.16,.97),(0,-.19,.68),'pelvis')
for s,side in [(1,'L'),(-1,'R')]:
    bone('clavicle.'+side,(0,0,1.4),(s*.24,0,1.4),'chest');bone('upper_arm.'+side,(s*.24,0,1.4),(s*.50,0,1.4),'clavicle.'+side);bone('forearm.'+side,(s*.50,0,1.4),(s*.78,0,1.4),'upper_arm.'+side);bone('hand.'+side,(s*.78,0,1.4),(s*.90,0,1.4),'forearm.'+side)
    for j in range(4):bone('finger%d.%s'%(j,side),(s*.89,-.044+j*.029,1.4),(s*1.025,-.044+j*.029,1.4),'hand.'+side)
    bone('thumb.'+side,(s*.82,-.04,1.39),(s*.895,-.115,1.36),'hand.'+side)
    bone('thigh.'+side,(s*.12,0,.91),(s*.17,-.009,.55),'pelvis');bone('shin.'+side,(s*.17,-.009,.55),(s*.18,0,.12),'thigh.'+side);bone('foot.'+side,(s*.18,0,.12),(s*.18,-.18,.06),'shin.'+side);bone('skirt.'+side,(s*.13,0,.96),(s*.24,-.03,.71),'pelvis')
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True;ad.display_type='STICK'
def blend(a,b,t):return {a:1-t,b:t}
def clamp(x):return max(0,min(1,x))
for o in parts:
    rule=weights[o.name]
    for v in o.data.vertices:
        p=o.matrix_world@v.co
        if rule=='TORSO':
            w=blend('pelvis','spine',clamp((p.z-1.0)/.14)) if p.z<1.17 else blend('spine','chest',clamp((p.z-1.17)/.18))
        elif rule.startswith('ARM.'):
            side=rule[-1];w=blend('upper_arm.'+side,'forearm.'+side,clamp((abs(p.x)-.445)/.11))
        elif rule.startswith('LEG.'):
            side=rule[-1];w=blend('shin.'+side,'thigh.'+side,clamp((p.z-.49)/.13))
        else:w={rule:1}
        for key,val in w.items():
            if val>0:
                g=o.vertex_groups.get(key) or o.vertex_groups.new(name=key);g.add([v.index],val,'REPLACE')
    mod=o.modifiers.new('Skin deformation','ARMATURE');mod.object=rig;o.parent=rig
    # UVs for later hand painting; current appearance uses material colors.
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(island_margin=.025);bpy.ops.object.mode_set(mode='OBJECT')
# Render studio is separate from exported character.
world=bpy.data.worlds.new('Studio world');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.065,.08,.12,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,size in [('Key',(-3,-4,5),450,4),('Fill',(4,-2,3),300,3),('Rim',(1,3,4),600,3)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;aim(o,(0,0,1.1))
camd=bpy.data.cameras.new('Preview');cam=bpy.data.objects.new('Preview',camd);scene.collection.objects.link(cam);cam.location=(2.6,-6,2.65);aim(cam,(0,0,1.1));camd.type='ORTHO';camd.ortho_scale=2.8;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
# Verify weights and an actual pose deformation, then restore T-pose.
report={'meshes':len(parts),'bones':len(ad.bones),'vertices':sum(len(o.data.vertices) for o in parts),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in parts),'unweighted':0,'bad_weight_sums':0,'pose_checks':{}}
for o in parts:
    for v in o.data.vertices:
        if not v.groups:report['unweighted']+=1
        if abs(sum(g.weight for g in v.groups)-1)>1e-5:report['bad_weight_sums']+=1
for bn,on in [('forearm.L','Sleeve.L'),('shin.L','Trouser.L'),('head','Face')]:
    o=bpy.data.objects[on];bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();base=[v.co.copy() for v in o.evaluated_get(dg).data.vertices]
    pb=rig.pose.bones[bn];pb.rotation_mode='XYZ';pb.rotation_euler.x=.6;bpy.context.view_layer.update();new=o.evaluated_get(bpy.context.evaluated_depsgraph_get());delta=max((a-v.co).length for a,v in zip(base,new.data.vertices));report['pose_checks'][bn]=delta;pb.rotation_euler=(0,0,0);bpy.context.view_layer.update()
assert report['unweighted']==0 and report['bad_weight_sums']==0 and all(v>.01 for v in report['pose_checks'].values()),report
assert not bpy.data.actions
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'Drow_Rig.glb'),export_format='GLB',use_selection=True,export_animations=False)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.shading.type='MATERIAL';area.spaces.active.region_3d.view_distance=3.3;area.spaces.active.region_3d.view_location=(0,0,1.1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Drow_Rig.blend'))
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
scene.render.filepath=str(OUT/'preview.png');bpy.ops.render.render(write_still=True)
cam.location=(0,-6,1.1);aim(cam,(0,0,1.1));scene.render.filepath=str(OUT/'front.png');bpy.ops.render.render(write_still=True)
rig.pose.bones['forearm.L'].rotation_euler.x=.8
rig.pose.bones['shin.L'].rotation_euler.x=.7
rig.pose.bones['upper_arm.R'].rotation_mode='XYZ';rig.pose.bones['upper_arm.R'].rotation_euler.x=-.45
scene.render.filepath=str(OUT/'pose_check.png');bpy.ops.render.render(write_still=True)
print('DROW_COMPLETE',json.dumps(report))

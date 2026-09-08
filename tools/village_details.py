"""Original Blender additions for Game2. Regenerate with blender --background --python tools/village_details.py.
Coordinates use Blender Z-up; GLB export converts them to Godot Y-up.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/village'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,color,rough=.8,metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    return m
M={name:mat(name,col) for name,col in {
    'tabby':(.51,.27,.105),'cream':(.81,.72,.51),'stripe':(.23,.115,.045),'nose':(.32,.16,.13),
    'eye':(.035,.045,.024),'iris':(.46,.57,.17),'wood':(.28,.155,.067),'wood_light':(.25,.20,.14),
    'iron':(.14,.16,.16),'duck_brown':(.36,.25,.15),'duck_cream':(.71,.68,.51),'duck_head':(.07,.24,.17),
    'orange':(.64,.35,.08),'blue':(.12,.23,.35),'soil':(.14,.095,.05),'leaf':(.18,.34,.10),'leaf_light':(.35,.46,.15),
    'carrot':(.66,.25,.065),'stone':(.39,.40,.34),'brass':(.55,.36,.105),'linen':(.66,.56,.37)
}.items()}
current=[]
def finish(ob,name,material):
    ob.name=name; ob.data.materials.append(M[material]); current.append(ob); return ob
def ell(name,p,s,material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=p)
    ob=bpy.context.object; ob.scale=s
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for f in ob.data.polygons:f.use_smooth=True
    return finish(ob,name,material)
def box(name,p,s,material,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p); ob=bpy.context.object; ob.scale=s
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Soft worn edges','BEVEL'); mod.width=bevel; mod.segments=2
        bpy.context.view_layer.objects.active=ob; bpy.ops.object.modifier_apply(modifier=mod.name)
        ob.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return finish(ob,name,material)
def rod(name,a,b,r,material,r2=None):
    v=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=r,radius2=r if r2 is None else r2,depth=v.length,location=(Vector(a)+Vector(b))/2)
    ob=bpy.context.object; ob.rotation_euler=v.to_track_quat('Z','Y').to_euler()
    for f in ob.data.polygons:f.use_smooth=True
    return finish(ob,name,material)
def curve(name,points,r,material):
    data=bpy.data.curves.new(name,'CURVE'); data.dimensions='3D'; data.bevel_depth=r; data.bevel_resolution=3
    spl=data.splines.new('BEZIER'); spl.bezier_points.add(len(points)-1)
    for b,p in zip(spl.bezier_points,points):b.co=p; b.handle_left_type='AUTO'; b.handle_right_type='AUTO'
    ob=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(ob); ob.data.materials.append(M[material]); current.append(ob);return ob
def export(name):
    col=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(col)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in current:
        for old in list(ob.users_collection):old.objects.unlink(ob)
        col.objects.link(ob);ob.select_set(True)
    bpy.context.view_layer.objects.active=current[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
    # Separate source collections remain editable; translated only in the library.
    offset=len(bpy.data.collections)*4
    for ob in current:
        if ob.parent is None: ob.location.x+=offset
    col['export_origin']=[offset,0,0]
    current.clear()

# Rounded tabby with separate animated extremities and modeled facial detail.
ell('CatBody',(0,0,.34),(.17,.33,.19),'tabby')
ell('ChestBib',(0,-.18,.34),(.135,.15,.145),'cream')
ell('CatHead',(0,-.30,.52),(.175,.15,.16),'tabby')
for side in [-1,1]:
    rod('PointedEar',(side*.12,-.29,.59),(side*.14,-.28,.77),.077,'tabby',0)
    rod('EarInner',(side*.12,-.337,.60),(side*.14,-.323,.72),.039,'nose',0)
    ell('Cheek',(side*.065,-.425,.465),(.066,.04,.04),'cream')
    ell('Eye',(side*.081,-.431,.545),(.038,.014,.032),'iris')
    ell('Pupil',(side*.081,-.444,.545),(.009,.008,.027),'eye')
    for j in range(3):
        curve('Whisker',[(side*.06,-.455,.477-j*.006),(side*.16,-.46,.48-j*.017),(side*.23,-.42,.50-j*.025)],.002,'cream')
ell('Nose',(0,-.469,.493),(.023,.017,.014),'nose')
for i,(x,y) in enumerate([(-.11,-.2),(.11,-.2),(-.11,.22),(.11,.22)]):
    ell('Leg'+str(i),(x,y,.155),(.054,.064,.15),'tabby')
    ell('Paw'+str(i),(x,y-.016,.045),(.065,.082,.045),'cream')
for y in [-.08,.05,.18]:
    curve('BackStripe',[(-.16,y,.37),(-.12,y,.48),(0,y,.523),(.12,y,.48),(.16,y,.37)],.019,'stripe')
curve('CatTail',[(0,.27,.40),(.07,.44,.56),(.1,.50,.8),(.04,.46,.9)],.042,'tabby')
# Put each limb's pivot at its shoulder/hip and carry its paw with it.
for i,(x,y) in enumerate([(-.11,-.2),(.11,-.2),(-.11,.22),(.11,.22)]):
    leg=bpy.data.objects['Leg'+str(i)]; paw=bpy.data.objects['Paw'+str(i)]
    pivot=Vector((x,y,.29)); shift=leg.location-pivot
    for vertex in leg.data.vertices: vertex.co+=shift
    leg.location=pivot
    world=paw.matrix_world.copy();paw.parent=leg;paw.matrix_world=world
# Curves used to rotate around the world origin, making the entire tail orbit.
tail=bpy.data.objects['CatTail'];pivot=Vector((0,.27,.4))
for spline in tail.data.splines:
    for point in spline.bezier_points:
        point.co-=pivot;point.handle_left-=pivot;point.handle_right-=pivot
tail.location=pivot
export('tabby_cat')

# Mallard, with individual wings for a greeting flap.
ell('DuckBody',(0,0,.19),(.20,.34,.18),'duck_cream')
ell('DuckBreast',(0,-.22,.25),(.155,.17,.17),'duck_brown')
ell('DuckNeck',(0,-.28,.38),(.09,.10,.20),'duck_head')
ell('DuckHead',(0,-.31,.52),(.12,.125,.12),'duck_head')
ell('NeckRing',(0,-.27,.32),(.095,.103,.026),'cream')
ell('Bill',(0,-.465,.49),(.085,.095,.029),'orange')
for side in [-1,1]:
    ell('DuckEye',(side*.096,-.373,.555),(.018,.014,.018),'eye')
    wing=ell('WingL' if side<0 else 'WingR',(side*.17,.045,.25),(.055,.25,.115),'duck_brown')
    ell('WingPatch',(side*.211,.06,.26),(.017,.12,.045),'blue')
    for j in range(4):
        ell('Feather',(side*.18,.10+j*.032,.265-j*.02),(.025,.13,.03),'duck_brown')
ell('Tail',(0,.30,.24),(.11,.16,.048),'duck_brown')
export('mallard')

# Small dock and a low feeding post, with irregular planks and rope.
for i in range(9):
    plank=box('DockPlank',((i-4)*.25,0,.20),(.225,1.82+(i%3)*.018,.11),'wood_light')
    plank.rotation_euler.z=math.sin(i*2.1)*.008
    for y in [-.70,.70]:ell('DockNail',((i-4)*.25,y,.258),(.015,.015,.004),'iron')
for x in [-.91,.91]:
    box('UnderBeam',(x,0,.09),(.13,2,.15),'wood')
    for y in [-.8,.8]:rod('DockPost',(x,y,-.35),(x,y,.66),.085,'wood')
curve('RopeRail',[(-.91,.8,.61),(0,.8,.47),(.91,.8,.61)],.019,'linen')
export('pond_dock')

# Garden bed; plant mesh is separate for the watered response.
box('RaisedSoil',(0,0,.14),(2.3,1.5,.25),'soil')
for x in [-1.22,1.22]:box('BedSide',(x,0,.18),(.10,1.7,.36),'wood')
for y in [-.81,.81]:box('BedEnd',(0,y,.18),(2.55,.10,.36),'wood')
for i in range(4):
    for j in range(3):
        x=-.8+i*.52;y=-.48+j*.45
        ell('CarrotTop',(x,y,.3),(.08,.075,.075),'carrot')
        for k in range(5):
            a=k*math.tau/5
            leaf=ell('GardenLeaf',(x+math.cos(a)*.11,y+math.sin(a)*.11,.43),(.035,.15,.04),'leaf_light' if k%2 else 'leaf')
            leaf.rotation_euler=(.35,0,a)
export('vegetable_bed')

# Watering can with spout and loop handle.
rod('CanBody',(0,0,.07),(0,0,.41),.18,'iron')
rod('Spout',(.13,0,.14),(.44,0,.4),.045,'iron',.03)
ell('Rose',(.46,0,.42),(.065,.065,.035),'iron')
curve('Handle',[(-.12,0,.38),(-.34,0,.4),(-.35,0,.11),(-.13,0,.12)],.025,'iron')
export('watering_can')

# Bell with a real flared open cup and timber support.
for x in [-.45,.45]:box('BellPost',(x,0,1.1),(.12,.16,2.2),'wood')
box('Lintel',(0,0,2.15),(1.2,.22,.18),'wood')
verts=[];faces=[]
for r,z in [(.10,1.99),(.13,1.88),(.20,1.68),(.29,1.58),(.27,1.55),(.18,1.69),(.11,1.88),(.08,1.97)]:
    for i in range(32):verts.append((math.cos(i*math.tau/32)*r,math.sin(i*math.tau/32)*r,z))
for row in range(7):
    for i in range(32):a=row*32+i;b=row*32+(i+1)%32;faces.append((a,b,b+32,a+32))
mesh=bpy.data.meshes.new('BellCup');mesh.from_pydata(verts,[],faces);ob=bpy.data.objects.new('BellCup',mesh);bpy.context.collection.objects.link(ob);finish(ob,'BellCup','brass')
rod('Clapper',(0,0,1.94),(0,0,1.57),.025,'iron')
ell('ClapperEnd',(0,0,1.57),(.05,.05,.05),'iron')
curve('BellRope',[(0,0,1.58),(.04,-.03,1.05),(.02,-.02,.52)],.017,'linen')
export('village_bell')

ROOT.joinpath('art/village').mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/village/village_details.blend'))
print('VILLAGE ASSETS READY')

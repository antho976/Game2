"""Reproducible review assets: one rigged local defender, mine vignette and village gate."""
import bpy, math, random
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/dungeon/first_portal'
random.seed(903)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/village/player_refined.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
rig.animation_data.action=None
# Keep the standard rig and authored locomotion. Replace exposed civilian details.
for track in rig.animation_data.nla_tracks: track.mute=True
for bone in rig.pose.bones:
 bone.rotation_mode='QUATERNION';bone.rotation_quaternion=(1,0,0,0);bone.location=(0,0,0);bone.scale=(1,1,1)
for o in list(bpy.context.scene.objects):
 if o.type=='MESH' and (not any(m.type=='ARMATURE' for m in o.modifiers) or o.name.startswith(('Face','Eye','Brow','Nose','SweptHair','FittedVest','SplitCollar','VestFastening','Buckle'))):bpy.data.objects.remove(o,do_unlink=True)
M={};groups={};active='warden';skin=None

def mat(name,color,metal=0,rough=.8,texture=False,emission=0):
 m=bpy.data.materials.new('Mine_'+name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
 p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if texture:
  n=256;y,x=np.mgrid[:n,:n];rng=np.random.default_rng(482);noise=rng.random((n,n));v=.77+.20*noise+.10*np.sin(x*.071)*np.cos(y*.092)
  if name in ['iron','copper']:v+=np.where((x%47<1)&(noise>.3),.18,0)
  if name=='cloth':v+=.055*((x%3==0)+(y%3==0))
  pixels=np.ones((n,n,4),dtype=np.float32);pixels[:,:,:3]=np.clip(v[:,:,None]*np.array(color)[None,None,:],0,1)
  image=bpy.data.images.new('mine_'+name,width=n,height=n);image.pixels.foreach_set(pixels.ravel());image.pack()
  node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;m.node_tree.links.new(node.outputs['Color'],p.inputs['Base Color'])
 if emission:
  p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 M[name]=m
mat('iron',(.31,.35,.34),.7,.51,True);mat('copper',(.41,.26,.13),.62,.65,True);mat('edge',(.49,.51,.46),.7,.45)
mat('cloth',(.31,.25,.18),0,.94,True);mat('leather',(.13,.10,.075),0,.93,True);mat('dark',(.025,.035,.035))
mat('stone',(.35,.39,.35),0,.91,True);mat('stone_dark',(.21,.26,.25),0,.95,True);mat('wood',(.25,.16,.09),0,.97,True)
mat('dust',(.30,.28,.20),0,.98,True);mat('glow',(.19,.58,.50),.2,.32,False,1.3);mat('crystal',(.12,.32,.30),.3,.4)
mat('amber',(.94,.51,.15),0,.5,False,2);mat('wax',(.68,.60,.40));mat('rope',(.38,.31,.19),0,.95)
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  name=o.name
  o.data.materials.clear();o.data.materials.append(M['cloth' if name.startswith(('Tailored','Sleeve')) else 'leather'])
groups['warden']=[o for o in bpy.context.scene.objects if o.type in ['MESH','ARMATURE']]
def cv(p):return (p[0],-p[2],p[1])
def register(o,name,m):
 o.name=name;o.data.materials.append(M[m]);groups.setdefault(active,[]).append(o)
 if skin:
  group=o.vertex_groups.new(name=skin);group.add(list(range(len(o.data.vertices))),1,'REPLACE')
  mod=o.modifiers.new('Warden skin','ARMATURE');mod.object=rig;o.parent=rig
 return o
def box(name,p,s,m,bevel=.012):
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  b=o.modifiers.new('Edge wear','BEVEL');b.width=bevel;b.segments=2;bpy.ops.object.modifier_apply(modifier=b.name)
 return register(o,name,m)
def mesh(name,verts,faces,m):
 data=bpy.data.meshes.new(name);data.from_pydata([cv(v) for v in verts],[],faces);data.update();o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);return register(o,name,m)
def rings(name,rows,m,n=12):
 vs=[]
 for x,y,z,rx,rz in rows:
  for i in range(n):a=i*math.tau/n;vs.append((x+rx*math.cos(a),y,z+rz*math.sin(a)))
 fs=[tuple(range(n-1,-1,-1))]
 for j in range(len(rows)-1):
  for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
 fs.append(tuple((len(rows)-1)*n+i for i in range(n)))
 return mesh(name,vs,fs,m)
def rod(name,a,b,r,m):
 v=Vector(cv(b))-Vector(cv(a));bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=r,depth=v.length,location=(Vector(cv(a))+Vector(cv(b)))/2)
 o=bpy.context.object;o.rotation_euler=v.to_track_quat('Z','Y').to_euler();return register(o,name,m)
def rock(p,s,m='stone_dark',detail=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=detail,radius=1,location=cv(p));o=bpy.context.object
 for v in o.data.vertices:v.co*=random.uniform(.86,1.12)
 o.scale=(s[0],s[2],s[1]);o.rotation_euler.z=random.random()*3;return register(o,'Fractured bedrock',m)
def crystal(p,height,r=.12):
 x,y,z=p
 return rings('Living seam',[(x,y,z,r,r*.8),(x+.04,y+height*.75,z,r*.77,r*.65),(x+.09,y+height,z+.035,.003,.003)],'glow' if height<.4 else 'crystal',5)
# Warden: articulated layers and a sealed miner's sallet, avoiding a civilian face.
skin='Chest'
rings('Quilted collar',[(0,1.42,0,.14,.12),(0,1.56,0,.105,.09)],'leather')
rings('Breastplate',[(0,1.05,0,.185,.147),(0,1.18,.012,.205,.172),(0,1.38,.0,.25,.17),(0,1.46,0,.20,.135)],'iron')
for side in [-1,1]:
 rod('Breastplate rib',(side*.20,1.13,.12),(side*.06,1.41,.17),.016,'copper')
 for y in [1.13,1.28,1.41]:rock((side*.18,y,.155),(.012,.012,.009),'edge')
box('Warden chest badge',(-.12,1.33,.182),(.09,.12,.018),'copper')
for i in range(3):box('Badge tally',(-.14+i*.022,1.33,.195),(.005,.06,.004),'dark',0)
rod('Shoulder strap',(-.20,1.43,.13),(.18,1.10,.17),.029,'leather')
# Half-apron and independently weighted tassets.
skin='Hips'
for i in range(3):rings('Fauld',[(0,1.035-i*.055,0,.199+i*.008,.158),(0,1.075-i*.055,0,.19+i*.008,.15)],'iron')
for side in [-1,1]:
 skin='Thigh.'+('L' if side<0 else 'R')
 mesh('Split work apron',[(side*.035,.95,.16),(side*.22,.93,.12),(side*.23,.64,.14),(side*.06,.61,.19)],[(0,1,2,3),(3,2,1,0)],'cloth')
 mesh('Shaped tasset',[(side*.05,.92,.18),(side*.21,.92,.145),(side*.235,.77,.155),(side*.185,.65,.17),(side*.06,.68,.19),(side*.13,.81,.215)],[(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5)],'iron')
 for y in [.71,.86]:rock((side*.14,y,.205),(.012,.012,.010),'copper')
 skin='UpperArm.'+('L' if side<0 else 'R')
 for i in range(3 if side<0 else 2):
  rings('Layered shoulder',[(side*(.25+i*.032),1.535-i*.086,0,.03,.05),(side*(.27+i*.032),1.48-i*.086,0,.127-i*.014,.145-i*.012),(side*(.29+i*.032),1.405-i*.086,0,.134-i*.017,.156-i*.016),(side*(.30+i*.032),1.37-i*.086,0,.105-i*.015,.13-i*.012)],'iron' if side<0 else 'leather')
 skin='Forearm.'+('L' if side<0 else 'R')
 rings('Riveted bracer',[(side*.347,1.17,0,.073,.079),(side*.37,1.00,.017,.071,.071)],'iron')
 for y in [1.025,1.145]:rings('Bracer strap',[(side*.36,y,.01,.078,.08),(side*.36,y+.025,.01,.078,.08)],'copper')
 skin='Hand.'+('L' if side<0 else 'R')
 box('Gauntlet knuckles',(side*.38,.92,.069),(.087,.09,.028),'iron')
 skin='Shin.'+('L' if side<0 else 'R')
 rings('Shin plates',[(side*.135,.19,.0,.083,.09),(side*.135,.43,.0,.09,.09),(side*.135,.52,.012,.09,.106)],'iron')
 box('Shin ridge',(side*.135,.36,.102),(.03,.27,.029),'copper')
 skin='Foot.'+('L' if side<0 else 'R')
 for j in range(3):box('Boot toe plate',(side*.135,.12-j*.015,.075+j*.036),(.18,.035,.072),'iron')
# Helmet with brow ridge, recessed sight slit, filter and crown lamp.
skin='Head'
rings('Helmet hood',[(0,1.53,-.012,.115,.104),(0,1.67,-.025,.146,.138),(0,1.82,-.023,.137,.124),(0,1.90,-.018,.07,.068),(0,1.925,-.018,.015,.02)],'iron',14)
box('Recessed sight slit',(0,1.737,.108),(.211,.044,.047),'dark',.007)
box('Brow visor',(0,1.78,.118),(.248,.031,.064),'edge')
box('Breathing faceplate',(0,1.64,.118),(.175,.13,.062),'copper')
for x in [-.054,-.018,.018,.054]:box('Filter opening',(x,1.64,.154),(.010,.061,.006),'dark',.002)
for side in [-1,1]:
 rod('Temple hinge',(side*.133,1.71,.015),(side*.15,1.71,.015),.025,'copper')
box('Crown lamp housing',(0,1.857,.084),(.082,.075,.061),'copper')
box('Miner lamp glass',(0,1.857,.119),(.054,.046,.012),'amber')
# Rear breathing pack and belt relic, with no extra shoulder silhouette noise.
skin='Chest'
box('Filter pack',(0,1.28,-.19),(.27,.34,.15),'leather')
for x in [-.08,.08]:rod('Filter cylinder',(x,1.12,-.29),(x,1.40,-.29),.046,'copper')
skin='Hips'
box('Sealed harvest vial',(.235,.99,.015),(.09,.18,.095),'copper')
box('Vial window',(.235,1.005,.068),(.04,.105,.007),'glow')
skin=None
# Standalone long mining blade; same origin/grip convention as the existing greatswords.
active='mining_blade'
rings('Cutting blade',[(0,.16,0,.115,.035),(0,1.26,0,.14,.026),(.028,1.47,0,.095,.016),(.095,1.54,0,.013,.005)],'iron',4)
box('Sharpened edge',(-.105,.80,.016),(.015,1.2,.019),'edge')
for y in [.43,.69,.95,1.2]:box('Blade forge scar',(.063,y,.027),(.034,.012,.006),'dark',.001)
box('Crossguard',(0,.13,0),(.46,.065,.082),'copper')
rod('Wrapped handle',(0,-.25,0),(0,.1,0),.035,'leather')
for i in range(9):rings('Handle binding',[(0,-.235+i*.037,0,.038,.039),(0,-.224+i*.037,0,.038,.039)],'rope',8)
box('Pommel',(0,-.29,0),(.09,.075,.072),'copper')
# Environment sample. Open front for camera review; architecture remains modular.
active='mine_sample'
box('Excavated floor',(0,-.20,0),(14,.4,17),'stone_dark',.12)
for z in range(-7,8):
 for x in range(-6,7):
  if random.random()<.29:continue
  rock((x+random.uniform(-.2,.2),-.015,z+random.uniform(-.2,.2)),(.6,.10,.59),'dust',1)
for side in [-1,1]:
 for i in range(7):
  z=-6+i*2
  rock((side*6.5,1.8,z),(1.2,2.5,1.4),detail=2)
  for row in range(4):
   if random.random()<.23:continue
   box('Buried settlement course',(side*5.8,.28+row*.53,z+(.2 if row%2 else 0)),(.58,.50,1.5),'stone',.055)
for i in range(7):
 if i in [3,4]:continue
 rock((-6+i*2,2,-8),(1.3,2.8,1.2),detail=2)
# Old gate embedded into the mine's far end.
for side in [-1,1]:
 for row in range(5):box('Ancient gate pier',(1+side*1.4,.33+row*.62,-7.6),(.8,.60,.9),'stone',.05)
for i in range(11):
 a=i*math.pi/11+.013;b=(i+1)*math.pi/11-.013;vs=[]
 for depth in [-8.04,-7.16]:
  for radius,angle in [(1.04,a),(1.84,a),(1.84,b),(1.04,b)]:vs.append((1+math.cos(angle)*radius,2.8+math.sin(angle)*radius,depth))
 mesh('Buried gate arch',vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'stone')
box('Dark tunnel beyond',(1,2,-8.35),(2.25,4,.1),'dark')
# Timber frames, braces and visible iron shoes.
for z in [-4,1.8]:
 for side in [-1,1]:
  box('Mine support',(side*4.5,1.85,z),(.3,3.7,.35),'wood',.035)
  box('Support shoe',(side*4.5,.19,z),(.4,.38,.43),'iron')
  rod('Diagonal brace',(side*4.5,2.8,z),(side*3.65,3.65,z),.13,'wood')
 box('Crossbeam',(0,3.65,z),(9.4,.33,.38),'wood',.04)
 for x in [-4.45,4.45]:box('Brace iron band',(x,3.64,z),(.43,.39,.44),'iron')
# Narrow gauge track changes direction toward the old settlement arch.
for i in range(17):
 z=-6.5+i*.72;x=.7*math.sin(z*.17)
 box('Rail sleeper',(x,.045,z),(1.45,.12,.16),'wood')
 for side in [-1,1]:box('Rail',(x+side*.46,.13,z),(.045,.095,.76),'iron',.006)
# Abandoned cart, boarded rim, metal tyres.
for z in [1.0,2.1]:
 for side in [-1,1]:rod('Cart wheel',(2.4+side*.60,.34,z),(2.4+side*.70,.34,z),.29,'iron')
box('Cart floor',(2.4,.58,1.55),(1.2,.13,1.7),'wood')
for side in [-1,1]:
 for row in range(4):box('Cart plank',(2.4+side*.61,.72+row*.15,1.55),(.09,.14,1.7),'wood')
for z in [.72,2.37]:
 for row in range(4):box('Cart end',(2.4,.72+row*.15,z),(1.2,.14,.08),'wood')
for i in range(15):rock((2.4+random.uniform(-.4,.4),.8+random.random()*.3,1.55+random.uniform(-.6,.6)),(.24,.18,.23))
# Life-bearing seam guarded by the local settlement: mineral growth and old extraction wounds.
for i in range(24):
 p=(random.uniform(-5.6,-4.4),random.uniform(.0,.28),random.uniform(-4.3,-1.6));crystal(p,random.uniform(.2,1.35),random.uniform(.08,.21))
for i in range(6):
 rod('Mineral root',(-5.7,random.uniform(.5,2.8),-2.5+i*.14),(-4.9,.15,-3.5+i*.3),.034,'glow')
for i in range(7):
 box('Empty extraction scar',(5.14,.7+i*.23,-3.8+random.uniform(-.3,.3)),(.025,.1,.48),'dark')
for p in [(4.8,0,4),(-4.9,0,3.8),(3.9,0,-5.6)]:
 for j in range(5):
  x,y,z=p;rod('Pale root',(x+j*.05,y,z),(x+.13*math.sin(j),y+.4+j*.09,z+.22),.025,'wax')
# Lamps and small remnants of daily life.
for x,z in [(-4.5,1.7),(4.5,-4.1)]:
 box('Lamp cage',(x,2.55,z),(.23,.35,.23),'iron')
 box('Lamp light',(x,2.55,z+.13),(.15,.24,.015),'amber')
for i in range(3):
 box('Supply crate',(-3.8+i*.65,.35,5.6),(.6,.7,.6),'wood',.03)
 for yy in [.15,.52]:box('Crate iron strap',(-3.8+i*.65,yy,5.92),(.63,.05,.025),'iron')
box('Abandoned cloth',(-2.3,.045,-5.8),(1.1,.04,.65),'cloth')
# Maintained village portal: stone voussoirs, repaired iron joints, lamps and offerings.
active='portal_frame'
box('Threshold',(0,.08,.2),(5.5,.16,2.6),'stone',.06)
for side in [-1,1]:
 for row in range(4):box('Portal pier',(side*1.85,.29+row*.55,0),(.77,.53,.88),'stone',.045)
 box('Portal plinth',(side*1.85,.14,0),(1.05,.28,1.1),'stone',.04)
 box('Pier capital',(side*1.85,2.18,0),(.94,.24,1.03),'stone',.04)
 for y in [.75,1.75]:box('Repair strap',(side*1.85,y,.455),(.8,.08,.025),'iron')
 for y in [.55,1.35,1.9]:
  box('Ceremonial inset',(side*1.85,y,.47),(.20,.24,.025),'copper')
  rod('Etched tally',(side*1.90,y-.06,.49),(side*1.80,y+.06,.49),.009,'dark')
for i in range(13):
 a=i*math.pi/13+.012;b=(i+1)*math.pi/13-.012;vs=[]
 for depth in [-.46,.46]:
  for radius,angle in [(1.46,a),(2.25,a),(2.25,b),(1.46,b)]:vs.append((math.cos(angle)*radius,2.12+math.sin(angle)*radius,depth))
 mesh('Arch voussoir',vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'stone')
for side in [-1,1]:
 x=side*2.5
 box('Lamp pedestal',(x,.45,.65),(.38,.9,.38),'stone',.04)
 box('Gate lantern',(x,1.07,.65),(.28,.34,.28),'iron')
 box('Gate lantern glass',(x,1.07,.80),(.19,.23,.014),'amber')
 for i in range(3):
  rod('Votive candle',(side*(2.1+i*.10),.18,1.04),(side*(2.1+i*.10),.35+i*.035,1.04),.028,'wax')
  rock((side*(2.1+i*.10),.36+i*.035,1.04),(.017,.035,.017),'amber')
# Save the editable library before batching. Each collection uses local coordinates.
for name,objects in groups.items():
 collection=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(collection)
 for o in objects:
  for old in list(o.users_collection):old.objects.unlink(o)
  collection.objects.link(o)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/dungeon/first_portal.blend'))
# Batch rigid assets by material. Skin groups remain on the warden's mesh batches.
for name,objects in groups.items():
 buckets={}
 for o in objects:
  if o.type=='MESH':buckets.setdefault(o.data.materials[0],[]).append(o)
 exports=[]
 for material,items in buckets.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in items:o.select_set(True)
  bpy.context.view_layer.objects.active=items[0];bpy.ops.object.join();exports.append(items[0])
 bpy.ops.object.select_all(action='DESELECT')
 for o in exports:o.select_set(True)
 if name=='warden':
  rig.select_set(True)
  for track in rig.animation_data.nla_tracks:track.mute=False
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=name=='warden',export_animation_mode='NLA_TRACKS' if name=='warden' else 'ACTIONS')
 if name=='warden':
  for track in rig.animation_data.nla_tracks:track.mute=True
print('FIRST_PORTAL_ASSETS_EXPORTED')

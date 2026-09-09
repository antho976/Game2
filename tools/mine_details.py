"""Authored ore-screening machinery and individually chipped paving for the mine."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/dungeon/first_portal/modules'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/dungeon/first_portal.blend'))
M={k:bpy.data.materials['Mine_'+k] for k in ['stone','stone_dark','wood','iron','copper','rope','dust']}
for obj in list(bpy.data.objects): bpy.data.objects.remove(obj,do_unlink=True)
random.seed(441)
groups={};active='sorting_machine'
def cv(p): return Vector((p[0],-p[2],p[1]))
def register(o,name,mat):
 o.name=name;o.data.materials.append(M[mat]);groups.setdefault(active,[]).append(o);return o
def box(name,p,s,mat='wood',bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1])
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 b=o.modifiers.new('Chipped edges','BEVEL');b.width=bevel;b.segments=2;bpy.ops.object.modifier_apply(modifier=b.name)
 return register(o,name,mat)
def rod(name,a,b,r,mat='iron',vertices=10):
 v=cv(b)-cv(a);bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=v.length,location=(cv(a)+cv(b))/2)
 o=bpy.context.object;o.rotation_euler=v.to_track_quat('Z','Y').to_euler();return register(o,name,mat)
def rock(p,s):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=cv(p));o=bpy.context.object
 for v in o.data.vertices:v.co*=random.uniform(.7,1.13)
 o.scale=(s[0],s[2],s[1]);return register(o,'Unsorted ore','stone_dark')
def mesh(name,verts,faces,mat):
 d=bpy.data.meshes.new(name);d.from_pydata([cv(v) for v in verts],[],faces);d.update()
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return register(o,name,mat)
# Feet, bracing and metal collars make the load path visible all the way to the floor.
for x in [-1.7,1.7]:
 for z in [-1.2,1.1]:
  box('Dressed footing',(x,.14,z),(.65,.28,.65),'stone',.065)
  box('Load bearing leg',(x,1.03,z),(.28,1.8,.30))
  for y in [.34,1.63]:box('Iron collar',(x,y,z),(.31,.10,.33),'iron',.009)
  for dz in [-.10,.10]:rod('Peg',(x-.165,1.65,z+dz),(x+.165,1.65,z+dz),.028,'copper')
 for y in [.6,1.55]:box('Side stringer',(x,y,-.05),(.20,.18,2.6))
 rod('Diagonal brace',(x,.4,1.1),(x,1.5,-1.15),.09,'wood')
for z in [-1.2,1.1]:box('Cross brace',(0,.57,z),(3.7,.19,.19))
# A visibly tilted screening deck, with an open iron grating and retained ore.
for i in range(22):
 z=-1.2+i*.11;y=1.82-z*.19
 if i in [7,8]:continue
 rod('Screen bar',(-1.5,y,z),(1.5,y,z),.028)
for x in [-1.57,-.52,.52,1.57]:rod('Screen rail',(x,2.05,-1.3),(x,1.59,1.15),.065,'iron')
for x in [-1.67,1.67]:
 rod('Screen rim',(x,2.17,-1.32),(x,1.67,1.30),.085,'wood')
for row in range(3):
 box('Loading hopper back',(0,2.10+row*.17,-1.32),(3.5,.15,.11))
 for side in [-1,1]:box('Hopper cheek',(side*1.67,2.10+row*.17,-.92),(.12,.15,.84))
for i in range(33):
 z=random.uniform(-1.12,.82);x=random.uniform(-1.35,1.35);r=random.uniform(.09,.24)
 rock((x,1.85-z*.19+r*.45,z),(r,r*.7,r*.8))
# Two sorting chutes lead down toward the collection point, with supporting trestles.
for x in [-.9,.9]:
 for side in [-1,1]:rod('Chute edge',(x+side*.37,1.72,1.1),(x+side*.37,1.43,2.65),.065,'wood')
 for i in range(12):
  z=1.15+i*.125;y=1.63-(z-1.15)*.16
  box('Chute slat',(x,y,z),(.75,.10,.14))
 box('Chute foot',(x,.64,2.55),(.16,1.28,.17))
 rod('Chute brace',(x,.15,2.55),(x,1.36,2.05),.05,'iron')
 for i in range(4):rock((x+random.uniform(-.22,.22),1.73-i*.05,1.35+i*.30),(.1,.06,.08))
# Large external eccentric wheel: rim, spokes, axle, pins and a grounded drive support.
for i in range(24):
 a=i*math.tau/24;b=(i+1)*math.tau/24
 rod('Flywheel rim',(2.08,1.28+math.cos(a)*.73,math.sin(a)*.73),(2.08,1.28+math.cos(b)*.73,math.sin(b)*.73),.061,'iron')
 if i%3==0:rod('Flywheel spoke',(2.08,1.28,0),(2.08,1.28+math.cos(a)*.71,math.sin(a)*.71),.037,'copper')
rod('Drive axle',(1.55,1.28,0),(2.32,1.28,0),.12)
box('Bearing stand',(2.14,.53,0),(.26,1.06,.36))
box('Bearing footing',(2.14,.10,0),(.62,.20,.68),'stone')
rod('Crank handle',(2.25,1.55,.40),(2.65,1.55,.40),.06,'wood')
box('Maker plate',(-.2,1.69,1.19),(.48,.19,.04),'copper')
for i in range(5):box('Stamped tally',(-.37+i*.075,1.69,1.214),(.019,.1,.012),'iron',.002)
# A half-buried retaining structure is separate from the active machine.
active='retaining_remnant'
for row in range(5):
 for i in range(8):
  if row>1 and (i<row-1 or i>8-row):continue
  x=-3.2+i*.82+(.2 if row%2 else 0)
  box('Retaining course',(x,.24+row*.46,0),(.79,.44,.72),'stone',random.uniform(.025,.075))
for x in [-2.4,1.5]:
 box('Buried brace',(x,.6,.52),(.23,1.2,.26))
 rod('Brace bolt',(x-.16,.65,.51),(x+.16,.65,.51),.038,'iron')
for i in range(26):
 x=random.uniform(-3.7,3.5);z=random.uniform(.4,2.1)
 if random.random()<.55:
  o=box('Fallen masonry',(x,.12,z),(.6,.25,.46),'stone',.07);o.rotation_euler=(random.uniform(-.12,.12),random.uniform(-.15,.15),random.uniform(-1,1))
 else:rock((x,.06,z),(.35,.20,.28))
# Chipped eight-sided slabs with uneven, inset upper edges and distinct silhouettes.
for i in range(10):
 active='paver_%02d'%i
 polygon=[(-.50,-.20),(-.40,-.30),(.39,-.30),(.50,-.19),(.50,.21),(.37,.30),(-.39,.30),(-.50,.17)]
 verts=[]
 for y,inset in [(-.08,0),(.065,.04)]:
  for x,z in polygon:
   verts.append((x*(1-inset)+random.uniform(-.045,.045),y+random.uniform(-.014,.014),z*(1-inset)+random.uniform(-.025,.025)))
 faces=[tuple(range(7,-1,-1)),tuple(range(8,16))]
 for j in range(8):faces.append((j,(j+1)%8,(j+1)%8+8,j+8))
 mesh('Fractured flagstone',verts,[tuple(reversed(face)) for face in faces],'stone')
for name,objects in groups.items():
 c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c)
 for o in objects:
  for old in list(o.users_collection):old.objects.unlink(o)
  c.objects.link(o)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/dungeon/mine_details.blend'))
for name,objects in groups.items():
 buckets={}
 for o in objects:buckets.setdefault(o.data.materials[0],[]).append(o)
 result=[]
 for items in buckets.values():
  bpy.ops.object.select_all(action='DESELECT')
  for o in items:o.select_set(True)
  bpy.context.view_layer.objects.active=items[0]
  if len(items)>1:bpy.ops.object.join()
  result.append(items[0])
 bpy.ops.object.select_all(action='DESELECT')
 for o in result:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
print('MINE_DETAILS_EXPORTED')

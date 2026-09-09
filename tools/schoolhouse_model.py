"""Build the walkable schoolhouse in Godot-local coordinates; export a batched GLB."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(2409)
materials={};objects=[]
def mat(name,color,texture=None):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.85
 if texture:
  n=256;rng=np.random.default_rng(42);y,x=np.mgrid[:n,:n];noise=rng.random((n,n))
  if texture=='wood':v=.86+.10*np.sin(x*.29+np.sin(y*.022)*2)+.05*np.sin(x*1.7)+noise*.065
  else:v=.90+noise*.12+.035*np.sin(x*.10)*np.sin(y*.14)
  pixels=np.ones((n,n,4),dtype=np.float32);pixels[:,:,:3]=np.clip(v[:,:,None]*np.array(color)[None,None,:],0,1)
  image=bpy.data.images.new(name+' texture',width=n,height=n);image.pixels.foreach_set(pixels.ravel());image.pack()
  node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;m.node_tree.links.new(node.outputs['Color'],p.inputs['Base Color'])
 materials[name]=m;return name
wood=mat('Aged oak',(.28,.16,.080),'wood');lightwood=mat('Worn floorboards',(.39,.27,.15),'wood');dark=mat('Dark endgrain',(.13,.085,.048),'wood')
plaster=mat('Limewash',(.69,.65,.49),'plaster');stone=mat('Foundation limestone',(.38,.40,.34),'plaster');iron=mat('Forged iron',(.12,.14,.14));paper=mat('Old paper',(.77,.72,.56),'plaster');ink=mat('Ink',(.19,.18,.14));board=mat('Slate board',(.075,.12,.10),'plaster');cover=mat('Book cloth',(.22,.29,.25),'plaster')
roofs=[mat('Slate '+str(i),(.24+i*.012,.29+i*.012,.30+i*.012),'plaster') for i in range(5)]
with bpy.data.libraries.load(str(ROOT/'art/hub/hub_library.blend'),link=False) as (src,dst):
 dst.materials=[n for n in ['oak','dark_oak','plaster','stone','slate'] if n in src.materials]
for key,source in [(wood,'oak'),(dark,'dark_oak'),(plaster,'plaster'),(stone,'stone')]+[(roof,'slate') for roof in roofs]:
 if bpy.data.materials.get(source): materials[key]=bpy.data.materials[source]
def cv(p):return (p[0],-p[2],p[1])
def box(name,p,s,m,bevel=.015,tilt=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.name=name;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  b=o.modifiers.new('Worn edges','BEVEL');b.width=bevel;b.segments=2;bpy.ops.object.modifier_apply(modifier=b.name)
 o.rotation_euler.y=-tilt;o.data.materials.append(materials[m]);objects.append(o);return o
def beam(name,a,b,w,m=wood):
 v=Vector(cv(b))-Vector(cv(a));o=box(name,tuple((a[i]+b[i])/2 for i in range(3)),(w,v.length,w),m,.014);o.rotation_euler=v.to_track_quat('Z','Y').to_euler();return o
# Continuous architecture with genuine openings.
box('Rear limewashed wall',(0,1.8,-4.6),(10,3.6,.22),plaster)
box('East lower wall',(5,.5,0),(.22,1,9.5),plaster)
box('East upper wall',(5,3.35,0),(.22,.70,9.5),plaster)
for z,l in [(-4,1.3),(-.65,2.1),(3.3,2.8)]:box('East window pier',(5,2,z),(.22,2,l),plaster)
for z in [-2.5,1.2]:
 for zz in [z-.8,z+.8]:box('East window jamb',(5,2,zz),(.32,2,.09),dark)
 for y in [1.03,3.0]:box('East window frame',(5,y,z),(.34,.10,1.7),dark)
 box('East mullion',(5,2,z),(.24,1.9,.06),dark)
 box('East crosspiece',(5,2,z),(.24,.06,1.6),dark)
 box('East sill',(5.15,1.02,z),(.65,.1,1.8),wood)
 for zz in [z-1.08,z+1.08]:
  for j in range(3):box('Open shutter',(5.17,2,zz+(j-1)*.14),(.08,1.8,.13),wood)
  for y in [1.3,2.7]:box('Shutter strap',(5.23,y,zz),(.035,.075,.44),iron)
for x in [-5.13,5.13]:
 for z in range(-9,10):box('Side stone footing',(x,.14,z*.49),(.33,.28,.48),stone,.025)

box('West lower wall',(-5,.5,0),(.22,1,9.5),plaster);box('West upper wall',(-5,3.35,0),(.22,.70,9.5),plaster)
for z,l in [(-4,1.3),(-.65,2.1),(3.3,2.8)]:box('West window pier',(-5,2,z),(.22,2,l),plaster)
for x in [-3.8,3.8]:box('Front wall',(x,1.8,4.7),(2.4,3.6,.22),plaster)
for x in [-1.05,1.05]:box('Door jamb',(x,1.8,4.7),(.5,3.6,.27),wood)
box('Overdoor lintel',(0,3.05,4.7),(1.7,1.1,.22),plaster)
for x in [-1.95,1.95]:
 box('Front sill masonry',(x,.55,4.7),(1.3,1.1,.22),plaster);box('Front window header',(x,3.2,4.7),(1.3,.8,.22),plaster)
 for xx in [x-.65,x+.65]:box('Front window post',(xx,1.96,4.7),(.08,1.8,.32),wood)
 for y in [1.08,2.8]:box('Window frame',(x,y,4.7),(1.45,.08,.36),wood)
 box('Front window mullion',(x,1.95,4.7),(.055,1.7,.24),wood);box('Crosspiece',(x,1.95,4.7),(1.3,.055,.24),wood)
 box('Deep window sill',(x,1.05,4.7),(1.55,.1,.6),lightwood)
for z in [-2.5,1.2]:
 for zz in [z-.8,z+.8]:box('Side window jamb',(-5,2,zz),(.32,2,.09),wood)
 for y in [1.03,3.0]:box('Side window frame',(-5,y,z),(.34,.10,1.7),wood)
 box('Window cross',(-5,2,z),(.24,.06,1.6),wood);box('Window mullion',(-5,2,z),(.24,1.9,.06),wood)
 box('Window seat sill',(-4.85,1.02,z),(.65,.10,1.8),lightwood)
# Foundation blocks stop at the doorway.
for x in range(-10,11):
 for z in [-4.73,4.78]:
  if z>0 and abs(x*.49)<.85:continue
  box('Footing',(x*.49,.12,z),(.48,.24,.33),stone,.035)
# Timber facade, joinery and cross braces.
for x in [-4.88,0,4.88]:
 for z in [-4.48,4.83]:
  if not (x==0 and z>0):box('Upright',(x,1.8,z),(.18,3.6,.17),wood)
for z in [-4.48,4.83]:
 box('Top plate',(0,3.49,z),(10.2,.19,.20),wood)
 for side in [-1,1]:beam('Corner knee brace',(side*4.8,2.75,z),(side*4.0,3.5,z),.12)
for x in [-4.85,-2.4,0,2.4,4.85]:box('Ceiling beam',(x,3.47,0),(.16,.22,9.5),dark)
box('Ceiling planks',(0,3.66,0),(10.3,.18,9.7),lightwood)
# Modeled staggered slate shingles, each with softened chipped edges.
for side in [-1,1]:
 box('Roof deck',(side*2.5,4.95,0),(6.15,.16,10.05),dark,.015,-side*.50)
 for row in range(13):
  x=side*(.12+row*.413);y=6.485-abs(x)*math.tan(.50)
  for col in range(23):
   z=-4.9+col*.445+(row%2)*.10
   if z>5.0:continue
   box('Slate shingle',(x,y+.06+random.uniform(-.005,.005),z),(.50,.045,.48),random.choice(roofs),.018,-side*.50)
for i in range(24):box('Ridge cap',(0,6.56,-4.98+i*.435),(.26,.12,.46),roofs[1],.035)
for z in [-4.84,4.91]:
 verts=[cv((-5.1,3.64,z)),cv((5.1,3.64,z)),cv((0,6.48,z))];mesh=bpy.data.meshes.new('Gable');mesh.from_pydata(verts,[],[(0,1,2),(2,1,0)]);o=bpy.data.objects.new('Closed gable',mesh);bpy.context.collection.objects.link(o);o.data.materials.append(materials[plaster]);objects.append(o)
 beam('Gable verge',(-5.2,3.65,z),(0,6.50,z),.16);beam('Gable verge',(0,6.50,z),(5.2,3.65,z),.16);beam('King post',(0,3.65,z),(0,6.48,z),.14)
# Half-timber panels echo the neighboring cottages, with open windows preserved.
for z in [-4.84,4.91]:
 for side in [-1,1]:
  beam('Gable diagonal',(side*4.8,3.65,z),(0,5.8,z),.18,dark)
for x in [-5.14,5.14]:
 for z in [-4.48,-.6,4.48]:box('Side upright',(x,1.8,z),(.18,3.6,.19),dark)
 box('Side wall plate',(x,3.48,0),(.19,.22,9.5),dark)
for x in [-3.8,3.8]:
 box('Facade mid rail',(x,1.1,4.84),(2.35,.15,.15),dark)
 beam('Facade diagonal',(x-1.0,1.18,4.84),(x+.95,3.37,4.84),.16,dark)
# Masonry chimney anchors the roof silhouette like the neighboring cottages.
for row in range(7):
 for j in range(2):box('Chimney masonry',(2.55+(j-.5)*.36,5.35+row*.18,-2.8),(.35,.175,.75),stone,.012)
box('Chimney cap',(2.55,6.63,-2.8),(.9,.16,.92),stone,.025)
box('Chimney opening',(2.55,6.72,-2.8),(.61,.015,.60),dark,0)
# Worn, offset flooring. No perfectly repeated large color squares.
for x in range(20):
 for row in range(7):box('Floor plank',(-4.75+x*.5,-.015,-4.1+row*1.32),(.493,.07,1.31),lightwood,.007)
# Open plank door outside the jamb.
for i in range(7):box('Open door plank',(-.97,1.18,4.75+i*.19),(.11,2.36,.18),wood,.012)
for y in [.45,1.85]:box('Door strap',(-.895,y,5.33),(.03,.09,1.24),iron,.005)
box('Door threshold',(0,.01,4.8),(1.7,.04,.8),stone,.025)
# Detailed classroom furniture.
def book(x,y,z):
 box('Book cover',(x,y,z),(.48,.035,.33),cover,.01);box('Paper block',(x,y+.032,z),(.45,.025,.30),paper,.006)
 for side in [-1,1]:
  for j in range(5):box('Written line',(x+side*.12,y+.047,z-.105+j*.047),(.17,.002,.007),ink,0)
 box('Binding',(x,y+.048,z),(.014,.003,.30),cover,0)
for row in range(2):
 for side in [-1,1]:
  x=side*1.5;z=.05+row*2.1
  for j in range(4):box('Desk top board',(x,.72,z-.24+j*.16),(1.6,.095,.155),wood,.02)
  for dx in [-.65,.65]:
   for dz in [-.23,.23]:box('Desk leg',(x+dx,.345,z+dz),(.09,.69,.09),wood,.012)
   box('Desk stretcher',(x+dx,.18,z),(.09,.09,.5),dark)
  box('Desk apron',(x,.62,z+.24),(1.42,.15,.065),dark)
  box('Bench seat',(x,.44,z+.70),(1.5,.10,.42),wood,.025)
  for dx in [-.59,.59]:box('Bench leg',(x+dx,.20,z+.70),(.11,.40,.34),dark,.015)
  box('Bench brace',(x,.18,z+.70),(1.27,.08,.08),wood)
  book(x-.30,.79,z);book(x+.36,.79,z)
box('Teachers table',(0,.91,-2.7),(2.15,.12,.84),wood,.03)
for x in [-.88,.88]:
 for z in [-2.96,-2.44]:box('Lectern leg',(x,.43,z),(.12,.86,.12),dark)
book(0,.99,-2.7);book(.63,.99,-2.68)
box('Slate frame',(0,2.15,-4.39),(3.8,1.6,.15),wood,.03);box('Writing board',(0,2.15,-4.29),(3.55,1.35,.035),board,.015);box('Chalk tray',(0,1.33,-4.17),(3.8,.075,.30),wood)
# Export few material batches, preserving the editable source first.
source=ROOT/'art/hub/schoolhouse.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source))
for m in list(dict.fromkeys(materials)):
 if any(materials[k]==materials[m] for k in list(materials)[:list(materials).index(m)]): continue
 group=[o for o in list(bpy.context.scene.objects) if o.type=="MESH" and o.data.materials and o.data.materials[0]==materials[m]]
 if not group:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in group:o.select_set(True)
 bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();group[0].name=m
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/village/schoolhouse.glb'),export_format='GLB',use_selection=True,export_animations=False)
print('SCHOOLHOUSE_EXPORTED')

"""Remove the horn and visibly support the anvil's side shelf and tool hanger."""
import bpy, sys, runpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/hub/hub_library.blend'))
col=bpy.data.collections['anvil_station'];origin=Vector(col['export_origin'])
for name in ['Smooth forged horn','Tong hook']:
    ob=col.objects.get(name)
    if ob:bpy.data.objects.remove(ob,do_unlink=True)
def bar(name,a,b,width,material):
    a,b=Vector(a)+origin,Vector(b)+origin
    bpy.ops.mesh.primitive_cube_add(size=1,location=(a+b)/2)
    ob=bpy.context.object;ob.name=name
    ob.dimensions=(width,width,(b-a).length)
    ob.rotation_mode='QUATERNION';ob.rotation_quaternion=(b-a).to_track_quat('Z','Y')
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for c in list(ob.users_collection):c.objects.unlink(ob)
    col.objects.link(ob);ob.data.materials.append(bpy.data.materials[material])
    bevel=ob.modifiers.new('Worn edges','BEVEL');bevel.width=.008;bevel.segments=2
    bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=bevel.name)
for y in [-.12,.19]:
    bar('Shelf brace',(-.31,y,.25),(-.53,y,.49),.075,'dark_oak')
    bar('Shelf ledger',(-.34,y,.28),(-.34,y,.52),.08,'dark_oak')
bar('Tool peg',(-.27,-.18,.50),(-.49,-.31,.50),.045,'iron')
bar('Raised peg lip',(-.49,-.31,.48),(-.49,-.31,.54),.035,'iron')
# Set the resting hammer onto the shelf using its evaluated lower bound.
props=[o for o in col.objects if o.name.startswith('Resting hammer')]
lowest=min((o.matrix_world@Vector(c)).z for o in props for c in o.bound_box)
for o in props:o.location.z += origin.z+.568-lowest
sys.argv=['export_hub.py','--','anvil_station']
runpy.run_path(str(ROOT/'tools/export_hub.py'),run_name='__main__')

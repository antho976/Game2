"""Export reusable scenery from the approved, editable mine study. Never edits combat."""
import bpy
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/dungeon/first_portal/modules'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/dungeon/first_portal.blend'))
source = list(bpy.data.collections['mine_sample'].objects)

def starts(obj, prefixes):
    return obj.name.startswith(tuple(prefixes))

def export(name, selected, center, normalize=False):
    copies = []
    offset = Vector((center[0], -center[2], center[1]))
    for original in selected:
        obj = original.copy()
        obj.data = original.data.copy()
        bpy.context.collection.objects.link(obj)
        obj.location -= offset
        copies.append(obj)
    if normalize:
        obj = copies[0]
        bounds = [obj.matrix_world @ Vector(v) for v in obj.bound_box]
        low = Vector(tuple(min(v[i] for v in bounds) for i in range(3)))
        high = Vector(tuple(max(v[i] for v in bounds) for i in range(3)))
        for v in obj.data.vertices:
            world = obj.matrix_world @ v.co
            v.co = Vector(tuple((world[i]-(low[i]+high[i])/2)/(high[i]-low[i]) for i in range(3)))
        obj.matrix_world.identity()
    buckets = {}
    for obj in copies:
        buckets.setdefault(obj.data.materials[0], []).append(obj)
    exports = []
    for objects in buckets.values():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        exports.append(objects[0])
    bpy.ops.object.select_all(action='DESELECT')
    for obj in exports: obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name+'.glb')), export_format='GLB', use_selection=True, export_animations=False)
    for obj in exports: bpy.data.objects.remove(obj, do_unlink=True)

export('arch', [o for o in source if starts(o, ['Ancient gate pier','Buried gate arch'])], (1,0,-7.6))
export('support', [o for o in source if starts(o, ['Mine support','Support shoe','Diagonal brace','Crossbeam','Brace iron band']) and o.location.y > 2], (0,0,-4))
export('cart', [o for o in source if starts(o, ['Cart '])], (2.4,0,1.55))
export('seam', [o for o in source if starts(o, ['Living seam','Mineral root'])], (-5,0,-3))
export('crates', [o for o in source if starts(o, ['Supply crate','Crate iron strap'])], (-3.15,0,5.6))
export('roots', [o for o in source if starts(o, ['Pale root']) and o.location.x > 4 and o.location.y < -3], (4.8,0,4))
export('lamp', [o for o in source if starts(o, ['Lamp cage','Lamp light']) and o.location.x < 0], (-4.5,2.55,1.7))
rocks = [o for o in source if starts(o, ['Fractured bedrock']) and o.dimensions.z > 3]
export('rock', rocks[:1], (0,0,0), True)
bpy.ops.mesh.primitive_cube_add(size=1)
stone = bpy.context.object
stone.data.materials.append(bpy.data.materials['Mine_stone'])
bevel = stone.modifiers.new('Worn corners', 'BEVEL')
bevel.width = .055
bevel.segments = 2
bpy.ops.object.modifier_apply(modifier=bevel.name)
export('block', [stone], (0,0,0))
print('MINE_MODULES_EXPORTED: 9 reusable modules')

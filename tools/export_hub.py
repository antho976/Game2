"""Export a manually edited collection from the packed library.

blender --background art/hub/hub_library.blend --python tools/export_hub.py -- cottage
The source file is not modified. Selected geometry is returned to asset-local origin.
"""
import bpy
import sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
names=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
if len(names)!=1 or names[0] not in bpy.data.collections:
    raise ValueError("Pass exactly one hub collection name after --")
name=names[0]
collection=bpy.data.collections[name]
if "export_origin" not in collection:
    raise ValueError("Collection has no asset origin metadata")
offset=Vector(collection["export_origin"])
bpy.ops.object.select_all(action="DESELECT")
objects=list(collection.objects)
for ob in objects:
    ob.hide_set(False)
    ob.hide_viewport=False
    ob.select_set(True)
    if ob.parent is None: ob.location-=offset
export_objects=objects
copies=[]
rig=next((ob for ob in objects if ob.type=="ARMATURE"),None)
tracks=[]
active=rig.animation_data.action if rig else None
try:
    if not any(ob.type=="ARMATURE" for ob in objects):
        buckets={}
        for source in objects:
            if source.type!="MESH": continue
            ob=source.copy()
            ob.data=source.data.copy()
            bpy.context.collection.objects.link(ob)
            buckets.setdefault(ob.data.materials[0].name,[]).append(ob)
        for group in buckets.values():
            bpy.ops.object.select_all(action="DESELECT")
            for ob in group: ob.select_set(True)
            bpy.context.view_layer.objects.active=group[0]
            bpy.ops.object.join()
            copies.append(group[0])
        export_objects=copies
    bpy.ops.object.select_all(action="DESELECT")
    for ob in export_objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=export_objects[0]
    if rig:
        rig.animation_data.action=None
        for action in bpy.data.actions:
            if action.name.startswith(name+"_"):
                track=rig.animation_data.nla_tracks.new()
                track.name=action.name
                track.strips.new(action.name,0,action)
                tracks.append(track)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/"assets/hub"/(name+".glb")),export_format="GLB",use_selection=True,export_animations=True,export_animation_mode="NLA_TRACKS" if rig else "ACTIONS")
finally:
    if rig:
        for track in tracks: rig.animation_data.nla_tracks.remove(track)
        rig.animation_data.action=active
    for ob in copies: bpy.data.objects.remove(ob,do_unlink=True)
    for ob in objects:
        if ob.parent is None: ob.location+=offset
print("EXPORTED_EDITED_ASSET",name)

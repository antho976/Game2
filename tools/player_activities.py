"""Extend the reused villager rig with hub-only actions; leave its source library unchanged."""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/hub/hub_library.blend'))
col=bpy.data.collections['villager']
objects=list(col.objects)
rig=next(ob for ob in objects if ob.type=='ARMATURE')
for ob in objects:
    ob.hide_set(False);ob.hide_viewport=False
    if ob.parent is None:ob.location-=Vector(col['export_origin'])
for clip in ['pet','water','feed','sit']:
    action=bpy.data.actions.new('villager_'+clip);action.use_fake_user=True
    rig.animation_data.action=action
    for frame in range(1,62,3):
        t=(frame-1)/60;phase=t*math.tau
        for bone in rig.pose.bones:
            bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0);bone.location=(0,0,0)
        def rx(name,value):rig.pose.bones[name].rotation_euler.x=value
        if clip=='sit':
            rig.pose.bones['Hips'].location.y=-.36
            for side in ['L','R']:
                rx('Thigh.'+side,-1.48);rx('Shin.'+side,1.50)
                rx('UpperArm.'+side,-.22);rx('Forearm.'+side,-.5)
            rx('Chest',.08);rx('Head',-.05+math.sin(phase)*.025)
        elif clip=='pet':
            rig.pose.bones['Hips'].location.y=-.26
            for side in ['L','R']:rx('Thigh.'+side,-.8);rx('Shin.'+side,1.15)
            rx('Chest',.32);rx('Head',.16)
            rx('UpperArm.R',-.52+math.sin(phase*2)*.16);rx('Forearm.R',-.25)
            rx('UpperArm.L',-.25);rx('Forearm.L',-.35)
        elif clip=='water':
            rx('Chest',.13);rx('Head',.16)
            rx('UpperArm.R',-.78);rx('Forearm.R',-.25+math.sin(phase)*.09)
            rx('UpperArm.L',-.48);rx('Forearm.L',-.55)
        elif clip=='feed':
            rx('Chest',.1);rx('Head',.15)
            rx('UpperArm.L',-.55);rx('Forearm.L',-1.1)
            rx('UpperArm.R',-.55+math.sin(phase)*.45);rx('Forearm.R',-.65-math.sin(phase)*.35)
        for bone in rig.pose.bones:
            bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
            bone.keyframe_insert(data_path='location',frame=frame,group=bone.name)
    action.frame_range=(1,61)
rig.animation_data.action=None
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for action in bpy.data.actions:
    if action.name.startswith('villager_'):
        track=rig.animation_data.nla_tracks.new();track.name=action.name;track.strips.new(action.name,0,action)
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:ob.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/village/hub_player.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS')
# The packed original source plus this script reproduce the animated derivative.
print('PLAYER ACTIVITY ANIMATIONS EXPORTED')

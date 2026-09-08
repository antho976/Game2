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
# A contact/swing walk cycle, authored on the source skeleton at 30 fps.
old=bpy.data.actions.get('villager_walk')
if old:bpy.data.actions.remove(old)
action=bpy.data.actions.new('villager_walk');action.use_fake_user=True
rig.animation_data.action=action
for frame in range(1,26):
    t=(frame-1)/24
    for bone in rig.pose.bones:
        bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0);bone.location=(0,0,0)
    rig.pose.bones['Hips'].location.y=-.045+.012*math.cos(t*math.tau*2)
    rig.pose.bones['Hips'].rotation_euler.z=.025*math.sin(t*math.tau)
    rig.pose.bones['Chest'].rotation_euler.z=-.035*math.sin(t*math.tau)
    for side,offset in [('L',0),('R',.5)]:
        phase=(t+offset)%1
        if phase<.6:
            y=-.30+phase/.6*.60;lift=0
        else:
            u=(phase-.6)/.4
            y=.30-.60*(u*u*(3-2*u));lift=.105*math.sin(u*math.pi)
        down=.70-lift
        distance=min(.755,math.hypot(y,down))
        knee=2*math.acos(distance/.76)
        thigh=math.atan2(y,down)-knee*.5
        rig.pose.bones['Thigh.'+side].rotation_euler.x=thigh
        rig.pose.bones['Shin.'+side].rotation_euler.x=knee
        rig.pose.bones['Foot.'+side].rotation_euler.x=-thigh-knee
        rig.pose.bones['UpperArm.'+side].rotation_euler.x=.28*math.cos((t+offset)*math.tau)
        rig.pose.bones['Forearm.'+side].rotation_euler.x=-.15-.08*max(0,math.cos((t+offset)*math.tau))
    for bone in rig.pose.bones:
        bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
        bone.keyframe_insert(data_path='location',frame=frame,group=bone.name)
action.frame_range=(1,25)
for clip in ['pet','water','feed','sit','draw_water']:
    action=bpy.data.actions.new('villager_'+clip);action.use_fake_user=True
    rig.animation_data.action=action
    for frame in range(1,38 if clip=='feed' else 62,3):
        t=(frame-1)/(36 if clip=='feed' else 60);phase=t*math.tau
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
            def smooth(a,b,x):
                u=max(0,min(1,(x-a)/(b-a)));return u*u*(3-2*u)
            prepare=smooth(0,.32,t);release=smooth(.32,.48,t);recover=smooth(.62,1,t)
            rx('Chest',.08+.06*release*(1-recover));rx('Head',.12)
            rx('UpperArm.L',-.3);rx('Forearm.L',-.9)
            rx('UpperArm.R',(-.2-.4*prepare-.35*release)*(1-recover))
            rx('Forearm.R',(-.2-1.0*prepare+.95*release)*(1-recover))
        elif clip=='draw_water':
            rx('Chest',.16+.08*math.sin(phase))
            rx('Head',.20)
            for side,offset in [('L',0),('R',math.pi)]:
                rx('UpperArm.'+side,-.7+.22*math.sin(phase+offset))
                rx('Forearm.'+side,-.8+.35*math.sin(phase+offset))
        for bone in rig.pose.bones:
            bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
            bone.keyframe_insert(data_path='location',frame=frame,group=bone.name)
    action.frame_range=(1,37 if clip=='feed' else 61)
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

# Keep villagers on their existing mesh. The new outfit is a separate player asset.
import sys
sys.path.insert(0,str(ROOT/'tools'))
from player_model import build
from hero_animation import extend_rig, author
for ob in objects:
    ob.select_set(False)
# The player rig gains a neck and shoulders; every villager bone keeps its name and rest pose.
extend_rig(rig)
hero_parts=build(rig)
# Warrior idle, walk and run replace the villager locomotion tracks for this export only.
author(rig)
for ob in hero_parts+[rig]:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/village/player_refined.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS')
print('REFINED PLAYER EXPORTED')

bpy.ops.object.select_all(action='DESELECT')
for ob in hero_parts:
    if ob.name.startswith(('Sleeve','Cuff','Hand','Thumb')):ob.select_set(True)
rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/village/first_person_arms.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS')

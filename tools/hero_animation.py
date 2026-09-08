"""Author the unarmed warrior's locomotion clips on the extended villager rig.

The villager skeleton gains a neck and two shoulder bones for the player only. The
existing activity clips keep working because every original bone keeps its name and
rest orientation; the new bones sit at identity in those clips.

Clips are generated procedurally at 30 fps. The gait solver plants each foot on the
ground with a two-bone leg solve, so strides do not slide, and layers pelvis twist,
lateral weight shift, counter-rotating shoulders, heel strike, toe-off and arm swing on
top. `GROUND_SPEED` records how fast each clip covers ground at speed scale 1 so the
player script can match playback to velocity.
"""
import bpy, math

TAU = math.tau
THIGH = .38
SHIN = .38
LEG = THIGH + SHIN
FPS = 30

WALK = dict(frames=24, front=.36, back=.42, stance=.60, lift=.10, crouch=.012, bob=.018, bob_phase=.25,
            land_lift=.045, land_flex=-.28, heel=.07, plant=0.0, toeoff=.40, sway=.016, twist=.07, roll=.03,
            hips_pitch=.02, lean=.05, chest_bob=.012, head_bob=.012, shoulder_twist=.09, stance_width=.03,
            arm_rest=.04, arm_swing=.34, arm_back_bias=.1, arm_out=.11, elbow=.40, elbow_var=.22,
            shrug=0.0, shoulder_back=.05, hand=-.12, lift_peak=.85)
RUN = dict(frames=20, front=.36, back=.62, stance=.32, lift=.32, crouch=.025, bob=.038, bob_phase=.45,
           land_lift=.03, land_flex=0.0, heel=.09, plant=.12, toeoff=.50, sway=.012, twist=.12, roll=.04,
           hips_pitch=.11, lean=.18, chest_bob=.02, head_bob=.015, shoulder_twist=.17, stance_width=.02,
           arm_rest=-.05, arm_swing=.75, arm_back_bias=.05, arm_out=.10, elbow=1.25, elbow_var=.45,
           shrug=.04, shoulder_back=.02, hand=-.35, lift_peak=.6)


def ground_speed(P):
    """Metres per second covered while the clip plays at speed scale 1."""
    return (P['front'] + P['back']) / (P['stance'] * P['frames'] / FPS)


GROUND_SPEED = {'walk': ground_speed(WALK), 'run': ground_speed(RUN)}


def smooth(a, b, x):
    u = max(0.0, min(1.0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)


def extend_rig(rig):
    """Add Neck and Shoulder.L/R bones; move the head pivot up to the top of the neck."""
    bpy.ops.object.select_all(action='DESELECT')
    rig.hide_set(False)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rig.data.edit_bones
    if 'Neck' not in eb:
        neck = eb.new('Neck')
        neck.head = (0, 0, 1.51)
        neck.tail = (0, 0, 1.60)
        neck.parent = eb['Chest']
        eb['Head'].parent = neck
        eb['Head'].head = (0, 0, 1.60)
        for side, s in [('L', -1), ('R', 1)]:
            sh = eb.new('Shoulder.' + side)
            sh.head = (s * .04, 0, 1.47)
            sh.tail = (s * .245, 0, 1.44)
            sh.parent = eb['Chest']
            eb['UpperArm.' + side].parent = sh
    bpy.ops.object.mode_set(mode='OBJECT')


class Pose:
    def __init__(self, rig):
        self.rig = rig

    def reset(self):
        for b in self.rig.pose.bones:
            b.rotation_mode = 'XYZ'
            b.rotation_euler = (0, 0, 0)
            b.location = (0, 0, 0)

    def rot(self, name, x=0.0, y=0.0, z=0.0):
        b = self.rig.pose.bones[name]
        e = b.rotation_euler
        b.rotation_euler = (e.x + x, e.y + y, e.z + z)

    def loc(self, name, x=0.0, y=0.0, z=0.0):
        b = self.rig.pose.bones[name]
        l = b.location
        b.location = (l.x + x, l.y + y, l.z + z)

    def key(self, frame):
        for b in self.rig.pose.bones:
            b.keyframe_insert(data_path='rotation_euler', frame=frame, group=b.name)
            b.keyframe_insert(data_path='location', frame=frame, group=b.name)


def place_leg(pose, side, forward, height, foot_extra, hips_pitch):
    """Two-bone solve: ankle `forward` metres ahead of the hip and `height` below it."""
    y = -forward   # bone pitch is positive toward +Y (backwards)
    d = min(LEG - .004, math.hypot(y, height))
    knee = 2 * math.acos(d / LEG)
    reach = math.atan2(y, height)
    thigh = reach - knee * .5 - hips_pitch
    pose.rot('Thigh.' + side, x=thigh)
    pose.rot('Shin.' + side, x=knee)
    pose.rot('Foot.' + side, x=-(reach + knee * .5) + foot_extra)


def gait(rig, name, P):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    pose = Pose(rig)
    frames = P['frames']
    for f in range(1, frames + 2):
        t = ((f - 1) % frames) / frames
        pose.reset()
        legs = {}
        travel = P['front'] + P['back']
        for side, off in [('L', 0.0), ('R', 0.5)]:
            ph = (t + off) % 1
            if ph < P['stance']:
                u = ph / P['stance']
                fwd = P['front'] - travel * u
                landing = 1 - smooth(0, .3, u)
                lift = P['land_lift'] * landing + P['heel'] * smooth(.65, 1, u)
                extra = P['plant'] + P['land_flex'] * landing + P['toeoff'] * smooth(.6, 1, u)
                legs[side] = (fwd, lift, extra, True)
            else:
                u = (ph - P['stance']) / (1 - P['stance'])
                fwd = -P['back'] + travel * smooth(0, 1, u)
                lift = P['heel'] * (1 - smooth(0, .3, u)) + P['land_lift'] * smooth(.7, 1, u) + P['lift'] * math.sin(math.pi * u ** P['lift_peak']) ** 1.1
                extra = P['toeoff'] * (1 - smooth(0, .35, u)) + P['land_flex'] * smooth(.55, 1, u)
                legs[side] = (fwd, lift, extra, False)
        bob = P['bob'] * math.cos(2 * TAU * (t - P['bob_phase']))
        hip = LEG - P['crouch'] + bob
        for fwd, lift, extra, planted in legs.values():
            if planted:
                hip = min(hip, math.sqrt(max(0.0, (LEG - .004) ** 2 - fwd ** 2)) + lift)
        c1, s1 = math.cos(TAU * t), math.sin(TAU * t)
        c2 = math.cos(2 * TAU * (t - P['bob_phase']))
        pose.loc('Hips', x=-P['sway'] * s1, y=hip - LEG)
        pose.rot('Hips', x=P['hips_pitch'], y=P['twist'] * c1, z=-P['roll'] * s1)
        for side, sgn in [('L', 1), ('R', -1)]:
            fwd, lift, extra, planted = legs[side]
            place_leg(pose, side, fwd, hip - lift, extra, P['hips_pitch'])
            pose.rot('Thigh.' + side, z=sgn * P['stance_width'])
        pose.rot('Chest', x=P['lean'] + P['chest_bob'] * c2, y=-(P['twist'] + P['shoulder_twist']) * c1, z=P['roll'] * 1.3 * s1)
        pose.rot('Neck', x=-(P['lean'] + P['hips_pitch']) * .35)
        pose.rot('Head', x=-(P['lean'] + P['hips_pitch']) * .5 + P['head_bob'] * c2, y=P['shoulder_twist'] * .7 * c1)
        for side, off, sgn in [('L', 0.0, 1), ('R', 0.5, -1)]:
            c = math.cos(TAU * (t + off))
            pose.rot('UpperArm.' + side, x=P['arm_rest'] + P['arm_swing'] * (c - P['arm_back_bias']), z=sgn * P['arm_out'])
            pose.rot('Forearm.' + side, x=-(P['elbow'] + P['elbow_var'] * (.5 - .5 * c)))
            pose.rot('Shoulder.' + side, x=P['shrug'] + .012 * c2, z=-sgn * P['shoulder_back'])
            pose.rot('Hand.' + side, x=P['hand'])
        pose.key(f)
    action.frame_range = (1, frames + 1)
    rig.animation_data.action = None
    return action


def idle(rig, name, seconds=8.0):
    """Grounded ready stance: weight on one leg, open chest, breathing, a slow scan and a
    weight shift so the loop never reads as a metronome."""
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    pose = Pose(rig)
    frames = int(seconds * FPS)
    for f in range(1, frames + 2, 2):
        t = ((f - 1) % frames) / frames
        T = t * seconds
        pose.reset()
        breath = math.sin(TAU * T / 4.0)
        shift = smooth(.34, .46, t) - smooth(.80, .92, t)          # 0 = weight right, 1 = weight left
        look = smooth(.12, .20, t) - smooth(.42, .50, t) - (smooth(.62, .70, t) - smooth(.88, .96, t))
        side_bias = 1 - 2 * shift                                   # +1 right leg loaded
        drift = .006 * math.sin(TAU * T / 8.0)
        pose.loc('Hips', x=.024 * side_bias + drift, y=-.012)
        pose.rot('Hips', y=.03 * side_bias, z=.03 * side_bias)
        for side, sgn in [('L', 1), ('R', -1)]:
            loaded = (.5 + .5 * side_bias) if side == 'R' else (.5 - .5 * side_bias)
            relaxed = 1 - loaded
            place_leg(pose, side, forward=.04 * relaxed - .01 * loaded, height=LEG - .012 - .014 * relaxed, foot_extra=.16 * relaxed, hips_pitch=0.0)
            pose.rot('Thigh.' + side, z=sgn * (.05 + .015 * relaxed))
        pose.rot('Chest', x=-.04 + .014 * breath, y=-.04 * side_bias, z=-.02 * side_bias)
        for side, sgn in [('L', 1), ('R', -1)]:
            pose.rot('Shoulder.' + side, x=.015 * breath, z=-sgn * .06)
            pose.rot('UpperArm.' + side, x=.06 + .012 * breath, z=sgn * .09)
            pose.rot('Forearm.' + side, x=-.32 - .02 * breath - .012 * math.sin(TAU * T / (8 / 3)))
            pose.rot('Hand.' + side, x=-.10)
        pose.rot('Neck', x=.02)
        pose.rot('Head', x=.03 - .008 * breath, y=.26 * look, z=.03 * look)
        pose.key(f)
    action.frame_range = (1, frames + 1)
    rig.animation_data.action = None
    return action


def author(rig):
    """Replace the villager idle and walk tracks with the warrior's, and add a run."""
    tracks = rig.animation_data.nla_tracks
    for track in list(tracks):
        if track.name in ('villager_idle', 'villager_walk', 'villager_run'):
            tracks.remove(track)
    clips = [('villager_idle', idle(rig, 'hero_idle')),
             ('villager_walk', gait(rig, 'hero_walk', WALK)),
             ('villager_run', gait(rig, 'hero_run', RUN))]
    for name, action in clips:
        track = tracks.new()
        track.name = name
        track.strips.new(name, 0, action)
    return clips

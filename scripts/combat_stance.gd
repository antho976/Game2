extends SkeletonModifier3D
# Whole-body fighting posture layered over the shared idle/walk clips, applied before the grip
# solver so the arms reach from the moved shoulders. Channels, all eased toward a target:
#   lean    chest pitch, forward positive: the coil behind a chamber and the drive through a cut
#   twist   chest yaw: the shoulders turning away from a cut, then through it
#   roll    chest bank: a flinch away from a blow
#   crouch  the hips sink and both knees bend so the feet stay planted
#   hips    hip yaw, the wind-up that leads the shoulders into a cut
#   shift_x shift_z  the pelvis slides sideways or forward: weight over the front foot
#   look nod  head yaw and pitch on top of the automatic counter-rotation that keeps eyes on the foe
const KEYS := ["lean","twist","roll","crouch","hips","shift_x","shift_z","look","nod"]
const LEG := .76 # Thigh plus shin of the villager rig, from tools/hero_animation.py.
var current := {}
var target := {}
var rate := 12.0
var lean := 0.0 # Kept as plain properties so callers can read the eased values.
var twist := 0.0
var roll := 0.0
var crouch := 0.0
func _init() -> void:
	for key in KEYS:
		current[key]=0.0
		target[key]=0.0
func aim(new_lean: float,new_twist: float,new_roll: float,new_crouch: float,speed := 12.0) -> void:
	pose({"lean":new_lean,"twist":new_twist,"roll":new_roll,"crouch":new_crouch},speed)
func pose(values: Dictionary,speed := 12.0) -> void:
	for key in KEYS: target[key]=float(values.get(key,0.0))
	rate=speed
# Jump straight to the target, for the cinematic that authors every frame itself.
func snap() -> void:
	for key in KEYS: current[key]=target[key]
func _process_modification() -> void:
	var rig := get_skeleton()
	var delta: float=get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()
	var weight: float=minf(delta*rate,1)
	for key in KEYS: current[key]=lerpf(current[key],target[key],weight)
	lean=current.lean
	twist=current.twist
	roll=current.roll
	crouch=current.crouch
	var hips := rig.find_bone("Hips")
	var chest := rig.find_bone("Chest")
	var neck := rig.find_bone("Neck")
	var head := rig.find_bone("Head")
	if hips>=0:
		rig.set_bone_pose_position(hips,rig.get_bone_pose_position(hips)+Vector3(current.shift_x,-crouch,current.shift_z))
		rig.set_bone_pose_rotation(hips,rig.get_bone_pose_rotation(hips)*Quaternion.from_euler(Vector3(lean*.3,current.hips+twist*.25,roll*.3)))
	if crouch>.001:
		# Two-bone knee bend: the hips come down by `crouch` while both feet keep their place.
		var knee: float=2.0*acos(clampf((LEG-crouch)/LEG,0,1))
		for side in ["L","R"]:
			var thigh := rig.find_bone("Thigh."+side)
			var shin := rig.find_bone("Shin."+side)
			var foot := rig.find_bone("Foot."+side)
			if thigh<0 or shin<0 or foot<0: continue
			rig.set_bone_pose_rotation(thigh,rig.get_bone_pose_rotation(thigh)*Quaternion.from_euler(Vector3(-knee*.5,0,0)))
			rig.set_bone_pose_rotation(shin,rig.get_bone_pose_rotation(shin)*Quaternion.from_euler(Vector3(knee,0,0)))
			rig.set_bone_pose_rotation(foot,rig.get_bone_pose_rotation(foot)*Quaternion.from_euler(Vector3(-knee*.5,0,0)))
	if chest>=0:
		rig.set_bone_pose_rotation(chest,rig.get_bone_pose_rotation(chest)*Quaternion.from_euler(Vector3(lean,twist,roll)))
	if neck>=0:
		rig.set_bone_pose_rotation(neck,rig.get_bone_pose_rotation(neck)*Quaternion.from_euler(Vector3(-lean*.3,-twist*.25,-roll*.25)))
	if head>=0:
		# The eyes stay on the opponent while the body coils.
		rig.set_bone_pose_rotation(head,rig.get_bone_pose_rotation(head)*Quaternion.from_euler(Vector3(-lean*.45+current.nod,-twist*.5+current.look,-roll*.4)))

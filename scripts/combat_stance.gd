extends SkeletonModifier3D
# Layers a fighting posture over the shared idle/walk clips: a forward-set ready stance,
# the chest coiling behind a chamber and driving through a cut, a flinch, and an exhausted slump.
# Applied before the grip solver so the arms reach from the moved shoulders.
var lean := 0.0
var twist := 0.0
var roll := 0.0
var crouch := 0.0
var target := Vector4.ZERO # lean, twist, roll, crouch
var rate := 12.0
func aim(new_lean: float,new_twist: float,new_roll: float,new_crouch: float,speed := 12.0) -> void:
	target=Vector4(new_lean,new_twist,new_roll,new_crouch)
	rate=speed
func _process_modification() -> void:
	var rig := get_skeleton()
	var delta: float=get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()
	var weight: float=minf(delta*rate,1)
	lean=lerpf(lean,target.x,weight)
	twist=lerpf(twist,target.y,weight)
	roll=lerpf(roll,target.z,weight)
	crouch=lerpf(crouch,target.w,weight)
	var hips := rig.find_bone("Hips")
	var chest := rig.find_bone("Chest")
	var head := rig.find_bone("Head")
	if hips>=0:
		rig.set_bone_pose_position(hips,rig.get_bone_pose_position(hips)+Vector3(0,-crouch,crouch*.35))
		rig.set_bone_pose_rotation(hips,rig.get_bone_pose_rotation(hips)*Quaternion.from_euler(Vector3(lean*.25,twist*.35,0)))
	if chest>=0:
		rig.set_bone_pose_rotation(chest,rig.get_bone_pose_rotation(chest)*Quaternion.from_euler(Vector3(lean,twist,roll)))
	if head>=0:
		# The eyes stay on the opponent while the body coils.
		rig.set_bone_pose_rotation(head,rig.get_bone_pose_rotation(head)*Quaternion.from_euler(Vector3(-lean*.7,-twist*.6,-roll*.5)))

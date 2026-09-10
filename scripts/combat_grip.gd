extends SkeletonModifier3D
# Two-bone arm reach keeps both hands on the moving greatsword grip, closed around it as fists.
# The lead hand sits against the cross and the trailing hand at the pommel. Which bone leads is
# the caller's choice: the choreography is mirrored onto the player's rig, and the lead hand must
# stay the one whose shoulder the forehand cut is thrown from. (On this rig the bones named R
# hang on the character's own left, so the player leads with Hand.L.)
var sword: Node3D
var lead := "R" # Suffix of the hand bone nearest the cross.
var reach_error := 0.0 # Distance left between the lead wrist and its target after the last solve.
var hand_align := 1.0 # Worst dot of a hand's thumb axis with the blade: 1 when both fists close across the grip.
const LEAD_AT := -.05 # Grip points along the sword's own axis: just under the cross, and at the pommel.
const TRAIL_AT := -.20
const FIST := .055 # Wrist to the middle of the fist along the fingers, where the grip passes through.
func _process_modification() -> void:
	if not is_inside_tree() or not is_instance_valid(sword) or not sword.is_inside_tree() or not sword.is_visible_in_tree(): return
	var rig := get_skeleton()
	if not is_instance_valid(rig) or not rig.is_inside_tree():return
	var to_rig: Basis=rig.global_basis.inverse()
	var blade: Vector3=(to_rig*sword.global_basis.y).normalized()
	var flat: Vector3=(to_rig*sword.global_basis.z).normalized()
	hand_align=1.0
	for side in ["R","L"]:
		var upper := rig.find_bone("UpperArm."+side)
		var lower := rig.find_bone("Forearm."+side)
		var hand := rig.find_bone("Hand."+side)
		if upper<0 or lower<0 or hand<0: continue
		var grip := rig.to_local(sword.to_global(Vector3(0,LEAD_AT if side==lead else TRAIL_AT,0)))
		var shoulder := rig.get_bone_global_pose(upper).origin
		var a := rig.get_bone_global_rest(lower).origin.distance_to(rig.get_bone_global_rest(upper).origin)
		var b := rig.get_bone_global_rest(hand).origin.distance_to(rig.get_bone_global_rest(lower).origin)
		var outward := Vector3(1 if side=="R" else -1,-.7,-.2)
		# Solve straight at the grip first to learn which way the forearm comes in. The fingers run
		# on from the forearm across the grip, so the wrist then sits a fist short of the grip point.
		var fingers := reach(rig,upper,lower,shoulder,grip,a,b,outward)
		fingers=fingers-blade*fingers.dot(blade)
		if fingers.length()<.05: fingers=-flat
		fingers=fingers.normalized()
		var target := grip-fingers*FIST
		reach(rig,upper,lower,shoulder,target,a,b,outward)
		var pose := rig.get_bone_global_pose(hand)
		# Fingers wrap across the grip and the thumb (the hand's -z) points up the blade: a fist, not a cuff.
		pose.basis=Basis(blade.cross(fingers),fingers,-blade).orthonormalized()
		rig.set_bone_global_pose(hand,pose)
		if side==lead: reach_error=pose.origin.distance_to(target)
		hand_align=minf(hand_align,-pose.basis.z.dot(blade))
# Points the upper arm at an elbow bent toward `outward` and the forearm at `target`; returns the forearm direction.
func reach(rig: Skeleton3D,upper: int,lower: int,shoulder: Vector3,target: Vector3,a: float,b: float,outward: Vector3) -> Vector3:
	var offset := target-shoulder
	var length := clampf(offset.length(),.02,a+b-.002)
	var axis := offset.normalized()
	var bend := (outward-axis*outward.dot(axis)).normalized()
	var along := (a*a-b*b+length*length)/(2*length)
	var elbow := shoulder+axis*along+bend*sqrt(maxf(0,a*a-along*along))
	var wrist := shoulder+axis*length
	point_bone(rig,upper,shoulder,elbow)
	point_bone(rig,lower,elbow,wrist)
	return (wrist-elbow).normalized()
func point_bone(rig: Skeleton3D,index: int,origin: Vector3,target: Vector3) -> void:
	var pose := rig.get_bone_global_pose(index)
	pose.basis = Basis(Quaternion(pose.basis.y.normalized(),(target-origin).normalized()))*pose.basis
	pose.origin=origin
	rig.set_bone_global_pose(index,pose)

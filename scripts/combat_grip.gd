extends SkeletonModifier3D
# Two-bone arm reach keeps both hands on the moving greatsword grip.
var sword: Node3D
func _process_modification() -> void:
	if not is_instance_valid(sword) or not sword.is_visible_in_tree(): return
	var rig := get_skeleton()
	for side in ["R","L"]:
		var upper := rig.find_bone("UpperArm."+side)
		var lower := rig.find_bone("Forearm."+side)
		var hand := rig.find_bone("Hand."+side)
		if upper<0 or lower<0 or hand<0: continue
		var target := rig.to_local(sword.to_global(Vector3(0,-.06 if side=="R" else -.22,0)))
		var shoulder := rig.get_bone_global_pose(upper).origin
		var a := rig.get_bone_global_rest(lower).origin.distance_to(rig.get_bone_global_rest(upper).origin)
		var b := rig.get_bone_global_rest(hand).origin.distance_to(rig.get_bone_global_rest(lower).origin)
		var offset := target-shoulder
		var length := clampf(offset.length(),.02,a+b-.002)
		var axis := offset.normalized()
		var outward := Vector3(1 if side=="R" else -1,-.7,-.2)
		outward = (outward-axis*outward.dot(axis)).normalized()
		var along := (a*a-b*b+length*length)/(2*length)
		var elbow := shoulder+axis*along+outward*sqrt(maxf(0,a*a-along*along))
		point_bone(rig,upper,shoulder,elbow)
		point_bone(rig,lower,elbow,shoulder+axis*length)
		var pose := rig.get_bone_global_pose(hand)
		pose.basis = rig.global_basis.inverse()*sword.global_basis
		rig.set_bone_global_pose(hand,pose)
func point_bone(rig: Skeleton3D,index: int,origin: Vector3,target: Vector3) -> void:
	var pose := rig.get_bone_global_pose(index)
	pose.basis = Basis(Quaternion(pose.basis.y.normalized(),(target-origin).normalized()))*pose.basis
	pose.origin=origin
	rig.set_bone_global_pose(index,pose)

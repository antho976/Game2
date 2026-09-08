class_name GearVisuals
extends RefCounted
static var bevel: Mesh
var model: Node3D
var skeleton: Skeleton3D
var steel: StandardMaterial3D
var trim: StandardMaterial3D
var leather: StandardMaterial3D
static func material(color: Color,metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = .34 if metal>0 else .85
	return m
static func apply(target: Node3D,loadout: Dictionary) -> void:
	var old = target.find_children("GearMount*","BoneAttachment3D",true,false)
	for node in old:
		node.get_parent().remove_child(node)
		node.queue_free()
	for mesh in target.find_children("*","MeshInstance3D",true,false):
		var n := str(mesh.name)
		var covered := (loadout.has("helmet") and (n.begins_with("Face") or n.begins_with("SweptHair") or n.begins_with("Eye") or n.begins_with("Brow") or n.begins_with("Nose") or n.begins_with("Neck"))) or (loadout.has("chest") and (n.begins_with("FittedVest") or n.begins_with("TailoredTunic") or n.begins_with("SplitCollar") or n.begins_with("VestFastening") or n.begins_with("Buckle") or n.begins_with("WaistBelt"))) or (loadout.has("gloves") and (n.begins_with("Hand") or n.begins_with("Thumb") or n.begins_with("Cuff"))) or (loadout.has("boots") and (n.begins_with("Boot") or n.begins_with("Trouser")))
		mesh.visible = not covered
	var builder := GearVisuals.new()
	builder.model = target
	builder.skeleton = target.find_children("*","Skeleton3D",true,false)[0]
	for slot in loadout:
		var item: Dictionary = loadout[slot]
		builder.steel = material(Color(.43,.48,.50) if item.style==0 else Color(.16,.20,.23),.78)
		builder.trim = material(Color(.54,.40,.20) if item.style==0 else Color(.45,.47,.46),.72)
		builder.leather = material(Color(.10,.07,.045))
		builder.piece(slot,int(item.style))
func mount(bone: String) -> Node3D:
	var attach := BoneAttachment3D.new()
	attach.name = "GearMount"+bone.replace(".","")
	attach.bone_name = bone
	skeleton.add_child(attach)
	var root := Node3D.new()
	attach.add_child(root)
	root.transform = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse()*skeleton.global_transform.affine_inverse()*model.global_transform
	return root
func box(parent: Node3D,p: Vector3,s: Vector3,m: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	if bevel==null:
		var source: Node3D = load("res://assets/models/stone_block.glb").instantiate()
		bevel = source.find_children("*","MeshInstance3D",true,false)[0].mesh
		source.free()
	node.mesh = bevel
	node.scale = s
	node.material_override = m
	node.position = p
	parent.add_child(node)
	return node
func plate(parent: Node3D,rows: Array,m: Material,segments := 12) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rows.size()-1:
		for i in segments:
			var points: Array[Vector3] = []
			for index in [[row,i],[row,(i+1)%segments],[row+1,(i+1)%segments],[row+1,i]]:
				var spec: Array = rows[index[0]]
				var a: float = index[1]*TAU/segments
				points.append(Vector3(spec[0]+cos(a)*spec[3],spec[1],spec[2]+sin(a)*spec[4]))
			var order: Array = [0,2,1,0,3,2] if float(rows[row+1][1])>float(rows[row][1]) else [0,1,2,0,2,3]
			for j in order: tool.add_vertex(points[j])
	# Close the plate ends so raised camera angles never reveal hollow limbs.
	for edge in [0,rows.size()-1]:
		var spec: Array = rows[edge]
		for i in segments:
			var a := i*TAU/segments
			var b := (i+1)*TAU/segments
			var p := Vector3(spec[0]+cos(a)*spec[3],spec[1],spec[2]+sin(a)*spec[4])
			var q := Vector3(spec[0]+cos(b)*spec[3],spec[1],spec[2]+sin(b)*spec[4])
			tool.add_vertex(Vector3(spec[0],spec[1],spec[2]))
			tool.add_vertex(p if edge==0 else q)
			tool.add_vertex(q if edge==0 else p)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = m
	parent.add_child(node)
func piece(slot: String,style: int) -> void:
	match slot:
		"helmet":
			var head := mount("Head")
			plate(head,[[0,1.51,0,.104,.113],[0,1.62,0,.127,.129],[0,1.78,0,.126,.127],[0,1.88,0,.087,.084],[0,1.90,0,.004,.005]],steel)
			box(head,Vector3(0,1.625,.125),Vector3(.20,.15,.032),steel)
			box(head,Vector3(0,1.73,.126),Vector3(.185,.018,.015),leather)
			box(head,Vector3(0,1.67,.135),Vector3(.028,.13,.025),trim)
			for x in [-.075,-.045,.045,.075]:box(head,Vector3(x,1.64,.148),Vector3(.008,.036,.016),leather)
			if style==1: box(head,Vector3(0,1.86,0),Vector3(.026,.11,.24),trim)
		"chest":
			var chest := mount("Chest")
			plate(chest,[[0,.96,0,.20,.16],[0,1.08,0,.18,.151],[0,1.27,0,.249,.176],[0,1.43,0,.254,.15],[0,1.50,0,.102,.102]],steel)
			box(chest,Vector3(0,1.27,.172),Vector3(.025,.29,.016),trim)
			for i in 3: plate(chest,[[0,.85+i*.065,0,.237-i*.008,.175],[0,.93+i*.065,0,.219-i*.008,.162]],steel)
			plate(chest,[[0,1.47,0,.116,.116],[0,1.51,0,.11,.108]],trim)
			for side in [-1,1]:
				var bone := "UpperArm.L" if side<0 else "UpperArm.R"
				var arm := mount(bone)
				for i in 3:
					plate(arm,[[side*(.25+i*.019),1.48-i*.07,0,.13 if style==0 else .16,.13],[side*(.27+i*.019),1.41-i*.07,0,.12,.115]],steel)
				plate(arm,[[side*.30,1.30,0,.087,.091],[side*.335,1.20,0,.079,.08]],steel)
		"gloves":
			for side in [-1,1]:
				var suffix := ".L" if side<0 else ".R"
				var arm := mount("Forearm"+suffix)
				plate(arm,[[side*.337,1.18,0,.078,.083],[side*.361,1.02,.015,.066,.073],[side*.375,.96,.025,.059,.06]],steel)
				var hand := mount("Hand"+suffix)
				box(hand,Vector3(side*.38,.91,.028),Vector3(.112,.10,.10),steel)
				for i in 3: box(hand,Vector3(side*.38,.852+i*.016,.028),Vector3(.10,.013,.096),trim if i==2 else steel)
				box(hand,Vector3(side*.336,.90,.045),Vector3(.033,.057,.046),steel)
		"boots":
			for side in [-1,1]:
				var suffix := ".L" if side<0 else ".R"
				var x: float = side*.135
				plate(mount("Thigh"+suffix),[[x,.89,0,.115,.125],[x,.64,.005,.101,.11],[x,.54,.01,.094,.101]],steel)
				var shin := mount("Shin"+suffix)
				plate(shin,[[x,.57,.01,.104,.107],[x,.47,.0,.092,.094],[x,.19,0,.074,.086]],steel)
				box(shin,Vector3(x,.54,.112),Vector3(.15,.10,.035),trim)
				var foot := mount("Foot"+suffix)
				for i in 4:box(foot,Vector3(x,.115-i*.012,.025+i*.047),Vector3(.168-i*.01,.10-i*.012,.07),steel)
		"weapon":
			var back := mount("Chest")
			var blade := Node3D.new()
			back.add_child(blade)
			blade.position = Vector3(.26,1.60,-.24)
			blade.rotation.z = PI+.28
			sword(blade,style)
func sword(parent: Node3D,style: int) -> void:
	var length: float = [1.32,1.52,1.38][style]
	var width: float = [.095,.075,.14][style]
	# Diamond sections give the blade a lit bevel, not a flat rectangular slab.
	plate(parent,[[0,.16,0,width,.025],[0,length-.18,0,width*.86,.021],[0,length,0,.002,.002]],steel,4)
	box(parent,Vector3(0,length*.50,.024),Vector3(.018,length*.72,.009),trim)
	box(parent,Vector3(0,.12,0),Vector3(.46 if style<2 else .54,.065,.085),trim)
	if style==1:
		for side in [-1,1]: box(parent,Vector3(side*.23,.15,0),Vector3(.07,.14,.075),trim).rotation.z = side*.5
	box(parent,Vector3(0,-.09,0),Vector3(.056,.34,.06),leather)
	for i in 7:box(parent,Vector3(0,-.23+i*.045,0),Vector3(.062,.012,.066),trim)
	box(parent,Vector3(0,-.29,0),Vector3(.10,.09,.10),trim)

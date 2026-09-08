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
		mesh.visible = not (covered or (loadout.has("chest") and loadout.has("gloves") and n.begins_with("Sleeve")))
	var builder := GearVisuals.new()
	builder.model = target
	builder.skeleton = target.find_children("*","Skeleton3D",true,false)[0]
	for slot in loadout:
		var item: Dictionary = loadout[slot]
		builder.steel = material(Color(.43,.48,.50) if item.style==0 else Color(.16,.20,.23),.78)
		builder.trim = material(Color(.54,.40,.20) if item.style==0 else Color(.45,.47,.46),.72)
		builder.leather = material(Color(.10,.07,.045))
		if slot!="weapon":
			builder.steel.roughness = .52
			builder.steel.metallic = .65
		builder.piece(slot,int(item.style))
func mount(bone: String) -> Node3D:
	var attach := BoneAttachment3D.new()
	attach.name = "GearMount"+bone.replace(".","")
	attach.bone_name = bone
	skeleton.add_child(attach,true)
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
			var upward: bool = (edge==0 and float(rows[0][1])>float(rows[-1][1])) or (edge!=0 and float(rows[-1][1])>float(rows[0][1]))
			tool.add_vertex(p if upward else q)
			tool.add_vertex(q if upward else p)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = m
	parent.add_child(node)
# Raised central ridge and swept edges form shaped sheet-metal surfaces.
# Rows contain height, half-width, edge depth, ridge depth, horizontal center.
func panel(parent: Node3D,rows: Array,m: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows.size()-1:
		for side in [-1,1]:
			var a: Array = rows[r]
			var b: Array = rows[r+1]
			var points := [Vector3(a[4],a[0],a[3]),Vector3(a[4]+side*a[1],a[0],a[2]),Vector3(b[4]+side*b[1],b[0],b[2]),Vector3(b[4],b[0],b[3])]
			var order := [0,2,1,0,3,2] if side==1 else [0,1,2,0,2,3]
			for i in order: tool.add_vertex(points[i])
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.material_override = m
	parent.add_child(mesh)
func rivet(parent: Node3D,p: Vector3) -> void:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .007
	sphere.height = .014
	sphere.radial_segments = 6
	sphere.rings = 3
	node.mesh = sphere
	node.material_override = trim
	node.position = p
	parent.add_child(node)
func piece(slot: String,style: int) -> void:
	match slot:
		"helmet":
			var head := mount("Head")
			# A close-fitting sallet shell, lower bevor, and a continuous brow.
			plate(head,[[0,1.53,-.015,.087,.086],[0,1.60,-.018,.119,.105],[0,1.74,-.023,.126,.123],[0,1.82,-.024,.093,.092],[0,1.85,-.025,.022,.041]],steel,10)
			panel(head,[[1.545,.07,.076,.12,0],[1.59,.112,.077,.151,0],[1.682,.122,.065,.17,0],[1.70,.119,.065,.169,0]],steel)
			panel(head,[[1.707,.118,.066,.153,0],[1.722,.12,.064,.148,0],[1.76,.114,.055,.127,0],[1.815,.07,.04,.086,0]],steel)
			# Recessed eye slot wraps the ridge instead of a grille glued to the face.
			panel(head,[[1.699,.113,.067,.158,0],[1.709,.113,.067,.158,0]],leather)
			for side in [-1,1]:
				for i in 3:
					box(head,Vector3(side*(.032+i*.023),1.632,.158-i*.018),Vector3(.005,.021,.005),leather)
				rivet(head,Vector3(side*.119,1.696,.068))
			plate(head,[[0,1.47,-.015,.073,.076],[0,1.57,-.015,.083,.082]],leather)
			plate(head,[[0,1.53,-.025,.09,.087],[0,1.55,-.025,.099,.095]],trim,10)
			if style==1:
				panel(head,[[1.76,.012,.125,.142,0],[1.835,.012,.068,.084,0],[1.865,.008,-.025,-.018,0]],trim)
		"chest":
			var chest := mount("Chest")
			plate(mount("Hips"),[[0,.82,0,.191,.139],[0,.98,0,.181,.13]],leather)
			plate(chest,[[0,1.0,-.008,.177,.128],[0,1.12,-.012,.181,.136],[0,1.34,-.014,.232,.151],[0,1.44,-.018,.225,.132],[0,1.49,-.015,.096,.087]],steel)
			panel(chest,[[1.025,.168,.082,.15,0],[1.13,.185,.092,.174,0],[1.32,.229,.075,.201,0],[1.40,.211,.065,.174,0],[1.46,.093,.066,.105,0]],steel)
			plate(chest,[[0,1.455,-.012,.114,.10],[0,1.49,-.012,.095,.088]],trim)
			# Short fauld follows the waist; separate tassets leave the legs free.
			for i in 2: plate(chest,[[0,.975-i*.047,0,.191+i*.012,.146+i*.009],[0,1.026-i*.047,0,.178+i*.012,.136+i*.009]],steel)
			for side in [-1,1]:
				for i in 3:
					panel(chest,[[.83+i*.036,.081,.137,.174,side*.111],[.872+i*.036,.079,.128,.166,side*.106]],steel)
				for y in [1.14,1.34]: rivet(chest,Vector3(side*(.17 if y<1.2 else .207),y,.109))
				var arm := mount("UpperArm.L" if side<0 else "UpperArm.R")
				for i in 3:
					var width: float = (.125 if style==0 else .145)-i*.018
					plate(arm,[[side*(.255+i*.023),1.49-i*.054,0,width*.65,.08],[side*(.268+i*.023),1.455-i*.054,0,width,.114],[side*(.279+i*.023),1.41-i*.054,0,width*.94,.106]],steel,10)
					rivet(arm,Vector3(side*(.30+i*.024),1.425-i*.054,.101))
				plate(arm,[[side*.30,1.31,0,.079,.081],[side*.335,1.20,0,.072,.074]],steel)
		"gloves":
			for side in [-1,1]:
				var suffix := ".L" if side<0 else ".R"
				var arm := mount("Forearm"+suffix)
				plate(arm,[[side*.335,1.22,0,.073,.074],[side*.34,1.16,0,.073,.074]],leather)
				plate(arm,[[side*.337,1.185,0,.079,.082],[side*.348,1.10,.008,.071,.073],[side*.37,.965,.025,.050,.056]],steel,10)
				plate(arm,[[side*.366,.988,.023,.059,.064],[side*.38,.939,.027,.069,.068]],steel,10)
				var hand := mount("Hand"+suffix)
				plate(hand,[[side*.38,.95,.025,.052,.052],[side*.38,.896,.028,.056,.052],[side*.38,.855,.033,.045,.045]],steel,10)
				for i in 3: panel(hand,[[.856+i*.022,.049,.067,.083,side*.38],[.875+i*.022,.051,.067,.083,side*.38]],steel)
				plate(hand,[[side*.33,.924,.043,.020,.025],[side*.323,.884,.052,.018,.02]],steel,8)
		"boots":
			for side in [-1,1]:
				var suffix := ".L" if side<0 else ".R"
				var x: float = side*.135
				plate(mount("Thigh"+suffix),[[x,.94,0,.108,.112],[x,.73,.005,.102,.102],[x,.55,.01,.077,.082]],steel,10)
				var shin := mount("Shin"+suffix)
				plate(shin,[[x,.55,.005,.082,.087],[x,.40,-.004,.084,.092],[x,.12,0,.058,.066]],steel,10)
				panel(shin,[[.19,.052,.039,.081,x],[.36,.076,.064,.108,x],[.49,.072,.056,.106,x]],steel)
				panel(shin,[[.493,.064,.071,.106,x],[.54,.092,.068,.149,x],[.584,.067,.06,.111,x]],steel)
				rivet(shin,Vector3(x+side*.077,.54,.095))
				var foot := mount("Foot"+suffix)
				# Rounded, tapered sabatons with articulated overlapping lames.
				for i in 4:
					plate(foot,[[x,.056,.025+i*.043,.079-i*.009,.048],[x,.113-i*.010,.025+i*.043,.067-i*.008,.038]],steel,10)

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

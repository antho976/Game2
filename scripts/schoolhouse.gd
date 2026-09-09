extends Node3D
var room: Node3D
var teacher: Node3D
var pupils: Array[Node3D] = []
var camera: Camera3D
const ORIGIN := Vector3(4.6,.06,-19.0)
func _ready() -> void:
	name="Schoolhouse"
	position=ORIGIN
	room=self
	build_room()
	camera=Camera3D.new()
	camera.fov=62
	camera.near=.04
	camera.position=Vector3(3.2,2.35,3.6)
	add_child(camera)
	camera.look_at(to_global(Vector3(-.3,1.2,-2.8)))
func contains(p: Vector3) -> bool:
	var local:=to_local(p)
	return absf(local.x)<4.95 and local.z>-4.6 and local.z<4.7 and local.y<3.6
func collider(p: Vector3,s: Vector3) -> void:
	var body:=StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=0
	body.position=p
	var shape:=CollisionShape3D.new()
	var box_shape:=BoxShape3D.new()
	box_shape.size=s
	shape.shape=box_shape
	body.add_child(shape)
	add_child(body)
func solid(p: Vector3,s: Vector3,m: Material) -> MeshInstance3D:
	collider(p,s)
	return box(p,s,m)
func material(color: Color) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=.85
	return m
func box(p: Vector3,s: Vector3,m: Material,parent: Node3D=null) -> MeshInstance3D:
	if parent==null: parent=room
	var n:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=s
	n.mesh=mesh
	n.material_override=m
	n.position=p
	parent.add_child(n)
	return n
func sphere(p: Vector3,s: Vector3,m: Material,parent: Node3D) -> MeshInstance3D:
	var n:=MeshInstance3D.new()
	var mesh:=SphereMesh.new()
	mesh.radial_segments=16
	mesh.rings=8
	n.mesh=mesh
	n.scale=s
	n.position=p
	n.material_override=m
	parent.add_child(n)
	return n
func book(p: Vector3,angle: float=0) -> void:
	var cover:=material(Color(.19,.24,.20))
	var pages:=material(Color(.76,.71,.55))
	var base:=Node3D.new()
	base.position=p
	base.rotation.y=angle
	room.add_child(base)
	box(Vector3.ZERO,Vector3(.48,.04,.33),cover,base)
	box(Vector3(0,.035,0),Vector3(.44,.03,.29),pages,base)
	box(Vector3(0,.055,0),Vector3(.015,.005,.29),cover,base)
	for side in [-1,1]:
		for j in 4:
			box(Vector3(side*.115,.054,-.10+j*.055),Vector3(.16,.003,.007),material(Color(.39,.35,.27)),base)
func actor(p: Vector3,color: Color,seated: bool,old: bool=false) -> Node3D:
	var model: Node3D=load("res://assets/village/player_refined.glb").instantiate()
	room.add_child(model)
	model.position=p
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name)
		if id.begins_with("FittedVest") or id.begins_with("TailoredTunic") or id.begins_with("Sleeve"):
			mesh.material_override=material(color)
		if old and (id.begins_with("SweptHair") or id.begins_with("Brow")):
			mesh.material_override=material(Color(.69,.67,.59))
	var animation: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	var clip: String="villager_sit" if seated else "villager_idle"
	animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	animation.play(clip)
	if old:
		var builder:=GearVisuals.new()
		builder.model=model
		builder.skeleton=model.find_children("*","Skeleton3D",true,false)[0]
		var head:=builder.mount("Head")
		sphere(Vector3(0,1.595,.10),Vector3(.16,.13,.095),material(Color(.66,.65,.58)),head)
		for side in [-1,1]:
			var spectacles:=MeshInstance3D.new()
			var ring:=TorusMesh.new()
			ring.inner_radius=.029
			ring.outer_radius=.034
			ring.rings=16
			ring.ring_segments=8
			spectacles.mesh=ring
			spectacles.position=Vector3(side*.042,1.725,.122)
			spectacles.rotation.x=PI/2
			spectacles.material_override=material(Color(.30,.22,.10))
			head.add_child(spectacles)
		box(Vector3(0,1.725,.124),Vector3(.022,.009,.009),material(Color(.30,.22,.10)),head)
	return model
func build_room() -> void:
	var building: Node3D=load("res://assets/village/schoolhouse.glb").instantiate()
	add_child(building)
	collider(Vector3(0,-.07,0),Vector3(10,.14,9.5))
	collider(Vector3(0,1.8,-4.6),Vector3(10,3.6,.22))
	collider(Vector3(5,.5,0),Vector3(.22,1,9.5))
	collider(Vector3(5,3.35,0),Vector3(.22,.7,9.5))
	for span in [[-4.0,1.3],[-.65,2.1],[3.3,2.8]]:
		collider(Vector3(5,2,span[0]),Vector3(.22,2,span[1]))
	collider(Vector3(-5,.5,0),Vector3(.22,1,9.5))
	collider(Vector3(-5,3.35,0),Vector3(.22,.7,9.5))
	for span in [[-4.0,1.3],[-.65,2.1],[3.3,2.8]]:
		collider(Vector3(-5,2,span[0]),Vector3(.22,2,span[1]))
	for x in [-3.8,3.8]: collider(Vector3(x,1.8,4.7),Vector3(2.4,3.6,.22))
	for x in [-1.05,1.05]: collider(Vector3(x,1.8,4.7),Vector3(.5,3.6,.22))
	collider(Vector3(0,3.05,4.7),Vector3(1.7,1.1,.22))
	for x in [-1.95,1.95]:
		collider(Vector3(x,.55,4.7),Vector3(1.3,1.1,.22))
		collider(Vector3(x,3.2,4.7),Vector3(1.3,.8,.22))
	collider(Vector3(-.97,1.18,5.33),Vector3(.11,2.36,1.35))
	collider(Vector3(0,3.66,0),Vector3(10.3,.18,9.7))
	collider(Vector3(0,.48,-2.7),Vector3(2.15,.96,.84))
	for row in 2:
		for side in [-1,1]:
			var x: float=side*1.5
			var z: float=.05+row*2.1
			collider(Vector3(x,.39,z),Vector3(1.6,.78,.64))
			collider(Vector3(x,.25,z+.70),Vector3(1.5,.50,.42))
			var pupil:=actor(Vector3(x,0,z+.68),Color(.20,.30,.33) if side<0 else Color(.36,.25,.20),true)
			pupil.rotation.y=PI
			pupils.append(pupil)
	pupils[2].name="SeatedPlayer"
	teacher=actor(Vector3(-.48,0,-3.45),Color(.30,.31,.25),false,true)
	collider(Vector3(-.48,.9,-3.45),Vector3(.5,1.8,.5))
	var chalk:=Label3D.new()
	chalk.text="HISTORY OF THE GATES\n\nWhat we keep. What we owe."
	chalk.font_size=40
	chalk.pixel_size=.005
	chalk.modulate=Color(.79,.80,.66)
	chalk.position=Vector3(0,2.2,-4.26)
	add_child(chalk)
	for z in [-2.5,1.2]:
		var light:=OmniLight3D.new()
		light.position=Vector3(-3.9,2.4,z)
		light.light_color=Color(1,.87,.68)
		light.light_energy=1.2
		light.omni_range=7
		add_child(light)
	for z in [-2.9,1.8]:
		var shelf: Node3D=load("res://assets/hub/bookcase.glb").instantiate()
		add_child(shelf)
		shelf.position=Vector3(4.3,0,z)
		shelf.scale=Vector3.ONE*.8
		shelf.rotation.y=-PI/2
		collider(Vector3(4.3,.8,z),Vector3(.8,1.6,1.5))

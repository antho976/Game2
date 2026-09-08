extends Node3D
var kit: HubKit
var target: Node3D
var swing := 0.0
var speed := 0.0
func _ready() -> void:
	name = "TrainingDummy"
	var shape = preload("res://scripts/hub_landscape.gd")
	shape.shape(self,Vector3(0,.12,0),Vector3(.65,.12,.55),Color(.34,.30,.22))
	var post := MeshInstance3D.new()
	post.mesh = BoxMesh.new()
	post.mesh.size = Vector3(.17,1.9,.17)
	post.position.y = .95
	post.material_override = kit.world.wood
	add_child(post)
	target = Node3D.new()
	target.position.y = .9
	add_child(target)
	shape.shape(target,Vector3(0,.48,0),Vector3(.38,.49,.23),Color(.61,.49,.28))
	shape.shape(target,Vector3(0,1.15,0),Vector3(.24,.24,.21),Color(.68,.56,.34))
	for y in [.17,.45,.73]:
		var ring := MeshInstance3D.new()
		ring.mesh = TorusMesh.new()
		ring.mesh.inner_radius = .34
		ring.mesh.outer_radius = .37
		ring.mesh.rings = 16
		ring.position.y = y
		ring.scale.z = .63
		ring.material_override = kit.world.wood
		target.add_child(ring)
	for radius in [.20,.12,.045]:
		var disc := MeshInstance3D.new()
		disc.mesh = CylinderMesh.new()
		disc.mesh.top_radius = radius
		disc.mesh.bottom_radius = radius
		disc.mesh.height = .015
		disc.position = Vector3(0,.5,.24+(.2-radius)*.12)
		disc.rotation.x = PI/2
		disc.material_override = kit.world.rough_material(Color(.54,.22,.16) if radius != .12 else Color(.73,.62,.40))
		target.add_child(disc)
func strike() -> void:
	speed += 1.8
func _process(delta: float) -> void:
	speed += (-swing*25-speed*4)*delta
	swing += speed*delta
	target.rotation.x = swing

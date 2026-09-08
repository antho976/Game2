class_name HubWorld
extends Node3D
var game: Node3D
var stone: Array[StandardMaterial3D] = []
var wood: StandardMaterial3D
var beveled_box: Mesh
var interactions: Array[Dictionary] = []
func _ready() -> void:
	var model: Node3D = load("res://assets/models/stone_block.glb").instantiate()
	beveled_box = model.find_children("*","MeshInstance3D",true,false)[0].mesh
	model.free()
	for i in 6: stone.append(rough_material(Color(.31+i*.02,.32+i*.019,.27+i*.016)))
	wood = rough_material(Color(.23,.13,.065))

func rough_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .92
	var noise = FastNoiseLite.new()
	noise.seed = 71
	noise.frequency = .065
	noise.fractal_octaves = 5
	var texture = NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.noise = noise
	texture.seamless = true
	var ramp = Gradient.new()
	ramp.set_color(0, Color(.72, .71, .68))
	ramp.set_color(1, Color(.96, .94, .89))
	texture.color_ramp = ramp
	material.albedo_texture = texture
	var normal = NoiseTexture2D.new()
	normal.width = 128
	normal.height = 128
	normal.noise = noise
	normal.seamless = true
	normal.as_normal_map = true
	normal.bump_strength = 1.8
	material.normal_enabled = true
	material.normal_texture = normal
	material.normal_scale = .8
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * .9
	return material

func box(pos: Vector3, size: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	mesh.mesh = beveled_box
	mesh.scale = size
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)
	if solid:
		block(pos, size)
	return mesh

func block(pos: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

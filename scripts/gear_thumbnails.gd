class_name GearThumbnails
extends Node
# Item icons rendered from the gear the game actually builds, so a card shows
# the same steel the fitting room does. Each piece is framed on a mannequin
# whose body is hidden; swords are forged on their own and stood diagonally.
signal finished

const SIZE := 176
# Slot, then the point the camera looks at and how much of the world it sees.
const FRAMING := {
	"helmet":[Vector3(0,1.665,0),.44],
	"chest":[Vector3(0,1.16,0),.92],
	"gloves":[Vector3(.355,1.045,0),.44],
	"boots":[Vector3(0,.50,0),1.06]}

var viewport: SubViewport
var camera: Camera3D
var mannequin: Node3D
var forge: Node3D
var cache := {}
var ready_for_use := false

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE,SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.80,.76,.72)
	env.environment.ambient_light_energy = .70
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34,-38,0)
	key.light_energy = 1.7
	key.light_color = Color(1,.94,.85)
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-12,148,0)
	rim.light_energy = 1.1
	rim.light_color = Color(.98,.62,.34)
	viewport.add_child(rim)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	mannequin = load("res://assets/village/player_refined.glb").instantiate()
	viewport.add_child(mannequin)
	forge = Node3D.new()
	viewport.add_child(forge)

## Point the camera at a spot in the mannequin's world, from three-quarters on.
func aim(at: Vector3,extent: float) -> void:
	camera.size = extent
	camera.position = at+Vector3(.62,.30,1.55).normalized()*3.0
	camera.look_at(at)

func bare() -> void:
	for mesh in mannequin.find_children("*","MeshInstance3D",true,false):
		var node: Node = mesh
		var worn := false
		while node != null and node != mannequin:
			if node is BoneAttachment3D:
				worn = true
				break
			node = node.get_parent()
		mesh.visible = worn

func shoot() -> Texture2D:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return ImageTexture.create_from_image(image)

func blade(style: int) -> void:
	for child in forge.get_children():
		forge.remove_child(child)
		child.queue_free()
	var builder := GearVisuals.new()
	builder.steel = GearVisuals.material(Color(.43,.48,.50) if style==0 else Color(.16,.20,.23),.78)
	builder.trim = GearVisuals.material(Color(.54,.40,.20) if style==0 else Color(.45,.47,.46),.72)
	builder.leather = GearVisuals.material(Color(.10,.07,.045))
	var pivot := Node3D.new()
	forge.add_child(pivot)
	pivot.rotation.z = -PI*.26
	pivot.rotation.y = .35
	var shaft := Node3D.new()
	pivot.add_child(shaft)
	shaft.position.y = -.56
	builder.sword(shaft,style)

## Render every catalogue entry once, a frame at a time, then say so.
func warm(items: Array) -> void:
	if DisplayServer.get_name()=="headless":
		ready_for_use = true
		finished.emit()
		return
	for item in items:
		if cache.has(item.id): continue
		if item.slot=="weapon":
			mannequin.hide()
			blade(int(item.style))
			forge.show()
			forge.position = Vector3(0,0,0)
			camera.size = 1.50
			camera.position = Vector3(.30,0,3)
			camera.look_at(Vector3(0,0,0))
		else:
			forge.hide()
			mannequin.show()
			GearVisuals.apply(mannequin,{item.slot:item})
			bare()
			var frame: Array = FRAMING[item.slot]
			aim(frame[0],frame[1])
		cache[item.id] = await shoot()
	mannequin.hide()
	forge.hide()
	ready_for_use = true
	finished.emit()

func icon(id: String) -> Texture2D:
	return cache.get(id,null)

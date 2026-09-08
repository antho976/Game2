class_name HubNPC
extends CharacterBody3D

signal work_struck

@export_enum("blacksmith", "scholar", "villager") var profession: String = "villager"
@export var route: PackedVector3Array = PackedVector3Array()
var animation: AnimationPlayer
var current_clip: String = ""
var waypoint: int = 0
var rest: float = 0
var model: Node3D
var home: Vector3
var previous_time: float = 0
var variant: int = 0
var idle_time: float = 0
var stuck_time: float = 0
var walk_speed: float = .65

func _ready() -> void:
	home = position
	collision_layer = 1
	collision_mask = 3
	var collider = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = .25
	shape.height = 1.8
	collider.shape = shape
	collider.position.y = .9
	add_child(collider)
	model = load("res://assets/hub/" + profession + ".glb").instantiate()
	add_child(model)
	var players = model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animation = players[0]
		for clip in animation.get_animation_list():
			animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	apply_variation()
	play("hammer" if profession == "blacksmith" else ("read" if profession == "scholar" else "idle"))

func play(action: String) -> void:
	if animation == null:
		return
	for clip in animation.get_animation_list():
		if clip.ends_with(profession + "_" + action) or clip == action:
			if current_clip != clip:
				current_clip = clip
				animation.play(clip, .25)
			return

func _physics_process(delta: float) -> void:
	idle_time += delta
	velocity = Vector3(0,-2,0)
	if profession == "blacksmith" and animation and current_clip.ends_with("_hammer"):
		var at: float = animation.current_animation_position
		if previous_time < .4 and at >= .4:
			work_struck.emit()
		previous_time = at
	if profession != "villager" or route.is_empty():
		if profession == "villager":
			var game = get_parent().world.game
			if is_instance_valid(game.player) and position.distance_to(game.player.position) < 3:
				var toward: Vector3 = game.player.position-position
				model.rotation.y = lerp_angle(model.rotation.y,atan2(toward.x,toward.z),delta*2)
			else:
				model.rotation.y += sin(idle_time*.5+variant)*delta*.10
		move_and_slide()
		return
	if rest > 0:
		rest -= delta
		play("idle")
		move_and_slide()
		return
	var target: Vector3 = home + route[waypoint]
	var direction: Vector3 = target - position
	direction.y = 0
	if direction.length() < .08:
		waypoint = (waypoint + 1) % route.size()
		rest = 1.4 + (variant%4)*.7
		return
	var motion: Vector3 = direction.normalized() * minf(walk_speed, direction.length()/delta)
	velocity.x = motion.x
	velocity.z = motion.z
	var before := position
	move_and_slide()
	if position.distance_to(before) < .002:
		stuck_time += delta
		if stuck_time > 1.5:
			waypoint = (waypoint+1)%route.size()
			stuck_time = 0
	else:
		stuck_time = 0
	model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), minf(delta * 5, 1))
	play("walk")

func apply_variation() -> void:
	if profession != "villager" or not is_instance_valid(model): return
	var coats := [Color(.22,.32,.27),Color(.49,.25,.18),Color(.26,.34,.46),Color(.55,.43,.23),Color(.42,.28,.43),Color(.30,.40,.38)]
	var skins := [Color(.57,.37,.25),Color(.75,.55,.39),Color(.36,.22,.16),Color(.63,.43,.30)]
	var hairs := [Color(.12,.085,.06),Color(.43,.28,.13),Color(.55,.53,.46),Color(.21,.15,.10)]
	model.scale = Vector3(1.0+(variant%3)*.06,.92+(variant%4)*.045,1.0+(variant%3)*.05)
	walk_speed = .48 + (variant%4)*.10
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.mesh.surface_get_material(surface)
			if not original is StandardMaterial3D: continue
			var material: StandardMaterial3D = original.duplicate()
			var id := original.resource_name.to_lower()
			if "wool" in id or "linen" in id:
				material.albedo_texture = null
				material.albedo_color = coats[variant%coats.size()]
			elif "skin" in id:
				material.albedo_color = skins[variant%skins.size()]
			elif "hair" in id:
				material.albedo_color = hairs[variant%hairs.size()]
			mesh.set_surface_override_material(surface,material)
	if animation:
		animation.speed_scale = .85+(variant%4)*.12
	# Accessories follow the animated head, with coordinates authored in model space.
	var skeleton: Skeleton3D = model.find_children("*","Skeleton3D",true,false)[0]
	var previous := skeleton.get_node_or_null("PersonalDetails")
	if previous: previous.free()
	var attachment := BoneAttachment3D.new()
	attachment.name = "PersonalDetails"
	attachment.bone_name = "Head"
	skeleton.add_child(attachment)
	var details := Node3D.new()
	attachment.add_child(details)
	details.transform = skeleton.get_bone_global_rest(skeleton.find_bone("Head")).affine_inverse() * skeleton.global_transform.affine_inverse() * model.global_transform
	var shape = preload("res://scripts/hub_landscape.gd")
	if variant%3 == 0:
		shape.shape(details,Vector3(0,1.86,0),Vector3(.25,.025,.21),Color(.57,.43,.23))
		shape.shape(details,Vector3(0,1.92,0),Vector3(.135,.10,.13),Color(.62,.49,.28))
	elif variant%3 == 1:
		shape.shape(details,Vector3(0,1.84,0),Vector3(.15,.085,.135),coats[variant%coats.size()])
		shape.shape(details,Vector3(.06,1.91,0),Vector3(.075,.035,.07),coats[variant%coats.size()])
	else:
		shape.shape(details,Vector3(0,1.54,0),Vector3(.14,.06,.11),coats[(variant+2)%coats.size()])

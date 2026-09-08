extends CharacterBody3D
var model: Node3D
var animation: AnimationPlayer
var game: Node3D
var current := ""
var activity := ""
var activity_time := 0.0
var facing := 0.0
var last_safe := Vector3(0,.1,8)
var seat_exit := Vector3.ZERO

func _ready() -> void:
	name = "UnarmedPlayer"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = .4
	var shape := CapsuleShape3D.new()
	shape.radius = .28
	shape.height = 1.65
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = .84
	add_child(collider)
	model = load("res://assets/village/hub_player.glb").instantiate()
	model.scale = Vector3.ONE*.97
	add_child(model)
	animation = model.find_children("*","AnimationPlayer",true,false)[0]
	for clip in animation.get_animation_list():
		animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.mesh.surface_get_material(surface)
			if original is StandardMaterial3D and "wool" in original.resource_name.to_lower():
				var mat: StandardMaterial3D = original.duplicate()
				mat.albedo_texture = null
				mat.albedo_color = Color(.24,.37,.40)
				mesh.set_surface_override_material(surface,mat)
	play("idle")

func play(action: String) -> void:
	for clip in animation.get_animation_list():
		if clip.ends_with("villager_"+action) and current != clip:
			current = clip
			animation.play(clip,.18)
			return

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("left","right","up","down")
	if game.input_blocked: input = Vector2.ZERO
	if activity_time > 0:
		activity_time -= delta
		input = Vector2.ZERO
		if activity_time <= 0: activity = ""
	if activity == "sit":
		if input.length() > 0.1:
			activity = ""
			position = seat_exit
			collision_mask = 1
		else: input = Vector2.ZERO
	var direction := Vector3(input.x,0,input.y).rotated(Vector3.UP,game.yaw)
	var speed := 4.4 if Input.is_action_pressed("run") else 2.4
	velocity.x = move_toward(velocity.x,direction.x*speed,delta*24)
	velocity.z = move_toward(velocity.z,direction.z*speed,delta*24)
	if activity != "sit":
		velocity.y -= 20*delta
		move_and_slide()
	else: velocity = Vector3.ZERO
	if direction.length() > .1: facing = atan2(direction.x,direction.z)
	model.rotation.y = lerp_angle(model.rotation.y,facing,minf(delta*10,1))
	if not activity.is_empty():
		play(activity)
		animation.speed_scale = 1.0
	else:
		play("walk" if Vector2(velocity.x,velocity.z).length()>.1 else "idle")
		animation.speed_scale = clampf(Vector2(velocity.x,velocity.z).length()/1.5,.35,2.5) if current.ends_with("_walk") else 1.0
	if is_on_floor(): last_safe = position
	if position.y < -3: position = last_safe+Vector3.UP

func act(id: String, target: Vector3, seconds: float) -> void:
	if id == "sit":
		seat_exit = position
		collision_mask = 0
	activity = id
	activity_time = seconds
	var direction := target-position
	facing = atan2(direction.x,direction.z)
	velocity.x = 0
	velocity.z = 0

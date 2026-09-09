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
var lean := 0.0
var bank := 0.0
var previous_yaw := 0.0
# Ground speed of each authored cycle at speed scale 1, from tools/hero_animation.py.
const WALK_GROUND_SPEED := 1.625
const RUN_GROUND_SPEED := 4.59
const RUN_THRESHOLD := 3.3
# Footsteps fire by distance travelled, half a cycle apart, so they stay under the feet at
# any playback speed: the walk clip covers 1.3 m per cycle and the run 3.06 m.
const WALK_STRIDE := .65
const RUN_STRIDE := 1.53
var stride := 0.0
var surface := "grass"

func _ready() -> void:
	name = "UnarmedPlayer"
	collision_layer = 2
	collision_mask = 5
	floor_snap_length = .4
	var shape := CapsuleShape3D.new()
	shape.radius = .28
	shape.height = 1.65
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = .84
	add_child(collider)
	model = load("res://assets/village/player_refined.glb").instantiate()
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

func play(action: String, blend: float = .18) -> void:
	for clip in animation.get_animation_list():
		if clip.ends_with("villager_"+action) and current != clip:
			current = clip
			animation.play(clip,blend)
			return

func has_clip(action: String) -> bool:
	for clip in animation.get_animation_list():
		if clip.ends_with("villager_"+action): return true
	return false

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
			collision_mask = 5
			game.audio.play("bench_stand",position,-14)
		else: input = Vector2.ZERO
	var direction := Vector3(input.x,0,input.y).rotated(Vector3.UP,game.yaw)
	var speed := 5.6 if Input.is_action_pressed("run") else 2.0
	var desired := direction*speed
	if is_instance_valid(game.combat) and game.combat.active and not game.input_blocked: desired=game.combat.movement(direction,speed)
	velocity.x = move_toward(velocity.x,desired.x,delta*80 if is_instance_valid(game.combat) and game.combat.active else delta*24)
	velocity.z = move_toward(velocity.z,desired.z,delta*80 if is_instance_valid(game.combat) and game.combat.active else delta*24)
	if activity != "sit":
		velocity.y -= 20*delta
		move_and_slide()
	else: velocity = Vector3.ZERO
	if direction.length() > .1: facing = atan2(direction.x,direction.z)
	if is_instance_valid(game.combat) and game.combat.active and game.lock_enabled:
		var target: Vector3=game.combat.enemy.position-position
		facing=atan2(target.x,target.z)
	model.rotation.y = lerp_angle(model.rotation.y,facing,minf(delta*10,1))
	var planar := Vector2(velocity.x,velocity.z).length()
	var target_lean := 0.0
	if not activity.is_empty():
		play(activity)
		animation.speed_scale = 1.0
	elif planar < .1:
		play("idle",.25)
		animation.speed_scale = 1.0
	elif planar > RUN_THRESHOLD and has_clip("run"):
		# Match stride to ground speed so the feet stay planted.
		play("run",.22)
		animation.speed_scale = clampf(planar/RUN_GROUND_SPEED,.6,1.7)
		target_lean = .07
	else:
		play("walk",.18)
		animation.speed_scale = clampf(planar/WALK_GROUND_SPEED,.35,2.2)
		target_lean = .015
	# Lean into speed and bank into turns so direction changes carry weight.
	var yaw_rate := wrapf(model.rotation.y-previous_yaw,-PI,PI)/maxf(delta,.001)
	previous_yaw = model.rotation.y
	lean = lerpf(lean,target_lean,minf(delta*6,1))
	bank = lerpf(bank,clampf(-yaw_rate*.028,-.11,.11)*clampf(planar/2.0,0,1),minf(delta*8,1))
	model.rotation.x = lean
	model.rotation.z = bank
	if is_on_floor(): last_safe = position
	if position.y < -3:
		position = last_safe+Vector3.UP
		game.audio.play("player_land",position,-12)
	footsteps(planar,delta)

func footsteps(planar: float,delta: float) -> void:
	if planar < .3 or not is_on_floor() or activity == "sit":
		stride = minf(stride,.2)
		return
	var running := planar > RUN_THRESHOLD
	stride += planar*delta
	if stride < (RUN_STRIDE if running else WALK_STRIDE): return
	stride = 0.0
	surface = game.kit.surface_at(position)
	var id := "step_"+surface+("_run" if running else "_walk")
	if running and not game.audio.has(id): id = "step_"+surface+"_walk"
	if not game.audio.has(id): id = "step_grass_run" if running else "step_grass_walk"
	game.audio.play(id,position,-12 if running else -17,{"max_distance":16,"pitch_spread":.07})
	game.audio.play("foley_cloth_walk",position,-24,{"max_distance":8})
	if not is_instance_valid(game.equipment): return
	if game.equipment.equipped.keys().any(func(slot): return slot != "weapon"):
		game.audio.play("foley_plate_walk",position,-22,{"max_distance":10})
	elif game.equipment.equipped.has("weapon"):
		game.audio.play("foley_sword_back",position,-24,{"max_distance":8})

func act(id: String, target: Vector3, seconds: float) -> void:
	if id == "sit":
		seat_exit = position
		collision_mask = 0
		game.audio.play("bench_sit",position,-14)
	activity = id
	activity_time = seconds
	var direction := target-position
	facing = atan2(direction.x,direction.z)
	velocity.x = 0
	velocity.z = 0

# Research stat bonuses are ready for the forthcoming combat system.
func combat_stats() -> Dictionary:
	return game.combat.stats() if is_instance_valid(game.combat) else game.research.player_stats()

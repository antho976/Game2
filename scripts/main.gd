extends Node3D
var world: HubWorld
var kit: HubKit
var player: CharacterBody3D
var camera: Camera3D
var activities: Node3D
var ui: CanvasLayer
var prompt: Label
var notice: Label
var notice_time := 0.0
var title: Label
var yaw := 0.0
var camera_target := Vector3(0,0,7)
var elapsed := 0.0
var overview := false
var input_blocked := false
var test_mode := false
var paused := false
var ambient: Array[AudioStreamPlayer] = []
var nearest := ""
var nearest_pos := Vector3.ZERO
var muted := false
var menus: CanvasLayer
var village_day: Node

func _ready() -> void:
	test_mode = "--player-visual" in OS.get_cmdline_user_args() or "--self-test" in OS.get_cmdline_user_args() or "--menu-test" in OS.get_cmdline_user_args() or "--polish-test" in OS.get_cmdline_user_args() or "--routine-test" in OS.get_cmdline_user_args() or "--village-capture" in OS.get_cmdline_user_args() or "--cleanup-test" in OS.get_cmdline_user_args()
	for spec in [["left",KEY_A,KEY_LEFT],["right",KEY_D,KEY_RIGHT],["up",KEY_W,KEY_UP],["down",KEY_S,KEY_DOWN],["run",KEY_SHIFT],["interact",KEY_F]]:
		InputMap.add_action(spec[0])
		for code in spec.slice(1):
			var e := InputEventKey.new()
			e.physical_keycode = code
			InputMap.action_add_event(spec[0],e)
	world = HubWorld.new()
	world.game = self
	add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.43,.54,.52)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.62,.72,.81)
	env.ambient_light_energy = .7
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-30,0)
	sun.light_color = Color(1.0,.89,.71)
	sun.shadow_enabled = true
	world.add_child(sun)
	player = preload("res://scripts/player.gd").new()
	player.game = self
	player.position = Vector3(0,.1,8.5)
	add_child(player)
	kit = HubKit.new()
	world.add_child(kit)
	kit.build(world)
	activities = preload("res://scripts/activities.gd").new()
	activities.game = self
	world.add_child(activities)
	activities.build()
	# Every stone and wood block has been placed by now; draw them as a few batches instead.
	world.merge_blocks()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23
	camera.far = 180
	add_child(camera)
	update_camera(1.0)
	build_ui()
	village_day = preload("res://scripts/village_day.gd").new()
	village_day.game = self
	add_child(village_day)
	village_day.build()
	menus = preload("res://scripts/menu.gd").new()
	menus.game = self
	add_child(menus)
	if not test_mode and not "--capture" in OS.get_cmdline_user_args(): menus.show_home()
	play_ambient("amb_hub_air_01",-23)
	play_ambient("music_hub_01",-25)
	spatial_loop("amb_pond_01",Vector3(-12,.5,8.7),-17,12)
	spatial_loop("amb_forge_01",Vector3(-9,1,0),-18,9)
	if "--capture" in OS.get_cmdline_user_args(): capture()
	if "--runtime-probe" in OS.get_cmdline_user_args():
		var probe := preload("res://tests/runtime_probe.gd").new()
		add_child(probe)
	if "--player-visual" in OS.get_cmdline_user_args():
		var visual = load("res://tests/player_visual.gd").new()
		add_child(visual)
		visual.run(self)
	if "--cleanup-test" in OS.get_cmdline_user_args():
		var cleanup = load("res://tests/cleanup_test.gd").new()
		add_child(cleanup)
		cleanup.run(self)
	if "--village-capture" in OS.get_cmdline_user_args():
		var capture_suite = load("res://tests/village_capture.gd").new()
		add_child(capture_suite)
		capture_suite.run(self)
	if "--routine-test" in OS.get_cmdline_user_args():
		var suite = load("res://tests/routine_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--polish-test" in OS.get_cmdline_user_args():
		var suite = load("res://tests/polish_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--menu-test" in OS.get_cmdline_user_args():
		var suite = load("res://tests/menu_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--self-test" in OS.get_cmdline_user_args():
		test_mode = true
		var suite = load("res://tests/hub_test.gd").new()
		add_child(suite)
		suite.run(self)

func flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	return mat

func play_sound(id: String,pos: Vector3,_channel := "",_cooldown := 0.0) -> void:
	if DisplayServer.get_name() == "headless": return
	var path := "res://assets/audio/"+id+"_01.ogg"
	if not ResourceLoader.exists(path) or muted or test_mode: return
	var sound := AudioStreamPlayer3D.new()
	sound.stream = load(path)
	sound.position = pos
	sound.volume_db = -16
	sound.max_distance = 18
	sound.unit_size = 4
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func play_ambient(id: String,volume: float) -> void:
	if DisplayServer.get_name() == "headless": return
	var sound := AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load("res://assets/audio/"+id+".ogg")
	stream.loop = true
	sound.stream = stream
	sound.volume_db = volume
	add_child(sound)
	ambient.append(sound)
	sound.play()

func spatial_loop(id: String,pos: Vector3,volume: float,radius: float) -> void:
	if DisplayServer.get_name() == "headless": return
	var sound := AudioStreamPlayer3D.new()
	var stream: AudioStreamOggVorbis = load("res://assets/audio/"+id+".ogg")
	stream.loop = true
	sound.stream = stream
	sound.position = pos
	sound.volume_db = volume
	sound.unit_size = 4
	sound.max_distance = radius
	world.add_child(sound)
	sound.play()

func label(text: String,size: int,color: Color,pos: Vector2) -> Label:
	var node := Label.new()
	node.text = text
	node.position = pos
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	node.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	node.add_theme_constant_override("shadow_offset_x",1)
	node.add_theme_constant_override("shadow_offset_y",2)
	ui.add_child(node)
	return node

func build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	title = label("THE VILLAGE",16,Color(.95,.91,.78),Vector2(30,25))
	label("A quiet place to return to",13,Color(.83,.85,.79),Vector2(30,49))
	prompt = label("",20,Color(1,.96,.82),Vector2.ZERO)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -95
	prompt.offset_bottom = -60
	notice = label("",17,Color(.94,.91,.80),Vector2(0,90))
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notice.offset_top = 90
	notice.offset_bottom = 120

func _process(delta: float) -> void:
	elapsed += delta
	update_camera(delta)
	notice_time = maxf(0,notice_time-delta)
	notice.modulate.a = minf(notice_time,1)
	if input_blocked: return
	update_interaction()
	if Input.is_action_just_pressed("interact") and not input_blocked:
		interact()

func update_camera(delta: float) -> void:
	if menus != null and menus.home:
		yaw += delta * .055
		camera.size = 43
	var target: Vector3 = Vector3(0,0,-.5) if overview or (menus != null and menus.home) else player.position
	target.y = .1
	camera_target = camera_target.lerp(target,1.0-exp(-delta*7.0))
	camera.position = camera_target+Vector3(0,19,15).rotated(Vector3.UP,yaw)
	camera.look_at(camera_target)

func update_interaction() -> void:
	nearest = ""
	var best := 2.3
	var text := ""
	for animal in kit.life.animals:
		if animal.kind != "cat": continue
		var distance: float = player.position.distance_to(animal.body.position)
		if distance < 1.9 and distance < best:
			best = distance
			nearest = "cat:"+str(animal.body.get_instance_id())
			nearest_pos = animal.body.position
			text = "F  ·  Pet the cat" if animal.friendly else "Give the shy cat a little space"
	for point in activities.points:
		var distance: float = player.position.distance_to(point.pos)
		if distance < point.radius and distance < best:
			best = distance
			nearest = point.id
			nearest_pos = point.pos
			text = "F  ·  "+point.text
	if nearest.is_empty():
		for service in world.interactions:
			if player.position.distance_to(service.pos) < 2.8: text = service.text
	prompt.text = "Move to stand up" if player.activity == "sit" else (text if player.activity_time <= 0 else "")

func interact() -> void:
	if player.activity_time > 0 or player.activity == "sit": return
	if nearest.begins_with("cat:"):
		for animal in kit.life.animals:
			if str(animal.body.get_instance_id()) == nearest.get_slice(":",1):
				if animal.friendly:
					kit.life.pet(animal)
					player.act("pet",animal.body.position,2.1)
					toast("A little trust, freely given.")
				return
	elif not nearest.is_empty():
		activities.interact(nearest)

func toast(text: String) -> void:
	notice.text = text
	notice_time = 3.5

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera.size = maxf(7,camera.size-1.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera.size = minf(46,camera.size+1.5)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE): yaw -= event.relative.x*.006
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				overview = not overview
				camera.size = 46 if overview else 23
			KEY_H: ui.visible = not ui.visible
			KEY_M:
				muted = not muted
				AudioServer.set_bus_mute(0,muted)
			KEY_R:
				player.activity = ""
				player.activity_time = 0
				player.collision_mask = 1
				player.velocity = Vector3.ZERO
				player.position = Vector3(0,.1,8.5)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var ignored := FileAccess.open("res://captures/.gdignore",FileAccess.WRITE)
	ignored.close()
	await get_tree().create_timer(3).timeout
	set_process(false)
	ui.hide()
	for view in [["arrival",Vector3(0,0,4),27.0],["overview",Vector3(0,0,-1),46.0],["pond",Vector3(-11,0,8.4),13.0],["smith",Vector3(-7.8,0,1),13.0],["research",Vector3(10,0,-2),13.0],["garden",Vector3(10,0,8),12.0]]:
		camera.size = view[2]
		camera.position = view[1]+Vector3(0,19,15)
		camera.look_at(view[1])
		await get_tree().create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/"+view[0]+".png")
		print("CAPTURE ",view[0])
	for action in ["pet","sit","water"]:
		var target := Vector3.ZERO
		if action == "pet":
			for animal in kit.life.animals:
				if animal.kind == "cat" and animal.friendly:
					player.position = animal.body.position+Vector3(0,0,.95)
					kit.life.pet(animal)
					player.act("pet",animal.body.position,2.1)
					target = animal.body.position+Vector3(0,.5,.35)
					break
		else:
			player.activity = ""
			player.activity_time = 0
			player.collision_mask = 1
			player.position = Vector3(7.2,.05,11.2) if action == "sit" else Vector3(8.25,.05,8.1)
			activities.interact(action)
			target = player.position+Vector3(0,.6,0)
		camera.size = 5.5
		camera.position = target+Vector3(4,5,7)
		camera.look_at(target)
		await get_tree().create_timer(.75).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/"+action+".png")
		print("CAPTURE ",action)
	get_tree().quit()

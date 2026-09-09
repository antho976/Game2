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
var sword_drawn:=false
var lock_mode:=0 # Aim-follow or hard target.
var lock_enabled:=true
var camera_mode := 0 # Overhead, first person, third person, far overhead.
var camera_distance := 15.0
var camera_height := 19.0
var camera_zoom := 23.0
var camera_fov := 75.0
var camera_pitch := 0.0
var camera_sensitivity := .003

func sync_camera_mouse() -> void:
	var duel: bool = is_instance_valid(combat) and combat.active and camera_mode==2 and not combat.cinematic.active()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if (camera_mode==1 or inside_school() or duel) and not input_blocked else Input.MOUSE_MODE_VISIBLE

var yaw := 0.0
var camera_target := Vector3(0,0,7)
var elapsed := 0.0
var overview := false
var input_blocked := false
var test_mode := false
var paused := false
var audio: AudioKit
var nearest := ""
var nearest_pos := Vector3.ZERO
var muted := false
var menus: CanvasLayer
var village_day: Node
var expedition: Node3D
var hub_subtitle: Label
var combat: Node3D
var equipment: Node
var inventory_menu: CanvasLayer
var smith_shop: CanvasLayer
var research: Node
var research_menu: CanvasLayer
var school: Node3D
var was_in_school := false
var doorway_fade: TextureRect

func blend_doorway_view() -> void:
	# Keep first person continuous. Blend the previous view for other projections.
	camera_target = player.position+Vector3(0,1 if camera_mode==2 else .1,0)
	if camera_mode==1 or input_blocked or DisplayServer.get_name()=="headless": return
	if is_instance_valid(doorway_fade): doorway_fade.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	doorway_fade = TextureRect.new()
	doorway_fade.texture = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	doorway_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	doorway_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(doorway_fade)
	var tween := create_tween()
	tween.tween_property(doorway_fade,"modulate:a",0.0,.32)
	tween.tween_callback(layer.queue_free)

func inside_school() -> bool:
	return is_instance_valid(school) and is_instance_valid(player) and school.contains(player.position)


func _ready() -> void:
	test_mode = "--targeting-test" in OS.get_cmdline_user_args() or "--inventory-test" in OS.get_cmdline_user_args() or "--expedition-test" in OS.get_cmdline_user_args() or "--expedition-capture" in OS.get_cmdline_user_args() or "--interaction-test" in OS.get_cmdline_user_args() or "--combat-test" in OS.get_cmdline_user_args() or "--school-test" in OS.get_cmdline_user_args() or "--research-test" in OS.get_cmdline_user_args() or "--shop-test" in OS.get_cmdline_user_args() or "--refresh-test" in OS.get_cmdline_user_args() or "--work-test" in OS.get_cmdline_user_args() or "--camera-test" in OS.get_cmdline_user_args() or "--player-visual" in OS.get_cmdline_user_args() or "--self-test" in OS.get_cmdline_user_args() or "--menu-test" in OS.get_cmdline_user_args() or "--polish-test" in OS.get_cmdline_user_args() or "--routine-test" in OS.get_cmdline_user_args() or "--village-capture" in OS.get_cmdline_user_args() or "--cleanup-test" in OS.get_cmdline_user_args()
	for spec in [["left",KEY_A],["right",KEY_D],["up",KEY_W],["down",KEY_S],["run",KEY_SHIFT],["interact",KEY_F]]:
		InputMap.add_action(spec[0])
		for code in spec.slice(1):
			var e := InputEventKey.new()
			e.physical_keycode = code
			InputMap.action_add_event(spec[0],e)
	audio = AudioKit.new()
	audio.game = self
	add_child(audio)
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
	school=load("res://scripts/schoolhouse.gd").new()
	world.add_child(school)
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
	camera.make_current()
	var hands := preload("res://scripts/first_person_hands.gd").new()
	hands.name = "FirstPersonHands"
	hands.game = self
	camera.add_child(hands)
	update_camera(1.0)
	build_ui()
	village_day = preload("res://scripts/village_day.gd").new()
	village_day.game = self
	add_child(village_day)
	village_day.build()
	equipment = preload("res://scripts/equipment.gd").new()
	equipment.game = self
	add_child(equipment)
	equipment.changed.connect(refresh_equipment)
	research = preload("res://scripts/research.gd").new()
	research.game = self
	add_child(research)
	menus = preload("res://scripts/menu.gd").new()
	menus.game = self
	add_child(menus)
	smith_shop = preload("res://scripts/blacksmith_shop.gd").new()
	smith_shop.game = self
	add_child(smith_shop)
	research_menu = preload("res://scripts/research_menu.gd").new()
	research_menu.game = self
	add_child(research_menu)
	combat=preload("res://scripts/combat.gd").new()
	combat.game=self
	add_child(combat)
	expedition=preload("res://scripts/dungeon/expedition.gd").new()
	expedition.game=self
	add_child(expedition)
	inventory_menu=preload("res://scripts/inventory_menu.gd").new()
	inventory_menu.game=self
	add_child(inventory_menu)
	if not test_mode and not "--capture" in OS.get_cmdline_user_args(): menus.show_home()
	audio.loop("music","music_hub",null,-25,{"bus":"Music"})
	audio.loop("pond","amb_pond",Vector3(-12,.5,8.7),-17,{"max_distance":12})
	audio.loop("forge","amb_forge",Vector3(-9,1,0),-18,{"max_distance":9})
	audio.loop("spring","amb_spring",Vector3(-15.15,.35,8.4),-20,{"max_distance":6})
	audio.loop("washing","amb_washing_line",Vector3(-9.05,1.6,-5.5),-24,{"max_distance":5})
	if "--capture" in OS.get_cmdline_user_args(): capture()
	if "--runtime-probe" in OS.get_cmdline_user_args():
		var probe := preload("res://tests/runtime_probe.gd").new()
		add_child(probe)
	if "--targeting-test" in OS.get_cmdline_user_args():
		var suite=load("res://tests/targeting_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--inventory-test" in OS.get_cmdline_user_args():
		var suite=load("res://tests/inventory_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--expedition-test" in OS.get_cmdline_user_args() or "--expedition-capture" in OS.get_cmdline_user_args():
		var suite=load("res://tests/expedition_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--interaction-test" in OS.get_cmdline_user_args():
		var suite=load("res://tests/interaction_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--combat-test" in OS.get_cmdline_user_args():
		var suite=load("res://tests/combat_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--school-test" in OS.get_cmdline_user_args():
		var suite = load("res://tests/school_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--research-test" in OS.get_cmdline_user_args():
		var suite = load("res://tests/research_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--shop-test" in OS.get_cmdline_user_args():
		var suite = load("res://tests/shop_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--refresh-test" in OS.get_cmdline_user_args():
		var suite = load("res://tests/refresh_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--work-test" in OS.get_cmdline_user_args():
		var suite = load("res://tests/work_test.gd").new()
		add_child(suite)
		suite.run(self)
	if "--camera-test" in OS.get_cmdline_user_args():
		var suite = load("res://tests/camera_test.gd").new()
		add_child(suite)
		suite.run(self)
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

func play_sound(id: String,pos: Vector3,_channel := "",cooldown := 0.0,volume := -16.0) -> void:
	audio.play(id,pos,volume,{"cooldown":cooldown,"max_distance":18})

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
	hub_subtitle=label("A quiet place to return to",13,Color(.83,.85,.79),Vector2(30,49))
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
	if was_in_school != inside_school():
		was_in_school = inside_school()
		blend_doorway_view()
		sync_camera_mouse()
		# The doorway: outdoor air gives way to the room, or the room opens onto the yard.
		audio.play("door_open",player.position,-14,{"cooldown":.5})
		if was_in_school: audio.loop("school","amb_school_room",null,-22,{"fade_in":true})
		else: audio.stop("school",.6)
	# Menus, the shop, the archive and the lesson pull the village behind a low-pass.
	audio.set_ducked((input_blocked and not (is_instance_valid(menus) and menus.home)) or (is_instance_valid(combat) and combat.skill_panel.visible))
	update_camera(delta)
	if is_instance_valid(combat):
		prompt.offset_top=-124
		prompt.offset_bottom=-84
	notice_time = maxf(0,notice_time-delta)
	notice.modulate.a = minf(notice_time,1)
	if input_blocked: return
	update_interaction()
	if Input.is_action_just_pressed("interact") and not input_blocked:
		interact()

func update_camera(delta: float) -> void:
	if is_instance_valid(menus) and is_instance_valid(menus.classroom) and menus.classroom.active:
		player.model.visible=player.visible
		return
	var title: bool = menus != null and menus.home
	if is_instance_valid(combat) and combat.cinematic.active():
		# The execution frames itself; the player's own body is in the shot.
		player.model.visible = true
		combat.cinematic.place_camera(camera,delta)
		return
	player.model.visible = (camera_mode!=1 and not inside_school()) or title or overview
	if title or overview:
		if title: yaw += delta*.055
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 43 if title else 46
		camera_target = camera_target.lerp(Vector3(0,.1,-.5),1-exp(-delta*7))
		camera.position = camera_target+Vector3(0,19,15).rotated(Vector3.UP,yaw)
		camera.look_at(camera_target)
		return
	if inside_school() and camera_mode!=1 and not title and not overview:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 75
		camera.near = .04
		camera.position = player.position+Vector3(0,1.65,0)
		camera.rotation = Vector3(camera_pitch,yaw,0)
		return
	if camera_mode==1:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = camera_fov
		camera.near = .04
		camera.position = player.position+Vector3(0,camera_height,0)
		camera.rotation = Vector3(camera_pitch,yaw,0)
		return
	var target: Vector3 = player.position+Vector3(0,1 if camera_mode==2 else .1,0)
	camera_target = camera_target.lerp(target,1-exp(-delta*7))
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE if camera_mode==2 else Camera3D.PROJECTION_ORTHOGONAL
	camera.fov = camera_fov
	camera.near = .1
	camera.size = minf(camera_zoom,13.0) if is_instance_valid(combat) and combat.active else camera_zoom
	var desired := camera_target+Vector3(0,camera_height,camera_distance).rotated(Vector3.UP,yaw)
	if camera_mode==2:
		var query := PhysicsRayQueryParameters3D.create(camera_target,desired,1,[player.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): desired = hit.position+(camera_target-hit.position).normalized()*.25
	camera.position = desired
	camera.look_at(camera_target)

func update_interaction() -> void:
	if is_instance_valid(expedition):
		if expedition.active:
			nearest="expedition"
			prompt.text=expedition.interaction_text()
			return
		if expedition.at_gate():
			nearest="mine_portal"
			prompt.text="F  ·  Enter the Spent Works"
			return
	nearest = ""
	if is_instance_valid(combat) and (combat.active or player.position.distance_to(combat.CENTER)<4.5):
		nearest="sparring"
		# There is no yielding once blades are out: the bout ends when one fighter falls.
		prompt.text="" if combat.active else "F  ·  Challenge the swordsman     K  ·  Combat skills"
		return
	if inside_school():
		if player.position.distance_to(school.teacher.global_position)<2.8:
			nearest="teacher"
			prompt.text="F  ·  Talk to the teacher"
		else: prompt.text="The door is open. Stay as long as you wish."
		return
	# Services are deliberate interactions. Ambient pets must never steal their key.
	var closest_service := 2.8
	var service_text := ""
	for service in world.interactions:
		if service.id not in ["smith","archive"]: continue
		var distance: float=player.position.distance_to(service.pos)
		if distance<closest_service:
			closest_service=distance
			nearest=service.id
			service_text="F  ·  Blacksmith shop" if service.id=="smith" else "F  ·  Research archive"
	if not nearest.is_empty():
		prompt.text=service_text if player.activity_time<=0 else ""
		return
	var best := 2.3
	var text := ""
	for animal in kit.life.animals:
		if animal.kind != "cat" or not animal.friendly: continue
		var distance: float = player.position.distance_to(animal.body.position)
		if distance < 1.9 and distance < best:
			best = distance
			nearest = "cat:"+str(animal.body.get_instance_id())
			nearest_pos = animal.body.position
			text = "F  ·  Pet the cat"
	for point in activities.points:
		var distance: float = player.position.distance_to(point.pos)
		if distance < point.radius and distance < best:
			best = distance
			nearest = point.id
			nearest_pos = point.pos
			text = "F  ·  "+point.text
	if nearest.is_empty():
		for service in world.interactions:
			if player.position.distance_to(service.pos) < 2.8:
				text = service.text
				if service.id=="archive":
					nearest = "archive"
					text = "F  ·  Research archive"
				if service.id=="smith":
					nearest = "smith"
					text = "F  ·  Blacksmith shop"
	prompt.text = "Move to stand up" if player.activity == "sit" else (text if player.activity_time <= 0 else "")

func interact() -> void:
	if nearest=="expedition":
		expedition.interact()
		return
	if nearest=="mine_portal":
		expedition.enter()
		return
	if nearest=="sparring":
		if not combat.active: combat.start()
		return
	if player.activity_time > 0 or player.activity == "sit": return
	if nearest=="teacher":
		if is_instance_valid(menus.classroom): menus.classroom.ask()
		else: menus.play_classroom(false)
		return
	if nearest=="archive":
		research_menu.open()
		return
	if nearest=="smith":
		smith_shop.open()
		return
	if nearest.begins_with("cat:"):
		for animal in kit.life.animals:
			if str(animal.body.get_instance_id()) == nearest.get_slice(":",1):
				if animal.friendly:
					kit.life.pet(animal)
					player.act("pet",animal.body.position,2.1)
					audio.play("pet_cat_hand",animal.body.position,-16)
					toast("A little trust, freely given.")
				return
	elif not nearest.is_empty():
		activities.interact(nearest)

func toast(text: String) -> void:
	notice.text = text
	notice_time = 3.5
	if not (is_instance_valid(combat) and combat.active): audio.ui("ui_toast",-20)

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and (camera_mode==1 or inside_school()): sync_camera_mouse()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: adjust_camera_zoom(-1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: adjust_camera_zoom(1)
	if event is InputEventMouseMotion:
		if (camera_mode==1 or inside_school()) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
			if not (combat.active and lock_mode==1 and lock_enabled): yaw -= event.relative.x*camera_sensitivity
			if not (combat.active and lock_mode==1 and lock_enabled): camera_pitch = clampf(camera_pitch-event.relative.y*camera_sensitivity,-1.35,1.35)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and not (combat.active and lock_mode==1 and lock_enabled): yaw -= event.relative.x*.006
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				if is_instance_valid(expedition) and expedition.active:return
				overview = not overview
				camera.size = 46 if overview else 23
			KEY_H: ui.visible = not ui.visible
			KEY_M:
				muted = not muted
				AudioServer.set_bus_mute(0,muted)
				if not muted: audio.ui("ui_click")
			KEY_F6:
				if is_instance_valid(expedition) and expedition.active:return
				if not combat.active:
					player.position=combat.CENTER+Vector3(0,.1,2)
					player.last_safe=player.position
					camera_target=player.position
					combat.start()
			KEY_R:
				if is_instance_valid(expedition) and expedition.active:return
				player.activity = ""
				player.activity_time = 0
				player.collision_mask = 5
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
			player.collision_mask = 5
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

func adjust_camera_zoom(direction: float) -> void:
	if camera_mode==1: return
	if camera_mode==2:
		camera_distance = clampf(camera_distance+direction*.5,1,16)
		menus.store_option("camera_distance",camera_distance)
	else:
		camera_zoom = clampf(camera_zoom+direction*1.5,7,60)
		menus.store_option("camera_zoom",camera_zoom)

func refresh_equipment() -> void:
	if not is_instance_valid(player): return
	var loadout := {}
	for slot in equipment.equipped:
		var entry: Dictionary = equipment.owned(equipment.equipped[slot])
		if not entry.is_empty(): loadout[slot] = GearCatalog.find(entry.id)
	GearVisuals.apply(player.model,loadout)
	var hands = camera.get_node_or_null("FirstPersonHands") if is_instance_valid(camera) else null
	if hands!=null and is_instance_valid(hands.arms):
		GearVisuals.apply(hands.arms,{"gloves":loadout.gloves} if loadout.has("gloves") else {})
		hands.set_weapon(loadout.get("weapon",{}) if sword_drawn else {})
	if is_instance_valid(combat) and combat.is_inside_tree():combat.refresh_weapon()

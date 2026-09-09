extends CanvasLayer
# Menus keep the village alive while blocking only player controls.
var game: Node3D
var home := false
var active := false
var started := false
var root: Control
var box: VBoxContainer
var settings := ConfigFile.new()
var save_path := "user://hub_save.cfg"
var settings_path := "user://settings.cfg"
var save_clock := 0.0
var window_size := Vector2i(1440,900)
var window_position := Vector2i.ZERO
var display_choice: OptionButton
var confirm: ConfirmationDialog
var panel: PanelContainer
var fps_label: Label
var fps_clock := 0.0

func _ready() -> void:
	layer = 10
	if game.test_mode:
		save_path = "user://test_hub_save.cfg"
		settings_path = "user://test_settings.cfg"
	settings.load(settings_path)
	build()
	root.hide()
	apply_settings()
	get_tree().auto_accept_quit = false

func build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(.025,.045,.037,.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 48
	panel.offset_right = 468
	panel.offset_top = 48
	panel.offset_bottom = -48
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.035,.065,.056,.94)
	style.border_color = Color(.55,.53,.36,.6)
	style.set_border_width_all(1)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 32
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel",style)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",12)
	scroll.add_child(box)
	var theme := Theme.new()
	theme.default_font_size = 18
	for state in ["normal","hover","pressed","focus"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color(.17,.23,.18) if state != "normal" else Color(.09,.14,.115)
		button_style.border_color = Color(.7,.65,.44)
		button_style.set_border_width_all(1 if state == "focus" else 0)
		button_style.content_margin_left = 18
		button_style.content_margin_right = 18
		theme.set_stylebox(state,"Button",button_style)
	root.theme = theme
	fps_label = Label.new()
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -170
	fps_label.offset_right = -24
	fps_label.offset_top = 20
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.add_theme_font_size_override("font_size",18)
	fps_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	fps_label.add_theme_constant_override("shadow_offset_x",2)
	fps_label.add_theme_constant_override("shadow_offset_y",2)
	add_child(fps_label)
	fps_label.visible = settings.get_value("options","show_fps",false)
	confirm = ConfirmationDialog.new()
	confirm.title = "Start a new game?"
	confirm.dialog_text = "This replaces your saved hub visit."
	confirm.confirmed.connect(new_game)
	root.add_child(confirm)

func clear(title: String, subtitle: String) -> void:
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 48
	panel.offset_right = 468
	panel.offset_top = 48
	panel.offset_bottom = -48
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	text("G A M E 2   /   H U B  S T U D Y",12)
	text(title,38)
	text(subtitle,16)
	var space := Control.new()
	space.custom_minimum_size.y = 18
	box.add_child(space)

func text(value: String, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color(.91,.88,.75))
	box.add_child(label)

func button(value: String, callback: Callable, disabled := false) -> Button:
	var node := Button.new()
	node.text = value
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.custom_minimum_size.y = 48
	node.disabled = disabled
	node.pressed.connect(callback)
	box.add_child(node)
	return node

func open() -> void:
	active = true
	game.input_blocked = true
	game.sync_camera_mouse()
	game.ui.hide()
	root.show()

func show_home() -> void:
	home = true
	open()
	clear("The village", "A quiet place to return to.")
	var saved := ConfigFile.new()
	var available := saved.load(save_path) == OK and saved.get_value("hub","position") is Vector3
	var cont := button("Continue",continue_game,not available)
	var fresh := button("New Game",request_new)
	button("Options",show_options)
	button("Quit",quit_game)
	text("Explore, linger, and make yourself at home.\n\nUnarmed hub prototype",14)
	if available: cont.grab_focus()
	else: fresh.grab_focus()

func show_pause() -> void:
	home = false
	open()
	clear("Take a breath", "Your place in the village is saved automatically.")
	button("Resume",resume).grab_focus()
	button("Options",show_options)
	button("Save & Main Menu",func(): save_game(); show_home())
	button("Save & Quit",quit_game)

func resume() -> void:
	home = false
	active = false
	started = true
	root.hide()
	game.ui.show()
	game.input_blocked = false
	game.overview = false
	game.sync_camera_mouse()

func request_new() -> void:
	if FileAccess.file_exists(save_path): confirm.popup_centered(Vector2i(440,160))
	else: new_game()

func reset_player(pos: Vector3) -> void:
	game.player.activity = ""
	game.player.activity_time = 0
	game.player.collision_mask = 1
	game.player.velocity = Vector3.ZERO
	game.player.position = pos
	game.player.last_safe = pos
	game.yaw = 0
	game.camera_target = pos

func new_game() -> void:
	if is_instance_valid(game.research_menu):
		game.research_menu.toast_time=0
		game.research_menu.toast_panel.hide()
	game.research.restore({})
	game.equipment.restore({})
	reset_player(Vector3(0,.1,8.5))
	game.activities.watered = false
	game.village_day.clock = 270.0
	for animal in game.kit.life.animals:
		if animal.kind == "cat": animal.pets = 0
	resume()
	save_game()

func continue_game() -> void:
	var data := ConfigFile.new()
	if data.load(save_path) != OK: return
	var pos: Vector3 = data.get_value("hub","position",Vector3(0,.1,8.5))
	if not pos.is_finite() or (pos.x < -19 or pos.x > 26) or absf(pos.z)>24 or pos.y < -1 or pos.y > 5: pos = Vector3(0,.1,8.5)
	reset_player(pos)
	game.equipment.restore(data.get_value("equipment","state",{}))
	game.research.restore(data.get_value("research","state",{}))
	game.activities.watered = data.get_value("hub","watered",false)
	game.village_day.clock = float(data.get_value("hub","clock",270.0))
	resume()
	game.research.apply_offline()
	game.research_menu.show_unread()

func save_game() -> Error:
	if not started: return ERR_UNAVAILABLE
	var data := ConfigFile.new()
	var pos: Vector3 = game.player.seat_exit if game.player.activity == "sit" else game.player.last_safe
	data.set_value("hub","position",pos)
	data.set_value("hub","watered",game.activities.watered)
	data.set_value("hub","clock",game.village_day.clock)
	data.set_value("equipment","state",game.equipment.snapshot())
	data.set_value("research","state",game.research.snapshot())
	var error := data.save(save_path+".tmp")
	if error==OK: error = DirAccess.rename_absolute(save_path+".tmp",save_path)
	if error != OK: game.toast("Could not save this visit.")
	return error

func quit_game() -> void:
	save_game()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	fps_clock += delta
	if fps_clock > .25:
		fps_clock = 0
		fps_label.text = str(int(Engine.get_frames_per_second()))+" FPS"
	if started and not active:
		save_clock += delta
		if save_clock > 15:
			save_clock = 0
			save_game()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE:
			if is_instance_valid(game.research_menu) and game.research_menu.active: return
			if is_instance_valid(game.smith_shop) and game.smith_shop.active: return
			if confirm.visible: confirm.hide()
			elif active:
				if home: show_home()
				else: resume()
			else: show_pause()
			get_viewport().set_input_as_handled()

func store_option(key: String, value: Variant) -> void:
	settings.set_value("options",key,value)
	settings.save(settings_path)

func set_fullscreen(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless": return
	if enabled:
		window_size = DisplayServer.window_get_size()
		if DisplayServer.get_name() == "X11": window_position = DisplayServer.window_get_position()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(window_size)
		if DisplayServer.get_name() == "X11": DisplayServer.window_set_position(window_position)
	store_option("fullscreen",enabled)
	if is_instance_valid(display_choice): display_choice.select(1 if enabled else 0)

func apply_settings() -> void:
	apply_camera_settings()
	AudioServer.set_bus_volume_db(0,linear_to_db(float(settings.get_value("options","volume",.8))))
	Engine.max_fps = int(settings.get_value("options","fps",60))
	get_viewport().scaling_3d_scale = float(settings.get_value("options","scale",.85))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.get_value("options","vsync",true) else DisplayServer.VSYNC_DISABLED)
		if settings.get_value("options","fullscreen",false): set_fullscreen(true)

func show_options() -> void:
	clear("Options", "Display, camera and sound")
	button("Camera",show_camera_options)
	# Dedicated centered page, separate from the title / pause navigation.
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -385
	panel.offset_bottom = 385
	var counter := CheckButton.new()
	counter.text = "Show FPS counter"
	counter.button_pressed = settings.get_value("options","show_fps",false)
	counter.toggled.connect(func(value): fps_label.visible = value; store_option("show_fps",value))
	box.add_child(counter)
	text("Display mode  ·  F11 to toggle",15)
	display_choice = OptionButton.new()
	display_choice.add_item("Windowed")
	display_choice.add_item("Borderless fullscreen")
	display_choice.select(1 if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else 0)
	display_choice.item_selected.connect(func(index): set_fullscreen(index == 1))
	box.add_child(display_choice)
	text("Frame limit",15)
	var fps := OptionButton.new()
	var caps := [60,90,120,144,165,240,0]
	for cap in caps: fps.add_item("Unlimited" if cap == 0 else str(cap)+" FPS")
	fps.select(maxi(0,caps.find(Engine.max_fps)))
	fps.item_selected.connect(func(index): Engine.max_fps = caps[index]; store_option("fps",caps[index]))
	box.add_child(fps)
	var vsync := CheckButton.new()
	vsync.text = "VSync"
	vsync.button_pressed = settings.get_value("options","vsync",true)
	vsync.toggled.connect(func(value): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED); store_option("vsync",value))
	box.add_child(vsync)
	text("3D resolution  ·  UI stays sharp",15)
	var scale_option := OptionButton.new()
	var scales := [.67,.85,1.0]
	for value in ["67%  ·  Performance","85%  ·  Balanced","100%  ·  Native"]: scale_option.add_item(value)
	scale_option.select(maxi(0,scales.find(float(settings.get_value("options","scale",.85)))))
	scale_option.item_selected.connect(func(index): get_viewport().scaling_3d_scale = scales[index]; store_option("scale",scales[index]))
	box.add_child(scale_option)
	text("Master volume",15)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = .01
	volume.value = float(settings.get_value("options","volume",.8))
	volume.value_changed.connect(func(value): game.muted = false; AudioServer.set_bus_mute(0,false); AudioServer.set_bus_volume_db(0,linear_to_db(value)); store_option("volume",value))
	box.add_child(volume)
	button("Back",func():
		if home: show_home()
		else: show_pause()
	).grab_focus()

func apply_camera_settings() -> void:
	game.camera_mode = clampi(int(settings.get_value("options","camera_mode",0)),0,3)
	game.camera_distance = clampf(float(settings.get_value("options","camera_distance",15)),1,40)
	game.camera_height = clampf(float(settings.get_value("options","camera_height",19)),.8,45)
	game.camera_zoom = clampf(float(settings.get_value("options","camera_zoom",23)),7,60)
	game.camera_fov = clampf(float(settings.get_value("options","camera_fov",75)),50,105)
	game.camera_sensitivity = clampf(float(settings.get_value("options","camera_sensitivity",.003)),.001,.008)

func camera_preset(mode: int) -> void:
	store_option("camera_mode",mode)
	var presets := [[15,19,23],[1,1.65,23],[5,2.5,23],[25,32,43]]
	store_option("camera_distance",presets[mode][0])
	store_option("camera_height",presets[mode][1])
	store_option("camera_zoom",presets[mode][2])
	game.camera_pitch = 0
	game.overview = false
	apply_camera_settings()
	game.sync_camera_mouse()

func camera_slider(title: String,key: String,low: float,high: float,step: float) -> void:
	var label := Label.new()
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(settings.get_value("options",key,game.get(key)))
	label.text = title+"  ·  "+str(snappedf(slider.value,step))
	box.add_child(label)
	box.add_child(slider)
	slider.value_changed.connect(func(value):
		label.text = title+"  ·  "+str(snappedf(value,step))
		store_option(key,value)
		apply_camera_settings()
	)

func show_camera_options() -> void:
	clear("Camera", "Changes apply immediately and save automatically.")
	var mode := OptionButton.new()
	for title in ["Overhead","First person","Third person","Far overhead"]: mode.add_item(title)
	mode.select(game.camera_mode)
	box.add_child(mode)
	mode.item_selected.connect(func(index): camera_preset(index); show_camera_options())
	if game.camera_mode==1:
		camera_slider("Eye height","camera_height",1,2.1,.05)
		camera_slider("Field of view","camera_fov",50,105,1)
		camera_slider("Mouse sensitivity","camera_sensitivity",.001,.008,.0005)
		text("Mouse to look. Esc releases the mouse and opens the menu.",15)
	else:
		camera_slider("Distance","camera_distance",1,16 if game.camera_mode==2 else 40,.5)
		camera_slider("Height above target","camera_height",.8,10 if game.camera_mode==2 else 45,.1)
		if game.camera_mode==2: camera_slider("Field of view","camera_fov",50,105,1)
		else: camera_slider("Zoom / visible area","camera_zoom",7,60,.5)
		text("Hold middle mouse to rotate. Mouse wheel adjusts zoom or third-person distance.",15)
	button("Reset this camera",func(): camera_preset(game.camera_mode); show_camera_options())
	button("Back",show_options)

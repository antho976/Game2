extends CanvasLayer
# The forge storefront: an armory screen built from drawn gear icons, framed
# item cards, stat bars and a lit fitting room, all generated at runtime.
var game: Node
var active := false
var root: Control
var rows: GridContainer
var rows_scroll: ScrollContainer
var detail: VBoxContainer
var balance: Label
var level_label: Label
var status: Label
var status_dot: Panel
var tabs: HBoxContainer
var tab_buttons := {}
var filters: HBoxContainer
var filter_buttons := {}
var preview: Node3D
var page := "stock"
var selected_id := "warden_blade"
var selected_uid := 0
var filter_slot := "all"
var confirm: ConfirmationDialog
var pending_uid := 0
var pending_rank := 0
const GOLD := Color(.87,.71,.37)
const PARCH := Color(.91,.87,.75)
const MUTED := Color(.63,.65,.59)
const EMBER := Color(.94,.60,.36)
const GOOD := Color(.56,.83,.48)
const BAD := Color(.91,.44,.37)
const TIERS := {"warden":["Common",Color(.82,.82,.78)],"pilgrim":["Fine",Color(.58,.84,.50)],"citadel":["Rare",Color(.48,.70,.97)]}
const SLOT_NAMES := {"all":"All","weapon":"Swords","helmet":"Helms","chest":"Cuirasses","gloves":"Gauntlets","boots":"Greaves"}
const SLOT_SINGULAR := {"weapon":"Sword","helmet":"Helm","chest":"Cuirass","gloves":"Gauntlets","boots":"Greaves"}
const STAT_NAMES := {"damage":"Damage","speed":"Attack speed","stamina":"Stamina cost","protection":"Protection","weight":"Weight"}
const STAT_MAX := {"damage":70.0,"speed":1.3,"stamina":40.0,"protection":26.0,"weight":12.0}
const STAT_COLORS := {"damage":Color(.94,.56,.34),"speed":Color(.62,.82,.96),"stamina":Color(.80,.68,.40),"protection":Color(.56,.76,.96),"weight":Color(.66,.63,.58)}
const LOWER_BETTER := ["stamina","weight"]
# Button skins: normal, hover, pressed, border, font.
const SKINS := {
	"primary":[Color(.74,.55,.20),Color(.85,.66,.27),Color(.60,.44,.15),Color(.97,.83,.50,.55),Color(.13,.08,.02)],
	"secondary":[Color(.10,.15,.13),Color(.16,.23,.19),Color(.08,.12,.10),Color(.72,.60,.32,.55),Color(.91,.87,.75)],
	"danger":[Color(.53,.19,.11),Color(.65,.26,.14),Color(.42,.15,.09),Color(.96,.56,.36,.6),Color(1,.93,.86)],
	"ghost":[Color(0,0,0,0),Color(1,1,1,.06),Color(1,1,1,.03),Color(0,0,0,0),Color(.63,.65,.59)]}
static func tier_of(id: String) -> Array:
	return TIERS.get(id.get_slice("_",0),TIERS.warden)
static func flat(bg: Color,border := Color(0,0,0,0),width := 0,radius := 6,pad := Vector2(12,8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	return s
func skin(button: Button,kind: String,radius := 6,pad := Vector2(18,8)) -> void:
	var spec: Array = SKINS[kind]
	for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		var bg: Color = spec[{"hover":1,"pressed":2,"hover_pressed":2}.get(state,0)]
		var border: Color = spec[3]
		if state=="disabled":
			bg = Color(.12,.12,.11,.9)
			border = Color(1,1,1,.08)
		button.add_theme_stylebox_override(state,flat(bg,border,1,radius,pad))
	button.add_theme_color_override("font_color",spec[4])
	for name in ["font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]: button.add_theme_color_override(name,spec[4].lightened(.08))
	button.add_theme_color_override("font_disabled_color",Color(.48,.46,.42))
	button.focus_mode = Control.FOCUS_NONE
func label_in(parent: Node,text: String,size := 16,color := PARCH) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label
func button_in(parent: Node,title: String,callback: Callable,disabled := false,kind := "secondary") -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 46 if kind!="ghost" else 40
	button.disabled = disabled
	button.pressed.connect(callback)
	button.add_theme_font_size_override("font_size",17 if kind=="primary" or kind=="danger" else 15)
	skin(button,kind)
	parent.add_child(button)
	return button
func panel_in(parent: Node,style: StyleBox) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	return panel
func chip(parent: Node,text: String,color: Color) -> Label:
	var panel := panel_in(parent,flat(Color(color.r,color.g,color.b,.14),Color(color.r,color.g,color.b,.45),1,10,Vector2(9,2)))
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := label_in(panel,text,12,color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.uppercase = true
	return label
func divider(parent: Node) -> void:
	var line := ColorRect.new()
	line.color = Color(GOLD.r,GOLD.g,GOLD.b,.28)
	line.custom_minimum_size.y = 1
	parent.add_child(line)
func spacer(parent: Node,height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)
func heading(parent: Node,text: String) -> void:
	var label := label_in(parent,text,12,GOLD)
	label.uppercase = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
func passthrough(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): passthrough(child)
func gradient_rect(parent: Node,colors: Array,radial: bool,from: Vector2,to: Vector2) -> TextureRect:
	var texture := GradientTexture2D.new()
	texture.gradient = Gradient.new()
	texture.gradient.set_color(0,colors[0])
	texture.gradient.set_color(1,colors[-1])
	if colors.size()>2: texture.gradient.add_point(.5,colors[1])
	texture.fill = GradientTexture2D.FILL_RADIAL if radial else GradientTexture2D.FILL_LINEAR
	texture.fill_from = from
	texture.fill_to = to
	texture.width = 128
	texture.height = 128
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect
func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color","Label",PARCH)
	theme.set_stylebox("panel","AcceptDialog",flat(Color(.07,.075,.07),Color(GOLD.r,GOLD.g,GOLD.b,.6),1,8,Vector2(18,14)))
	var window := flat(Color(.10,.095,.08),Color(GOLD.r,GOLD.g,GOLD.b,.6),1,8,Vector2.ZERO)
	window.expand_margin_top = 34
	theme.set_stylebox("embedded_border","Window",window)
	theme.set_stylebox("embedded_unfocused_border","Window",window)
	theme.set_color("title_color","Window",GOLD)
	theme.set_font_size("title_font_size","Window",17)
	var spec: Array = SKINS.secondary
	for state in ["normal","hover","pressed","focus"]:
		theme.set_stylebox(state,"Button",flat(spec[1] if state!="normal" else spec[0],spec[3],1,6,Vector2(18,8)))
	theme.set_color("font_color","Button",spec[4])
	root.theme = theme
	var shade := ColorRect.new()
	shade.color = Color(.022,.024,.024)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	gradient_rect(root,[Color(.24,.12,.05),Color(.08,.05,.035),Color(.025,.028,.03)],true,Vector2(.5,1.05),Vector2(.5,.15))
	gradient_rect(root,[Color(0,0,0,0),Color(0,0,0,.62)],true,Vector2(.5,.5),Vector2(.5,1.05))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,22)
	root.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	margin.add_child(body)
	# Header bar: title, purse, level and the way out.
	var header_style := flat(Color(.045,.05,.045,.9),Color(.72,.58,.30,.55),0,8,Vector2(22,10))
	header_style.border_width_bottom = 2
	var header := panel_in(body,header_style)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation",14)
	header.add_child(header_row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation",0)
	header_row.add_child(title_box)
	var title := label_in(title_box,"THE BLACKSMITH",30,GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var subtitle := label_in(title_box,"Forge & armory  ·  Buy, fit and temper your gear",13,MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	var purse := panel_in(header_row,flat(Color(.14,.11,.05,.92),Color(.74,.58,.28,.6),1,16,Vector2(14,6)))
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var purse_row := HBoxContainer.new()
	purse_row.add_theme_constant_override("separation",8)
	purse.add_child(purse_row)
	var coin := GearIcon.new()
	coin.slot = "coin"
	coin.custom_minimum_size = Vector2(20,20)
	purse_row.add_child(coin)
	balance = label_in(purse_row,"0",19,GOLD)
	balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	var level_panel := panel_in(header_row,flat(Color(.08,.11,.10,.92),Color(.55,.62,.50,.5),1,16,Vector2(14,6)))
	level_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_label = label_in(level_panel,"Level 1",17,PARCH)
	level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var leave := button_in(header_row,"Leave  ·  Esc",close)
	leave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Tabs on the left, slot filters on the right.
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation",12)
	body.add_child(nav)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation",4)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(tabs)
	for tab in [["stock","Buy equipment"],["owned","Your equipment"],["upgrade","The anvil"]]:
		var button := button_in(tabs,tab[1],func(): page=tab[0]; selected_uid=0; refresh(),false,"ghost")
		button.add_theme_font_size_override("font_size",16)
		tab_buttons[tab[0]] = button
	filters = HBoxContainer.new()
	filters.add_theme_constant_override("separation",6)
	nav.add_child(filters)
	for slot in ["all"]+GearCatalog.SLOTS:
		var button := Button.new()
		button.text = SLOT_NAMES[slot]
		button.custom_minimum_size.y = 36
		button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(func(): filter_slot=slot; refresh())
		if slot!="all":
			var icon := GearIcon.new()
			icon.slot = slot
			icon.tier = 0
			icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
			icon.offset_left = 10
			icon.offset_right = 30
			icon.offset_top = -10
			icon.offset_bottom = 10
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(icon)
		filters.add_child(button)
		filter_buttons[slot] = button
	# Three columns: the racks, the appraisal and the fitting room.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var racks := panel_in(columns,flat(Color(.045,.05,.048,.82),Color(GOLD.r,GOLD.g,GOLD.b,.22),1,10,Vector2(10,10)))
	racks.custom_minimum_size.x = 330
	racks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	racks.size_flags_stretch_ratio = 1.25
	rows_scroll = ScrollContainer.new()
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	racks.add_child(rows_scroll)
	rows = GridContainer.new()
	rows.columns = 3
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("h_separation",8)
	rows.add_theme_constant_override("v_separation",8)
	rows_scroll.add_child(rows)
	rows_scroll.resized.connect(fit_columns)
	var appraisal := panel_in(columns,flat(Color(.06,.065,.06,.94),Color(GOLD.r,GOLD.g,GOLD.b,.45),1,10,Vector2(20,18)))
	appraisal.custom_minimum_size.x = 380
	appraisal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	appraisal.size_flags_stretch_ratio = 1.0
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	appraisal.add_child(detail_scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",10)
	detail_scroll.add_child(detail)
	var fitting := panel_in(columns,flat(Color(.05,.05,.048,.94),Color(GOLD.r,GOLD.g,GOLD.b,.45),1,10,Vector2(12,12)))
	fitting.custom_minimum_size.x = 300
	fitting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fitting.size_flags_stretch_ratio = .8
	var visual := VBoxContainer.new()
	visual.add_theme_constant_override("separation",8)
	fitting.add_child(visual)
	heading(visual,"Fitting room")
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",flat(Color(.03,.03,.03),Color(GOLD.r,GOLD.g,GOLD.b,.3),1,6,Vector2(2,2)))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual.add_child(frame)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(240,300)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.stretch = true
	frame.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(380,580)
	viewport.own_world_3d = true
	container.add_child(viewport)
	build_fitting_room(viewport)
	var ornament := Ornament.new()
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(ornament)
	var hint := label_in(visual,"Drag to turn. Trying gear on never buys or equips it.",12,MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.gui_input.connect(func(event):
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): preview.rotation.y+=event.relative.x*.012
	)
	# The smith's word: a message strip along the bottom.
	var strip := panel_in(body,flat(Color(.07,.07,.065,.92),Color(GOLD.r,GOLD.g,GOLD.b,.3),1,8,Vector2(16,8)))
	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation",10)
	strip.add_child(strip_row)
	status_dot = Panel.new()
	status_dot.custom_minimum_size = Vector2(9,9)
	status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_dot.add_theme_stylebox_override("panel",flat(GOLD,Color(0,0,0,0),0,5,Vector2.ZERO))
	strip_row.add_child(status_dot)
	status = label_in(strip_row,"Gold and levels will come from progression. Combat comes later.",14,MUTED)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm = ConfirmationDialog.new()
	confirm.title = "Risk this item?"
	confirm.ok_button_text = "Attempt upgrade"
	confirm.confirmed.connect(attempt_upgrade)
	skin(confirm.get_ok_button(),"danger")
	skin(confirm.get_cancel_button(),"secondary")
	root.add_child(confirm)
	root.hide()
	preview.process_mode = Node.PROCESS_MODE_DISABLED
func build_fitting_room(viewport: SubViewport) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.035,.032,.03)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.78,.72,.66)
	env.environment.ambient_light_energy = .55
	viewport.add_child(env)
	# A warm pool of light behind the stand, like a lamp on the smithy wall.
	var backdrop := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(9,12)
	backdrop.mesh = quad
	backdrop.position = Vector3(0,1.3,-3)
	var glow := GradientTexture2D.new()
	glow.gradient = Gradient.new()
	glow.gradient.set_color(0,Color(.30,.19,.10))
	glow.gradient.add_point(.45,Color(.10,.075,.055))
	glow.gradient.set_color(1,Color(.035,.032,.03))
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(.5,.56)
	glow.fill_to = Vector2(.5,1.0)
	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.albedo_texture = glow
	backdrop.material_override = glow_material
	viewport.add_child(backdrop)
	var pedestal := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = .78
	disc.bottom_radius = .9
	disc.height = .09
	pedestal.mesh = disc
	pedestal.position.y = -.045
	pedestal.material_override = GearVisuals.material(Color(.13,.12,.11),.25)
	viewport.add_child(pedestal)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = .74
	torus.outer_radius = .80
	ring.mesh = torus
	ring.position.y = .0
	ring.material_override = GearVisuals.material(Color(.60,.45,.20),.8)
	viewport.add_child(ring)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38,-32,0)
	key_light.light_energy = 1.45
	key_light.light_color = Color(1,.95,.88)
	key_light.shadow_enabled = true
	viewport.add_child(key_light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18,152,0)
	rim.light_energy = .9
	rim.light_color = Color(.62,.74,.98)
	viewport.add_child(rim)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.9
	viewport.add_child(camera)
	camera.position = Vector3(0,1.2,4)
	camera.look_at(Vector3(0,1,0))
	preview = load("res://assets/village/player_refined.glb").instantiate()
	viewport.add_child(preview)
	preview.rotation.y = -.35
	var anim: AnimationPlayer = preview.find_children("*","AnimationPlayer",true,false)[0]
	anim.get_animation("villager_idle").loop_mode = Animation.LOOP_LINEAR
	anim.play("villager_idle")
func fit_columns() -> void:
	if is_instance_valid(rows): rows.columns = clampi(int((rows_scroll.size.x+8)/164),2,5)
func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
func open() -> void:
	active = true
	preview.process_mode = Node.PROCESS_MODE_INHERIT
	game.input_blocked = true
	game.ui.hide()
	game.sync_camera_mouse()
	root.show()
	refresh()
func close() -> void:
	active = false
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	confirm.hide()
	root.hide()
	game.input_blocked = false
	game.ui.show()
	game.sync_camera_mouse()
func _input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		if confirm.visible: confirm.hide()
		else: close()
		get_viewport().set_input_as_handled()
func message(text: String,tone := GOLD) -> void:
	status.text = text
	status.add_theme_color_override("font_color",PARCH if tone==GOLD else tone)
	status_dot.add_theme_stylebox_override("panel",flat(tone,Color(0,0,0,0),0,5,Vector2.ZERO))
	refresh()
func loadout() -> Dictionary:
	var result := {}
	for slot in game.equipment.equipped:
		var item = game.equipment.owned(game.equipment.equipped[slot])
		if not item.is_empty(): result[slot] = GearCatalog.find(item.id)
	return result
func owned_count(id: String) -> int:
	var count := 0
	for entry in game.equipment.inventory:
		if entry.id==id: count+=1
	return count
func fmt(key: String,value: float) -> String:
	if key=="speed": return "%.2f"%value
	return ("%d"%int(round(value))) if is_equal_approx(value,round(value)) else "%.1f"%value
func style_nav() -> void:
	for id in tab_buttons:
		var button: Button = tab_buttons[id]
		var on: bool = id==page
		var box := flat(Color(.16,.15,.10,.95) if on else Color(0,0,0,0),GOLD if on else Color(0,0,0,0),0,6,Vector2(18,8))
		box.border_width_bottom = 3 if on else 0
		button.add_theme_stylebox_override("normal",box)
		button.add_theme_stylebox_override("hover",flat(Color(.16,.15,.10,.95) if on else Color(1,1,1,.06),GOLD if on else Color(0,0,0,0),0,6,Vector2(18,8)))
		button.get_theme_stylebox("hover").border_width_bottom = 3 if on else 0
		button.add_theme_color_override("font_color",GOLD if on else MUTED)
		button.add_theme_color_override("font_hover_color",GOLD if on else PARCH)
	for slot in filter_buttons:
		var button: Button = filter_buttons[slot]
		var on: bool = slot==filter_slot
		for state in ["normal","hover","pressed","focus"]:
			var box := flat(Color(.28,.21,.10,.95) if on else (Color(.12,.13,.12) if state=="hover" else Color(.08,.09,.09,.9)),GOLD if on else Color(GOLD.r,GOLD.g,GOLD.b,.25),1,17,Vector2(14,4))
			if slot!="all": box.content_margin_left = 34
			button.add_theme_stylebox_override(state,box)
		button.add_theme_color_override("font_color",GOLD if on else MUTED)
		button.add_theme_color_override("font_hover_color",GOLD if on else PARCH)
		button.add_theme_color_override("font_pressed_color",GOLD)
		button.add_theme_color_override("font_focus_color",GOLD if on else MUTED)
		button.focus_mode = Control.FOCUS_NONE
		for child in button.get_children():
			if child is GearIcon: child.modulate = Color(1,1,1,1 if on else .6)
func card_in(def: Dictionary,entry: Dictionary,selected: bool) -> Button:
	var tier: Array = tier_of(def.id)
	var tint: Color = tier[1]
	var locked: bool = game.equipment.level<def.level
	var worn: bool = page!="stock" and game.equipment.equipped.get(def.slot,0)==int(entry.get("uid",-1))
	var card := Button.new()
	card.custom_minimum_size = Vector2(150,180)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	var edge := Color(tint.r,tint.g,tint.b,.30)
	card.add_theme_stylebox_override("normal",flat(Color(.11,.12,.10,.98) if selected else Color(.075,.083,.08,.96),GOLD if selected else edge,2 if selected else 1,8,Vector2.ZERO))
	card.add_theme_stylebox_override("hover",flat(Color(.13,.15,.13),GOLD if selected else Color(tint.r,tint.g,tint.b,.65),2 if selected else 1,8,Vector2.ZERO))
	card.add_theme_stylebox_override("pressed",flat(Color(.15,.17,.15),GOLD,2,8,Vector2.ZERO))
	card.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	margin.add_child(column)
	spacer(column,12)
	var slot_holder := CenterContainer.new()
	column.add_child(slot_holder)
	var slot_panel := panel_in(slot_holder,flat(Color(tint.r,tint.g,tint.b,.10 if not selected else .18),Color(tint.r,tint.g,tint.b,.45),1,8,Vector2(6,6)))
	var icon := GearIcon.new()
	icon.slot = def.slot
	icon.tier = ["warden","pilgrim","citadel"].find(def.id.get_slice("_",0))
	icon.custom_minimum_size = Vector2(58,58)
	if locked: icon.modulate = Color(.45,.45,.45)
	slot_panel.add_child(icon)
	var name := label_in(column,def.name,14,PARCH if not locked else MUTED)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.custom_minimum_size.y = 38
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation",5)
	column.add_child(footer)
	if page=="stock":
		var coin := GearIcon.new()
		coin.slot = "coin"
		coin.custom_minimum_size = Vector2(14,14)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		footer.add_child(coin)
		var affordable: bool = game.equipment.gold>=def.price
		var price := label_in(footer,str(def.price),14,GOLD if affordable and not locked else Color(.72,.50,.42))
		price.autowrap_mode = TextServer.AUTOWRAP_OFF
		var tier_tag := label_in(footer,"· "+tier[0],12,tint)
		tier_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		tier_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		var pips := RankPips.new()
		pips.rank = int(entry.upgrade)
		pips.custom_minimum_size = Vector2(62,12)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		footer.add_child(pips)
		var copy := label_in(footer,"#%d"%entry.uid,11,MUTED)
		copy.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Corner badges: level locks, owned copies and the piece being worn.
	if locked:
		var lock := chip(card,"Lv %d"%def.level,BAD)
		lock.get_parent().set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		lock.get_parent().position = Vector2(6,6)
	if page=="stock" and owned_count(def.id)>0:
		var owned := chip(card,"Owned ×%d"%owned_count(def.id),GOOD)
		anchor_right(owned.get_parent())
	elif worn:
		var tag := chip(card,"Worn",GOLD)
		anchor_right(tag.get_parent())
	passthrough(margin)
	for child in card.get_children(): passthrough(child)
	return card
func anchor_right(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	node.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	node.position = Vector2(node.get_parent().size.x-node.size.x-6,6)
	node.anchor_left = 1
	node.anchor_right = 1
	node.offset_right = -6
	node.offset_left = -6-node.get_combined_minimum_size().x
	node.offset_top = 6
	node.offset_bottom = 6+node.get_combined_minimum_size().y
func stat_row(key: String,value: float,baseline: Variant) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	detail.add_child(row)
	var name := label_in(row,STAT_NAMES[key],13,MUTED)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.custom_minimum_size.x = 104
	var bar := StatBar.new()
	bar.value = value
	bar.maximum = STAT_MAX[key]
	bar.baseline = float(baseline) if baseline!=null else -1.0
	bar.color = STAT_COLORS[key]
	bar.custom_minimum_size = Vector2(70,12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var amount := label_in(row,fmt(key,value),16,PARCH)
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.custom_minimum_size.x = 46
	var delta_label := label_in(row,"",12,MUTED)
	delta_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	delta_label.custom_minimum_size.x = 50
	if baseline!=null:
		var delta: float = value-float(baseline)
		if absf(delta)>.001:
			var better: bool = (delta<0) if key in LOWER_BETTER else (delta>0)
			delta_label.text = ("▲ " if delta>0 else "▼ ")+fmt(key,absf(delta))
			delta_label.add_theme_color_override("font_color",GOOD if better else BAD)
		else: delta_label.text = "same"
func item_header(def: Dictionary,rank: int) -> void:
	var tier: Array = tier_of(def.id)
	var tint: Color = tier[1]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",14)
	detail.add_child(head)
	var frame := panel_in(head,flat(Color(tint.r,tint.g,tint.b,.12),Color(tint.r,tint.g,tint.b,.55),1,10,Vector2(8,8)))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var icon := GearIcon.new()
	icon.slot = def.slot
	icon.tier = ["warden","pilgrim","citadel"].find(def.id.get_slice("_",0))
	icon.custom_minimum_size = Vector2(78,78)
	frame.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",6)
	head.add_child(text)
	var name := label_in(text,def.name+(" +%d"%rank if rank>0 else ""),24,tint)
	name.add_theme_color_override("font_shadow_color",Color(0,0,0,.6))
	name.add_theme_constant_override("shadow_offset_y",2)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation",6)
	text.add_child(chips)
	chip(chips,tier[0],tint)
	chip(chips,SLOT_SINGULAR[def.slot],MUTED)
	chip(chips,"Level %d"%def.level,BAD if game.equipment.level<def.level else Color(.62,.72,.60))
func refresh() -> void:
	if not is_instance_valid(rows): return
	balance.text = "%d gold"%game.equipment.gold
	level_label.text = "Level %d"%game.equipment.level
	style_nav()
	fit_columns()
	clear(rows)
	clear(detail)
	var entries: Array = GearCatalog.items() if page=="stock" else game.equipment.inventory
	var visible_entries: Array = []
	for entry in entries:
		var def: Dictionary = entry if page=="stock" else GearCatalog.find(entry.id)
		if filter_slot!="all" and def.slot!=filter_slot: continue
		visible_entries.append(entry)
	var selected: Dictionary = {}
	for entry in visible_entries:
		if (page=="stock" and entry.id==selected_id) or (page!="stock" and entry.uid==selected_uid): selected=entry
	if selected.is_empty() and not visible_entries.is_empty(): selected=visible_entries[0]
	for entry in visible_entries:
		var def: Dictionary = entry if page=="stock" else GearCatalog.find(entry.id)
		var card := card_in(def,entry,entry==selected)
		card.pressed.connect(func(): selected_id=def.id; selected_uid=0 if page=="stock" else entry.uid; preview.rotation.y=2.8 if def.slot=="weapon" else -.35; refresh())
		rows.add_child(card)
	if visible_entries.is_empty():
		spacer(detail,30)
		var empty := GearIcon.new()
		empty.slot = filter_slot if filter_slot!="all" else "chest"
		empty.modulate = Color(1,1,1,.25)
		empty.custom_minimum_size = Vector2(96,96)
		var holder := CenterContainer.new()
		holder.add_child(empty)
		detail.add_child(holder)
		var title := label_in(detail,"The rack is empty" if page!="stock" else "Nothing on this rack",22,PARCH)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var hint := label_in(detail,"Bought pieces hang here. Browse Buy equipment to see what the forge offers." if page!="stock" else "Try another slot filter.",14,MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		GearVisuals.apply(preview,loadout())
		return
	selected_id = selected.id
	selected_uid = 0 if page=="stock" else int(selected.uid)
	var def := GearCatalog.find(selected_id)
	var rank: int = selected.get("upgrade",0)
	var stats: Dictionary = game.equipment.stats({"id":selected_id,"upgrade":rank})
	item_header(def,rank)
	label_in(detail,def.description,14,MUTED)
	divider(detail)
	heading(detail,"Stats")
	var current = game.equipment.owned(game.equipment.equipped.get(def.slot,0))
	var comparing: bool = not current.is_empty() and not (page!="stock" and int(current.uid)==selected_uid)
	var baseline: Dictionary = game.equipment.stats(current) if comparing else {}
	for key in ["damage","speed","stamina","protection","weight"]:
		if not stats.has(key): continue
		stat_row(key,float(stats[key]),baseline[key] if baseline.has(key) else null)
	if comparing: label_in(detail,"Compared with the %s you wear: %s"%[SLOT_SINGULAR[def.slot].to_lower(),GearCatalog.find(current.id).name],12,MUTED)
	divider(detail)
	var display := loadout()
	display[def.slot] = def
	GearVisuals.apply(preview,display)
	if page=="stock":
		var reason: String = game.equipment.buy_error(selected_id)
		button_in(detail,"Buy  ·  %d gold"%def.price,func():
			var error: String = game.equipment.buy(selected_id)
			message(error if not error.is_empty() else "Purchased "+def.name+". It hangs under Your equipment.",BAD if not error.is_empty() else GOOD)
		,not reason.is_empty(),"primary")
		if not reason.is_empty():
			var why := label_in(detail,reason,13,EMBER)
			why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if def.slot!="weapon":
			button_in(detail,"Try on the full "+("Warden" if def.style==0 else "Citadel")+" set",func():
				var suit := {}
				for slot in ["helmet","chest","gloves","boots"]: suit[slot] = GearCatalog.find(("warden_" if def.style==0 else "citadel_")+slot)
				suit.weapon = GearCatalog.find("warden_blade" if def.style==0 else "citadel_blade")
				GearVisuals.apply(preview,suit)
				status.text = "Showing the complete set. Nothing was bought or equipped."
			)
	elif page=="owned":
		var worn: bool = game.equipment.equipped.get(def.slot,0)==selected_uid
		button_in(detail,"Unequip" if worn else "Equip",func():
			var error: String = game.equipment.unequip(def.slot) if worn else game.equipment.equip(selected_uid)
			message(error if not error.is_empty() else ("Unequipped " if worn else "Equipped ")+def.name,BAD if not error.is_empty() else GOOD)
		,false,"secondary" if worn else "primary")
		button_in(detail,"Take to the anvil",func(): page="upgrade"; refresh())
	else:
		heading(detail,"Tempering")
		var pips := RankPips.new()
		pips.rank = rank
		pips.next = rank<GearCatalog.MAX_UPGRADE
		pips.custom_minimum_size = Vector2(150,22)
		var pip_row := HBoxContainer.new()
		pip_row.add_theme_constant_override("separation",12)
		detail.add_child(pip_row)
		pip_row.add_child(pips)
		var rank_text := label_in(pip_row,"Fully tempered  ·  +%d"%rank if rank>=GearCatalog.MAX_UPGRADE else "+%d  →  +%d"%[rank,rank+1],18,GOLD)
		rank_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		if rank<GearCatalog.MAX_UPGRADE:
			var chance: float = game.equipment.survival(selected)
			var gauge_row := HBoxContainer.new()
			gauge_row.add_theme_constant_override("separation",10)
			detail.add_child(gauge_row)
			var survive := label_in(gauge_row,"Survival",13,MUTED)
			survive.custom_minimum_size.x = 104
			survive.autowrap_mode = TextServer.AUTOWRAP_OFF
			var gauge := StatBar.new()
			gauge.value = chance
			gauge.maximum = 1
			gauge.color = BAD.lerp(GOOD,chance)
			gauge.custom_minimum_size = Vector2(70,12)
			gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			gauge_row.add_child(gauge)
			var odds := label_in(gauge_row,"%.0f%%"%(chance*100),16,BAD.lerp(GOOD,chance))
			odds.custom_minimum_size.x = 46
			odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			odds.autowrap_mode = TextServer.AUTOWRAP_OFF
			var next: Dictionary = game.equipment.stats({"id":selected_id,"upgrade":rank+1})
			var key := "damage" if def.slot=="weapon" else "protection"
			var gain_row := HBoxContainer.new()
			gain_row.add_theme_constant_override("separation",10)
			detail.add_child(gain_row)
			var gain_name := label_in(gain_row,STAT_NAMES[key],13,MUTED)
			gain_name.custom_minimum_size.x = 104
			gain_name.autowrap_mode = TextServer.AUTOWRAP_OFF
			var gain := label_in(gain_row,"%s  →  %s"%[fmt(key,float(stats[key])),fmt(key,float(next[key]))],16,GOOD)
			gain.autowrap_mode = TextServer.AUTOWRAP_OFF
			var warning := panel_in(detail,flat(Color(.20,.09,.05,.7),Color(EMBER.r,EMBER.g,EMBER.b,.45),1,6,Vector2(12,8)))
			label_in(warning,"%.0f%% chance the forge ruins it. Failure spends the gold and destroys this exact copy, even while worn. Other copies are safe."%((1-chance)*100),13,EMBER)
			var reason: String = game.equipment.upgrade_error(selected_uid)
			button_in(detail,"Temper  ·  %d gold"%game.equipment.upgrade_cost(selected),request_upgrade,not reason.is_empty(),"danger")
			if not reason.is_empty():
				var why := label_in(detail,reason,13,EMBER)
				why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else: label_in(detail,"This piece has taken every temper the forge can give.",14,MUTED)
func request_upgrade() -> void:
	var item = game.equipment.owned(selected_uid)
	if item.is_empty(): return
	pending_uid = selected_uid
	pending_rank = item.upgrade
	confirm.dialog_text = "%s +%d → +%d\nCost: %d gold\nSurvival: %.0f%%\n\nFailure permanently destroys copy #%d. Gold is spent either way."%[GearCatalog.find(item.id).name,item.upgrade,item.upgrade+1,game.equipment.upgrade_cost(item),game.equipment.survival(item)*100,item.uid]
	confirm.popup_centered(Vector2i(500,270))
func attempt_upgrade() -> void:
	var result: Dictionary = game.equipment.upgrade(pending_uid,pending_rank)
	if not result.error.is_empty(): message(result.error,BAD)
	elif result.survived: message("The temper held. The piece is stronger.",GOOD)
	else: message("The forge ruined it. That copy is gone for good.",BAD)
# Gear silhouettes drawn in a 100-unit square, lit from the upper left.
class GearIcon extends Control:
	var slot := "weapon"
	var tier := 0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func pts(raw: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		var s: float = minf(size.x,size.y)/100.0
		var off: Vector2 = (size-Vector2(100,100)*s)*.5
		for p in raw: out.append(off+Vector2(p[0],p[1])*s)
		return out
	func shape(raw: Array,fill: Color,line := Color(.04,.04,.05,.9)) -> void:
		var p := pts(raw)
		var colors := PackedColorArray()
		for q in raw: colors.append(fill.lightened(.22*(1.0-q[0]/100.0)).darkened(.18*q[1]/100.0))
		draw_polygon(p,colors)
		p.append(p[0])
		draw_polyline(p,line,maxf(1.2,size.x*.018),true)
	func stroke(raw: Array,color: Color,width: float) -> void:
		draw_polyline(pts(raw),color,maxf(1.0,width*size.x/100.0),true)
	func _draw() -> void:
		var steel: Color = [Color(.76,.79,.81),Color(.44,.48,.52),Color(.32,.35,.40)][clampi(tier,0,2)]
		var trim: Color = [Color(.74,.56,.26),Color(.70,.72,.74),Color(.64,.66,.70)][clampi(tier,0,2)]
		var leather := Color(.26,.17,.10)
		var shade := steel.darkened(.35)
		match slot:
			"coin":
				var c: Vector2 = size*.5
				var r: float = minf(size.x,size.y)*.48
				draw_circle(c,r,Color(.58,.42,.13))
				draw_circle(c,r*.86,Color(.90,.72,.30))
				draw_circle(c,r*.56,Color(.98,.84,.44))
				draw_arc(c,r*.72,PI*1.1,PI*1.9,12,Color(1,.95,.75,.6),maxf(1,r*.12),true)
			"weapon":
				var w: float = [8,6,11][clampi(tier,0,2)]
				var top: float = [6,2,6][clampi(tier,0,2)]
				shape([[50,top],[50+w,top+11],[50+w,62],[50-w,62],[50-w,top+11]],steel)
				stroke([[50,top+12],[50,58]],shade,2.2)
				if tier==1: shape([[26,58],[74,58],[76,64],[70,68],[30,68],[24,64]],trim)
				elif tier==2: shape([[25,58],[75,58],[75,68],[25,68]],trim)
				else: shape([[30,60],[70,60],[70,67],[30,67]],trim)
				shape([[46,68],[54,68],[54,86],[46,86]],leather)
				for i in 4: stroke([[46,72+i*4],[54,72+i*4]],leather.darkened(.5),1.4)
				draw_circle(pts([[50,90]])[0],maxf(2,size.x*.05),trim)
			"helmet":
				var dome := []
				for i in 13: dome.append([50+30*cos(PI+i*PI/12),46+34*sin(PI+i*PI/12)])
				dome.append_array([[80,60],[74,74],[26,74],[20,60]])
				shape(dome,steel)
				shape([[26,74],[74,74],[70,88],[30,88]],steel.darkened(.15))
				shape([[28,48],[72,48],[72,54],[28,54]],leather.darkened(.4))
				stroke([[22,46],[78,46]],trim,3)
				if tier==2: shape([[46,13],[54,13],[56,2],[44,2]],trim)
			"chest":
				if tier==2:
					shape([[13,18],[24,11],[29,31],[16,35]],steel.darkened(.1))
					shape([[87,18],[76,11],[71,31],[84,35]],steel.darkened(.1))
				shape([[22,16],[38,10],[50,15],[62,10],[78,16],[82,42],[74,56],[72,84],[50,92],[28,84],[26,56],[18,42]],steel)
				shape([[40,10],[50,15],[60,10],[58,21],[50,25],[42,21]],leather.darkened(.3))
				stroke([[50,26],[50,80]],shade,2.2)
				stroke([[30,70],[70,70]],shade,1.6)
				stroke([[31,78],[69,78]],shade,1.6)
				for x in [31,69]: draw_circle(pts([[x,32]])[0],maxf(1.5,size.x*.026),trim)
			"gloves":
				shape([[28,8],[72,8],[70,30],[30,30]],steel.darkened(.1))
				shape([[30,30],[70,30],[74,60],[66,86],[36,86],[28,60]],steel)
				shape([[28,42],[34,33],[40,40],[32,66],[22,58]],steel.darkened(.05))
				for y in [48,58,68]: stroke([[37,y],[66,y]],shade,1.6)
				stroke([[29,30],[71,30]],trim,3)
			"boots":
				shape([[34,6],[66,6],[68,56],[62,62],[38,62],[32,56]],steel)
				shape([[38,62],[62,62],[64,70],[86,82],[86,92],[36,92],[32,78]],steel.darkened(.12))
				stroke([[33,20],[67,20]],trim,3)
				stroke([[40,72],[62,72]],shade,1.6)
				stroke([[42,80],[70,80]],shade,1.6)
class StatBar extends Control:
	var value := 0.0
	var maximum := 1.0
	var baseline := -1.0
	var color := Color.WHITE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var back := StyleBoxFlat.new()
		back.bg_color = Color(1,1,1,.07)
		back.set_corner_radius_all(4)
		back.draw(get_canvas_item(),Rect2(Vector2.ZERO,size))
		for i in range(1,4): draw_line(Vector2(size.x*i/4.0,1),Vector2(size.x*i/4.0,size.y-1),Color(0,0,0,.35),1)
		var fraction: float = clampf(value/maximum,0,1)
		if fraction>0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = color
			fill.set_corner_radius_all(4)
			var width: float = maxf(size.x*fraction,6)
			fill.draw(get_canvas_item(),Rect2(0,0,width,size.y))
			draw_rect(Rect2(2,1,maxf(width-4,1),size.y*.4),Color(1,1,1,.14))
		if baseline>=0:
			var x: float = clampf(baseline/maximum,0,1)*size.x
			draw_line(Vector2(x,-3),Vector2(x,size.y+3),Color(1,1,1,.9),2)
class RankPips extends Control:
	var rank := 0
	var next := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var step: float = size.x/GearCatalog.MAX_UPGRADE
		var r: float = minf(size.y*.5,step*.36)
		for i in GearCatalog.MAX_UPGRADE:
			var c := Vector2(step*(i+.5),size.y*.5)
			var diamond := PackedVector2Array([c+Vector2(0,-r),c+Vector2(r,0),c+Vector2(0,r),c+Vector2(-r,0)])
			if i<rank: draw_colored_polygon(diamond,Color(.90,.74,.38))
			else: draw_colored_polygon(diamond,Color(1,1,1,.07))
			diamond.append(diamond[0])
			draw_polyline(diamond,Color(.95,.80,.45) if (i<rank or (next and i==rank)) else Color(1,1,1,.22),1.5,true)
class Ornament extends Control:
	func _ready() -> void: resized.connect(queue_redraw)
	func _draw() -> void:
		var l: float = 18
		var c := Color(.87,.71,.37,.9)
		for corner in [[Vector2(0,0),Vector2(1,1)],[Vector2(size.x,0),Vector2(-1,1)],[Vector2(0,size.y),Vector2(1,-1)],[Vector2(size.x,size.y),Vector2(-1,-1)]]:
			var o: Vector2 = corner[0]+corner[1]*3
			draw_line(o,o+Vector2(corner[1].x*l,0),c,2)
			draw_line(o,o+Vector2(0,corner[1].y*l),c,2)

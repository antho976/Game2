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
var pending_quote: Dictionary = {}
const GOLD := UiKit.GOLD
const PARCH := UiKit.PARCH
const MUTED := UiKit.MUTED
const EMBER := UiKit.EMBER
const GOOD := UiKit.GOOD
const BAD := UiKit.BAD
const GearIcon := UiKit.GearIcon
const StatBar := UiKit.StatBar
const RankPips := UiKit.RankPips
const Ornament := UiKit.Ornament
const TIERS := {"warden":["Common",Color(.82,.82,.78)],"pilgrim":["Fine",Color(.58,.84,.50)],"citadel":["Rare",Color(.48,.70,.97)]}
const SLOT_NAMES := {"all":"All","weapon":"Swords","helmet":"Helms","chest":"Cuirasses","gloves":"Gauntlets","boots":"Greaves"}
const SLOT_SINGULAR := {"weapon":"Sword","helmet":"Helm","chest":"Cuirass","gloves":"Gauntlets","boots":"Greaves"}
const STAT_NAMES := {"damage":"Damage","speed":"Attack speed","stamina":"Stamina cost","protection":"Protection","weight":"Weight"}
const STAT_MAX := {"damage":70.0,"speed":1.3,"stamina":40.0,"protection":26.0,"weight":12.0}
const STAT_COLORS := {"damage":Color(.94,.56,.34),"speed":Color(.62,.82,.96),"stamina":Color(.80,.68,.40),"protection":Color(.56,.76,.96),"weight":Color(.66,.63,.58)}
const LOWER_BETTER := ["stamina","weight"]
static func tier_of(id: String) -> Array:
	return TIERS.get(id.get_slice("_",0),TIERS.warden)
func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.theme = UiKit.theme()
	UiKit.backdrop(root,[Color(.24,.12,.05),Color(.08,.05,.035),Color(.025,.028,.03)],Vector2(.5,1.05))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,22)
	root.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	margin.add_child(body)
	# Header bar: title, purse, level and the way out.
	var header_style := UiKit.flat(Color(.045,.05,.045,.9),Color(.72,.58,.30,.55),0,8,Vector2(22,10))
	header_style.border_width_bottom = 2
	var header := UiKit.panel(body,header_style)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation",14)
	header.add_child(header_row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation",0)
	header_row.add_child(title_box)
	var title := UiKit.label(title_box,"THE BLACKSMITH",30,GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var subtitle := UiKit.label(title_box,"Forge & armory  ·  Buy, fit and temper your gear",13,MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	var purse := UiKit.panel(header_row,UiKit.flat(Color(.14,.11,.05,.92),Color(.74,.58,.28,.6),1,16,Vector2(14,6)))
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var purse_row := HBoxContainer.new()
	purse_row.add_theme_constant_override("separation",8)
	purse.add_child(purse_row)
	var coin := GearIcon.new()
	coin.slot = "coin"
	coin.custom_minimum_size = Vector2(20,20)
	purse_row.add_child(coin)
	balance = UiKit.label(purse_row,"0",19,GOLD)
	balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	var level_panel := UiKit.panel(header_row,UiKit.flat(Color(.08,.11,.10,.92),Color(.55,.62,.50,.5),1,16,Vector2(14,6)))
	level_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_label = UiKit.label(level_panel,"Level 1",17,PARCH)
	level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var leave := UiKit.button(header_row,"Leave  ·  Esc",close)
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
		var button := UiKit.button(tabs,tab[1],func(): page=tab[0]; selected_uid=0; refresh(),false,"ghost")
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
		UiKit.sound(button)
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
	var racks := UiKit.panel(columns,UiKit.flat(Color(.045,.05,.048,.82),Color(GOLD.r,GOLD.g,GOLD.b,.22),1,10,Vector2(10,10)))
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
	var appraisal := UiKit.panel(columns,UiKit.flat(Color(.06,.065,.06,.94),Color(GOLD.r,GOLD.g,GOLD.b,.45),1,10,Vector2(20,18)))
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
	var fitting := UiKit.panel(columns,UiKit.flat(Color(.05,.05,.048,.94),Color(GOLD.r,GOLD.g,GOLD.b,.45),1,10,Vector2(12,12)))
	fitting.custom_minimum_size.x = 300
	fitting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fitting.size_flags_stretch_ratio = .8
	var visual := VBoxContainer.new()
	visual.add_theme_constant_override("separation",8)
	fitting.add_child(visual)
	UiKit.heading(visual,"Fitting room")
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",UiKit.flat(Color(.03,.03,.03),Color(GOLD.r,GOLD.g,GOLD.b,.3),1,6,Vector2(2,2)))
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
	var hint := UiKit.label(visual,"Drag to turn. Trying gear on never buys or equips it.",12,MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.gui_input.connect(func(event):
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): preview.rotation.y+=event.relative.x*.012
	)
	# The smith's word: a message strip along the bottom.
	var strip := UiKit.panel(body,UiKit.flat(Color(.07,.07,.065,.92),Color(GOLD.r,GOLD.g,GOLD.b,.3),1,8,Vector2(16,8)))
	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation",10)
	strip.add_child(strip_row)
	status_dot = Panel.new()
	status_dot.custom_minimum_size = Vector2(9,9)
	status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_dot.add_theme_stylebox_override("panel",UiKit.flat(GOLD,Color(0,0,0,0),0,5,Vector2.ZERO))
	strip_row.add_child(status_dot)
	status = UiKit.label(strip_row,"Claim your first blade here. Earn gold and experience in the yard or the mine.",14,MUTED)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm = ConfirmationDialog.new()
	confirm.title = "Risk this item?"
	confirm.ok_button_text = "Attempt upgrade"
	confirm.confirmed.connect(attempt_upgrade)
	UiKit.skin(confirm.get_ok_button(),"danger")
	UiKit.skin(confirm.get_cancel_button(),"secondary")
	UiKit.sound(confirm.get_ok_button(),"confirm")
	UiKit.sound(confirm.get_cancel_button(),"back")
	for dialog_button in [confirm.get_ok_button(),confirm.get_cancel_button()]: dialog_button.focus_mode = Control.FOCUS_ALL
	root.add_child(confirm)
	game.research.changed.connect(func():
		if active: refresh()
	)
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
	if not game.equipment.starter_claimed:
		page="stock"
		selected_id="warden_blade"
		filter_slot="all"
	active = true
	game.audio.ui("shop_open",-10)
	game.audio.set_loop_volume("forge",-13)
	preview.process_mode = Node.PROCESS_MODE_INHERIT
	game.input_blocked = true
	game.ui.hide()
	game.sync_camera_mouse()
	root.show()
	refresh()
func close() -> void:
	active = false
	game.audio.ui("shop_close",-12)
	game.audio.set_loop_volume("forge",-18)
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
	if tone == BAD: game.audio.ui("ui_denied")
	status.text = text
	status.add_theme_color_override("font_color",PARCH if tone==GOLD else tone)
	status_dot.add_theme_stylebox_override("panel",UiKit.flat(tone,Color(0,0,0,0),0,5,Vector2.ZERO))
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
		var box := UiKit.flat(Color(.16,.15,.10,.95) if on else Color(0,0,0,0),GOLD if on else Color(0,0,0,0),0,6,Vector2(18,8))
		box.border_width_bottom = 3 if on else 0
		button.add_theme_stylebox_override("normal",box)
		button.add_theme_stylebox_override("hover",UiKit.flat(Color(.16,.15,.10,.95) if on else Color(1,1,1,.06),GOLD if on else Color(0,0,0,0),0,6,Vector2(18,8)))
		button.get_theme_stylebox("hover").border_width_bottom = 3 if on else 0
		button.add_theme_color_override("font_color",GOLD if on else MUTED)
		button.add_theme_color_override("font_hover_color",GOLD if on else PARCH)
	for slot in filter_buttons:
		var button: Button = filter_buttons[slot]
		var on: bool = slot==filter_slot
		for state in ["normal","hover","pressed","focus"]:
			var box := UiKit.flat(Color(.28,.21,.10,.95) if on else (Color(.12,.13,.12) if state=="hover" else Color(.08,.09,.09,.9)),GOLD if on else Color(GOLD.r,GOLD.g,GOLD.b,.25),1,17,Vector2(14,4))
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
	card.add_theme_stylebox_override("normal",UiKit.flat(Color(.11,.12,.10,.98) if selected else Color(.075,.083,.08,.96),GOLD if selected else edge,2 if selected else 1,8,Vector2.ZERO))
	card.add_theme_stylebox_override("hover",UiKit.flat(Color(.13,.15,.13),GOLD if selected else Color(tint.r,tint.g,tint.b,.65),2 if selected else 1,8,Vector2.ZERO))
	card.add_theme_stylebox_override("pressed",UiKit.flat(Color(.15,.17,.15),GOLD,2,8,Vector2.ZERO))
	card.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	margin.add_child(column)
	UiKit.spacer(column,12)
	var slot_holder := CenterContainer.new()
	column.add_child(slot_holder)
	var slot_panel := UiKit.panel(slot_holder,UiKit.flat(Color(tint.r,tint.g,tint.b,.10 if not selected else .18),Color(tint.r,tint.g,tint.b,.45),1,8,Vector2(6,6)))
	var icon := GearIcon.new()
	icon.slot = def.slot
	icon.tier = ["warden","pilgrim","citadel"].find(def.id.get_slice("_",0))
	icon.custom_minimum_size = Vector2(58,58)
	if locked: icon.modulate = Color(.45,.45,.45)
	slot_panel.add_child(icon)
	var name := UiKit.label(column,def.name,14,PARCH if not locked else MUTED)
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
		var affordable: bool = game.equipment.gold>=game.equipment.purchase_price(def.id)
		var price := UiKit.label(footer,str(game.equipment.purchase_price(def.id)),14,GOLD if affordable and not locked else Color(.72,.50,.42))
		price.autowrap_mode = TextServer.AUTOWRAP_OFF
		var tier_tag := UiKit.label(footer,"· "+tier[0],12,tint)
		tier_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		tier_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		var pips := RankPips.new()
		pips.maximum = game.equipment.max_upgrade()
		pips.rank = int(entry.upgrade)
		pips.custom_minimum_size = Vector2(62,12)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		footer.add_child(pips)
		var copy := UiKit.label(footer,"#%d"%entry.uid,11,MUTED)
		copy.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Corner badges: level locks, owned copies and the piece being worn.
	if locked:
		var lock := UiKit.chip(card,"Lv %d"%def.level,BAD)
		lock.get_parent().set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		lock.get_parent().position = Vector2(6,6)
	if page=="stock" and owned_count(def.id)>0:
		var owned := UiKit.chip(card,"Owned ×%d"%owned_count(def.id),GOOD)
		anchor_right(owned.get_parent())
	elif worn:
		var tag := UiKit.chip(card,"Worn",GOLD)
		anchor_right(tag.get_parent())
	UiKit.passthrough(margin)
	for child in card.get_children(): UiKit.passthrough(child)
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
	var name := UiKit.label(row,STAT_NAMES[key],13,MUTED)
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
	var amount := UiKit.label(row,fmt(key,value),16,PARCH)
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.custom_minimum_size.x = 46
	var delta_label := UiKit.label(row,"",12,MUTED)
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
	var frame := UiKit.panel(head,UiKit.flat(Color(tint.r,tint.g,tint.b,.12),Color(tint.r,tint.g,tint.b,.55),1,10,Vector2(8,8)))
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
	var name := UiKit.label(text,def.name+(" +%d"%rank if rank>0 else ""),24,tint)
	name.add_theme_color_override("font_shadow_color",Color(0,0,0,.6))
	name.add_theme_constant_override("shadow_offset_y",2)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation",6)
	text.add_child(chips)
	UiKit.chip(chips,tier[0],tint)
	UiKit.chip(chips,SLOT_SINGULAR[def.slot],MUTED)
	UiKit.chip(chips,"Level %d"%def.level,BAD if game.equipment.level<def.level else Color(.62,.72,.60))
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
		card.pressed.connect(func():
			selected_id=def.id
			selected_uid=0 if page=="stock" else entry.uid
			preview.rotation.y=2.8 if def.slot=="weapon" else -.35
			# A locked or unaffordable piece answers with a thin purse instead of a click.
			if page=="stock" and not game.equipment.buy_error(def.id).is_empty(): game.audio.ui("shop_buy_denied",-16)
			refresh())
		UiKit.sound(card)
		rows.add_child(card)
	if visible_entries.is_empty():
		UiKit.spacer(detail,30)
		var empty := GearIcon.new()
		empty.slot = filter_slot if filter_slot!="all" else "chest"
		empty.modulate = Color(1,1,1,.25)
		empty.custom_minimum_size = Vector2(96,96)
		var holder := CenterContainer.new()
		holder.add_child(empty)
		detail.add_child(holder)
		var title := UiKit.label(detail,"The rack is empty" if page!="stock" else "Nothing on this rack",22,PARCH)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var hint := UiKit.label(detail,"Bought pieces hang here. Browse Buy equipment to see what the forge offers." if page!="stock" else "Try another slot filter.",14,MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		GearVisuals.apply(preview,loadout())
		return
	selected_id = selected.id
	selected_uid = 0 if page=="stock" else int(selected.uid)
	var def := GearCatalog.find(selected_id)
	var rank: int = selected.get("upgrade",0)
	var stats: Dictionary = game.equipment.stats(selected)
	item_header(def,rank)
	UiKit.label(detail,def.description,14,MUTED)
	UiKit.divider(detail)
	UiKit.heading(detail,"Stats")
	var current = game.equipment.owned(game.equipment.equipped.get(def.slot,0))
	var comparing: bool = not current.is_empty() and not (page!="stock" and int(current.uid)==selected_uid)
	var baseline: Dictionary = game.equipment.stats(current) if comparing else {}
	for key in ["damage","speed","stamina","protection","weight"]:
		if not stats.has(key): continue
		stat_row(key,float(stats[key]),baseline[key] if baseline.has(key) else null)
	if comparing: UiKit.label(detail,"Compared with the %s you wear: %s"%[SLOT_SINGULAR[def.slot].to_lower(),GearCatalog.find(current.id).name],12,MUTED)
	UiKit.divider(detail)
	var display := loadout()
	display[def.slot] = def
	GearVisuals.apply(preview,display)
	if page=="stock":
		if def.id=="warden_blade" and not game.equipment.starter_claimed:
			UiKit.label(detail,"A blade for your first journey. The smith offers you one greatsword, free of charge.",14,GOOD)
			UiKit.button(detail,"Accept starter greatsword  ·  Free",func():
				var error: String=game.equipment.claim_starter()
				message(error if not error.is_empty() else "It's yours. Keep your guard up. Press I to open your inventory.",BAD if not error.is_empty() else GOOD)
			,false,"primary")
		var reason: String = game.equipment.buy_error(selected_id)
		UiKit.button(detail,"Buy  ·  %d gold"%game.equipment.purchase_price(def.id),func():
			var error: String = game.equipment.buy(selected_id)
			if error.is_empty(): game.audio.ui("shop_buy",-8)
			message(error if not error.is_empty() else "Purchased "+def.name+". It hangs under Your equipment.",BAD if not error.is_empty() else GOOD)
		,not reason.is_empty(),"primary")
		if not reason.is_empty():
			var why := UiKit.label(detail,reason,13,EMBER)
			why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if def.slot!="weapon":
			UiKit.button(detail,"Try on the full "+("Warden" if def.style==0 else "Citadel")+" set",func():
				var suit := {}
				for slot in ["helmet","chest","gloves","boots"]: suit[slot] = GearCatalog.find(("warden_" if def.style==0 else "citadel_")+slot)
				suit.weapon = GearCatalog.find("warden_blade" if def.style==0 else "citadel_blade")
				GearVisuals.apply(preview,suit)
				status.text = "Showing the complete set. Nothing was bought or equipped."
			)
	elif page=="owned":
		var worn: bool = game.equipment.equipped.get(def.slot,0)==selected_uid
		UiKit.button(detail,"Unequip" if worn else "Equip",func():
			var error: String = game.equipment.unequip(def.slot) if worn else game.equipment.equip(selected_uid)
			if error.is_empty(): game.audio.ui("unequip" if worn else ("equip_weapon" if def.slot=="weapon" else "equip_armor"),-10)
			message(error if not error.is_empty() else ("Unequipped " if worn else "Equipped ")+def.name,BAD if not error.is_empty() else GOOD)
		,false,"secondary" if worn else "primary")
		UiKit.button(detail,"Take to the anvil",func(): page="upgrade"; refresh())
	else:
		UiKit.heading(detail,"Tempering")
		var pips := RankPips.new()
		pips.maximum = game.equipment.max_upgrade()
		pips.rank = rank
		pips.next = rank<game.equipment.max_upgrade()
		pips.custom_minimum_size = Vector2(150,22)
		var pip_row := HBoxContainer.new()
		pip_row.add_theme_constant_override("separation",12)
		detail.add_child(pip_row)
		pip_row.add_child(pips)
		var rank_text := UiKit.label(pip_row,"Fully tempered  ·  +%d"%rank if rank>=game.equipment.max_upgrade() else "+%d  →  +%d"%[rank,rank+1],18,GOLD)
		rank_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		if rank<game.equipment.max_upgrade():
			var chance: float = game.equipment.survival(selected)
			var gauge_row := HBoxContainer.new()
			gauge_row.add_theme_constant_override("separation",10)
			detail.add_child(gauge_row)
			var survive := UiKit.label(gauge_row,"Survival",13,MUTED)
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
			var odds := UiKit.label(gauge_row,"%.0f%%"%(chance*100),16,BAD.lerp(GOOD,chance))
			odds.custom_minimum_size.x = 46
			odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			odds.autowrap_mode = TextServer.AUTOWRAP_OFF
			var next: Dictionary = game.equipment.next_stats(selected)
			var key := "damage" if def.slot=="weapon" else "protection"
			var gain_row := HBoxContainer.new()
			gain_row.add_theme_constant_override("separation",10)
			detail.add_child(gain_row)
			var gain_name := UiKit.label(gain_row,STAT_NAMES[key],13,MUTED)
			gain_name.custom_minimum_size.x = 104
			gain_name.autowrap_mode = TextServer.AUTOWRAP_OFF
			var gain := UiKit.label(gain_row,"%s  →  %s"%[fmt(key,float(stats[key])),fmt(key,float(next[key]))],16,GOOD)
			gain.autowrap_mode = TextServer.AUTOWRAP_OFF
			var warning := UiKit.panel(detail,UiKit.flat(Color(.20,.09,.05,.7),Color(EMBER.r,EMBER.g,EMBER.b,.45),1,6,Vector2(12,8)))
			UiKit.label(warning,"%.0f%% chance the forge ruins it. Failure spends the gold and destroys this exact copy, even while worn. Other copies are safe."%((1-chance)*100),13,EMBER)
			var reason: String = game.equipment.upgrade_error(selected_uid)
			UiKit.button(detail,"Temper  ·  %d gold"%game.equipment.upgrade_cost(selected),request_upgrade,not reason.is_empty(),"danger")
			if not reason.is_empty():
				var why := UiKit.label(detail,reason,13,EMBER)
				why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else: UiKit.label(detail,"This piece has taken every temper the forge can give.",14,MUTED)
func request_upgrade() -> void:
	var item = game.equipment.owned(selected_uid)
	if item.is_empty(): return
	pending_uid = selected_uid
	pending_rank = item.upgrade
	pending_quote = game.equipment.upgrade_quote(item)
	confirm.dialog_text = "%s +%d → +%d\nCost: %d gold\nSurvival: %.0f%%\n\nFailure permanently destroys copy #%d. Gold is spent either way."%[GearCatalog.find(item.id).name,item.upgrade,item.upgrade+1,game.equipment.upgrade_cost(item),game.equipment.survival(item)*100,item.uid]
	confirm.popup_centered(Vector2i(500,270))
func attempt_upgrade() -> void:
	var result: Dictionary = game.equipment.upgrade(pending_uid,pending_rank,pending_quote)
	if not result.error.is_empty():
		message(result.error,BAD)
		return
	# Three strikes and a quench, then the verdict lands on the hiss.
	game.audio.ui("upgrade_attempt",-8)
	var verdict := func():
		if not active: return
		game.audio.ui("upgrade_success" if result.survived else "upgrade_fail",-8)
	if game.test_mode or DisplayServer.get_name() == "headless": verdict.call()
	else: get_tree().create_timer(1.6).timeout.connect(verdict)
	if result.survived: message("The temper held. The piece is stronger.",GOOD)
	else: message("The forge ruined it. That copy is gone for good.",BAD)

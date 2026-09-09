extends CanvasLayer
# Your belongings, on the same illuminated page as the forge and the archive:
# what you are wearing on the left under one lamp, the bag in the middle, and
# the appraisal of whatever you picked up on the right.
var game: Node
var active := false
var root: Control
var grid: GridContainer
var slots: VBoxContainer
var details: VBoxContainer
var actions: VBoxContainer
var detail_fade: Control
var purse: Label
var coins: Label
var gems: Label
var essence: Label
var summary: Label
var notice: Label
var notice_dot: ColorRect
var preview: Node3D
var viewport: SubViewport
var thumbnails: GearThumbnails
var filter_buttons := {}
var sort_button: Button
var selected := 0
var filter_slot := "all"
var sort_mode := 0
var cards: Array[Button] = []
const GILT := ForgeUi.GILT
const VELLUM := ForgeUi.VELLUM
const PARCH := ForgeUi.PARCH
const FADED := ForgeUi.FADED
const FORGE := ForgeUi.FORGE
const GOOD := ForgeUi.VERDIGRIS
const BAD := ForgeUi.BLOOD
const SLOT_NAMES := {"weapon":"Greatsword","helmet":"Helmet","chest":"Chest","gloves":"Gloves","boots":"Boots"}
const FILTER_NAMES := {"all":"All","weapon":"Swords","helmet":"Helms","chest":"Chest","gloves":"Gloves","boots":"Boots"}
const SORT_NAMES := ["By type","By name","Highest temper"]

func _ready() -> void:
	layer = 30
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = ForgeUi.theme()
	add_child(root)
	# A table by one candle: warm from the low left, cold air from the right.
	ForgeUi.page(root,Color(.24,.13,.05),Vector2(-.02,1.04),Color(.06,.08,.12),Vector2(1.02,-.04))
	thumbnails = GearThumbnails.instance(game)
	thumbnails.finished.connect(func():
		if active: refresh())
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margins.add_theme_constant_override("margin_"+side,26)
	root.add_child(margins)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	margins.add_child(body)
	var header := ForgeUi.header(body,"Belongings","Equipment and what you carry")
	var coin := UiKit.GearIcon.new()
	coin.slot = "coin"
	coin.custom_minimum_size = Vector2(19,19)
	coins = ForgeUi.counter(header,coin,GILT)
	var gem := UiKit.Glyph.new()
	gem.kind = "diamond"
	gem.custom_minimum_size = Vector2(19,19)
	gems = ForgeUi.counter(header,gem,ForgeUi.SAPPHIRE)
	essence = ForgeUi.counter(header,null,Color(.62,.82,.62),"Essence")
	purse = ForgeUi.counter(header,null,Color(.78,.76,.71),"Level")
	var close_button := ForgeUi.button(header,"Close  ·  I / Esc",close,false,"ghost",14)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.focus_mode = Control.FOCUS_ALL
	ForgeUi.rule(body)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	build_worn(columns)
	build_bag(columns)
	var parts := ForgeUi.appraisal(columns)
	var appraisal: PanelContainer = parts[0]
	appraisal.custom_minimum_size.x = 300
	details = parts[1]
	details.custom_minimum_size.x = 210
	actions = parts[2]
	detail_fade = parts[3]
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",11)
	body.add_child(line)
	notice_dot = ColorRect.new()
	notice_dot.color = GILT
	notice_dot.custom_minimum_size = Vector2(8,8)
	notice_dot.pivot_offset = Vector2(4,4)
	notice_dot.rotation = PI*.25
	notice_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(notice_dot)
	notice = ForgeUi.text(line,"Select an item to compare it with your worn equipment.",14,FADED)
	notice.add_theme_font_override("font",ForgeUi.tracked(1.0,false))
	notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

## The left column: what you have on, standing in the lamplight unframed.
func build_worn(columns: Node) -> void:
	var worn := VBoxContainer.new()
	worn.custom_minimum_size.x = 236
	worn.add_theme_constant_override("separation",8)
	columns.add_child(worn)
	ForgeUi.caps(worn,"Worn equipment")
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size.y = 180
	stage.clip_contents = true
	worn.add_child(stage)
	var display := SubViewportContainer.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.stretch = true
	stage.add_child(display)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(280,360)
	display.add_child(viewport)
	display.resized.connect(func():
		viewport.size = Vector2i(maxi(64,int(display.size.x)),maxi(64,int(display.size.y))))
	build_preview()
	display.gui_input.connect(func(event):
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): preview.rotation.y+=event.relative.x*.012)
	var hint := ForgeUi.caps(worn,"Drag to turn",10,FADED,3.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ForgeUi.rule(worn,false)
	slots = VBoxContainer.new()
	slots.add_theme_constant_override("separation",4)
	worn.add_child(slots)
	summary = ForgeUi.text(worn,"",12,FADED)

## The middle column: the bag itself, with the racks it can be narrowed to.
func build_bag(columns: Node) -> void:
	var bag := VBoxContainer.new()
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag.size_flags_stretch_ratio = 1.35
	bag.custom_minimum_size.x = 300
	bag.add_theme_constant_override("separation",8)
	columns.add_child(bag)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation",6)
	bag.add_child(tools)
	for slot in ["all"]+GearCatalog.SLOTS:
		var button := Button.new()
		button.text = FILTER_NAMES[slot]
		button.custom_minimum_size.y = 30
		button.add_theme_font_override("font",ForgeUi.tracked(1.0,false))
		button.add_theme_font_size_override("font_size",11)
		button.pressed.connect(func(): filter_slot=slot; refresh())
		ForgeUi.sound(button)
		tools.add_child(button)
		filter_buttons[slot] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools.add_child(spacer)
	sort_button = ForgeUi.button(tools,"",func(): sort_mode=(sort_mode+1)%SORT_NAMES.size(); refresh(),false,"ghost",12)
	sort_button.custom_minimum_size.y = 30
	sort_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ForgeUi.style_scroll(scroll)
	bag.add_child(scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right",14)
	gutter.add_theme_constant_override("margin_bottom",8)
	scroll.add_child(gutter)
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	gutter.add_child(grid)
	scroll.resized.connect(func(): grid.columns=clampi(int((scroll.size.x-14)/152),2,5))

func build_preview() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.80,.76,.70)
	env.environment.ambient_light_energy = .50
	viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-36,-34,0)
	light.light_energy = 1.5
	light.light_color = Color(1,.95,.87)
	light.shadow_enabled = true
	viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12,142,0)
	fill.light_color = Color(.60,.75,1)
	fill.light_energy = .85
	viewport.add_child(fill)
	preview = load("res://assets/village/player_refined.glb").instantiate()
	viewport.add_child(preview)
	preview.rotation.y = -.25
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.55
	camera.position = Vector3(0,1.55,4)
	camera.look_at(Vector3(0,.96,0))
	camera.current = true

func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
func open() -> void:
	if game.input_blocked or game.menus.home: return
	if game.combat.active:
		game.toast("Finish the fight before changing equipment.")
		return
	active = true
	game.input_blocked = true
	game.ui.hide()
	game.sync_camera_mouse()
	root.show()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	message("Select an item to compare it with your worn equipment.")
	refresh()
	if not thumbnails.ready_for_use: thumbnails.warm(GearCatalog.items())
	if not cards.is_empty(): cards[0].grab_focus()
func close() -> void:
	active = false
	root.hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	game.input_blocked = false
	game.ui.show()
	game.sync_camera_mouse()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_I,KEY_ESCAPE]:
		if active:
			close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_I and not game.input_blocked and not game.menus.home:
			open()
			get_viewport().set_input_as_handled()
func message(text: String,tone := GILT) -> void:
	notice.text = text
	notice.add_theme_color_override("font_color",VELLUM if tone!=GILT else FADED)
	notice_dot.color = tone
	notice_dot.modulate = Color(1,1,1,0)
	create_tween().tween_property(notice_dot,"modulate",Color(1,1,1,1),.45)

## The rendered piece when the forge has cut it; the drawn glyph until then.
func item_art(def: Dictionary,extent: float,dim: bool) -> Control:
	var texture: Texture2D = thumbnails.icon(def.id)
	if texture != null:
		var node := TextureRect.new()
		node.texture = texture
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node.custom_minimum_size = Vector2(extent,extent)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if dim: node.modulate = Color(.40,.40,.42)
		return node
	var icon := UiKit.GearIcon.new()
	icon.slot = def.slot
	icon.tier = int(def.style)
	icon.custom_minimum_size = Vector2(extent*.72,extent*.72)
	if dim: icon.modulate = Color(.45,.45,.45)
	return icon

func style_tools() -> void:
	for slot in filter_buttons:
		var button: Button = filter_buttons[slot]
		var on: bool = slot==filter_slot
		for state in ["normal","hover","pressed","focus"]:
			var lit: bool = on or state=="hover"
			button.add_theme_stylebox_override(state,ForgeUi.plate_box(
				Color(.34,.25,.10,.95) if on else Color(1,.94,.84,.06 if lit else .025),
				Color(.20,.14,.05,.95) if on else Color(1,.94,.84,.02 if lit else .01),
				Color(GILT.r,GILT.g,GILT.b,.75 if on else (.35 if lit else .18)),Vector2(9,4),5.0))
		button.add_theme_color_override("font_color",GILT.lightened(.2) if on else FADED)
		button.add_theme_color_override("font_hover_color",GILT.lightened(.2) if on else VELLUM)
		button.focus_mode = Control.FOCUS_NONE
	sort_button.text = "Sort  ·  "+SORT_NAMES[sort_mode]

func refresh() -> void:
	var gear: Node = game.equipment
	purse.text = "%d"%gear.level
	coins.text = "%d"%gear.gold
	gems.text = "%d"%gear.diamonds
	essence.text = "%d"%gear.life_essence
	style_tools()
	clear(slots)
	var outfit := {}
	for slot in GearCatalog.SLOTS:
		var item: Dictionary = gear.owned(gear.equipped.get(slot,0))
		var empty: bool = item.is_empty()
		if not empty: outfit[slot] = GearCatalog.find(item.id)
		var button := Button.new()
		button.custom_minimum_size.y = 32
		button.disabled = empty
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(func(): selected=item.uid; refresh())
		ForgeUi.sound(button)
		for state in ["normal","hover","pressed","focus","disabled"]:
			var lit: bool = state=="hover" or state=="focus"
			button.add_theme_stylebox_override(state,ForgeUi.plate_box(
				Color(1,.94,.84,.02) if empty else Color(1,.94,.84,.075 if lit else .045),
				Color(0,0,0,.20),
				Color(GILT.r,GILT.g,GILT.b,.10 if empty else (.55 if lit else .30)),Vector2(9,4),5.0))
		slots.add_child(button)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 9
		row.offset_right = -9
		row.add_theme_constant_override("separation",8)
		button.add_child(row)
		ForgeUi.caps(row,SLOT_NAMES[slot],10,FADED,2.0).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var worn_name := ForgeUi.title(row,"Empty" if empty else outfit[slot].name+"  +%d"%item.upgrade,12,FADED if empty else VELLUM,0.5)
		worn_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		worn_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		worn_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		worn_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ForgeUi.passthrough(row)
	GearVisuals.apply(preview,outfit)
	var stats: Dictionary = game.combat.stats()
	summary.text = "%d health  ·  %d stamina\n%.1f weapon dmg  ·  %.1f protection"%[stats.health,stats.stamina,float(game.combat.weapon().damage) if gear.equipped.has("weapon") else 0.0,game.combat.protection()]
	clear(grid)
	cards.clear()
	var items: Array = gear.inventory.duplicate()
	items.sort_custom(func(a,b):
		var ad := GearCatalog.find(a.id)
		var bd := GearCatalog.find(b.id)
		if sort_mode==2 and a.upgrade!=b.upgrade: return a.upgrade>b.upgrade
		if sort_mode==0 and ad.slot!=bd.slot: return GearCatalog.SLOTS.find(ad.slot)<GearCatalog.SLOTS.find(bd.slot)
		return ad.name<bd.name if ad.name!=bd.name else a.uid<b.uid)
	var visible_items: Array = []
	for item in items:
		if filter_slot=="all" or GearCatalog.find(item.id).slot==filter_slot: visible_items.append(item)
	if gear.owned(selected).is_empty() or not visible_items.any(func(item): return item.uid==selected): selected=visible_items[0].uid if not visible_items.is_empty() else 0
	for item in visible_items: make_card(item)
	if visible_items.is_empty():
		var empty := ForgeUi.text(grid,"No items here.\nThe blacksmith offers a free starter greatsword.",15,FADED)
		empty.custom_minimum_size = Vector2(220,140)
	show_details()

func make_card(item: Dictionary) -> void:
	var def := GearCatalog.find(item.id)
	var tier: Array = ForgeUi.RARITY.get(def.id.get_slice("_",0),ForgeUi.RARITY.warden)
	var tint: Color = tier[1]
	var worn: bool = game.equipment.equipped.get(def.slot,0)==item.uid
	var chosen: bool = selected==item.uid
	var button := Button.new()
	button.custom_minimum_size = Vector2(140,178)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	for state in ["normal","hover","pressed","focus"]:
		var hot: bool = state=="hover" or state=="pressed" or state=="focus"
		var box := ForgeUi.plate_box(
			Color(.175,.150,.115,.96) if chosen else (Color(.125,.118,.108,.94) if hot else Color(.095,.090,.083,.92)),
			Color(.075,.066,.052,.97) if chosen else (Color(.062,.058,.054,.95) if hot else Color(.048,.046,.043,.93)),
			Color(GILT.r,GILT.g,GILT.b,.85) if chosen else Color(tint.r,tint.g,tint.b,.55 if hot else .26),
			Vector2.ZERO,9.0)
		if chosen:
			box.inner = Color(GILT.r,GILT.g,GILT.b,.28)
			box.sheen = Color(1,.84,.55,.10)
			box.drop = 3.0
		elif hot:
			box.sheen = Color(1,.90,.72,.05)
			box.drop = 2.0
		button.add_theme_stylebox_override(state,box)
	button.set_meta("item_uid",item.uid)
	button.pressed.connect(func():
		selected = item.uid
		refresh()
		for card in cards:
			if card.get_meta("item_uid")==selected: card.grab_focus())
	ForgeUi.sound(button)
	grid.add_child(button)
	cards.append(button)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",8)
	margin.add_theme_constant_override("margin_right",8)
	margin.add_theme_constant_override("margin_top",14)
	margin.add_theme_constant_override("margin_bottom",10)
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	margin.add_child(column)
	var art_holder := CenterContainer.new()
	art_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(art_holder)
	art_holder.add_child(item_art(def,80,false))
	var label := ForgeUi.title(column,def.name,13,VELLUM,0.5)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.y = 34
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation",6)
	column.add_child(footer)
	var pips := ForgeUi.Pips.new()
	pips.maximum = game.equipment.max_upgrade()
	pips.rank = int(item.upgrade)
	pips.custom_minimum_size = Vector2(62,12)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(pips)
	ForgeUi.number(footer,"#%d"%item.uid,11,FADED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if worn:
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		row.offset_left = 7
		row.offset_right = -7
		row.offset_top = 7
		row.offset_bottom = 31
		row.alignment = BoxContainer.ALIGNMENT_END
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		ForgeUi.tag(row,"Worn",GILT,true)
	if chosen:
		var marks := ForgeUi.Corners.new()
		marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		marks.color = Color(GILT.r,GILT.g,GILT.b,.85)
		marks.arm = 13
		marks.inset = 5
		button.add_child(marks)
	ForgeUi.passthrough(margin)
	for child in button.get_children(): ForgeUi.passthrough(child)

func show_details() -> void:
	clear(details)
	clear(actions)
	detail_fade.modulate = Color(1,1,1,0)
	create_tween().set_ease(Tween.EASE_OUT).tween_property(detail_fade,"modulate",Color(1,1,1,1),.16)
	var gear: Node = game.equipment
	var item: Dictionary = gear.owned(selected)
	if item.is_empty():
		ForgeUi.spacer(details,20)
		var mark := UiKit.GearIcon.new()
		mark.slot = filter_slot if filter_slot!="all" else "chest"
		mark.modulate = Color(1,1,1,.22)
		mark.custom_minimum_size = Vector2(88,88)
		var holder := CenterContainer.new()
		holder.add_child(mark)
		details.add_child(holder)
		ForgeUi.spacer(details,10)
		var title := ForgeUi.title(details,"Your bag is empty",21,PARCH,1.5)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var hint := ForgeUi.text(details,"Your greatsword and four plate pieces live here. Select owned gear to inspect or equip it.",14,FADED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	var def: Dictionary = gear.stats(item)
	var catalog := GearCatalog.find(item.id)
	var tier: Array = ForgeUi.RARITY.get(item.id.get_slice("_",0),ForgeUi.RARITY.warden)
	var tint: Color = tier[1]
	var worn: bool = gear.equipped.get(def.slot,0)==item.uid
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",14)
	details.add_child(head)
	var frame_box := ForgeUi.plate_box(Color(tint.r,tint.g,tint.b,.13),Color(0,0,0,.30),Color(tint.r,tint.g,tint.b,.50),Vector2(4,4),8.0)
	frame_box.sheen = Color(1,.92,.78,.07)
	var frame := ForgeUi.panel(head,frame_box)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_child(item_art(catalog,84,false))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",8)
	head.add_child(text)
	ForgeUi.spacer(text,2)
	var name := ForgeUi.title(text,def.name+(" +%d"%item.upgrade if item.upgrade>0 else ""),21,tint.lightened(.12),1.0)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation",6)
	chips.add_theme_constant_override("v_separation",5)
	text.add_child(chips)
	ForgeUi.tag(chips,tier[0],tint,true)
	ForgeUi.tag(chips,SLOT_NAMES[def.slot],FADED,false)
	ForgeUi.tag(chips,"Level %d"%def.level,BAD if gear.level<def.level else Color(.62,.72,.60),false)
	ForgeUi.spacer(details,4)
	ForgeUi.text(details,def.description,14,PARCH)
	ForgeUi.rule(details,false)
	ForgeUi.caps(details,"Stats")
	ForgeUi.spacer(details,2)
	var current: Dictionary = gear.owned(gear.equipped.get(def.slot,0))
	var baseline: Dictionary = gear.stats(current) if not worn and not current.is_empty() else {}
	for key in ["damage","speed","stamina","protection","weight"]:
		if not def.has(key): continue
		ForgeUi.measure(details,key,float(def[key]),float(baseline[key]) if baseline.has(key) else -1.0,96.0)
	if not baseline.is_empty(): ForgeUi.text(details,"Compared with the %s you wear: %s"%[SLOT_NAMES[def.slot].to_lower(),baseline.name],12,FADED)
	ForgeUi.text(details,"Tempering is available at the blacksmith. Each copy keeps its own upgrade rank.",12,FADED)
	var action := ForgeUi.button(actions,"Unequip" if worn else ("Equip greatsword" if def.slot=="weapon" else "Equip armour"),toggle_item,gear.level<def.level,"secondary" if worn else "primary")
	action.name = "EquipAction"
	action.focus_mode = Control.FOCUS_ALL
	if gear.level<def.level:
		var why := ForgeUi.text(actions,"Requires level %d."%def.level,13,FORGE)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func toggle_item() -> void:
	if game.combat.active: return
	var item: Dictionary = game.equipment.owned(selected)
	if item.is_empty():
		refresh()
		return
	var slot: String = GearCatalog.find(item.id).slot
	var worn: bool = game.equipment.equipped.get(slot,0)==selected
	var error: String = game.equipment.unequip(slot) if worn else game.equipment.equip(selected)
	if error.is_empty(): game.audio.ui("unequip" if worn else ("equip_weapon" if slot=="weapon" else "equip_armor"),-10)
	message(error if not error.is_empty() else ("Unequipped " if worn else "Equipped ")+GearCatalog.find(item.id).name+".",BAD if not error.is_empty() else GOOD)
	refresh()

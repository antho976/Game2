extends CanvasLayer
# The forge storefront, laid out as a page from the same illuminated book the
# opening cinematic comes from: vellum ground, cut steel plates, gilt rules,
# and one lit alcove on the right where the armour is actually worn.
var game: Node
var active := false
var root: Control
var rows: GridContainer
var rows_scroll: ScrollContainer
var detail: VBoxContainer
var actions: VBoxContainer
var detail_fade: Control
var balance: Label
var level_label: Label
var status: Label
var status_dot: ColorRect
var tabs: ForgeUi.TabStrip
var tab_order: Array[String] = []
var filters: HBoxContainer
var filter_buttons := {}
var preview: Node3D
var thumbnails: GearThumbnails
var page := "stock"
var selected_id := "warden_blade"
var selected_uid := 0
var filter_slot := "all"
var confirm: ConfirmationDialog
var scrim: ColorRect
var pending_uid := 0
var pending_rank := 0
var pending_quote: Dictionary = {}
const GILT := ForgeUi.GILT
const VELLUM := ForgeUi.VELLUM
const PARCH := ForgeUi.PARCH
const FADED := ForgeUi.FADED
const FORGE := ForgeUi.FORGE
const GOOD := ForgeUi.VERDIGRIS
const BAD := ForgeUi.BLOOD
const GearIcon := UiKit.GearIcon
const SLOT_NAMES := {"all":"All","weapon":"Swords","helmet":"Helms","chest":"Cuirasses","gloves":"Gauntlets","boots":"Greaves"}
const SLOT_SINGULAR := {"weapon":"Sword","helmet":"Helm","chest":"Cuirass","gloves":"Gauntlets","boots":"Greaves"}
const STAT_NAMES := {"damage":"Damage","speed":"Attack speed","stamina":"Stamina cost","protection":"Protection","weight":"Weight"}
const STAT_MAX := {"damage":70.0,"speed":1.3,"stamina":40.0,"protection":26.0,"weight":12.0}
const STAT_COLORS := {"damage":Color(.95,.55,.28),"speed":Color(.58,.80,.96),"stamina":Color(.86,.72,.40),"protection":Color(.60,.78,.96),"weight":Color(.70,.66,.60)}
const LOWER_BETTER := ["stamina","weight"]
static func tier_of(id: String) -> Array:
	return ForgeUi.RARITY.get(id.get_slice("_",0),ForgeUi.RARITY.warden)
func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.theme = ForgeUi.theme()
	ForgeUi.page(root)
	thumbnails = GearThumbnails.new()
	add_child(thumbnails)
	thumbnails.finished.connect(func():
		if active: refresh())
	# The page on the left, the lit alcove on the right, sharing no border.
	var split := HBoxContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation",0)
	root.add_child(split)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_stretch_ratio = 2.5
	for side in ["left","top","bottom"]: margin.add_theme_constant_override("margin_"+side,26)
	margin.add_theme_constant_override("margin_right",18)
	split.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	margin.add_child(body)
	build_header(body)
	build_nav(body)
	build_columns(body)
	build_smith_line(body)
	build_alcove(split)
	scrim = ColorRect.new()
	scrim.color = Color(0,0,0,.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.hide()
	root.add_child(scrim)
	confirm = ConfirmationDialog.new()
	confirm.title = "Risk this item?"
	confirm.ok_button_text = "Attempt upgrade"
	confirm.confirmed.connect(attempt_upgrade)
	ForgeUi.skin(confirm.get_ok_button(),"danger")
	ForgeUi.skin(confirm.get_cancel_button(),"secondary")
	ForgeUi.sound(confirm.get_ok_button(),"confirm")
	ForgeUi.sound(confirm.get_cancel_button(),"back")
	for dialog_button in [confirm.get_ok_button(),confirm.get_cancel_button()]: dialog_button.focus_mode = Control.FOCUS_ALL
	root.add_child(confirm)
	confirm.about_to_popup.connect(func(): scrim.show())
	confirm.visibility_changed.connect(func():
		if not confirm.visible: scrim.hide())
	game.research.changed.connect(func():
		if active: refresh()
	)
	root.hide()
	preview.process_mode = Node.PROCESS_MODE_DISABLED

# ---------------------------------------------------------------- chrome

func build_header(body: Node) -> void:
	var header := ForgeUi.header(body,"The Blacksmith","Forge and armoury")
	var coin := GearIcon.new()
	coin.slot = "coin"
	coin.custom_minimum_size = Vector2(19,19)
	balance = ForgeUi.counter(header,coin,GILT)
	level_label = ForgeUi.counter(header,null,Color(.78,.76,.71),"Level")
	var leave := ForgeUi.button(header,"Leave  ·  Esc",close,false,"ghost",14)
	leave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ForgeUi.rule(body)

func build_nav(body: Node) -> void:
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation",12)
	body.add_child(nav)
	tabs = ForgeUi.TabStrip.new()
	nav.add_child(tabs)
	for tab in [["stock","Buy equipment"],["owned","Your equipment"],["upgrade","The anvil"]]:
		tabs.add(tab[1],func(): page=tab[0]; selected_uid=0; refresh())
		tab_order.append(tab[0])
	filters = HBoxContainer.new()
	filters.add_theme_constant_override("separation",6)
	filters.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nav.add_child(filters)
	for slot in ["all"]+GearCatalog.SLOTS:
		var button := Button.new()
		button.text = SLOT_NAMES[slot]
		button.custom_minimum_size.y = 30
		button.add_theme_font_override("font",ForgeUi.tracked(1.0,false))
		button.add_theme_font_size_override("font_size",11)
		button.pressed.connect(func(): filter_slot=slot; refresh())
		ForgeUi.sound(button)
		filters.add_child(button)
		filter_buttons[slot] = button

func build_columns(body: Node) -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	# The rack carries no chrome of its own: the cards float on the page.
	rows_scroll = ScrollContainer.new()
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_scroll.size_flags_stretch_ratio = 1.35
	rows_scroll.custom_minimum_size.x = 300
	ForgeUi.style_scroll(rows_scroll)
	columns.add_child(rows_scroll)
	var rack_margin := MarginContainer.new()
	rack_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rack_margin.add_theme_constant_override("margin_right",12)
	rack_margin.add_theme_constant_override("margin_bottom",8)
	rows_scroll.add_child(rack_margin)
	rows = GridContainer.new()
	rows.columns = 3
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("h_separation",12)
	rows.add_theme_constant_override("v_separation",12)
	rack_margin.add_child(rows)
	rows_scroll.resized.connect(fit_columns)
	# The appraisal is the only heavy plate; the eye should land here.
	var appraisal := ForgeUi.panel(columns,ForgeUi.appraisal_box(Vector2(24,22)))
	appraisal.custom_minimum_size.x = 330
	appraisal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var corners := ForgeUi.Corners.new()
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corners.color = Color(GILT.r,GILT.g,GILT.b,.55)
	corners.inset = 7
	appraisal.add_child(corners)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",10)
	appraisal.add_child(stack)
	detail_fade = stack
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ForgeUi.style_scroll(detail_scroll)
	stack.add_child(detail_scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",7)
	detail_scroll.add_child(detail)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation",8)
	stack.add_child(actions)

func build_smith_line(body: Node) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",11)
	body.add_child(line)
	status_dot = ColorRect.new()
	status_dot.color = GILT
	status_dot.custom_minimum_size = Vector2(8,8)
	status_dot.pivot_offset = Vector2(4,4)
	status_dot.rotation = PI*.25
	status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(status_dot)
	status = ForgeUi.text(line,"Claim your first blade here. Earn gold and experience in the yard or the mine.",14,FADED)
	status.add_theme_font_override("font",ForgeUi.tracked(1.0,false))
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL

## The alcove: the mannequin stands in the forge light with nothing framing it.
func build_alcove(split: Node) -> void:
	var alcove := Control.new()
	alcove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alcove.size_flags_stretch_ratio = 1.35
	alcove.custom_minimum_size.x = 420
	alcove.clip_contents = true
	split.add_child(alcove)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	alcove.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(420,900)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	container.add_child(viewport)
	container.resized.connect(func():
		viewport.size = Vector2i(maxi(64,int(container.size.x)),maxi(64,int(container.size.y))))
	build_fitting_room(viewport)
	var caption := VBoxContainer.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -58
	caption.offset_left = 40
	caption.offset_right = -40
	caption.offset_bottom = -16
	caption.add_theme_constant_override("separation",6)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alcove.add_child(caption)
	ForgeUi.rule(caption,true,Color(GILT.r,GILT.g,GILT.b,.30))
	var hint := ForgeUi.caps(caption,"Drag to turn",10,FADED,3.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.gui_input.connect(func(event):
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): preview.rotation.y+=event.relative.x*.012
	)

func build_fitting_room(viewport: SubViewport) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.80,.73,.66)
	env.environment.ambient_light_energy = .48
	viewport.add_child(env)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = .34
	torus.outer_radius = .375
	torus.rings = 24
	ring.mesh = torus
	ring.position.y = .006
	ring.material_override = GearVisuals.material(Color(.17,.12,.05),.55)
	viewport.add_child(ring)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-36,-30,0)
	key_light.light_energy = 1.5
	key_light.light_color = Color(1,.95,.88)
	key_light.shadow_enabled = true
	viewport.add_child(key_light)
	# The forge itself, off to the right and below, throwing an ember rim.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-8,140,0)
	rim.light_energy = 1.35
	rim.light_color = Color(.99,.56,.26)
	viewport.add_child(rim)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.95
	viewport.add_child(camera)
	camera.position = Vector3(0,1.62,4)
	camera.look_at(Vector3(0,.94,0))
	preview = load("res://assets/village/player_refined.glb").instantiate()
	viewport.add_child(preview)
	preview.rotation.y = -.35
	preview.position.x = -.06
	var anim: AnimationPlayer = preview.find_children("*","AnimationPlayer",true,false)[0]
	anim.get_animation("villager_idle").loop_mode = Animation.LOOP_LINEAR
	anim.play("villager_idle")

# ---------------------------------------------------------------- lifecycle

func fit_columns() -> void:
	if is_instance_valid(rows): rows.columns = clampi(int((rows_scroll.size.x+12)/172),2,4)
func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
func open() -> void:
	if not game.equipment.starter_claimed:
		page = "stock"
		selected_id = "warden_blade"
		filter_slot = "all"
	active = true
	game.audio.ui("shop_open",-10)
	game.audio.set_loop_volume("forge",-13)
	preview.process_mode = Node.PROCESS_MODE_INHERIT
	game.input_blocked = true
	game.ui.hide()
	game.sync_camera_mouse()
	root.show()
	refresh()
	if not thumbnails.ready_for_use: thumbnails.warm(GearCatalog.items())
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
func message(text: String,tone := GILT) -> void:
	if tone == BAD: game.audio.ui("ui_denied")
	status.text = text
	status.add_theme_color_override("font_color",VELLUM if tone==GILT else tone)
	status_dot.color = tone
	status_dot.modulate = Color(1,1,1,0)
	create_tween().tween_property(status_dot,"modulate",Color(1,1,1,1),.45)
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

# ---------------------------------------------------------------- pieces

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
	var icon := GearIcon.new()
	icon.slot = def.slot
	icon.tier = ["warden","pilgrim","citadel"].find(def.id.get_slice("_",0))
	icon.custom_minimum_size = Vector2(extent*.72,extent*.72)
	if dim: icon.modulate = Color(.45,.45,.45)
	return icon

func style_nav() -> void:
	tabs.mark(tab_order.find(page))
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
		button.add_theme_color_override("font_pressed_color",GILT.lightened(.2))
		button.focus_mode = Control.FOCUS_NONE

func card_in(def: Dictionary,entry: Dictionary,selected: bool) -> Button:
	var tier: Array = tier_of(def.id)
	var tint: Color = tier[1]
	var locked: bool = game.equipment.level<def.level
	var worn: bool = page!="stock" and game.equipment.equipped.get(def.slot,0)==int(entry.get("uid",-1))
	var card := Button.new()
	card.custom_minimum_size = Vector2(158,198)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	card.clip_contents = false
	for state in ["normal","hover","pressed","focus"]:
		var hot: bool = state=="hover" or state=="pressed"
		var box := ForgeUi.plate_box(
			Color(.175,.150,.115,.96) if selected else (Color(.125,.118,.108,.94) if hot else Color(.095,.090,.083,.92)),
			Color(.075,.066,.052,.97) if selected else (Color(.062,.058,.054,.95) if hot else Color(.048,.046,.043,.93)),
			Color(GILT.r,GILT.g,GILT.b,.85) if selected else Color(tint.r,tint.g,tint.b,.55 if hot else .26),
			Vector2.ZERO,9.0)
		if selected:
			box.inner = Color(GILT.r,GILT.g,GILT.b,.28)
			box.sheen = Color(1,.84,.55,.10)
			box.drop = 3.0
		elif hot:
			box.sheen = Color(1,.90,.72,.05)
			box.drop = 2.0
		card.add_theme_stylebox_override(state,box)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",8)
	margin.add_theme_constant_override("margin_right",8)
	margin.add_theme_constant_override("margin_top",14)
	margin.add_theme_constant_override("margin_bottom",10)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	margin.add_child(column)
	var art_holder := CenterContainer.new()
	art_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(art_holder)
	art_holder.add_child(item_art(def,92,locked))
	var name := ForgeUi.title(column,def.name,14,VELLUM if not locked else FADED,1.0)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.custom_minimum_size.y = 36
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation",6)
	column.add_child(footer)
	if page=="stock":
		var coin := GearIcon.new()
		coin.slot = "coin"
		coin.custom_minimum_size = Vector2(13,13)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		footer.add_child(coin)
		var affordable: bool = game.equipment.gold>=game.equipment.purchase_price(def.id)
		ForgeUi.number(footer,str(game.equipment.purchase_price(def.id)),15,GILT.lightened(.2) if affordable and not locked else Color(.66,.44,.36))
		ForgeUi.caps(footer,tier[0],10,tint,2.0).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		var pips := ForgeUi.Pips.new()
		pips.maximum = game.equipment.max_upgrade()
		pips.rank = int(entry.upgrade)
		pips.custom_minimum_size = Vector2(66,13)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		footer.add_child(pips)
		ForgeUi.number(footer,"#%d"%entry.uid,11,FADED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if locked: badge(card,"Lv %d"%def.level,BAD,false)
	if page=="stock" and owned_count(def.id)>0: badge(card,"Owned ×%d"%owned_count(def.id),GOOD,true)
	elif worn: badge(card,"Worn",GILT,true)
	if selected:
		var corners := ForgeUi.Corners.new()
		corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		corners.color = Color(GILT.r,GILT.g,GILT.b,.85)
		corners.arm = 14
		corners.inset = 5
		card.add_child(corners)
	ForgeUi.passthrough(margin)
	for child in card.get_children(): ForgeUi.passthrough(child)
	# Hover lifts the plate rather than merely tinting it.
	card.mouse_entered.connect(func():
		if is_instance_valid(card): create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).tween_property(card,"scale",Vector2(1.035,1.035),.12))
	card.mouse_exited.connect(func():
		if is_instance_valid(card): create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).tween_property(card,"scale",Vector2.ONE,.14))
	card.resized.connect(func(): card.pivot_offset = card.size*.5)
	card.pivot_offset = card.custom_minimum_size*.5
	return card

func badge(card: Control,label: String,color: Color,right: bool) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = 7
	row.offset_right = -7
	row.offset_top = 7
	row.offset_bottom = 31
	row.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	ForgeUi.tag(row,label,color,true)

func stat_row(key: String,value: float,baseline: Variant) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	detail.add_child(row)
	var name := ForgeUi.caps(row,STAT_NAMES[key],11,FADED,2.0)
	name.custom_minimum_size.x = 108
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar := ForgeUi.Bar.new()
	bar.value = value
	bar.maximum = STAT_MAX[key]
	bar.baseline = float(baseline) if baseline!=null else -1.0
	bar.color = STAT_COLORS[key]
	bar.custom_minimum_size = Vector2(70,11)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var amount := ForgeUi.number(row,fmt(key,value),17,VELLUM)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.custom_minimum_size.x = 46
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var delta_label := ForgeUi.number(row,"",12,FADED)
	delta_label.custom_minimum_size.x = 52
	delta_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	head.add_theme_constant_override("separation",16)
	detail.add_child(head)
	var frame_box := ForgeUi.plate_box(Color(tint.r,tint.g,tint.b,.13),Color(0,0,0,.30),Color(tint.r,tint.g,tint.b,.50),Vector2(4,4),8.0)
	frame_box.sheen = Color(1,.92,.78,.07)
	var frame := ForgeUi.panel(head,frame_box)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_child(item_art(def,96,false))
	var corners := ForgeUi.Corners.new()
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corners.color = Color(tint.r,tint.g,tint.b,.65)
	corners.arm = 12
	corners.inset = 4
	frame.add_child(corners)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",8)
	head.add_child(text)
	ForgeUi.spacer(text,2)
	var name := ForgeUi.title(text,def.name+(" +%d"%rank if rank>0 else ""),22,tint.lightened(.12),1.0)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation",6)
	chips.add_theme_constant_override("v_separation",5)
	text.add_child(chips)
	ForgeUi.tag(chips,tier[0],tint,true)
	ForgeUi.tag(chips,SLOT_SINGULAR[def.slot],FADED,false)
	ForgeUi.tag(chips,"Level %d"%def.level,BAD if game.equipment.level<def.level else Color(.62,.72,.60),false)

# ---------------------------------------------------------------- refresh

func refresh() -> void:
	if not is_instance_valid(rows): return
	balance.text = "%d"%game.equipment.gold
	level_label.text = "%d"%game.equipment.level
	style_nav()
	fit_columns()
	clear(rows)
	clear(detail)
	clear(actions)
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
		ForgeUi.sound(card)
		rows.add_child(card)
	# The appraisal fades in whenever what it describes changes.
	detail_fade.modulate = Color(1,1,1,0)
	create_tween().set_ease(Tween.EASE_OUT).tween_property(detail_fade,"modulate",Color(1,1,1,1),.16)
	if visible_entries.is_empty():
		ForgeUi.spacer(detail,34)
		var empty := GearIcon.new()
		empty.slot = filter_slot if filter_slot!="all" else "chest"
		empty.modulate = Color(1,1,1,.22)
		empty.custom_minimum_size = Vector2(96,96)
		var holder := CenterContainer.new()
		holder.add_child(empty)
		detail.add_child(holder)
		ForgeUi.spacer(detail,10)
		var title := ForgeUi.title(detail,"The rack is empty" if page!="stock" else "Nothing on this rack",22,PARCH,2.0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var hint := ForgeUi.text(detail,"Bought pieces hang here. Browse Buy equipment to see what the forge offers." if page!="stock" else "Try another slot filter.",14,FADED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		GearVisuals.apply(preview,loadout())
		return
	selected_id = selected.id
	selected_uid = 0 if page=="stock" else int(selected.uid)
	var def := GearCatalog.find(selected_id)
	var rank: int = selected.get("upgrade",0)
	var stats: Dictionary = game.equipment.stats(selected)
	item_header(def,rank)
	ForgeUi.spacer(detail,4)
	ForgeUi.text(detail,def.description,14,PARCH)
	ForgeUi.rule(detail,false)
	ForgeUi.caps(detail,"Stats")
	ForgeUi.spacer(detail,2)
	var current = game.equipment.owned(game.equipment.equipped.get(def.slot,0))
	var comparing: bool = not current.is_empty() and not (page!="stock" and int(current.uid)==selected_uid)
	var baseline: Dictionary = game.equipment.stats(current) if comparing else {}
	for key in ["damage","speed","stamina","protection","weight"]:
		if not stats.has(key): continue
		stat_row(key,float(stats[key]),baseline[key] if baseline.has(key) else null)
	if comparing: ForgeUi.text(detail,"Compared with the %s you wear: %s"%[SLOT_SINGULAR[def.slot].to_lower(),GearCatalog.find(current.id).name],12,FADED)
	ForgeUi.rule(detail,false)
	var display := loadout()
	display[def.slot] = def
	GearVisuals.apply(preview,display)
	if page=="stock": actions_stock(def)
	elif page=="owned": actions_owned(def)
	else: actions_anvil(def,rank,stats)
	if actions.get_child_count()>0: actions.move_child(ForgeUi.rule(actions,false),0)

func actions_stock(def: Dictionary) -> void:
	if def.id=="warden_blade" and not game.equipment.starter_claimed:
		ForgeUi.text(detail,"A blade for your first journey. The smith offers you one greatsword, free of charge.",14,GOOD)
		ForgeUi.button(actions,"Accept starter greatsword  ·  Free",func():
			var error: String = game.equipment.claim_starter()
			message(error if not error.is_empty() else "It's yours. Keep your guard up. Press I to open your inventory.",BAD if not error.is_empty() else GOOD)
		,false,"primary")
	var reason: String = game.equipment.buy_error(selected_id)
	ForgeUi.button(actions,"Buy  ·  %d gold"%game.equipment.purchase_price(def.id),func():
		var error: String = game.equipment.buy(selected_id)
		if error.is_empty(): game.audio.ui("shop_buy",-8)
		message(error if not error.is_empty() else "Purchased "+def.name+". It hangs under Your equipment.",BAD if not error.is_empty() else GOOD)
	,not reason.is_empty(),"primary")
	if not reason.is_empty():
		var why := ForgeUi.text(actions,reason,13,FORGE)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if def.slot!="weapon":
		ForgeUi.button(actions,"Try on the full "+("Warden" if def.style==0 else "Citadel")+" set",func():
			var suit := {}
			for slot in ["helmet","chest","gloves","boots"]: suit[slot] = GearCatalog.find(("warden_" if def.style==0 else "citadel_")+slot)
			suit.weapon = GearCatalog.find("warden_blade" if def.style==0 else "citadel_blade")
			GearVisuals.apply(preview,suit)
			status.text = "Showing the complete set. Nothing was bought or equipped."
		)

func actions_owned(def: Dictionary) -> void:
	var worn: bool = game.equipment.equipped.get(def.slot,0)==selected_uid
	ForgeUi.button(actions,"Unequip" if worn else "Equip",func():
		var error: String = game.equipment.unequip(def.slot) if worn else game.equipment.equip(selected_uid)
		if error.is_empty(): game.audio.ui("unequip" if worn else ("equip_weapon" if def.slot=="weapon" else "equip_armor"),-10)
		message(error if not error.is_empty() else ("Unequipped " if worn else "Equipped ")+def.name,BAD if not error.is_empty() else GOOD)
	,false,"secondary" if worn else "primary")
	ForgeUi.button(actions,"Take to the anvil",func(): page="upgrade"; refresh())

func actions_anvil(def: Dictionary,rank: int,stats: Dictionary) -> void:
	var selected = game.equipment.owned(selected_uid)
	ForgeUi.caps(detail,"Tempering")
	ForgeUi.spacer(detail,2)
	var pips := ForgeUi.Pips.new()
	pips.maximum = game.equipment.max_upgrade()
	pips.rank = rank
	pips.next = rank<game.equipment.max_upgrade()
	pips.custom_minimum_size = Vector2(150,22)
	var pip_row := HBoxContainer.new()
	pip_row.add_theme_constant_override("separation",14)
	detail.add_child(pip_row)
	pip_row.add_child(pips)
	ForgeUi.title(pip_row,"Fully tempered  ·  +%d"%rank if rank>=game.equipment.max_upgrade() else "+%d  →  +%d"%[rank,rank+1],18,GILT,1.5)
	if rank>=game.equipment.max_upgrade():
		ForgeUi.text(detail,"This piece has taken every temper the forge can give.",14,FADED)
		return
	var chance: float = game.equipment.survival(selected)
	var gauge_row := HBoxContainer.new()
	gauge_row.add_theme_constant_override("separation",12)
	detail.add_child(gauge_row)
	var survive := ForgeUi.caps(gauge_row,"Survival",11,FADED,2.0)
	survive.custom_minimum_size.x = 108
	survive.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gauge := ForgeUi.Bar.new()
	gauge.value = chance
	gauge.maximum = 1
	gauge.color = BAD.lerp(GOOD,chance)
	gauge.custom_minimum_size = Vector2(70,11)
	gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge_row.add_child(gauge)
	var odds := ForgeUi.number(gauge_row,"%.0f%%"%(chance*100),17,BAD.lerp(GOOD,chance))
	odds.custom_minimum_size.x = 52
	odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	odds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var next: Dictionary = game.equipment.next_stats(selected)
	var key := "damage" if def.slot=="weapon" else "protection"
	var gain_row := HBoxContainer.new()
	gain_row.add_theme_constant_override("separation",12)
	detail.add_child(gain_row)
	var gain_name := ForgeUi.caps(gain_row,STAT_NAMES[key],11,FADED,2.0)
	gain_name.custom_minimum_size.x = 108
	gain_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ForgeUi.number(gain_row,"%s  →  %s"%[fmt(key,float(stats[key])),fmt(key,float(next[key]))],17,GOOD)
	var warn_box := ForgeUi.plate_box(Color(.26,.10,.05,.75),Color(.14,.05,.03,.8),Color(FORGE.r,FORGE.g,FORGE.b,.45),Vector2(13,9),7.0)
	var warning := ForgeUi.panel(detail,warn_box)
	ForgeUi.text(warning,"%.0f%% chance the forge ruins it. Failure spends the gold and destroys this exact copy, even while worn. Other copies are safe."%((1-chance)*100),13,FORGE)
	var reason: String = game.equipment.upgrade_error(selected_uid)
	ForgeUi.button(actions,"Temper  ·  %d gold"%game.equipment.upgrade_cost(selected),request_upgrade,not reason.is_empty(),"danger")
	if not reason.is_empty():
		var why := ForgeUi.text(actions,reason,13,FORGE)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func request_upgrade() -> void:
	var item = game.equipment.owned(selected_uid)
	if item.is_empty(): return
	pending_uid = selected_uid
	pending_rank = item.upgrade
	pending_quote = game.equipment.upgrade_quote(item)
	confirm.dialog_text = "%s +%d → +%d\nCost: %d gold\nSurvival: %.0f%%\n\nFailure permanently destroys copy #%d. Gold is spent either way."%[GearCatalog.find(item.id).name,item.upgrade,item.upgrade+1,game.equipment.upgrade_cost(item),game.equipment.survival(item)*100,item.uid]
	confirm.popup_centered(Vector2i(520,280))
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

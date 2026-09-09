extends CanvasLayer
var game: Node
var active:=false
var root: Control
var grid: GridContainer
var slots: VBoxContainer
var details: VBoxContainer
var purse: Label
var summary: Label
var notice: Label
var preview: Node3D
var viewport: SubViewport
var selected:=0
var filter_slot:="all"
var sort_mode:=0
var cards: Array[Button]=[]
const SLOT_NAMES:={"weapon":"Greatsword","helmet":"Helmet","chest":"Chest","gloves":"Gloves","boots":"Boots"}
func _ready() -> void:
	layer=30
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme=UiKit.theme()
	add_child(root)
	UiKit.backdrop(root,[Color(.035,.075,.073),Color(.025,.04,.037),Color(.015,.021,.019)],Vector2(.1,.4))
	var margins:=MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margins.add_theme_constant_override("margin_"+side,24)
	root.add_child(margins)
	var body:=VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	margins.add_child(body)
	var header:=HBoxContainer.new()
	body.add_child(header)
	var title:=UiKit.label(header,"EQUIPMENT & BELONGINGS",26,UiKit.GOLD)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var close_button:=UiKit.button(header,"Close  ·  I / Esc",close)
	close_button.focus_mode=Control.FOCUS_ALL
	purse=UiKit.label(body,"",15,UiKit.PARCH)
	var columns:=HBoxContainer.new()
	columns.add_theme_constant_override("separation",14)
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var worn:=UiKit.panel(columns,UiKit.flat(Color(.04,.062,.056,.95),UiKit.tinted(UiKit.GOLD,.28),1,8,Vector2(14,12)))
	worn.custom_minimum_size.x=240
	var worn_column:=VBoxContainer.new()
	worn.add_child(worn_column)
	UiKit.label(worn_column,"WORN EQUIPMENT",14,UiKit.GOLD)
	var display:=SubViewportContainer.new()
	display.custom_minimum_size=Vector2(200,160)
	display.size_flags_vertical=Control.SIZE_EXPAND_FILL
	display.stretch=true
	worn_column.add_child(display)
	viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.size=Vector2i(260,260)
	display.add_child(viewport)
	build_preview()
	display.gui_input.connect(func(event):
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):preview.rotation.y+=event.relative.x*.012)
	UiKit.label(worn_column,"Drag to turn · Shows your equipped gear",11,UiKit.MUTED)
	slots=VBoxContainer.new()
	slots.add_theme_constant_override("separation",4)
	worn_column.add_child(slots)
	summary=UiKit.label(worn_column,"",12,UiKit.MUTED)
	var bag:=UiKit.panel(columns,UiKit.flat(Color(.032,.045,.040,.9),UiKit.tinted(UiKit.GOLD,.25),1,8,Vector2(12,12)))
	bag.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var bag_column:=VBoxContainer.new()
	bag.add_child(bag_column)
	var tools:=HBoxContainer.new()
	bag_column.add_child(tools)
	var filter:=OptionButton.new()
	for name in ["All items","Greatswords","Helmets","Chest armor","Gloves","Boots"]:filter.add_item(name)
	filter.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	filter.item_selected.connect(func(index):filter_slot=(["all"]+GearCatalog.SLOTS)[index];refresh())
	tools.add_child(filter)
	var sort:=OptionButton.new()
	for name in ["By type","By name","Highest upgrade"]:sort.add_item(name)
	sort.item_selected.connect(func(index):sort_mode=index;refresh())
	tools.add_child(sort)
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	bag_column.add_child(scroll)
	grid=GridContainer.new()
	grid.columns=3
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	scroll.resized.connect(func():grid.columns=maxi(1,int((scroll.size.x+8)/125)))
	var appraisal:=UiKit.panel(columns,UiKit.flat(Color(.05,.065,.056,.96),UiKit.tinted(UiKit.GOLD,.4),1,8,Vector2(16,14)))
	appraisal.custom_minimum_size.x=276
	var detail_scroll:=ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	appraisal.add_child(detail_scroll)
	details=VBoxContainer.new()
	details.custom_minimum_size.x=240
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",10)
	detail_scroll.add_child(details)
	notice=UiKit.label(body,"Select an item to compare it with your worn equipment.",13,UiKit.MUTED)
	root.hide()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
func build_preview() -> void:
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.025,.039,.034)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.78,.87,.90)
	env.environment.ambient_light_energy=.65
	viewport.add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-38,-38,0)
	light.light_energy=1.4
	viewport.add_child(light)
	var fill:=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-22,130,0)
	fill.light_color=Color(.52,.73,1)
	fill.light_energy=.6
	viewport.add_child(fill)
	preview=load("res://assets/village/player_refined.glb").instantiate()
	viewport.add_child(preview)
	preview.rotation.y=-.25
	var camera:=Camera3D.new()
	viewport.add_child(camera)
	camera.position=Vector3(0,1.05,4)
	camera.look_at(Vector3(0,1.03,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.3
	camera.current=true
func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
func open() -> void:
	if game.input_blocked or game.menus.home:return
	if game.combat.active:
		game.toast("Finish the fight before changing equipment.")
		return
	active=true
	game.input_blocked=true
	game.ui.hide()
	game.sync_camera_mouse()
	root.show()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	notice.text="Select an item to compare it with your worn equipment."
	refresh()
	if not cards.is_empty():cards[0].grab_focus()
func close() -> void:
	active=false
	root.hide()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	game.input_blocked=false
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
func refresh() -> void:
	var gear: Node=game.equipment
	purse.text="Level %d    ·    %d gold    ·    %d diamonds    ·    %d living essence    ·    %d items"%[gear.level,gear.gold,gear.diamonds,gear.life_essence,gear.inventory.size()]
	clear(slots)
	var outfit:={}
	for slot in GearCatalog.SLOTS:
		var item: Dictionary=gear.owned(gear.equipped.get(slot,0))
		var title: String=SLOT_NAMES[slot]+"  ·  Empty"
		if not item.is_empty():
			outfit[slot]=GearCatalog.find(item.id)
			title=outfit[slot].name+"  +%d"%item.upgrade
		var button:=UiKit.button(slots,title,func():selected=item.uid;refresh(),item.is_empty(),"secondary")
		button.custom_minimum_size.y=34
		button.add_theme_font_size_override("font_size",12)
		button.focus_mode=Control.FOCUS_ALL
	GearVisuals.apply(preview,outfit)
	var stats: Dictionary=game.combat.stats()
	summary.text="%d health  ·  %d stamina\n%.1f weapon dmg  ·  %.1f protection"%[stats.health,stats.stamina,float(game.combat.weapon().damage) if gear.equipped.has("weapon") else 0.0,game.combat.protection()]
	clear(grid)
	cards.clear()
	var items: Array=gear.inventory.duplicate()
	items.sort_custom(func(a,b):
		var ad:=GearCatalog.find(a.id)
		var bd:=GearCatalog.find(b.id)
		if sort_mode==2 and a.upgrade!=b.upgrade:return a.upgrade>b.upgrade
		if sort_mode==0 and ad.slot!=bd.slot:return GearCatalog.SLOTS.find(ad.slot)<GearCatalog.SLOTS.find(bd.slot)
		return ad.name<bd.name if ad.name!=bd.name else a.uid<b.uid)
	var visible_items: Array=[]
	for item in items:
		if filter_slot=="all" or GearCatalog.find(item.id).slot==filter_slot:visible_items.append(item)
	if gear.owned(selected).is_empty() or not visible_items.any(func(item):return item.uid==selected):selected=visible_items[0].uid if not visible_items.is_empty() else 0
	for item in visible_items:make_card(item)
	if visible_items.is_empty():
		var empty:=UiKit.label(grid,"No items here.\nThe blacksmith offers a free starter greatsword.",15,UiKit.MUTED)
		empty.custom_minimum_size=Vector2(220,140)
	show_details()
func make_card(item: Dictionary) -> void:
	var def:=GearCatalog.find(item.id)
	var worn: bool=game.equipment.equipped.get(def.slot,0)==item.uid
	var button:=Button.new()
	button.custom_minimum_size=Vector2(117,138)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	UiKit.skin(button,"secondary")
	button.focus_mode=Control.FOCUS_ALL
	if selected==item.uid:button.add_theme_stylebox_override("normal",UiKit.flat(Color(.17,.21,.15),UiKit.GOLD,2,6))
	button.set_meta("item_uid",item.uid)
	button.pressed.connect(func():
		selected=item.uid
		refresh()
		for card in cards:
			if card.get_meta("item_uid")==selected:card.grab_focus())
	grid.add_child(button)
	cards.append(button)
	var box:=VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left=7;box.offset_right=-7;box.offset_top=8;box.offset_bottom=-7
	button.add_child(box)
	var icon:=UiKit.GearIcon.new()
	icon.slot=def.slot
	icon.tier=def.style
	icon.custom_minimum_size=Vector2(56,56)
	box.add_child(icon)
	var label:=UiKit.label(box,def.name,12)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var mark:=UiKit.label(box,("WORN  ·  " if worn else "")+"+%d"%item.upgrade,11,UiKit.GOLD if worn else UiKit.MUTED)
	mark.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	ignore_mouse(box)
func ignore_mouse(node: Node) -> void:
	if node is Control:node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():ignore_mouse(child)
func show_details() -> void:
	clear(details)
	var gear: Node=game.equipment
	var item: Dictionary=gear.owned(selected)
	if item.is_empty():
		UiKit.label(details,"YOUR INVENTORY",20,UiKit.GOLD)
		UiKit.label(details,"Keep your greatsword and four plate pieces here. Select owned gear to inspect or equip it.",15,UiKit.MUTED)
		return
	var def: Dictionary=gear.stats(item)
	var worn: bool=gear.equipped.get(def.slot,0)==item.uid
	UiKit.label(details,def.name,23,UiKit.GOLD)
	UiKit.label(details,SLOT_NAMES[def.slot]+"  ·  +%d  ·  Level %d"%[item.upgrade,def.level],13,UiKit.MUTED)
	UiKit.label(details,def.description,14)
	UiKit.divider(details)
	var current: Dictionary=gear.owned(gear.equipped.get(def.slot,0))
	var baseline: Dictionary=gear.stats(current) if not current.is_empty() else {}
	for key in ["damage","speed","stamina","protection","weight"]:
		if not def.has(key):continue
		var line: String=key.capitalize()+"   %.1f"%def[key]
		if not worn and baseline.has(key):line+="   (%+.1f)"%(float(def[key])-float(baseline[key]))
		UiKit.label(details,line,16)
	if not worn and not baseline.is_empty():UiKit.label(details,"Compared with "+baseline.name+". Lower weight and stamina cost are better.",12,UiKit.MUTED)
	UiKit.divider(details)
	var action:=UiKit.button(details,"Unequip" if worn else "Equip greatsword" if def.slot=="weapon" else "Equip armor",func():toggle_item(),gear.level<def.level,"secondary" if worn else "primary")
	action.name="EquipAction"
	action.focus_mode=Control.FOCUS_ALL
	if gear.level<def.level:UiKit.label(details,"Requires level %d."%def.level,13,UiKit.EMBER)
	UiKit.label(details,"Tempering is available at the blacksmith. Each copy keeps its own upgrade rank.",12,UiKit.MUTED)
func toggle_item() -> void:
	if game.combat.active:return
	var item: Dictionary=game.equipment.owned(selected)
	if item.is_empty():refresh();return
	var slot: String=GearCatalog.find(item.id).slot
	var worn: bool=game.equipment.equipped.get(slot,0)==selected
	var error: String=game.equipment.unequip(slot) if worn else game.equipment.equip(selected)
	notice.text=error if not error.is_empty() else ("Unequipped " if worn else "Equipped ")+GearCatalog.find(item.id).name+"."
	refresh()

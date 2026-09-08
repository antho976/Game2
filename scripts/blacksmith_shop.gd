extends CanvasLayer
var game: Node
var active := false
var root: Control
var rows: VBoxContainer
var detail: VBoxContainer
var balance: Label
var status: Label
var tabs: HBoxContainer
var preview: Node3D
var page := "stock"
var selected_id := "warden_blade"
var selected_uid := 0
var filter_slot := "all"
var confirm: ConfirmationDialog
var pending_uid := 0
var pending_rank := 0
var pending_quote: Dictionary = {}
func label_in(parent: Node,text: String,size := 18,color := Color(.86,.85,.78)) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label
func button_in(parent: Node,title: String,callback: Callable,disabled := false) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 42
	button.disabled = disabled
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.theme = game.menus.root.theme
	var shade := ColorRect.new()
	shade.color = Color(.018,.025,.025,.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	root.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",14)
	margin.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := label_in(header,"THE BLACKSMITH",30,Color(.83,.70,.44))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	balance = label_in(header,"",20)
	balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button_in(header,"Leave · Esc",close)
	tabs = HBoxContainer.new()
	body.add_child(tabs)
	for spec in [["stock","Buy equipment"],["owned","Your equipment"],["upgrade","Upgrade"]]:
		button_in(tabs,spec[1],func(): page=spec[0]; selected_uid=0; refresh())
	var filter := OptionButton.new()
	for slot in ["all"]+GearCatalog.SLOTS: filter.add_item(slot.capitalize())
	filter.item_selected.connect(func(index): filter_slot=(["all"]+GearCatalog.SLOTS)[index]; refresh())
	tabs.add_child(filter)
	status = label_in(body,"Gold and levels will come from progression. Combat comes later.",16,Color(.68,.73,.69))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 270
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",7)
	scroll.add_child(rows)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size.x = 265
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(detail_scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",12)
	detail_scroll.add_child(detail)
	var visual := VBoxContainer.new()
	visual.custom_minimum_size.x = 250
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(visual)
	label_in(visual,"FITTING PREVIEW",16,Color(.83,.70,.44))
	label_in(visual,"Drag to rotate. Previewing does not equip or purchase an item.",14)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(240,300)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.stretch = true
	visual.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(380,580)
	viewport.own_world_3d = true
	container.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.055,.072,.074)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.72,.80,.86)
	env.environment.ambient_light_energy = .7
	viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-30,0)
	light.light_energy = 1.5
	viewport.add_child(light)
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
	container.gui_input.connect(func(event):
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): preview.rotation.y+=event.relative.x*.012
	)
	confirm = ConfirmationDialog.new()
	confirm.title = "Risk this item?"
	confirm.ok_button_text = "Attempt upgrade"
	confirm.confirmed.connect(attempt_upgrade)
	root.add_child(confirm)
	game.research.changed.connect(func():
		if active: refresh()
	)
	root.hide()
	preview.process_mode = Node.PROCESS_MODE_DISABLED
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
func message(text: String) -> void:
	status.text = text
	refresh()
func loadout() -> Dictionary:
	var result := {}
	for slot in game.equipment.equipped:
		var item = game.equipment.owned(game.equipment.equipped[slot])
		if not item.is_empty(): result[slot] = GearCatalog.find(item.id)
	return result
func refresh() -> void:
	if not is_instance_valid(rows): return
	balance.text = "%d gold   ·   Level %d"%[game.equipment.gold,game.equipment.level]
	clear(rows)
	clear(detail)
	var entries: Array = GearCatalog.items() if page=="stock" else game.equipment.inventory
	var visible_entries: Array = []
	for entry in entries:
		var def: Dictionary = entry if page=="stock" else GearCatalog.find(entry.id)
		if filter_slot!="all" and def.slot!=filter_slot: continue
		visible_entries.append(entry)
		var caption: String = def.name
		if page=="stock": caption+="\n%d gold · Level %d"%[game.equipment.purchase_price(def.id),def.level]
		else:
			caption+=" +%d  ·  #%d"%[entry.upgrade,entry.uid]
			if game.equipment.equipped.get(def.slot,0)==entry.uid: caption+="  [equipped]"
		button_in(rows,caption,func(): selected_id=def.id; selected_uid=0 if page=="stock" else entry.uid; preview.rotation.y=2.8 if def.slot=="weapon" else -.35; refresh())
	if visible_entries.is_empty():
		label_in(detail,"No equipment here yet.",24)
		label_in(detail,"Purchased items appear here. Browse Buy equipment to inspect the available gear.",16)
		GearVisuals.apply(preview,loadout())
		return
	var selected: Dictionary = {}
	for entry in visible_entries:
		if (page=="stock" and entry.id==selected_id) or (page!="stock" and entry.uid==selected_uid): selected=entry
	if selected.is_empty(): selected=visible_entries[0]
	selected_id = selected.id
	selected_uid = 0 if page=="stock" else int(selected.uid)
	var def := GearCatalog.find(selected_id)
	var rank: int = selected.get("upgrade",0)
	var stats: Dictionary = game.equipment.stats(selected)
	label_in(detail,def.name+(" +%d"%rank if rank>0 else ""),26,Color(.91,.80,.58))
	label_in(detail,def.slot.capitalize()+" · Requires level %d"%def.level,15)
	label_in(detail,def.description,16)
	var current = game.equipment.owned(game.equipment.equipped.get(def.slot,0))
	var baseline: Dictionary = game.equipment.stats(current) if not current.is_empty() else {}
	for key in ["damage","speed","stamina","protection","weight"]:
		if not stats.has(key): continue
		var text := "%s: %s"%[{"damage":"Damage","speed":"Attack speed","stamina":"Stamina cost","protection":"Protection","weight":"Weight"}[key],str(stats[key])]
		if baseline.has(key): text+="  (%+.1f vs equipped)"%(float(stats[key])-float(baseline[key]))
		label_in(detail,text,18)
	var display := loadout()
	display[def.slot] = def
	GearVisuals.apply(preview,display)
	if page=="stock":
		if def.slot!="weapon":
			button_in(detail,"Preview complete plate set",func():
				var suit := {}
				for slot in ["helmet","chest","gloves","boots"]: suit[slot] = GearCatalog.find(("warden_" if def.style==0 else "citadel_")+slot)
				suit.weapon = GearCatalog.find("warden_blade" if def.style==0 else "citadel_blade")
				GearVisuals.apply(preview,suit)
				status.text = "Previewing the complete set. No equipment was purchased or equipped."
			)
		var reason: String = game.equipment.buy_error(selected_id)
		button_in(detail,"Buy · %d gold"%game.equipment.purchase_price(def.id),func():
			var error: String = game.equipment.buy(selected_id)
			message(error if not error.is_empty() else "Purchased "+def.name+". Find it in Your equipment.")
		,not reason.is_empty())
		if not reason.is_empty(): label_in(detail,reason,16,Color(.88,.59,.43))
	elif page=="owned":
		var worn: bool = game.equipment.equipped.get(def.slot,0)==selected_uid
		button_in(detail,"Unequip" if worn else "Equip",func():
			var error: String = game.equipment.unequip(def.slot) if worn else game.equipment.equip(selected_uid)
			message(error if not error.is_empty() else ("Unequipped " if worn else "Equipped ")+def.name)
		)
	else:
		if rank>=game.equipment.max_upgrade(): label_in(detail,"Current upgrade limit · +%d"%game.equipment.max_upgrade(),22)
		else:
			var chance: float = game.equipment.survival(selected)
			label_in(detail,"+%d → +%d"%[rank,rank+1],24)
			label_in(detail,"%.0f%% survives and improves\n%.0f%% permanently destroyed"%[chance*100,(1-chance)*100],18,Color(.94,.66,.43))
			var next: Dictionary = game.equipment.next_stats(selected)
			var key := "damage" if def.slot=="weapon" else "protection"
			label_in(detail,"%s: %s → %s"%[key.capitalize(),stats[key],next[key]])
			label_in(detail,"Failure consumes the gold and this exact item, including equipped gear. Other copies are safe.",16)
			var reason: String = game.equipment.upgrade_error(selected_uid)
			button_in(detail,"Upgrade · %d gold"%game.equipment.upgrade_cost(selected),request_upgrade,not reason.is_empty())
			if not reason.is_empty(): label_in(detail,reason,16,Color(.88,.59,.43))
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
	message(result.error if not result.error.is_empty() else ("Upgrade succeeded. The item is stronger." if result.survived else "Upgrade failed. That item was permanently destroyed."))

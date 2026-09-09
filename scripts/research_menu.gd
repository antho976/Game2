extends CanvasLayer
var game: Node
var active := false
var root: Control
var graph: Control
var detail: VBoxContainer
var jobs: HBoxContainer
var balance: Label
var summary: Label
var status: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_time := 0.0
var selected := "conditioning"
var tree_index := 0
var progress_widgets: Dictionary = {}
var clock := 0.0
const GOLD := Color(.86,.73,.48)
const TEXT := Color(.85,.87,.83)
func label(parent: Node,value: String,size := 17,color := TEXT) -> Label:
	var node := Label.new()
	node.text=value
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node
func button(parent: Node,value: String,callback: Callable,disabled := false) -> Button:
	var node := Button.new()
	node.text=value
	node.custom_minimum_size.y=40
	node.disabled=disabled
	node.pressed.connect(callback)
	parent.add_child(node)
	return node
func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
func _ready() -> void:
	layer=21
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme=game.menus.root.theme
	add_child(root)
	var shade := ColorRect.new()
	shade.color=Color(.025,.044,.044,.99)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	root.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	margin.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := label(header,"THE ARCHIVE",30,GOLD)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title.autowrap_mode=TextServer.AUTOWRAP_OFF
	balance=label(header,"",18)
	balance.autowrap_mode=TextServer.AUTOWRAP_OFF
	button(header,"Leave · Esc",close)
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	for i in ResearchCatalog.TREES.size():
		button(tabs,ResearchCatalog.TREES[i],func(): tree_index=i; selected=""; refresh())
	button(tabs,"Journal",func(): tree_index=5; refresh())
	summary=label(body,"",15,Color(.58,.75,.72))
	status=label(body,"Choose a study to inspect its branches, costs and bonuses.",15)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",20)
	body.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	columns.add_child(scroll)
	graph=Control.new()
	graph.custom_minimum_size=Vector2(540,480)
	var center := CenterContainer.new()
	center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	center.add_child(graph)
	var details_scroll := ScrollContainer.new()
	details_scroll.custom_minimum_size.x=clampf(get_viewport().get_visible_rect().size.x*.29,290,420)
	get_viewport().size_changed.connect(func(): details_scroll.custom_minimum_size.x=clampf(get_viewport().get_visible_rect().size.x*.29,290,420))
	columns.add_child(details_scroll)
	detail=VBoxContainer.new()
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",12)
	details_scroll.add_child(detail)
	label(body,"RESEARCH DESKS  /  Paused studies keep their progress and free a desk",14,GOLD)
	var jobs_scroll := ScrollContainer.new()
	jobs_scroll.custom_minimum_size.y=138
	body.add_child(jobs_scroll)
	jobs=HBoxContainer.new()
	jobs.add_theme_constant_override("separation",12)
	jobs_scroll.add_child(jobs)
	toast_panel=PanelContainer.new()
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toast_panel.offset_left=-450
	toast_panel.offset_right=-24
	toast_panel.offset_top=90
	toast_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color=Color(.07,.16,.14,.98)
	style.border_color=GOLD
	style.set_border_width_all(1)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=14
	style.content_margin_bottom=14
	toast_panel.add_theme_stylebox_override("panel",style)
	add_child(toast_panel)
	toast_label=label(toast_panel,"",18,GOLD)
	toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	toast_panel.hide()
	root.hide()
	game.research.changed.connect(func():
		if active: refresh()
	)
	game.research.finished.connect(notify)
func notify(message: String) -> void:
	toast_label.text=message
	toast_time=8
	toast_panel.show()
func show_unread() -> void:
	var count := 0
	for entry in game.research.journal:
		if entry.get("unread",false): count+=1
	if count>0: notify("%d completed studies\nBonuses are active. Details are in the archive journal."%count)
func open() -> void:
	active=true
	game.input_blocked=true
	game.ui.hide()
	game.sync_camera_mouse()
	root.show()
	refresh()
func close() -> void:
	active=false
	root.hide()
	game.input_blocked=false
	game.ui.show()
	game.sync_camera_mouse()
func _input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
func time_text(seconds: float) -> String:
	var total := int(ceil(seconds))
	return "%dm %02ds"%[total/60,total%60] if total>=60 else "%ds"%total
func act(result: String) -> void:
	status.text=result if not result.is_empty() else "Research updated. Progress and payment are saved."
	refresh()
func refresh() -> void:
	if not active: return
	var research = game.research
	balance.text="%d gold   ·   %d diamonds"%[game.equipment.gold,game.equipment.diamonds]
	summary.text="%d / %d desks active   ·   Offline speed: %.0f%%   ·   Bonuses activate automatically"%[research.running_count(),research.slots(),research.offline_rate()*100]
	clear(graph)
	clear(detail)
	clear(jobs)
	progress_widgets.clear()
	if tree_index==5:
		var list := VBoxContainer.new()
		list.position=Vector2(12,10)
		list.size=Vector2(505,580)
		list.add_theme_constant_override("separation",14)
		graph.add_child(list)
		label(list,"Completed studies",27,GOLD)
		if research.journal.is_empty(): label(list,"Your discoveries will be recorded here.")
		for entry in research.journal: label(list,("NEW · " if entry.get("unread",false) else "")+str(entry.message))
		graph.custom_minimum_size.y=maxf(610,70+research.journal.size()*62)
		button(detail,"Mark all as read",research.acknowledge)
		label(detail,"Current bonuses",24,GOLD)
		var stats: Dictionary=research.player_stats()
		label(detail,"Maximum health: %.0f\nMaximum stamina: %.0f\nStamina recovery: +%.0f%%"%[stats.health,stats.stamina,(stats.stamina_recovery_multiplier-1)*100])
		label(detail,"Character bonuses are recorded for the upcoming combat system.",15)
		label(detail,"Purchase discount: %.0f%%\nUpgrade discount: %.0f%%\nNew upgrade gains: %.1f%% of base stats\nItem upgrade limit: +%d"%[research.bonus("shop_discount")*100,research.bonus("forge_discount")*100,game.equipment.next_gain()*100,game.equipment.max_upgrade()])
	else:
		graph.custom_minimum_size.y=480
		var definitions: Array[Dictionary]=[]
		for def in ResearchCatalog.all():
			if def.tree==tree_index: definitions.append(def)
		if selected.is_empty() or ResearchCatalog.find(selected).get("tree",-1)!=tree_index: selected=definitions[0].id
		for def in definitions:
			for req in def.requires:
				var previous := ResearchCatalog.find(req)
				var from: Vector2=Vector2(previous.pos.x,previous.pos.y*.78)+Vector2(110,96)
				var to: Vector2=Vector2(def.pos.x,def.pos.y*.78)+Vector2(110,0)
				var line := Line2D.new()
				line.width=2
				line.default_color=Color(.53,.65,.44) if int(research.completed.get(req,0))>=def.requires[req] else Color(.22,.30,.28)
				line.points=PackedVector2Array([from,Vector2(from.x,(from.y+to.y)*.5),Vector2(to.x,(from.y+to.y)*.5),to])
				graph.add_child(line)
		for def in definitions:
			var rank: int=research.completed.get(def.id,0)
			var state: String="Completed" if rank>=def.ranks else "Available"
			for req in def.requires:
				if int(research.completed.get(req,0))<def.requires[req]: state="Locked"
			if def.wip: state="In development"
			if research.projects.has(def.id): state="Paused" if research.projects[def.id].paused else "Researching"
			var node := button(graph,"%s\n%s\n%d / %d ranks"%[def.name,state,rank,def.ranks],func(): selected=def.id; refresh())
			node.position=Vector2(def.pos.x,def.pos.y*.78)
			node.size=Vector2(220,96)
			node.add_theme_font_size_override("font_size",16)
			var style := StyleBoxFlat.new()
			style.bg_color=Color(.12,.22,.19) if rank>0 else Color(.07,.115,.108)
			style.border_color=GOLD if def.id==selected else Color(.23,.38,.33)
			style.set_border_width_all(2 if def.id==selected else 1)
			style.set_corner_radius_all(5)
			node.add_theme_stylebox_override("normal",style)
		show_detail(ResearchCatalog.find(selected))
	for id in research.projects:
		var project: Dictionary=research.projects[id]
		var card := VBoxContainer.new()
		card.custom_minimum_size.x=220
		jobs.add_child(card)
		label(card,ResearchCatalog.find(id).name+" · %d"%project.rank,16,GOLD)
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y=14
		progress.show_percentage=false
		card.add_child(progress)
		var remaining := label(card,"",14)
		progress_widgets[id]=[progress,remaining]
		button(card,"Resume" if project.paused else "Pause",func(): act(research.set_paused(id,not project.paused)))
	for i in maxi(0,research.slots()-research.running_count()):
		var empty := VBoxContainer.new()
		empty.custom_minimum_size.x=180
		jobs.add_child(empty)
		label(empty,"OPEN DESK",16,Color(.45,.57,.52))
		label(empty,"Select an available study\nto begin.",14)
	update_progress()
func show_detail(def: Dictionary) -> void:
	var research=game.research
	var rank: int=research.completed.get(def.id,0)
	label(detail,def.name,25,GOLD)
	label(detail,"Rank %d / %d"%[rank,def.ranks],15)
	label(detail,def.description,17)
	if not def.requires.is_empty():
		label(detail,"Prerequisites",16,GOLD)
		for req in def.requires:
			label(detail,"%s · rank %d %s"%[ResearchCatalog.find(req).name,def.requires[req],"✓" if int(research.completed.get(req,0))>=def.requires[req] else "required"],15)
	if def.wip:
		label(detail,"WIP · No cost or timer until this branch is ready.",16)
	elif research.projects.has(def.id):
		label(detail,"This rank is already paid for. Pausing keeps all progress and releases its desk.",16)
		button(detail,"Resume study" if research.projects[def.id].paused else "Pause study",func(): act(research.set_paused(def.id,not research.projects[def.id].paused)))
	elif rank>=def.ranks:
		label(detail,"Fully researched",20,Color(.57,.79,.62))
	else:
		label(detail,"Next rank · %d"%(rank+1),20,GOLD)
		label(detail,"%d gold%s"%[def.gold[rank]," + %d diamonds"%def.diamonds[rank] if def.diamonds[rank]>0 else ""])
		label(detail,"Playing: %s\nOffline: about %s"%[time_text(def.times[rank]),time_text(def.times[rank]/research.offline_rate())],16)
		var reason: String=research.start_error(def.id)
		button(detail,"Begin research",func(): act(research.start(def.id)),not reason.is_empty())
		if not reason.is_empty(): label(detail,reason,15,Color(.85,.64,.46))
		label(detail,"Payment is taken when this rank starts. You can pause it, but cannot cancel or refund it.",14)
func update_progress() -> void:
	for id in progress_widgets:
		if not game.research.projects.has(id): continue
		var project: Dictionary=game.research.projects[id]
		var duration: float=ResearchCatalog.find(id).times[int(project.rank)-1]
		progress_widgets[id][0].value=(1-project.remaining/maxf(1,duration))*100
		progress_widgets[id][1].text=("Paused · " if project.paused else "Remaining · ")+time_text(project.remaining)
func _process(delta: float) -> void:
	if toast_time>0:
		toast_time-=delta
		if toast_time<=0: toast_panel.hide()
	if not active: return
	clock+=delta
	if clock>.25:
		clock=0
		update_progress()

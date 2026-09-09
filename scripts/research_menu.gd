extends CanvasLayer
# The archive: the same illuminated page as the forge, lit from a cold window
# instead of a fire. A study tree drawn straight onto the page, an appraisal
# plate for the chosen study, and a row of desks along the foot.
var game: Node
var active := false
var root: Control
var graph: Control
var detail: VBoxContainer
var actions: VBoxContainer
var detail_fade: Control
var jobs: HBoxContainer
var balance: Label
var diamonds: Label
var summary: Label
var status: Label
var status_dot: ColorRect
var desk_caption: Label
var tabs: ForgeUi.TabStrip
var toast_panel: PanelContainer
var toast_label: Label
var toast_time := 0.0
var selected := "conditioning"
var tree_index := 0
var progress_widgets: Dictionary = {}
var node_bars: Dictionary = {}
var clock := 0.0
const NODE_WIDTH := 238.0
const GILT := ForgeUi.GILT
const VELLUM := ForgeUi.VELLUM
const PARCH := ForgeUi.PARCH
const FADED := ForgeUi.FADED
const FORGE := ForgeUi.FORGE
const GOOD := ForgeUi.VERDIGRIS
const BAD := ForgeUi.BLOOD
const SAPPHIRE := ForgeUi.SAPPHIRE
const Glyph := UiKit.Glyph
# Glyph and colour for each research tree, in catalog order.
const TREE_LOOK := [["character",Color(.93,.58,.52)],["equipment",Color(.62,.78,.96)],["trade",Color(.87,.71,.37)],["scholarship",Color(.66,.82,.60)],["hub",Color(.62,.72,.66)]]
const STATE_COLORS := {"Completed":GOOD,"Researching":GILT,"Paused":FORGE,"Locked":FADED,"In development":FADED}
# Readable names for bonuses: label, display multiplier, suffix.
const EFFECTS := {"health":["Max health",1,""],"stamina":["Max stamina",1,""],"recovery":["Stamina recovery",100,"%"],"potency":["Upgrade gains",100,"%"],"survival":["Item survival",100,"%"],"upgrade_cap":["Upgrade limit",1,""],"shop_discount":["Purchase discount",100,"%"],"forge_discount":["Forging discount",100,"%"],"slots":["Research desks",1,""],"offline":["Offline speed",100,"%"]}
func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
func tree_color(def: Dictionary) -> Color:
	return TREE_LOOK[clampi(int(def.tree),0,TREE_LOOK.size()-1)][1]
## A study's mark, struck on a cut plate the way a piece of gear is framed.
func medallion(parent: Node,def: Dictionary,size: float,dim := false) -> PanelContainer:
	var tint := tree_color(def)
	var box := ForgeUi.plate_box(Color(tint.r,tint.g,tint.b,.06 if dim else .17),Color(0,0,0,.28),
		Color(tint.r,tint.g,tint.b,.25 if dim else .55),Vector2(size*.16,size*.16),size*.20)
	if not dim: box.sheen = Color(1,.94,.82,.07)
	var holder := ForgeUi.panel(parent,box)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var glyph := Glyph.new()
	glyph.kind = TREE_LOOK[clampi(int(def.tree),0,TREE_LOOK.size()-1)][0]
	glyph.color = tint
	glyph.custom_minimum_size = Vector2(size*.62,size*.62)
	if dim: glyph.modulate = Color(.55,.55,.55)
	holder.add_child(glyph)
	return holder
func fmt(value: float) -> String:
	return ("%d"%int(round(value))) if is_equal_approx(value,round(value)) else "%.1f"%value
func state_of(def: Dictionary) -> String:
	var research = game.research
	var rank: int = research.completed.get(def.id,0)
	var state := "Completed" if rank>=def.ranks else "Available"
	for req in def.requires:
		if int(research.completed.get(req,0))<def.requires[req]: state="Locked"
	if def.wip: state="In development"
	if research.projects.has(def.id): state="Paused" if research.projects[def.id].paused else "Researching"
	return state

func _ready() -> void:
	layer = 21
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = ForgeUi.theme()
	add_child(root)
	# A study, not a smithy: one cold window high on the right, a reading
	# lamp low on the left.
	ForgeUi.page(root,Color(.20,.13,.05),Vector2(.06,1.04),Color(.07,.10,.15),Vector2(.96,-.06))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,26)
	root.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	margin.add_child(body)
	var header := ForgeUi.header(body,"The Archive","Study, unlock and improve")
	var coin := Glyph.new()
	coin.kind = "coin"
	coin.custom_minimum_size = Vector2(19,19)
	balance = ForgeUi.counter(header,coin,GILT)
	var gem := Glyph.new()
	gem.kind = "diamond"
	gem.custom_minimum_size = Vector2(19,19)
	diamonds = ForgeUi.counter(header,gem,SAPPHIRE)
	var desk := Glyph.new()
	desk.kind = "desk"
	desk.color = PARCH
	desk.custom_minimum_size = Vector2(19,19)
	summary = ForgeUi.counter(header,desk,Color(.72,.74,.68))
	var leave := ForgeUi.button(header,"Leave  ·  Esc",close,false,"ghost",14)
	leave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ForgeUi.rule(body)
	tabs = ForgeUi.TabStrip.new()
	body.add_child(tabs)
	for i in ResearchCatalog.TREES.size():
		tabs.add(ResearchCatalog.TREES[i],func(): tree_index=i; selected=""; refresh(),14)
	tabs.add("Journal",func(): tree_index=5; refresh(),14)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",20)
	body.add_child(columns)
	# The tree is drawn straight onto the page; nothing frames it.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ForgeUi.style_scroll(scroll)
	columns.add_child(scroll)
	graph = Control.new()
	graph.custom_minimum_size = Vector2(NODE_WIDTH+320,480)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	center.add_child(graph)
	var parts := ForgeUi.appraisal(columns)
	var appraisal: PanelContainer = parts[0]
	appraisal.custom_minimum_size.x = clampf(get_viewport().get_visible_rect().size.x*.29,290,420)
	get_viewport().size_changed.connect(func(): appraisal.custom_minimum_size.x=clampf(get_viewport().get_visible_rect().size.x*.29,290,420))
	detail = parts[1]
	actions = parts[2]
	detail_fade = parts[3]
	var desk_row := HBoxContainer.new()
	desk_row.add_theme_constant_override("separation",12)
	body.add_child(desk_row)
	ForgeUi.caps(desk_row,"Research desks").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	desk_caption = ForgeUi.caps(desk_row,"",10,FADED,2.0)
	desk_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var jobs_scroll := ScrollContainer.new()
	jobs_scroll.custom_minimum_size.y = 108
	jobs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	jobs_scroll.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	body.add_child(jobs_scroll)
	jobs = HBoxContainer.new()
	jobs.add_theme_constant_override("separation",10)
	jobs_scroll.add_child(jobs)
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
	status = ForgeUi.text(line,"Choose a study to inspect its branches, costs and bonuses.",14,FADED)
	status.add_theme_font_override("font",ForgeUi.tracked(1.0,false))
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_toast()
	root.hide()
	game.research.changed.connect(func():
		if active: refresh()
	)
	game.research.finished.connect(notify)

func build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toast_panel.offset_left = -450
	toast_panel.offset_right = -26
	toast_panel.offset_top = 100
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := ForgeUi.appraisal_box(Vector2(18,14))
	box.edge = Color(GILT.r,GILT.g,GILT.b,.75)
	toast_panel.add_theme_stylebox_override("panel",box)
	add_child(toast_panel)
	var toast_row := HBoxContainer.new()
	toast_row.add_theme_constant_override("separation",12)
	toast_panel.add_child(toast_row)
	var toast_glyph := Glyph.new()
	toast_glyph.kind = "scholarship"
	toast_glyph.color = GILT
	toast_glyph.custom_minimum_size = Vector2(30,30)
	toast_glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	toast_row.add_child(toast_glyph)
	toast_label = ForgeUi.text(toast_row,"",15,PARCH)
	toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var corners := ForgeUi.Corners.new()
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corners.color = Color(GILT.r,GILT.g,GILT.b,.7)
	corners.arm = 12
	corners.inset = 5
	toast_panel.add_child(corners)
	toast_panel.hide()

func notify(message: String) -> void:
	game.audio.ui("research_complete",-8)
	toast_label.text = message
	toast_time = 8
	toast_panel.show()
	toast_panel.modulate = Color(1,1,1,0)
	create_tween().tween_property(toast_panel,"modulate",Color(1,1,1,1),.35)
func show_unread() -> void:
	var count := 0
	for entry in game.research.journal:
		if entry.get("unread",false): count+=1
	if count>0: notify("%d completed studies\nBonuses are active. Details are in the archive journal."%count)
func open() -> void:
	active = true
	game.audio.ui("archive_open",-10)
	game.input_blocked = true
	game.ui.hide()
	game.sync_camera_mouse()
	root.show()
	refresh()
func close() -> void:
	active = false
	game.audio.ui("archive_close",-12)
	root.hide()
	game.input_blocked = false
	game.ui.show()
	game.sync_camera_mouse()
func _input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
func time_text(seconds: float) -> String:
	var total := int(ceil(seconds))
	return "%dm %02ds"%[total/60,total%60] if total>=60 else "%ds"%total
func act(result: String,sound := "research_start") -> void:
	game.audio.ui("ui_denied" if not result.is_empty() else sound,-10)
	status.text = result if not result.is_empty() else "Research updated. Progress and payment are saved."
	var tone: Color = BAD if not result.is_empty() else GOOD
	status.add_theme_color_override("font_color",VELLUM)
	status_dot.color = tone
	status_dot.modulate = Color(1,1,1,0)
	create_tween().tween_property(status_dot,"modulate",Color(1,1,1,1),.45)
	refresh()

## A study on the board: a cut plate whose edge carries its state.
func study_node(def: Dictionary) -> Button:
	var research = game.research
	var rank: int = research.completed.get(def.id,0)
	var state := state_of(def)
	var tint := tree_color(def)
	var accent: Color = STATE_COLORS.get(state,tint)
	var locked: bool = state=="Locked" or state=="In development"
	var chosen: bool = def.id==selected
	var node := Button.new()
	node.position = Vector2(def.pos.x,def.pos.y*.78)
	node.size = Vector2(NODE_WIDTH,96)
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(func(): selected=def.id; refresh())
	ForgeUi.sound(node)
	var top: Color = {"Completed":Color(.10,.15,.10,.96),"Researching":Color(.175,.150,.105,.96),"Paused":Color(.17,.11,.07,.96)}.get(state,Color(.062,.060,.058,.88) if locked else Color(.105,.100,.093,.94))
	for state_name in ["normal","hover","pressed","focus"]:
		var hot: bool = state_name=="hover" or state_name=="pressed"
		var box := ForgeUi.plate_box(top.lightened(.06) if hot else top,
			Color(.048,.046,.043,.95),
			Color(GILT.r,GILT.g,GILT.b,.85) if chosen else Color(accent.r,accent.g,accent.b,(.45 if hot else .20) if locked else (.85 if hot else .45)),
			Vector2.ZERO,9.0)
		if chosen:
			box.inner = Color(GILT.r,GILT.g,GILT.b,.26)
			box.sheen = Color(1,.84,.55,.10)
			box.drop = 3.0
		elif hot:
			box.sheen = Color(1,.90,.72,.05)
			box.drop = 2.0
		node.add_theme_stylebox_override(state_name,box)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
	node.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",11)
	margin.add_child(row)
	medallion(row,def,54,locked)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",3)
	row.add_child(text)
	var name := ForgeUi.title(text,def.name,13,FADED if locked else VELLUM,0.5)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ForgeUi.caps(text,state,10,accent,3.0)
	var pips := ForgeUi.Pips.new()
	pips.maximum = maxi(1,int(def.ranks))
	pips.rank = rank
	pips.next = state=="Researching"
	pips.color = GOOD if state=="Completed" else GILT
	pips.custom_minimum_size = Vector2(minf(72,14*def.ranks),11)
	pips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	text.add_child(pips)
	if state=="Researching" or state=="Paused":
		var bar := ForgeUi.Bar.new()
		bar.color = accent
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_left = 10
		bar.offset_right = -10
		bar.offset_top = -8
		bar.offset_bottom = -4
		node.add_child(bar)
		node_bars[def.id] = bar
	if chosen:
		var mark := ForgeUi.Corners.new()
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mark.color = Color(GILT.r,GILT.g,GILT.b,.85)
		mark.arm = 13
		mark.inset = 5
		node.add_child(mark)
	for child in node.get_children(): ForgeUi.passthrough(child)
	return node

func refresh() -> void:
	if not active: return
	var research = game.research
	balance.text = "%d"%game.equipment.gold
	diamonds.text = "%d"%game.equipment.diamonds
	summary.text = "%d / %d"%[research.running_count(),research.slots()]
	desk_caption.text = "Offline speed %.0f%%  ·  paused studies keep their progress and free a desk"%(research.offline_rate()*100)
	var unread := 0
	for entry in research.journal:
		if entry.get("unread",false): unread+=1
	tabs.buttons[5].text = "Journal" if unread==0 else "Journal  ·  %d new"%unread
	tabs.mark(tree_index)
	clear(graph)
	clear(detail)
	clear(actions)
	clear(jobs)
	progress_widgets.clear()
	node_bars.clear()
	detail_fade.modulate = Color(1,1,1,0)
	create_tween().set_ease(Tween.EASE_OUT).tween_property(detail_fade,"modulate",Color(1,1,1,1),.16)
	if tree_index==5: show_journal()
	else:
		graph.custom_minimum_size.y = 480
		var definitions: Array[Dictionary] = []
		for def in ResearchCatalog.all():
			if def.tree==tree_index: definitions.append(def)
		if selected.is_empty() or ResearchCatalog.find(selected).get("tree",-1)!=tree_index: selected=definitions[0].id
		var lines := TreeLines.new()
		lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		graph.add_child(lines)
		for def in definitions:
			for req in def.requires:
				var previous := ResearchCatalog.find(req)
				var from: Vector2 = Vector2(previous.pos.x,previous.pos.y*.78)+Vector2(NODE_WIDTH*.5,96)
				var to: Vector2 = Vector2(def.pos.x,def.pos.y*.78)+Vector2(NODE_WIDTH*.5,0)
				lines.links.append([from,to,int(research.completed.get(req,0))>=int(def.requires[req]),tree_color(def)])
		for def in definitions: graph.add_child(study_node(def))
		show_detail(ResearchCatalog.find(selected))
	if actions.get_child_count()>0: actions.move_child(ForgeUi.rule(actions,false),0)
	for id in research.projects:
		var project: Dictionary = research.projects[id]
		var def := ResearchCatalog.find(id)
		var accent: Color = FORGE if project.paused else GILT
		var box := ForgeUi.plate_box(Color(.115,.108,.098,.94),Color(.052,.048,.044,.96),Color(accent.r,accent.g,accent.b,.55),Vector2(13,9),8.0)
		box.sheen = Color(1,.92,.76,.05)
		box.drop = 2.0
		var card := ForgeUi.panel(jobs,box)
		card.custom_minimum_size.x = 272
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",11)
		card.add_child(row)
		medallion(row,def,44)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation",5)
		row.add_child(column)
		var title := ForgeUi.title(column,"%s  ·  rank %d"%[def.name,project.rank],13,VELLUM,0.5)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var progress := ForgeUi.Bar.new()
		progress.color = accent
		progress.custom_minimum_size.y = 9
		column.add_child(progress)
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation",8)
		column.add_child(foot)
		var remaining := ForgeUi.caps(foot,"",10,FADED,2.0)
		remaining.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		remaining.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var toggle := ForgeUi.button(foot,"Resume" if project.paused else "Pause",func(): act(research.set_paused(id,not project.paused),"research_pause"),false,"secondary",12)
		toggle.custom_minimum_size.y = 26
		ForgeUi.skin(toggle,"secondary",Vector2(11,2),5.0)
		progress_widgets[id] = [progress,remaining]
	for i in maxi(0,research.slots()-research.running_count()):
		var empty := ForgeUi.panel(jobs,ForgeUi.plate_box(Color(1,.96,.88,.03),Color(0,0,0,.22),Color(1,.96,.88,.10),Vector2(14,9),8.0))
		empty.custom_minimum_size.x = 214
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",11)
		empty.add_child(row)
		var glyph := Glyph.new()
		glyph.kind = "desk"
		glyph.color = Color(.45,.50,.48)
		glyph.custom_minimum_size = Vector2(34,34)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		glyph.modulate = Color(1,1,1,.55)
		row.add_child(glyph)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation",3)
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(text)
		ForgeUi.caps(text,"Open desk",11,Color(.55,.60,.56),3.0)
		ForgeUi.text(text,"Pick an available study to begin.",12,FADED).autowrap_mode = TextServer.AUTOWRAP_OFF
	update_progress()

func show_journal() -> void:
	var research = game.research
	var list := VBoxContainer.new()
	list.position = Vector2(12,10)
	list.size = Vector2(NODE_WIDTH+296,580)
	list.add_theme_constant_override("separation",8)
	graph.add_child(list)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",11)
	list.add_child(head)
	var glyph := Glyph.new()
	glyph.kind = "scholarship"
	glyph.color = GILT
	glyph.custom_minimum_size = Vector2(28,28)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(glyph)
	ForgeUi.title(head,"Completed studies",24,GILT,2.0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ForgeUi.rule(list,false)
	if research.journal.is_empty():
		ForgeUi.text(list,"Your discoveries will be recorded here.",15,FADED)
	for entry in research.journal:
		var unread: bool = entry.get("unread",false)
		var box := ForgeUi.plate_box(Color(.15,.13,.09,.95) if unread else Color(.085,.082,.078,.90),
			Color(.06,.055,.048,.96),Color(GILT.r,GILT.g,GILT.b,.55) if unread else Color(1,.96,.88,.09),Vector2(13,8),7.0)
		if unread: box.sheen = Color(1,.90,.68,.07)
		var row := ForgeUi.panel(list,box)
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation",11)
		row.add_child(inner)
		var check := Glyph.new()
		check.kind = "check"
		check.color = GILT if unread else GOOD
		check.custom_minimum_size = Vector2(17,17)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(check)
		var text := ForgeUi.text(inner,str(entry.message),14,PARCH if unread else FADED)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if unread: ForgeUi.tag(inner,"New",GILT,true)
	graph.custom_minimum_size.y = maxf(480,70+research.journal.size()*48)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation",12)
	detail.add_child(head_row)
	var badge := Glyph.new()
	badge.kind = "character"
	badge.color = TREE_LOOK[0][1]
	badge.custom_minimum_size = Vector2(42,42)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(badge)
	ForgeUi.title(head_row,"Current bonuses",22,GILT,1.5).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ForgeUi.text(detail,"Every finished rank is already in effect. Character values wait for the combat system.",13,FADED)
	ForgeUi.rule(detail,false)
	var stats: Dictionary = research.player_stats()
	ForgeUi.caps(detail,"Character")
	bonus_row("Maximum health","%.0f"%stats.health,stats.health>100)
	bonus_row("Maximum stamina","%.0f"%stats.stamina,stats.stamina>100)
	bonus_row("Stamina recovery","+%.0f%%"%((stats.stamina_recovery_multiplier-1)*100),stats.stamina_recovery_multiplier>1)
	ForgeUi.spacer(detail,4)
	ForgeUi.caps(detail,"Forge and trade")
	bonus_row("Purchase discount","%.0f%%"%(research.bonus("shop_discount")*100),research.bonus("shop_discount")>0)
	bonus_row("Forging discount","%.0f%%"%(research.bonus("forge_discount")*100),research.bonus("forge_discount")>0)
	bonus_row("New upgrade gains","%.1f%% of base"%(game.equipment.next_gain()*100),research.bonus("potency")>0)
	bonus_row("Item survival","+%.0f points"%(research.bonus("survival")*100),research.bonus("survival")>0)
	bonus_row("Upgrade limit","+%d"%game.equipment.max_upgrade(),research.bonus("upgrade_cap")>0)
	ForgeUi.spacer(detail,4)
	ForgeUi.caps(detail,"Archive")
	bonus_row("Research desks","%d"%research.slots(),research.slots()>2)
	bonus_row("Offline speed","%.0f%%"%(research.offline_rate()*100),research.bonus("offline")>0)
	var unread := 0
	for entry in research.journal:
		if entry.get("unread",false): unread+=1
	ForgeUi.button(actions,"Mark all as read",research.acknowledge,unread==0,"secondary")

func bonus_row(name: String,value: String,improved: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	detail.add_child(row)
	var label := ForgeUi.caps(row,name,11,FADED,2.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var amount := ForgeUi.number(row,value,16,GOOD if improved else VELLUM)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func cost_row(gold: int,diamond_cost: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	detail.add_child(row)
	var name := ForgeUi.caps(row,"Cost",11,FADED,2.0)
	name.custom_minimum_size.x = 88
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coin := Glyph.new()
	coin.kind = "coin"
	coin.custom_minimum_size = Vector2(16,16)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	ForgeUi.number(row,"%d"%gold,16,GILT.lightened(.2) if game.equipment.gold>=gold else BAD)
	if diamond_cost>0:
		ForgeUi.spacer(row,0)
		var gem := Glyph.new()
		gem.kind = "diamond"
		gem.custom_minimum_size = Vector2(16,16)
		gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(gem)
		ForgeUi.number(row,"%d"%diamond_cost,16,SAPPHIRE if game.equipment.diamonds>=diamond_cost else BAD)

func show_detail(def: Dictionary) -> void:
	var research = game.research
	var rank: int = research.completed.get(def.id,0)
	var state := state_of(def)
	var tint := tree_color(def)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",14)
	detail.add_child(head)
	var frame := medallion(head,def,70)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var corners := ForgeUi.Corners.new()
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corners.color = Color(tint.r,tint.g,tint.b,.65)
	corners.arm = 11
	corners.inset = 4
	frame.add_child(corners)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",8)
	head.add_child(text)
	ForgeUi.spacer(text,2)
	var name := ForgeUi.title(text,def.name,22,tint.lightened(.12),1.0)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation",6)
	chips.add_theme_constant_override("v_separation",5)
	text.add_child(chips)
	ForgeUi.tag(chips,ResearchCatalog.TREES[def.tree].get_slice(" ",0),tint,true)
	ForgeUi.tag(chips,state,STATE_COLORS.get(state,tint),false)
	ForgeUi.tag(chips,"Rank %d / %d"%[rank,def.ranks],FADED,false)
	ForgeUi.spacer(detail,4)
	ForgeUi.text(detail,def.description,14,PARCH)
	ForgeUi.rule(detail,false)
	if not def.effects.is_empty():
		ForgeUi.caps(detail,"Bonus per rank")
		for key in def.effects:
			var spec: Array = EFFECTS.get(key,[key.capitalize(),1,""])
			var per: float = float(def.effects[key])*spec[1]
			var now: String = fmt(per*rank)+spec[2]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation",10)
			detail.add_child(row)
			var label := ForgeUi.caps(row,spec[0],11,FADED,2.0)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var amount := ForgeUi.number(row,"+"+now+("  →  +"+fmt(per*(rank+1))+spec[2] if rank<def.ranks else ""),16,GOOD if rank>0 else VELLUM)
			amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not def.requires.is_empty():
		ForgeUi.spacer(detail,4)
		ForgeUi.caps(detail,"Requires")
		for req in def.requires:
			var met: bool = int(research.completed.get(req,0))>=def.requires[req]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation",8)
			detail.add_child(row)
			var mark := Glyph.new()
			mark.kind = "check" if met else "lock"
			mark.color = GOOD if met else BAD
			mark.custom_minimum_size = Vector2(16,16)
			mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mark)
			var need := ForgeUi.text(row,"%s  ·  rank %d"%[ResearchCatalog.find(req).name,def.requires[req]],14,PARCH if met else FADED)
			need.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ForgeUi.rule(detail,false)
	if def.wip:
		var holder := HBoxContainer.new()
		detail.add_child(holder)
		ForgeUi.tag(holder,"In development",FADED,false)
		ForgeUi.text(detail,"No cost or timer until this branch of the village is ready.",13,FADED)
	elif research.projects.has(def.id):
		var project: Dictionary = research.projects[def.id]
		ForgeUi.caps(detail,"On the desk  ·  rank %d"%project.rank)
		ForgeUi.spacer(detail,2)
		var progress := ForgeUi.Bar.new()
		progress.color = FORGE if project.paused else GILT
		progress.custom_minimum_size.y = 12
		detail.add_child(progress)
		var remaining := ForgeUi.caps(detail,"",11,FADED,2.0)
		progress_widgets["detail:"+def.id] = [progress,remaining]
		ForgeUi.text(detail,"This rank is already paid for. Pausing keeps all progress and releases its desk.",13,FADED)
		ForgeUi.button(actions,"Resume study" if project.paused else "Pause study",func(): act(research.set_paused(def.id,not research.projects[def.id].paused),"research_pause"),false,"primary" if project.paused else "secondary")
	elif rank>=def.ranks:
		var done := HBoxContainer.new()
		done.add_theme_constant_override("separation",9)
		detail.add_child(done)
		var mark := Glyph.new()
		mark.kind = "check"
		mark.color = GOOD
		mark.custom_minimum_size = Vector2(22,22)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		done.add_child(mark)
		ForgeUi.title(done,"Fully researched",18,GOOD,1.5)
	else:
		ForgeUi.caps(detail,"Next rank  ·  %d of %d"%[rank+1,def.ranks])
		ForgeUi.spacer(detail,2)
		cost_row(int(def.gold[rank]),int(def.diamonds[rank]))
		var time_row := HBoxContainer.new()
		time_row.add_theme_constant_override("separation",8)
		detail.add_child(time_row)
		var name_label := ForgeUi.caps(time_row,"Time",11,FADED,2.0)
		name_label.custom_minimum_size.x = 88
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var watch := Glyph.new()
		watch.kind = "clock"
		watch.color = PARCH
		watch.custom_minimum_size = Vector2(16,16)
		watch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		time_row.add_child(watch)
		ForgeUi.number(time_row,"%s  ·  offline about %s"%[time_text(def.times[rank]),time_text(def.times[rank]/research.offline_rate())],14,PARCH).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ForgeUi.text(detail,"Payment is taken when this rank starts. You can pause it, but cannot cancel or refund it.",12,FADED)
		var reason: String = research.start_error(def.id)
		ForgeUi.button(actions,"Begin research",func(): act(research.start(def.id)),not reason.is_empty(),"primary")
		if not reason.is_empty():
			var why := ForgeUi.text(actions,reason,13,FORGE)
			why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func update_progress() -> void:
	for key in progress_widgets:
		var id: String = str(key).trim_prefix("detail:")
		if not game.research.projects.has(id): continue
		var project: Dictionary = game.research.projects[id]
		var duration: float = ResearchCatalog.find(id).times[int(project.rank)-1]
		progress_widgets[key][0].value = 1-project.remaining/maxf(1,duration)
		progress_widgets[key][1].text = ("Paused  ·  " if project.paused else "Remaining  ·  ")+time_text(project.remaining)
	for id in node_bars:
		if not game.research.projects.has(id): continue
		var project: Dictionary = game.research.projects[id]
		node_bars[id].value = 1-project.remaining/maxf(1,float(ResearchCatalog.find(id).times[int(project.rank)-1]))
func _process(delta: float) -> void:
	if toast_time>0:
		toast_time-=delta
		if toast_time<=0: toast_panel.hide()
	if not active: return
	clock+=delta
	if clock>.25:
		clock = 0
		update_progress()

# Prerequisite connectors, inked onto the page and gilt where they are met.
class TreeLines extends Control:
	var links: Array = []
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		# Faint ruled lines, as though the tree were drawn on prepared paper.
		for y in range(0,int(size.y)+1,32):
			draw_line(Vector2(0,y),Vector2(size.x,y),Color(1,.96,.88,.025),1.0)
		for link in links:
			var from: Vector2 = link[0]
			var to: Vector2 = link[1]
			var done: bool = link[2]
			var tint: Color = link[3]
			var mid: float = (from.y+to.y)*.5
			var color: Color = Color(ForgeUi.GILT.r,ForgeUi.GILT.g,ForgeUi.GILT.b,.85) if done else Color(1,.95,.86,.14)
			var points := PackedVector2Array([from,Vector2(from.x,mid-8),Vector2(from.x+signf(to.x-from.x)*8 if absf(to.x-from.x)>16 else from.x,mid),Vector2(to.x-signf(to.x-from.x)*8 if absf(to.x-from.x)>16 else to.x,mid),Vector2(to.x,mid+8),to])
			draw_polyline(points,Color(0,0,0,.55),5,true)
			draw_polyline(points,color,2.0,true)
			var r := 4.0
			draw_colored_polygon(PackedVector2Array([to+Vector2(0,-r),to+Vector2(r,0),to+Vector2(0,r),to+Vector2(-r,0)]),
				color if done else Color(tint.r,tint.g,tint.b,.55))

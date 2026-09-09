extends CanvasLayer
# The archive: a lamp-lit study tree with drawn connectors, study nodes,
# an appraisal panel for the chosen study and a strip of research desks.
var game: Node
var active := false
var root: Control
var graph: Control
var detail: VBoxContainer
var jobs: HBoxContainer
var balance: Label
var diamonds: Label
var summary: Label
var status: Label
var status_dot: Panel
var desk_caption: Label
var tab_buttons: Array[Button] = []
var toast_panel: PanelContainer
var toast_label: Label
var toast_time := 0.0
var selected := "conditioning"
var tree_index := 0
var progress_widgets: Dictionary = {}
var node_bars: Dictionary = {}
var clock := 0.0
const NODE_WIDTH := 238.0
const GOLD := UiKit.GOLD
const PARCH := UiKit.PARCH
const MUTED := UiKit.MUTED
const EMBER := UiKit.EMBER
const GOOD := UiKit.GOOD
const BAD := UiKit.BAD
const Glyph := UiKit.Glyph
const StatBar := UiKit.StatBar
const RankPips := UiKit.RankPips
# Glyph and colour for each research tree, in catalog order.
const TREE_LOOK := [["character",Color(.93,.58,.52)],["equipment",Color(.62,.78,.96)],["trade",Color(.87,.71,.37)],["scholarship",Color(.66,.82,.60)],["hub",Color(.62,.72,.66)]]
const STATE_COLORS := {"Completed":GOOD,"Researching":GOLD,"Paused":EMBER,"Locked":MUTED,"In development":MUTED}
# Readable names for bonuses: label, display multiplier, suffix.
const EFFECTS := {"health":["Max health",1,""],"stamina":["Max stamina",1,""],"recovery":["Stamina recovery",100,"%"],"potency":["Upgrade gains",100,"%"],"survival":["Item survival",100,"%"],"upgrade_cap":["Upgrade limit",1,""],"shop_discount":["Purchase discount",100,"%"],"forge_discount":["Forging discount",100,"%"],"slots":["Research desks",1,""],"offline":["Offline speed",100,"%"]}
func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
func tree_color(def: Dictionary) -> Color:
	return TREE_LOOK[clampi(int(def.tree),0,TREE_LOOK.size()-1)][1]
func medallion(parent: Node,def: Dictionary,size: float,dim := false) -> void:
	var tint := tree_color(def)
	var holder := UiKit.panel(parent,UiKit.flat(UiKit.tinted(tint,.06 if dim else .16),UiKit.tinted(tint,.25 if dim else .55),1,int(size*.5),Vector2(size*.18,size*.18)))
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var glyph := Glyph.new()
	glyph.kind = TREE_LOOK[clampi(int(def.tree),0,TREE_LOOK.size()-1)][0]
	glyph.color = tint
	glyph.custom_minimum_size = Vector2(size*.64,size*.64)
	if dim: glyph.modulate = Color(.55,.55,.55)
	holder.add_child(glyph)
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
	layer=21
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme=UiKit.theme()
	add_child(root)
	UiKit.backdrop(root,[Color(.09,.17,.21),Color(.04,.07,.09),Color(.02,.025,.03)],Vector2(.5,-.05))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,22)
	root.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	margin.add_child(body)
	var header := UiKit.header(body,"THE ARCHIVE","Study, unlock and improve")
	balance=UiKit.counter(header,"coin",GOLD,Color(.74,.58,.28))
	diamonds=UiKit.counter(header,"diamond",UiKit.DIAMOND,Color(.40,.62,.72))
	summary=UiKit.counter(header,"desk",PARCH,Color(.55,.62,.50))
	var leave := UiKit.button(header,"Leave  ·  Esc",close)
	leave.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",4)
	body.add_child(tabs)
	for i in ResearchCatalog.TREES.size():
		var tab := UiKit.button(tabs,ResearchCatalog.TREES[i],func(): tree_index=i; selected=""; refresh(),false,"ghost")
		tab.add_theme_font_size_override("font_size",16)
		tab_buttons.append(tab)
	var journal_tab := UiKit.button(tabs,"Journal",func(): tree_index=5; refresh(),false,"ghost")
	journal_tab.add_theme_font_size_override("font_size",16)
	tab_buttons.append(journal_tab)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",16)
	body.add_child(columns)
	var board := UiKit.panel(columns,UiKit.flat(Color(.04,.05,.055,.85),UiKit.tinted(GOLD,.22),1,10,Vector2(6,6)))
	board.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	board.add_child(scroll)
	graph=Control.new()
	graph.custom_minimum_size=Vector2(NODE_WIDTH+320,480)
	var center := CenterContainer.new()
	center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	center.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	center.add_child(graph)
	var appraisal := UiKit.panel(columns,UiKit.flat(Color(.06,.065,.07,.94),UiKit.tinted(GOLD,.45),1,10,Vector2(18,16)))
	appraisal.custom_minimum_size.x=clampf(get_viewport().get_visible_rect().size.x*.29,290,420)
	get_viewport().size_changed.connect(func(): appraisal.custom_minimum_size.x=clampf(get_viewport().get_visible_rect().size.x*.29,290,420))
	var details_scroll := ScrollContainer.new()
	details_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	appraisal.add_child(details_scroll)
	detail=VBoxContainer.new()
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",10)
	details_scroll.add_child(detail)
	var desk_row := HBoxContainer.new()
	desk_row.add_theme_constant_override("separation",12)
	body.add_child(desk_row)
	UiKit.heading(desk_row,"Research desks")
	desk_caption=UiKit.label(desk_row,"",12,MUTED)
	desk_caption.autowrap_mode=TextServer.AUTOWRAP_OFF
	var jobs_scroll := ScrollContainer.new()
	jobs_scroll.custom_minimum_size.y=112
	jobs_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(jobs_scroll)
	jobs=HBoxContainer.new()
	jobs.add_theme_constant_override("separation",10)
	jobs_scroll.add_child(jobs)
	var notice: Array = UiKit.notice(body)
	status=notice[0]
	status_dot=notice[1]
	status.text="Choose a study to inspect its branches, costs and bonuses."
	toast_panel=PanelContainer.new()
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toast_panel.offset_left=-450
	toast_panel.offset_right=-24
	toast_panel.offset_top=96
	toast_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel",UiKit.flat(Color(.08,.11,.11,.97),GOLD,1,8,Vector2(16,12)))
	add_child(toast_panel)
	var toast_row := HBoxContainer.new()
	toast_row.add_theme_constant_override("separation",12)
	toast_panel.add_child(toast_row)
	var toast_glyph := Glyph.new()
	toast_glyph.kind="scholarship"
	toast_glyph.color=GOLD
	toast_glyph.custom_minimum_size=Vector2(30,30)
	toast_glyph.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	toast_row.add_child(toast_glyph)
	toast_label=UiKit.label(toast_row,"",16,PARCH)
	toast_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
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
	var tone: Color = BAD if not result.is_empty() else GOOD
	status.add_theme_color_override("font_color",PARCH)
	status_dot.add_theme_stylebox_override("panel",UiKit.flat(tone,Color(0,0,0,0),0,5,Vector2.ZERO))
	refresh()
func study_node(def: Dictionary) -> Button:
	var research = game.research
	var rank: int=research.completed.get(def.id,0)
	var state := state_of(def)
	var tint := tree_color(def)
	var accent: Color = STATE_COLORS.get(state,tint)
	var locked: bool = state=="Locked" or state=="In development"
	var node := Button.new()
	node.position=Vector2(def.pos.x,def.pos.y*.78)
	node.size=Vector2(NODE_WIDTH,96)
	node.focus_mode=Control.FOCUS_NONE
	node.pressed.connect(func(): selected=def.id; refresh())
	var bg: Color = {"Completed":Color(.09,.13,.09,.97),"Researching":Color(.15,.13,.08,.97),"Paused":Color(.13,.10,.07,.97)}.get(state,Color(.05,.06,.065,.9) if locked else Color(.075,.085,.09,.96))
	var chosen: bool = def.id==selected
	node.add_theme_stylebox_override("normal",UiKit.flat(bg,GOLD if chosen else UiKit.tinted(accent,.2 if locked else .6),2 if chosen else 1,8,Vector2.ZERO))
	node.add_theme_stylebox_override("hover",UiKit.flat(bg.lightened(.06),GOLD if chosen else UiKit.tinted(accent,.5 if locked else .9),2 if chosen else 1,8,Vector2.ZERO))
	node.add_theme_stylebox_override("pressed",UiKit.flat(bg.lightened(.1),GOLD,2,8,Vector2.ZERO))
	node.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
	node.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	margin.add_child(row)
	medallion(row,def,56,locked)
	var text := VBoxContainer.new()
	text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",3)
	row.add_child(text)
	var name := UiKit.label(text,def.name,14,MUTED if locked else PARCH)
	name.autowrap_mode=TextServer.AUTOWRAP_OFF
	name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var state_label := UiKit.label(text,state.to_upper(),11,accent)
	state_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	var pips := RankPips.new()
	pips.maximum=maxi(1,int(def.ranks))
	pips.rank=rank
	pips.next=state=="Researching"
	pips.color=GOOD if state=="Completed" else GOLD
	pips.custom_minimum_size=Vector2(minf(72,14*def.ranks),11)
	pips.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	text.add_child(pips)
	if state=="Researching" or state=="Paused":
		var bar := StatBar.new()
		bar.color=accent
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_left=10
		bar.offset_right=-10
		bar.offset_top=-7
		bar.offset_bottom=-3
		node.add_child(bar)
		node_bars[def.id]=bar
	for child in node.get_children(): UiKit.passthrough(child)
	return node
func refresh() -> void:
	if not active: return
	var research = game.research
	balance.text="%d gold"%game.equipment.gold
	diamonds.text="%d"%game.equipment.diamonds
	summary.text="%d / %d desks"%[research.running_count(),research.slots()]
	desk_caption.text="·  Offline speed %.0f%%  ·  Paused studies keep their progress and free a desk"%(research.offline_rate()*100)
	var unread := 0
	for entry in research.journal:
		if entry.get("unread",false): unread+=1
	for i in tab_buttons.size():
		UiKit.tab_style(tab_buttons[i],i==tree_index)
		if i==5: tab_buttons[i].text="Journal" if unread==0 else "Journal  ·  %d new"%unread
	clear(graph)
	clear(detail)
	clear(jobs)
	progress_widgets.clear()
	node_bars.clear()
	if tree_index==5: show_journal()
	else:
		graph.custom_minimum_size.y=480
		var definitions: Array[Dictionary]=[]
		for def in ResearchCatalog.all():
			if def.tree==tree_index: definitions.append(def)
		if selected.is_empty() or ResearchCatalog.find(selected).get("tree",-1)!=tree_index: selected=definitions[0].id
		var lines := TreeLines.new()
		lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		graph.add_child(lines)
		for def in definitions:
			for req in def.requires:
				var previous := ResearchCatalog.find(req)
				var from: Vector2=Vector2(previous.pos.x,previous.pos.y*.78)+Vector2(NODE_WIDTH*.5,96)
				var to: Vector2=Vector2(def.pos.x,def.pos.y*.78)+Vector2(NODE_WIDTH*.5,0)
				lines.links.append([from,to,int(research.completed.get(req,0))>=int(def.requires[req]),tree_color(def)])
		for def in definitions: graph.add_child(study_node(def))
		show_detail(ResearchCatalog.find(selected))
	for id in research.projects:
		var project: Dictionary=research.projects[id]
		var def := ResearchCatalog.find(id)
		var card := UiKit.panel(jobs,UiKit.flat(Color(.07,.08,.085,.95),UiKit.tinted(EMBER if project.paused else GOLD,.5),1,8,Vector2(12,8)))
		card.custom_minimum_size.x=250
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		card.add_child(row)
		medallion(row,def,44)
		var column := VBoxContainer.new()
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation",4)
		row.add_child(column)
		var title := UiKit.label(column,"%s  ·  rank %d"%[def.name,project.rank],14,PARCH)
		title.autowrap_mode=TextServer.AUTOWRAP_OFF
		title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		var progress := StatBar.new()
		progress.color=EMBER if project.paused else GOLD
		progress.custom_minimum_size.y=9
		column.add_child(progress)
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation",8)
		column.add_child(foot)
		var remaining := UiKit.label(foot,"",12,MUTED)
		remaining.autowrap_mode=TextServer.AUTOWRAP_OFF
		remaining.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		remaining.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var toggle := UiKit.button(foot,"Resume" if project.paused else "Pause",func(): act(research.set_paused(id,not project.paused)),false,"secondary")
		toggle.custom_minimum_size.y=28
		toggle.add_theme_font_size_override("font_size",13)
		UiKit.skin(toggle,"secondary",6,Vector2(10,2))
		progress_widgets[id]=[progress,remaining]
	for i in maxi(0,research.slots()-research.running_count()):
		var empty := UiKit.panel(jobs,UiKit.flat(Color(.04,.05,.05,.7),Color(1,1,1,.10),1,8,Vector2(14,8)))
		empty.custom_minimum_size.x=210
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		empty.add_child(row)
		var glyph := Glyph.new()
		glyph.kind="desk"
		glyph.color=Color(.45,.50,.48)
		glyph.custom_minimum_size=Vector2(36,36)
		glyph.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		glyph.modulate=Color(1,1,1,.6)
		row.add_child(glyph)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation",2)
		text.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		row.add_child(text)
		UiKit.label(text,"OPEN DESK",13,Color(.50,.58,.54)).autowrap_mode=TextServer.AUTOWRAP_OFF
		UiKit.label(text,"Pick an available study to begin.",12,MUTED).autowrap_mode=TextServer.AUTOWRAP_OFF
	update_progress()
func show_journal() -> void:
	var research = game.research
	var list := VBoxContainer.new()
	list.position=Vector2(12,10)
	list.size=Vector2(NODE_WIDTH+296,580)
	list.add_theme_constant_override("separation",8)
	graph.add_child(list)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",10)
	list.add_child(head)
	var glyph := Glyph.new()
	glyph.kind="scholarship"
	glyph.color=GOLD
	glyph.custom_minimum_size=Vector2(30,30)
	head.add_child(glyph)
	UiKit.label(head,"Completed studies",24,GOLD).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if research.journal.is_empty():
		UiKit.label(list,"Your discoveries will be recorded here.",15,MUTED)
	for entry in research.journal:
		var unread: bool=entry.get("unread",false)
		var row := UiKit.panel(list,UiKit.flat(Color(.10,.10,.07,.95) if unread else Color(.06,.07,.075,.9),UiKit.tinted(GOLD,.45) if unread else Color(1,1,1,.08),1,6,Vector2(12,7)))
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation",10)
		row.add_child(inner)
		var check := Glyph.new()
		check.kind="check"
		check.color=GOLD if unread else GOOD
		check.custom_minimum_size=Vector2(18,18)
		check.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		inner.add_child(check)
		var text := UiKit.label(inner,str(entry.message),14,PARCH if unread else MUTED)
		text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		if unread: UiKit.chip(inner,"New",GOLD)
	graph.custom_minimum_size.y=maxf(480,70+research.journal.size()*48)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation",12)
	detail.add_child(head_row)
	var badge := Glyph.new()
	badge.kind="character"
	badge.color=TREE_LOOK[0][1]
	badge.custom_minimum_size=Vector2(44,44)
	head_row.add_child(badge)
	UiKit.label(head_row,"Current bonuses",22,GOLD).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	UiKit.label(detail,"Every finished rank is already in effect. Character values wait for the combat system.",13,MUTED)
	UiKit.divider(detail)
	var stats: Dictionary=research.player_stats()
	UiKit.heading(detail,"Character")
	bonus_row("Maximum health","%.0f"%stats.health,stats.health>100)
	bonus_row("Maximum stamina","%.0f"%stats.stamina,stats.stamina>100)
	bonus_row("Stamina recovery","+%.0f%%"%((stats.stamina_recovery_multiplier-1)*100),stats.stamina_recovery_multiplier>1)
	UiKit.heading(detail,"Forge and trade")
	bonus_row("Purchase discount","%.0f%%"%(research.bonus("shop_discount")*100),research.bonus("shop_discount")>0)
	bonus_row("Forging discount","%.0f%%"%(research.bonus("forge_discount")*100),research.bonus("forge_discount")>0)
	bonus_row("New upgrade gains","%.1f%% of base"%(game.equipment.next_gain()*100),research.bonus("potency")>0)
	bonus_row("Item survival","+%.0f points"%(research.bonus("survival")*100),research.bonus("survival")>0)
	bonus_row("Upgrade limit","+%d"%game.equipment.max_upgrade(),research.bonus("upgrade_cap")>0)
	UiKit.heading(detail,"Archive")
	bonus_row("Research desks","%d"%research.slots(),research.slots()>2)
	bonus_row("Offline speed","%.0f%%"%(research.offline_rate()*100),research.bonus("offline")>0)
	UiKit.divider(detail)
	var unread := 0
	for entry in research.journal:
		if entry.get("unread",false): unread+=1
	UiKit.button(detail,"Mark all as read",research.acknowledge,unread==0,"secondary")
func bonus_row(name: String,value: String,improved: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	detail.add_child(row)
	var label := UiKit.label(row,name,13,MUTED)
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.autowrap_mode=TextServer.AUTOWRAP_OFF
	var amount := UiKit.label(row,value,15,GOOD if improved else PARCH)
	amount.autowrap_mode=TextServer.AUTOWRAP_OFF
	amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
func cost_row(gold: int,diamond_cost: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	detail.add_child(row)
	var name := UiKit.label(row,"Cost",13,MUTED)
	name.custom_minimum_size.x=84
	name.autowrap_mode=TextServer.AUTOWRAP_OFF
	var coin := Glyph.new()
	coin.kind="coin"
	coin.custom_minimum_size=Vector2(16,16)
	coin.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	UiKit.label(row,"%d"%gold,16,GOLD if game.equipment.gold>=gold else BAD).autowrap_mode=TextServer.AUTOWRAP_OFF
	if diamond_cost>0:
		UiKit.spacer(row,0)
		var gem := Glyph.new()
		gem.kind="diamond"
		gem.custom_minimum_size=Vector2(16,16)
		gem.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		row.add_child(gem)
		UiKit.label(row,"%d"%diamond_cost,16,UiKit.DIAMOND if game.equipment.diamonds>=diamond_cost else BAD).autowrap_mode=TextServer.AUTOWRAP_OFF
func show_detail(def: Dictionary) -> void:
	var research = game.research
	var rank: int=research.completed.get(def.id,0)
	var state := state_of(def)
	var tint := tree_color(def)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",14)
	detail.add_child(head)
	medallion(head,def,72)
	var text := VBoxContainer.new()
	text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",6)
	head.add_child(text)
	var name := UiKit.label(text,def.name,23,tint)
	name.add_theme_color_override("font_shadow_color",Color(0,0,0,.6))
	name.add_theme_constant_override("shadow_offset_y",2)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation",6)
	text.add_child(chips)
	UiKit.chip(chips,ResearchCatalog.TREES[def.tree].get_slice(" ",0),tint)
	UiKit.chip(chips,state,STATE_COLORS.get(state,tint))
	UiKit.chip(chips,"Rank %d / %d"%[rank,def.ranks],MUTED)
	UiKit.label(detail,def.description,14,MUTED)
	UiKit.divider(detail)
	if not def.effects.is_empty():
		UiKit.heading(detail,"Bonus per rank")
		for key in def.effects:
			var spec: Array = EFFECTS.get(key,[key.capitalize(),1,""])
			var per: float = float(def.effects[key])*spec[1]
			var now: String = fmt(per*rank)+spec[2]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation",10)
			detail.add_child(row)
			var label := UiKit.label(row,spec[0],13,MUTED)
			label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			label.autowrap_mode=TextServer.AUTOWRAP_OFF
			var amount := UiKit.label(row,"+"+now+("  →  +"+fmt(per*(rank+1))+spec[2] if rank<def.ranks else ""),15,GOOD if rank>0 else PARCH)
			amount.autowrap_mode=TextServer.AUTOWRAP_OFF
	if not def.requires.is_empty():
		UiKit.heading(detail,"Requires")
		for req in def.requires:
			var met: bool = int(research.completed.get(req,0))>=def.requires[req]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation",8)
			detail.add_child(row)
			var mark := Glyph.new()
			mark.kind="check" if met else "lock"
			mark.color=GOOD if met else BAD
			mark.custom_minimum_size=Vector2(16,16)
			mark.size_flags_vertical=Control.SIZE_SHRINK_CENTER
			row.add_child(mark)
			var need := UiKit.label(row,"%s  ·  rank %d"%[ResearchCatalog.find(req).name,def.requires[req]],14,PARCH if met else MUTED)
			need.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	UiKit.divider(detail)
	if def.wip:
		UiKit.chip(detail,"In development",MUTED)
		UiKit.label(detail,"No cost or timer until this branch of the village is ready.",13,MUTED)
	elif research.projects.has(def.id):
		var project: Dictionary=research.projects[def.id]
		UiKit.heading(detail,"On the desk  ·  rank %d"%project.rank)
		var progress := StatBar.new()
		progress.color=EMBER if project.paused else GOLD
		progress.custom_minimum_size.y=12
		detail.add_child(progress)
		var remaining := UiKit.label(detail,"",13,MUTED)
		progress_widgets["detail:"+def.id]=[progress,remaining]
		UiKit.label(detail,"This rank is already paid for. Pausing keeps all progress and releases its desk.",13,MUTED)
		UiKit.button(detail,"Resume study" if project.paused else "Pause study",func(): act(research.set_paused(def.id,not research.projects[def.id].paused)),false,"primary" if project.paused else "secondary")
	elif rank>=def.ranks:
		var done := HBoxContainer.new()
		done.add_theme_constant_override("separation",8)
		detail.add_child(done)
		var mark := Glyph.new()
		mark.kind="check"
		mark.color=GOOD
		mark.custom_minimum_size=Vector2(22,22)
		done.add_child(mark)
		UiKit.label(done,"Fully researched",18,GOOD)
	else:
		UiKit.heading(detail,"Next rank  ·  %d of %d"%[rank+1,def.ranks])
		cost_row(int(def.gold[rank]),int(def.diamonds[rank]))
		var time_row := HBoxContainer.new()
		time_row.add_theme_constant_override("separation",8)
		detail.add_child(time_row)
		var name_label := UiKit.label(time_row,"Time",13,MUTED)
		name_label.custom_minimum_size.x=84
		name_label.autowrap_mode=TextServer.AUTOWRAP_OFF
		var watch := Glyph.new()
		watch.kind="clock"
		watch.color=PARCH
		watch.custom_minimum_size=Vector2(16,16)
		watch.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		time_row.add_child(watch)
		UiKit.label(time_row,"%s  ·  offline about %s"%[time_text(def.times[rank]),time_text(def.times[rank]/research.offline_rate())],14,PARCH).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var reason: String=research.start_error(def.id)
		UiKit.button(detail,"Begin research",func(): act(research.start(def.id)),not reason.is_empty(),"primary")
		if not reason.is_empty():
			var why := UiKit.label(detail,reason,13,EMBER)
			why.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		UiKit.label(detail,"Payment is taken when this rank starts. You can pause it, but cannot cancel or refund it.",12,MUTED)
func update_progress() -> void:
	for key in progress_widgets:
		var id: String=str(key).trim_prefix("detail:")
		if not game.research.projects.has(id): continue
		var project: Dictionary=game.research.projects[id]
		var duration: float=ResearchCatalog.find(id).times[int(project.rank)-1]
		progress_widgets[key][0].value=1-project.remaining/maxf(1,duration)
		progress_widgets[key][0].queue_redraw()
		progress_widgets[key][1].text=("Paused  ·  " if project.paused else "Remaining  ·  ")+time_text(project.remaining)
	for id in node_bars:
		if not game.research.projects.has(id): continue
		var project: Dictionary=game.research.projects[id]
		node_bars[id].value=1-project.remaining/maxf(1,float(ResearchCatalog.find(id).times[int(project.rank)-1]))
		node_bars[id].queue_redraw()
func _process(delta: float) -> void:
	if toast_time>0:
		toast_time-=delta
		if toast_time<=0: toast_panel.hide()
	if not active: return
	clock+=delta
	if clock>.25:
		clock=0
		update_progress()
# Prerequisite connectors and a faint drafting grid beneath the study nodes.
class TreeLines extends Control:
	var links: Array = []
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		for x in range(0,int(size.x)+1,24):
			for y in range(0,int(size.y)+1,24): draw_circle(Vector2(x,y),1,Color(1,1,1,.05))
		for link in links:
			var from: Vector2=link[0]
			var to: Vector2=link[1]
			var done: bool=link[2]
			var tint: Color=link[3]
			var mid: float=(from.y+to.y)*.5
			var color: Color = UiKit.tinted(UiKit.GOOD,.9) if done else Color(1,1,1,.16)
			var points := PackedVector2Array([from,Vector2(from.x,mid-8),Vector2(from.x+signf(to.x-from.x)*8 if absf(to.x-from.x)>16 else from.x,mid),Vector2(to.x-signf(to.x-from.x)*8 if absf(to.x-from.x)>16 else to.x,mid),Vector2(to.x,mid+8),to])
			draw_polyline(points,Color(0,0,0,.5),6,true)
			draw_polyline(points,color,2.5,true)
			draw_circle(to,4.5,Color(.03,.03,.04))
			draw_circle(to,3,color if done else UiKit.tinted(tint,.5))

class_name ForgeUi
extends RefCounted
# The armory's look: an illuminated page rather than a dark panel stack.
# Hard chamfered plates, gilt hairlines, a display serif for anything that
# names a thing, and the sans reserved for numbers you have to read fast.
# Only the blacksmith uses this; UiKit still dresses the other screens.

const INK := Color(.052,.046,.041)          # the page, in shadow
const VELLUM := Color(.90,.85,.74)          # lit text
const PARCH := Color(.74,.69,.59)           # body text
const FADED := Color(.55,.51,.44)           # captions
const GILT := Color(.85,.68,.34)            # gold leaf
const GILT_DIM := Color(.55,.43,.21)        # the same leaf, unlit
const FORGE := Color(.95,.55,.24)           # ember
const BLOOD := Color(.76,.29,.24)           # loss
const VERDIGRIS := Color(.52,.76,.55)       # gain
const STEEL := Color(.72,.78,.84)
const SAPPHIRE := Color(.56,.82,.96)     # cut gems, and anything cold

const RARITY := {
	"warden":["Common",Color(.80,.79,.74)],
	"pilgrim":["Fine",Color(.60,.83,.55)],
	"citadel":["Rare",Color(.52,.72,.98)]}

# ---------------------------------------------------------------- type

static var _display: Font
static func display() -> Font:
	if _display == null: _display = load("res://assets/ui/display.ttf")
	return _display
static var _display_bold: Font
static func display_bold() -> Font:
	if _display_bold == null: _display_bold = load("res://assets/ui/display_bold.ttf")
	return _display_bold
static var _tracked := {}
## Cinzel with real letterspacing; a display serif set tight reads as a webpage.
static func tracked(spacing: float,bold := false) -> FontVariation:
	var key := "%s_%.2f"%["b" if bold else "r",spacing]
	if not _tracked.has(key):
		var font := FontVariation.new()
		font.base_font = display_bold() if bold else display()
		font.spacing_glyph = int(round(spacing))
		_tracked[key] = font
	return _tracked[key]

static func text(parent: Node,body: String,size: int,color: Color) -> Label:
	var node := Label.new()
	node.text = body
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node
## A name: display serif, lightly tracked, carrying its own shadow.
static func title(parent: Node,body: String,size: int,color := GILT,spacing := 2.0) -> Label:
	var node := text(parent,body,size,color)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.add_theme_font_override("font",tracked(spacing,true))
	node.add_theme_color_override("font_shadow_color",Color(0,0,0,.75))
	node.add_theme_constant_override("shadow_offset_x",1)
	node.add_theme_constant_override("shadow_offset_y",2)
	return node
## A section rubric: small, wide, unmissable as a label and never as content.
static func caps(parent: Node,body: String,size := 12,color := GILT_DIM,spacing := 4.0) -> Label:
	var node := text(parent,body.to_upper(),size,color)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.add_theme_font_override("font",tracked(spacing,false))
	return node
static func number(parent: Node,body: String,size: int,color: Color) -> Label:
	var node := text(parent,body,size,color)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	return node

# ---------------------------------------------------------------- plates

## A cut-cornered metal plate: vertical gradient, gilt hairline, optional
## second rule inside it, a light catching the top edge and a cast shadow.
class Plate extends StyleBox:
	var top := Color(.115,.102,.090,.93)
	var bottom := Color(.052,.047,.042,.96)
	var edge := Color(.55,.43,.21,.55)
	var inner := Color(0,0,0,0)
	var sheen := Color(0,0,0,0)
	var cut := 10.0
	var drop := 0.0
	var thickness := 1.0
	func chamfer(rect: Rect2,shrink := 0.0) -> PackedVector2Array:
		var r := rect.grow(-shrink)
		var c: float = minf(cut,minf(r.size.x,r.size.y)*.5)
		var p := r.position
		var s := r.size
		return PackedVector2Array([
			p+Vector2(c,0),p+Vector2(s.x-c,0),p+Vector2(s.x,c),p+Vector2(s.x,s.y-c),
			p+Vector2(s.x-c,s.y),p+Vector2(c,s.y),p+Vector2(0,s.y-c),p+Vector2(0,c)])
	func flat_colors(count: int,color: Color) -> PackedColorArray:
		var out := PackedColorArray()
		for i in count: out.append(color)
		return out
	func outline(item: RID,points: PackedVector2Array,color: Color,width: float) -> void:
		var loop := points.duplicate()
		loop.append(points[0])
		RenderingServer.canvas_item_add_polyline(item,loop,flat_colors(loop.size(),color),width,true)
	func _draw(item: RID,rect: Rect2) -> void:
		if rect.size.x<=2 or rect.size.y<=2: return
		if drop>0.0:
			var cast := chamfer(Rect2(rect.position+Vector2(0,drop),rect.size))
			RenderingServer.canvas_item_add_polygon(item,cast,flat_colors(cast.size(),Color(0,0,0,.34)))
		var face := chamfer(rect)
		var shades := PackedColorArray()
		for point in face:
			shades.append(top.lerp(bottom,clampf((point.y-rect.position.y)/maxf(rect.size.y,1.0),0.0,1.0)))
		RenderingServer.canvas_item_add_polygon(item,face,shades)
		if sheen.a>0.0:
			var height: float = minf(rect.size.y*.5,54.0)
			var lit := PackedVector2Array([
				rect.position+Vector2(cut,1),rect.position+Vector2(rect.size.x-cut,1),
				rect.position+Vector2(rect.size.x-cut,height),rect.position+Vector2(cut,height)])
			RenderingServer.canvas_item_add_polygon(item,lit,PackedColorArray([sheen,sheen,Color(sheen,0),Color(sheen,0)]))
		if inner.a>0.0: outline(item,chamfer(rect,4.0),inner,1.0)
		if edge.a>0.0: outline(item,face,edge,thickness)

static func plate_box(top: Color,bottom: Color,edge: Color,pad: Vector2,cut := 10.0) -> Plate:
	var box := Plate.new()
	box.top = top
	box.bottom = bottom
	box.edge = edge
	box.cut = cut
	box.content_margin_left = pad.x
	box.content_margin_right = pad.x
	box.content_margin_top = pad.y
	box.content_margin_bottom = pad.y
	return box
## The one heavy plate on the screen: everything else defers to it.
static func appraisal_box(pad: Vector2) -> Plate:
	var box := plate_box(Color(.115,.100,.085,.95),Color(.045,.041,.038,.97),Color(GILT.r,GILT.g,GILT.b,.42),pad,14.0)
	box.inner = Color(GILT.r,GILT.g,GILT.b,.13)
	box.sheen = Color(1,.86,.62,.055)
	box.drop = 3.0
	return box
static func panel(parent: Node,box: StyleBox) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel",box)
	parent.add_child(node)
	return node

# ---------------------------------------------------------------- marks

## A hairline rule with a struck diamond at its centre; ends fade to nothing.
class Rule extends Control:
	var color := Color(GILT.r,GILT.g,GILT.b,.45)
	var pip := true
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 9
		resized.connect(queue_redraw)
	func _draw() -> void:
		var y: float = size.y*.5
		var mid: float = size.x*.5
		var gap: float = 9.0 if pip else 0.0
		for side in [-1.0,1.0]:
			var steps := 24
			for i in steps:
				var a: float = mid+side*(gap+(size.x*.5-gap)*float(i)/steps)
				var b: float = mid+side*(gap+(size.x*.5-gap)*float(i+1)/steps)
				var fade: float = 1.0-pow(float(i)/steps,2.2)
				draw_line(Vector2(a,y),Vector2(b,y),Color(color,color.a*fade),1.0)
		if pip:
			var r := 3.5
			draw_colored_polygon(PackedVector2Array([
				Vector2(mid,y-r),Vector2(mid+r,y),Vector2(mid,y+r),Vector2(mid-r,y)]),color)

## Illuminated corners: the frame a manuscript puts round a miniature.
class Corners extends Control:
	var color := Color(GILT.r,GILT.g,GILT.b,.75)
	var arm := 20.0
	var inset := 2.0
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		for corner in [[Vector2(inset,inset),Vector2(1,1)],[Vector2(size.x-inset,inset),Vector2(-1,1)],
				[Vector2(inset,size.y-inset),Vector2(1,-1)],[Vector2(size.x-inset,size.y-inset),Vector2(-1,-1)]]:
			var o: Vector2 = corner[0]
			var d: Vector2 = corner[1]
			draw_line(o,o+Vector2(d.x*arm,0),color,1.5)
			draw_line(o,o+Vector2(0,d.y*arm),color,1.5)
			var p: Vector2 = o+d*5.0
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-2.6),p+Vector2(2.6,0),p+Vector2(0,2.6),p+Vector2(-2.6,0)]),color)

## A measure struck into the page: ink channel, filled bar, hammered baseline.
class Bar extends Control:
	var value := 0.0
	var maximum := 1.0
	var baseline := -1.0
	var color := GILT
	var shown := -1.0
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		set_process(true)
	func _process(delta: float) -> void:
		var target: float = clampf(value/maxf(maximum,.0001),0.0,1.0)
		if shown<0.0: shown = 0.0
		if absf(shown-target)<.0015:
			if shown!=target:
				shown = target
				queue_redraw()
			return
		shown = lerpf(shown,target,clampf(delta*8.0,0.0,1.0))
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,.52))
		draw_line(Vector2(0,.5),Vector2(size.x,.5),Color(0,0,0,.5),1.0)
		draw_line(Vector2(0,size.y-.5),Vector2(size.x,size.y-.5),Color(1,.93,.80,.07),1.0)
		var width: float = size.x*maxf(shown,0.0)
		if width>1.0:
			draw_rect(Rect2(0,0,width,size.y),color.darkened(.34))
			draw_rect(Rect2(0,0,width,size.y*.42),color)
			draw_line(Vector2(width-.5,0),Vector2(width-.5,size.y),color.lightened(.35),1.0)
		for i in range(1,4):
			var x: float = size.x*i/4.0
			draw_line(Vector2(x,1),Vector2(x,size.y-1),Color(0,0,0,.45),1.0)
		if baseline>=0.0:
			var x: float = clampf(baseline/maxf(maximum,.0001),0.0,1.0)*size.x
			draw_line(Vector2(x,-3),Vector2(x,size.y+3),Color(.95,.91,.82,.9),2.0)

## Temper marks: a filled lozenge for every rank the forge has already taken.
class Pips extends Control:
	var maximum := 5
	var rank := 0
	var next := false
	var color := GILT
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var step: float = size.x/maxf(maximum,1)
		var r: float = minf(size.y*.5,step*.34)
		for i in maximum:
			var c := Vector2(step*(i+.5),size.y*.5)
			var mark := PackedVector2Array([c+Vector2(0,-r),c+Vector2(r*.72,0),c+Vector2(0,r),c+Vector2(-r*.72,0)])
			if i<rank: draw_colored_polygon(mark,color)
			elif next and i==rank: draw_colored_polygon(mark,Color(color,.16))
			var loop := mark.duplicate()
			loop.append(mark[0])
			var line: Color = color.lightened(.2) if i<rank else (Color(color,.55) if next and i==rank else Color(1,.94,.84,.18))
			draw_polyline(loop,line,1.2,true)

## The page itself, drawn once behind everything. The two lights are the
## room: a forge low and right, a window high and left, or whatever a
## given screen keeps for company.
static func page(root: Control,warm := Color(.26,.11,.03),warm_at := Vector2(1.02,1.06),
		cold := Color(.05,.065,.095),cold_at := Vector2(.04,-.05)) -> ColorRect:
	var sheet := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/ui/forge_page.gdshader")
	material.set_shader_parameter("forge_color",warm)
	material.set_shader_parameter("forge_at",warm_at)
	material.set_shader_parameter("window_color",cold)
	material.set_shader_parameter("window_at",cold_at)
	sheet.material = material
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sheet)
	return sheet

## A screen's name, its rubric, and room on the right for counters and the
## way out. Follow it with a rule.
static func header(parent: Node,name: String,rubric: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	parent.add_child(row)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",2)
	row.add_child(box)
	title(box,name,34,GILT,3.0)
	caps(box,rubric,11,FADED,5.0)
	return row

## A tally in a tinted plate: an optional drawn mark, an optional rubric,
## and the figure the caller keeps writing into.
static func counter(parent: Node,mark: Control,color: Color,rubric := "") -> Label:
	var holder := panel(parent,plate_box(Color(color.r,color.g,color.b,.17),
		Color(color.r,color.g,color.b,.07),Color(color.r,color.g,color.b,.55),Vector2(14,7),7.0))
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	holder.add_child(row)
	if mark != null:
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
	if not rubric.is_empty():
		caps(row,rubric,11,FADED,3.0).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return number(row,"",19,color.lightened(.25))

## Tabs with a gilt marker that slides to whichever one is open.
class TabStrip extends Control:
	var row: HBoxContainer
	var marker: ColorRect
	var buttons: Array[Button] = []
	func _init() -> void:
		custom_minimum_size.y = 44
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row = HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_theme_constant_override("separation",6)
		add_child(row)
		marker = ColorRect.new()
		marker.color = ForgeUi.GILT
		marker.size = Vector2(0,2)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(marker)
	func add(label: String,callback: Callable,size := 15) -> Button:
		var button := Button.new()
		button.text = label
		button.add_theme_font_override("font",ForgeUi.tracked(2.0,false))
		button.add_theme_font_size_override("font_size",size)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(callback)
		ForgeUi.sound(button)
		for state in ["normal","hover","pressed","focus"]:
			var lit: bool = state=="hover"
			button.add_theme_stylebox_override(state,ForgeUi.plate_box(
				Color(1,.92,.80,.05 if lit else 0),Color(1,.92,.80,.02 if lit else 0),
				Color(0,0,0,0),Vector2(13,9),6.0))
		row.add_child(button)
		buttons.append(button)
		return button
	func mark(index: int) -> void:
		for i in buttons.size():
			var on: bool = i==index
			buttons[i].add_theme_color_override("font_color",ForgeUi.GILT if on else ForgeUi.FADED)
			buttons[i].add_theme_color_override("font_hover_color",ForgeUi.GILT if on else ForgeUi.VELLUM)
			buttons[i].add_theme_color_override("font_pressed_color",ForgeUi.GILT)
		custom_minimum_size.x = row.get_combined_minimum_size().x
		var current: Button = buttons[clampi(index,0,buttons.size()-1)]
		if current.size.x<=0.0: return
		var target := Rect2(current.position.x+10,current.size.y-4,current.size.x-20,2)
		if marker.size.x<=0.0:
			marker.position = target.position
			marker.size = target.size
			return
		var slide := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		slide.tween_property(marker,"position",target.position,.18)
		slide.tween_property(marker,"size",target.size,.18)

# ---------------------------------------------------------------- controls

static var audio_kit: Node
static func sound(node: BaseButton,kind := "click") -> void:
	if not node.is_inside_tree():
		node.tree_entered.connect(func(): sound(node,kind),CONNECT_ONE_SHOT)
		return
	if not is_instance_valid(audio_kit): audio_kit = node.get_tree().root.find_child("AudioKit",true,false)
	var audio := audio_kit
	if audio == null: return
	node.pressed.connect(func(): audio.ui("ui_back" if kind=="back" else ("ui_confirm" if kind=="confirm" else "ui_click")))
	node.mouse_entered.connect(func(): if not node.disabled: audio.ui("ui_hover",-22))

const BUTTONS := {
	# top, bottom, edge, font
	"primary":[Color(.62,.47,.17),Color(.40,.29,.09),Color(.98,.85,.52,.75),Color(.10,.07,.02)],
	"secondary":[Color(.15,.14,.12),Color(.085,.078,.07),Color(.72,.58,.30,.45),VELLUM],
	"danger":[Color(.44,.16,.11),Color(.26,.09,.06),Color(.96,.52,.34,.6),Color(1,.92,.86)],
	"ghost":[Color(1,1,1,.02),Color(1,1,1,.01),Color(.72,.58,.30,.0),PARCH]}
static func skin(button: Button,kind: String,pad := Vector2(20,10),cut := 9.0) -> void:
	var spec: Array = BUTTONS[kind]
	for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		var lift: float = {"hover":.09,"hover_pressed":-.06,"pressed":-.06}.get(state,0.0)
		var box := plate_box(spec[0].lightened(maxf(lift,0)) if lift>=0 else spec[0].darkened(-lift),
			spec[1].lightened(maxf(lift,0)) if lift>=0 else spec[1].darkened(-lift),
			Color(spec[2],spec[2].a*(1.35 if lift>0 else 1.0)),pad,cut)
		if kind=="primary":
			box.sheen = Color(1,.94,.72,.18 if lift>0 else .10)
			box.drop = 2.0
		if kind=="ghost" and lift>0: box.edge = Color(GILT.r,GILT.g,GILT.b,.35)
		if state=="disabled":
			box = plate_box(Color(.10,.098,.094,.9),Color(.07,.068,.065,.9),Color(1,1,1,.07),pad,cut)
		button.add_theme_stylebox_override(state,box)
	button.add_theme_color_override("font_color",spec[3])
	for name in ["font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		button.add_theme_color_override(name,spec[3].lightened(.12))
	button.add_theme_color_override("font_disabled_color",Color(.45,.42,.38))
	button.add_theme_color_override("font_outline_color",Color(0,0,0,.7))
	button.add_theme_constant_override("outline_size",0)
	button.focus_mode = Control.FOCUS_NONE

static func button(parent: Node,label: String,callback: Callable,disabled := false,kind := "secondary",size := 16) -> Button:
	var node := Button.new()
	node.text = label.to_upper() if kind=="primary" or kind=="danger" else label
	node.custom_minimum_size.y = 48 if kind=="primary" or kind=="danger" else 40
	node.disabled = disabled
	node.pressed.connect(callback)
	node.add_theme_font_override("font",tracked(3.0 if kind=="primary" or kind=="danger" else 1.0,kind=="primary" or kind=="danger"))
	node.add_theme_font_size_override("font_size",size)
	skin(node,kind)
	sound(node,"confirm" if kind=="primary" or kind=="danger" else "click")
	parent.add_child(node)
	return node

## A tag: cut corners, tinted ground, the word set small and wide.
static func tag(parent: Node,label: String,color: Color,strong := false) -> PanelContainer:
	var box := plate_box(Color(color.r,color.g,color.b,.20 if strong else .11),
		Color(color.r,color.g,color.b,.10 if strong else .05),
		Color(color.r,color.g,color.b,.75 if strong else .40),Vector2(9,3),5.0)
	var holder := panel(parent,box)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var node := caps(holder,label,11,color,3.0)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return holder

## Scrollbars: an ink channel with a gilt thumb, not the engine default.
static func style_scroll(scroll: ScrollContainer) -> void:
	scroll.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var bar := scroll.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll",plate_box(Color(0,0,0,.35),Color(0,0,0,.35),Color(1,.94,.84,.05),Vector2(3,0),0.0))
	for state in ["grabber","grabber_highlight","grabber_pressed"]:
		var lit: bool = state!="grabber"
		bar.add_theme_stylebox_override(state,plate_box(
			Color(GILT.r,GILT.g,GILT.b,.55 if lit else .30),
			Color(GILT.r,GILT.g,GILT.b,.35 if lit else .18),
			Color(GILT.r,GILT.g,GILT.b,.5 if lit else .22),Vector2(3,0),3.0))
	bar.custom_minimum_size.x = 9

static func rule(parent: Node,pip := true,color := Color(GILT.r,GILT.g,GILT.b,.42)) -> Rule:
	var node := Rule.new()
	node.pip = pip
	node.color = color
	parent.add_child(node)
	return node
static func spacer(parent: Node,height: float) -> void:
	var node := Control.new()
	node.custom_minimum_size.y = height
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
static func passthrough(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): passthrough(child)

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 16
	result.set_color("font_color","Label",PARCH)
	# The dialog's fill comes from the window frame, so its client panel only
	# holds the margins; Godot needs a StyleBoxFlat here to expand over the
	# title bar, which is the one place a chamfer has to give way.
	var body := StyleBoxFlat.new()
	body.bg_color = Color(0,0,0,0)
	body.set_corner_radius_all(0)
	body.content_margin_left = 24
	body.content_margin_right = 24
	body.content_margin_top = 18
	body.content_margin_bottom = 18
	result.set_stylebox("panel","AcceptDialog",body)
	var window := StyleBoxFlat.new()
	window.bg_color = Color(.085,.078,.070,.99)
	window.border_color = Color(GILT.r,GILT.g,GILT.b,.55)
	window.set_border_width_all(1)
	window.set_corner_radius_all(0)
	window.expand_margin_top = 40
	window.shadow_color = Color(0,0,0,.55)
	window.shadow_size = 10
	result.set_stylebox("embedded_border","Window",window)
	result.set_stylebox("embedded_unfocused_border","Window",window)
	result.set_color("title_color","Window",GILT)
	result.set_font("title_font","Window",tracked(3.0,true))
	result.set_font_size("title_font_size","Window",16)
	result.set_constant("title_height","Window",40)
	return result

class_name UiKit
extends RefCounted
# Shared look for the village storefront screens: colours, button skins,
# small layout helpers and the drawn glyphs, all generated at runtime.
const GOLD := Color(.87,.71,.37)
const PARCH := Color(.91,.87,.75)
const MUTED := Color(.63,.65,.59)
const EMBER := Color(.94,.60,.36)
const GOOD := Color(.56,.83,.48)
const BAD := Color(.91,.44,.37)
const DIAMOND := Color(.58,.86,.96)
# Button skins: normal, hover, pressed, border, font.
const SKINS := {
	"primary":[Color(.74,.55,.20),Color(.85,.66,.27),Color(.60,.44,.15),Color(.97,.83,.50,.55),Color(.13,.08,.02)],
	"secondary":[Color(.10,.15,.13),Color(.16,.23,.19),Color(.08,.12,.10),Color(.72,.60,.32,.55),Color(.91,.87,.75)],
	"danger":[Color(.53,.19,.11),Color(.65,.26,.14),Color(.42,.15,.09),Color(.96,.56,.36,.6),Color(1,.93,.86)],
	"ghost":[Color(0,0,0,0),Color(1,1,1,.06),Color(1,1,1,.03),Color(0,0,0,0),Color(.63,.65,.59)]}
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
static func tinted(color: Color,alpha: float) -> Color:
	return Color(color.r,color.g,color.b,alpha)
static func skin(button: Button,kind: String,radius := 6,pad := Vector2(18,8)) -> void:
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
static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 16
	result.set_color("font_color","Label",PARCH)
	result.set_stylebox("panel","AcceptDialog",flat(Color(.07,.075,.07),tinted(GOLD,.6),1,8,Vector2(18,14)))
	var window := flat(Color(.10,.095,.08),tinted(GOLD,.6),1,8,Vector2.ZERO)
	window.expand_margin_top = 34
	result.set_stylebox("embedded_border","Window",window)
	result.set_stylebox("embedded_unfocused_border","Window",window)
	result.set_color("title_color","Window",GOLD)
	result.set_font_size("title_font_size","Window",17)
	var spec: Array = SKINS.secondary
	for state in ["normal","hover","pressed","focus"]:
		result.set_stylebox(state,"Button",flat(spec[1] if state!="normal" else spec[0],spec[3],1,6,Vector2(18,8)))
	result.set_color("font_color","Button",spec[4])
	return result
static func label(parent: Node,text: String,size := 16,color := PARCH) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node
static func button(parent: Node,title: String,callback: Callable,disabled := false,kind := "secondary") -> Button:
	var node := Button.new()
	node.text = title
	node.custom_minimum_size.y = 46 if kind!="ghost" else 40
	node.disabled = disabled
	node.pressed.connect(callback)
	node.add_theme_font_size_override("font_size",17 if kind=="primary" or kind=="danger" else 15)
	skin(node,kind)
	parent.add_child(node)
	return node
static func panel(parent: Node,style: StyleBox) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel",style)
	parent.add_child(node)
	return node
static func chip(parent: Node,text: String,color: Color) -> Label:
	var holder := panel(parent,flat(tinted(color,.14),tinted(color,.45),1,10,Vector2(9,2)))
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var node := label(holder,text,12,color)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.uppercase = true
	return node
static func divider(parent: Node) -> void:
	var line := ColorRect.new()
	line.color = tinted(GOLD,.28)
	line.custom_minimum_size.y = 1
	parent.add_child(line)
static func spacer(parent: Node,height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)
static func heading(parent: Node,text: String) -> void:
	var node := label(parent,text,12,GOLD)
	node.uppercase = true
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
static func passthrough(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): passthrough(child)
static func gradient_rect(parent: Node,colors: Array,radial: bool,from: Vector2,to: Vector2) -> TextureRect:
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
# A dark room lit from one direction, with a vignette closing in the edges.
static func backdrop(root: Control,glow: Array,from: Vector2) -> void:
	var shade := ColorRect.new()
	shade.color = Color(.022,.024,.024)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	gradient_rect(root,glow,true,from,Vector2(.5,.15) if from.y>.5 else Vector2(.5,.85))
	gradient_rect(root,[Color(0,0,0,0),Color(0,0,0,.62)],true,Vector2(.5,.5),Vector2(.5,1.05))
# The screen header: title, subtitle and a row of chips ending in the exit.
static func header(parent: Node,title: String,subtitle: String) -> HBoxContainer:
	var style := flat(Color(.045,.05,.045,.9),Color(.72,.58,.30,.55),0,8,Vector2(22,10))
	style.border_width_bottom = 2
	var bar := panel(parent,style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	bar.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",0)
	row.add_child(text)
	label(text,title,30,GOLD).autowrap_mode = TextServer.AUTOWRAP_OFF
	label(text,subtitle,13,MUTED).autowrap_mode = TextServer.AUTOWRAP_OFF
	return row
# A rounded pill holding a glyph and a value, for purses and counters.
static func counter(parent: Node,glyph: String,color: Color,border: Color) -> Label:
	var pill := panel(parent,flat(tinted(border,.16),tinted(border,.6),1,16,Vector2(14,6)))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	pill.add_child(row)
	if not glyph.is_empty():
		var icon := Glyph.new()
		icon.kind = glyph
		icon.custom_minimum_size = Vector2(20,20)
		row.add_child(icon)
	var value := label(row,"",18,color)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	return value
# The strip along the bottom where the keeper's last word is shown.
static func notice(parent: Node) -> Array:
	var strip := panel(parent,flat(Color(.07,.07,.065,.92),tinted(GOLD,.3),1,8,Vector2(16,8)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	strip.add_child(row)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(9,9)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel",flat(GOLD,Color(0,0,0,0),0,5,Vector2.ZERO))
	row.add_child(dot)
	var text := label(row,"",14,MUTED)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return [text,dot]
static func tab_style(button: Button,on: bool) -> void:
	var box := flat(Color(.16,.15,.10,.95) if on else Color(0,0,0,0),GOLD if on else Color(0,0,0,0),0,6,Vector2(18,8))
	box.border_width_bottom = 3 if on else 0
	button.add_theme_stylebox_override("normal",box)
	var hover := flat(Color(.16,.15,.10,.95) if on else Color(1,1,1,.06),GOLD if on else Color(0,0,0,0),0,6,Vector2(18,8))
	hover.border_width_bottom = 3 if on else 0
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_color_override("font_color",GOLD if on else MUTED)
	button.add_theme_color_override("font_hover_color",GOLD if on else PARCH)
# Drawn shapes share a 100-unit square, lit from the upper left.
class Drawn extends Control:
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
	func dot(raw: Array,radius: float,color: Color) -> void:
		draw_circle(pts([raw])[0],maxf(1.5,size.x*radius/100.0),color)
	func ring(raw: Array,radius: float,color: Color,width: float) -> void:
		draw_arc(pts([raw])[0],size.x*radius/100.0,0,TAU,32,color,maxf(1.0,width*size.x/100.0),true)
# Equipment silhouettes by slot; tier picks bright, dark or broad steel.
class GearIcon extends Drawn:
	var slot := "weapon"
	var tier := 0
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
				dot([50,90],5,trim)
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
				for x in [31,69]: dot([x,32],2.6,trim)
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
# Small emblems for currencies, research trees and the journal.
class Glyph extends Drawn:
	var kind := "coin"
	var color := Color(.87,.71,.37)
	func _draw() -> void:
		var ink := Color(.04,.04,.05,.9)
		match kind:
			"coin":
				var c: Vector2 = size*.5
				var r: float = minf(size.x,size.y)*.48
				draw_circle(c,r,Color(.58,.42,.13))
				draw_circle(c,r*.86,Color(.90,.72,.30))
				draw_circle(c,r*.56,Color(.98,.84,.44))
				draw_arc(c,r*.72,PI*1.1,PI*1.9,12,Color(1,.95,.75,.6),maxf(1,r*.12),true)
			"diamond":
				shape([[18,38],[34,16],[66,16],[82,38],[50,90]],Color(.52,.82,.94),Color(.10,.22,.30))
				stroke([[18,38],[82,38]],Color(.92,.98,1,.8),1.6)
				stroke([[34,16],[40,38],[50,90]],Color(.92,.98,1,.55),1.4)
				stroke([[66,16],[60,38],[50,90]],Color(.20,.45,.60,.7),1.4)
			"character":
				dot([50,26],14,color.darkened(.1))
				ring([50,26],14,ink,1.8)
				shape([[30,48],[70,48],[80,92],[20,92]],color)
				shape([[44,48],[56,48],[50,60]],color.darkened(.45))
			"equipment":
				shape([[8,30],[92,30],[92,42],[64,50],[64,72],[80,80],[80,90],[20,90],[20,80],[36,72],[36,50],[10,42]],color)
				stroke([[14,36],[86,36]],Color(1,1,1,.25),2)
			"trade":
				shape([[47,22],[53,22],[53,80],[47,80]],color.darkened(.2))
				shape([[28,80],[72,80],[72,88],[28,88]],color.darkened(.2))
				shape([[14,26],[86,26],[86,33],[14,33]],color)
				for side in [-1,1]:
					var x: float = 50+side*30
					stroke([[x,33],[x-12,56]],color.darkened(.3),1.4)
					stroke([[x,33],[x+12,56]],color.darkened(.3),1.4)
					shape([[x-14,56],[x+14,56],[x+8,64],[x-8,64]],color)
			"scholarship":
				shape([[12,24],[48,32],[48,84],[12,76]],color)
				shape([[52,32],[88,24],[88,76],[52,84]],color.darkened(.08))
				for i in 3:
					stroke([[18,38+i*12],[42,42+i*12]],Color(0,0,0,.45),1.6)
					stroke([[58,42+i*12],[82,38+i*12]],Color(0,0,0,.45),1.6)
				stroke([[50,30],[50,86]],ink,2)
			"hub":
				shape([[50,10],[92,50],[8,50]],color.darkened(.15))
				shape([[20,50],[80,50],[80,92],[20,92]],color)
				shape([[42,64],[58,64],[58,92],[42,92]],color.darkened(.5))
			"clock":
				dot([50,50],40,color.darkened(.55))
				ring([50,50],40,color,3)
				stroke([[50,50],[50,24]],color,3)
				stroke([[50,50],[68,60]],color,3)
			"desk":
				shape([[10,40],[90,40],[90,50],[10,50]],color)
				shape([[16,50],[26,50],[26,88],[16,88]],color.darkened(.25))
				shape([[74,50],[84,50],[84,88],[74,88]],color.darkened(.25))
				shape([[30,28],[62,22],[64,40],[32,40]],Color(.91,.87,.75))
			"check":
				stroke([[22,52],[42,72],[80,30]],color,9)
			"lock":
				shape([[26,44],[74,44],[74,88],[26,88]],color)
				stroke([[34,44],[34,30],[42,20],[58,20],[66,30],[66,44]],color,6)
				dot([50,64],5,ink)
class StatBar extends Drawn:
	var value := 0.0
	var maximum := 1.0
	var baseline := -1.0
	var color := Color.WHITE
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
class RankPips extends Drawn:
	var maximum := 5
	var rank := 0
	var next := false
	var color := Color(.90,.74,.38)
	func _draw() -> void:
		var step: float = size.x/maximum
		var r: float = minf(size.y*.5,step*.36)
		for i in maximum:
			var c := Vector2(step*(i+.5),size.y*.5)
			var diamond := PackedVector2Array([c+Vector2(0,-r),c+Vector2(r,0),c+Vector2(0,r),c+Vector2(-r,0)])
			if i<rank: draw_colored_polygon(diamond,color)
			else: draw_colored_polygon(diamond,Color(1,1,1,.07))
			diamond.append(diamond[0])
			draw_polyline(diamond,color.lightened(.15) if (i<rank or (next and i==rank)) else Color(1,1,1,.22),1.5,true)
class Ornament extends Drawn:
	func _draw() -> void:
		var l: float = 18
		var c := Color(.87,.71,.37,.9)
		for corner in [[Vector2(0,0),Vector2(1,1)],[Vector2(size.x,0),Vector2(-1,1)],[Vector2(0,size.y),Vector2(1,-1)],[Vector2(size.x,size.y),Vector2(-1,-1)]]:
			var o: Vector2 = corner[0]+corner[1]*3
			draw_line(o,o+Vector2(corner[1].x*l,0),c,2)
			draw_line(o,o+Vector2(0,corner[1].y*l),c,2)

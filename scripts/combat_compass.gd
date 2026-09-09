extends Control
# The duel reticle, drawn over the opponent's chest so the eye never leaves him: four triangles,
# one per lane, each with a red outline. The player's lane fills gold. The incoming cut fills its
# triangle red and pushes it outward as the blade comes in, then turns it white for the fifth of a
# second in which a guard raised now is a perfect one. His guard sits as a small blue triangle
# inside the lane it covers, pulsing white when it is set to parry. Beneath the triangles run his
# health and stagger and the player's stamina; when the stagger bar fills, his weak spot pulses
# on the triangle a heavy cut has to go through.
var combat: Node
const GAP := 26.0 # Radius of the empty centre.
const LENGTH := 30.0 # Triangle height.
const HALF := 19.0 # Half of the triangle base.
const OUTLINE := Color(.82,.12,.08,.95)
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	visible=combat.active and not combat.game.input_blocked and not combat.cinematic.active()
	queue_redraw()
func anchor_point() -> Vector2:
	var center := size*.5
	var camera: Camera3D=combat.game.camera
	if camera==null or combat.game.overview: return center
	var target: Vector3=combat.enemy.position+Vector3(0,1.15,0)
	if camera.is_position_behind(target): return center
	var point := camera.unproject_position(target)
	return Vector2(clampf(point.x,90,size.x-90),clampf(point.y,110,size.y-150))
static func axis_of(lane: int) -> Vector2: return Vector2.UP.rotated(lane*PI/2)
# The lane triangle: apex outward, base toward the centre, grown by `push` along its axis.
func triangle(center: Vector2,lane: int,push := 0.0,scale := 1.0) -> PackedVector2Array:
	var axis := axis_of(lane)
	var side := axis.orthogonal()
	var base := center+axis*(GAP+push)
	return PackedVector2Array([base+axis*LENGTH*scale,base+side*HALF*scale,base-side*HALF*scale])
func outline(points: PackedVector2Array,color: Color,width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed,color,width,true)
# A gradient band along one screen edge: top for High, right for Right, bottom for Low, left for Left.
func edge_flash(lane: int,color: Color,depth: float) -> void:
	var w := size.x
	var h := size.y
	var clear := Color(color.r,color.g,color.b,0)
	var points: PackedVector2Array
	match lane:
		0: points=PackedVector2Array([Vector2(0,0),Vector2(w,0),Vector2(w,h*depth),Vector2(0,h*depth)])
		1: points=PackedVector2Array([Vector2(w,0),Vector2(w,h),Vector2(w*(1-depth),h),Vector2(w*(1-depth),0)])
		2: points=PackedVector2Array([Vector2(w,h),Vector2(0,h),Vector2(0,h*(1-depth)),Vector2(w,h*(1-depth))])
		_: points=PackedVector2Array([Vector2(0,h),Vector2(0,0),Vector2(w*depth,0),Vector2(w*depth,h)])
	draw_polygon(points,PackedColorArray([color,color,clear,clear]))
func bar(at: Vector2,width: float,height: float,fraction: float,ghost: float,color: Color,back := Color(.08,.08,.09,.7)) -> void:
	draw_rect(Rect2(at-Vector2(width*.5,0),Vector2(width,height)),back)
	if ghost>fraction: draw_rect(Rect2(at-Vector2(width*.5,0),Vector2(width*clampf(ghost,0,1),height)),Color(color.r,color.g,color.b,.45).lightened(.4))
	if fraction>0: draw_rect(Rect2(at-Vector2(width*.5,0),Vector2(width*clampf(fraction,0,1),height)),color)
	draw_rect(Rect2(at-Vector2(width*.5,0),Vector2(width,height)),Color(.55,.10,.08,.8),false,1)
func _draw() -> void:
	if not visible: return
	var hero: Dictionary=combat.hero
	var foe: Dictionary=combat.foe
	var center := anchor_point()
	var font := ThemeDB.fallback_font
	var pulse: float=.5+.5*sin(Time.get_ticks_msec()*.012)
	var blink: bool=int(Time.get_ticks_msec()/180)%2==0
	if combat.hit_flash>0:
		var strength: float=clampf(combat.hit_flash/.6,0,1)
		edge_flash(combat.hit_lane,Color(.85,.10,.05,strength*.55),.26)
	var incoming: int=foe.attack_dir if foe.phase=="windup" else -1
	var fraction: float=CombatRules.progress(foe) if incoming>=0 else 0.0
	var now: bool=incoming>=0 and foe.timer<=CombatRules.PERFECT_WINDOW
	var frozen: int=foe.guard if foe.phase=="open" else -1
	var his_guard: int=foe.guard if foe.phase=="idle" and foe.blocking else frozen
	for lane in 4:
		var fill := Color(.04,.04,.05,.42)
		var line := OUTLINE
		var width := 2.0
		var push := 0.0
		var scale := 1.0
		if hero.guard==lane:
			var perfect: bool=hero.blocking and hero.block_age<=CombatRules.PERFECT_WINDOW
			fill=Color(1,1,1,.95) if perfect else (Color(1,.84,.38,.92) if hero.blocking else Color(.95,.78,.36,.70))
			if hero.blocking: line=Color(1,.93,.7,1)
			width=3.0 if hero.blocking else 2.0
		if frozen>=0 and lane!=frozen:
			# His guard is stuck: every other lane is an invitation.
			line=Color(1,.85,.4,.55+.45*pulse)
		if foe.phase=="exhausted" and foe.weak==lane:
			line=Color(1,.9,.55,.6+.4*pulse)
			width=3.0
		if incoming==lane:
			push=6.0*fraction
			scale=1.0+.22*fraction
			fill=Color(1,1,1,.98) if now else Color(.95,.16,.10,.40+.55*fraction)
			line=Color(1,1,1,1) if now else Color(1,.35,.25,1)
			width=3.0
		if combat.hit_flash>0 and combat.hit_lane==lane: fill=Color(1,.2,.1,clampf(combat.hit_flash/.6,0,1))
		var points := triangle(center,lane,push,scale)
		draw_colored_polygon(points,fill)
		outline(points,line,width)
		if incoming==lane and foe.heavy:
			# A heavy cut wears a second outline outside the first.
			outline(triangle(center,lane,push+6,scale+.18),Color(1,.45,.3,.5+.5*fraction),2.0)
		if his_guard==lane:
			var inner := triangle(center,lane,4.0,.45)
			var guard_color := Color(.38,.74,1,.9) if not foe.parry_ready else Color(1,1,1,.7+.3*pulse)
			if frozen==lane: guard_color=Color(.55,.80,1,.95)
			draw_colored_polygon(inner,guard_color)
		if incoming==lane and foe.flash>0:
			var axis := axis_of(lane)
			draw_string(font,center+axis*(GAP+LENGTH+26)+Vector2(-30,5),"FEINT",HORIZONTAL_ALIGNMENT_CENTER,60,13,Color(1,.55,.35,clampf(foe.flash*3,0,1)))
	draw_circle(center,2.5,Color(1,1,1,.5))
	# Timing rings in the centre gap: his windup closes in, a counter window drains, a frozen guard thaws.
	if hero.counter>0:
		draw_arc(center,GAP-8,-PI/2,-PI/2+TAU*clampf(hero.counter/1.05,0,1),32,Color(1,.84,.34),3,true)
		draw_circle(center+axis_of(hero.counter_dir)*(GAP-8),4,Color(1,.9,.6))
	elif incoming>=0:
		var closing: float=clampf(foe.timer/.6,0,1)
		draw_arc(center,GAP-6+closing*40,0,TAU,48,Color(1,1,1,.95) if now else Color(1,.3,.18,.25+.5*(1-closing)),3 if now else 2,true)
	elif foe.phase=="open":
		var left: float=clampf(foe.open/maxf(foe.get("open_total",1.0),.01),0,1)
		draw_arc(center,GAP-8,-PI/2,-PI/2+TAU*left,32,Color(.55,.80,1,.9),3,true)
		draw_string(font,center+Vector2(-60,-GAP-LENGTH-22),"OPEN",HORIZONTAL_ALIGNMENT_CENTER,120,15,Color(.7,.88,1))
	elif foe.phase=="exhausted":
		var left: float=clampf(foe.timer/CombatRules.EXHAUST_WINDOW,0,1)
		draw_arc(center,GAP-8,-PI/2,-PI/2+TAU*left,32,Color(1,.7,.35,.9),3,true)
		if foe.weak>=0:
			# The weak spot: a circle on the lane a heavy has to go through.
			var at := center+axis_of(foe.weak)*(GAP+LENGTH*.55)
			draw_circle(at,11+4*pulse,Color(1,1,1,.85))
			draw_arc(at,13+4*pulse,0,TAU,32,OUTLINE,2.5,true)
			draw_arc(at,20+8*pulse,0,TAU,32,Color(1,.9,.6,.5-.4*pulse),2,true)
		if blink: draw_string(font,center+Vector2(-80,-GAP-LENGTH-22),"EXHAUSTED  ·  HEAVY INTO THE MARK",HORIZONTAL_ALIGNMENT_CENTER,160,13,Color(1,.8,.45))
	if hero.phase=="windup":
		var mine: float=CombatRules.progress(hero)
		var can_feint: bool=mine<CombatRules.FEINT_LIMIT and not hero.feinted
		draw_arc(center,GAP-14,-PI/2,-PI/2+TAU*mine,24,Color(1,.9,.6,.9) if can_feint else Color(1,.8,.5,.4),2,true)
	if combat.pulse_time>0:
		var life: float=clampf(combat.pulse_time/.35,0,1)
		var color: Color=combat.pulse_color
		draw_arc(center,GAP+(1-life)*52,0,TAU,40,Color(color.r,color.g,color.b,life*.9),2+life*4,true)
	# Meters beneath: his health with a ghost, his stagger, the player's stamina.
	var top := center+Vector2(0,GAP+LENGTH+16)
	var ghost: float=clampf(combat.foe_ghost/maxf(foe.max_health,1),0,1)
	bar(top,124,6,foe.health/maxf(foe.max_health,1),ghost,Color(.88,.30,.24,.95))
	var stagger: float=clampf(foe.exhaust/100.0,0,1)
	var near: bool=foe.exhaust>=75 and foe.phase!="exhausted"
	bar(top+Vector2(0,9),124,4,stagger,0.0,Color(1,.78,.4) if near and blink else Color(.94,.57,.24,.95))
	var stamina: float=clampf(hero.stamina/maxf(hero.max_stamina,1),0,1)
	var stamina_color := Color(.38,.78,.48,.9)
	if combat.winded(hero): stamina_color=Color(1,.42,.3) if blink else Color(.62,.3,.25)
	if combat.stamina_flash>0: stamina_color=Color(1,.3,.2,.6+.4*clampf(combat.stamina_flash/.6,0,1))
	bar(top+Vector2(0,16),90,3,stamina,0.0,stamina_color)
	# Form pips.
	var progress: Dictionary=CombatRules.combo_progress(hero.chain)
	var step: int=progress.step if hero.chain_time>0 else 0
	var base := top+Vector2(0,30)
	for i in 3:
		var at := base+Vector2((i-1)*16,0)
		draw_circle(at,5,Color(.12,.12,.12,.7))
		if i<step: draw_circle(at,4,Color(1,.85,.45))
	if step>0:
		var combo: Dictionary=progress.combo
		var axis := axis_of(combo.steps[step])
		var glyph := base+Vector2(38,0)
		draw_colored_polygon(PackedVector2Array([glyph+axis*7,glyph-axis*4+axis.orthogonal()*5,glyph-axis*4-axis.orthogonal()*5]),Color(1,.85,.45))
		draw_string(font,base+Vector2(-60,22),str(combo.name).to_upper(),HORIZONTAL_ALIGNMENT_CENTER,120,11,Color(1,.85,.45,.85))

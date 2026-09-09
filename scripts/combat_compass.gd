extends Control
# The duel reticle: drawn over the opponent's chest so the eye never leaves the fight.
# Gold: the player's lane. Blue: the partner's guard (white when sharp). Red: the incoming cut,
# with a ring that closes on the reticle as it comes in and turns white when a guard raised
# now would parry. Hits taken flash the lane and the matching screen edge.
var combat: Node
const RADIUS := 52.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	visible=combat.active and not combat.game.input_blocked
	queue_redraw()
func anchor_point() -> Vector2:
	var center := size*.5
	var camera: Camera3D=combat.game.camera
	if camera==null or combat.game.overview: return center
	var target: Vector3=combat.enemy.position+Vector3(0,1.15,0)
	if camera.is_position_behind(target): return center
	var point := camera.unproject_position(target)
	return Vector2(clampf(point.x,RADIUS+40,size.x-RADIUS-40),clampf(point.y,RADIUS+60,size.y-RADIUS-90))
func lane_angle(lane: int) -> float: return -PI/2+lane*PI/2
func wedge(center: Vector2,radius: float,lane: int,width: float,color: Color,span := .62) -> void:
	var middle := lane_angle(lane)
	draw_arc(center,radius,middle-span,middle+span,18,color,width,true)
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
	# Outer state: the partner's health (with a pale ghost that drains after a hit) and exhaustion.
	draw_arc(center,RADIUS+21,PI*.75,PI*2.25,40,Color(.12,.12,.12,.55),5,true)
	var ghost: float=clampf(combat.foe_ghost/maxf(foe.max_health,1),0,1)
	var health: float=clampf(foe.health/maxf(foe.max_health,1),0,1)
	if ghost>health: draw_arc(center,RADIUS+21,PI*.75,PI*.75+PI*1.5*ghost,40,Color(1,.8,.7,.75),5,true)
	if health>0: draw_arc(center,RADIUS+21,PI*.75,PI*.75+PI*1.5*health,40,Color(.88,.34,.28,.9),5,true)
	if foe.exhaust>0:
		var near: bool=foe.exhaust>=75
		draw_arc(center,RADIUS+27,PI*.75,PI*.75+PI*1.5*clampf(foe.exhaust/100.0,0,1),40,Color(1,.75,.4) if near and blink else Color(.94,.57,.24,.8),3 if near else 2,true)
	# The player's own stamina sits in the gap beneath the reticle, where the eye already rests.
	var stamina: float=clampf(hero.stamina/maxf(hero.max_stamina,1),0,1)
	var winded: bool=combat.winded(hero)
	draw_arc(center,RADIUS+21,PI*.30,PI*.70,16,Color(.12,.12,.12,.55),5,true)
	var stamina_color := Color(.38,.78,.48,.95)
	if winded: stamina_color=Color(1,.42,.3) if blink else Color(.62,.3,.25)
	if combat.stamina_flash>0: stamina_color=Color(1,.3,.2,.6+.4*clampf(combat.stamina_flash/.6,0,1))
	if stamina>0: draw_arc(center,RADIUS+21,PI*.30,PI*.30+PI*.40*stamina,16,stamina_color,5,true)
	for lane in 4:
		var axis := Vector2.UP.rotated(lane*PI/2)
		var side := axis.orthogonal()
		var tip := center+axis*(RADIUS+8)
		wedge(center,RADIUS,lane,4,Color(.25,.28,.28,.5))
		var triangle := PackedVector2Array([tip+axis*8,tip-axis*4+side*6,tip-axis*4-side*6])
		var color := Color(.3,.35,.35,.6)
		if hero.guard==lane:
			var perfect: bool=hero.blocking and hero.block_age<=CombatRules.PERFECT_WINDOW
			color=Color(1,1,1) if perfect else (Color(1,.86,.45) if hero.blocking else Color(.95,.80,.40,.95))
			wedge(center,RADIUS,lane,7 if hero.blocking else 5,color)
		if combat.hit_flash>0 and combat.hit_lane==lane:
			wedge(center,RADIUS,lane,9,Color(1,.2,.1,clampf(combat.hit_flash/.6,0,1)))
		draw_colored_polygon(triangle,color)
		if foe.phase=="idle" and foe.blocking and foe.guard==lane:
			var guard_color := Color(.4,.8,1) if not foe.parry_ready else Color(1,1,1,.7+.3*pulse)
			wedge(center,RADIUS+12,lane,3,guard_color,.5)
		if foe.phase=="windup" and foe.attack_dir==lane:
			var fraction: float=CombatRules.progress(foe)
			var hot: bool=fraction>.7
			var now: bool=foe.timer<=CombatRules.PERFECT_WINDOW
			var incoming := Color(1,1,1) if now else Color(1,.3,.15,.55+.45*(pulse if not hot else 1.0))
			wedge(center,RADIUS-10,lane,3+fraction*9,incoming,.4+fraction*.25)
			draw_circle(tip+axis*14,5+fraction*3,incoming)
			if foe.heavy: draw_circle(tip+axis*14,9+fraction*3,Color(1,.3,.15,.35+.4*fraction))
			if foe.flash>0: draw_string(font,tip+axis*24+Vector2(-14,6),"FEINT",HORIZONTAL_ALIGNMENT_CENTER,60,13,Color(1,.55,.35,clampf(foe.flash*3,0,1)))
	# Timing rings: the counter window, or the partner's windup as a filling arc and a closing ring.
	if hero.counter>0:
		draw_arc(center,RADIUS-24,-PI/2,-PI/2+TAU*clampf(hero.counter/1.05,0,1),32,Color(1,.84,.34),3,true)
		var axis := Vector2.UP.rotated(hero.counter_dir*PI/2)
		draw_circle(center+axis*(RADIUS-24),4,Color(1,.9,.6))
	elif foe.phase=="windup":
		var fraction: float=CombatRules.progress(foe)
		draw_arc(center,RADIUS-24,-PI/2,-PI/2+TAU*fraction,32,Color(1,.35,.18,.85),2,true)
		var closing: float=clampf(foe.timer/.6,0,1)
		var now: bool=foe.timer<=CombatRules.PERFECT_WINDOW
		draw_arc(center,RADIUS+6+closing*46,0,TAU,48,Color(1,1,1,.95) if now else Color(1,.35,.18,.3+.5*(1-closing)),3 if now else 2,true)
	elif foe.phase=="exhausted":
		draw_arc(center,RADIUS-24,-PI/2,-PI/2+TAU*(1-clampf(foe.timer/3.0,0,1)),32,Color(1,.6,.3,.7),2,true)
		if blink: draw_string(font,center+Vector2(-60,-RADIUS-40),"OPEN",HORIZONTAL_ALIGNMENT_CENTER,120,14,Color(1,.7,.35))
	if hero.phase=="windup":
		var fraction: float=CombatRules.progress(hero)
		var can_feint: bool=fraction<CombatRules.FEINT_LIMIT and not hero.feinted
		draw_arc(center,RADIUS-30,-PI/2,-PI/2+TAU*fraction,24,Color(1,.9,.6,.9) if can_feint else Color(1,.8,.5,.4),2,true)
	# An expanding ring marks a landed cut, a parry or a clash.
	if combat.pulse_time>0:
		var life: float=clampf(combat.pulse_time/.35,0,1)
		var color: Color=combat.pulse_color
		draw_arc(center,RADIUS-24+(1-life)*44,0,TAU,40,Color(color.r,color.g,color.b,life*.9),2+life*4,true)
	# Form pips beneath the reticle.
	var progress: Dictionary=CombatRules.combo_progress(hero.chain)
	var step: int=progress.step if hero.chain_time>0 else 0
	var base := center+Vector2(0,RADIUS+44)
	for i in 3:
		var at := base+Vector2((i-1)*16,0)
		draw_circle(at,5,Color(.12,.12,.12,.7))
		if i<step: draw_circle(at,4,Color(1,.85,.45))
	if step>0:
		var combo: Dictionary=progress.combo
		var next_lane: int=combo.steps[step]
		var axis := Vector2.UP.rotated(next_lane*PI/2)
		var glyph := base+Vector2(38,0)
		draw_colored_polygon(PackedVector2Array([glyph+axis*7,glyph-axis*4+axis.orthogonal()*5,glyph-axis*4-axis.orthogonal()*5]),Color(1,.85,.45))
		draw_string(font,base+Vector2(-60,26),str(combo.name).to_upper(),HORIZONTAL_ALIGNMENT_CENTER,120,11,Color(1,.85,.45,.85))
	if combat.salute>0:
		draw_string(font,center+Vector2(-60,-RADIUS-40),"SALUTE",HORIZONTAL_ALIGNMENT_CENTER,120,14,Color(.95,.88,.66))

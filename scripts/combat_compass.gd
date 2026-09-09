extends Control
# The duel reticle, drawn small over the opponent's chest so the eye never leaves him: four
# triangles, one per lane, each with a red outline. The player's lane fills gold. The incoming cut
# fills its triangle red and pushes it outward as the blade comes in. Timing is read off his blade,
# not off a ring: a pale spark bursts on it the instant the cut commits, meaning a guard raised
# now will meet it, and a red spark burns on it through the fifth of a second in which a guard
# raised now is a perfect one. His guard is a small blue triangle inside the lane it covers.
var combat: Node
const GAP := 13.0 # Radius of the empty centre.
const LENGTH := 12.0 # Triangle height.
const HALF := 7.5 # Half of the triangle base.
const OUTLINE := Color(.82,.12,.08,.95)
const PARRY_RED := Color(1,.055,.075)
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	visible=combat.active and not combat.game.input_blocked and combat.game.ui.visible and not combat.cinematic.active()
	queue_redraw()
func anchor_point() -> Vector2:
	var camera: Camera3D=combat.game.camera
	var target: Vector3=combat.enemy.global_position+Vector3(0,1.15,0)
	if camera.is_position_behind(target): return Vector2(-200,-200)
	return camera.unproject_position(target)
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
	var parry_now: bool=combat.parry_cue_active()
	var frozen: int=foe.guard if foe.phase=="open" else -1
	var his_guard: int=foe.guard if foe.phase=="idle" and foe.blocking else frozen
	for lane in 4:
		var fill := Color(.04,.04,.05,.42)
		var line := OUTLINE
		var width := 1.5
		var push := 0.0
		var scale := 1.0
		if hero.guard==lane:
			var perfect: bool=hero.blocking and hero.block_age<=CombatRules.PERFECT_WINDOW
			fill=Color(1,1,1,.95) if perfect else (Color(1,.84,.38,.92) if hero.blocking else Color(.95,.78,.36,.70))
			if hero.blocking: line=Color(1,.93,.7,1)
			width=2.0 if hero.blocking else 1.5
		if frozen>=0 and lane!=frozen: line=Color(1,.85,.4,.55+.45*pulse)
		if foe.phase=="exhausted" and foe.weak==lane:
			line=Color(1,.9,.55,.6+.4*pulse)
			width=2.0
		if incoming==lane:
			push=4.0*fraction
			scale=1.0+.25*fraction
			fill=PARRY_RED if parry_now else Color(.95,.16,.10,.45+.5*fraction)
			line=Color(1,.6,.5,1) if parry_now else Color(1,.35,.25,1)
			width=2.0
		if combat.hit_flash>0 and combat.hit_lane==lane: fill=Color(1,.2,.1,clampf(combat.hit_flash/.6,0,1))
		var points := triangle(center,lane,push,scale)
		draw_colored_polygon(points,fill)
		outline(points,line,width)
		if incoming==lane and foe.heavy: outline(triangle(center,lane,push+3,scale+.25),Color(1,.45,.3,.5+.5*fraction),1.2)
		if his_guard==lane:
			var guard_color := Color(.38,.74,1,.9) if not foe.parry_ready else Color(1,1,1,.7+.3*pulse)
			if frozen==lane: guard_color=Color(.55,.80,1,.95)
			draw_colored_polygon(triangle(center,lane,2.0,.42),guard_color)
		if incoming==lane and foe.flash>0:
			draw_string(font,center+axis_of(lane)*(GAP+LENGTH+16)+Vector2(-30,4),"FEINT",HORIZONTAL_ALIGNMENT_CENTER,60,11,Color(1,.55,.35,clampf(foe.flash*3,0,1)))
	draw_circle(center,1.5,Color(1,1,1,.5))
	if hero.counter>0:
		draw_arc(center,GAP-4,-PI/2,-PI/2+TAU*clampf(hero.counter/1.05,0,1),24,Color(1,.84,.34),2,true)
		draw_circle(center+axis_of(hero.counter_dir)*(GAP-4),2.5,Color(1,.9,.6))
	elif foe.phase=="open":
		var left: float=clampf(foe.open/maxf(foe.get("open_total",1.0),.01),0,1)
		draw_arc(center,GAP-4,-PI/2,-PI/2+TAU*left,24,Color(.55,.80,1,.9),2,true)
		draw_string(font,center+Vector2(-40,-GAP-LENGTH-12),"OPEN",HORIZONTAL_ALIGNMENT_CENTER,80,12,Color(.7,.88,1))
	elif foe.phase=="exhausted":
		var left: float=clampf(foe.timer/CombatRules.EXHAUST_WINDOW,0,1)
		draw_arc(center,GAP-4,-PI/2,-PI/2+TAU*left,24,Color(1,.7,.35,.9),2,true)
		if foe.weak>=0:
			# The weak spot: a circle on the lane a heavy has to go through.
			var at := center+axis_of(foe.weak)*(GAP+LENGTH*.6)
			draw_circle(at,6+2*pulse,Color(1,1,1,.85))
			draw_arc(at,7.5+2*pulse,0,TAU,24,OUTLINE,1.8,true)
			draw_arc(at,12+5*pulse,0,TAU,24,Color(1,.9,.6,.5-.4*pulse),1.5,true)
		if blink: draw_string(font,center+Vector2(-80,-GAP-LENGTH-12),"EXHAUSTED  ·  HEAVY INTO THE MARK",HORIZONTAL_ALIGNMENT_CENTER,160,11,Color(1,.8,.45))
	if combat.pulse_time>0:
		var life: float=clampf(combat.pulse_time/.35,0,1)
		var color: Color=combat.pulse_color
		draw_arc(center,GAP+(1-life)*36,0,TAU,32,Color(color.r,color.g,color.b,life*.9),1.5+life*3,true)
	# Form pips.
	var progress: Dictionary=CombatRules.combo_progress(hero.chain)
	var step: int=progress.step if hero.chain_time>0 else 0
	if step>0:
		var base := center+Vector2(0,GAP+LENGTH+12)
		for i in 3:
			var at := base+Vector2((i-1)*10,0)
			draw_circle(at,3,Color(.12,.12,.12,.7))
			if i<step: draw_circle(at,2.5,Color(1,.85,.45))
		var combo: Dictionary=progress.combo
		var axis := axis_of(combo.steps[step])
		var glyph := base+Vector2(24,0)
		draw_colored_polygon(PackedVector2Array([glyph+axis*5,glyph-axis*3+axis.orthogonal()*3.5,glyph-axis*3-axis.orthogonal()*3.5]),Color(1,.85,.45))
	# Sparks on his blade: pale when the cut commits, red while a guard raised now is perfect.
	if parry_now: blade_spark(PARRY_RED,Color(1,.80,.72),1.0-clampf(foe.timer/CombatRules.PERFECT_WINDOW,0,1),1.0)
	elif foe.get("spark",0.0)>0 and incoming>=0: blade_spark(Color(1,.93,.75),Color(1,1,1),1.0-clampf(foe.spark/.16,0,1),.72)
func blade_spark(color: Color,core: Color,progress: float,size: float) -> void:
	if not is_instance_valid(combat.enemy_sword) or not combat.enemy_sword.is_inside_tree(): return
	var camera: Camera3D=combat.game.camera
	var point: Vector3=combat.enemy_sword.to_global(Vector3(0,.9,0))
	if camera.is_position_behind(point): return
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position,point,1)
	if not combat.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return
	var center := camera.unproject_position(point)
	# Screen-sized and blade-attached, so it reads at every camera distance.
	var radius: float=lerpf(26,16,progress)*size
	draw_circle(center,radius,Color(color.r*.2,color.g*.2,color.b*.2,.30))
	draw_circle(center,radius*.78,Color(color.r,color.g,color.b,.13))
	draw_circle(center,radius*.48,Color(color.r,color.g,color.b,.28))
	for i in 8:
		var axis := Vector2.UP.rotated(i*PI/4+.12)
		var length: float=radius*(1.0 if i%2==0 else .62)
		draw_colored_polygon(PackedVector2Array([center+axis*length,center+axis.orthogonal()*2.5,center-axis*2.5,center-axis.orthogonal()*2.5]),color)
	draw_circle(center,3.5,core)

extends Control
# Amber previews the attack lane; a sharp red weapon spark means parry now.
var combat: Node
const RADIUS:=23.0
const PARRY_RED:=Color(1,.055,.075)
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	visible=combat.active and not combat.game.input_blocked and combat.game.ui.visible
	queue_redraw()
func anchor_point() -> Vector2:
	var camera: Camera3D=combat.game.camera
	var target: Vector3=combat.enemy.global_position+Vector3(0,1.2,0)
	if camera.is_position_behind(target):return Vector2(-100,-100)
	return camera.unproject_position(target)
func arrow(center: Vector2,axis: Vector2,color: Color,width: float,scale:=1.0) -> void:
	var side:=axis.orthogonal()
	var tip:=center+axis*(RADIUS+6)*scale
	var tail:=center+axis*(RADIUS-6)*scale
	draw_line(tail,tip,color,width,true)
	draw_polyline(PackedVector2Array([tip-axis*5*scale+side*4*scale,tip,tip-axis*5*scale-side*4*scale]),color,width,true)
func _draw() -> void:
	if not visible:return
	var center:=anchor_point()
	var hero: Dictionary=combat.hero
	var foe: Dictionary=combat.foe
	var parry_now: bool=combat.parry_cue_active()
	for lane in 4:
		var axis:=Vector2.UP.rotated(lane*PI/2)
		var color:=Color(.53,.57,.55,.65)
		if lane==hero.guard:color=Color(.95,.78,.36)
		if foe.blocking and lane==foe.guard:color=Color(.42,.75,.94)
		if foe.phase=="windup" and lane==foe.attack_dir:
			color=PARRY_RED if parry_now else Color(.92,.56,.24)
			if parry_now:
				arrow(center,axis,Color(1,.025,.05,.22),15,1.12)
				arrow(center,axis,Color(1,.025,.05,.5),8)
		arrow(center,axis,color,2.4)
	if parry_now:draw_parry_spark()
func draw_parry_spark() -> void:
	if not is_instance_valid(combat.enemy_sword):return
	var camera: Camera3D=combat.game.camera
	var point: Vector3=combat.enemy_sword.to_global(Vector3(0,.4,0))
	if camera.is_position_behind(point):return
	var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,point,1)
	if not combat.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return
	var center:=camera.unproject_position(point)
	# Screen-sized, blade-attached burst stays readable at both camera distances.
	# State-driven drawing stops immediately on impact, interruption or target change.
	var progress:=1.0-clampf(combat.foe.timer/CombatRules.PERFECT_WINDOW,0,1)
	var radius:=lerpf(29,19,progress)
	draw_circle(center,radius,Color(.04,.005,.008,.32))
	draw_circle(center,radius*.78,Color(1,.015,.035,.13))
	draw_circle(center,radius*.48,Color(1,.025,.045,.28))
	for i in 8:
		var axis:=Vector2.UP.rotated(i*PI/4+.12)
		var length: float=radius*(1.0 if i%2==0 else .62)
		var points:=PackedVector2Array([center+axis*length,center+axis.orthogonal()*3,center-axis*3,center-axis.orthogonal()*3])
		draw_colored_polygon(points,PARRY_RED)
	draw_circle(center,4,Color(1,.80,.72))

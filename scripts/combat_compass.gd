extends Control
var combat: Node
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	visible=combat.active and not combat.game.input_blocked
	queue_redraw()
func _draw() -> void:
	if not visible: return
	var center := Vector2(64,64)
	for lane in 4:
		var axis := Vector2.UP.rotated(lane*PI/2)
		var side := axis.orthogonal()
		var p := center+axis*48
		var triangle := PackedVector2Array([p+axis*10,p-axis*5+side*8,p-axis*5-side*8])
		var color := Color(.3,.35,.35,.6)
		if combat.hero.guard==lane: color=Color(.95,.80,.40,.95)
		draw_colored_polygon(triangle,color)
		if combat.foe.guard==lane and combat.foe.phase=="idle":
			draw_line(p+side*10-axis*9,p-side*10-axis*9,Color(.4,.8,1),3)
		if combat.foe.phase=="windup" and combat.foe.attack_dir==lane:
			draw_circle(p+axis*14,5,Color(1,.25,.13))
	if combat.hero.counter>0:
		draw_arc(center,27,-PI/2,-PI/2+TAU*clampf(combat.hero.counter/1.05,0,1),32,Color(1,.84,.34),3)
	elif combat.foe.phase=="windup":
		var fraction: float=1-combat.foe.timer/maxf(combat.foe.total,.01)
		draw_arc(center,23,-PI/2,-PI/2+TAU*fraction,32,Color(1,.35,.18,.8),2)

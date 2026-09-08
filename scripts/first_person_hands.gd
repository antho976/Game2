extends Node3D
var game: Node3D
var arms: Node3D
var animation: AnimationPlayer
var clock := 0.0
var current := ""
func _ready() -> void:
	arms = load("res://assets/village/first_person_arms.glb").instantiate()
	add_child(arms)
	arms.scale = Vector3.ONE*.65
	arms.rotation = Vector3(-PI/2,PI,0)
	arms.position = Vector3(0,-.25,-1.0)
	animation = arms.find_children("*","AnimationPlayer",true,false)[0]
	for clip in animation.get_animation_list(): animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for mesh in arms.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _process(delta: float) -> void:
	visible = game.camera_mode==1 and not game.overview and not game.menus.home
	if not visible: return
	clock += delta
	var speed: float = Vector2(game.player.velocity.x,game.player.velocity.z).length()
	var action: String = game.player.activity if not game.player.activity.is_empty() else "idle"
	for clip in animation.get_animation_list():
		if clip.ends_with("villager_"+action) and current!=clip:
			animation.play(clip,.15)
			current = clip
	position = Vector3(sin(clock*7)*.009,sin(clock*14)*.008,0)*minf(speed,1)

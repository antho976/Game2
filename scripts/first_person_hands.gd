extends Node3D
var game: Node3D
var arms: Node3D
var animation: AnimationPlayer
var clock := 0.0
var current := ""
var combat_grip: SkeletonModifier3D
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
	visible = (game.camera_mode==1 or game.inside_school()) and not game.overview and not game.menus.home
	if not visible: return
	var fighting: bool=is_instance_valid(game.combat) and game.combat.active
	arms.rotation=Vector3(0,PI,0) if fighting else Vector3(-PI/2,PI,0)
	arms.position=Vector3(0,-1.60,0) if fighting else Vector3(0,-.25,-1.0)
	arms.scale=Vector3.ONE*(.97 if fighting else .65)
	clock += delta
	var speed: float = Vector2(game.player.velocity.x,game.player.velocity.z).length()
	var action: String = game.player.activity if not game.player.activity.is_empty() else "idle"
	for clip in animation.get_animation_list():
		if clip.ends_with("villager_"+action) and current!=clip:
			animation.play(clip,.15)
			current = clip
	position = Vector3(sin(clock*7)*.009,sin(clock*14)*.008,0)*minf(speed,1)

func set_weapon(item: Dictionary) -> void:
	if is_instance_valid(combat_grip): combat_grip.queue_free()
	var old := get_node_or_null("HeldGreatsword")
	if old:
		remove_child(old)
		old.queue_free()
	if item.is_empty(): return
	var root := Node3D.new()
	root.name = "HeldGreatsword"
	add_child(root)
	root.position = Vector3(.29,-.21,-.62)
	root.rotation = Vector3(-.42,0,-.12)
	root.scale = Vector3.ONE*.65
	var builder := GearVisuals.new()
	builder.steel = GearVisuals.material(Color(.43,.48,.50) if item.style==0 else Color(.16,.20,.23),.78)
	builder.trim = GearVisuals.material(Color(.54,.40,.20),.72)
	builder.leather = GearVisuals.material(Color(.10,.07,.045))
	builder.sword(root,item.style)
	combat_grip=preload("res://scripts/combat_grip.gd").new()
	combat_grip.sword=root
	arms.find_children("*","Skeleton3D",true,false)[0].add_child(combat_grip)

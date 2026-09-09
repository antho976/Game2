extends Node3D
## Isolated art review. Does not load, replace or modify the live combat controller.
const ROOT := "res://assets/dungeon/first_portal/"
var camera: Camera3D
var warden: Node3D
var mine: Node3D
var gate: Node3D
var environment: WorldEnvironment
var title: Label
var detail: Label
var mode := 1
var turn := 0.0
func _ready() -> void:
	DisplayServer.window_set_title("Game2 • First portal asset review")
	Engine.max_fps=60
	environment=WorldEnvironment.new()
	environment.environment=Environment.new()
	var env:=environment.environment
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(.025,.033,.037)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(.53,.65,.67)
	env.ambient_light_energy=.55
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-32,0)
	sun.light_color=Color(.79,.83,.78)
	sun.light_energy=.6
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=55
	add_child(sun)
	warden=load(ROOT+"warden.glb").instantiate()
	add_child(warden)
	var floor:=MeshInstance3D.new()
	var cylinder:=CylinderMesh.new()
	cylinder.top_radius=1.2
	cylinder.bottom_radius=1.3
	cylinder.height=.10
	cylinder.radial_segments=48
	floor.mesh=cylinder
	floor.position.y=-.05
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color(.13,.15,.14)
	mat.roughness=.9
	floor.material_override=mat
	add_child(floor)
	var sword: Node3D=load(ROOT+"mining_blade.glb").instantiate()
	sword.position=Vector3(.72,.30,0)
	sword.rotation.z=-.1
	add_child(sword)
	mine=load(ROOT+"mine_sample.glb").instantiate()
	mine.position.x=28
	add_child(mine)
	var defender: Node3D=load(ROOT+"warden.glb").instantiate()
	defender.position=Vector3(29.6,0,-3.3)
	add_child(defender)
	gate=load(ROOT+"portal_frame.glb").instantiate()
	gate.position.x=-20
	add_child(gate)
	portal_veil()
	spot(Vector3(2.5,4.0,3.5),Vector3(0,1,0),Color(1,.79,.57),5,12)
	spot(Vector3(-2,3,-2.5),Vector3(0,1,0),Color(.34,.7,.76),4,10)
	spot(Vector3(-3,2,2),Vector3(0,1,0),Color(.67,.79,.83),2,10)
	spot(Vector3(28,5,7),Vector3(28,0,-3),Color(.65,.76,.75),6,22)
	lamp(Vector3(23.5,2.55,1.95),Color(1,.53,.22),3.0,7)
	lamp(Vector3(32.5,2.55,-3.8),Color(1,.53,.22),3.0,7)
	lamp(Vector3(23,1,-3),Color(.18,.74,.63),2.0,5)
	lamp(Vector3(29,2,-7),Color(.29,.55,.66),2,6)
	spot(Vector3(-17,7,6),Vector3(-20,1,0),Color(1,.86,.67),7,18)
	lamp(Vector3(-20,2,.6),Color(.27,.56,.58),1.5,5)
	for side in [-1,1]:lamp(Vector3(-20+side*2.5,1.1,1),Color(1,.57,.23),.6,3)
	camera=Camera3D.new()
	camera.near=.05
	camera.far=100
	add_child(camera)
	camera.make_current()
	var overlay:=CanvasLayer.new()
	add_child(overlay)
	title=Label.new()
	title.position=Vector2(32,25)
	title.add_theme_font_size_override("font_size",26)
	title.modulate=Color(.90,.79,.54)
	overlay.add_child(title)
	detail=Label.new()
	detail.position=Vector2(34,65)
	detail.add_theme_font_size_override("font_size",15)
	overlay.add_child(detail)
	var controls:=Label.new()
	controls.text="1  Warden     2  Mine entrance     3  Village gate     A / D  Rotate model     Esc  Close"
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position=Vector2(32,-38)
	controls.add_theme_font_size_override("font_size",15)
	overlay.add_child(controls)
	show_view(1)
	if "--asset-capture" in OS.get_cmdline_user_args(): capture()
	elif "--asset-check" in OS.get_cmdline_user_args(): check_assets()
func spot(pos: Vector3,target: Vector3,color: Color,power: float,reach: float) -> void:
	var light:=SpotLight3D.new()
	add_child(light)
	light.position=pos
	light.look_at(target)
	light.light_color=color
	light.light_energy=power
	light.spot_range=reach
	light.spot_angle=65
	light.spot_attenuation=.7
	light.shadow_enabled=false
func lamp(pos: Vector3,color: Color,power: float,reach: float) -> void:
	var light:=OmniLight3D.new()
	light.position=pos
	light.light_color=color
	light.light_energy=power
	light.omni_range=reach
	light.omni_attenuation=1.4
	add_child(light)
func portal_veil() -> void:
	var mesh:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(2.92,3.63)
	mesh.mesh=quad
	mesh.position=Vector3(-20,1.815,-.08)
	var material:=ShaderMaterial.new()
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float arch=length(vec2(p.x,max(0.0,-p.y*1.25-.23)));
 float edge=1.0-smoothstep(.90,1.0,arch);
 float waves=sin(UV.y*21.0+sin(UV.x*9.0+TIME*.4)*2.0-TIME*.65)*.5+.5;
 float rim=pow(clamp(arch,0.0,1.0),12.0);
 ALBEDO=mix(vec3(.022,.052,.062),vec3(.14,.32,.33),waves*.25+rim*.5);
 ALPHA=edge*.95;
}
"""
	material.shader=shader
	mesh.material_override=material
	add_child(mesh)
func show_view(value: int) -> void:
	mode=value
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	match mode:
		1:
			camera.size=3.3
			camera.position=Vector3(2.7,1.95,4.8)
			camera.look_at(Vector3(.1,1.0,0))
			title.text="THE TITHE WARDEN"
			detail.text="Local mine defender • Existing humanoid rig • Mining blade shown separately"
		2:
			camera.size=17
			camera.position=Vector3(38,10,14)
			camera.look_at(Vector3(28,1,-1))
			title.text="THE SPENT WORKS"
			detail.text="Mine entrance study • Settlement ruins, extracted seams and a guarded living deposit"
		3:
			camera.size=6.3
			camera.position=Vector3(-16,3.4,8)
			camera.look_at(Vector3(-20,2,0))
			title.text="THE VILLAGE THRESHOLD"
			detail.text="Weathered stone, repaired joints, lamps and votive offerings"
func _process(delta: float) -> void:
	if mode==1:
		if Input.is_physical_key_pressed(KEY_A): turn+=delta
		if Input.is_physical_key_pressed(KEY_D): turn-=delta
		warden.rotation.y=turn
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_1:show_view(1)
		KEY_2:show_view(2)
		KEY_3:show_view(3)
		KEY_ESCAPE:get_tree().quit()
func check_assets() -> void:
	var skeletons=warden.find_children("*","Skeleton3D",true,false)
	assert(skeletons.size()==1,"Warden needs a single humanoid skeleton")
	for bone in ["Hips","Chest","Head","UpperArm.R","Forearm.R","Hand.R","Thigh.L","Shin.L"]:
		assert(skeletons[0].find_bone(bone)>=0,"Missing combat-compatible bone: "+bone)
	var animation: AnimationPlayer=warden.find_children("*","AnimationPlayer",true,false)[0]
	assert(not animation.get_animation_list().is_empty(),"Locomotion clips must be retained")
	print("ASSET CHECKS COMPLETE: rig bones and ",animation.get_animation_list().size()," animation clips present")
	get_tree().quit()
func capture() -> void:
	await get_tree().create_timer(2).timeout
	for view in [1,2,3]:
		show_view(view)
		await get_tree().create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/first-portal-%d.png"%view)
	show_view(1)
	turn=PI
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/first-portal-warden-back.png")
	turn=0
	var animation: AnimationPlayer=warden.find_children("*","AnimationPlayer",true,false)[0]
	for clip in animation.get_animation_list():
		if "walk" in clip:
			animation.play(clip)
			break
	await get_tree().create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/first-portal-warden-walk.png")
	check_assets()

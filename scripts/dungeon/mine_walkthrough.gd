extends Node3D
## Environment-only expedition review. Intentionally has no dependency on combat.gd.
const ROOT := "res://assets/dungeon/first_portal/"
const MODULES := ROOT+"modules/"
const SPAWN := Vector3(0,.1,11)
const AREAS := [
	["THE THRESHOLD", Rect2(-6,2,12,14)],
	["THE LAMP GALLERY", Rect2(-4,-14,8,16)],
	["THE SORTING HALL", Rect2(-12,-34,24,20)],
	["THE HAULAGE WORKS", Rect2(2,-52,10,18)],
	["THE LAST VEIN", Rect2(-6,-72,20,20)],
	["THE OLD SERVICE WAY", Rect2(-16,-56,4,62)],
	["THE OLD SERVICE WAY", Rect2(-16,2,12,4)],
	["THE OLD SERVICE WAY", Rect2(-16,-56,20,4)]
]
var embedded := false
var defenders: Array[Dictionary] = []
var cells: Dictionary = {}
var batches: Dictionary = {}
var mats: Dictionary = {}
var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var camera: Camera3D
var roof: Node3D
var shell: Node3D
var world: Node3D
var input_blocked := false
var combat: Node = null
var yaw := 0.0
var pitch := -.06
var first_person := false
var heading: Label
var caption: Label
var prompt: Label
var markers: Array[Dictionary] = []
var materials: Array[Material] = []
var rubble_mesh: Mesh
var active_marker := -1
var reading := 0.0
var ceiling_light: DirectionalLight3D
var cave_environment: Environment
var block_mesh: Mesh
var grain_texture: NoiseTexture2D
const SURFACES = preload("res://scripts/dungeon/mine_surfaces.gd")

func _ready() -> void:
	if not embedded: DisplayServer.window_set_title("Game2 • The Spent Works • Environment review")
	if not embedded: Engine.max_fps=90
	rng.seed=90821
	world=Node3D.new()
	add_child(world)
	shell=Node3D.new()
	add_child(shell)
	shell.scale.y=.42
	roof=Node3D.new()
	add_child(roof)
	roof.hide()
	make_materials()
	var block_scene: Node3D=load(MODULES+"block.glb").instantiate()
	block_mesh=block_scene.find_children("*","MeshInstance3D",true,false)[0].mesh
	block_scene.free()
	make_layout()
	decorate()
	flush_batches()
	setup_light()
	if embedded:return
	setup_player()
	setup_overlay()
	if "--mine-check" in OS.get_cmdline_user_args(): call_deferred("check_route")
	if "--mine-capture" in OS.get_cmdline_user_args(): call_deferred("capture")

func material(color: Color, roughness := .9) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=roughness
	materials.append(m)
	return m

func make_materials() -> void:
	mats.stone=material(Color(.34,.37,.33))
	mats.wood=material(Color(.23,.14,.08))
	mats.iron=material(Color(.12,.17,.17),.65)
	mats.iron.metallic=.6
	mats.cloth=material(Color(.30,.24,.17))
	mats.dark=material(Color(.035,.045,.04))
	mats.pottery=material(Color(.4,.24,.14))
	var noise:=FastNoiseLite.new()
	noise.seed=919
	noise.frequency=.14
	noise.fractal_octaves=5
	grain_texture=NoiseTexture2D.new()
	grain_texture.width=1024
	grain_texture.height=1024
	grain_texture.seamless=true
	grain_texture.noise=noise
	for key in ["ground","paving","rock"]:
		var shader_material:=ShaderMaterial.new()
		shader_material.shader=load("res://scripts/dungeon/mine_"+key+".gdshader")
		shader_material.set_shader_parameter("grain",grain_texture)
		mats[key]=shader_material
	mats.stone=mats.paving
	mats.bedrock=mats.rock

func bounds_box(pos: Vector3,size: Vector3,parent: Node=null) -> void:
	if parent==null:parent=world
	var body:=StaticBody3D.new()
	body.position=pos
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	parent.add_child(body)

func block(key: String,pos: Vector3,size: Vector3,mat: Material,angle := 0.0,parent: Node=null) -> void:
	if parent==null:parent=world
	if not batches.has(key):
		var mesh: Mesh=block_mesh
		if key in ["floor","roof","wall"]:
			mesh=BoxMesh.new()
		batches[key]={"mesh":mesh,"material":mat,"transforms":[],"parent":parent}
	var basis:=Basis(Vector3.UP,angle).scaled(size)
	batches[key].transforms.append(Transform3D(basis,pos))

func flush_batches() -> void:
	for b in batches.values():
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=b.mesh
		mm.instance_count=b.transforms.size()
		for i in b.transforms.size(): mm.set_instance_transform(i,b.transforms[i])
		var instance:=MultiMeshInstance3D.new()
		instance.multimesh=mm
		instance.material_override=b.material
		if b.material==mats.ground or b.material is ShaderMaterial and b.material.shader==mats.paving.shader:
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.parent.add_child(instance)
	batches.clear()

func asset(name: String,pos: Vector3,angle := 0.0,size := Vector3.ONE) -> Node3D:
	var model: Node3D=load(MODULES+name+".glb").instantiate()
	model.name=name
	model.position=pos
	model.rotation.y=angle
	model.scale=size
	world.add_child(model)
	return model

func make_layout() -> void:
	for area in AREAS:
		var rect: Rect2=area[1]
		for x in range(int(rect.position.x/2),int(rect.end.x/2)):
			for z in range(int(rect.position.y/2),int(rect.end.y/2)):
				cells[Vector2i(x,z)]=true
	# Ground and ceiling share the same connected footprint. No concealed outer floor.
	for c: Vector2i in cells.keys():
		if c.y < -34 and (c.x < -1 or c.x > 4):cells.erase(c)
	var rock_scene: Node3D=load(MODULES+"rock.glb").instantiate()
	var rock_mesh: MeshInstance3D=rock_scene.find_children("*","MeshInstance3D",true,false)[0]
	rubble_mesh=rock_mesh.mesh
	batches["ceiling_rock"]={"mesh":rock_mesh.mesh,"material":mats.bedrock,"transforms":[],"parent":roof}
	for cell: Vector2i in cells:
		var p:=Vector3(cell.x*2+1,0,cell.y*2+1)
		block("floor",p-Vector3(0,.2,0),Vector3(2,.4,2),mats.ground)
		bounds_box(p-Vector3(0,.25,0),Vector3(2,.5,2))
		block("roof",p+Vector3(0,7,0),Vector3(2,1,2),mats.ground,0,roof)
		if (cell.x+cell.y)%2==0:
			batches.ceiling_rock.transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3(4,1.8,4)),p+Vector3(0,6.8,0)))
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if cells.has(cell+d): continue
			var edge:=p+Vector3(d.x,0,d.y)
			var size:=Vector3(.45,7,2.05) if d.x else Vector3(2.05,7,.45)
			var solid_size:=Vector3(1.3,7,2.05) if d.x else Vector3(2.05,7,1.3)
			bounds_box(edge+Vector3(0,3.5,0),solid_size)
	rock_scene.free()
	SURFACES.cave(cells,shell,mats.bedrock)

func boulder(pos: Vector3,size: Vector3,solid := true) -> void:
	if not batches.has("rubble"):
		batches.rubble={"mesh":rubble_mesh,"material":mats.bedrock,"transforms":[],"parent":world}
	batches.rubble.transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(size),pos))
	if solid:bounds_box(pos,Vector3(size.x*.60,size.y*.9,size.z*.60))

func lamp(pos: Vector3,color := Color(1,.62,.30),power := 2.0,reach := 8.0,shadows := false) -> void:
	asset("lamp",pos)
	var light:=OmniLight3D.new()
	light.position=pos+Vector3(0,0,.22)
	light.light_color=color
	light.light_energy=power
	light.omni_range=reach
	light.omni_attenuation=1.45
	light.shadow_enabled=shadows
	light.shadow_bias=.04
	light.shadow_normal_bias=1.2
	world.add_child(light)

func support(pos: Vector3,width := 1.0) -> void:
	asset("support",pos,0,Vector3(width,1.25,1))
	for side in [-1,1]: bounds_box(pos+Vector3(side*4.5*width,2.2,0),Vector3(.42,4.4,.5))

func track(x: float,from_z: float,to_z: float) -> void:
	for i in range(int((to_z-from_z)/.8)):
		var z:=from_z+i*.8
		block("sleepers",Vector3(x,.065,z),Vector3(1.5,.13,.18),mats.wood,rng.randf_range(-.025,.025))
		for side in [-1,1]: block("rails",Vector3(x+side*.48,.16,z),Vector3(.055,.09,.80),mats.iron)

func marker(pos: Vector3,label: String,text: String,kind := "story") -> void:
	markers.append({"pos":pos,"label":label,"text":text,"kind":kind})

func buried_paving() -> void:
	var noise:=FastNoiseLite.new()
	noise.seed=871
	noise.frequency=.28
	for variant in range(10):
		var scene: Node3D=load(MODULES+"paver_%02d.glb"%variant).instantiate()
		var mesh: Mesh=scene.find_children("*","MeshInstance3D",true,false)[0].mesh
		var mat: ShaderMaterial=mats.paving.duplicate()
		mat.set_shader_parameter("tone",.90+variant*.022)
		batches["flags_%d"%variant]={"mesh":mesh,"material":mat,"transforms":[],"parent":world}
		scene.free()
	for x in range(-11,11):
		for row in range(-57,-25):
			var z:=row*.60
			var px:=x+(row%2)*.47
			var age:=noise.get_noise_2d(px,z)
			var edge:=Vector2((px-.2)/10.5,(z+24)/10.8).length()
			var density:=clampf(1.3-edge+age*.65,.02,.94)
			if rng.randf()>density:continue
			var variant:=rng.randi_range(0,9)
			var rot:=Vector3(rng.randf_range(-.08,.08),rng.randf_range(-.15,.15),rng.randf_range(-.05,.05))
			var size:=Vector3(rng.randf_range(.87,1.03),.48,rng.randf_range(.82,1.04))
			var pos:=Vector3(px+rng.randf_range(-.04,.04),rng.randf_range(-.032,.014),z+rng.randf_range(-.03,.03))
			batches["flags_%d"%variant].transforms.append(Transform3D(Basis.from_euler(rot).scaled(size),pos))
	# Shallow scalloped deposits physically veil groups of flagstones and soften their edges.
	for data in [[Vector3(-7.8,0,-22),Vector2(3.7,6.0),.15],[Vector3(7.5,0,-20),Vector2(3.9,4.8),.13],[Vector3(-4,0,-29.6),Vector2(4.8,2.5),.14],[Vector3(3.0,0,-25.6),Vector2(2.5,1.4),.08],[Vector3(0,0,-15.2),Vector2(3.2,2.8),.07]]:
		SURFACES.drift(world,mats.ground,data[0],data[1],data[2],rng.randi())

func sorting_hall() -> void:
	buried_paving()
	asset("sorting_machine",Vector3(-3,0,-24))
	bounds_box(Vector3(-3,1.15,-24),Vector3(3.8,2.3,2.7))
	bounds_box(Vector3(-.85,.95,-24),Vector3(.65,1.9,1.6))
	for x in [-3.9,-2.1]:bounds_box(Vector3(x,.7,-22.15),Vector3(.82,1.4,1.4))
	asset("cart",Vector3(-3,0,-20.7),PI/2)
	bounds_box(Vector3(-3,.6,-20.7),Vector3(1.9,1.2,1.45))
	marker(Vector3(-.35,0,-22),"Read the screening plate","Separate the living ore from the dead stone. Even the smallest fragments were counted.")
	marker(Vector3(-3,0,-18.9),"Inspect the collection cart","The screen is clogged. A final cart of worthless shale was left beneath it.")
	# Retaining walls are grounded in collapse fans against the actual excavation boundary.
	for data in [[Vector3(-10.4,0,-22),PI/2],[Vector3(-4.5,0,-32.4),0],[Vector3(10.4,0,-26),-PI/2]]:
		asset("retaining_remnant",data[0],data[1])
		var body:=StaticBody3D.new()
		body.position=data[0]+Vector3(0,.8,0)
		body.rotation.y=data[1]
		var shape:=CollisionShape3D.new()
		var box:=BoxShape3D.new()
		box.size=Vector3(6.7,1.6,1.1)
		shape.shape=box
		body.add_child(shape)
		world.add_child(body)
	for data in [[Vector3(-10.7,0,-23),Vector2(2.2,5.1),.85],[Vector3(-5,0,-32.1),Vector2(4.7,2.4),.80],[Vector3(10.5,0,-27),Vector2(2.1,4.5),.75]]:
		SURFACES.drift(world,mats.ground,data[0],data[1],data[2],rng.randi())
		for i in range(20):
			var a:=rng.randf()*TAU
			var t:=rng.randf_range(.2,.93)
			var pos: Vector3=data[0]+Vector3(cos(a)*data[1].x*t,0,sin(a)*data[1].y*t)
			pos.y=data[2]*pow(1-t*t,2)-.06
			var size:=rng.randf_range(.22,.7)
			boulder(pos,Vector3(size,size*.65,size*.83),false)
	# Incoming rails connect the chamber to both galleries and terminate at the loading point.
	track(0,-19,-13)
	track(7,-34,-27)
	asset("cart",Vector3(7,0,-29.5))
	bounds_box(Vector3(7,.65,-29.5),Vector3(1.45,1.3,1.9))
	asset("crates",Vector3(8.6,0,-31.7),PI/2)
	bounds_box(Vector3(8.6,.4,-31.7),Vector3(.7,.8,2))
	for i in range(80):
		var p:=Vector3(rng.randf_range(-9,9),.01,rng.randf_range(-32,-16))
		var size:=rng.randf_range(.06,.18)
		boulder(p,Vector3(size,size*.5,size*.8),false)
	for p in [Vector3(-7.5,2.2,-25),Vector3(7.6,2.2,-32),Vector3(-3.7,2.5,-31.8)]:
		# Lamps hang from supported timber posts, not thin air beside removed facades.
		block("lamp_posts",Vector3(p.x,p.y*.5,p.z),Vector3(.16,p.y,.16),mats.wood)
		block("lamp_bases",Vector3(p.x,.1,p.z),Vector3(.4,.2,.4),mats.stone)
		bounds_box(Vector3(p.x,p.y*.5,p.z),Vector3(.22,p.y,.22))
		lamp(p,Color(1,.67,.36),1.7,10,p.x < -7)

func decorate() -> void:
	var portal: Node3D=load(ROOT+"portal_frame.glb").instantiate()
	portal.position=Vector3(0,0,14)
	portal.rotation.y=PI
	world.add_child(portal)
	for x in [-1.85,1.85]:bounds_box(Vector3(x,2,14),Vector3(.9,4,1.1))
	var veil:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(2.85,3.55)
	veil.mesh=quad
	veil.position=Vector3(0,1.79,13.94)
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode unshaded,cull_disabled;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float arch=length(vec2(p.x,max(0.0,-p.y*1.25-.23)));
 if(arch>.99)discard;
 float ripple=sin(UV.y*19.0+sin(UV.x*12.0+TIME*.4)-TIME*.5)*.5+.5;
 ALBEDO=mix(vec3(.03,.09,.11),vec3(.25,.47,.45),ripple*.25+pow(arch,12.0)*.65);
}
"""
	var m:=ShaderMaterial.new()
	m.shader=shader
	veil.material_override=m
	world.add_child(veil)
	marker(Vector3(0,0,12),"Finish the walkthrough","The threshold marks the return route.","return")
	asset("crates",Vector3(-3.5,0,10))
	bounds_box(Vector3(-3.5,.4,10),Vector3(2,.8,.65))
	marker(Vector3(-3.5,0,9),"Read the abandoned manifest","The last shipment: grain, lamp oil, six breathing filters. No payment recorded.")
	support(Vector3(0,0,3),.58)
	track(0,-13,3)
	for z in [-2,-9]:
		support(Vector3(0,0,z),.63)
		lamp(Vector3(-2.9,2.85,z+.3))
	lamp(Vector3(3.2,2.6,8),Color(.35,.65,.65),1.6,10)
	sorting_hall()
	for z in [-37,-44,-49]:
		support(Vector3(7,0,z),.78)
		lamp(Vector3(3.5,2.9,z),Color(1,.52,.25),2,9)
	track(7,-51,-34)
	asset("cart",Vector3(9.2,0,-42),-.08)
	bounds_box(Vector3(9.2,.65,-42),Vector3(1.5,1.3,1.9))
	asset("crates",Vector3(3.3,0,-46),PI/2)
	bounds_box(Vector3(3.3,.4,-46),Vector3(.7,.8,2))
	marker(Vector3(9.2,0,-40.7),"Read the shift ledger","Three shifts became two. Then one. The quotas beside them kept rising.")
	# Terminal cavern holds surviving mineral ecology. There is no boss.
	track(7,-58,-52)
	for data in [[Vector3(-3.4,.5,-64),Vector3(3,1.0,3.2)],[Vector3(10.7,.7,-66),Vector3(3.4,1.4,4)],[Vector3(7.8,2.4,-67.5),Vector3(3.3,5.5,3.1)],[Vector3(-2.6,2,-57.8),Vector3(2.7,4.7,3.5)]]:
		boulder(data[0],data[1])
	for i in range(40):
		var side: int=-1 if i%2==0 else 1
		var pos:=Vector3(-3.6 if side<0 else 11.7,.06,rng.randf_range(-65,-55))
		pos.x+=rng.randf_range(-.45,.45)
		var size:=rng.randf_range(.25,.65)
		boulder(pos,Vector3(size,size*.55,size),false)
	for data in [[Vector3(-3.3,0,-64),.3],[Vector3(10.3,0,-67),PI],[Vector3(4,0,-69.9),PI/2]]:
		asset("seam",data[0],data[1])
		bounds_box(data[0]+Vector3(0,.5,0),Vector3(1.4,1,1.5))
		lamp(data[0]+Vector3(0,1.6,.2),Color(.23,.76,.67),1.5,8)
		marker(data[0]+Vector3(0,0,1.7),"Study the living seam","Life still moves beneath the stone. Taking too much would leave only another empty wall.","seam")
	for p in [Vector3(-3.7,0,-58),Vector3(11,0,-59),Vector3(1,0,-69)]:
		asset("roots",p,0,Vector3(2,2,2))
	for z in [-5,-20,-38,-53]:lamp(Vector3(-14.7,2.7,z),Color(.7,.57,.32),1.1,8)
	marker(Vector3(-14,0,-34),"Read the service marker","Maintenance passage. The faded arrows still point toward the threshold.")
	# Keep the original three indices stable for existing expedition saves.
	warden(Vector3(3,0,-19),Vector3(5,0,-19),"Sorting watch")
	warden(Vector3(7,0,-47),Vector3(7,0,-49),"Haulage watch")
	warden(Vector3(6,0,-60),Vector3(6,0,-62),"Seam watch")
	warden(Vector3(7,0,-25),Vector3(3,0,-23),"Sorting patrol")
	warden(Vector3(-7,0,-29),Vector3(-4,0,-27),"Screening watch")
	warden(Vector3(5,0,-38),Vector3(5,0,-35),"Loading watch")
	warden(Vector3(5,0,-44),Vector3(7,0,-42),"Haulage patrol")
	warden(Vector3(0,0,-65),Vector3(4,0,-62),"Vein patrol")

func warden(pos: Vector3,target: Vector3,label: String) -> void:
	var model: Node3D=load(ROOT+"warden.glb").instantiate()
	model.position=pos
	world.add_child(model)
	var animation: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	for clip in animation.get_animation_list():
		animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		if clip.ends_with("villager_idle"):animation.play(clip)
	# Static actor collisions keep the review honest about occupied space.
	var body:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.34
	capsule.height=1.8
	shape.shape=capsule
	shape.position.y=.9
	body.add_child(shape)
	model.add_child(body)
	var skeleton: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
	var mount:=BoneAttachment3D.new()
	mount.bone_name="Chest"
	skeleton.add_child(mount)
	var blade: Node3D=load(ROOT+"mining_blade.glb").instantiate()
	mount.add_child(blade)
	blade.transform=skeleton.get_bone_global_rest(skeleton.find_bone("Chest")).affine_inverse()*Transform3D(Basis(Vector3.FORWARD,PI+.25),Vector3(.06,1.48,-.25))
	model.rotation.y=atan2(target.x-pos.x,target.z-pos.z)
	defenders.append({"pos":pos,"label":label,"model":model,"collider":body,"animation":animation})
	if not embedded: markers.append({"pos":pos,"label":label,"text":"A local defender guards this part of the works.","kind":"warden"})

func setup_light() -> void:
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.022,.035,.037)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.64,.65,.60)
	env.environment.ambient_light_energy=.65
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	cave_environment=env.environment
	add_child(env)
	ceiling_light=DirectionalLight3D.new()
	ceiling_light.rotation_degrees=Vector3(-58,-25,0)
	ceiling_light.light_color=Color(.48,.64,.63)
	ceiling_light.light_energy=.5
	ceiling_light.shadow_enabled=true
	ceiling_light.directional_shadow_max_distance=40
	add_child(ceiling_light)

func setup_player() -> void:
	for name in ["left","right","up","down","run"]:
		if not InputMap.has_action(name):InputMap.add_action(name)
	var keys:={"left":KEY_A,"right":KEY_D,"up":KEY_W,"down":KEY_S,"run":KEY_SHIFT}
	for name in keys:
		var event:=InputEventKey.new()
		event.physical_keycode=keys[name]
		InputMap.action_add_event(name,event)
	player=preload("res://scripts/player.gd").new()
	player.game=self
	player.position=SPAWN
	add_child(player)
	player.last_safe=SPAWN
	camera=Camera3D.new()
	camera.near=.06
	camera.far=160
	add_child(camera)
	camera.make_current()
	update_camera(1.0)

func setup_overlay() -> void:
	var canvas:=CanvasLayer.new()
	add_child(canvas)
	heading=Label.new()
	heading.position=Vector2(30,24)
	heading.add_theme_font_size_override("font_size",25)
	heading.modulate=Color(.85,.76,.56)
	canvas.add_child(heading)
	caption=Label.new()
	caption.position=Vector2(32,62)
	caption.text="Environment walkthrough • Combat available in the main game • No boss"
	canvas.add_child(caption)
	prompt=Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	prompt.position=Vector2(32,-96)
	prompt.add_theme_font_size_override("font_size",18)
	canvas.add_child(prompt)
	var controls:=Label.new()
	controls.text="WASD  Move    Shift  Run    E  Inspect    V  First person / overhead    Esc  Release mouse / close"
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position=Vector2(32,-34)
	canvas.add_child(controls)

func update_camera(delta: float) -> void:
	shell.scale.y=1.0 if first_person else .42
	ceiling_light.light_energy=0.0 if first_person else .5
	cave_environment.ambient_light_energy=.80 if first_person else .65
	if first_person:
		camera.projection=Camera3D.PROJECTION_PERSPECTIVE
		camera.fov=76
		camera.position=player.position+Vector3(0,1.62,0)
		camera.rotation=Vector3(pitch,yaw,0)
	else:
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=18
		var target:=player.position+Vector3(0,.65,0)
		camera.position=camera.position.lerp(target+Vector3(9,14,12),minf(delta*8,1))
		camera.look_at(target)

func _process(delta: float) -> void:
	if embedded:return
	reading=maxf(0,reading-delta)
	update_camera(delta)
	var area_name:="THE SPENT WORKS"
	for area in AREAS:
		if area[1].has_point(Vector2(player.position.x,player.position.z)):
			area_name=area[0]
			break
	heading.text=area_name
	active_marker=-1
	var nearest:=2.5
	for i in markers.size():
		var d: float=player.position.distance_to(markers[i].pos)
		if d<nearest:
			nearest=d
			active_marker=i
	if reading<=0:
		prompt.text="E  "+str(markers[active_marker].label) if active_marker>=0 else ""

func _unhandled_input(event: InputEvent) -> void:
	if embedded:return
	if event is InputEventMouseButton and event.pressed and first_person:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and first_person and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		yaw-=event.relative.x*.0025
		pitch=clampf(pitch-event.relative.y*.0025,-1.35,1.15)
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_V:
			first_person=not first_person
			player.model.visible=not first_person
			roof.visible=first_person
			yaw=0
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if first_person else Input.MOUSE_MODE_VISIBLE
		KEY_E:
			if active_marker<0:return
			var entry:=markers[active_marker]
			if entry.kind=="return":
				get_tree().quit()
			else:
				prompt.text=entry.text
			reading=6
		KEY_ESCAPE:
			if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
			else:get_tree().quit()

func check_route() -> void:
	await get_tree().physics_frame
	assert(shell.get_node_or_null("ContinuousExcavatedBanks")!=null,"Cave geometry must have built successfully")
	assert(shell.get_node_or_null("UnexcavatedBedrock")!=null,"Cave needs a solid surrounding mass")
	assert(world.get_node_or_null("sorting_machine")!=null,"Sorting hall needs its machinery")
	assert(not world.find_children("DepositedSilt*","MeshInstance3D",true,false).is_empty(),"Buried paving needs physical silt dressing")
	var start:=Vector2i(0,5)
	var reached:={start:true}
	var queue: Array[Vector2i]=[start]
	while not queue.is_empty():
		var cell: Vector2i=queue.pop_front()
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if cells.has(cell+d) and not reached.has(cell+d):
				reached[cell+d]=true
				queue.append(cell+d)
	assert(reached.size()==cells.size(),"Every floor region must connect to the threshold")
	assert(cells.has(Vector2i(2,-34)),"Living vein must be reachable")
	assert(cells.has(Vector2i(-7,-20)),"Service return route must exist")
	# Build a second reachability map using the real standing capsule and scene colliders.
	var shape:=CapsuleShape3D.new()
	shape.radius=.28
	shape.height=1.65
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=1
	query.margin=.015
	var walkable:={}
	var space:=get_world_3d().direct_space_state
	for x in range(-31,29):
		for z in range(-143,32):
			var point:=Vector2i(x,z)
			if not cells.has(Vector2i(floori(x*.25),floori(z*.25))):continue
			query.transform=Transform3D(Basis.IDENTITY,Vector3(x*.5,.87,z*.5))
			if space.intersect_shape(query,1).is_empty():walkable[point]=true
	var physical_start:=Vector2i(0,22)
	assert(walkable.has(physical_start),"Spawn capsule must be clear")
	assert(not walkable.has(Vector2i(18,-84)),"Cart must physically obstruct the capsule")
	assert(not walkable.has(Vector2i(-8,-10)),"Tunnel wall must physically obstruct the capsule")
	assert(not walkable.has(Vector2i(-6,-48)),"Screening machinery must physically obstruct the capsule")
	var physical_reached:={physical_start:true}
	queue=[physical_start]
	while not queue.is_empty():
		var cell: Vector2i=queue.pop_front()
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if walkable.has(cell+d) and not physical_reached.has(cell+d):
				physical_reached[cell+d]=true
				queue.append(cell+d)
	for target in [Vector2i(0,-12),Vector2i(2,-42),Vector2i(14,-80),Vector2i(8,-128),Vector2i(-28,-108),Vector2i(-28,8)]:
		assert(physical_reached.has(target),"Player capsule route blocked at "+str(target))
	print("MINE CHECKS COMPLETE: ",cells.size()," connected floor cells; physical capsule reaches all areas and return passage; no combat dependency; no boss")
	get_tree().quit()

func capture() -> void:
	input_blocked=true
	await get_tree().create_timer(2).timeout
	var views:=[Vector3(0,0,7),Vector3(0,0,-22),Vector3(7,0,-42),Vector3(4,0,-63)]
	for i in views.size():
		player.position=views[i]+Vector3(0,.1,0)
		await get_tree().create_timer(.7).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/mine-expanded-%d.png"%(i+1))
	# Wide, rotated views expose any outer edge at the entrance.
	set_process(false)
	for angle in [0.0,PI*.5,PI,PI*1.5]:
		var target:=Vector3(0,.65,11)
		camera.size=55
		camera.position=target+Vector3(0,38,32).rotated(Vector3.UP,angle)
		camera.look_at(target)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/mine-border-%d.png"%roundi(rad_to_deg(angle)))
	set_process(true)
	first_person=true
	roof.show()
	player.model.hide()
	player.position=Vector3(1,.1,-17)
	yaw=.3
	pitch=-.05
	await get_tree().create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/mine-expanded-first-person.png")
	get_tree().quit()

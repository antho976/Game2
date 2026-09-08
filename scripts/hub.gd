class_name HubKit
extends Node3D

var world: HubWorld
var wind_time: float = 0
var trees: Array[Node3D] = []
var smoke: GPUParticles3D
var forge_light: OmniLight3D
var npcs: Array[HubNPC] = []
var landscape: Node3D
var life: Node3D

const SMITH_POINT = Vector3(-6.5,0,4.0)
const ARCHIVE_POINT = Vector3(10,0,-.5)
const GATE_POINT = Vector3(0,0,-13)
const WELL_POINT = Vector3(0,0,.3)
const BATCH_CHUNK = 16.0

func build(target: HubWorld) -> void:
	world = target
	build_ground()
	# A connected square, with residential lanes behind the two working yards.
	asset("cottage",Vector3(-6.5,0,-10),Vector3(4.8,4,4.1))
	asset("townhouse",Vector3(4.6,0,-12.2),Vector3(4.2,4,4.2))
	asset("townhouse",Vector3(-13.1,0,-6.8),Vector3(4.2,4,4.2))
	asset("cottage",Vector3(13.5,0,-11.6),Vector3(4.8,4,4.1))
	asset("smith_workshop",Vector3(-8,0,.2))
	for x in [-10.5,-5.5]:
		for z in [-1.3,1.7]: world.block(Vector3(x,1.5,z),Vector3(.25,3,.25))
	asset("forge",Vector3(-9.2,0,-.6),Vector3(1.6,1.3,1))
	asset("anvil_station",Vector3(-7.4,0,3),Vector3(1.55,.95,.8))
	var smith = npc("blacksmith",Vector3(-7.51,0,2.30))
	smith.name = "WorkingBlacksmith"
	smith.work_struck.connect(sparks)
	smith.work_struck.connect(func(): world.game.play_sound("smith_hammer_anvil",smith.global_position,"smith",.1))
	world.interactions.append({"id":"smith","pos":SMITH_POINT,"text":"Blacksmith · greatswords & armor"})
	asset("research_pavilion",Vector3(10,0,-4))
	for x in [7.75,12.25]:
		for z in [-5.35,-2.65]: world.block(Vector3(x,1.5,z),Vector3(.22,3,.22))
	asset("research_desk",Vector3(10,0,-1.8),Vector3(2.2,1,1.05))
	asset("bookcase",Vector3(9,0,-4.9),Vector3(2.2,2.2,.55))
	world.box(Vector3(12,.48,-2.2),Vector3(.85,.96,.85),world.stone[4],true)
	asset("armillary",Vector3(12,.97,-2.2))
	npc("scholar",Vector3(10,0,-2.5))
	world.interactions.append({"id":"archive","pos":ARCHIVE_POINT,"text":"Research pavilion"})
	var well = asset("village_well",WELL_POINT,Vector3(2.55,1.3,2.3))
	var plushie = preload("res://scripts/pigeon_plushie.gd").new()
	plushie.name = "PigeonPlushie"
	# Coping top is 1.11 m. Sit on the arrival-facing rim, clear of the rope.
	plushie.position = Vector3(0,1.11,.87)
	# Its stitched normal maps rely on per-part tangent space, so it keeps its own meshes.
	plushie.set_meta(StaticBatcher.NO_BATCH,true)
	well.add_child(plushie)
	asset("garden_bench",Vector3(-11.1,0,5.2),Vector3(2,1.2,.7)).rotation.y = .1
	asset("garden_bench",Vector3(7.2,0,12.2),Vector3(2,1.2,.7)).rotation.y = -.25
	# Residents occupy purposeful places; full schedules come in a later pass.
	var gardener = npc("villager",Vector3(11.9,0,7.2))
	gardener.name = "KitchenGardener"
	gardener.variant = 2
	gardener.apply_variation()
	gardener.rotation.y = -.7
	var neighbors = [Vector3(-4,0,-5.7),Vector3(-2.8,0,-5.9)]
	for i in neighbors.size():
		var resident = npc("villager",neighbors[i])
		resident.name = "Neighbors%d" % i
		resident.variant = 4+i
		resident.apply_variation()
		resident.rotation.y = PI/2 if i == 0 else -PI/2
	for lamp_pos in [Vector3(-4.4,0,-5.5),Vector3(3.1,0,-9),Vector3(-5.8,0,5.7),Vector3(9.6,0,6.7),Vector3(14,0,-3)]:
		asset("street_lantern",lamp_pos)
		var lamp = OmniLight3D.new()
		lamp.position = lamp_pos + Vector3(.43,2.35,0)
		lamp.light_color = Color(1,.66,.29)
		lamp.light_energy = 1.1
		lamp.omni_range = 5
		lamp.shadow_enabled = true
		add_child(lamp)
	build_boundaries()
	var keeper = npc("villager",Vector3(1.15,0,-11.8))
	keeper.name = "Gatekeeper"
	world.interactions.append({"id":"enter","pos":Vector3(0,0,-11.2),"text":"The northern road"})
	build_gateway()
	setup_forge()
	landscape = preload("res://scripts/hub_landscape.gd").new()
	landscape.name = "Landscape"
	add_child(landscape)
	landscape.build(self)
	var dressing := preload("res://scripts/hub_dressing.gd").new()
	add_child(dressing)
	dressing.build(self)
	life = preload("res://scripts/hub_life.gd").new()
	life.name = "VillageLife"
	add_child(life)
	life.build(self)
	# Thousands of rigid flowers, stones, shrubs and small props become a few ground-grid
	# batches per material. Trees, residents, animals and effects are left as they are.
	StaticBatcher.merge(self,BATCH_CHUNK)

func on_path(p: Vector2) -> bool:
	var square: bool = Vector2(p.x/5.4,(p.y-.5)/5.8).length() < 1
	var road: bool = absf(p.x - (.45*sin(p.y*.32) if p.y > 5 else 0.0)) < 1.55 and p.y > -14.7 and p.y < 16
	var work_lane: bool = absf(p.y-3.4) < 1.25 and absf(p.x) < 11
	var research_lane: bool = p.distance_to(Vector2(10,-.8)) < 2.5 or (p.x > 5 and p.x < 11 and absf(p.y+1.0) < .9)
	var home_lane: bool = absf(p.y+5.2) < 1.15 and absf(p.x) < 14.4
	var doorstep: bool = false
	for center in [Vector2(-6.5,-10),Vector2(4.6,-12.2),Vector2(-13.1,-6.8),Vector2(13.5,-11.6)]:
		doorstep = doorstep or (absf(p.x-center.x+.65) < 1.0 and p.y > center.y+1.5 and p.y < -4.4)
	var yard: bool = (absf(p.x+8) < 2.85 and absf(p.y-.8) < 3.2) or (absf(p.x-10) < 2.8 and absf(p.y+3.3) < 2.6)
	var dock_lane: bool = p.x > -9.7 and p.x < -5.5 and absf(p.y-8.2) < .85
	var west_door: bool = absf(p.x+13.75) < 1.05 and p.y > -5.3 and p.y < 4.9
	var pond_walk: bool = p.distance_to(Vector2(-11.1,5.0)) < 1.5 or (p.x > -12.2 and p.x < -8 and absf(p.y-4.7) < .7)
	var practice: bool = p.distance_to(Vector2(9.5,8)) < 3.1 or (absf(p.x-7.2) < .85 and p.y > 3.4 and p.y < 10.5)
	return (p.distance_to(Vector2(7.2,11.3)) < 1.2) or dock_lane or west_door or research_lane or square or road or work_lane or home_lane or doorstep or yard or pond_walk or practice

func build_ground() -> void:
	var soil = world.rough_material(Color(.30,.36,.20))
	world.box(Vector3(0,-.24,0),Vector3(110,.48,100),soil,true)
	var palette: Array[StandardMaterial3D] = []
	for color in [Color(.39,.37,.30),Color(.44,.42,.36),Color(.34,.35,.31),Color(.48,.43,.35),Color(.37,.39,.33),Color(.43,.39,.32),Color(.32,.34,.30),Color(.49,.47,.4)]:
		palette.append(world.rough_material(color))
	# Shared geometry batches keep the smaller, irregular cobbles inexpensive.
	var batches: Array[Array] = []
	for i in palette.size(): batches.append([])
	var rng = RandomNumberGenerator.new()
	rng.seed = 193
	for row in range(-45,45):
		for col in range(-39,40):
			var p = Vector2(col*.49+(row%2)*.245,row*.36)
			if not on_path(p): continue
			if rng.randf() < .025: continue
			var size = Vector3(rng.randf_range(.39,.46),rng.randf_range(.035,.06),rng.randf_range(.27,.335))
			var basis = Basis(Vector3.UP,rng.randf_range(-.09,.09)).scaled(size)
			batches[rng.randi_range(0,palette.size()-1)].append(Transform3D(basis,Vector3(p.x+rng.randf_range(-.014,.014),.014,p.y)))
	for i in palette.size():
		var batch = MultiMeshInstance3D.new()
		batch.name = "VillageCobbles%d" % i
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = world.beveled_box
		batch.multimesh.instance_count = batches[i].size()
		batch.material_override = palette[i]
		for j in batches[i].size(): batch.multimesh.set_instance_transform(j,batches[i][j])
		add_child(batch)

func asset(id: String, pos: Vector3, collider: Vector3 = Vector3.ZERO) -> Node3D:
	var instance: Node3D = load("res://assets/hub/"+id+".glb").instantiate()
	instance.name = id
	instance.position = pos
	add_child(instance)
	if collider != Vector3.ZERO:
		world.block(pos+Vector3(0,collider.y*.5,0),collider)
	return instance

func npc(profession: String, pos: Vector3) -> HubNPC:
	var person = HubNPC.new()
	person.profession = profession
	person.position = pos
	person.variant = npcs.size()
	add_child(person)
	npcs.append(person)
	return person

func setup_forge() -> void:
	forge_light = OmniLight3D.new()
	forge_light.position = Vector3(-9.2,1,-.3)
	forge_light.light_color = Color(1,.31,.075)
	forge_light.light_energy = 2.5
	forge_light.omni_range = 4
	add_child(forge_light)
	smoke = GPUParticles3D.new()
	smoke.position = Vector3(-9.2,3.3,-.9)
	smoke.amount = 24
	smoke.lifetime = 3.5
	smoke.visibility_aabb = AABB(Vector3(-3,-1,-3),Vector3(6,8,6))
	var motion = ParticleProcessMaterial.new()
	motion.direction = Vector3(.15,1,0)
	motion.spread = 12
	motion.initial_velocity_min = .45
	motion.initial_velocity_max = .7
	motion.gravity = Vector3(.06,.18,0)
	motion.scale_min = .14
	motion.scale_max = .35
	var gradient = Gradient.new()
	gradient.set_color(0,Color(.36,.35,.33,.15))
	gradient.set_color(1,Color(.45,.43,.39,0))
	var ramp = GradientTexture1D.new()
	ramp.gradient = gradient
	motion.color_ramp = ramp
	smoke.process_material = motion
	var quad = QuadMesh.new()
	quad.size = Vector2(.9,.9)
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Soft radial alpha avoids visible square particle cards.
	var image = Image.create(32,32,false,Image.FORMAT_RGBA8)
	for x in 32:
		for y in 32:
			var distance: float = Vector2(x-15.5,y-15.5).length()/15.5
			image.set_pixel(x,y,Color(1,1,1,pow(maxf(0,1-distance),2)))
	material.albedo_texture = ImageTexture.create_from_image(image)
	quad.material = material
	smoke.draw_pass_1 = quad
	add_child(smoke)

func _process(delta: float) -> void:
	wind_time += delta
	# Swaying re-uploads every mesh of a tree each frame. Trees too far from the view to show
	# on screen, even through a canopy or a long shadow, wait until they can be seen again.
	var focus: Vector3 = world.game.camera_target
	var reach: float = world.game.camera.size*1.5+25.0
	for i in trees.size():
		var tree := trees[i]
		if Vector2(tree.position.x-focus.x,tree.position.z-focus.z).length_squared() > reach*reach: continue
		tree.rotation.z = sin(wind_time*.65+i)*.006
	if forge_light:
		forge_light.light_energy = 2.5+sin(wind_time*8)*.15

func sparks() -> void:
	var particles = GPUParticles3D.new()
	particles.position = Vector3(-7.4,1.09,3)
	particles.amount = 10
	particles.lifetime = .3
	particles.one_shot = true
	particles.explosiveness = 1
	var motion = ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 65
	motion.initial_velocity_min = .7
	motion.initial_velocity_max = 1.4
	motion.gravity = Vector3(0,-4,0)
	motion.scale_min = .6
	motion.scale_max = 1
	particles.process_material = motion
	var sphere = SphereMesh.new()
	sphere.radius = .018
	sphere.height = .04
	sphere.radial_segments = 4
	sphere.rings = 2
	sphere.material = world.game.flat_material(Color(1,.54,.12))
	particles.draw_pass_1 = sphere
	add_child(particles)
	particles.finished.connect(particles.queue_free)

func build_gateway() -> void:
	for side in [-1,1]:
		for tier in 7:
			world.box(Vector3(side*2.1,.28+tier*.5,-14),Vector3(.85,.47,.9),world.stone[tier%6],true)
	world.box(Vector3(0,3.55,-14),Vector3(5.1,.4,1),world.stone[4])
	for i in 7:
		world.box(Vector3((i-3)*.52,1.5,-14),Vector3(.12,3,.12),world.wood)
	world.box(Vector3(0,1.7,-14),Vector3(3.8,.15,.2),world.wood)

func build_boundaries() -> void:
	# Continuous masonry base, overlapping coping, and planted buttresses close corners.
	for side in [-1,1]:
		world.box(Vector3(side*19,.48,-.5),Vector3(.72,.96,32),world.stone[2],true)
	for z in [-16.0,15.0]:
		world.box(Vector3(0,.48,z),Vector3(38.7,.96,.72),world.stone[2],true)
	for side in [-1,1]:
		for i in 33:
			var z := -16.0+i
			world.box(Vector3(side*19,1.02,z),Vector3(.87,.18,1.03),world.stone[i%6])
	for z in [-16.0,15.0]:
		for i in 39:
			world.box(Vector3(-19+i,1.02,z),Vector3(1.03,.18,.87),world.stone[i%6])
	for x in [-19.0,19.0]:
		for z in [-16.0,-8,0,8,15]:
			world.box(Vector3(x,.7,z),Vector3(1.08,1.4,1.08),world.stone[3],true)
			world.box(Vector3(x,1.47,z),Vector3(1.2,.16,1.2),world.stone[5])

	# Exposed courses break up the retaining face; the continuous core carries collision.
	for row in 3:
		for i in 39:
			var x := -18.8+i*.98+(row%2)*.20
			if x>19: continue
			for z in [-16.0,15.0]:
				world.box(Vector3(x,.17+row*.29,z),Vector3(.91,.26,.78),world.stone[(i+row*2)%6])
		for i in 32:
			var z := -15.6+i*.98+(row%2)*.20
			for x in [-19.0,19.0]:
				world.box(Vector3(x,.17+row*.29,z),Vector3(.78,.26,.91),world.stone[(i+row*2)%6])

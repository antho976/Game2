extends Node3D
const POND := Vector3(-12,0,8.7)
var game: Node3D
var points: Array[Dictionary] = []
var ducks: Array[Dictionary] = []
var elapsed := 0.0
var feed_until := 0.0
var duck_food: Array[Vector3] = []
var fed_count := 0
var watered := false
var water_until := 0.0
var bell_time := 0.0
var bell: Node3D
var can: Node3D
var garden_mat: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var water_emitter: GPUParticles3D
var quack_due := 4.0

func asset(id: String,pos: Vector3) -> Node3D:
	var node: Node3D = load("res://assets/village/"+id+".glb").instantiate()
	node.position = pos
	add_child(node)
	return node

func build() -> void:
	rng.seed = 829
	points.append({"id":"pond_sit","pos":Vector3(-11.1,0,4.25),"radius":1.7,"text":"Sit by the pond"})
	points.append({"id":"feed","pos":Vector3(-7.85,0,8.25),"radius":2.0,"text":"Scatter feed for the ducks"})
	for i in 4:
		var duck := CharacterBody3D.new()
		duck.name = "PondDuck%d" % i
		duck.position = POND+Vector3(cos(i*1.7)*1.65,.085,sin(i*1.7)*1.15)
		duck.collision_layer = 16
		duck.collision_mask = 16
		duck.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		add_child(duck)
		var art := asset("mallard",duck.position)
		art.reparent(duck)
		var size := .95 if i==0 else (.65 if i==3 else .83)
		art.scale *= size
		var collider := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = .22*size
		shape.height = .78*size
		collider.shape = shape
		collider.rotation.x = PI/2
		collider.position.y = .22*size
		duck.add_child(collider)
		var head := Node3D.new()
		head.name = "FeedingHeadPivot"
		art.add_child(head)
		head.position = Vector3(0,.20,.22)
		for part in art.find_children("*","MeshInstance3D",true,false):
			if str(part.name).begins_with("DuckNeck") or str(part.name).begins_with("DuckHead") or str(part.name).begins_with("NeckRing") or str(part.name).begins_with("Bill") or str(part.name).begins_with("DuckEye"):
				part.reparent(head)
		var ring := ripple(duck.position,.32,.37)
		ducks.append({"model":duck,"art":art,"head":head,"radius":shape.radius,"phase":float(i)*1.7,"wake":ring,"mode":"swim","fed":false})
	asset("vegetable_bed",Vector3(10,0,8.3))
	asset("vegetable_bed",Vector3(13.3,0,7.8)).rotation.y = .12
	game.world.block(Vector3(10,.18,8.3),Vector3(2.6,.36,1.8))
	game.world.block(Vector3(13.3,.18,7.8),Vector3(2.8,.36,2))
	can = asset("watering_can",Vector3(8.4,.05,8.3))
	game.world.block(Vector3(8.4,.22,8.3),Vector3(.4,.44,.4))

	points.append({"id":"dummy","pos":Vector3(21.5,0,4.2),"radius":1.8,"text":"Test the training dummy"})
	points.append({"id":"sit","pos":Vector3(5.4,0,10.1),"radius":1.7,"text":"Sit for a moment"})
	bell = asset("village_bell",Vector3(1.1,0,-6.4))
	game.world.block(Vector3(1.1,1,-6.4),Vector3(1.1,2,.4))
	points.append({"id":"bell","pos":Vector3(1.1,0,-5.5),"radius":1.8,"text":"Ring the village bell"})
	# Hand-built workyard details break up the empty spaces between larger assets.
	var world = game.world
	for i in 7:
		world.box(Vector3(-10.3,.14+i*.08,2.8),Vector3(1.2,.12,.17),world.wood).rotation.y = .1*(i%3)
	for i in 5:
		var bench = world.box(Vector3(10.1+i*.7,.43,11.4),Vector3(.12,.86,.12),world.wood)
		bench.rotation.z = .04*sin(i)
	world.box(Vector3(11.5,.65,11.4),Vector3(3.5,.10,.10),world.wood)
	world.box(Vector3(11.5,.36,11.4),Vector3(3.5,.10,.10),world.wood)
	world.block(Vector3(11.5,.43,11.4),Vector3(3.6,.86,.18))
	# A washing line between two houses, rather than duplicated street furniture.
	for x in [-10.3,-7.8]: world.box(Vector3(x,1,-5.5),Vector3(.12,2,.12),world.wood,true)
	world.box(Vector3(-9.05,1.85,-5.5),Vector3(2.6,.025,.025),world.wood)
	for i in 4:
		var cloth := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(.42,.62)
		mesh.subdivide_width = 8
		mesh.subdivide_depth = 8
		cloth.mesh = mesh
		cloth.rotation.x = PI/2
		cloth.position = Vector3(-10.05+i*.6,1.54,-5.5)
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode cull_disabled; uniform vec4 tint:source_color; void vertex(){float free_edge=UV.y; VERTEX.y+=(sin(TIME*1.8+VERTEX.x*5.0)*.12+sin(TIME*2.9+VERTEX.z*9.0)*.035)*free_edge*free_edge;} void fragment(){ALBEDO=tint.rgb;ROUGHNESS=.95;}"
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tint",[Color(.64,.57,.4),Color(.23,.35,.4),Color(.47,.28,.18),Color(.70,.66,.5)][i])
		cloth.material_override = mat
		add_child(cloth)
		for dx in [-.14,.14]: world.box(Vector3(-10.05+i*.6+dx,1.85,-5.5),Vector3(.04,.08,.045),world.wood)


func ripple(pos: Vector3,inner: float,outer: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 4
	node.mesh = mesh
	node.position = Vector3(pos.x,.102,pos.z)
	node.scale = Vector3(1,.08,1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.48,.63,.47,.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	add_child(node)
	return node

func _physics_process(delta: float) -> void:
	elapsed += delta
	for duck in ducks:
		var angle: float = elapsed*.11+duck.phase
		var target := POND+Vector3(cos(angle)*1.85,.085,sin(angle)*1.2)
		duck.mode = "swim"
		if elapsed < feed_until:
			target = duck_food[ducks.find(duck)%duck_food.size()] if not duck_food.is_empty() else POND+Vector3(1.7+cos(duck.phase)*.45,.085,sin(duck.phase)*.8)
			duck.mode = "feeding"
		else:
			var away: Vector3 = duck.model.position-game.player.position
			away.y = 0
			if away.length() < 2.2:
				target += away.normalized()*.5
				duck.mode = "avoid"
		var direction: Vector3 = target-duck.model.position
		direction.y = 0
		var feeding: bool = duck.mode=="feeding" and direction.length()<.6
		var velocity := direction.normalized()*minf(.65,direction.length()*2)
		for other in ducks:
			if other==duck: continue
			var away: Vector3 = duck.model.position-other.model.position
			away.y = 0
			var clearance: float = duck.radius+other.radius+.28
			if away.length()<clearance:
				velocity += away.normalized()*(clearance-away.length())*2
		duck.model.velocity = duck.model.velocity.move_toward(velocity,delta*1.5)
		duck.model.move_and_slide()
		# Paddling is a loop that rides on the wake: audible while the duck actually moves.
		var paddle_key: String = "paddle:"+str(duck.model.get_instance_id())
		if duck.model.velocity.length() > .18: game.audio.loop(paddle_key,"duck_paddle",Vector3(0,.1,0),-26,{"bus":"SFX","max_distance":9,"fade_in":true,"parent":duck.model})
		else: game.audio.stop(paddle_key,.8)
		if duck.model.velocity.length()>.08:
			duck.model.rotation.y = lerp_angle(duck.model.rotation.y,atan2(duck.model.velocity.x,duck.model.velocity.z),delta*2.5)
		duck.art.position.y = sin(elapsed*2+duck.phase)*.013
		duck.art.rotation.z = sin(elapsed*2+duck.phase)*.025
		var dip: float = .9+.42*(.5+.5*sin(elapsed*7+duck.phase)) if feeding else 0.0
		duck.head.rotation.x = lerpf(duck.head.rotation.x,dip,minf(delta*8,1))
		if duck.mode == "avoid" and not duck.get("alarmed",false):
			game.audio.play("duck_avoid",duck.model.position,-16,{"cooldown":1.5})
		duck.alarmed = duck.mode == "avoid"
		if feeding and rng.randf() < delta*.5: game.audio.play("duck_dabble",duck.model.position,-20,{"cooldown":.6})
		duck.fed = feeding
		duck.wake.position = Vector3(duck.model.position.x,.102,duck.model.position.z)
		var size := .85+sin(elapsed*1.4+duck.phase)*.12
		duck.wake.scale = Vector3(size,.08,size*.75)
	# A quack now and then from whichever duck is furthest from the last one.
	quack_due -= delta
	if quack_due <= 0:
		quack_due = rng.randf_range(5,14)
		var duck: Dictionary = ducks[rng.randi_range(0,ducks.size()-1)]
		var size: float = duck.art.scale.x
		game.audio.play("duck_quack",duck.model.position,-16,{"pitch":1.15-size*.35,"pitch_spread":.04})
	if bell_time > 0:
		bell_time -= delta
		# Gentle swing of the authored cup; posts stay planted.
		var cups := bell.find_children("BellCup","Node3D",true,false)
		if not cups.is_empty(): cups[0].rotation.z = sin(elapsed*13)*.10*minf(bell_time,1)
	if elapsed < water_until:
		var skeleton: Skeleton3D = game.player.model.find_children("*","Skeleton3D",true,false)[0]
		var hand := skeleton.find_bone("Hand.R")
		can.rotation.z = -.65
		can.global_position = skeleton.global_transform*skeleton.get_bone_global_pose(hand).origin-can.global_basis*Vector3(-.29,.25,0)
		if is_instance_valid(water_emitter): water_emitter.global_position = can.global_transform*Vector3(.43,.4,0)
	else:
		can.position = can.position.lerp(Vector3(8.4,.05,8.3),delta*5)
		can.rotation.z = lerpf(can.rotation.z,0,delta*5)

func interact(id: String) -> void:
	match id:
		"dummy":
			game.kit.practice_dummy.strike()
			game.audio.play("dummy_hit",game.kit.practice_dummy.position+Vector3.UP,-8)
			game.audio.play("dummy_swing",game.kit.practice_dummy.position+Vector3.UP,-20,{"cooldown":1.0})
			game.toast("Ready for greatsword practice, once you have a blade.")
		"feed":
			if elapsed < feed_until:
				game.toast("They are still enjoying the last handful.")
				return
			feed_until = elapsed+16
			fed_count += 1
			game.player.act("feed",POND,1.3)
			game.audio.play("feed_grab",game.player.position+Vector3.UP,-16)
			throw_feed(game.player, POND+Vector3(1.7,.12,0))
			game.toast("The ducks paddle over for a closer look.")
			for i in 8:
				var ring := ripple(POND+Vector3(1.7+rng.randf_range(-.3,.3),0,rng.randf_range(-.6,.6)),.04,.06)
				var tween := create_tween()
				tween.tween_property(ring,"scale",Vector3(5,.08,5),1.8)
				tween.tween_callback(ring.queue_free)
		"water":
			if watered:
				game.toast("The soil is still damp. Let it soak in.")
				return
			watered = true
			water_until = elapsed+3
			game.player.act("water",Vector3(10,0,8.3),3)
			game.toast("A little care for tomorrow's supper.")
			game.audio.play("water_can_lift",can.position+Vector3.UP*.3,-14)
			water_particles()
		"pond_sit":
			game.player.act("sit",Vector3(-12.0,0,8.7),0)
			game.player.position = Vector3(-11.1,.02,5.2)
			game.toast("A moment beside the water.")
		"sit":
			game.player.act("sit",Vector3(5.4,0,8),0)
			game.player.position = Vector3(5.4,.02,11.0)
			game.toast("Stay a while. Move when you are ready.")
		"bell":
			bell_time = 3.0
			game.audio.play("bell_rope",bell.position+Vector3.UP,-16)
			game.toast("The sound carries across the square.")
			for animal in game.kit.life.animals:
				if animal.kind == "bird": game.kit.life.begin_flight(animal,game.player.position)
			bell_sound()

func water_particles() -> void:
	var particles := GPUParticles3D.new()
	water_emitter = particles
	particles.position = Vector3(9.45,.88,8.25)
	particles.amount = 65
	particles.lifetime = .55
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3(.3,-1,0)
	motion.spread = 10
	motion.initial_velocity_min = .5
	motion.initial_velocity_max = .9
	motion.gravity = Vector3(0,-2,0)
	motion.scale_min = .015
	motion.scale_max = .025
	particles.process_material = motion
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = game.flat_material(Color(.48,.69,.74))
	particles.draw_pass_1 = mesh
	add_child(particles)
	var key := "pour:"+str(particles.get_instance_id())
	game.audio.loop(key,"water_pour",Vector3(9.45,.6,8.25),-16,{"bus":"SFX","max_distance":10,"fade_in":true,"fade":.25})
	get_tree().create_timer(3.0).timeout.connect(func():
		game.audio.stop(key,.5)
		game.audio.play("water_can_set",Vector3(8.4,.3,8.3),-18,{"cooldown":.5}))
	get_tree().create_timer(3.6).timeout.connect(particles.queue_free)

func bell_sound() -> void:
	if game.muted or game.test_mode: return
	if game.audio.has("bell_ring"):
		game.audio.play("bell_ring",bell.position+Vector3.UP*1.7,-6,{"max_distance":45,"unit_size":6,"pitch_spread":.01})
		return
	var data := PackedByteArray()
	data.resize(44100*3*2)
	for i in 44100*3:
		var t := float(i)/44100.0
		var sample := (sin(t*TAU*660)*exp(-t*1.6)+sin(t*TAU*1325)*exp(-t*2.8)*.35+sin(t*TAU*1830)*exp(-t*4)*.15)*.13
		data.encode_s16(i*2,int(sample*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.data = data
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.position = bell.position+Vector3.UP*1.7
	audio.max_distance = 40
	audio.volume_db = -10
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

var feed_releases := 0
var water_draws := 0
func throw_feed(person: Node3D,target: Vector3) -> void:
	# Release on the extension of the authored throw, not at the beginning of the gesture.
	await get_tree().create_timer(.5).timeout
	if not is_instance_valid(person): return
	var source: Node3D = person.model
	if person==game.player and game.camera_mode==1:
		source = game.camera.get_node("FirstPersonHands").arms
	var skeletons = source.find_children("*","Skeleton3D",true,false)
	var start: Vector3 = person.global_position+Vector3(0,1,0)
	if not skeletons.is_empty():
		var skeleton: Skeleton3D = skeletons[0]
		start = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Hand.R")).origin
	feed_releases += 1
	game.audio.play("feed_throw",start,-16)
	var spots: Array[Vector3] = []
	var for_ducks := Vector2(target.x-POND.x,target.z-POND.z).length()<3.7
	var mesh := SphereMesh.new()
	mesh.radius = .035
	mesh.height = .04
	mesh.radial_segments = 5
	mesh.rings = 2
	var material = game.flat_material(Color(.78,.59,.28))
	for i in 14:
		var seed := MeshInstance3D.new()
		seed.name = "ThrownFeed"
		seed.mesh = mesh
		seed.material_override = material
		add_child(seed)
		var angle := (i%4)*TAU/4
		var end: Vector3 = target+Vector3(cos(angle)*.55,0,sin(angle)*.55)
		if i>=4: end += Vector3(rng.randf_range(-.12,.12),0,rng.randf_range(-.12,.12))
		spots.append(end)
		var tween := create_tween()
		tween.tween_method(func(t: float): seed.global_position = start.lerp(end,t)+Vector3.UP*sin(t*PI)*.45,0.0,1.0,.65+rng.randf()*.2)
		tween.tween_interval(18)
		tween.tween_property(seed,"scale",Vector3.ZERO,.5)
		tween.tween_callback(seed.queue_free)

	await get_tree().create_timer(.85).timeout
	game.audio.play("feed_land_water" if for_ducks else "feed_land_ground",target,-16)
	if for_ducks:
		if elapsed >= feed_until-.5: game.audio.play("duck_gather",POND+Vector3(1.7,.1,0),-12,{"cooldown":6.0})
		duck_food.assign(spots.slice(0,4))
		feed_until = elapsed+18
	elif target.distance_to(game.village_day.stations.birds+Vector3(0,.06,1.2))<1:
		game.kit.life.offer_bird_food(spots)

func draw_water(person: Node3D, carried: Node3D) -> void:
	water_draws += 1
	var bucket := MeshInstance3D.new()
	bucket.name = "WellDrawBucket"
	bucket.mesh = CylinderMesh.new()
	bucket.mesh.top_radius = .17
	bucket.mesh.bottom_radius = .13
	bucket.mesh.height = .3
	bucket.material_override = game.world.wood
	bucket.position = Vector3(.25,1.2,.3)
	add_child(bucket)
	var rope := MeshInstance3D.new()
	rope.mesh = CylinderMesh.new()
	rope.mesh.top_radius = .012
	rope.mesh.bottom_radius = .012
	rope.mesh.height = 1
	rope.material_override = game.world.wood
	add_child(rope)
	var tween := create_tween()
	var lower := func(y: float):
		bucket.position.y = y
		rope.position = Vector3(.25,(2.35+y)*.5,.3)
		rope.scale.y = 2.35-y
	var well := Vector3(0,1.2,.3)
	game.audio.play("well_crank",well,-16)
	tween.tween_method(lower,1.2,.42,1.8)
	tween.tween_callback(func(): game.audio.play("well_splash",Vector3(0,-1.5,.3),-12,{"unit_size":6}))
	tween.tween_interval(.6)
	tween.tween_callback(func(): game.audio.play("well_haul",well,-16))
	tween.tween_method(lower,.42,1.35,2.4)
	tween.tween_callback(func():
		if is_instance_valid(person) and is_instance_valid(carried): carried.show()
		game.audio.play("well_bucket_set",well,-16)
		bucket.queue_free()
		rope.queue_free()
	)

extends Node3D
const POND := Vector3(-12,0,8.7)
var game: Node3D
var points: Array[Dictionary] = []
var ducks: Array[Dictionary] = []
var elapsed := 0.0
var feed_until := 0.0
var fed_count := 0
var watered := false
var water_until := 0.0
var bell_time := 0.0
var bell: Node3D
var can: Node3D
var garden_mat: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var water_emitter: GPUParticles3D

func asset(id: String,pos: Vector3) -> Node3D:
	var node: Node3D = load("res://assets/village/"+id+".glb").instantiate()
	node.position = pos
	add_child(node)
	return node

func build() -> void:
	rng.seed = 829
	points.append({"id":"pond_sit","pos":Vector3(-11.1,0,4.25),"radius":1.7,"text":"Sit by the pond"})
	points.append({"id":"feed","pos":Vector3(-8.15,0,8.25),"radius":2.0,"text":"Scatter feed for the ducks"})
	for i in 4:
		var duck := asset("mallard",POND+Vector3(cos(i*1.7)*1.65,.085,sin(i*1.7)*1.15))
		duck.name = "PondDuck%d" % i
		duck.scale *= .95 if i == 0 else (.65 if i == 3 else .83)
		var ring := ripple(duck.position, .32, .37)
		ducks.append({"model":duck,"phase":float(i)*1.7,"wake":ring,"mode":"swim","fed":false})
	asset("vegetable_bed",Vector3(10,0,8.3))
	asset("vegetable_bed",Vector3(13.3,0,8.8)).rotation.y = .12
	game.world.block(Vector3(10,.18,8.3),Vector3(2.6,.36,1.8))
	game.world.block(Vector3(13.3,.18,8.8),Vector3(2.8,.36,2))
	can = asset("watering_can",Vector3(8.4,.05,8.3))

	points.append({"id":"portal","pos":Vector3(21,0,-6.0),"radius":2.1,"text":"Listen to the portal"})
	points.append({"id":"dummy","pos":Vector3(21.5,0,4.2),"radius":1.8,"text":"Test the training dummy"})
	points.append({"id":"sit","pos":Vector3(5.4,0,10.1),"radius":1.7,"text":"Sit for a moment"})
	bell = asset("village_bell",Vector3(3.3,0,-10.5))
	game.world.block(Vector3(3.3,1,-10.5),Vector3(1.1,2,.4))
	points.append({"id":"bell","pos":Vector3(3.3,0,-9.6),"radius":1.8,"text":"Ring the village bell"})
	# Hand-built workyard details break up the empty spaces between larger assets.
	var world = game.world
	for i in 7:
		world.box(Vector3(-10.3,.14+i*.08,2.8),Vector3(1.2,.12,.17),world.wood).rotation.y = .1*(i%3)
	for i in 5:
		var bench = world.box(Vector3(10.1+i*.7,.43,11.4),Vector3(.12,.86,.12),world.wood)
		bench.rotation.z = .04*sin(i)
	world.box(Vector3(11.5,.65,11.4),Vector3(3.5,.10,.10),world.wood)
	world.box(Vector3(11.5,.36,11.4),Vector3(3.5,.10,.10),world.wood)
	# A washing line between two houses, rather than duplicated street furniture.
	for x in [-10.3,-7.8]: world.box(Vector3(x,1,-5.5),Vector3(.09,2,.09),world.wood)
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

func _process(delta: float) -> void:
	elapsed += delta
	for duck in ducks:
		var angle: float = elapsed*.11+duck.phase
		var target := POND+Vector3(cos(angle)*1.85,.085,sin(angle)*1.2)
		duck.mode = "swim"
		if elapsed < feed_until:
			target = POND+Vector3(1.7+cos(duck.phase)*.18,.085,sin(duck.phase)*.5)
			duck.mode = "feeding"
		else:
			var away: Vector3 = duck.model.position-game.player.position
			away.y = 0
			if away.length() < 2.2:
				target += away.normalized()*.5
				duck.mode = "avoid"
		var direction: Vector3 = target-duck.model.position
		direction.y = 0
		if direction.length() > .05:
			duck.model.position += direction.normalized()*minf(delta*.65,direction.length())
			duck.model.rotation.y = lerp_angle(duck.model.rotation.y,atan2(direction.x,direction.z),delta*2.5)
		duck.model.position.y = .085+sin(elapsed*2+duck.phase)*.013
		duck.model.rotation.z = sin(elapsed*2+duck.phase)*.035
		duck.wake.position = Vector3(duck.model.position.x,.102,duck.model.position.z)
		var size := .85+sin(elapsed*1.4+duck.phase)*.12
		duck.wake.scale = Vector3(size,.08,size*.75)
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
		"portal":
			game.toast("The passage is awake. Its destination is still beyond this prototype.")
		"dummy":
			game.kit.practice_dummy.strike()
			game.toast("Ready for greatsword practice, once you have a blade.")
		"feed":
			if elapsed < feed_until:
				game.toast("They are still enjoying the last handful.")
				return
			feed_until = elapsed+16
			fed_count += 1
			game.player.act("feed",POND,1.3)
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
	get_tree().create_timer(3.6).timeout.connect(particles.queue_free)

func bell_sound() -> void:
	if game.muted or game.test_mode: return
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

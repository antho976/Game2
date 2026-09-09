extends Node3D
## Residents share a clearance grid baked from actual static hub collision.
const Landscape = preload("res://scripts/hub_landscape.gd")
var kit: HubKit
var animals: Array[Dictionary] = []
var elapsed: float = 0
var cat_food_until := 0.0
var cat_food_position := Vector3.ZERO
var navigation := AStarGrid2D.new()
var navigation_ready := false
var rng := RandomNumberGenerator.new()
var last_takeoff := -10.0
var takeoffs := 0
const CELL := .6
const GRID_ORIGIN := Vector2(-18.6,-15)
const FEEDING_PATCHES := [Vector3(3,0,7.5),Vector3(-7.7,0,6.4),Vector3(0,0,-5.2),Vector3(10.8,0,4.2),Vector3(-4,0,-3.5),Vector3(1.8,0,11.5)]


func build(hub: HubKit) -> void:
	kit = hub
	rng.seed = 2317
	for entry in [[Vector3(-4.8,.1,7.8),true,Color(.64,.35,.16)],
		[Vector3(10.8,.1,4.5),false,Color(.19,.21,.22)],
		[Vector3(-10.8,.1,-3.5),false,Color(.72,.67,.54)],
		[Vector3(4.8,.1,-5.7),true,Color(.40,.37,.33)]]:
		cat(entry[0],entry[1],entry[2])
	for i in 10:
		bird(Vector3(2.5+(i%4)*.55,.12,7.5+(i/4)*.7),i)
	for i in 5:
		bird(Vector3(-8.3+(i%3)*.45,.12,6.4+(i/3)*.5),i+10)
	initialize_navigation.call_deferred()

func body_at(pos: Vector3, radius: float) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = pos
	body.collision_layer = 0
	body.collision_mask = 5
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	shape.position.y = radius
	body.add_child(shape)
	add_child(body)
	return body

func cat(pos: Vector3, friendly: bool, coat: Color) -> void:
	var body := body_at(pos,.16)
	body.name = "FriendlyCat" if friendly else "ShyCat"
	var model := Node3D.new()
	body.add_child(model)
	var art: Node3D = load("res://assets/village/tabby_cat.glb").instantiate()
	model.add_child(art)
	var legs: Array[Node3D] = []
	for i in 4:
		var found := art.find_children("Leg"+str(i),"Node3D",true,false)
		if not found.is_empty(): legs.append(found[0])
	var tails := art.find_children("CatTail","Node3D",true,false)
	var tail: Node3D = tails[0] if not tails.is_empty() else Node3D.new()
	if tails.is_empty(): model.add_child(tail)
	if not friendly:
		for mesh in art.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var original: Material = mesh.mesh.surface_get_material(surface)
				if original is StandardMaterial3D and original.resource_name == "tabby":
					var mat: StandardMaterial3D = original.duplicate()
					mat.albedo_color = coat
					mesh.set_surface_override_material(surface,mat)
	animals.append({"body":body,"model":model,"home":pos,"kind":"cat","friendly":friendly,
		"gait":0.0,"pet_until":0.0,"pets":0,"state":"idle","timer":0.0,"legs":legs,"tail":tail,"phase":float(animals.size())*1.7,"target":pos,"path":PackedVector3Array(),"decision":0.0,"stalled":0.0,"interest":0.0,"attention_cooldown":rng.randf_range(1,5),"wander_due":rng.randf_range(3,8),"avoid_for":0.0,"avoid_direction":Vector3.ZERO})

func bird(pos: Vector3, index: int) -> void:
	var body := body_at(pos,.065)
	body.name = "GardenBird%d" % index
	var model := Node3D.new()
	body.add_child(model)
	var coat := Color(.27,.31,.34) if index%2 else Color(.43,.31,.20)
	Landscape.shape(model,Vector3(0,.13,0),Vector3(.10,.10,.16),coat)
	Landscape.shape(model,Vector3(0,.23,.12),Vector3(.08,.08,.08),coat)
	Landscape.shape(model,Vector3(0,.20,.205),Vector3(.025,.022,.055),Color(.68,.49,.19))
	Landscape.shape(model,Vector3(0,.11,.105),Vector3(.07,.065,.065),Color(.66,.44,.27))
	for x in [-.065,.065]:
		Landscape.shape(model,Vector3(x,.24,.166),Vector3(.012,.012,.01),Color(.015,.019,.016))
	var wings: Array[Node3D] = []
	for side in [-1,1]:
		var wing := Node3D.new()
		wing.position = Vector3(side*.07,.16,0)
		model.add_child(wing)
		Landscape.shape(wing,Vector3(side*.10,0,-.025),Vector3(.15,.027,.085),coat)
		wing.set_meta(StaticBatcher.NO_BATCH,true)
		wings.append(wing)
		Landscape.shape(model,Vector3(side*.035,.025,0),Vector3(.012,.065,.013),Color(.42,.28,.14))
	# Body, head, beak, eyes and legs move together, so they draw as one object; wings flap alone.
	StaticBatcher.merge(model)
	animals.append({"body":body,"model":model,"home":pos,"kind":"bird","state":"feeding",
		"timer":rng.randf_range(1,4),"wings":wings,"phase":index*.9,"target":pos,"path":PackedVector3Array(),"flight_due":rng.randf_range(10,26),"landings":0})

func _physics_process(delta: float) -> void:
	if not is_instance_valid(kit.world.game.player): return
	elapsed += delta
	var player: Vector3 = kit.world.game.player.global_position
	for animal in animals:
		step_animal(animal,player,delta)

func initialize_navigation() -> void:
	# All the kit's deferred physics bodies must exist in the space before querying.
	if not is_inside_tree() or is_queued_for_deletion(): return
	await get_tree().physics_frame
	if not is_inside_tree() or is_queued_for_deletion(): return
	await get_tree().physics_frame
	if not is_inside_tree() or is_queued_for_deletion(): return
	navigation.region = Rect2i(0,0,75,51)
	navigation.cell_size = Vector2.ONE*CELL
	navigation.offset = GRID_ORIGIN
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	var query := PhysicsShapeQueryParameters3D.new()
	var probe := CapsuleShape3D.new()
	probe.height = 1.8
	probe.radius = .42 # Body clearance plus half a grid step catches thin fences between samples.
	query.shape = probe
	query.collision_mask = 5
	# Moving people should not permanently remove pavement from the shared map.
	var excluded: Array[RID] = []
	for npc in kit.npcs: excluded.append(npc.get_rid())
	query.exclude = excluded
	var space := get_world_3d().direct_space_state
	for x in 75:
		for z in 51:
			var point := navigation.get_point_position(Vector2i(x,z))
			query.transform = Transform3D(Basis.IDENTITY,Vector3(point.x,.95,point.y))
			navigation.set_point_solid(Vector2i(x,z),not space.intersect_shape(query,1).is_empty())
	navigation_ready = true

func cell_at(p: Vector3) -> Vector2i:
	return Vector2i(roundi((p.x-GRID_ORIGIN.x)/CELL),roundi((p.z-GRID_ORIGIN.y)/CELL))

func open_cell(cell: Vector2i) -> bool:
	return navigation.is_in_boundsv(cell) and not navigation.is_point_solid(cell)

func nearest_cell(p: Vector3) -> Vector2i:
	var cell := cell_at(p)
	if open_cell(cell): return cell
	for radius in range(1,5):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var candidate := cell+Vector2i(x,z)
				if open_cell(candidate): return candidate
	return Vector2i(-1,-1)

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start := nearest_cell(from)
	var end := cell_at(to)
	var result := PackedVector3Array()
	if not open_cell(start) or not open_cell(end): return result
	# Re-route around today's NPC positions without baking yesterday's positions in.
	var temporary: Array[Vector2i] = []
	for person in kit.npcs:
		var center := cell_at(person.position)
		for x in range(-1,2):
			for z in range(-1,2):
				var cell := center+Vector2i(x,z)
				if cell != start and open_cell(cell):
					navigation.set_point_solid(cell,true)
					temporary.append(cell)
	if open_cell(end):
		for point in navigation.get_point_path(start,end):
			result.append(Vector3(point.x,0,point.y))
	for cell in temporary: navigation.set_point_solid(cell,false)
	return result

func follow_route(a: Dictionary) -> Vector3:
	while not a.path.is_empty():
		var offset: Vector3 = a.path[0]-a.body.position
		offset.y = 0
		if offset.length() > .18: return offset.normalized()
		a.path.remove_at(0)
	return Vector3.ZERO

func escape_route(a: Dictionary, threat: Vector3) -> void:
	var best := -INF
	var chosen := PackedVector3Array()
	var away: Vector3 = a.body.position-threat
	away.y = 0
	for i in 20:
		var angle := i*TAU/20
		var candidate: Vector3 = a.body.position+Vector3(cos(angle),0,sin(angle))*rng.randf_range(3.5,6.5)
		var cell := cell_at(candidate)
		if not open_cell(cell): continue
		var path := route(a.body.position,candidate)
		if path.size() < 2: continue
		var endpoint: Vector3 = path[path.size()-1]
		var clearance := 0
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if open_cell(cell+offset): clearance += 1
		# Prefer space away from the threat, but allow a sideways escape from corners.
		var score := endpoint.distance_to(threat) - path.size()*.065 + clearance*.35
		if score > best:
			best = score
			chosen = path
	a.path = chosen
	a.decision = 1.1
	a.stalled = 0.0

func steer_clear(a: Dictionary, desired: Vector3, delta: float) -> Vector3:
	if desired.is_zero_approx(): return desired
	var body: CharacterBody3D = a.body
	var probe := body.global_transform
	probe.origin.y += .08
	a.avoid_for = maxf(0,a.avoid_for-delta)
	if a.avoid_for > 0 and not body.test_move(probe,a.avoid_direction*.55):
		return a.avoid_direction
	if not body.test_move(probe,desired*.55): return desired
	for angle in [.7,-.7,1.35,-1.35,2.0,-2.0]:
		var candidate := desired.rotated(Vector3.UP,angle)
		if not body.test_move(probe,candidate*.65):
			a.avoid_direction = candidate
			a.avoid_for = .35
			return candidate
	# An obstructed cat waits and replans instead of playing a run into a wall.
	a.decision = 0.0
	return Vector3.ZERO

func wander_route(a: Dictionary) -> void:
	a.path.clear()
	for attempt in 16:
		var candidate: Vector3 = a.home+Vector3(rng.randf_range(-4,4),0,rng.randf_range(-4,4))
		var path := route(a.body.position,candidate)
		if path.size() > 2:
			a.path = path
			break
	a.state = "wander"
	a.wander_due = rng.randf_range(5,10)

func landing_spot(a: Dictionary, player: Vector3) -> Vector3:
	for attempt in 45:
		var patch: Vector3 = FEEDING_PATCHES[rng.randi_range(0,FEEDING_PATCHES.size()-1)]
		var candidate := patch+Vector3(rng.randf_range(-1.2,1.2),0,rng.randf_range(-.8,.8))
		var cell := cell_at(candidate)
		if not open_cell(cell): continue
		var p := navigation.get_point_position(cell)
		candidate = Vector3(p.x,.12,p.y)
		if candidate.distance_to(player) < 4 or candidate.distance_to(a.home) < 2.2: continue
		return candidate
	# Stay airborne and retry if a safe alternative is temporarily unavailable.
	return Vector3.INF

func begin_flight(a: Dictionary, player: Vector3) -> void:
	var destination := landing_spot(a,player)
	if destination == Vector3.INF:
		a.timer = 1.0
		return
	a.target = destination
	# Three or more birds leaving inside half a second read as one startled flock.
	var now := elapsed
	if now-last_takeoff < .5:
		takeoffs += 1
		if takeoffs == 3: kit.world.game.audio.play("bird_flock_alarm",a.body.position,-10,{"cooldown":2.0})
	else: takeoffs = 1
	last_takeoff = now
	kit.world.game.audio.play("bird_takeoff",a.body.position,-14,{"cooldown":.08})
	a.state = "takeoff"
	a.path.clear()
	a.timer = 12.0

func step_animal(a: Dictionary, player: Vector3, delta: float) -> void:
	if not navigation_ready: return
	var body: CharacterBody3D = a.body
	var food: bool = a.kind == "cat" and elapsed < cat_food_until
	if food: player = cat_food_position
	var offset: Vector3 = body.position-player
	offset.y = 0
	var distance := offset.length()
	var direction := Vector3.ZERO
	var speed := 0.0
	a.timer = maxf(0,a.timer-delta)
	if a.kind == "cat":
		if a.pet_until > elapsed:
			a.state = "petted"
			a.body.velocity = Vector3(0,-2,0)
			a.body.move_and_slide()
			a.model.rotation.z = sin(elapsed*2)*.025
			for leg in a.legs: leg.rotation.x = lerp_angle(leg.rotation.x,0,delta*8)
			a.tail.rotation.z = sin(elapsed*2)*.14
			return
		a.model.rotation.z = lerpf(a.model.rotation.z,0,delta*5)
		a.decision = maxf(0,a.decision-delta)
		a.attention_cooldown = maxf(0,a.attention_cooldown-delta)
		a.wander_due -= delta
		if a.friendly:
			if a.interest > 0:
				a.interest = maxf(0,a.interest-delta)
				if a.interest == 0:
					a.attention_cooldown = rng.randf_range(10,22)
					wander_route(a)
				elif a.state == "follow" and rng.randf() < delta*.25:
					kit.world.game.audio.play("cat_chirrup",body.position,-18,{"cooldown":2.5})
			elif distance < 6 and a.attention_cooldown <= 0:
				kit.world.game.play_sound("cat_meow",body.position,"",0,-14)
				a.interest = rng.randf_range(3,6)
				a.decision = 0.0
		if not food and not a.friendly and (distance < 3.3 or (a.state == "flee" and distance < 5.5)):
			if a.state != "flee": kit.world.game.audio.play("cat_hiss",body.position,-14,{"cooldown":4.0})
			a.state = "flee"
			a.timer = 1.8
			if a.decision <= 0: escape_route(a,player)
			direction = follow_route(a)
			speed = 2.5
		elif a.state == "flee" and a.timer > 0:
			direction = follow_route(a)
			speed = 1.7
		elif (food or (a.friendly and a.interest > 0)) and distance < 14 and distance > 1.25:
			a.state = "follow"
			if a.decision <= 0:
				a.path = route(body.position,player+offset.normalized()*1.1)
				a.decision = .7
			direction = follow_route(a)
			speed = 1.3 if distance < 3 else 2.0
		elif food or (a.friendly and a.interest > 0):
			a.state = "watch"
			a.path.clear()
		elif a.friendly and (a.state == "wander" or a.wander_due <= 0):
			if a.wander_due <= 0: wander_route(a)
			direction = follow_route(a)
			speed = .65
			if a.path.is_empty(): a.state = "idle"
		elif body.position.distance_to(a.home) > 5 and distance > 7:
			a.state = "return"
			if a.decision <= 0:
				a.path = route(body.position,a.home)
				a.decision = 2.0
			direction = follow_route(a)
			speed = .8
		else:
			a.state = "idle"
			a.path.clear()
		direction = steer_clear(a,direction,delta)
		var before := body.position
		body.velocity = body.velocity.move_toward(direction*speed+Vector3(0,-3,0),delta*5)
		body.move_and_slide()
		var moved := Vector2(body.position.x-before.x,body.position.z-before.z).length()
		if speed > 0 and not direction.is_zero_approx() and moved < .15*speed*delta:
			a.stalled += delta
			if a.stalled > .3:
				escape_route(a,player)
				a.decision = 1.2
		else:
			a.stalled = 0.0
		a.gait += moved*TAU/.66
		for i in a.legs.size():
			var angle: float = sin(a.gait+[0.0,PI,PI*1.5,PI*.5][i])*.38 if moved > .001 else 0.0
			a.legs[i].rotation.x = lerp_angle(a.legs[i].rotation.x,angle,minf(delta*18,1))
		a.tail.rotation.z = sin(elapsed*2+a.phase)*.25
		a.model.position.y = sin(elapsed*3+a.phase)*.008
	else:
		var offered: bool = elapsed<a.get("food_until",0.0)
		if offered and distance>.8 and a.state in ["feeding","hopping"]:
			var goal: Vector3 = a.food_target
			var toward := goal-body.position
			toward.y = 0
			if toward.length()>.22:
				if a.timer<=0:
					a.path = route(body.position,goal)
					a.timer = 1.0
				direction = follow_route(a) if toward.length()>.8 else toward.normalized()
				speed = 1.0
				a.state = "hopping"
			else:
				a.state = "feeding"
				a.model.rotation.y = atan2(toward.x,toward.z)
			body.velocity = direction*speed+Vector3(0,-2,0)
			body.move_and_slide()
			a.model.rotation.x = maxf(0,sin(elapsed*6+a.phase))*.6 if a.state=="feeding" else 0.0
			if direction.length()>.01: a.model.rotation.y = lerp_angle(a.model.rotation.y,atan2(direction.x,direction.z),delta*8)
			return
		a.flight_due -= delta
		if a.state in ["feeding","hopping"]:
			if distance < 2.7 or a.flight_due <= 0:
				begin_flight(a,player)
			elif a.state == "feeding" and a.timer <= 0:
				if rng.randf() < .12: kit.world.game.play_sound("bird_chirp",body.position,"",0,-18)
				var candidate: Vector3 = a.home+Vector3(rng.randf_range(-1.4,1.4),0,rng.randf_range(-1.4,1.4))
				a.path = route(body.position,candidate)
				if not a.path.is_empty():
					a.state = "hopping"
				else: a.timer = 1
			if a.state == "hopping":
				direction = follow_route(a)
				speed = .48
				if a.path.is_empty():
					a.state = "feeding"
					a.timer = rng.randf_range(1.2,3.2)
		if a.state == "takeoff":
			direction = Vector3.UP
			speed = 3.5
			if body.position.y >= 7.5:
				a.state = "cruise"
		elif a.state == "cruise":
			var destination: Vector3 = Vector3(a.target.x,7.5,a.target.z)
			direction = (destination-body.position).normalized()
			speed = 4.8
			if body.position.distance_to(destination) < .25:
				a.state = "land"
				a.timer = 8.0
		elif a.state == "land":
			if a.target.distance_to(player) < 3:
				begin_flight(a,player)
				direction = Vector3.UP
				speed = 3.5
			else:
				direction = (a.target-body.position).normalized()
				speed = minf(2.6,body.position.distance_to(a.target)/maxf(delta,.001))
				if body.position.distance_to(a.target) < .12:
					a.home = a.target
					a.landings += 1
					kit.world.game.audio.play("bird_land",body.position,-18,{"cooldown":.1})
					a.state = "feeding"
					a.timer = rng.randf_range(1.2,3.2)
					a.flight_due = rng.randf_range(12,28)
		var flying: bool = a.state in ["takeoff","cruise","land"]
		body.velocity = direction*speed+(Vector3.ZERO if flying else Vector3(0,-2,0))
		body.move_and_slide()
		if flying:
			a.model.rotation.x = lerpf(a.model.rotation.x,0,delta*6)
			if a.timer <= 0: begin_flight(a,player)
		else:
			a.model.rotation.x = maxf(0,sin(elapsed*2.7+a.phase))*.55 if a.state == "feeding" else -.12
			a.model.position.y = absf(sin(elapsed*12+a.phase))*.035 if a.state == "hopping" else 0.0
		for i in 2:
			a.wings[i].rotation.z = sin(elapsed*22+a.phase)*.8*(1 if i == 0 else -1) if flying else (.95 if i == 0 else -.95)
	if direction.length() > .01 and Vector2(direction.x,direction.z).length() > .01:
		a.model.rotation.y = lerp_angle(a.model.rotation.y,atan2(direction.x,direction.z),minf(delta*7,1))

func pet(animal: Dictionary) -> void:
	if animal.kind != "cat" or not animal.friendly: return
	animal.pet_until = elapsed+2.4
	animal.path.clear()
	animal.pets += 1
	animal.interest = 6.0
	animal.attention_cooldown = 12.0
	# The purr lasts as long as the hand does.
	var key := "purr:"+str(animal.body.get_instance_id())
	kit.world.game.audio.loop(key,"cat_purr",Vector3(0,.15,0),-16,{"bus":"SFX","max_distance":8,"fade_in":true,"parent":animal.body})
	get_tree().create_timer(2.4).timeout.connect(func(): kit.world.game.audio.stop(key,.6))

func offer_bird_food(spots: Array[Vector3]) -> void:
	var birds: Array[Dictionary] = []
	for animal in animals:
		if animal.kind=="bird" and animal.state in ["feeding","hopping"]: birds.append(animal)
	birds.sort_custom(func(a,b): return a.body.position.distance_squared_to(spots[0])<b.body.position.distance_squared_to(spots[0]))
	for i in mini(6,birds.size()):
		var bird = birds[i]
		bird.food_target = spots[i]
		bird.food_until = elapsed+18
		bird.timer = 0
		bird.flight_due = 22

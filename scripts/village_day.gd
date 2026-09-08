extends Node
# A twelve-minute day. Station reservations include travel time, preventing queues.
const DAY_SECONDS := 720.0
var game: Node3D
var clock := 270.0
var enabled := true
var residents: Array[Dictionary] = []
var reservations := {}
var stations := {"water":Vector3(1.9,0,.3),"birds":Vector3(-7.7,0,6.4),"cats":Vector3(3.5,0,7.2),"ducks":Vector3(-8.15,0,8.25),"garden":Vector3(8.25,0,8.1),"talk_a":Vector3(-3.9,0,-5.2),"talk_b":Vector3(-2.6,0,-5.2)}
var sun: DirectionalLight3D
var environment: Environment
var lamps: Array[OmniLight3D] = []
var clock_label: Label
var completed := {}

func build() -> void:
	enabled = not game.test_mode or "--routine-test" in OS.get_cmdline_user_args()
	for child in game.world.get_children():
		if child is DirectionalLight3D: sun = child
		if child is WorldEnvironment: environment = child.environment
	for child in game.kit.get_children():
		if child is OmniLight3D and child != game.kit.forge_light: lamps.append(child)
	clock_label = game.label("",14,Color(.87,.85,.74),Vector2(30,74))
	var doors := [Vector3(-7.15,0,-7.4),Vector3(3.95,0,-9.5),Vector3(12.85,0,-8.8),Vector3(-13.75,0,-4.0)]
	var plans := [["work","water","work","talk_a"],["work","birds","work","talk_b"],["garden","water","garden","ducks"],["water","cats","talk_a","birds"],["talk_b","ducks","water","cats"],["birds","talk_b","cats","water"]]
	for i in game.kit.npcs.size():
		var person: HubNPC = game.kit.npcs[i]
		person.routine_managed = enabled
		var prop := make_bucket(person)
		residents.append({"npc":person,"work":person.position,"door":doors[i%4],"plan":plans[i%plans.size()],"index":i%4,"job":"","state":"waiting","path":PackedVector3Array(),"due":float(i)*4+1,"timer":0.0,"stuck":0.0,"night":20.0+i*.28,"morning":6.1+i*.25,"prop":prop,"arrivals":0})
	update_light()

func make_bucket(person: HubNPC) -> Node3D:
	var skeleton: Skeleton3D = person.model.find_children("*","Skeleton3D",true,false)[0]
	var attach := BoneAttachment3D.new()
	attach.bone_name = "Hand.R"
	skeleton.add_child(attach)
	var root := Node3D.new()
	attach.add_child(root)
	root.transform = skeleton.get_bone_global_rest(skeleton.find_bone("Hand.R")).affine_inverse()
	var mesh := MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	mesh.mesh.top_radius = .15
	mesh.mesh.bottom_radius = .11
	mesh.mesh.height = .27
	mesh.position = Vector3(.40,.69,.02)
	mesh.material_override = game.world.wood
	root.add_child(mesh)
	var handle := MeshInstance3D.new()
	handle.mesh = TorusMesh.new()
	handle.mesh.inner_radius = .13
	handle.mesh.outer_radius = .145
	handle.mesh.rings = 12
	handle.position = Vector3(.40,.9,.02)
	handle.rotation.x = PI/2
	handle.material_override = game.world.stone[1]
	root.add_child(handle)
	root.hide()
	return root

func hour() -> float:
	return fposmod(clock,DAY_SECONDS)/30.0

func _process(delta: float) -> void:
	if enabled: clock = fposmod(clock+delta,DAY_SECONDS)
	update_light()

func update_light() -> void:
	var h := hour()
	var daylight := smoothstep(5.5,7.5,h)*(1.0-smoothstep(18.2,20.8,h))
	var dusk := (1.0-smoothstep(0,2,absf(h-18.8)))*daylight
	sun.light_energy = lerpf(.10,1.15,daylight)
	sun.light_color = Color(.40,.52,.80).lerp(Color(1,.96,.87),daylight).lerp(Color(1,.61,.34),dusk*.5)
	environment.ambient_light_energy = lerpf(.5,.72,daylight)
	environment.ambient_light_color = Color(.25,.34,.55).lerp(Color(.57,.70,.83),daylight)
	environment.background_color = Color(.035,.055,.11).lerp(Color(.43,.54,.52),daylight)
	for lamp in lamps: lamp.light_energy = lerpf(1.2,0.0,daylight)
	var minute := int(h*60)%60
	clock_label.text = "%02d:%02d  ·  %s" % [int(h),minute,"Night" if daylight<.2 else ("Evening" if h>18 else "Day")]

func _physics_process(delta: float) -> void:
	if not enabled or not game.kit.life.navigation_ready: return
	for i in residents.size(): step(residents[i],i,delta)

func release(r: Dictionary) -> void:
	if reservations.get(r.job,-1) == r.npc.get_instance_id(): reservations.erase(r.job)
	if r.job != "water": r.prop.hide()
	r.job = ""

func path_to(person: HubNPC,target: Vector3) -> PackedVector3Array:
	var life = game.kit.life
	var start: Vector2i = life.nearest_cell(person.position)
	var end: Vector2i = life.nearest_cell(target)
	var result := PackedVector3Array()
	if not life.open_cell(start) or not life.open_cell(end): return result
	for p in life.navigation.get_point_path(start,end): result.append(Vector3(p.x,0,p.y))
	return result

func travel(r: Dictionary, job: String, target: Vector3) -> bool:
	var path := path_to(r.npc,target)
	if path.is_empty(): return false
	release(r)
	r.job = job
	if job != "home": reservations[job] = r.npc.get_instance_id()
	r.path = path
	r.state = "walking"
	r.timer = 0.0
	r.stuck = 0.0
	return true

func step(r: Dictionary, index: int, delta: float) -> void:
	var person: HubNPC = r.npc
	var at_night: bool = hour()>=r.night or hour()<r.morning
	if r.state == "inside":
		if at_night: return
		# The same doorway is occupied only briefly; departures are offset per resident.
		person.position = r.door
		person.show()
		person.collision_layer = 1
		person.collision_mask = 3
		r.state = "waiting"
		r.due = 2+index
	if at_night and r.job != "home": travel(r,"home",r.door)
	if r.state == "waiting":
		r.due -= delta
		if r.due <= 0 and not at_night:
			var job: String = r.plan[r.index%r.plan.size()]
			r.index += 1
			var key := "work_"+str(index) if job == "work" else job
			if not reservations.has(key): travel(r,key,r.work if job=="work" else stations[job])
			r.due = 3+index*.4
		person.play("idle")
	elif r.state == "walking":
		r.timer += delta
		while not r.path.is_empty() and Vector2(person.position.x-r.path[0].x,person.position.z-r.path[0].z).length()<.22: r.path.remove_at(0)
		if r.path.is_empty():
			arrive(r,index)
			return
		var direction: Vector3 = (r.path[0]-person.position)
		direction.y = 0
		direction = direction.normalized()
		# Give passing residents and the player room without abandoning the route.
		var avoidance := Vector3.ZERO
		for other in residents:
			if other == r or other.state == "inside": continue
			var offset: Vector3 = person.position-other.npc.position
			offset.y = 0
			if offset.length()<.85: avoidance += offset.normalized()*(.85-offset.length())*1.8
		direction = (direction+avoidance).normalized()
		person.velocity = direction*(1.15+index*.025)+Vector3(0,-3,0)
		var before := person.position
		person.move_and_slide()
		r.stuck = r.stuck+delta if person.position.distance_to(before)<.002 else 0.0
		person.model.rotation.y = lerp_angle(person.model.rotation.y,atan2(direction.x,direction.z),delta*5)
		person.play("walk")
		person.animation.speed_scale = .8
		if r.stuck>2:
			r.path = path_to(person,r.door if r.job=="home" else (r.work if r.job.begins_with("work_") else stations[r.job]))
			r.stuck = 0.0
		# If a visitor keeps a station blocked, release it and try another activity later.
		if r.timer>75 and r.job!="home":
			release(r)
			r.state = "waiting"
			r.due = 3
		return
	elif r.state == "working":
		r.timer -= delta
		var job: String = r.job
		var action := "idle"
		if job.begins_with("work_"): action = "hammer" if person.profession=="blacksmith" else "read"
		elif job in ["birds","cats","ducks"] and person.profession=="villager": action = "feed"
		elif job == "garden": action = "water"
		person.play(action)
		person.animation.speed_scale = 1
		if action == "hammer":
			var at: float = person.animation.current_animation_position
			if person.previous_time<.4 and at>=.4: person.work_struck.emit()
			person.previous_time = at
		if job.begins_with("talk"):
			var other_pos: Vector3 = stations["talk_b" if job=="talk_a" else "talk_a"]
			var facing := other_pos-person.position
			person.model.rotation.y = lerp_angle(person.model.rotation.y,atan2(facing.x,facing.z),delta*3)
			person.model.rotation.z = sin(r.timer*1.4+index)*.015
		if r.timer<=0:
			person.model.rotation.z = 0
			release(r)
			r.state = "waiting"
			r.due = 5+index*1.7
	person.velocity = Vector3(0,-3,0)
	person.move_and_slide()

func arrive(r: Dictionary,index: int) -> void:
	if r.job == "home":
		r.npc.hide()
		r.npc.collision_layer = 0
		r.npc.collision_mask = 0
		release(r)
		r.state = "inside"
		return
	r.state = "working"
	r.arrivals += 1
	var target: Vector3 = r.npc.position+Vector3(0,0,1)
	if r.job == "water": target = Vector3(0,0,.3)
	elif r.job == "garden": target = Vector3(10,0,8.3)
	elif r.job == "ducks": target = Vector3(-12,0,8.7)
	var facing: Vector3 = target-r.npc.position
	r.npc.model.rotation.y = atan2(facing.x,facing.z)
	r.timer = 14+index*1.1
	completed[r.job] = int(completed.get(r.job,0))+1
	if r.job.begins_with("talk"): r.timer = 40
	r.prop.visible = r.job in ["water","garden"]
	if r.job == "garden":
		game.activities.watered = true
		game.activities.water_particles()
	if r.job == "ducks": game.activities.feed_until = game.activities.elapsed+18
	if r.job == "cats":
		game.kit.life.cat_food_until = game.kit.life.elapsed+18
		game.kit.life.cat_food_position = stations.cats+Vector3(0,0,1.2)
	if r.job == "birds":
		for animal in game.kit.life.animals:
			if animal.kind == "bird" and animal.body.position.distance_to(stations.birds)<12:
				animal.path = game.kit.life.route(animal.body.position,stations.birds+Vector3(.7,0,.9))
				animal.state = "hopping"
				animal.flight_due = 25

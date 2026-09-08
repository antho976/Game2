extends Node
var failures := 0
func check(ok: bool,text: String) -> void:
	print("PASS: " if ok else "FAIL: ",text)
	if not ok: failures+=1
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func run(game: Node) -> void:
	Engine.max_fps = 0
	await frames(30)
	for spec in [["house",Vector3(-7.15,.1,-5.7),Vector3(-7.15,0,-10)],["well",Vector3(0,.1,3.7),Vector3(0,0,.3)],["garden bed",Vector3(10,.1,10.6),Vector3(10,0,8.3)],["lamp post",Vector3(-4.4,.1,-3.5),Vector3(-4.4,0,-5.5)],["fence",Vector3(11.5,.1,13.5),Vector3(11.5,0,11.4)]]:
		game.player.position = spec[1]
		game.player.velocity = Vector3.ZERO
		game.yaw = 0
		Input.action_press("up")
		await frames(160)
		Input.action_release("up")
		check(game.player.position.z>spec[2].z+.25,"Collision blocks walking through "+spec[0])
	game.player.position = Vector3(-8.15,.1,8.25)
	game.player.velocity = Vector3.ZERO
	game.activities.interact("feed")
	await frames(36)
	await shot(game,"feed",game.player.position+Vector3(-1,.8,0))
	check(game.activities.feed_releases>0,"Feed releases visible projectiles")
	check(game.activities.find_children("ThrownFeed*","Node",true,false).size()>0,"Food remains visible during the throw")
	var person = game.kit.npcs[2]
	person.position = Vector3(1.9,0,.3)
	person.model.rotation.y = -PI/2
	person.play("draw_water")
	game.activities.draw_water(person,game.village_day.residents[2].prop)
	await frames(60)
	await shot(game,"well",Vector3(.5,1,.3))
	var bucket = game.activities.find_children("WellDrawBucket*","Node3D",true,false)
	check(not bucket.is_empty() and bucket[0].position.y<1.1,"Well bucket visibly lowers")
	await frames(260)
	check(game.village_day.residents[2].prop.visible,"Drawn bucket transfers to the resident")
	var eating := false
	var separated := true
	game.activities.feed_until = game.activities.elapsed+20
	for frame in 600:
		await frames(1)
		for duck in game.activities.ducks:
			eating = eating or duck.head.rotation.x>.9
			for other in game.activities.ducks:
				if other==duck: continue
				if duck.model.position.distance_to(other.model.position)<duck.radius+other.radius-.03: separated = false
	check(eating,"Ducks dip their heads to eat")
	check(separated,"Duck bodies remain separated while gathering")
	var day = game.village_day
	var resident = day.residents[2]
	person.routine_managed = true
	person.rotation.y = 0
	person.position = Vector3(11.5,.1,12.2)
	person.velocity = Vector3.ZERO
	resident.work = Vector3(11.5,0,10.2)
	check(day.travel(resident,"work_2",resident.work),"Route around southeast fence exists")
	for frame in 900:
		day.step(resident,2,1.0/60)
		await frames(1)
		if resident.state=="working": break
	check(resident.state=="working" and person.position.z<10.8,"Resident gets around southeast fence without becoming stuck")
	print("CLEANUP CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

func shot(game: Node,id: String,target: Vector3) -> void:
	if DisplayServer.get_name()=="headless": return
	game.set_process(false)
	game.ui.hide()
	game.camera.size = 5.5
	game.camera.position = target+(Vector3(5,7,-6) if id=="feed" else Vector3(4,5,7))
	game.camera.look_at(target)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/cleanup_"+id+".png")
	game.set_process(true)
	game.ui.show()

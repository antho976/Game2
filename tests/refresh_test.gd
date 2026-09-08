extends Node
var failures := 0
func check(ok: bool,message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func shot(game: Node,id: String,target: Vector3,size: float) -> void:
	if DisplayServer.get_name()=="headless": return
	game.set_process(false)
	game.ui.hide()
	game.menus.root.hide()
	game.camera.size = size
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.position = target+Vector3(4,12,10)
	game.camera.look_at(target)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/refresh_"+id+".png")
	game.set_process(true)
func run(game: Node) -> void:
	Engine.max_fps = 0
	await frames(60)
	game.player.position = Vector3(0,0,12)
	var person = game.kit.npcs[3]
	person.routine_managed = true
	person.position = game.village_day.stations.birds
	person.play("feed")
	game.activities.throw_feed(person,game.village_day.feed_target("birds"))
	await frames(960)
	var reached := 0
	for bird in game.kit.life.animals:
		if bird.kind=="bird" and bird.has("food_target") and bird.body.position.distance_to(bird.food_target)<.4: reached+=1
	check(reached>=2,"Birds gather at actual thrown food ("+str(reached)+")")
	person.position = game.village_day.stations.ducks
	game.activities.throw_feed(person,game.village_day.feed_target("ducks"))
	await frames(780)
	var ducks := 0
	for duck in game.activities.ducks:
		for food in game.activities.duck_food:
			if duck.model.position.distance_to(food)<.7:
				ducks+=1
				break
	check(ducks==4,"All ducks reach the food landing area")
	await shot(game,"pond",Vector3(-12,0,8.7),11)
	await shot(game,"forge",Vector3(-8,1,.2),10)
	await shot(game,"archive",Vector3(10,1,-3.5),10)
	print("REFRESH CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

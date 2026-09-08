extends Node
var failures := 0
func check(ok: bool,message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func run(game: Node) -> void:
	await get_tree().create_timer(1).timeout
	var day = game.village_day
	var r = day.residents[0]
	var person = r.npc
	person.routine_managed = true
	person.position = Vector3(-4,0,2)
	check(day.travel(r,"work_0",r.work),"Smith can route back to anvil")
	for i in 900:
		day.step(r,0,1.0/60)
		await get_tree().physics_frame
		if r.state=="working": break
	check(person.position.distance_to(r.work)<.08,"Smith reaches authored hammer position")
	person.play("hammer")
	person.animation.play(person.current_clip,0)
	person.animation.seek(.8,true)
	person.animation.advance(0)
	person.animation.pause()
	game.set_process(false)
	game.ui.hide()
	game.menus.root.hide()
	game.camera.size = 5
	game.camera.position = Vector3(-7.4,1,2.6)+Vector3(2,5,5)
	game.camera.look_at(Vector3(-7.4,1,2.6))
	if DisplayServer.get_name()!="headless":
		for i in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/smith_contact.png")
	print("WORK CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

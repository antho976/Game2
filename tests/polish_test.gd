extends Node
var failures := 0
var rendered := 0
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
func shot(game: Node,id: String,target: Vector3,size: float) -> void:
	game.set_process(false)
	game.camera.size = size
	game.camera.position = target+Vector3(4,5,7)
	game.camera.look_at(target)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/polish_"+id+".png")
	game.set_process(true)
func run(game: Node) -> void:
	RenderingServer.frame_post_draw.connect(func(): rendered+=1)
	await wait(2)
	print("BACKEND ",DisplayServer.get_name()," / ",RenderingServer.get_current_rendering_method())
	game.menus.new_game()
	game.player.position = Vector3(-11.1,.1,4.2)
	await wait(.3)
	game.activities.interact("pond_sit")
	await wait(.5)
	check(game.player.activity == "sit","Pond bench seats player")
	await shot(game,"pond_bench",game.player.position+Vector3(0,.7,0),5)
	Input.action_press("up")
	await wait(.5)
	Input.action_release("up")
	check(game.player.activity.is_empty(),"Pond bench exit restores walking")
	check(game.activities.find_children("*Dock*","Node",true,false).is_empty(),"Pond dock removed")
	game.menus.reset_player(Vector3(0,.1,8))
	game.menus.show_pause()
	game.menus.show_options()
	game.menus.fps_label.show()
	await wait(.4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/polish_settings.png")
	check(game.menus.fps_label.text.ends_with("FPS"),"FPS counter updates")
	game.menus.resume()
	# Hold each direction through full walking cycles while repeatedly switching display modes.
	# Three minutes exceed the last observed freeze at 134 seconds.
	for cycle in (1 if "--quick-check" in OS.get_cmdline_user_args() else 18):
		game.menus.reset_player(Vector3(0,.1,8))
		if cycle in [1,5,10,14]: game.menus.set_fullscreen(cycle in [1,10])
		var before := rendered
		for direction in ["right","up","left","down"]:
			Input.action_press(direction)
			await wait(2.5)
			Input.action_release(direction)
			if cycle==0: await shot(game,"walk_"+direction,game.player.position+Vector3(0,.8,0),4)
		check(rendered>before+100,"Native movement/render soak segment "+str(cycle+1))
	game.menus.set_fullscreen(false)
	DirAccess.remove_absolute(game.menus.save_path)
	DirAccess.remove_absolute(game.menus.settings_path)
	print("POLISH CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

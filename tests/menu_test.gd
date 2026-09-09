extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
func shot(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/menu_"+id+".png")
func finish_lesson(menu: Node) -> void:
	var lesson = menu.classroom
	lesson.elapsed = 2.0
	for i in lesson.lines.size():
		lesson.dialogue.visible_characters = -1
		lesson.advance()
	menu.reset_player(menu.game.school.to_global(Vector3(0,.1,5.6)))
	lesson._process(.01)

func run(game: Node) -> void:
	await wait(2)
	var menu = game.menus
	menu.show_home()
	var yaw: float = game.yaw
	var start: Vector3 = game.player.position
	Input.action_press("right")
	await wait(1)
	Input.action_release("right")
	check(game.yaw>yaw,"Title background rotates")
	check(game.player.position.distance_to(start)<.1,"Menu blocks player movement")
	await shot("title")
	menu.new_game()
	check(is_instance_valid(menu.intro),"New Game opens the cinematic")
	check(get_tree().paused and game.input_blocked,"Cinematic pauses the world and blocks movement")
	menu.intro.finish()
	await wait(.1)
	check(not get_tree().paused and is_instance_valid(menu.classroom),"Skipping cinematic starts the classroom")
	var lesson = menu.classroom
	lesson.elapsed = 2.0
	lesson.advance()
	check(lesson.line_index==0 and lesson.dialogue.visible_characters==-1,"First advance reveals the current line without skipping it")
	var lesson_save := ConfigFile.new()
	lesson_save.load(menu.save_path)
	check(lesson_save.get_value("story","stage")=="classroom","Unfinished lesson is saved for Continue")
	lesson.get_parent().queue_free()
	menu.classroom = null
	get_tree().paused = false
	await wait(.1)
	menu.continue_game()
	check(is_instance_valid(menu.classroom) and not get_tree().paused,"Continue resumes an unfinished classroom lesson")
	finish_lesson(menu)
	await wait(.1)
	check(not get_tree().paused and not game.input_blocked,"Dismissal restores the world and controls")
	check(not game.school.contains(game.player.position),"Player leaves through the schoolhouse location")
	Input.action_press("right")
	await wait(1)
	Input.action_release("right")
	await wait(.3)
	check(game.player.position.x>start.x+1,"New game enables movement")
	menu.play_intro()
	menu.intro.elapsed = float(menu.intro.data.duration)
	menu.intro._process(.01)
	check(is_instance_valid(menu.classroom) and not get_tree().paused,"Natural cinematic completion also starts the lesson")
	finish_lesson(menu)
	check(not get_tree().paused and not game.input_blocked,"Completing the lesson restores control")
	await wait(.1)
	menu.save_game()
	var saved: Vector3 = game.player.last_safe
	game.player.position = Vector3(0,.1,12)
	menu.show_home()
	menu.continue_game()
	check(game.player.position.distance_to(saved)<.1,"Continue restores saved position")
	menu.show_pause()
	check(game.input_blocked,"Pause blocks controls")
	menu.show_options()
	await shot("options")
	if DisplayServer.get_name() != "headless":
		for i in 2:
			menu.set_fullscreen(true)
			await wait(2)
			check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"Fullscreen entered")
			menu.resume()
			var before: Vector3 = game.player.position
			Input.action_press("down")
			await wait(.7)
			Input.action_release("down")
			check(game.player.position.distance_to(before)>.5,"Movement survives fullscreen transition")
			await shot("fullscreen")
			menu.show_pause()
			menu.set_fullscreen(false)
			await wait(1)
			check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"Windowed mode restored")
	menu.resume()
	check(not game.input_blocked and game.ui.visible,"Resume restores HUD and control")
	print("MENU CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

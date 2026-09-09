extends Node
var failures := 0
func check(ok: bool,text: String) -> void:
	print("PASS: " if ok else "FAIL: ",text)
	if not ok:failures+=1
func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/school-"+id+".png")
func run(game: Node) -> void:
	await wait(2)
	var menu=game.menus
	menu.new_game()
	await wait(2)
	check(not menu.intro.audio.playing,"Cinematic narration is disabled")
	check(menu.intro.audio.stream!=null,"Original narration file remains available")
	menu.intro.finish()
	await wait(2)
	var lesson=menu.classroom
	check(is_instance_valid(lesson) and not get_tree().paused,"Classroom runs in the live village")
	check(game.school.get_world_3d()==game.player.get_world_3d(),"School and hub share the same world")
	check(game.school.contains(game.player.position),"Player begins inside the actual school")
	await shot("lesson")
	lesson.line_index=2
	lesson.show_line()
	await wait(2)
	await shot("third-line")
	lesson.line_index=lesson.lines.size()-1
	lesson.dialogue.visible_characters=-1
	lesson.advance()
	await wait(.2)
	check(not game.input_blocked and lesson.mode=="roam","Dismissal enables walking")
	check(game.school.contains(game.player.position),"Dismissal does not teleport the player")
	lesson.ask()
	check(lesson.choices.get_child_count()==6,"Five optional questions plus exit")
	await shot("questions")
	lesson.answer(1)
	check(lesson.dialogue.text==lesson.questions[1][1],"Questions display matching answers")
	check(1 in menu.asked_teacher_questions,"Answered teacher questions are remembered")
	lesson.ask()
	await wait(.15)
	check(lesson.choices.get_child(1).get_meta("asked",false),"Answered question is visually marked and remains available")
	check(not lesson.choices.get_child(1).disabled,"Answered questions can be revisited")
	check(game.player.visible and game.player.model.visible,"Optional teacher conversation shows the real player body")
	check(not game.camera.get_node("FirstPersonHands").visible,"External dialogue camera hides first-person hands")
	var save := ConfigFile.new()
	check(save.load(menu.save_path)==OK and 1 in save.get_value("story","asked_teacher_questions",[]),"Question history is saved to disk")
	lesson.answer(1)
	await wait(.15)
	check(lesson.chatter.stream!=null and lesson.chatter.bus=="Dialogue","Revealing dialogue triggers nonverbal speaker sounds")
	lesson.begin_roam()
	var space=game.get_world_3d().direct_space_state
	var origin: Vector3=game.school.global_position
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3(-4,1.8,-2.5),origin+Vector3(-5.5,1.8,-2.5),1)).is_empty(),"Window opens onto live hub")
	check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3(-4,.5,-2.5),origin+Vector3(-5.5,.5,-2.5),1)).is_empty(),"Wall beneath window blocks movement")
	check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3(0,2,0),origin+Vector3(0,4,0),1)).is_empty(),"Solid ceiling completes room")
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3(2.7,.5,-3.0),origin+Vector3(2.7,.5,-4.3),1)).is_empty(),"Former boundary wall no longer crosses school")
	for x in [-17.0,0.0,4.6,16.0,24.0]:
		check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,.5,-27),Vector3(x,.5,-29),1)).is_empty(),"Expanded northern wall stays continuous at "+str(x))
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3(-6,1.8,-2.5),origin+Vector3(-9,1.8,-2.5),1)).is_empty(),"Window has yard space beyond the school")
	var saved_mode=game.camera_mode
	game.camera_mode=1
	game.camera_height=1.7
	menu.reset_player(origin+Vector3(0,.12,3.3))
	game.update_camera(.016)
	check(is_equal_approx(game.camera.position.y-game.player.position.y,1.7),"First person keeps selected eye height inside")
	menu.reset_player(origin+Vector3(0,.12,5.7))
	game.update_camera(.016)
	check(is_equal_approx(game.camera.position.y-game.player.position.y,1.7),"First person keeps selected eye height outside")
	game.camera_mode=saved_mode
	menu.reset_player(origin+Vector3(-3.7,.12,-2.5))
	game.yaw=PI/2
	await wait(.2)
	await shot("window")
	menu.reset_player(origin+Vector3(0,.12,3.3))
	game.yaw=0
	await wait(.2)
	await shot("inside-door")
	Input.action_press("down")
	await wait(1.4)
	Input.action_release("down")
	await wait(.2)
	check(not game.school.contains(game.player.position),"Player walks through doorway")
	check(menu.story_stage=="done" and not is_instance_valid(menu.classroom),"Opening completes after walking outside")
	await shot("outside")
	Input.action_press("up")
	await wait(2.8)
	Input.action_release("up")
	await wait(.2)
	check(game.school.contains(game.player.position),"Player can reenter school")
	game.input_blocked=true
	game.camera.make_current()
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size=35
	game.camera.position=Vector3(24,24,3)
	game.camera.look_at(Vector3(4,0,-17))
	game.set_process(false)
	await shot("district")
	game.set_process(true)
	game.input_blocked=false
	menu.play_classroom(false)
	check(menu.classroom.mode=="questions","Teacher remains available afterwards")
	menu.classroom.begin_roam()
	menu.release_classroom()
	await wait(.3)
	print("SCHOOL CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

extends Node
var failures := 0
func check(ok: bool,message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func run(game: Node) -> void:
	await get_tree().create_timer(1).timeout
	var menu = game.menus
	menu.new_game()
	for mode in 4:
		menu.camera_preset(mode)
		game.update_camera(1)
		check(game.camera.projection==(Camera3D.PROJECTION_PERSPECTIVE if mode in [1,2] else Camera3D.PROJECTION_ORTHOGONAL),"Projection for mode "+str(mode))
		check(game.player.model.visible==(mode!=1),"Player visibility for mode "+str(mode))
		check(game.camera.position.is_finite(),"Finite camera placement")
		if mode==1:
			check(absf(game.camera.position.y-game.player.position.y-1.65)<.01,"First-person eye height")
		menu.show_pause()
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Menus release the cursor")
		menu.show_camera_options()
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://captures/camera_options_"+str(mode)+".png")
		menu.resume()
		await get_tree().create_timer(.15).timeout
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://captures/camera_view_"+str(mode)+".png")
	menu.camera_preset(2)
	menu.store_option("camera_distance",7.5)
	menu.store_option("camera_height",3.4)
	menu.apply_camera_settings()
	menu.show_pause()
	menu.resume()
	check(is_equal_approx(game.camera_distance,7.5) and is_equal_approx(game.camera_height,3.4),"Resume preserves camera settings")
	var saved := ConfigFile.new()
	saved.load(menu.settings_path)
	check(is_equal_approx(float(saved.get_value("options","camera_distance")),7.5),"Camera preference saved to disk")
	menu.camera_preset(0)
	DirAccess.remove_absolute(menu.settings_path)
	DirAccess.remove_absolute(menu.save_path)
	print("CAMERA CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

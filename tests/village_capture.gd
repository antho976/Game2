extends Node
func capture(game: Node,id: String,target: Vector3,size: float) -> void:
	game.camera.size = size
	game.camera.position = target+Vector3(0,19,15)
	game.camera.look_at(target)
	await get_tree().create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/village_"+id+".png")
func run(game: Node) -> void:
	await get_tree().create_timer(2).timeout
	game.set_process(false)
	game.ui.hide()
	game.village_day.enabled = true
	for r in game.village_day.residents: r.npc.routine_managed = true
	await capture(game,"pond",Vector3(-12,0,8.7),13)
	await capture(game,"laundry",Vector3(-9,1,-5.5),7)
	await capture(game,"garden",Vector3(8.5,0,8),14)
	await capture(game,"portal",Vector3(21,1,-8),11)
	await capture(game,"dummy",Vector3(21.5,0,3),12)
	game.village_day.clock = 20.7*30
	await get_tree().create_timer(25).timeout
	await capture(game,"night",Vector3(3.5,0,-1),50)
	await capture(game,"portal_night",Vector3(21,1,-8),11)
	print("VILLAGE CAPTURES COMPLETE")
	get_tree().quit()

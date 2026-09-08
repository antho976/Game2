extends Node
func shot(game: Node,id: String,target: Vector3,size: float,offset: Vector3) -> void:
	game.camera.size = size
	game.camera.position = target+offset
	game.camera.look_at(target)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png('res://captures/player_'+id+'.png')
func run(game: Node) -> void:
	await get_tree().create_timer(2).timeout
	game.set_process(false)
	game.ui.hide()
	game.player.position = Vector3(4,0,3)
	game.player.facing = 0
	await get_tree().create_timer(.5).timeout
	await shot(game,'idle',game.player.position+Vector3(0,1,0),3.2,Vector3(2,1.8,4))
	game.player.set_physics_process(false)
	game.player.play('walk')
	await get_tree().create_timer(.22).timeout
	game.player.animation.pause()
	print('HERO WALK ',game.player.current,' ',game.player.animation.current_animation_position)
	await shot(game,'walk',game.player.position+Vector3(0,1,0),3.2,Vector3(2,1.8,4))
	await shot(game,'hub',Vector3(13,0,-7),25,Vector3(0,19,15))
	print('PLAYER VISUAL CAPTURES COMPLETE')
	get_tree().quit()

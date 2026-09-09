extends Node
var failures := 0
func check(ok: bool,text: String) -> void:
	print("PASS: " if ok else "FAIL: ",text)
	if not ok: failures+=1
func run(game: Node) -> void:
	await get_tree().create_timer(2).timeout
	game.menus.new_game()
	game.menus.intro.finish()
	game.menus.classroom.begin_roam()
	game.menus.release_classroom()
	var cat: Dictionary={}
	for animal in game.kit.life.animals:
		if animal.kind=="cat":
			cat=animal
			break
	var original: Vector3=cat.body.position
	var friendly: bool=cat.friendly
	for service in game.world.interactions:
		if service.id not in ["smith","archive"]: continue
		game.player.position=service.pos
		cat.body.position=service.pos
		cat.friendly=true
		game.update_interaction()
		check(game.nearest==service.id,"Service wins when cat occupies "+service.id)
		cat.friendly=false
		game.update_interaction()
		check(game.nearest==service.id,"Shy cat cannot obstruct "+service.id)
	game.player.position=Vector3(2,0,7)
	cat.body.position=game.player.position
	cat.friendly=false
	game.update_interaction()
	check(not game.nearest.begins_with("cat:") and not "shy" in game.prompt.text.to_lower(),"Shy cat produces no interaction prompt")
	cat.friendly=true
	game.update_interaction()
	check(game.nearest.begins_with("cat:"),"Friendly cat remains pettable outside service range")
	cat.body.position=original
	cat.friendly=friendly
	await get_tree().create_timer(.3).timeout
	print("INTERACTION CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

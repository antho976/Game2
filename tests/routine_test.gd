extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func run(game: Node) -> void:
	Engine.max_fps = 0
	await get_tree().create_timer(2).timeout
	var day = game.village_day
	game.player.position = Vector3(0,.1,12)
	var exclusive := true
	var conversation := false
	for frame in 10800:
		await get_tree().physics_frame
		var occupied := {}
		var talking := 0
		for r in day.residents:
			if r.job.is_empty() or r.job=="home": continue
			if occupied.has(r.job): exclusive = false
			occupied[r.job] = true
			if r.state == "working" and r.job.begins_with("talk"): talking += 1
		if talking==2: conversation = true
	check(conversation,"Two residents meet for a conversation")
	check(exclusive,"Shared stations have only one assigned resident")
	for job in ["water","garden","birds","cats","ducks","talk_a","talk_b"]:
		check(day.completed.has(job),"Resident reaches activity: "+job)
	for r in day.residents:
		check(is_zero_approx(r.npc.rotation.y),"Moving resident has no inherited sideways rotation: "+str(r.npc.name))
		check(r.arrivals>0,"Resident completes travel: "+str(r.npc.name))
	day.clock = 22*30
	for frame in 9000: await get_tree().physics_frame
	for r in day.residents:
		check(r.state=="inside" and not r.npc.visible and r.npc.collision_layer==0,"Resident enters home at night: "+str(r.npc.name))
	day.clock = 8*30
	for frame in 900: await get_tree().physics_frame
	for r in day.residents: check(r.npc.visible and r.npc.collision_layer==1,"Resident returns in morning: "+str(r.npc.name))
	check(game.kit.find_children("VillagePortal","Node3D",true,false).is_empty(),"Removed portal is absent from eastern courtyard")
	check(game.kit.practice_dummy != null,"Training dummy occupies separate practice ground")
	print("ROUTINE CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

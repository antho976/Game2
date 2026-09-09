extends Node
var failures := 0
var notifications := 0
func check(ok: bool,message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func fund(game: Node) -> void:
	game.equipment.gold=100000
	game.equipment.diamonds=10000
func succeed(gear: Node,uid: int) -> Dictionary:
	var item: Dictionary=gear.owned(uid)
	var rng := RandomNumberGenerator.new()
	for seed_value in 1000:
		rng.seed=seed_value
		if rng.randf()<gear.survival(item):
			gear.rng.seed=seed_value
			break
	return gear.upgrade(uid,item.upgrade)
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/research_"+id+".png")
func run(game: Node) -> void:
	await get_tree().create_timer(1).timeout
	game.research.set_process(false)
	game.menus.new_game()
	var r=game.research
	var gear=game.equipment
	r.finished.connect(func(_message): notifications+=1)
	check(r.slots()==2 and r.projects.is_empty() and gear.diamonds==0,"New game starts with two desks and no free resources")
	check(not r.start("conditioning").is_empty(),"Research cannot start without payment")
	fund(game)
	check(not r.start("potency").is_empty(),"Prerequisites block later branches")
	check(not r.start("hub_plan").is_empty(),"WIP hub studies cannot consume resources")
	var gold: int=gear.gold
	check(r.start("conditioning").is_empty() and gear.gold==gold-50 and gear.diamonds==10000,"Entry study charges gold only")
	check(r.start("metallurgy").is_empty(),"Two projects can run together")
	check(not r.start("appraisal").is_empty(),"A third project requires a free desk")
	r.advance(5)
	check(is_equal_approx(r.projects.conditioning.remaining,10) and is_equal_approx(r.projects.metallurgy.remaining,15),"Each active timer advances independently")
	gold=gear.gold
	r.set_paused("conditioning",true)
	check(r.start("appraisal").is_empty(),"Pausing releases the desk")
	check(not r.set_paused("conditioning",false).is_empty(),"Resuming cannot exceed capacity")
	r.advance(5)
	check(is_equal_approx(r.projects.conditioning.remaining,10),"Paused research retains progress")
	r.set_paused("appraisal",true)
	gold=gear.gold
	check(r.set_paused("conditioning",false).is_empty() and gear.gold==gold,"Resuming does not charge again")
	r.advance(10)
	check(r.completed.get("conditioning")==1 and r.completed.get("metallurgy")==1 and notifications==1,"Concurrent completions apply automatically and notify together")
	check(r.projects.has("appraisal") and r.projects.appraisal.paused,"Other paused work survives completion")
	check(not r.start("conditioning").is_empty(),"Completed single-rank studies cannot be purchased again")
	gear.diamonds=0
	check(r.start("potency").is_empty(),"First equipment study rank uses gold only")
	r.advance(30)
	check(not r.start("potency").is_empty(),"Later rank requires diamonds")
	fund(game)
	var diamonds: int=gear.diamonds
	r.start("potency")
	check(gear.diamonds==diamonds-2,"Later rank deducts its diamond cost")
	var path: String=game.menus.save_path
	game.menus.save_path="user://missing_research_test_dir/save.cfg"
	gold=gear.gold
	check(not r.start("vitality").is_empty() and gear.gold==gold and not r.projects.has("vitality"),"Failed save rolls back research purchase")
	check(not r.set_paused("potency",true).is_empty() and not r.projects.potency.paused,"Failed save rolls back pause")
	var remaining: float=r.projects.potency.remaining
	check(not r.advance(100).is_empty() and r.completed.potency==1 and is_equal_approx(r.projects.potency.remaining,remaining),"Failed completion save restores timer and unearned bonus")
	game.menus.save_path=path
	# Offline progress, pause preservation, and one-time loading.
	var state: Dictionary=r.snapshot()
	state.projects={"potency":{"rank":2,"remaining":60.0,"paused":false},"appraisal":{"rank":1,"remaining":10.0,"paused":true}}
	state.saved_at=Time.get_unix_time_from_system()-40
	r.restore(state)
	r.apply_offline()
	check(absf(r.projects.potency.remaining-50)<.2 and r.projects.appraisal.remaining==10,"Offline progress runs at one quarter speed and respects pause")
	game.menus.continue_game()
	check(absf(r.projects.potency.remaining-50)<.3,"Reloading does not award offline time twice")
	state=r.snapshot()
	state.completed={"organization":1,"conditioning":1}
	state.projects={"fieldnotes":{"rank":1,"remaining":10.0,"paused":false},"vitality":{"rank":1,"remaining":90.0,"paused":false}}
	# Vitality rank 3 has a 120 second duration, so the saved remaining time is valid.
	state.completed.vitality=2
	state.projects.vitality.rank=3
	r.restore(state)
	r.advance(120,true)
	check(absf(r.projects.vitality.remaining-50)<.001,"Offline speed improvement starts at its actual completion time")
	# An existing item keeps every earned gain when potency research completes.
	game.menus.new_game()
	r.set_process(false)
	fund(game)
	gear.buy("warden_blade")
	var uid: int=gear.inventory[-1].uid
	succeed(gear,uid)
	var damage: float=gear.stats(gear.owned(uid)).damage
	r.completed.metallurgy=1
	r.start("potency")
	var quote: Dictionary=gear.upgrade_quote(gear.owned(uid))
	r.advance(30)
	check(gear.stats(gear.owned(uid)).damage==damage,"Potency research never changes existing upgrade gains")
	gold=gear.gold
	check(not gear.upgrade(uid,1,quote).error.is_empty() and gear.gold==gold,"Research finishing during confirmation forces a fresh upgrade quote")
	succeed(gear,uid)
	check(is_equal_approx(gear.owned(uid).earned_gain,.225),"Only the next successful upgrade gains the new research bonus")
	game.menus.save_game()
	game.menus.continue_game()
	check(is_equal_approx(gear.owned(uid).earned_gain,.225),"Per-attempt item gains survive save and Continue")
	# Traverse every available branch through normal start and completion operations.
	fund(game)
	for pass_index in 30:
		var advanced := false
		for def in ResearchCatalog.all():
			if r.start_error(def.id).is_empty():
				r.start(def.id)
				r.advance(600)
				advanced=true
		if not advanced: break
	var complete := true
	for def in ResearchCatalog.all():
		if not def.wip and r.completed.get(def.id,0)!=def.ranks: complete=false
	check(complete,"Every non-WIP branch and rank is reachable through prerequisites")
	check(r.slots()==4 and is_equal_approx(r.offline_rate(),.5),"Research unlocks four desks and improved offline speed")
	check(gear.max_upgrade()==8,"Equipment research extends upgrade limit to plus eight")
	check(is_equal_approx(gear.survival({"upgrade":0}),1) and gear.survival({"upgrade":7})<1,"Early upgrades can become safe while the final upgrade remains risky")
	check(gear.purchase_price("warden_blade")==135 and gear.upgrade_cost({"id":"warden_blade","upgrade":0})==34,"Trade discounts change purchase and upgrade prices")
	check(game.player.combat_stats().health==150 and game.player.combat_stats().stamina==134,"Completed character branches aggregate the planned combat stats")
	while gear.owned(uid).upgrade<8: succeed(gear,uid)
	check(not gear.upgrade(uid,8).error.is_empty(),"Expanded upgrade cap is enforced")
	var legacy := {"gold":1,"inventory":[{"uid":1,"id":"warden_blade","upgrade":2}],"stat_bonus":.05}
	gear.restore(legacy)
	check(is_equal_approx(gear.owned(1).earned_gain,.3),"Legacy upgraded items migrate without losing earned stats")
	# Native visual checks use isolated test saves only.
	game.menus.new_game()
	r.set_process(false)
	fund(game)
	r.start("conditioning")
	r.start("metallurgy")
	r.advance(5)
	game.nearest="archive"
	game.interact()
	check(game.research_menu.active and game.input_blocked,"Research interaction opens the archive and blocks movement")
	await shot("character")
	game.research_menu.tree_index=1
	game.research_menu.selected="limits"
	game.research_menu.refresh()
	await shot("equipment")
	if DisplayServer.get_name()!="headless":
		var original_size := DisplayServer.window_get_size()
		DisplayServer.window_set_size(Vector2i(960,600))
		await get_tree().create_timer(.3).timeout
		await shot("compact")
		check(game.research_menu.root.get_combined_minimum_size().x<=960,"Research fits a compact window with scrollable tree and details")
		DisplayServer.window_set_size(original_size)
		await get_tree().create_timer(.3).timeout
	game.research_menu.tree_index=4
	game.research_menu.refresh()
	await shot("hub_wip")
	r.advance(20)
	game.research_menu.tree_index=5
	game.research_menu.refresh()
	await shot("journal")
	check(not r.journal.is_empty() and game.research_menu.toast_panel.visible,"Completions remain visible in notifications and journal")
	r.acknowledge()
	check(not r.journal[0].unread,"Journal notifications can be acknowledged")
	game.research_menu.close()
	check(not game.input_blocked,"Leaving research restores player control")
	game.menus.new_game()
	check(r.completed.is_empty() and r.projects.is_empty() and r.slots()==2,"New Game resets research and slots")
	DirAccess.remove_absolute(game.menus.save_path)
	DirAccess.remove_absolute(game.menus.settings_path)
	print("RESEARCH CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

extends Node
var failures := 0
func check(ok: bool,text: String) -> void:
	print("PASS: " if ok else "FAIL: ",text)
	if not ok: failures+=1
func shot(game: Node,id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/shop_"+id+".png")
func run(game: Node) -> void:
	await get_tree().create_timer(1).timeout
	game.menus.new_game()
	var gear = game.equipment
	check(gear.gold==0 and gear.level==1,"New game has no debug currency or levels")
	check(not gear.buy("warden_blade").is_empty() and gear.inventory.is_empty(),"Insufficient gold cannot purchase")
	gear.gold = 20000
	check(not gear.buy("citadel_blade").is_empty() and gear.gold==20000,"Level requirements are enforced")
	gear.level = 10
	check(gear.buy("warden_blade").is_empty(),"Purchase succeeds")
	var first: int = gear.inventory[-1].uid
	gear.buy("warden_blade")
	var duplicate: int = gear.inventory[-1].uid
	check(first!=duplicate and gear.inventory.size()==2,"Duplicate purchases have distinct identities")
	check(gear.equip(first).is_empty(),"Owned weapon equips")
	for slot in ["helmet","chest","gloves","boots"]:
		gear.buy("warden_"+slot)
		gear.equip(gear.inventory[-1].uid)
	check(gear.equipped.size()==5,"All five slots equip independently")
	check(game.player.model.find_children("GearMount*","BoneAttachment3D",true,false).size()>5,"Equipped armor attaches to the animated player")
	var unchanged: int = gear.gold
	check(not gear.equip(999999).is_empty() and gear.gold==unchanged,"Unowned item cannot equip")
	gear.survival_bonus = 1
	var before: float = gear.stats(gear.owned(first)).damage
	var cost: int = gear.upgrade_cost(gear.owned(first))
	var result: Dictionary = gear.upgrade(first,0)
	check(result.error.is_empty() and result.survived and gear.gold==unchanged-cost,"Successful upgrade charges exact gold")
	check(gear.stats(gear.owned(first)).damage>before and gear.owned(duplicate).upgrade==0,"Upgrade changes only its own copy")
	unchanged = gear.gold
	check(not gear.upgrade(first,0).error.is_empty() and gear.gold==unchanged,"Stale upgrade confirmation cannot spend gold")
	for rank in range(1,5):
		# Higher upgrades retain risk even with large survival bonuses.
		var success_probe := RandomNumberGenerator.new()
		for seed_value in 1000:
			success_probe.seed=seed_value
			if success_probe.randf()<gear.survival(gear.owned(first)):
				gear.rng.seed=seed_value
				break
		gear.upgrade(first,rank)
	check(not gear.upgrade(first,5).error.is_empty(),"Upgrade cap is enforced")
	gear.survival_bonus = 0
	gear.equip(duplicate)
	var probe := RandomNumberGenerator.new()
	for seed_value in 1000:
		probe.seed = seed_value
		if probe.randf()>.85:
			gear.rng.seed = seed_value
			break
	var failure_gold: int = gear.gold
	var failure_cost: int = gear.upgrade_cost(gear.owned(duplicate))
	result = gear.upgrade(duplicate,0)
	check(gear.gold==failure_gold-failure_cost,"Destruction still consumes the displayed gold cost")
	check(result.error.is_empty() and not result.survived,"First upgrade can permanently fail")
	check(gear.owned(duplicate).is_empty() and not gear.equipped.has("weapon") and not gear.owned(first).is_empty(),"Breakage removes only the destroyed copy and clears its slot")
	gear.equip(first)
	var state: Dictionary = gear.snapshot()
	game.menus.save_game()
	gear.restore({})
	game.menus.continue_game()
	check(gear.snapshot()==state,"Gold, level, owned copies, upgrades and slots survive Continue")
	var path: String = game.menus.save_path
	game.menus.save_path = "user://missing_shop_test_directory/save.cfg"
	state = gear.snapshot()
	check(not gear.buy("warden_blade").is_empty() and gear.snapshot()==state,"Save failure rolls purchase back")
	check(not gear.upgrade(gear.equipped.helmet,0).error.is_empty() and gear.snapshot()==state,"Save failure restores an attempted upgrade")
	game.menus.save_path = path
	game.nearest = "smith"
	game.interact()
	check(game.input_blocked,"Shop blocks movement")
	await shot(game,"stock")
	GearVisuals.apply(game.smith_shop.preview,{"helmet":GearCatalog.find("warden_helmet")})
	await shot(game,"helmet")
	check(game.smith_shop.preview.find_children("GearMount*","BoneAttachment3D",true,false).size()==1,"Changing preview removes every previous armor attachment")
	game.smith_shop.refresh()
	game.smith_shop.page = "upgrade"
	game.smith_shop.selected_uid = gear.equipped.helmet
	game.smith_shop.refresh()
	await shot(game,"upgrade")
	game.smith_shop.request_upgrade()
	check(game.smith_shop.confirm.visible,"Destructive upgrades require a displayed confirmation")
	await shot(game,"confirm")
	game.smith_shop.confirm.hide()
	game.smith_shop.close()
	check(not game.input_blocked,"Leaving shop restores movement")
	game.set_process(false)
	game.ui.hide()
	game.player.position = Vector3(4,0,3)
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 3.0
	game.camera.position = game.player.position+Vector3(2,2.4,4)
	game.camera.look_at(game.player.position+Vector3(0,1,0))
	await shot(game,"armor")
	for slot in ["helmet","chest","gloves","boots","blade"]:
		gear.buy("citadel_"+slot)
		gear.equip(gear.inventory[-1].uid)
	await shot(game,"citadel")
	game.camera_mode = 1
	game.camera_height = 1.65
	game.update_camera(1)
	await shot(game,"first_person")
	var legacy := ConfigFile.new()
	legacy.set_value("hub","position",Vector3(4,.1,3))
	legacy.save(game.menus.save_path)
	game.menus.continue_game()
	check(gear.inventory.is_empty() and gear.gold==0,"Legacy hub saves migrate without granting equipment")
	game.menus.new_game()
	check(gear.inventory.is_empty() and gear.equipped.is_empty(),"New Game clears previous equipment")
	DirAccess.remove_absolute(game.menus.save_path)
	DirAccess.remove_absolute(game.menus.settings_path)
	print("SHOP CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

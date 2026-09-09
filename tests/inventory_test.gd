extends Node
var failures:=0
func check(ok: bool,label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func wait(seconds:=.2) -> void:await get_tree().create_timer(seconds).timeout
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await wait(.3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/inventory-"+id+".png")
func key(code: int) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await wait()
	event=InputEventKey.new()
	event.physical_keycode=code
	Input.parse_input_event(event)
func run(game: Node) -> void:
	await wait(.5)
	game.menus.resume()
	game.menus.story_stage="done"
	var gear: Node=game.equipment
	gear.restore({})
	game.menus.save_game()
	var inventory: Node=game.inventory_menu
	await key(KEY_I)
	check(inventory.active and game.input_blocked,"I opens an empty inventory and blocks movement")
	await shot("empty")
	await key(KEY_ESCAPE)
	check(not inventory.active and not game.input_blocked and not game.menus.active,"Escape closes inventory without opening pause")
	game.smith_shop.open()
	await shot("starter-offer")
	var offer: Button
	# The offer sits on the shop's action rail and is set in display caps.
	for button in game.smith_shop.root.find_children("*","Button",true,false):
		if button.text.to_lower().begins_with("accept starter"):offer=button
	check(offer!=null,"Blacksmith presents a free starter offer to a fresh character")
	var path: String=game.menus.save_path
	game.menus.save_path="user://missing-inventory-folder/save.cfg"
	check(not gear.claim_starter().is_empty() and not gear.starter_claimed and gear.inventory.is_empty(),"Failed save rolls back both starter item and claim flag")
	game.menus.save_path=path
	if offer:offer.pressed.emit()
	check(gear.starter_claimed and gear.gold==0 and gear.inventory.size()==1 and gear.equipped.weapon==gear.inventory[0].uid,"Free starter is owned and equipped with zero gold")
	var starter: int=gear.inventory[0].uid
	check(not gear.claim_starter().is_empty() and gear.inventory.size()==1,"Starter cannot be claimed twice")
	var saved:=ConfigFile.new()
	saved.load(path)
	gear.restore(saved.get_value("equipment","state"))
	check(gear.starter_claimed and not gear.claim_starter().is_empty(),"Claim survives save and reload")
	game.smith_shop.close()
	gear.gold=5000
	gear.level=6
	for id in ["warden_blade","pilgrim_blade","citadel_blade","warden_helmet","warden_chest","warden_gloves","warden_boots"]:gear.buy(id)
	var duplicate: int=gear.inventory[1].uid
	gear.owned(duplicate).upgrade=2
	gear.owned(duplicate).earned_gain=.2
	gear.skill_points=4
	gear.learn_combat("poise")
	gear.learn_combat("riposte")
	gear.learn_combat("footwork")
	gear.learn_combat("pursuit")
	await key(KEY_I)
	check(inventory.cards.size()==8,"Inventory grid shows distinct owned copies")
	inventory.selected=duplicate
	inventory.refresh()
	inventory.toggle_item()
	check(gear.equipped.weapon==duplicate and gear.owned(starter).upgrade==0,"Equipping an upgraded duplicate keeps the other copy intact")
	inventory.toggle_item()
	check(not gear.equipped.has("weapon"),"Inventory can unequip a weapon")
	inventory.toggle_item()
	for item in gear.inventory:
		if GearCatalog.find(item.id).slot!="weapon":
			inventory.selected=item.uid
			inventory.toggle_item()
	check(gear.equipped.size()==5,"Inventory equips weapon and all four armor slots")
	inventory.filter_slot="helmet"
	inventory.refresh()
	check(inventory.cards.size()==1,"Slot filter limits the item grid")
	inventory.filter_slot="all"
	inventory.sort_mode=2
	inventory.selected=duplicate
	inventory.refresh()
	check(inventory.cards[0].get_meta("item_uid")==duplicate,"Upgrade sorting places the strongest tempered copy first")
	game.menus.save_path="user://missing-inventory-folder/save.cfg"
	inventory.toggle_item()
	check(gear.equipped.weapon==duplicate,"Failed inventory save preserves equipped gear")
	game.menus.save_path=path
	if DisplayServer.get_name()!="headless":
		# Item icons are rendered from the real gear; wait for the forge.
		if not inventory.thumbnails.ready_for_use: await inventory.thumbnails.finished
		inventory.refresh()
		for size in [Vector2i(1080,720),Vector2i(1440,900),Vector2i(1920,1080)]:
			DisplayServer.window_set_size(size)
			await wait(.6)
			await shot("gear-%d"%size.x)
			check(inventory.details.get_global_rect().end.x<=game.get_viewport().get_visible_rect().size.x,"Inventory detail fits viewport at %d"%size.x)
		DisplayServer.window_set_size(Vector2i(1440,900))
	inventory.close()
	await wait()
	var c: Node=game.combat
	check(c.player_hud.dock.visible and c.health_bar.value>0,"Player health and stamina dock remains visible outside combat")
	check(c.player_hud.skill_slots.is_empty() and c.player_hud.dock.size.y<90,"Player HUD is compact without the removed skill and shortcut rows")
	await shot("hub-hud")
	game.player.position=c.CENTER+Vector3(0,.1,2)
	game.camera_target=game.player.position
	c.start()
	c.set_physics_process(false)
	await wait(.5)
	await key(KEY_I)
	check(not inventory.active and c.active,"Inventory cannot swap equipment during a fight")
	c.hero.health=63
	c.hero.stamina=42
	c.foe.health=87
	await wait()
	check(c.health_bar.value==63 and c.stamina_bar.value==42 and c.foe_health_bar.value==87,"Combat meters follow separate hero and enemy values")
	await shot("combat-hud")
	check(c.player_hud.enemy_plate.visible,"Enemy health bar is projected above a visible opponent")
	var projected: Vector2=game.camera.unproject_position(c.enemy.global_position+Vector3(0,2.65,0))
	check(c.player_hud.enemy_plate.get_global_rect().end.y<=projected.y,"Enemy plate sits above the head anchor")
	c.stop("Test complete")
	gear.inventory.erase(gear.owned(starter))
	check(not gear.claim_starter().is_empty(),"Losing the original weapon does not reset the one-time offer")
	gear.restore({})
	check(not gear.starter_claimed and gear.inventory.is_empty(),"New-character state resets starter claim and inventory")
	await wait(1.5)
	print("INVENTORY CHECKS COMPLETE: ",failures," failures")
	get_tree().quit(1 if failures else 0)

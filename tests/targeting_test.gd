extends Node
var failures:=0
func check(ok: bool,label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func wait(seconds:=.2) -> void:await get_tree().create_timer(seconds).timeout
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await wait(.25)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/targeting-"+id+".png")
func run(game: Node) -> void:
	await wait(.5)
	game.menus.resume()
	game.menus.story_stage="done"
	game.equipment.restore({})
	game.equipment.claim_starter()
	game.sword_drawn=false
	game.refresh_equipment()
	var c: Node=game.combat
	check(not is_instance_valid(c.hero_sword),"Sheathed state has no duplicate sword in the hand")
	c.toggle_weapon()
	await wait()
	check(game.sword_drawn and is_instance_valid(c.hero_sword),"Sword can be drawn while exploring")
	await shot("drawn")
	c.toggle_weapon()
	await wait()
	check(not game.sword_drawn and not is_instance_valid(c.hero_sword),"Sword can be sheathed while exploring")
	await shot("sheathed")
	game.menus.store_option("lock_mode",1)
	game.menus.apply_camera_settings()
	check(game.lock_mode==1,"Hard-lock option applies")
	game.lock_mode=0
	game.menus.settings.load(game.menus.settings_path)
	game.menus.apply_camera_settings()
	check(game.lock_mode==1,"Targeting preference survives a settings reload")
	game.menus.store_option("lock_mode",0)
	game.menus.apply_camera_settings()
	var exp: Node=game.expedition
	exp.enter()
	for i in 300:
		await get_tree().process_frame
		if exp.ready_to_fight:break
	exp.set_physics_process(false)
	check(exp.foes.size()==8,"Eight Wardens occupy the mine rooms")
	game.player.position=exp.OFFSET+Vector3(3,.1,-21)
	game.player.last_safe=game.player.position
	game.camera_target=game.player.position
	exp.engage(0)
	c=game.combat
	c.set_physics_process(false)
	check(not game.sword_drawn and not c.attack(false),"Aggro respects a sheathed sword and cannot attack invisibly")
	c.toggle_weapon()
	check(game.sword_drawn and c.attack(false),"Drawing during combat enables attacks")
	c.toggle_weapon()
	check(game.sword_drawn and c.pending_sheath,"Sheathing waits for a committed attack to finish")
	c.hero.phase="idle"
	c._physics_process(0)
	check(not game.sword_drawn and not c.pending_sheath,"Queued sheath completes on returning to idle")
	c.toggle_weapon()
	c.hero.phase="idle"
	c.hero.health=61
	c.hero.stamina=43
	c.foe.health=57
	c.foe.exhaust=35
	c.foe.phase="recovery"
	c.foe.timer=.32
	await wait(.5)
	var screen: Vector2=game.camera.unproject_position(exp.foes[3].model.global_position+Vector3(0,1.2,0))
	check(exp.aim_target(screen)==3,"Pointing at another visible enemy selects that enemy")
	var from: Vector3=game.player.position
	var motion:=InputEventMouseMotion.new()
	motion.position=screen
	motion.global_position=screen
	Input.parse_input_event(motion)
	await get_tree().process_frame
	exp.update_targeting(.2)
	exp.update_targeting(.2)
	check(exp.target==3 and c.hero.health==61 and c.hero.stamina==43 and game.player.position==from,"Target switch preserves hero vitals and position")
	check(exp.foes[0].health==57 and exp.foes[0].model.visible,"Previous enemy retains damage and remains in the room")
	exp.switch_target(0)
	check(c.foe.health==57 and c.foe.exhaust==35 and c.foe.phase=="recovery" and is_equal_approx(c.foe.timer,.32),"Returning to a target preserves its exhaustion and recovery state")
	game.lock_mode=1
	exp.switch_target(3)
	check(exp.target==0,"Hard lock refuses to jump to a different enemy")
	var lock_key:=InputEventKey.new()
	lock_key.physical_keycode=KEY_T
	lock_key.pressed=true
	c._input(lock_key)
	check(not game.lock_enabled,"T releases a hard lock")
	c._input(lock_key)
	check(game.lock_enabled and exp.target==3,"T reacquires the pointed enemy explicitly in hard-lock mode")
	exp.switch_target(0,true)
	game.camera_mode=1
	game.camera_height=1.65
	game.yaw=1
	c.hero.phase="idle"
	c.foe.phase="idle"
	c._physics_process(.1)
	check(absf(game.yaw-1)>.01,"Hard lock steers first-person view toward its fixed enemy")
	game.lock_mode=0
	game.yaw=1
	c._physics_process(.1)
	check(is_equal_approx(game.yaw,1),"Aim mode leaves first-person looking under player control")
	game.camera_mode=0
	game.camera_height=19
	game.yaw=0
	c.hero.phase="windup"
	exp.switch_target(3)
	check(exp.target==0,"A target change cannot redirect a committed player swing")
	c.hero.phase="idle"
	c.foe.phase="windup"
	c.foe.attack_dir=1
	c.foe.total=1
	c.foe.timer=.12
	await wait(.4)
	await shot("arrows-and-hud")
	check(c.player_hud.dock.size.y<90 and c.player_hud.dock.size.x<=470,"Health and stamina dock is compact")
	check(c.player_hud.skill_slots.is_empty(),"Removed bottom rows are absent")
	game.lock_enabled=false
	exp.switch_target(3)
	check(exp.target==0,"Released lock does not auto-switch")
	game.lock_enabled=true
	exp.cleared.append(3)
	check(exp.aim_target(screen)!=3,"Dead enemies cannot be selected")
	game.camera_mode=1
	game.camera_height=1.65
	game.yaw=c.lock_yaw()
	c.hero.phase="idle"
	await shot("drawn-first-person")
	c.toggle_weapon()
	await shot("sheathed-first-person")
	check(not game.camera.get_node("FirstPersonHands").has_node("HeldGreatsword"),"First-person sword is removed when sheathed")
	c.toggle_weapon()
	game.camera_mode=0
	game.camera_height=19
	c.stop("Check complete")
	exp.leave()
	await wait(.5)
	check(game.sword_drawn and is_instance_valid(game.combat.hero_sword),"Drawn sword carries back to the hub without orphaned visuals")
	check(game.player.model.get_children().filter(func(child):return child.get_meta("player_weapon",false)).size()==1,"Returning leaves exactly one drawn player sword")
	game.combat.toggle_weapon()
	await wait(.3)
	check(not is_instance_valid(game.combat.hero_sword),"Returned sword can still be sheathed")
	print("TARGETING CHECKS COMPLETE: ",failures," failures")
	await wait(1)
	get_tree().quit(1 if failures else 0)

extends Node
var failures := 0
func check(ok: bool,text: String) -> void:
	print("PASS: " if ok else "FAIL: ",text)
	if not ok:failures+=1
func frames(count := 3) -> void:
	for i in count:await get_tree().physics_frame
func ready(exp: Node) -> void:
	for i in range(300):
		if exp.active and exp.ready_to_fight:return
		await get_tree().process_frame
	check(false,"Expedition became ready")
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/expedition-"+id+".png")
func engage(game: Node,index: int) -> void:
	var exp=game.expedition
	game.player.position=exp.OFFSET+exp.foes[index].pos+Vector3(0,.1,2)
	game.player.last_safe=game.player.position
	game.camera_target=game.player.position
	exp.engage(index)
	exp.battle.set_physics_process(false)
	await frames()
func kill_warden(game: Node,index: int) -> void:
	await engage(game,index)
	var c=game.combat
	c.foe.health=1
	c.foe.blocking=false
	c.foe.phase="recovery"
	c.hero.attack_dir=1
	c.hero.heavy=false
	var outcome: String=c.resolve_hit(true)
	await frames()
func run(game: Node) -> void:
	await frames(4)
	game.menus.resume()
	game.menus.story_stage="done"
	game.equipment.restore({})
	game.equipment.claim_starter()
	if not game.sword_drawn:game.combat.toggle_weapon()
	game.menus.save_game()
	var exp=game.expedition
	var trainer=game.combat
	game.player.position=exp.RETURN
	game.camera_target=game.player.position
	game.update_interaction()
	check(game.nearest=="mine_portal","Hub portal is reachable through the normal interaction priority")
	await shot("hub-gate")
	game.interact()
	await ready(exp)
	exp.set_physics_process(false)
	check(exp.active and game.combat.encounter_mode and not game.world.visible,"Portal loads the mine with the encounter combat controller")
	check(game.combat.enemy_sword.scene_file_path.ends_with("mining_blade.glb"),"Warden holds the authored mining blade")
	check(trainer.process_mode==Node.PROCESS_MODE_DISABLED,"Village sparring is suspended during the expedition")
	game.menus.save_game()
	var data:=ConfigFile.new()
	data.load(game.menus.save_path)
	check(data.get_value("hub","position")==exp.RETURN,"Autosave never writes a dungeon position into the hub spawn")
	await engage(game,0)
	var c=game.combat
	c.hero.blocking=true
	c.hero.guard=1
	c.hero.block_age=.1
	c.foe.attack_dir=1
	var stamina: float=c.hero.stamina
	check(c.resolve_hit(false)=="perfect" and c.hero.stamina==stamina,"Claude's perfect directional block costs no stamina against the Warden")
	c.hero.blocking=false
	c.dodge_time=.15
	check(c.resolve_hit(false)=="dodge","Claude's quickstep invulnerability applies in the expedition")
	c.dodge_time=0
	c.hero.health=65
	c.foe.health=40
	c.foe.phase="idle"
	await shot("warden-combat")
	# The same hit resolver must reject scenery between the combatants.
	game.player.position=exp.OFFSET+Vector3(-6,.1,-24)
	c.enemy.position=exp.OFFSET+Vector3(-.2,.1,-24)
	check(not c.clear_strike_path(),"The screening machine blocks strike line of sight")
	game.player.position=exp.OFFSET+Vector3(-5,.1,-24)
	c.enemy.position=exp.OFFSET+Vector3(-2.6,.1,-24)
	check(c.resolve_hit(true)=="obstructed","A close attack cannot damage through the screening machine")
	var direction: Vector3=exp.chase_direction(exp.OFFSET+Vector3(-7,0,-24),exp.OFFSET+Vector3(1,0,-24))
	check(direction.length()>.5 and exp.path.size()>5,"Warden navigation finds a route around the machinery")
	game.player.position=c.encounter_origin+Vector3(0,0,11)
	game.player.last_safe=game.player.position
	c.enemy.position=c.encounter_origin
	c._physics_process(.016)
	await frames()
	check(not c.active and exp.returning and exp.health==65 and exp.foes[0].health==40,"Retreat preserves damage and sends the Warden toward its post")
	game.menus.save_game()
	game.menus.show_home()
	check(not exp.active and game.world.visible,"Main menu restores the hub scene while keeping the expedition saved")
	game.menus.continue_game()
	await ready(exp)
	exp.set_physics_process(false)
	check(exp.health==65 and exp.foes[0].health==40,"Continue restores hero and Warden health")
	await kill_warden(game,0)
	check(0 in exp.cleared and exp.pending.gold==25 and game.equipment.gold==0,"A defeated Warden adds unbanked loot without changing the wallet")
	game.combat.finish(true)
	await frames()
	check(exp.pending.gold==25,"Repeated completion cannot duplicate the Warden reward")
	await engage(game,1)
	c=game.combat
	c.hero.health=1
	c.hero.blocking=false
	c.hero.phase="idle"
	c.foe.attack_dir=2
	c.foe.heavy=true
	c.resolve_hit(false)
	await frames()
	check(not exp.active and game.player.position.distance_to(exp.RETURN)<.5,"Defeat returns the player through the village gate")
	check(game.equipment.gold==0 and exp.pending.gold==0 and exp.snapshot().is_empty(),"Defeat discards the run haul and does not duplicate saved loot")
	check(game.combat==trainer and game.world.visible,"Defeat restores the original sparring controller and hub")
	exp.enter()
	await ready(exp)
	exp.set_physics_process(false)
	for i in range(exp.foes.size()):await kill_warden(game,i)
	check(exp.cleared.size()==8,"All eight regular Warden encounters can be completed without a boss")
	for i in exp.mine.markers.size():
		if exp.mine.markers[i].kind!="seam":continue
		game.player.position=exp.OFFSET+exp.mine.markers[i].pos
		exp.interact()
		exp._process(2.0)
		exp.interact()
		exp._process(2.0)
	check(exp.pending.essence==12 and exp.harvested.size()==3,"Each guarded vein yields one small harvest, not duplicate rewards")
	game.menus.save_game()
	game.menus.show_home()
	game.menus.continue_game()
	await ready(exp)
	exp.set_physics_process(false)
	check(exp.cleared.size()==8 and exp.harvested.size()==3 and exp.pending.gold==480,"Continue preserves cleared enemies, exhausted samples and the unbanked haul")
	var valid_path: String=game.menus.save_path
	game.menus.save_path="user://missing-expedition-test-folder/save.cfg"
	check(not exp.bank_and_return() and exp.active and game.equipment.gold==0 and exp.pending.gold==480,"A failed bank save rolls back the wallet and retains the haul")
	game.menus.save_path=valid_path
	check(exp.bank_and_return(),"The return gate successfully commits the haul")
	check(game.equipment.gold==480 and game.equipment.diamonds==4 and game.equipment.life_essence==12 and game.equipment.level>1,"Banked loot drives the existing gold, research currency and level systems")
	data.load(valid_path)
	check(data.get_value("expedition","state",{}).is_empty(),"Successful banking atomically clears the saved expedition")
	game.menus.show_home()
	game.menus.continue_game()
	await frames()
	check(not exp.active and game.equipment.gold==480,"Reloading after banking cannot replay expedition rewards")
	game.player.position=trainer.CENTER+Vector3(0,.1,2)
	trainer.start()
	check(trainer.active and not trainer.encounter_mode,"The village swordsman can still start a normal sparring bout")
	trainer.stop("Test complete")
	# Let the real encounter scheduler and physics run, without forcing a hit.
	exp.enter()
	await ready(exp)
	exp.set_physics_process(true)
	game.player.position=exp.OFFSET+exp.foes[0].pos+Vector3(0,.1,4)
	game.player.last_safe=game.player.position
	await get_tree().create_timer(1.2).timeout
	check(exp.battle.active,"Approaching a Warden starts combat through live proximity and sight")
	c=exp.battle
	c.hero.blocking=true
	c.hero.guard=1
	await get_tree().create_timer(5.0).timeout
	check(c.active and c.foe_swings>=1 and c.enemy.position.distance_to(game.player.position)<3.5 and c.enemy.position.y>-.2,"Live Warden closes distance and attacks while remaining on the mine floor")
	game.camera_mode=1
	game.camera_height=1.65
	await shot("first-person-combat")
	game.camera_mode=0
	game.camera_height=19
	game.player.position=exp.OFFSET+Vector3(3,.1,-8)
	game.player.last_safe=game.player.position
	await get_tree().create_timer(8).timeout
	check(not c.active and not exp.returning and exp.foes[0].model.visible,"Live retreat returns the Warden to its post without teleporting the player")
	exp.leave()
	await get_tree().create_timer(1.5).timeout
	print("EXPEDITION TESTS COMPLETE: ",failures," failures")
	get_tree().quit(1 if failures else 0)

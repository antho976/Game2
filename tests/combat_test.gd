extends Node
var failures := 0
func check(ok: bool,text: String) -> void:
	print("PASS: " if ok else "FAIL: ",text)
	if not ok: failures+=1
func wait(t: float) -> void: await get_tree().create_timer(t).timeout
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/combat-"+id+".png")
func run(game: Node) -> void:
	await wait(2)
	game.menus.new_game()
	game.menus.intro.finish()
	game.menus.classroom.begin_roam()
	game.menus.release_classroom()
	game.menus.story_stage="done"
	var c=game.combat
	c.start()
	c.set_physics_process(false)
	check(c.active and game.equipment.inventory.is_empty(),"Practice loan starts combat without adding inventory")
	for direction in 4:
		check(CombatRules.defence(direction,direction,true,.1,0,18)=="perfect","Matching timely guard works in lane "+str(direction))
		check(CombatRules.defence(direction,(direction+1)%4,true,.1,100,18)=="hit","Wrong direction never blocks")
	check(CombatRules.defence(0,0,true,.5,100,18)=="block","Late matching guard costs stamina")
	check(CombatRules.defence(0,0,true,.5,0,18)=="break","Empty guard breaks")
	c.hero.blocking=false
	c.block(true)
	c.hero.block_age=.4
	c.set_guard(2)
	check(c.hero.block_age==.4,"Changing direction cannot renew the perfect window")
	c.block(false)
	c.block(true)
	check(c.hero.block_age>1,"Rapid guard tapping cannot renew perfect block")
	game.player.position=c.enemy.position+Vector3(0,0,2)
	c.hero.phase="idle"
	c.hero.blocking=true
	c.hero.guard=1
	c.hero.block_age=.1
	c.foe.attack_dir=1
	var stamina: float=c.hero.stamina
	check(c.resolve_hit(false)=="perfect" and c.hero.stamina==stamina,"Perfect block costs zero stamina")
	check(c.foe.timer>=1 and c.foe.exhaust==38 and c.hero.counter>0,"Perfect block opens counter window and builds exhaustion")
	c.foe.phase="idle"
	c.foe.blocking=true
	c.foe.guard=3
	c.foe.block_age=99
	c.hero.attack_dir=3
	c.hero.heavy=false
	var health: float=c.foe.health
	check(c.resolve_hit(true)=="block" and c.foe.health==health,"Attacking the existing enemy guard does no health damage")
	c.foe.phase="idle"
	c.foe.blocking=true
	c.hero.attack_dir=0
	check(c.resolve_hit(true)=="hit" and c.foe.health<health,"Unguarded direction deals damage")
	c.hero.phase="idle"
	c.hero.stamina=0
	check(not c.attack(false) and not c.quickstep(),"Cannot attack or dodge without stamina")
	c.hero.stamina=100
	check(c.quickstep() and c.hero.stamina==76,"Quickstep consumes stamina")
	c.dodge_time=.15
	c.foe.attack_dir=2
	check(c.resolve_hit(false)=="dodge","Quickstep avoids impact during its invulnerability window")
	c.dodge_time=0
	c.hero.phase="idle"
	c.hero.blocking=true
	c.hero.guard=2
	c.hero.block_age=.1
	c.foe.exhaust=80
	c.resolve_hit(false)
	check(c.foe.phase=="exhausted" and c.foe.timer==3,"Repeated parries exhaust the attacker")
	c.foe.phase="idle"
	c.foe.blocking=false
	c.foe.health=1
	c.hero.critical=false
	c.hero.attack_dir=0
	c.resolve_hit(true)
	check(not c.active and game.equipment.xp==60 and game.equipment.gold==25,"Victory awards XP and gold exactly once")
	check(game.equipment.award_combat(60,25).is_empty(),"Progression rewards persist")
	check(game.equipment.level==2 and game.equipment.xp==20 and game.equipment.skill_points==1,"XP advances level and awards one skill point")
	check(c.stats().health==106 and c.stats().stamina==104,"Levels raise stats automatically")
	check(not game.equipment.learn_combat("riposte").is_empty(),"Skill prerequisites enforced")
	check(game.equipment.learn_combat("poise").is_empty(),"Passive skill can be purchased")
	game.equipment.award_combat(140,0)
	check(game.equipment.learn_combat("riposte").is_empty(),"Preceding passive unlocks the critical combat move")
	var saved: Dictionary=game.equipment.snapshot()
	game.equipment.restore({})
	game.equipment.restore(saved)
	check(game.equipment.level==3 and "riposte" in game.equipment.combat_skills,"XP, points and skills survive restoration")
	c.respawn=0
	c.start()
	c.hero.counter=1.0
	c.hero.counter_dir=3
	c.hero.guard=3
	check(c.attack(false) and c.hero.critical,"Correct directional counter enables learned critical strike")
	c.hero.phase="idle"
	c.hero.counter=1.0
	c.hero.guard=0
	check(c.attack(false) and not c.hero.critical,"Wrong directional counter remains an ordinary attack")
	# Feints, pulls, clashes, interrupts, chip damage, forms and input buffering.
	c.hero.phase="idle"
	c.hero.counter=0
	c.hero.stamina=100
	c.hero.guard=0
	check(c.attack(false),"Attack begins from the selected lane")
	var total: float=c.hero.total
	c.hero.timer=total*.8
	var before: float=c.hero.stamina
	c.set_guard(1)
	check(c.hero.attack_dir==1 and c.hero.feinted and c.hero.stamina==before-6 and is_equal_approx(c.hero.timer,total*.55),"Changing lane early in a swing feints into the new lane")
	c.set_guard(2)
	check(c.hero.attack_dir==1,"A swing can only feint once")
	c.hero.phase="idle"
	c.hero.guard=0
	c.attack(false)
	c.hero.timer=c.hero.total*.3
	c.set_guard(3)
	check(c.hero.attack_dir==0,"A committed swing cannot change lane")
	c.hero.phase="idle"
	c.attack(false)
	c.hero.timer=c.hero.total*.9
	before=c.hero.stamina
	c.block(true)
	check(c.hero.phase=="idle" and c.hero.blocking and c.hero.block_age>1 and c.hero.stamina==before-4,"Guarding early in a swing pulls the blow without a perfect window")
	c.block(false)
	c.hero.phase="windup"
	c.hero.attack_dir=1
	c.hero.heavy=false
	c.hero.critical=false
	c.hero.combo=""
	c.foe.phase="windup"
	c.foe.attack_dir=1
	c.foe.total=1.0
	c.foe.timer=.3
	c.foe.blocking=false
	health=c.foe.health
	check(c.resolve_hit(true)=="clash" and c.foe.phase=="recovery" and c.hero.phase=="recovery" and c.foe.health==health,"Two committed swings in one lane bind without damage")
	check(c.hitstop>0 and c.movement(Vector3.FORWARD,2)==Vector3.ZERO,"Impacts freeze the frame briefly")
	c.hitstop=0
	c.hero.phase="windup"
	c.hero.attack_dir=0
	c.foe.phase="windup"
	c.foe.attack_dir=2
	c.foe.timer=.9
	c.resolve_hit(true)
	check(c.foe.phase=="hurt","A hit stops an early swing")
	c.hero.phase="windup"
	c.foe.phase="windup"
	c.foe.total=1.0
	c.foe.timer=.3
	c.resolve_hit(true)
	check(c.foe.phase=="windup","A light hit does not stop a committed swing")
	c.hero.phase="windup"
	c.hero.heavy=true
	c.foe.total=1.0
	c.foe.timer=.3
	c.resolve_hit(true)
	check(c.foe.phase=="hurt","A heavy hit stops any swing")
	check(c.foe.timer>.4 and c.foe.get("staggered",false) and c.foe.knock.length()>3 and c.hitstop>=.14,"A heavy hit staggers: a longer reel, a harder knockback and a longer freeze")
	c.hitstop=0
	c.hero.phase="idle"
	c.hero.knock=Vector3(0,0,2)
	check(c.movement(Vector3.ZERO,2)==Vector3(0,0,2),"The player is knocked back through their own movement")
	c.hero.knock=Vector3.ZERO
	c.hero.phase="windup"
	c.hero.heavy=false
	c.hero.total=1.0
	c.hero.timer=.2
	check(c.movement(Vector3.ZERO,2).length()>2,"A committed swing lunges toward the swordsman")
	c.hero.phase="idle"
	c.hero.blocking=false
	c.foe.phase="windup"
	c.foe.attack_dir=2
	c.foe.heavy=false
	check(c.resolve_hit(false)=="hit" and c.hit_lane==2 and c.hit_flash>0 and c.hero.phase=="hurt","A hit taken flags its lane for the reticle and screen-edge flash")
	c.hitstop=0
	c.hero.phase="idle"
	c.hero.heavy=true
	c.foe.phase="idle"
	c.foe.blocking=true
	c.foe.guard=0
	c.foe.block_age=99
	c.foe.exhaust=0
	c.foe.stamina=100
	c.foe.health=140
	c.hero.phase="windup"
	check(c.resolve_hit(true)=="block" and c.foe.health<140 and c.foe.health>130,"A blocked heavy blow chips through the guard")
	c.hero.heavy=false
	check(CombatRules.finisher([3,1],0).id=="crossing" and CombatRules.finisher([2,0],2).id=="serpent" and CombatRules.finisher([1,1],0).is_empty(),"Forms complete only from their full sequence")
	check(CombatRules.combo_progress([3,1]).step==2 and CombatRules.combo_progress([1]).step==0 and CombatRules.combo_progress([0,2]).step==1,"Form progress follows the tail of the chain")
	c.hero.phase="idle"
	c.hero.stamina=100
	c.hero.chain=[3,1]
	c.hero.chain_time=1.0
	c.hero.guard=0
	c.attack(false)
	check(c.hero.combo=="crossing","The third cut of a form is flagged as its finisher")
	c.foe.phase="idle"
	c.foe.blocking=true
	c.foe.guard=0
	c.foe.block_age=99
	c.foe.stamina=100
	c.foe.exhaust=0
	health=c.foe.health
	check(c.resolve_hit(true)=="hit" and c.foe.health<health and c.hero.chain.is_empty(),"The Crossing cut finisher forces a held guard and resets the chain")
	c.hero.phase="idle"
	c.hero.chain=[3,1]
	c.hero.chain_time=0
	c.attack(false)
	check(c.hero.combo=="","A stale chain does not complete a form")
	c.hero.phase="recovery"
	c.hero.timer=.1
	c.hero.total=.38
	check(not c.attack(false) and c.buffered==0,"An attack late in recovery is buffered")
	c.buffer_time=.3
	c.tick(c.hero,.2,true)
	check(c.hero.phase=="windup","The buffered attack begins as soon as recovery ends")
	c.hero.phase="recovery"
	c.hero.timer=.1
	c.buffered=-1
	c.guard_held=true
	c.hero.blocking=false
	c.tick(c.hero,.2,true)
	check(c.hero.blocking and c.hero.block_age>1,"A held guard rises again after recovery, never as a perfect block")
	c.guard_held=false
	c.hero.blocking=false
	check(CombatRules.partner(1).feint_chance==0 and CombatRules.partner(4).read_chance>CombatRules.partner(1).read_chance and CombatRules.partner(1).health==140,"The partner grows sharper with the player's level")
	check(c.salute<=0 or c.fight_time==0,"The bout opens with a salute before the partner attacks")
	c.stop("Visual check")
	c.respawn=0
	c.start()
	game.camera_mode=2
	game.camera_distance=4.2
	game.camera_height=2.5
	game.yaw=0
	game.camera_target=game.player.position
	await wait(.4)
	c.foe.phase="windup"
	c.foe.attack_dir=1
	c.foe.total=.8
	c.foe.timer=.5
	c.pose_sword(c.enemy_sword,c.foe,0)
	c.pose_sword(c.hero_sword,c.hero,0)
	await shot("stance")
	# Lanes are read from the player's side: a Right guard sits on screen right for both fighters.
	c.foe.phase="idle"
	c.foe.guard=1
	c.hero.phase="idle"
	c.hero.guard=1
	c.pose_sword(c.enemy_sword,c.foe,0)
	c.pose_sword(c.hero_sword,c.hero,0)
	check(c.hero_sword.global_position.x>game.player.position.x+.2 and c.enemy_sword.global_position.x>c.enemy.position.x+.2,"Right-lane guards sit on the player's right for both fighters")
	check(is_instance_valid(c.hero_stance) and is_instance_valid(c.hero_grip) and c.hero_stance.get_index()<c.hero_grip.get_index(),"Posture is layered before the grip solve on the player rig")
	c.hero.guard=0
	c.pose_sword(c.hero_sword,c.hero,0)
	await wait(.2)
	# Modifier results are restored after each skeleton update, so the solver reports its own reach.
	check(c.hero_grip.reach_error<.03,"The hands stay on the grip through the posture layer")
	c.enemy.position=c.CENTER+Vector3(2.0,.1,.2)
	c.set_physics_process(true)
	await wait(.6)
	c.set_physics_process(false)
	check(absf(wrapf(game.yaw-c.lock_yaw(),-PI,PI))<.6,"Third person softly locks the view onto the swordsman")
	c.enemy.position=c.CENTER+Vector3(0,.1,-1)
	game.player.position=c.CENTER+Vector3(0,.1,1.6)
	game.camera_mode=1
	game.camera_height=1.65
	game.camera_pitch=0
	await wait(.3)
	c.pose_sword(game.camera.get_node("FirstPersonHands/HeldGreatsword"),c.hero,0,true)
	await wait(.15)
	await shot("first-person")
	# Input events use the same routing as actual mouse and keyboard controls.
	c.hero.phase="idle"
	c.hero.stamina=100
	var key := InputEventKey.new()
	key.physical_keycode=KEY_LEFT
	key.pressed=true
	Input.parse_input_event(key)
	await wait(.03)
	check(c.hero.guard==3,"Arrow input selects attack and guard direction")
	var mouse := InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	Input.parse_input_event(mouse)
	await wait(.03)
	check(c.hero.phase=="windup" and c.hero.stamina<100,"Mouse input begins a stamina-consuming attack")
	mouse.pressed=false
	Input.parse_input_event(mouse)
	key.pressed=false
	Input.parse_input_event(key)
	c.stop("Skills")
	c.open_skills()
	await wait(.3)
	await shot("skills")
	c.close_skills()
	check(game.menus.save_game()==OK,"Combat progression saves to disk")
	var disk := ConfigFile.new()
	check(disk.load(game.menus.save_path)==OK and disk.get_value("equipment","state",{}).get("combat_skills",[]).has("riposte"),"Save file contains learned combat moves")
	c.respawn=0
	c.start()
	c.set_physics_process(true)
	await wait(1.5)
	check(c.foe.phase!="idle" or c.decision<1.1,"Live opponent approaches and schedules readable attacks")
	# Hold a guard and let the partner work for a while: he must attack, keep the measure and stay upright.
	c.hero.blocking=true
	c.hero.guard=1
	await wait(6)
	var measure: float=game.player.position.distance_to(c.enemy.position)
	check(c.foe_swings>=2 and measure>1.0 and measure<3.4 and c.enemy.position.y>-.5,"Partner presses the attack while keeping the measure (%d swings, you %d HP, him %d HP, %.1f m)"%[c.foe_swings,c.hero.health,c.foe.health,measure])
	check(c.active or c.hero.health<=0,"A live bout continues until a fighter falls")
	c.hero.blocking=false
	if not c.active:
		c.respawn=0
		c.start()
	# Exercise the actual physics collider instead of teleporting into it.
	c.set_physics_process(false)
	c.enemy.position=c.CENTER+Vector3(0,.1,-1)
	game.player.position=c.enemy.position+Vector3(0,0,1)
	Input.action_press("up")
	await wait(1)
	Input.action_release("up")
	check(game.player.position.distance_to(c.enemy.position)>.54,"Player cannot walk through swordsman capsule")
	c.stop("Complete")
	game.menus.release_classroom()
	await wait(.5)
	print("COMBAT CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)

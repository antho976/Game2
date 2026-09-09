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
	game.player.position=c.CENTER+Vector3(0,.1,1.6)
	c.start()
	c.set_physics_process(false)
	for heavy in [false,true]:
		c.foe=CombatRules.state(140,100)
		c.foe.phase="windup"
		c.foe.heavy=heavy
		c.foe.total=.65 if heavy else .34
		c.foe.timer=CombatRules.PERFECT_WINDOW+.001
		check(not c.parry_cue_active(),"No early parry spark for "+("heavy" if heavy else "light"))
		c.foe.timer=CombatRules.PERFECT_WINDOW
		check(c.parry_cue_active(),"Red spark starts at the exact perfect-parry boundary")
		c.foe.feint_plan=true
		check(not c.parry_cue_active(),"A planned feint cannot falsely signal parry now")
		c.foe.feint_plan=false
		c.foe.timer=.001
		check(c.parry_cue_active(),"Spark stays visible until impact")
		c.foe.timer=0
		check(not c.parry_cue_active(),"Spark ends at impact")
		c.foe.timer=.1
		c.foe.phase="hurt"
		check(not c.parry_cue_active(),"Interrupting a strike immediately removes its parry cue")
	c.foe=CombatRules.state(140,100)
	check(c.active and game.equipment.inventory.is_empty(),"Practice loan starts combat without adding inventory")
	check(game.sword_drawn and is_instance_valid(c.hero_sword) and c.fight_time==0,"The bout begins where the player stands with the sword drawn and no salute")
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
	check(c.foe.phase=="open" and c.foe.guard==1 and is_equal_approx(c.foe.open,1.3) and c.foe.exhaust==38 and c.hero.counter>0,"A perfect parry freezes the swordsman's guard in the parried lane for 1.3 seconds and fills the stagger bar")
	c.hero.phase="windup"
	c.hero.attack_dir=1
	c.hero.heavy=false
	c.hero.critical=false
	c.hero.combo=""
	c.hero.chain.clear()
	var frozen_health: float=c.foe.health
	check(c.resolve_hit(true)=="block" and c.foe.health==frozen_health and c.foe.phase=="open","Striking the lane his stuck blade covers is still blocked")
	c.hero.phase="windup"
	c.hero.attack_dir=3
	check(c.resolve_hit(true)=="hit" and c.foe.health<frozen_health and c.foe.phase=="hurt","Striking any other lane while he is open lands")
	check(c.last_result=="hit" and frozen_health-c.foe.health>float(GearCatalog.find("warden_blade").damage)*1.2,"An open fighter takes bonus damage")
	c.hitstop=0
	c.foe.phase="open"
	c.foe.timer=.1
	c.foe.total=1.3
	c.tick(c.foe,.2,false)
	check(c.foe.phase=="idle" and c.foe.blocking and c.foe.open==0,"The frozen guard comes free when the opening ends")
	# Tiers: a recruit stays open longer, a master never opens and only builds stagger.
	check(CombatRules.partner(1,"grunt").open_time>CombatRules.partner(1,"normal").open_time and CombatRules.partner(1,"boss").open_time==0,"Openings shorten with enemy tier, not level")
	c.tier="boss"
	c.profile=CombatRules.partner(1,"boss")
	c.hero.phase="idle"
	c.hero.blocking=true
	c.hero.guard=0
	c.hero.block_age=.1
	c.foe.phase="windup"
	c.foe.attack_dir=0
	c.foe.exhaust=0
	check(c.resolve_hit(false)=="perfect" and c.foe.phase=="recovery" and c.foe.exhaust==48,"A perfect parry never opens a master but fills his stagger bar faster")
	c.tier="normal"
	c.profile=CombatRules.partner(1,"normal")
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
	c.foe.phase="windup"
	c.resolve_hit(false)
	check(c.foe.phase=="exhausted" and c.foe.timer==3 and c.foe.weak>=0 and c.foe.weak<4 and c.weak_marker.visible,"A full stagger bar exhausts him and shows a weak spot")
	c.hitstop=0
	c.hero.phase="windup"
	c.hero.heavy=true
	c.hero.critical=false
	c.hero.pursuit=false
	c.hero.combo=""
	c.hero.chain.clear()
	c.hero.attack_dir=(c.foe.weak+1)%4
	c.foe.health=140
	var spent_health: float=c.foe.health
	check(c.resolve_hit(true)=="hit" and c.foe.phase=="exhausted" and c.foe.health<spent_health,"A heavy into the wrong lane only wounds an exhausted fighter and leaves him exhausted")
	c.hitstop=0
	c.hero.phase="windup"
	c.hero.attack_dir=c.foe.weak
	c.foe.health=400
	spent_health=c.foe.health
	check(c.resolve_hit(true)=="execution" and c.cinematic.active() and c.hero.phase=="cinematic" and c.foe.phase=="cinematic","A heavy through the weak spot starts the execution cinematic")
	check(c.movement(Vector3.FORWARD,2)==Vector3.ZERO and not c.attack(false),"Nobody moves or swings during the execution")
	c.cinematic.time=c.cinematic.LENGTH*c.cinematic.LAND
	c.cinematic.step(.02)
	check(c.cinematic.landed and spent_health-c.foe.health>float(GearCatalog.find("warden_blade").damage)*1.65*2.5,"The execution lands for several times a heavy cut")
	c.cinematic.time=c.cinematic.LENGTH
	c.cinematic.step(.02)
	check(not c.cinematic.active() and c.foe.phase=="idle" and c.foe.exhaust==0 and c.foe.weak==-1 and not c.weak_marker.visible and c.hero.phase=="recovery","After the execution both fighters are let go and the mark is gone")
	c.hitstop=0
	c.foe.phase="exhausted"
	c.foe.timer=.05
	c.foe.total=3
	c.foe.weak=2
	c.weak_marker.show()
	c.tick(c.foe,.1,false)
	check(c.foe.phase=="idle" and c.foe.weak==-1 and not c.weak_marker.visible,"Missing the window lets him recover")
	c.hero.heavy=false
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
	# Engagement: no transition. A swing near him starts the bout mid-cut; walking up to him does too.
	c.stop("Visual check")
	game.player.position=c.CENTER+Vector3(0,.1,7)
	c.set_physics_process(true)
	await wait(2.4)
	c.set_physics_process(false)
	c.respawn=0
	c.truce=0
	check(not game.sword_drawn and not is_instance_valid(c.hero_sword),"The sword goes back on the shoulder after a bout")
	game.player.position=c.CENTER+Vector3(0,.1,7)
	check(not c.attack(false) and not game.sword_drawn,"A swing away from him with no sword owned only asks for one")
	game.equipment.claim_starter()
	check(c.attack(false) and game.sword_drawn and not c.active and c.hero.phase=="windup","A swing thrown away from him draws the owned sword without starting a bout")
	c.hero.phase="idle"
	c.sheathe()
	game.player.position=c.CENTER+Vector3(0,.1,1.6)
	check(c.attack(false) and c.active and c.hero.phase=="windup" and c.hero.stamina<c.hero.max_stamina,"A swing thrown near him starts the bout with that swing already in the air")
	c.stop("Sight check")
	c.respawn=0
	c.truce=0
	c.sheathe()
	game.player.position=c.CENTER+Vector3(0,.1,6.5)
	c.set_physics_process(true)
	await wait(.5)
	check(not c.active,"He does not square up while the player keeps their distance")
	game.player.position=c.CENTER+Vector3(0,.1,2.5)
	await wait(1.2)
	c.set_physics_process(false)
	check(c.active and c.fight_time>0 and game.sword_drawn,"He squares up the moment he sees the player and the bout is on")
	c.stop("Visual check")
	c.respawn=0
	game.player.position=c.CENTER+Vector3(0,.1,1.6)
	c.start()
	game.lock_mode=1
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
	c.foe.phase="open"
	c.foe.attack_dir=1
	c.foe.guard=1
	c.foe.open=1.0
	c.foe.open_total=1.3
	c.foe.timer=1.0
	c.foe.total=1.3
	c.hero.phase="windup"
	c.hero.attack_dir=3
	c.hero.total=1.0
	c.hero.timer=.05
	c.pose_sword(c.enemy_sword,c.foe,0)
	c.pose_sword(c.hero_sword,c.hero,0)
	await wait(.1)
	await shot("open")
	c.foe.phase="exhausted"
	c.foe.timer=2.0
	c.foe.total=3.0
	c.foe.weak=0
	c.foe.exhaust=100
	c.weak_marker.position=c.WEAK_SPOT[0]
	c.weak_marker.show()
	c.hero.phase="idle"
	c.hero.blocking=true
	c.hero.guard=0
	c.pose_sword(c.enemy_sword,c.foe,0)
	c.pose_sword(c.hero_sword,c.hero,0)
	await wait(.1)
	await shot("exhausted")
	c.weak_marker.hide()
	c.foe.exhaust=0
	c.hero.blocking=false
	# Side view of both cuts: his heavy chambered high, the player's rising cut at contact.
	game.yaw=PI/2
	game.camera_distance=3.6
	game.camera_height=1.3
	game.camera_target=(game.player.position+c.enemy.position)*.5
	c.foe.phase="windup"
	c.foe.attack_dir=0
	c.foe.heavy=true
	c.foe.total=1.0
	c.foe.timer=.45
	c.hero.phase="windup"
	c.hero.attack_dir=2
	c.hero.heavy=false
	c.hero.total=1.0
	c.hero.timer=.02
	for i in 3:
		c.pose_sword(c.enemy_sword,c.foe,0)
		c.pose_sword(c.hero_sword,c.hero,0)
		c.posture(c.hero,c.hero_stance,-1.0)
		c.posture(c.foe,c.enemy_stance,1.0)
		c.hero_stance.snap()
		c.enemy_stance.snap()
		await wait(.1)
	await shot("side-cuts")
	# The execution, mid wind-up and at the moment the edge lands.
	c.foe.phase="exhausted"
	c.foe.weak=1
	c.foe.timer=2.0
	c.foe.total=3.0
	c.foe.health=400
	c.hero.phase="windup"
	c.hero.heavy=true
	c.hero.attack_dir=1
	c.hero.critical=false
	c.hero.combo=""
	c.resolve_hit(true)
	c.cinematic.time=c.cinematic.LENGTH*.30
	for i in 4:
		c.cinematic.step(.01)
		await wait(.08)
	await shot("execution-wind")
	c.cinematic.time=c.cinematic.LENGTH*.57
	for i in 4:
		c.cinematic.step(.01)
		await wait(.08)
	await shot("execution-hit")
	c.cinematic.time=c.cinematic.LENGTH
	c.cinematic.step(.01)
	c.hitstop=0
	c.hero.phase="idle"
	c.foe.phase="idle"
	game.yaw=0
	game.camera_height=2.5
	game.camera_distance=4.2
	# Lanes are read from the player's side: a Right guard sits on screen right for both fighters.
	c.foe.phase="idle"
	c.foe.guard=1
	c.foe.blocking=true
	c.hero.phase="idle"
	c.hero.guard=1
	c.hero.blocking=true
	c.pose_sword(c.enemy_sword,c.foe,0)
	c.pose_sword(c.hero_sword,c.hero,0)
	var hero_tip: Vector3=c.hero_sword.to_global(Vector3(0,1.25,0))
	var foe_tip: Vector3=c.enemy_sword.to_global(Vector3(0,1.25,0))
	check(hero_tip.x>game.player.position.x+.3 and foe_tip.x>c.enemy.position.x+.3,"Right-lane guards raise the blade on the player's right for both fighters")
	check(is_instance_valid(c.hero_stance) and is_instance_valid(c.hero_grip) and c.hero_stance.get_index()<c.hero_grip.get_index(),"Posture is layered before the grip solve on the player rig")
	c.hero.guard=0
	c.pose_sword(c.hero_sword,c.hero,0)
	await wait(.2)
	# Modifier results are restored after each skeleton update, so the solver reports its own reach.
	check(c.hero_grip.reach_error<.03,"The hands stay on the grip through the posture layer")
	# Every authored key keeps both hands on the grip: chamber, strike and follow-through in each lane.
	var worst := 0.0
	for lane in 4:
		for state in [["windup",.55,false],["windup",.55,true],["windup",.99,true],["windup",.99,false],["recovery",.15,true],["recovery",.15,false],["idle",0.0,false],["idle",0.0,true]]:
			c.hero.phase=state[0]
			c.hero.attack_dir=lane
			c.hero.guard=lane
			c.hero.heavy=state[2]
			c.hero.blocking=state[0]=="idle" and not state[2] # The last idle key is the unguarded ready.
			c.hero.total=.9
			c.hero.timer=.9*(1.0-float(state[1]))
			c.pose_sword(c.hero_sword,c.hero,0)
			c.posture(c.hero,c.hero_stance,-1.0)
			c.hero_stance.snap()
			await wait(.12)
			if c.hero_grip.reach_error>.02: print("reach %s %s %.2f heavy=%s: %.3f m"%[CombatRules.DIRECTIONS[lane],state[0],state[1],state[2],c.hero_grip.reach_error])
			worst=maxf(worst,c.hero_grip.reach_error)
	c.hero.phase="idle"
	c.hero.blocking=false
	c.hero.guard=0
	check(worst<.04,"Chambers, cuts and follow-throughs in every lane keep the hands on the grip (worst %.3f m)"%worst)
	# The fists close across the grip with the thumbs up the blade, and the player's lead hand is
	# the one on the forehand side: the character's own right, which is the bone named L on this rig.
	check(c.hero_grip.lead=="L" and c.enemy_grip.lead=="R","The player leads with the hand on his forehand side; the partner mirrors him")
	c.hero.phase="idle"
	c.hero.blocking=true
	c.hero.guard=1
	c.pose_sword(c.hero_sword,c.hero,0)
	c.posture(c.hero,c.hero_stance,-1.0)
	c.hero_stance.snap()
	await wait(.15)
	check(c.hero_grip.hand_align>.9 and c.hero_grip.reach_error<.03,"Both fists close across the grip, thumbs up the blade (align %.2f)"%c.hero_grip.hand_align)
	# Every cover turns an edge, not the flat, toward the cut it answers, and the roof is above the head.
	var flat_to_cut := 0.0
	for lane in 4:
		var cover: Transform3D=CombatChoreo.guard(lane)
		var from: Vector3=(-CombatChoreo.TRAVEL[lane]+Vector3(0,0,.5)).normalized()
		flat_to_cut=maxf(flat_to_cut,absf(cover.basis.z.dot(from)))
	check(flat_to_cut<.4,"Each cover meets its lane's cut edge on (worst flat %.2f)"%flat_to_cut)
	check(CombatChoreo.guard(0).origin.y>1.70 and CombatChoreo.guard(2).basis.y.y<-.7,"The High cover is a roof above the head and the Low cover a hanging point")
	# No key parks the grip inside the body: the pommel end of every ready, cover, chamber, strike
	# and follow-through stays outside the torso and head boxes of the villager rig.
	var inside := []
	for lane in 4:
		var keys := {"guard":CombatChoreo.guard(lane),"chamber":CombatChoreo.chamber(lane,false),"heavy":CombatChoreo.chamber(lane,true),"strike":CombatChoreo.strike(lane,false),"follow":CombatChoreo.follow(lane,false),"ready":CombatChoreo.ready(0.0)}
		for name in keys:
			var xf: Transform3D=keys[name]
			for along in [-.26,-.10,.05,.30]:
				var point: Vector3=xf.origin+xf.basis.y*along
				var torso: bool=absf(point.x)<.24 and point.y>.85 and point.y<1.52 and absf(point.z)<.15
				var head: bool=absf(point.x)<.12 and point.y>=1.52 and point.y<1.87 and point.z>-.12 and point.z<.11
				if torso or head: inside.append("%s %s %.2f"%[CombatRules.DIRECTIONS[lane],name,along])
	check(inside.is_empty(),"No authored key runs the grip or blade through the body"+("" if inside.is_empty() else ": "+", ".join(inside)))
	# A block drives the guard along the cut; a perfect parry beats the blade out against it.
	c.hero.flash=CombatChoreo.FLASH
	c.hero.counter=0.0
	var jolted: Transform3D=CombatChoreo.blade(c.hero,0.0,0.0,0.0).xf
	c.hero.flash=0.0
	var settled: Transform3D=CombatChoreo.blade(c.hero,0.0,0.0,0.0).xf
	c.hero.flash=CombatChoreo.FLASH
	c.hero.counter=1.0
	var beaten: Transform3D=CombatChoreo.blade(c.hero,0.0,0.0,0.0).xf
	c.hero.flash=0.0
	c.hero.counter=0.0
	check(jolted.origin.x<settled.origin.x-.05 and jolted.origin.z<settled.origin.z-.05,"A blocked Right cut drives the guard along the cut and back")
	check(beaten.origin.x>settled.origin.x+.05 and beaten.origin.z>settled.origin.z+.05,"A perfect parry beats the blade out against the cut")
	# A swing is drawn from wherever the blade was shown last, and a feint re-chambers from its lie.
	c.hero.blocking=false
	c.hero.phase="recovery"
	c.hero.attack_dir=1
	c.hero.timer=.30
	c.hero.total=.38
	c.pose_sword(c.hero_sword,c.hero,0)
	var shown: Transform3D=c.hero.last_xf
	c.hero.phase="idle"
	c.hero.timer=0
	c.hero.stamina=100
	c.attack(false)
	var first: Transform3D=CombatChoreo.blade(c.hero,0.0,0.0,0.0).xf
	check(c.hero.phase=="windup" and first.origin.distance_to(shown.origin)<.001 and first.basis.y.distance_to(shown.basis.y)<.001,"A swing is drawn from where the blade was shown, not from a fixed start")
	check(c.feint(c.hero,3,true) and c.hero.from_at==.45 and c.hero.has("from_xf"),"A feint re-chambers from the lie it abandons")
	c.hero.phase="idle"
	c.hero.feinted=false
	c.hero.combo=""
	c.hero.guard=0
	c.hero.attack_dir=0
	await gallery(game,c)
	c.enemy.position=c.CENTER+Vector3(2.0,.1,.2)
	c.set_physics_process(true)
	await wait(.6)
	c.set_physics_process(false)
	check(absf(wrapf(game.yaw-c.lock_yaw(),-PI,PI))<.6,"Third person hard-locks the view onto the swordsman")
	c.enemy.position=c.CENTER+Vector3(0,.1,-1)
	game.player.position=c.CENTER+Vector3(0,.1,1.6)
	game.camera_mode=1
	game.camera_height=1.65
	game.camera_pitch=0
	await wait(.3)
	c.pose_sword(game.camera.get_node("FirstPersonHands/HeldGreatsword"),c.hero,0,true)
	await wait(.15)
	await shot("first-person")
	if DisplayServer.get_name()!="headless":
		# Every cover, chamber and cut as the player sees it over the blade.
		var held: Node3D=game.camera.get_node("FirstPersonHands/HeldGreatsword")
		for key in GALLERY_KEYS:
			for lane in 4:
				if key[0]=="ready" and lane>0: continue
				pose_key(c.hero,key,lane)
				c.pose_sword(held,c.hero,0,true)
				await wait(.12)
				await shot("fp-%s-%s"%[key[0],CombatRules.DIRECTIONS[lane].to_lower()])
		c.hero.phase="idle"
		c.hero.blocking=false
		c.hero.guard=0
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
# Close-ups of every authored key on both rigs, so hands, edges and covers can be eyeballed.
const GALLERY_KEYS := [["guard","idle",0.0,false,true],["ready","idle",0.0,false,false],["chamber","windup",.56,false,false],["chamber-heavy","windup",.56,true,false],["strike","windup",.995,false,false],["follow","recovery",.15,false,false]]
func pose_key(f: Dictionary,key: Array,lane: int) -> void:
	f.phase=key[1]
	f.attack_dir=lane
	f.guard=lane
	f.heavy=key[3]
	f.blocking=key[4]
	f.total=1.0
	f.timer=1.0-float(key[2])
	f.whiff=false
	f.bounce=false
	f.flash=0.0
	f.raise=0.0
	f.counter=0.0
	f.erase("from_xf")
func gallery(game: Node,c) -> void:
	if DisplayServer.get_name()=="headless": return
	var cam := Camera3D.new()
	cam.fov=36
	cam.near=.05
	game.add_child(cam)
	cam.current=true
	for who in ["hero","foe"]:
		var f: Dictionary=c.hero if who=="hero" else c.foe
		var body: Node3D=game.player if who=="hero" else c.enemy
		var sword: Node3D=c.hero_sword if who=="hero" else c.enemy_sword
		var stance=c.hero_stance if who=="hero" else c.enemy_stance
		var facing: Vector3=(game.player.model if who=="hero" else c.enemy_model).global_basis.z.normalized() # Both rigs face their own +z.
		var right: Vector3=facing.cross(Vector3.UP)
		# The other fighter leaves the close-up without either rig turning: the swordsman is hidden
		# while the player is shot, and the player steps far back behind the camera for the swordsman's turn.
		var other: Node3D=c.enemy if who=="hero" else game.player
		var parked: Vector3=other.position
		if who=="hero": c.enemy.visible=false
		else: other.position=parked+facing*9.0
		var views: Array=[["front",facing*1.7+right*1.3+Vector3.UP*1.55]]
		if who=="hero": views.append(["back",-facing*1.6+right*1.4+Vector3.UP*1.75])
		for view in views:
			for key in GALLERY_KEYS:
				for lane in 4:
					if key[0]=="ready" and lane>0: continue
					pose_key(f,key,lane)
					c.pose_sword(sword,f,0)
					c.posture(f,stance,-1.0 if who=="hero" else 1.0)
					stance.snap()
					cam.global_position=body.position+view[1]
					cam.look_at(body.position+Vector3.UP*1.15)
					await wait(.1)
					await shot("pose-%s-%s-%s-%s"%[who,view[0],key[0],CombatRules.DIRECTIONS[lane].to_lower()])
		f.phase="idle"
		f.blocking=false
		f.guard=0
		f.attack_dir=0
		f.heavy=false
		other.position=parked
		c.enemy.visible=true
	cam.queue_free()
	game.camera.current=true

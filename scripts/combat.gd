extends Node3D
# Directional greatsword sparring: four lanes, read-and-answer guards, feints, forms and a partner
# who studies the player. Rules live in combat_rules.gd; this node runs the bout, the partner,
# the choreography and the feedback layer (hit-stop, shake, sparks, trails, numbers, sound).
const CENTER := Vector3(19,0,-19)
const RULES = preload("res://scripts/combat_rules.gd")
const REACH := 2.65
const DODGE_TIME := .28
var game: Node
var active := false
var hero: Dictionary
var foe: Dictionary
var profile: Dictionary
var enemy: CharacterBody3D
var enemy_model: Node3D
var enemy_animation: AnimationPlayer
var hero_sword: Node3D
var enemy_sword: Node3D
var hero_grip: SkeletonModifier3D
var enemy_grip: SkeletonModifier3D
var hero_stance # combat_stance.gd
var enemy_stance
var hero_trail # combat_trail.gd
var enemy_trail
var hands_trail
var audio # combat_audio.gd
var hud: CanvasLayer
var status: Label
var meters: Label
var hints: Label
var stamina_bar: ProgressBar
var exhaustion_bar: ProgressBar
var health_bar: ProgressBar
var hero_exhaust_bar: ProgressBar
var foe_health_bar: ProgressBar
var banner: Label
var banner_time := 0.0
var vignette: ColorRect
var hurt_flash := 0.0
var enemy_label: Label3D
var skill_panel: PanelContainer
var message := ""
var message_time := 0.0
var decision := 1.0
var dodge_time := 0.0
var dodge_recent := 0.0
var dodge_direction := Vector3.ZERO
var swipe := Vector2.ZERO
var swipe_idle := 0.0
var parry_lock := 0.0
var guard_held := false
var buffered := -1
var buffer_time := 0.0
var respawn := 0.0
var hitstop := 0.0
var shake := 0.0
var salute := 0.0
var fight_time := 0.0
var last_result := ""
var foe_swings := 0
# Impact feedback: lane flashes, reticle pulses, camera recoil, slow motion and blood.
var hit_lane := 0
var hit_flash := 0.0
var pulse_time := 0.0
var pulse_color := Color.WHITE
var kick := Vector3.ZERO # Camera-space recoil from the last impact.
var roll := 0.0
var punch := 0.0 # Field-of-view punch when a blow lands.
var white_flash := 0.0
var stamina_flash := 0.0
var fallen := 0.0 # The beaten swordsman stays down until he rises to spar again.
var slow_until := 0
var foe_ghost := 0.0
var ghosts := {} # Meter -> the pale bar that drains after it.
var splats: Array = []
var splat_texture: GradientTexture2D
var glint_texture: GradientTexture2D
var you_caption: Label
var foe_caption: Label
var flash_rect: ColorRect
var rng := RandomNumberGenerator.new()
func _ready() -> void:
	rng.seed=60908
	splat_texture=soft_disc(Color(.30,.02,.02,.95),Color(.30,.02,.02,.72),.55)
	glint_texture=soft_disc(Color(1,1,1,1),Color(1,1,1,.5),.3)
	hero=RULES.state(100,100)
	foe=RULES.state(140,100)
	profile=RULES.partner(1)
	audio=preload("res://scripts/combat_audio.gd").new()
	audio.game=game
	add_child(audio)
	build_yard()
	build_hud()
func build_yard() -> void:
	# Open training yard, well away from shops, animals and the school doorway.
	var floor := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius=3.55
	disc.bottom_radius=3.55
	disc.height=.03
	disc.radial_segments=40
	floor.mesh=disc
	floor.position=CENTER+Vector3(0,.012,0)
	floor.material_override=game.world.rough_material(Color(.50,.44,.33))
	add_child(floor)
	for i in 40:
		var angle := i*TAU/40
		game.world.box(CENTER+Vector3(cos(angle)*3.7,.015,sin(angle)*3.7),Vector3(.22,.045,.22),game.world.stone[i%6])
	for i in 4:
		# Corner posts mark the square the swordsman keeps to.
		var angle := PI/4+i*PI/2
		game.world.box(CENTER+Vector3(cos(angle)*4.3,.55,sin(angle)*4.3),Vector3(.09,.55,.09),game.world.wood,true)
	enemy=CharacterBody3D.new()
	enemy.name="SparringSwordsman"
	enemy.collision_layer=4
	enemy.collision_mask=3
	enemy.position=CENTER+Vector3(0,.1,-1.0)
	add_child(enemy)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=.32
	capsule.height=1.7
	collider.shape=capsule
	collider.position.y=.86
	enemy.add_child(collider)
	enemy_model=load("res://assets/village/player_refined.glb").instantiate()
	enemy.add_child(enemy_model)
	GearVisuals.apply(enemy_model,{"chest":GearCatalog.find("warden_chest"),"gloves":GearCatalog.find("warden_gloves"),"boots":GearCatalog.find("warden_boots")})
	enemy_animation=enemy_model.find_children("*","AnimationPlayer",true,false)[0]
	play_enemy("idle")
	enemy_sword=make_sword(enemy_model,0)
	enemy_stance=add_stance(enemy_model)
	enemy_grip=add_grip(enemy_model,enemy_sword)
	enemy_trail=add_trail(enemy_sword)
	enemy_label=Label3D.new()
	enemy_label.position=Vector3(0,2.65,0)
	enemy_label.font_size=32
	enemy_label.pixel_size=.0035
	enemy_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	enemy_label.no_depth_test=true
	enemy_label.outline_size=8
	enemy.add_child(enemy_label)
	pose_sword(enemy_sword,foe,0)
func make_sword(parent: Node3D,style: int) -> Node3D:
	var root := Node3D.new()
	root.name="CombatGreatsword"
	parent.add_child(root)
	var builder := GearVisuals.new()
	builder.steel=GearVisuals.material(Color(.43,.48,.50) if style==0 else Color(.16,.20,.23),.78)
	builder.trim=GearVisuals.material(Color(.54,.40,.20),.72)
	builder.leather=GearVisuals.material(Color(.10,.07,.045))
	builder.sword(root,style)
	return root
func add_grip(model: Node3D,sword: Node3D) -> SkeletonModifier3D:
	var grip=preload("res://scripts/combat_grip.gd").new()
	grip.sword=sword
	model.find_children("*","Skeleton3D",true,false)[0].add_child(grip)
	return grip
func add_stance(model: Node3D) -> Node:
	# Added before the grip so the arms are solved from the coiled shoulders.
	var stance=preload("res://scripts/combat_stance.gd").new()
	model.find_children("*","Skeleton3D",true,false)[0].add_child(stance)
	return stance
func add_trail(sword: Node3D) -> Node:
	var trail=preload("res://scripts/combat_trail.gd").new()
	trail.sword=sword
	add_child(trail)
	return trail
func weapon() -> Dictionary:
	var item=game.equipment.owned(int(game.equipment.equipped.get("weapon",0)))
	return GearCatalog.find("warden_blade") if item.is_empty() else game.equipment.stats(item)
func stats() -> Dictionary:
	var result: Dictionary=game.research.player_stats()
	var rank: int=game.equipment.level-1
	result.health+=rank*6
	result.stamina+=rank*4+(12 if has_skill("resolve") else 0)
	result.stamina_recovery_multiplier*=1.12 if has_skill("poise") else 1.0
	return result
func has_skill(id: String) -> bool: return id in game.equipment.combat_skills
func protection() -> float:
	var total := float(game.equipment.level-1)*1.0
	for slot in ["helmet","chest","gloves","boots"]:
		var item=game.equipment.owned(int(game.equipment.equipped.get(slot,0)))
		if not item.is_empty(): total+=float(game.equipment.stats(item).protection)
	return total
func winded(fighter: Dictionary) -> bool: return fighter.stamina<fighter.max_stamina*RULES.WINDED
func lock_yaw() -> float:
	var offset: Vector3=game.player.position-enemy.position
	return atan2(offset.x,offset.z)
func start() -> void:
	if active or respawn>0 or game.input_blocked: return
	var values=stats()
	profile=RULES.partner(game.equipment.level)
	hero=RULES.state(values.health,values.stamina)
	foe=RULES.state(profile.health,100)
	foe.block_age=99.0
	foe.blocking=true
	active=true
	decision=1.1
	dodge_time=0
	dodge_recent=0
	hitstop=0
	shake=0
	salute=1.2
	fight_time=0
	buffered=-1
	guard_held=false
	last_result=""
	foe_swings=0
	hit_flash=0
	pulse_time=0
	white_flash=0
	stamina_flash=0
	fallen=0
	foe_ghost=0
	for meter in ghosts: ghosts[meter].value=0
	game.player.activity=""
	game.player.activity_time=0
	game.player.position=CENTER+Vector3(0,.1,1.6)
	game.player.collision_mask=5
	enemy.position=CENTER+Vector3(0,.1,-1)
	game.yaw=lock_yaw() if game.camera_mode in [1,2] else 0.0
	game.camera_pitch=0
	game.camera_target=game.player.position
	enemy_model.show()
	if is_instance_valid(hero_sword): hero_sword.queue_free()
	if is_instance_valid(hero_stance): hero_stance.queue_free()
	if is_instance_valid(hero_trail): hero_trail.queue_free()
	hero_sword=make_sword(game.player.model,int(weapon().style))
	hero_stance=add_stance(game.player.model)
	hero_grip=add_grip(game.player.model,hero_sword)
	hero_trail=add_trail(hero_sword)
	for mount in game.player.model.find_children("GearMountChest*","BoneAttachment3D",true,false):
		# Only hide the back-mounted sword, not chest armor.
		for child in mount.get_children():
			for blade in child.get_children():
				if blade is Node3D and blade.position.y>1.55: blade.hide()
	var hands=game.camera.get_node_or_null("FirstPersonHands")
	if hands:
		hands.set_weapon(weapon())
		if is_instance_valid(hands_trail): hands_trail.queue_free()
		var held=hands.get_node_or_null("HeldGreatsword")
		if held: hands_trail=add_trail(held)
	show_banner("SALUTE",Color(.95,.88,.66))
	audio.play("sword_draw",game.player.position+Vector3.UP*1.3,-10)
	audio.play("sword_draw",enemy.position+Vector3.UP*1.3,-14,.94)
	game.audio.loop("combat_music","music_combat_layer",null,-22,{"bus":"Music","fade_in":true,"fade":1.5})
	say("Sparring begun. Read the raised guard before you strike.")
func stop(reason: String) -> void:
	if not active: return
	active=false
	hero.blocking=false
	dodge_time=0
	hitstop=0
	salute=0
	game.player.collision_mask=5
	game.player.velocity=Vector3.ZERO
	if is_instance_valid(hero_grip): hero_grip.queue_free()
	if is_instance_valid(hero_stance): hero_stance.queue_free()
	if is_instance_valid(hero_sword): hero_sword.queue_free()
	if is_instance_valid(hero_trail): hero_trail.queue_free()
	if is_instance_valid(hands_trail): hands_trail.queue_free()
	game.refresh_equipment()
	respawn=3.0
	foe=RULES.state(profile.health,100)
	audio.play("sword_sheathe",game.player.position+Vector3.UP*1.3,-12)
	game.audio.stop("combat_music",2.0)
	game.audio.stop("winded",.4)
	say(reason)
func say(text: String) -> void:
	message=text
	message_time=2.5
	game.toast(text)
func show_banner(text: String,color := Color(1,.9,.7)) -> void:
	banner.text=text
	banner.modulate=color
	banner_time=1.1
	# The word lands with a punch: oversized for a frame, then settling with a little overshoot.
	banner.pivot_offset=banner.size*.5
	banner.scale=Vector2.ONE*1.35
	game.audio.ui("hud_banner",-16)
	create_tween().tween_property(banner,"scale",Vector2.ONE,.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
func pulse(color: Color) -> void:
	pulse_time=.35
	pulse_color=color
# Camera recoil away from a lane, with a forward shove when the player's own blow lands.
func recoil(lane: int,strength: float,forward := 0.0) -> void:
	var axis: Vector3=[Vector3(0,1,0),Vector3(1,0,0),Vector3(0,-1,0),Vector3(-1,0,0)][lane]
	kick+=-axis*strength+Vector3(0,0,-forward)
	roll+=(-.9 if lane==1 else (.9 if lane==3 else 0.0))*strength
func refuse() -> void:
	stamina_flash=.6
	audio.play("deny",game.player.position+Vector3.UP,-14)
func slow_motion(scale: float,seconds: float) -> void:
	if game.test_mode or DisplayServer.get_name()=="headless": return
	Engine.time_scale=scale
	game.audio.set_ducked(true)
	get_tree().create_timer(seconds,true,false,true).timeout.connect(func(): game.audio.set_ducked(false))
	slow_until=Time.get_ticks_msec()+int(seconds*1000)
	get_tree().create_timer(seconds,true,false,true).timeout.connect(func():
		if Time.get_ticks_msec()>=slow_until-5: Engine.time_scale=1.0)
func _exit_tree() -> void:
	Engine.time_scale=1.0
func set_guard(direction: int) -> void:
	if hero.phase=="windup" and active:
		feint(hero,direction,true)
		return
	hero.guard=direction
# A swing still early in its windup may change lane once: the shown lane was a lie.
func feint(fighter: Dictionary,direction: int,is_hero: bool) -> bool:
	if fighter.phase!="windup" or fighter.feinted or direction==fighter.attack_dir: return false
	if RULES.progress(fighter)>=RULES.FEINT_LIMIT: return false
	if is_hero and fighter.stamina<6: return false
	if is_hero: fighter.stamina-=6
	fighter.feint_at=RULES.progress(fighter)
	fighter.feinted=true
	fighter.cued=false
	fighter.attack_dir=direction
	fighter.guard=direction
	fighter.timer=fighter.total*.55
	fighter.flash=.35
	if is_hero: show_banner("FEINT",Color(.95,.85,.55))
	else: show_banner("FEINT!",Color(1,.5,.35))
	audio.play("feint",(game.player.position if is_hero else enemy.position)+Vector3.UP*1.3,-14)
	return true
func block(pressed: bool) -> void:
	if not active: return
	guard_held=pressed
	if pressed and hero.phase=="windup" and not hero.feinted and RULES.progress(hero)<RULES.PULL_LIMIT and dodge_time<=0:
		# Pull the blow: the swing is abandoned for an ordinary guard, never a perfect one.
		hero.phase="idle"
		hero.stamina=maxf(0,hero.stamina-4)
		hero.blocking=true
		hero.block_age=99.0
		hero.combo=""
		if is_instance_valid(hero_trail): hero_trail.active=false
		return
	if pressed and not hero.blocking and hero.phase=="idle" and dodge_time<=0:
		hero.block_age=0.0 if parry_lock<=0 else 99.0
		parry_lock=RULES.REARM_LOCK
		hero.blocking=true
		hero.raise=.14
		audio.play("raise",game.player.position+Vector3.UP*1.2,-18)
	elif not pressed: hero.blocking=false
func attack(heavy: bool) -> bool:
	if not active: return false
	if hero.phase!="idle" or dodge_time>0:
		if hero.phase=="recovery" and hero.timer<.22:
			buffered=1 if heavy else 0
			buffer_time=.3
		return false
	var cost: float=float(weapon().stamina)*(1.6 if heavy else 1.0)
	if hero.stamina<cost:
		say("Not enough stamina")
		refuse()
		return false
	hero.stamina-=cost
	hero.regen_delay=.8
	hero.phase="windup"
	hero.heavy=heavy
	hero.attack_dir=hero.guard
	hero.blocking=false
	hero.riposte=hero.counter>0
	hero.critical=hero.counter>0 and hero.guard==hero.counter_dir and has_skill("riposte")
	hero.pursuit=not heavy and dodge_recent>0 and has_skill("pursuit")
	hero.feinted=false
	hero.whiff=false
	hero.combo=""
	if hero.chain_time>0:
		var form: Dictionary=RULES.finisher(hero.chain,hero.guard)
		if not form.is_empty(): hero.combo=form.id
	hero.counter=0.0
	hero.total=RULES.windup(heavy,float(weapon().speed),hero.pursuit,hero.riposte,winded(hero))
	hero.timer=hero.total
	hero.swoosh=true
	# A short, ordinary effort grunt as the swing starts; heavier cuts breathe a little deeper.
	audio.play("hero_effort",game.player.position+Vector3.UP*1.5,-16 if heavy else -19,.94 if heavy else 1.0)
	if is_instance_valid(hero_trail): hero_trail.active=false
	return true
func quickstep() -> bool:
	if not active or hero.phase!="idle" or dodge_time>0: return false
	var cost := 19.0 if has_skill("footwork") else 24.0
	if hero.stamina<cost:
		refuse()
		return false
	hero.stamina-=cost
	hero.regen_delay=.75
	hero.blocking=false
	dodge_time=DODGE_TIME
	dodge_recent=.65
	var input := Input.get_vector("left","right","up","down")
	dodge_direction=Vector3(input.x,0,input.y).rotated(Vector3.UP,game.yaw).normalized()
	if dodge_direction.length()<.1: dodge_direction=(game.player.position-enemy.position).normalized()
	puff(game.player.position)
	audio.play("step",game.player.position,-14)
	return true
func movement(direction: Vector3,speed: float) -> Vector3:
	if not active: return direction*speed
	if hitstop>0: return Vector3.ZERO
	if dodge_time>0: return dodge_direction*8.5*(.65+.35*dodge_time/DODGE_TIME)
	var knock: Vector3=hero.get("knock",Vector3.ZERO)
	if hero.phase=="exhausted" or hero.phase=="hurt": return knock
	var pace: float=minf(speed,2.8)
	match hero.phase:
		"windup": pace*=.38
		"recovery": pace*=.6
	if hero.blocking: pace*=.55
	if winded(hero): pace*=.85
	var result: Vector3=direction*pace
	if hero.phase=="windup" and RULES.progress(hero)>=.62:
		# The body drives into the cut: a committed swing closes the last of the measure.
		var toward: Vector3=enemy.position-game.player.position
		toward.y=0
		if toward.length()>1.25 and toward.length()<REACH+.9: result+=toward.normalized()*(3.2 if hero.heavy else 2.4)
	return result+knock
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and not hero.is_empty():
		hero.blocking=false
		guard_held=false
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_K:
		if skill_panel.visible: close_skills()
		elif not active and not game.input_blocked and not game.menus.home: open_skills()
		get_viewport().set_input_as_handled()
		return
	if not active or game.input_blocked: return
	if event is InputEventKey and event.pressed and not event.echo:
		var direction := [KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_LEFT].find(event.physical_keycode)
		if direction>=0: set_guard(direction)
		elif event.physical_keycode==KEY_Q: attack(true)
		elif event.physical_keycode==KEY_SPACE: quickstep()
		else: return
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:
			block(event.pressed)
			swipe=Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			game.sync_camera_mouse()
			attack(Input.is_key_pressed(KEY_SHIFT))
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		# Holding guard, the mouse steers the blade. Outside first person the free mouse does too.
		var free_aim: bool=game.camera_mode!=1 and not game.inside_school()
		if hero.blocking or free_aim:
			swipe+=event.relative
			swipe_idle=.25
			var threshold: float=24.0 if hero.blocking else 38.0
			if swipe.length()>threshold:
				set_guard((1 if swipe.x>0 else 3) if absf(swipe.x)>absf(swipe.y) else (2 if swipe.y>0 else 0))
				swipe=Vector2.ZERO
			if hero.blocking: get_viewport().set_input_as_handled()
func tick(fighter: Dictionary,delta: float,is_hero: bool) -> void:
	fighter.block_age+=delta
	fighter.counter=maxf(0,fighter.counter-delta)
	fighter.regen_delay=maxf(0,fighter.regen_delay-delta)
	fighter.pain=maxf(0,fighter.pain-delta*4)
	fighter.flash=maxf(0,fighter.flash-delta)
	fighter.raise=maxf(0,fighter.get("raise",0.0)-delta)
	if fighter.chain_time>0:
		fighter.chain_time-=delta
		if fighter.chain_time<=0: fighter.chain.clear()
	if fighter.regen_delay<=0 and fighter.phase=="idle":
		var rate: float=18.0*(float(stats().stamina_recovery_multiplier) if is_hero else 1.0)
		fighter.stamina=minf(fighter.max_stamina,fighter.stamina+rate*delta*(.35 if fighter.blocking else 1.0))
	if fighter.phase=="idle": return
	fighter.timer-=delta
	if fighter.phase=="windup":
		var progress: float=RULES.progress(fighter)
		if fighter.get("swoosh",false) and progress>=.62:
			fighter.swoosh=false
			var feet: Vector3=game.player.position if is_hero else enemy.position
			audio.play("heavy_whoosh" if fighter.heavy else "whoosh",feet+Vector3.UP*1.2,-11 if fighter.heavy else -16,1.0 if is_hero else .92)
			if fighter.heavy:
				# A heavy cut plants the front foot as the blade drops.
				audio.play("stomp",feet,-16)
				puff(feet)
			for ribbon in [hero_trail if is_hero else enemy_trail,hands_trail if is_hero else null]:
				if not is_instance_valid(ribbon): continue
				ribbon.active=true
				ribbon.life=.30 if fighter.heavy else .22
				ribbon.width=.8 if fighter.heavy else .55
				ribbon.color=(Color(1,.95,.75) if fighter.heavy else Color(1,.92,.72)) if is_hero else (Color(1,.5,.35) if fighter.heavy else Color(1,.62,.45))
			if not is_hero and is_instance_valid(enemy_sword): glint(enemy_sword.to_global(Vector3(0,1.25,0)),Color(1,.6,.4))
		if not is_hero and fighter.timer<=RULES.PERFECT_WINDOW and not fighter.get("cued",false):
			# The last fifth of a second before impact: a guard raised now is a perfect one.
			fighter.cued=true
			audio.play("tick",enemy.position+Vector3.UP*1.3,-17)
		if not is_hero and fighter.get("feint_plan",false) and progress>=.45:
			fighter.feint_plan=false
			var open: Array=[]
			for lane in 4:
				if lane!=fighter.attack_dir and lane!=hero.guard: open.append(lane)
			feint(fighter,open[rng.randi_range(0,open.size()-1)],false)
	if fighter.timer>0: return
	if fighter.phase=="windup":
		fighter.phase="recovery"
		fighter.timer=RULES.recovery(fighter.heavy,false)
		fighter.total=fighter.timer
		snap_strike(is_hero)
		var result := resolve_hit(is_hero)
		if result=="miss":
			fighter.whiff=true
			fighter.timer=RULES.recovery(fighter.heavy,true)
			fighter.total=fighter.timer
	else:
		if fighter.phase=="exhausted":
			fighter.exhaust=0.0
			fighter.stamina=fighter.max_stamina*.55
		fighter.phase="idle"
		fighter.whiff=false
		var trail=hero_trail if is_hero else enemy_trail
		if is_instance_valid(trail): trail.active=false
		if is_hero:
			if is_instance_valid(hands_trail): hands_trail.active=false
			if buffered>=0 and buffer_time>0:
				var heavy: bool=buffered==1
				buffered=-1
				attack(heavy)
			elif guard_held and not hero.blocking:
				hero.blocking=true
				hero.block_age=99.0
		elif fighter.followup and game.player.position.distance_to(enemy.position)<REACH and fighter.stamina>=12:
			# A double: the second cut comes from another lane before the guard resets.
			fighter.followup=false
			var lanes: Array=[0,1,2,3]
			lanes.erase(fighter.attack_dir)
			begin_enemy_attack(lanes[rng.randi_range(0,2)],false,float(profile.windup_light)*.72)
func exhaust(fighter: Dictionary) -> void:
	fighter.phase="exhausted"
	fighter.timer=3.0
	fighter.total=3.0
	fighter.blocking=false
	fighter.chain.clear()
	audio.play("crack",(game.player.position if is_same(fighter,hero) else enemy.position)+Vector3.UP,-10)
func extend_chain(fighter: Dictionary,direction: int) -> void:
	if fighter.chain_time<=0: fighter.chain.clear()
	fighter.chain.append(direction)
	if fighter.chain.size()>3: fighter.chain.pop_front()
	fighter.chain_time=RULES.CHAIN_WINDOW
func resolve_hit(from_hero: bool) -> String:
	var attacker: Dictionary=hero if from_hero else foe
	var defender: Dictionary=foe if from_hero else hero
	var contact: Vector3=(enemy.position+game.player.position)*.5+Vector3.UP*1.15
	attacker.combo=attacker.get("combo","")
	if game.player.position.distance_to(enemy.position)>REACH:
		if from_hero: say("Out of reach")
		attacker.chain.clear()
		attacker.combo=""
		last_result="miss"
		return "miss"
	if not from_hero and dodge_time>.055 and dodge_time<.255:
		say("Evaded")
		show_banner("EVADED",Color(.75,.9,1))
		attacker.chain.clear()
		last_result="dodge"
		return "dodge"
	if RULES.clashes(defender.phase,RULES.progress(defender),attacker.attack_dir,defender.attack_dir):
		for fighter in [attacker,defender]:
			fighter.phase="recovery"
			fighter.timer=.55
			fighter.total=.55
			fighter.stamina=maxf(0,fighter.stamina-8)
			fighter.chain.clear()
			fighter.combo=""
		show_banner("CLASH",Color(1,.95,.8))
		say("Blades bind. Both swings are thrown off.")
		impact(true)
		sparks(contact,Color(1,.9,.6),24)
		audio.play("bind",contact,-6)
		pulse(Color(1,.95,.8))
		recoil(attacker.attack_dir,.035,.01)
		white_flash=.12
		hitstop=.14
		shake=.8
		last_result="clash"
		return "clash"
	var guarding: bool=defender.blocking and defender.phase=="idle"
	var cost: float=28 if attacker.heavy else 18
	var age: float=0.0 if from_hero and defender.parry_ready else defender.block_age
	var result := RULES.defence(attacker.attack_dir,defender.guard,guarding,age,defender.stamina,cost)
	var form: Dictionary={}
	if from_hero and not attacker.combo.is_empty():
		for combo in RULES.combos():
			if combo.id==attacker.combo: form=combo
	var pierced := false
	if result=="block" and not form.is_empty() and form.pierce:
		result="hit"
		pierced=true
	if result=="perfect":
		attacker.exhaust+=38
		attacker.phase="recovery"
		attacker.timer=1.05
		attacker.total=1.05
		attacker.chain.clear()
		attacker.combo=""
		defender.counter=1.05
		defender.counter_dir=RULES.opposite(attacker.attack_dir)
		defender.flash=.3
		if attacker.exhaust>=100: exhaust(attacker)
		if from_hero:
			say("Parried! The swordsman turns your blade aside.")
			show_banner("PARRIED",Color(.6,.8,1))
		else:
			say("Perfect block! Counter from "+RULES.DIRECTIONS[defender.counter_dir]+".")
			show_banner("PERFECT",Color(1,.95,.75))
			white_flash=.2
		impact(true)
		sparks(contact,Color(1,.95,.7),28)
		audio.play("parry",contact,-5)
		pulse(Color(.6,.8,1) if from_hero else Color(1,.95,.75))
		recoil(attacker.attack_dir,.055 if from_hero else .03,-.02 if from_hero else 0.0)
		hitstop=.12
		shake=.6
		last_result=result
		return result
	if result=="block":
		defender.stamina-=cost
		defender.regen_delay=1.0
		defender.exhaust+=(26.0*(1.5 if from_hero and has_skill("breaker") else 1.0)) if attacker.heavy else 12.0
		if not form.is_empty(): defender.exhaust+=float(form.exhaust)
		extend_chain(attacker,attacker.attack_dir)
		if attacker.heavy:
			# Plate and a braced guard still let a little of a heavy blow through.
			var chip: float=(float(weapon().damage) if from_hero else float(profile.damage))*1.65*.12
			defender.health=maxf(0,defender.health-chip)
			defender.damage_taken+=chip
			spawn_number(str(roundi(chip)),contact,Color(.85,.8,.7))
		if defender.exhaust>=100 or defender.stamina<=0:
			exhaust(defender)
			say("Exhausted!" if from_hero else "Your guard is exhausted!")
			show_banner("GUARD BROKEN",Color(1,.6,.3))
		else: say("Guarded. Change your attack direction." if from_hero else "Blocked")
		impact(true)
		sparks(contact,Color(1,.85,.55),16 if attacker.heavy else 10)
		audio.play("clang",contact,-7 if attacker.heavy else -9)
		if attacker.heavy: audio.play("thud",contact,-14,.8)
		recoil(attacker.attack_dir,(.06 if attacker.heavy else .03) if not from_hero else 0.0,.02 if from_hero else 0.0)
		hitstop=.07 if attacker.heavy else .04
		shake=.5 if attacker.heavy else .25
		last_result=result
		if defender.health<=0: finish(from_hero)
		return result
	var damage: float=float(weapon().damage)*(1+(game.equipment.level-1)*.04) if from_hero else float(profile.damage)
	damage*=1.65 if attacker.heavy else 1.0
	if from_hero and attacker.critical: damage*=1.65
	if from_hero and attacker.get("pursuit",false): damage*=1.2
	if not form.is_empty(): damage*=float(form.damage)
	if pierced: damage*=.7
	var finishing: bool=defender.phase=="exhausted" and attacker.heavy
	if defender.phase=="exhausted": damage*=2.0 if finishing else 1.5
	if not from_hero: damage*=100.0/(100.0+protection())
	if result=="break":
		defender.stamina=0.0
		exhaust(defender)
		damage*=.5
		show_banner("GUARD BROKEN",Color(1,.6,.3))
	if pierced:
		defender.exhaust+=float(form.exhaust)
		if defender.exhaust>=100: exhaust(defender)
	var interrupted: bool=RULES.interrupts(defender.phase,RULES.progress(defender),attacker.heavy)
	defender.health=maxf(0,defender.health-damage)
	defender.damage_taken+=damage
	defender.pain=1.0
	defender.chain.clear()
	defender.combo=""
	var stagger: bool=attacker.heavy or finishing or attacker.critical
	defender.staggered=stagger
	if defender.phase!="exhausted" and interrupted:
		defender.phase="hurt"
		defender.timer=.46 if stagger else .26
		defender.total=defender.timer
		defender.followup=false
		defender.feint_plan=false
	var away: Vector3=(enemy.position-game.player.position if from_hero else game.player.position-enemy.position).normalized()
	defender.knock=away*(3.4 if stagger else 1.7)
	if from_hero:
		decision=.12
		extend_chain(attacker,attacker.attack_dir)
		if not form.is_empty():
			attacker.chain.clear()
			show_banner(str(form.name).to_upper(),Color(1,.85,.45))
		recoil(attacker.attack_dir,0.0,.045 if stagger else .022)
		punch=1.0 if stagger else .55
		pulse(Color(1,.9,.6) if stagger else Color(1,.8,.6))
	else:
		hurt_flash=.75 if stagger else .5
		hit_lane=attacker.attack_dir
		hit_flash=.6
		recoil(attacker.attack_dir,.095 if stagger else .05)
	if attacker.critical or finishing: white_flash=.25
	defender.blocking=false
	impact(false)
	blood(contact,away,stagger)
	sparks(contact,Color(1,.55,.3),8 if not attacker.heavy else 14)
	audio.play("slam" if attacker.heavy else "thud",contact,-4 if attacker.heavy else -8)
	audio.play("flesh",contact,-8 if stagger else -12)
	audio.play("clang",contact,-20,.8)
	audio.play("blood_spatter",contact-Vector3.UP*.9,-16 if stagger else -20)
	if attacker.critical or finishing: audio.play("finishing_blow" if finishing else "critical_hit",contact,-4)
	var victim: Vector3=(enemy.position if from_hero else game.player.position)+Vector3.UP*1.5
	if from_hero: audio.play("foe_hurt_heavy" if stagger else "foe_hurt_light",victim,-10 if stagger else -14)
	else: audio.play("hero_hurt_heavy" if stagger else "hero_hurt_light",victim,-10 if stagger else -14)
	hitstop=.20 if (attacker.critical or finishing) else (.14 if attacker.heavy else .07)
	shake=1.0 if stagger else .5
	var label := "Critical! " if from_hero and attacker.critical else ("Finishing blow! " if finishing else ("Guard forced! " if pierced else ""))
	say(label+str(roundi(damage))+" damage")
	spawn_number(str(roundi(damage)),contact+Vector3(rng.randf_range(-.2,.2),0,0),Color(1,.9,.55) if attacker.critical or finishing or not form.is_empty() else (Color(1,.75,.6) if from_hero else Color(1,.45,.4)),1.45 if (attacker.critical or finishing) else (1.2 if attacker.heavy else 1.0))
	last_result=result
	if defender.health<=0: finish(from_hero)
	return result
func finish(hero_won: bool) -> void:
	if hero_won:
		var previous_level: int=game.equipment.level
		var xp := 60
		var flawless: bool=hero.damage_taken<=0 and fight_time>=8
		if flawless: xp+=20
		var error: String=game.equipment.award_combat(xp,25)
		var reward := "Victory. +%d XP, +25 gold"%xp
		if flawless: reward+=" (flawless)"
		if game.equipment.level>previous_level: reward+=" • Level %d! Press K to spend your skill point."%game.equipment.level
		show_banner("VICTORY",Color(1,.88,.5))
		shake=1.0
		white_flash=.3
		slow_motion(.3,.9)
		game.audio.play_2d("victory_stinger",-8,{"bus":"Music"})
		audio.play("foe_kneel",enemy.position,-12)
		stop(reward if error.is_empty() else error)
		fallen=respawn
	else:
		show_banner("DEFEATED",Color(1,.5,.4))
		hurt_flash=1.4
		slow_motion(.45,.8)
		game.audio.play_2d("defeat_stinger",-8,{"bus":"Music"})
		stop("Defeated. Rest, then press F to try again. No items lost.")
func begin_enemy_attack(lane: int,heavy: bool,windup: float) -> void:
	foe_swings+=1
	foe.phase="windup"
	foe.attack_dir=lane
	foe.guard=lane
	foe.heavy=heavy
	foe.total=windup
	foe.timer=windup
	foe.blocking=false
	foe.parry_ready=false
	foe.feinted=false
	foe.whiff=false
	foe.swoosh=true
	foe.cued=false
	foe.stamina=maxf(0,foe.stamina-15)
	foe.regen_delay=.8
	audio.play("foe_effort",enemy.position+Vector3.UP*1.5,-16 if heavy else -19,.92 if heavy else 1.0)
func _physics_process(delta: float) -> void:
	respawn=maxf(0,respawn-delta)
	message_time=maxf(0,message_time-delta)
	buffer_time=maxf(0,buffer_time-delta)
	if buffer_time<=0: buffered=-1
	if not active:
		fallen=maxf(0,fallen-delta)
		if is_instance_valid(enemy_stance):
			# Beaten, he drops to a knee and stays there until he is ready to spar again.
			if fallen>0: enemy_stance.aim(.85,0,.25,.42,5)
			else: enemy_stance.aim(0,0,0,0,4)
		if fallen<=0: enemy.position=enemy.position.lerp(CENTER+Vector3(0,.1,-1),minf(delta*2,1))
		enemy_model.rotation.y=lerp_angle(enemy_model.rotation.y,0,minf(delta*3,1))
		enemy_model.rotation.z=0
		pose_sword(enemy_sword,foe,delta)
		return
	if game.input_blocked:
		hero.blocking=false
		return
	if game.player.position.distance_to(CENTER)>6:
		stop("You left the training yard.")
		return
	var toward: Vector3=game.player.position-enemy.position
	toward.y=0
	var distance: float=toward.length()
	if game.camera_mode in [1,2]:
		# A soft lock keeps the duel framed; the mouse can still nudge the view.
		game.yaw=lerp_angle(game.yaw,lock_yaw(),minf(delta*5,1))
		if game.camera_mode==1: game.camera_pitch=lerpf(game.camera_pitch,atan2(-.35,maxf(distance,1)),minf(delta*1.5,1))
	if hitstop>0:
		hitstop-=delta
		enemy.velocity=Vector3.ZERO
		posture(hero,hero_stance,-1.0)
		posture(foe,enemy_stance,1.0)
		return
	hero.knock=hero.get("knock",Vector3.ZERO).move_toward(Vector3.ZERO,delta*7)
	salute=maxf(0,salute-delta)
	if salute<=0 and fight_time==0:
		show_banner("FIGHT",Color(1,.75,.4))
	if salute<=0: fight_time+=delta
	parry_lock=maxf(0,parry_lock-delta)
	dodge_time=maxf(0,dodge_time-delta)
	if winded(hero): game.audio.loop("winded","winded_breath",null,-20,{"bus":"SFX","fade_in":true})
	else: game.audio.stop("winded",.8)
	dodge_recent=maxf(0,dodge_recent-delta)
	swipe_idle=maxf(0,swipe_idle-delta)
	if swipe_idle<=0 and not hero.blocking: swipe=Vector2.ZERO
	tick(hero,delta,true)
	if not active: return
	tick(foe,delta,false)
	if not active: return
	partner_ai(delta,toward,distance)
	if not active: return
	pose_sword(hero_sword,hero,delta)
	pose_sword(enemy_sword,foe,delta)
	posture(hero,hero_stance,-1.0)
	posture(foe,enemy_stance,1.0)
	enemy_model.rotation.z=sin(foe.timer*32)*(.09 if foe.get("staggered",false) else .055)*foe.pain if foe.phase=="hurt" else 0.0
	# The player's own model shudders through a hit; the walk script has already set its bank this tick.
	if hero.phase=="hurt": game.player.model.rotation.z+=sin(hero.timer*30)*(.08 if hero.get("staggered",false) else .05)*hero.pain
	var hands=game.camera.get_node_or_null("FirstPersonHands")
	if hands and hands.visible:
		var held=hands.get_node_or_null("HeldGreatsword")
		if held: pose_sword(held,hero,delta,true)
func partner_ai(delta: float,toward: Vector3,distance: float) -> void:
	enemy_model.rotation.y=lerp_angle(enemy_model.rotation.y,atan2(toward.x,toward.z),minf(delta*9,1))
	# Footwork: keep the measure, circle when the measure is right, retreat to breathe.
	var step := Vector3.ZERO
	var forward: Vector3=toward.normalized() if distance>.01 else Vector3.FORWARD
	if foe.phase=="idle":
		if foe.resting:
			if distance<3.3: step=-forward*.9
		elif distance>2.35: step=forward*(1.1 if salute>0 else 1.6)
		elif distance<1.45: step=-forward*.8
		else:
			foe.strafe_time-=delta
			if foe.strafe_time<=0:
				foe.strafe=-foe.strafe
				foe.strafe_time=rng.randf_range(1.4,3.2)
			step=forward.cross(Vector3.UP)*foe.strafe*.55
	elif foe.phase=="windup":
		# He drives into his own cut once it is committed, closing the last of the measure.
		if RULES.progress(foe)>=.62 and distance>1.25: step=forward*(2.6 if foe.heavy else 2.0)
		elif distance>1.7: step=forward*.7
	var knock: Vector3=foe.get("knock",Vector3.ZERO)
	foe.knock=knock.move_toward(Vector3.ZERO,delta*6)
	enemy.velocity=step+knock
	enemy.velocity.y=-2
	enemy.move_and_slide()
	var pace := Vector2(enemy.velocity.x,enemy.velocity.z).length()
	play_enemy("walk" if pace>.2 else "idle")
	enemy_animation.speed_scale=clampf(pace/1.625,.55,1.4) if pace>.2 else 1.0
	foe.blocking=foe.phase=="idle"
	if foe.stamina<25 and foe.phase=="idle": foe.resting=true
	if foe.resting and foe.stamina>50: foe.resting=false
	# Reading the player's swing: the shown lane is answered after a short delay, most of the time.
	if hero.phase=="windup":
		if foe.read_timer==-1.0:
			foe.read_timer=rng.randf_range(float(profile.read_delay_min),float(profile.read_delay_max))
			foe.reread=false
		elif foe.read_timer>0:
			foe.read_timer-=delta
			if foe.read_timer<=0:
				foe.read_timer=-2.0
				var chance: float=float(profile.read_chance)*(.45 if hero.feinted else 1.0)
				if foe.phase=="idle" and salute<=0 and rng.randf()<chance:
					foe.guard=hero.attack_dir
					foe.block_age=99.0 # Ordinary answers; the rare sharp guard is flagged below.
					foe.parry_ready=rng.randf()<float(profile.parry_chance)
		elif hero.feinted and not foe.get("reread",false):
			foe.reread=true
			foe.read_timer=rng.randf_range(.2,.36)
	else:
		foe.read_timer=-1.0
		foe.parry_ready=false
	if foe.phase!="idle" or salute>0: return
	decision-=delta
	if hero.phase=="recovery" and hero.whiff and distance<REACH and foe.stamina>=20 and not foe.resting: decision=minf(decision,.05)
	if decision>0: return
	# Guard choice: sometimes the lane the player is showing, otherwise a fresh one.
	if rng.randf()<.4: foe.guard=hero.guard
	else: foe.guard=rng.randi_range(0,3)
	foe.block_age=99.0
	foe.parry_ready=false
	if distance<REACH and foe.stamina>=15 and not foe.resting:
		var lane: int=rng.randi_range(0,3)
		if rng.randf()<.65:
			var open: Array=[0,1,2,3]
			open.erase(hero.guard)
			lane=open[rng.randi_range(0,2)]
		var heavy: bool=rng.randf()<float(profile.heavy_chance)
		begin_enemy_attack(lane,heavy,float(profile.windup_heavy) if heavy else float(profile.windup_light))
		foe.feint_plan=not heavy and rng.randf()<float(profile.feint_chance)
		foe.followup=not heavy and not foe.feint_plan and rng.randf()<float(profile.double_chance)
	decision=rng.randf_range(float(profile.decision_min),float(profile.decision_max))
# Blade choreography per lane, authored from the player's viewpoint: +x is screen right, +z toward the opponent.
const GUARD := [Vector3(.08,1.40,.28),Vector3(.24,1.18,.26),Vector3(.10,1.02,.30),Vector3(-.24,1.18,.26)]
const GUARD_ROT := [Vector3(.35,0,.15),Vector3(.5,0,-.6),Vector3(.95,0,.2),Vector3(.5,0,.6)]
const CHAMBER := [Vector3(.14,1.58,.02),Vector3(.36,1.30,-.02),Vector3(.20,.98,.02),Vector3(-.36,1.30,-.02)]
const CHAMBER_ROT := [Vector3(-.5,0,.2),Vector3(.9,0,-1.15),Vector3(1.35,0,.3),Vector3(.9,0,1.15)]
const STRIKE := [Vector3(0,1.22,.48),Vector3(-.12,1.22,.46),Vector3(.02,1.18,.50),Vector3(.12,1.22,.46)]
const STRIKE_ROT := [Vector3(1.35,0,0),Vector3(1.5,0,.5),Vector3(1.55,0,0),Vector3(1.5,0,-.5)]
const FOLLOW := [Vector3(-.04,1.06,.40),Vector3(-.30,1.15,.28),Vector3(.04,1.24,.44),Vector3(.30,1.15,.28)]
const FOLLOW_ROT := [Vector3(1.85,0,-.15),Vector3(1.4,0,1.2),Vector3(1.4,0,-.1),Vector3(1.4,0,-1.2)]
func pose_sword(sword: Node3D,fighter: Dictionary,delta: float,first_person := false) -> void:
	if not is_instance_valid(sword): return
	var direction: int=fighter.attack_dir if fighter.phase=="windup" or fighter.phase=="recovery" else fighter.guard
	var pos: Vector3=GUARD[direction]
	var rot: Vector3=GUARD_ROT[direction]
	var rate := 22.0
	var heavy_pull: Vector3=Vector3(0,.08,-.08) if fighter.heavy else Vector3.ZERO
	if fighter.phase=="windup":
		var t: float=RULES.progress(fighter)
		var coil: float=smoothstep(0,.62,t)
		pos=pos.lerp(CHAMBER[direction]+heavy_pull,coil)
		rot=rot.lerp(CHAMBER_ROT[direction]+(Vector3(-.3,0,0) if fighter.heavy else Vector3.ZERO),coil)
		var cut: float=pow(smoothstep(.70,1.0,t),.6)
		pos=pos.lerp(STRIKE[direction]+(Vector3(0,0,.06) if fighter.heavy else Vector3.ZERO),cut)
		rot=rot.lerp(STRIKE_ROT[direction],cut)
		if fighter.heavy and t>.5 and t<.7:
			# The heavy blade trembles at the top of its chamber before it drops.
			var tremor: float=(t-.5)/.2
			pos+=Vector3(sin(fighter.timer*90)*.012,sin(fighter.timer*70)*.01,0)*tremor
		if t>.7: rate=55.0
	elif fighter.phase=="recovery":
		var t: float=RULES.progress(fighter)
		var through: float=smoothstep(0,.35,t)
		var back: float=smoothstep(.35,1.0,t)
		pos=STRIKE[direction].lerp(FOLLOW[direction],through).lerp(pos,back)
		rot=STRIKE_ROT[direction].lerp(FOLLOW_ROT[direction],through).lerp(rot,back)
		if fighter.total>=1.0:
			# Parried: the blade is flung wide and takes its time coming back.
			pos+=Vector3(.25 if direction!=1 else -.25,.15,-.15)*(1.0-back)
			rot+=Vector3(-.6,0,.8 if direction!=1 else -.8)*(1.0-back)
	elif fighter.phase=="hurt":
		var reel: float=1.6 if fighter.get("staggered",false) else 1.0
		pos+=Vector3(0,-.10,-.15)*reel
		rot+=Vector3(-.4*reel,0,0)
		rate=30.0
	elif fighter.phase=="exhausted":
		var sway: float=sin(fighter.timer*4.0)*.05
		pos=Vector3(.12+sway,.92,.30)
		rot=Vector3(1.5,0,-.25+sway)
		rate=8.0
	elif fighter.blocking:
		pos+=Vector3(0,.03,.10)
		rot+=Vector3(.15,0,0)
		if fighter.flash>0: pos+=Vector3(0,.04,-.10)*fighter.flash*3
		var raise: float=fighter.get("raise",0.0)
		if raise>0:
			# A freshly raised guard snaps up past its mark and settles.
			pos+=Vector3(0,.07,.08)*(raise/.14)
			rate=34.0
	else:
		var breath: float=sin(Time.get_ticks_msec()*.0021)
		pos+=Vector3(0,.012*breath,.01*breath)
	var s: float=1.0
	if not first_person and is_instance_valid(game.player) and sword.get_parent()==game.player.model: s=-1.0
	pos.x*=s
	rot.y*=s
	rot.z*=s
	if first_person:
		pos=Vector3(pos.x*.7,pos.y*.7-1.1,-pos.z*.7-.1)
		rot=Vector3(-rot.x,-rot.y,rot.z)
	var weight: float=1.0 if delta<=0 else minf(delta*rate,1)
	sword.position=sword.position.lerp(pos,weight)
	sword.rotation=sword.rotation.lerp(rot,weight)
# Whole-body posture per phase, mirrored the same way as the blade.
func posture(fighter: Dictionary,stance,s: float) -> void:
	if not is_instance_valid(stance): return
	var lane: int=fighter.attack_dir if fighter.phase in ["windup","recovery"] else fighter.guard
	var side: float=[0.0,1.0,.4,-1.0][lane]*s
	match fighter.phase:
		"windup":
			var t: float=RULES.progress(fighter)
			if t<.7: stance.aim((-.2 if fighter.heavy else -.14)*smoothstep(0,.6,t),side*.45*smoothstep(0,.6,t),0,.02,14)
			else: stance.aim(.5 if fighter.heavy else .38,-side*.5,0,.10 if fighter.heavy else .07,30)
		"recovery":
			var t: float=RULES.progress(fighter)
			stance.aim(lerpf(.25,.10,t),lerpf(-side*.4,0,t),0,lerpf(.06,.03,t),10)
		"hurt":
			var reel: float=1.6 if fighter.get("staggered",false) else 1.0
			stance.aim(-.28*reel,0,.12*s*reel*(1 if lane%2==0 else -1),.05*reel,24)
		"exhausted": stance.aim(.45,0,sin(fighter.timer*4)*.04,.12,5)
		_:
			if fighter.blocking: stance.aim(.06,side*.12,0,.06,12)
			else: stance.aim(.10,side*.15,0,.03,10)
func play_enemy(action: String) -> void:
	for clip in enemy_animation.get_animation_list():
		if clip.ends_with("villager_"+action) and enemy_animation.current_animation!=clip:
			enemy_animation.play(clip,.2)
func impact(metal: bool) -> void:
	var flash := OmniLight3D.new()
	flash.position=(enemy.position+game.player.position)*.5+Vector3.UP*1.1
	flash.light_color=Color(1,.77,.35) if metal else Color(1,.4,.2)
	flash.omni_range=1.6
	flash.light_energy=.9
	flash.shadow_enabled=false
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash,"light_energy",0.0,.16)
	tween.tween_callback(flash.queue_free)
	if metal and not game.test_mode and not game.muted and DisplayServer.get_name()!="headless":
		var sound := AudioStreamPlayer3D.new()
		sound.stream=load("res://assets/audio/smith_hammer_anvil_01.ogg")
		sound.volume_db=-18
		sound.pitch_scale=rng.randf_range(1.15,1.45)
		sound.position=flash.position
		add_child(sound)
		sound.play()
		sound.finished.connect(sound.queue_free)
func sparks(pos: Vector3,color: Color,count: int) -> void:
	var burst := CPUParticles3D.new()
	burst.amount=count
	burst.one_shot=true
	burst.explosiveness=1.0
	burst.lifetime=.38
	burst.direction=Vector3.UP
	burst.spread=75
	burst.initial_velocity_min=2.2
	burst.initial_velocity_max=4.6
	burst.gravity=Vector3(0,-9,0)
	burst.scale_amount_min=.6
	burst.scale_amount_max=1.0
	var quad := QuadMesh.new()
	quad.size=Vector2(.035,.035)
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=color
	material.emission_enabled=true
	material.emission=color
	material.emission_energy_multiplier=2.0
	material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material=material
	burst.mesh=quad
	burst.position=pos
	add_child(burst)
	burst.emitting=true
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)
func puff(pos: Vector3) -> void:
	var dust := CPUParticles3D.new()
	dust.amount=10
	dust.one_shot=true
	dust.explosiveness=.9
	dust.lifetime=.55
	dust.direction=Vector3.UP
	dust.spread=80
	dust.initial_velocity_min=.5
	dust.initial_velocity_max=1.3
	dust.gravity=Vector3(0,-.8,0)
	dust.scale_amount_min=1.0
	dust.scale_amount_max=2.2
	var quad := QuadMesh.new()
	quad.size=Vector2(.09,.09)
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(.62,.56,.45,.45)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material=material
	dust.mesh=quad
	dust.position=pos+Vector3(0,.08,0)
	add_child(dust)
	dust.emitting=true
	get_tree().create_timer(1.2).timeout.connect(dust.queue_free)
func spawn_number(text: String,pos: Vector3,color: Color,size := 1.0) -> void:
	var number := Label3D.new()
	number.text=text
	number.font_size=44
	number.pixel_size=.0038
	number.modulate=color
	number.outline_size=10
	number.outline_modulate=Color(.05,.04,.03,.9)
	number.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test=true
	number.position=pos+Vector3(0,.25,0)
	number.scale=Vector3.ONE*size*1.8
	add_child(number)
	var tween := create_tween().set_parallel(true)
	# The number lands oversized and settles with a snap, then drifts up and fades.
	tween.tween_property(number,"scale",Vector3.ONE*size,.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(number,"position",number.position+Vector3(rng.randf_range(-.15,.15),.7,0),.85).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(number,"modulate:a",0.0,.85).set_delay(.25)
	tween.chain().tween_callback(number.queue_free)
# A soft radial disc texture for blood marks and blade glints.
func soft_disc(core: Color,mid: Color,mid_at: float) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.gradient=Gradient.new()
	texture.gradient.set_color(0,core)
	texture.gradient.set_color(1,Color(core.r,core.g,core.b,0))
	texture.gradient.add_point(mid_at,mid)
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5)
	texture.fill_to=Vector2(1,.5)
	texture.width=64
	texture.height=64
	return texture
# A white flare at the blade tip the instant a cut commits: the moment to read it.
func glint(pos: Vector3,color := Color(1,1,1)) -> void:
	var flare := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size=Vector2(.24,.24)
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture=glint_texture
	material.albedo_color=color
	material.no_depth_test=true
	quad.material=material
	flare.mesh=quad
	flare.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flare.position=pos
	flare.scale=Vector3.ONE*.4
	add_child(flare)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flare,"scale",Vector3.ONE*1.7,.16).set_ease(Tween.EASE_OUT)
	tween.tween_property(material,"albedo_color:a",0.0,.2)
	tween.chain().tween_callback(flare.queue_free)
# A cut that lands throws blood away from the blade and leaves a mark on the yard.
func blood(pos: Vector3,away: Vector3,heavy: bool) -> void:
	var spray := CPUParticles3D.new()
	spray.amount=24 if heavy else 12
	spray.one_shot=true
	spray.explosiveness=1.0
	spray.lifetime=.6
	spray.direction=(away+Vector3.UP*.6).normalized()
	spray.spread=38
	spray.initial_velocity_min=2.0
	spray.initial_velocity_max=5.5 if heavy else 4.0
	spray.gravity=Vector3(0,-14,0)
	spray.scale_amount_min=.5
	spray.scale_amount_max=1.4
	spray.damping_min=1.0
	spray.damping_max=3.0
	var quad := QuadMesh.new()
	quad.size=Vector2(.05,.05)
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(.42,.03,.03)
	material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material=material
	spray.mesh=quad
	spray.position=pos
	add_child(spray)
	spray.emitting=true
	get_tree().create_timer(1.3).timeout.connect(spray.queue_free)
	splat(Vector3(pos.x,0,pos.z)+away*rng.randf_range(.2,.6)+Vector3(rng.randf_range(-.3,.3),0,rng.randf_range(-.3,.3)),.24 if heavy else .15)
func splat(pos: Vector3,size: float) -> void:
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size=Vector2(size*rng.randf_range(1.6,2.6),size*rng.randf_range(1.2,2.0))
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture=splat_texture
	material.albedo_color=Color(1,1,1,.85)
	quad.material=material
	mark.mesh=quad
	mark.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.position=Vector3(pos.x,.035,pos.z)
	mark.rotation=Vector3(-PI/2,rng.randf_range(0,TAU),0)
	add_child(mark)
	splats.append(mark)
	while splats.size()>14:
		var old=splats.pop_front()
		if is_instance_valid(old): old.queue_free()
	var tween := create_tween()
	tween.tween_interval(7.0)
	tween.tween_property(material,"albedo_color:a",0.0,6.0)
	tween.tween_callback(mark.queue_free)
# Freeze the attacker's blade at full extension so the hit-stop shows the cut, not a lerp toward it.
func snap_strike(is_hero: bool) -> void:
	pose_sword(hero_sword if is_hero else enemy_sword,hero if is_hero else foe,0)
	if is_hero:
		var hands=game.camera.get_node_or_null("FirstPersonHands")
		var held=hands.get_node_or_null("HeldGreatsword") if hands else null
		if held: pose_sword(held,hero,0,true)
func build_hud() -> void:
	hud=CanvasLayer.new()
	hud.layer=20
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position=Vector2(24,142)
	panel.custom_minimum_size=Vector2(340,0)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",UiKit.flat(Color(.035,.045,.043,.9),Color(.60,.47,.25),1))
	hud.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	panel.add_child(column)
	status=Label.new()
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size",16)
	column.add_child(status)
	you_caption=caption(column,"YOU")
	health_bar=bar(column,Color(.80,.32,.26),10)
	stamina_bar=bar(column,Color(.28,.64,.43),7)
	hero_exhaust_bar=bar(column,Color(.94,.57,.24),4)
	foe_caption=caption(column,"SWORDSMAN")
	foe_health_bar=bar(column,Color(.80,.32,.26),10)
	exhaustion_bar=bar(column,Color(.94,.57,.24),4)
	meters=Label.new()
	meters.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	meters.add_theme_font_size_override("font_size",12)
	meters.modulate=UiKit.MUTED
	column.add_child(meters)
	var compass=preload("res://scripts/combat_compass.gd").new()
	compass.combat=self
	compass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(compass)
	vignette=ColorRect.new()
	vignette.color=Color(.55,.05,.02,0)
	vignette.mouse_filter=Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(vignette)
	flash_rect=ColorRect.new()
	flash_rect.color=Color(1,.97,.9,0)
	flash_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(flash_rect)
	# Controls live along the bottom edge and fade once the first exchanges are over.
	hints=Label.new()
	hints.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hints.text="LMB Light   Q Heavy   RMB Guard   Space Quickstep   Arrows / swipe: lane\nSwipe mid-swing: feint   RMB mid-swing: pull   Gold: your lane   Blue: his guard   Red: incoming, ring turns white: guard now\nForms: Left Right High  ·  Low High Low"
	hints.add_theme_font_size_override("font_size",13)
	hints.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	hints.add_theme_constant_override("shadow_offset_x",1)
	hints.add_theme_constant_override("shadow_offset_y",2)
	hints.modulate=UiKit.MUTED
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hints.offset_top=-176
	hints.offset_bottom=-108
	hints.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hints.hide()
	hud.add_child(hints)
	banner=Label.new()
	banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size",36)
	banner.add_theme_color_override("font_shadow_color",Color(0,0,0,.85))
	banner.add_theme_constant_override("shadow_offset_x",2)
	banner.add_theme_constant_override("shadow_offset_y",3)
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top=150
	banner.offset_bottom=200
	banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
	banner.modulate.a=0
	hud.add_child(banner)
	skill_panel=PanelContainer.new()
	skill_panel.anchor_left=.12
	skill_panel.anchor_right=.88
	skill_panel.anchor_top=.08
	skill_panel.anchor_bottom=.92
	skill_panel.theme=UiKit.theme()
	skill_panel.add_theme_stylebox_override("panel",UiKit.flat(Color(.045,.055,.05,.98),UiKit.GOLD,1,8,Vector2(24,20)))
	hud.add_child(skill_panel)
	skill_panel.hide()
func caption(parent: Node,text: String) -> Label:
	var label := Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",11)
	label.modulate=UiKit.GOLD
	parent.add_child(label)
	return label
# A meter over a paler ghost bar that drains after it, so a lost chunk stays readable for a moment.
func bar(parent: Node,color: Color,height := 7) -> ProgressBar:
	var frame := Control.new()
	frame.custom_minimum_size=Vector2(0,height)
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var ghost := ProgressBar.new()
	ghost.show_percentage=false
	ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ghost.add_theme_stylebox_override("background",UiKit.flat(Color(.10,.13,.12),Color.TRANSPARENT,0,2,Vector2.ZERO))
	ghost.add_theme_stylebox_override("fill",UiKit.flat(color.lightened(.45),Color.TRANSPARENT,0,2,Vector2.ZERO))
	frame.add_child(ghost)
	var meter := ProgressBar.new()
	meter.show_percentage=false
	meter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	meter.add_theme_stylebox_override("background",UiKit.flat(Color.TRANSPARENT,Color.TRANSPARENT,0,2,Vector2.ZERO))
	meter.add_theme_stylebox_override("fill",UiKit.flat(color,Color.TRANSPARENT,0,2,Vector2.ZERO))
	frame.add_child(meter)
	ghosts[meter]=ghost
	return meter
func settle(meter: ProgressBar,delta: float) -> void:
	var ghost: ProgressBar=ghosts[meter]
	ghost.max_value=meter.max_value
	if ghost.value<meter.value: ghost.value=meter.value
	else: ghost.value=lerpf(ghost.value,meter.value,minf(delta*2.2,1))
func _process(delta: float) -> void:
	var near_yard: bool=game.player.position.distance_to(CENTER)<8
	hud.get_child(0).visible=active and not game.input_blocked
	banner_time=maxf(0,banner_time-delta)
	banner.modulate.a=clampf(banner_time*2.2,0,1)
	hurt_flash=maxf(0,hurt_flash-delta*1.6)
	hit_flash=maxf(0,hit_flash-delta*1.8)
	pulse_time=maxf(0,pulse_time-delta)
	white_flash=maxf(0,white_flash-delta*2.5)
	stamina_flash=maxf(0,stamina_flash-delta*1.5)
	var shown: float=1.0 if not game.input_blocked else 0.0
	var low: bool=active and hero.health<hero.max_health*.3
	var low_pulse: float=(.5+.5*sin(Time.get_ticks_msec()*.006))*.16 if low else 0.0
	vignette.color.a=(clampf(hurt_flash,0,1)*.42+low_pulse if active or hurt_flash>0 else 0.0)*shown
	flash_rect.color.a=clampf(white_flash,0,1)*.35*shown
	if not game.test_mode:
		if shake>0:
			shake=maxf(0,shake-delta*3.2)
			var jolt := Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),0)*shake*shake*.05
			game.camera.position+=game.camera.global_transform.basis*jolt
			game.camera.rotation.z+=rng.randf_range(-1,1)*shake*shake*.007
		if kick.length()>.0005 or absf(roll)>.0005:
			# Directional recoil: the view is shoved away from the lane that landed, and rolls with side cuts.
			game.camera.position+=game.camera.global_transform.basis*kick
			game.camera.rotation.z+=roll
			kick=kick.lerp(Vector3.ZERO,minf(delta*12,1))
			roll=lerpf(roll,0,minf(delta*12,1))
		if punch>0:
			if game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE: game.camera.fov+=punch*punch*6
			punch=maxf(0,punch-delta*5)
	hints.visible=active and not game.input_blocked and not game.menus.home
	hints.modulate.a=clampf((13.0-fight_time)/2.5,0,1)
	if not active:
		enemy_label.text=("SWORDSMAN\nF  Spar   •   K  Combat skills" if respawn<=0 else "Resting…")
	else:
		enemy_label.text=(("FEINT  ·  "+RULES.DIRECTIONS[foe.attack_dir]) if foe.flash>0 and foe.phase=="windup" else ("ATTACK: "+RULES.DIRECTIONS[foe.attack_dir])) if foe.phase=="windup" else ("EXHAUSTED" if foe.phase=="exhausted" else ("Winded" if foe.resting else ("Guard: "+RULES.DIRECTIONS[foe.guard]+("  ·  sharp" if foe.parry_ready else ""))))
	enemy_label.modulate=Color(1,.42,.23) if active and foe.phase=="windup" else Color(.95,.85,.58)
	enemy_label.visible=near_yard and not game.menus.home
	if not active: return
	var blink: bool=int(Time.get_ticks_msec()/180)%2==0
	health_bar.max_value=hero.max_health
	health_bar.value=hero.health
	stamina_bar.max_value=hero.max_stamina
	stamina_bar.value=hero.stamina
	hero_exhaust_bar.value=hero.exhaust
	foe_health_bar.max_value=foe.max_health
	foe_health_bar.value=foe.health
	exhaustion_bar.value=foe.exhaust
	for meter in [health_bar,stamina_bar,hero_exhaust_bar,foe_health_bar,exhaustion_bar]: settle(meter,delta)
	foe_ghost=foe.health if foe_ghost<foe.health else lerpf(foe_ghost,foe.health,minf(delta*2.2,1))
	stamina_bar.modulate=Color(1,.6,.6) if winded(hero) and blink else Color.WHITE
	if stamina_flash>0: stamina_bar.modulate=Color(1,.35,.3)
	health_bar.modulate=Color(1,.7,.7) if low and blink else Color.WHITE
	exhaustion_bar.modulate=Color(1,.85,.6) if foe.exhaust>=75 and blink else Color.WHITE
	you_caption.text="YOU   %d / %d"%[ceili(hero.health),hero.max_health]
	foe_caption.text="SWORDSMAN   %d / %d"%[ceili(foe.health),foe.max_health]
	var cue: String
	var cue_color: Color=UiKit.PARCH
	if salute>0: cue="Salute. The bout begins in a breath."
	elif foe.phase=="windup":
		cue=("Feint! Now " if foe.flash>0 else "Incoming ")+RULES.DIRECTIONS[foe.attack_dir]+("  (heavy)" if foe.heavy else "")
		cue_color=Color(1,1,1) if foe.timer<=RULES.PERFECT_WINDOW else Color(1,.45,.3)
	elif foe.phase=="exhausted":
		cue="Guard broken. A heavy blow finishes."
		cue_color=Color(1,.7,.35)
	elif foe.phase=="recovery" and foe.whiff:
		cue="He missed. Punish the recovery."
		cue_color=UiKit.GOOD
	elif hero.phase=="hurt": cue="Staggered."
	elif foe.resting: cue="He is winded and giving ground."
	else: cue="His guard: "+RULES.DIRECTIONS[foe.guard]+("  ·  sharp, feint it" if foe.parry_ready else "")
	status.text=cue+"\nYour lane: "+RULES.DIRECTIONS[hero.guard]
	if hero.counter>0:
		status.text="COUNTER WINDOW: "+RULES.DIRECTIONS[hero.counter_dir]+(" • critical" if has_skill("riposte") else " • quick riposte")
		cue_color=UiKit.GOLD
	status.add_theme_color_override("font_color",cue_color)
	var progress: Dictionary=RULES.combo_progress(hero.chain)
	var form_text := ""
	if progress.step>0 and hero.chain_time>0:
		var combo: Dictionary=progress.combo
		form_text="\n%s: next %s"%[combo.name,RULES.DIRECTIONS[combo.steps[progress.step]]]
	meters.text="Level %d   XP %d/%d   Skill points %d%s"%[game.equipment.level,game.equipment.xp,RULES.xp_needed(game.equipment.level),game.equipment.skill_points,form_text]
func open_skills() -> void:
	if active: return
	game.audio.ui("ui_panel_open")
	game.input_blocked=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	skill_panel.show()
	refresh_skills()
func refresh_skills() -> void:
	for child in skill_panel.get_children():
		skill_panel.remove_child(child)
		child.queue_free()
	var scroll := ScrollContainer.new()
	skill_panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)
	var title := Label.new()
	title.text="DISCIPLINE   •   Level %d   •   %d skill points"%[game.equipment.level,game.equipment.skill_points]
	title.add_theme_font_size_override("font_size",22)
	column.add_child(title)
	var info := Label.new()
	info.text="XP %d / %d   |   Each level: +6 health, +4 stamina, +4%% damage, +1 protection\nEarn 60 XP and 25 gold per training victory (+20 XP flawless). Each skill costs one point. The swordsman studies you harder as you level."%[game.equipment.xp,RULES.xp_needed(game.equipment.level)]
	info.add_theme_font_size_override("font_size",13)
	column.add_child(info)
	var branches := HBoxContainer.new()
	branches.add_theme_constant_override("separation",18)
	column.add_child(branches)
	for branch in [["COUNTERPLAY","poise","riposte","resolve"],["PRESSURE","footwork","breaker","pursuit"]]:
		var path := VBoxContainer.new()
		path.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		path.add_theme_constant_override("separation",7)
		branches.add_child(path)
		var heading := Label.new()
		heading.text=branch[0]
		heading.modulate=UiKit.GOLD
		path.add_child(heading)
		for id in branch.slice(1):
			var skill: Dictionary={}
			for definition in RULES.skills():
				if definition.id==id: skill=definition
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel",UiKit.flat(Color(.10,.115,.10),Color(.35,.32,.21),1,5,Vector2(12,10)))
			path.add_child(card)
			var content := VBoxContainer.new()
			content.add_theme_constant_override("separation",6)
			card.add_child(content)
			var name_label := Label.new()
			name_label.text=("✓ " if has_skill(id) else "")+skill.name
			name_label.modulate=UiKit.GOLD if has_skill(id) else UiKit.PARCH
			content.add_child(name_label)
			var description := Label.new()
			description.text=skill.text
			description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			description.custom_minimum_size.x=220
			description.add_theme_font_size_override("font_size",14)
			content.add_child(description)
			var button := Button.new()
			var prerequisite: bool=skill.before.is_empty() or has_skill(skill.before)
			button.text="Learn • 1 point" if prerequisite else "Learn the preceding skill first"
			if has_skill(id): button.text="Learned"
			UiKit.skin(button,"secondary")
			button.add_theme_font_size_override("font_size",13)
			button.disabled=has_skill(id) or game.equipment.skill_points<1 or not prerequisite
			button.pressed.connect(func():
				var error: String=game.equipment.learn_combat(id)
				if not error.is_empty(): game.toast(error)
				game.audio.ui("ui_denied" if not error.is_empty() else "skill_learn",-10)
				refresh_skills())
			content.add_child(button)
	# Sword forms are known from the start; the cards are a reference, not a purchase.
	var forms := VBoxContainer.new()
	forms.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	forms.add_theme_constant_override("separation",7)
	branches.add_child(forms)
	var forms_heading := Label.new()
	forms_heading.text="FORMS"
	forms_heading.modulate=UiKit.GOLD
	forms.add_child(forms_heading)
	for combo in RULES.combos():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",UiKit.flat(Color(.10,.115,.10),Color(.35,.32,.21),1,5,Vector2(12,10)))
		forms.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation",6)
		card.add_child(content)
		var name_label := Label.new()
		name_label.text=combo.name
		name_label.modulate=UiKit.PARCH
		content.add_child(name_label)
		var description := Label.new()
		description.text=combo.text+" Cuts must connect within %.1f seconds of each other."%RULES.CHAIN_WINDOW
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.x=220
		description.add_theme_font_size_override("font_size",14)
		content.add_child(description)
	var notes := Label.new()
	notes.text="Feint: change lane in the first half of a swing (6 stamina). Pull: guard in the first half of a swing (4 stamina).\nClash: two swings in the same lane bind and throw both fighters off. A light hit stops an early swing; a heavy hit stops any."
	notes.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notes.add_theme_font_size_override("font_size",13)
	notes.modulate=UiKit.MUTED
	column.add_child(notes)
	var close := Button.new()
	close.text="Return   [K]"
	UiKit.skin(close,"primary")
	close.pressed.connect(close_skills)
	column.add_child(close)
func close_skills() -> void:
	if skill_panel.visible: game.audio.ui("ui_panel_close")
	skill_panel.hide()
	game.input_blocked=false
	game.sync_camera_mouse()

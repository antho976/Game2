extends Node3D
const CENTER := Vector3(19,0,-19)
const RULES = preload("res://scripts/combat_rules.gd")
var game: Node
var active := false
var hero: Dictionary
var foe: Dictionary
var enemy: CharacterBody3D
var enemy_model: Node3D
var enemy_animation: AnimationPlayer
var hero_sword: Node3D
var enemy_sword: Node3D
var hero_grip: SkeletonModifier3D
var enemy_grip: SkeletonModifier3D
var hud: CanvasLayer
var status: Label
var meters: Label
var hints: Label
var stamina_bar: ProgressBar
var exhaustion_bar: ProgressBar
var enemy_label: Label3D
var skill_panel: PanelContainer
var message := ""
var message_time := 0.0
var decision := 1.0
var dodge_time := 0.0
var dodge_recent := 0.0
var dodge_direction := Vector3.ZERO
var swipe := Vector2.ZERO
var parry_lock := 0.0
var respawn := 0.0
var rng := RandomNumberGenerator.new()
func _ready() -> void:
	rng.seed=60908
	hero=RULES.state(100,100)
	foe=RULES.state(140,100)
	build_yard()
	build_hud()
func build_yard() -> void:
	# Open training yard, well away from shops, animals and the school doorway.
	for i in 40:
		var angle := i*TAU/40
		game.world.box(CENTER+Vector3(cos(angle)*3.7,.015,sin(angle)*3.7),Vector3(.22,.045,.22),game.world.stone[i%6])
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
	enemy_grip=add_grip(enemy_model,enemy_sword)
	enemy_label=Label3D.new()
	enemy_label.position=Vector3(0,2.65,0)
	enemy_label.font_size=32
	enemy_label.pixel_size=.0035
	enemy_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	enemy_label.no_depth_test=true
	enemy.add_child(enemy_label)
	pose_sword(enemy_sword,foe,0)
func make_sword(parent: Node3D,style: int) -> Node3D:
	var root := Node3D.new()
	root.name="CombatGreatsword"
	parent.add_child(root)
	var builder := GearVisuals.new()
	builder.steel=GearVisuals.material(Color(.43,.48,.50),.78)
	builder.trim=GearVisuals.material(Color(.54,.40,.20),.72)
	builder.leather=GearVisuals.material(Color(.10,.07,.045))
	builder.sword(root,style)
	return root
func add_grip(model: Node3D,sword: Node3D) -> SkeletonModifier3D:
	var grip=preload("res://scripts/combat_grip.gd").new()
	grip.sword=sword
	model.find_children("*","Skeleton3D",true,false)[0].add_child(grip)
	return grip
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
func start() -> void:
	if active or respawn>0 or game.input_blocked: return
	var values=stats()
	hero=RULES.state(values.health,values.stamina)
	foe=RULES.state(140,100)
	foe.block_age=99.0
	foe.blocking=true
	active=true
	decision=1.1
	dodge_time=0
	dodge_recent=0
	game.player.activity=""
	game.player.activity_time=0
	game.player.position=CENTER+Vector3(0,.1,1.6)
	game.player.collision_mask=5
	game.yaw=0
	game.camera_pitch=0
	game.camera_target=game.player.position
	enemy.position=CENTER+Vector3(0,.1,-1)
	enemy_model.show()
	if is_instance_valid(hero_sword): hero_sword.queue_free()
	hero_sword=make_sword(game.player.model,int(weapon().style))
	hero_grip=add_grip(game.player.model,hero_sword)
	for mount in game.player.model.find_children("GearMountChest*","BoneAttachment3D",true,false):
		# Only hide the back-mounted sword, not chest armor.
		for child in mount.get_children():
			for blade in child.get_children():
				if blade is Node3D and blade.position.y>1.55: blade.hide()
	var hands=game.camera.get_node_or_null("FirstPersonHands")
	if hands: hands.set_weapon(weapon())
	say("Sparring begun. Read the raised guard before you strike.")
func stop(reason: String) -> void:
	if not active: return
	active=false
	hero.blocking=false
	dodge_time=0
	game.player.collision_mask=5
	game.player.velocity=Vector3.ZERO
	if is_instance_valid(hero_grip): hero_grip.queue_free()
	if is_instance_valid(hero_sword): hero_sword.queue_free()
	game.refresh_equipment()
	respawn=3.0
	foe=RULES.state(140,100)
	say(reason)
func say(text: String) -> void:
	message=text
	message_time=2.5
	game.toast(text)
func set_guard(direction: int) -> void:
	hero.guard=direction
func block(pressed: bool) -> void:
	if not active: return
	if pressed and not hero.blocking and hero.phase=="idle" and dodge_time<=0:
		hero.block_age=0.0 if parry_lock<=0 else 99.0
		parry_lock=.32
		hero.blocking=true
	elif not pressed: hero.blocking=false
func attack(heavy: bool) -> bool:
	if not active or hero.phase!="idle" or dodge_time>0: return false
	var cost: float=float(weapon().stamina)*(1.6 if heavy else 1.0)
	if hero.stamina<cost:
		say("Not enough stamina")
		return false
	hero.stamina-=cost
	hero.regen_delay=.8
	hero.phase="windup"
	hero.heavy=heavy
	hero.attack_dir=hero.guard
	hero.blocking=false
	hero.critical=hero.counter>0 and hero.guard==hero.counter_dir and has_skill("riposte")
	hero.pursuit=not heavy and dodge_recent>0 and has_skill("pursuit")
	hero.counter=0.0
	hero.total=(.65 if heavy else (.22 if hero.pursuit else .34))/float(weapon().speed)
	hero.timer=hero.total
	return true
func quickstep() -> bool:
	if not active or hero.phase!="idle" or dodge_time>0: return false
	var cost := 19.0 if has_skill("footwork") else 24.0
	if hero.stamina<cost: return false
	hero.stamina-=cost
	hero.regen_delay=.75
	hero.blocking=false
	dodge_time=.28
	dodge_recent=.65
	var input := Input.get_vector("left","right","up","down")
	dodge_direction=Vector3(input.x,0,input.y).rotated(Vector3.UP,game.yaw).normalized()
	if dodge_direction.length()<.1: dodge_direction=(game.player.position-enemy.position).normalized()
	return true
func movement(direction: Vector3,speed: float) -> Vector3:
	if not active: return direction*speed
	if dodge_time>0: return dodge_direction*8.5
	if hero.phase=="exhausted" or hero.phase=="hurt": return Vector3.ZERO
	return direction*minf(speed,2.8)*(.38 if hero.phase=="windup" else (.55 if hero.blocking else 1.0))
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and not hero.is_empty(): hero.blocking=false
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
	if event is InputEventMouseMotion and hero.blocking:
		swipe+=event.relative
		if swipe.length()>24:
			set_guard((1 if swipe.x>0 else 3) if absf(swipe.x)>absf(swipe.y) else (2 if swipe.y>0 else 0))
			swipe=Vector2.ZERO
		get_viewport().set_input_as_handled()
func tick(fighter: Dictionary,delta: float,is_hero: bool) -> void:
	fighter.block_age+=delta
	fighter.counter=maxf(0,fighter.counter-delta)
	fighter.regen_delay=maxf(0,fighter.regen_delay-delta)
	if fighter.regen_delay<=0 and fighter.phase=="idle":
		var rate: float=18.0*(float(stats().stamina_recovery_multiplier) if is_hero else 1.0)
		fighter.stamina=minf(fighter.max_stamina,fighter.stamina+rate*delta*(.35 if fighter.blocking else 1.0))
	if fighter.phase=="idle": return
	fighter.timer-=delta
	if fighter.timer>0: return
	if fighter.phase=="windup":
		fighter.phase="recovery"
		fighter.timer=.60 if fighter.heavy else .38
		fighter.total=fighter.timer
		resolve_hit(is_hero)
	else:
		if fighter.phase=="exhausted":
			fighter.exhaust=0.0
			fighter.stamina=fighter.max_stamina*.55
		fighter.phase="idle"
func exhaust(fighter: Dictionary) -> void:
	fighter.phase="exhausted"
	fighter.timer=3.0
	fighter.total=3.0
	fighter.blocking=false
func resolve_hit(from_hero: bool) -> String:
	var attacker: Dictionary=hero if from_hero else foe
	var defender: Dictionary=foe if from_hero else hero
	if game.player.position.distance_to(enemy.position)>2.65:
		if from_hero: say("Out of reach")
		return "miss"
	if not from_hero and dodge_time>.055 and dodge_time<.255:
		say("Evaded")
		return "dodge"
	var guarding: bool=defender.blocking and defender.phase=="idle"
	var result := RULES.defence(attacker.attack_dir,defender.guard,guarding,defender.block_age,defender.stamina,28 if attacker.heavy else 18)
	if result=="perfect":
		attacker.exhaust+=38
		attacker.phase="recovery"
		attacker.timer=1.05
		attacker.total=1.05
		defender.counter=1.05
		defender.counter_dir=RULES.opposite(attacker.attack_dir)
		if attacker.exhaust>=100: exhaust(attacker)
		say("Perfect block! Counter from "+RULES.DIRECTIONS[defender.counter_dir]+".")
		impact(true)
		return result
	if result=="block":
		defender.stamina-=28 if attacker.heavy else 18
		defender.regen_delay=1.0
		defender.exhaust+=(26.0*(1.5 if from_hero and has_skill("breaker") else 1.0)) if attacker.heavy else 12.0
		if defender.exhaust>=100 or defender.stamina<=0:
			exhaust(defender)
			say("Exhausted!" if from_hero else "Your guard is exhausted!")
		else: say("Guarded. Change your attack direction." if from_hero else "Blocked")
		impact(true)
		return result
	var damage: float=float(weapon().damage)*(1+(game.equipment.level-1)*.04) if from_hero else 18.0
	damage*=1.65 if attacker.heavy else 1.0
	if from_hero and attacker.critical: damage*=1.65
	if from_hero and attacker.get("pursuit",false): damage*=1.2
	if defender.phase=="exhausted": damage*=1.5
	if not from_hero:
		var protection := float(game.equipment.level-1)*1.0
		for slot in ["helmet","chest","gloves","boots"]:
			var item=game.equipment.owned(int(game.equipment.equipped.get(slot,0)))
			if not item.is_empty(): protection+=float(game.equipment.stats(item).protection)
		damage*=100.0/(100.0+protection)
	if result=="break":
		defender.stamina=0.0
		exhaust(defender)
		damage*=.5
	defender.health=maxf(0,defender.health-damage)
	if defender.phase!="exhausted" and defender.phase!="windup":
		defender.phase="hurt"
		defender.timer=.24
		defender.total=.24
	if from_hero: decision=.12
	defender.blocking=false
	impact(false)
	say(("Critical! " if from_hero and attacker.critical else "")+str(roundi(damage))+" damage")
	if defender.health<=0:
		if from_hero:
			var previous_level: int=game.equipment.level
			var error: String=game.equipment.award_combat(60,25)
			var reward := "Victory. +60 XP, +25 gold"
			if game.equipment.level>previous_level: reward+=" • Level %d! Press K to spend your skill point."%game.equipment.level
			stop(reward if error.is_empty() else error)
		else: stop("Defeated. Rest, then press F to try again. No items lost.")
	return result
func _physics_process(delta: float) -> void:
	respawn=maxf(0,respawn-delta)
	message_time=maxf(0,message_time-delta)
	if not active:
		enemy.position=enemy.position.lerp(CENTER+Vector3(0,.1,-1),minf(delta*2,1))
		enemy_model.rotation.y=0
		enemy_model.rotation.z=0
		pose_sword(enemy_sword,foe,delta)
		return
	if game.input_blocked:
		hero.blocking=false
		return
	if game.player.position.distance_to(CENTER)>6:
		stop("You left the training yard.")
		return
	parry_lock=maxf(0,parry_lock-delta)
	dodge_time=maxf(0,dodge_time-delta)
	dodge_recent=maxf(0,dodge_recent-delta)
	tick(hero,delta,true)
	if not active: return
	tick(foe,delta,false)
	if not active: return
	var toward: Vector3=game.player.position-enemy.position
	toward.y=0
	enemy_model.rotation.y=lerp_angle(enemy_model.rotation.y,atan2(toward.x,toward.z),minf(delta*9,1))
	var moving: bool=toward.length()>2.15 and foe.phase=="idle"
	enemy.velocity=toward.normalized()*1.6 if moving else Vector3.ZERO
	enemy.velocity.y=-2
	enemy.move_and_slide()
	play_enemy("walk" if moving else "idle")
	foe.blocking=foe.phase=="idle"
	if foe.phase=="idle":
		decision-=delta
		if decision<=0:
			foe.guard=rng.randi_range(0,3)
			foe.block_age=99.0 # Trainer uses ordinary guards, never perfect AI reactions.
			if toward.length()<2.6:
				foe.phase="windup"
				foe.attack_dir=foe.guard
				foe.heavy=rng.randf()<.3
				foe.total=1.05 if foe.heavy else .78
				foe.timer=foe.total
				foe.blocking=false
				foe.stamina=maxf(0,foe.stamina-15)
			decision=rng.randf_range(.9,1.6)
	pose_sword(hero_sword,hero,delta)
	pose_sword(enemy_sword,foe,delta)
	enemy_model.rotation.z=sin(foe.timer*32)*.055 if foe.phase=="hurt" else 0.0
	var hands=game.camera.get_node_or_null("FirstPersonHands")
	if hands and hands.visible:
		var held=hands.get_node_or_null("HeldGreatsword")
		if held:
			pose_sword(held,hero,delta,true)
func pose_sword(sword: Node3D,fighter: Dictionary,delta: float,first_person := false) -> void:
	if not is_instance_valid(sword): return
	var direction: int=fighter.attack_dir if fighter.phase=="windup" or fighter.phase=="recovery" else fighter.guard
	var guard_positions := [Vector3(.08,1.36,.43),Vector3(.34,1.13,.42),Vector3(.08,.92,.48),Vector3(-.32,1.13,.42)]
	var guard_rotations := [Vector3(.5,0,1.1),Vector3(.5,0,-.6),Vector3(1.0,0,1.3),Vector3(.5,0,.6)]
	var pos: Vector3=guard_positions[direction]
	var rot: Vector3=guard_rotations[direction]
	if fighter.phase=="windup":
		var t: float=1-fighter.timer/maxf(.01,fighter.total)
		pos+=Vector3(0,.1,-.18)*smoothstep(0,.7,t)
		rot+=Vector3(-.7,0,(-.65 if direction==1 else .65))*smoothstep(0,.6,t)
		var strike := smoothstep(.73,1.0,t)
		pos=pos.lerp(Vector3(-.24 if direction==1 else .24,1.02,.75),strike)
		rot=rot.lerp(Vector3(1.6,0,.9 if direction==1 else -.9),strike)
	elif fighter.phase=="recovery":
		var t: float=1-fighter.timer/maxf(.01,fighter.total)
		var arc: float=1.0-smoothstep(.3,1.0,t)
		pos=pos.lerp(Vector3(-.24 if direction==1 else .24,1.02,.75),arc)
		rot=rot.lerp(Vector3(1.8,0,.9 if direction==1 else -.9),arc)
	elif fighter.phase=="exhausted":
		pos=Vector3(.2,.8,.5)
		rot=Vector3(1.7,0,-.2)
	if first_person:
		pos=Vector3(pos.x*.7,pos.y*.7-1.1,-pos.z*.7-.1)
		rot.x=-rot.x
	var weight: float=1.0 if delta<=0 else minf(delta*22,1)
	sword.position=sword.position.lerp(pos,weight)
	sword.rotation=sword.rotation.lerp(rot,weight)
func play_enemy(action: String) -> void:
	for clip in enemy_animation.get_animation_list():
		if clip.ends_with("villager_"+action) and enemy_animation.current_animation!=clip:
			enemy_animation.play(clip,.2)
func impact(metal: bool) -> void:
	var flash := OmniLight3D.new()
	flash.position=(enemy.position+game.player.position)*.5+Vector3.UP*1.1
	flash.light_color=Color(1,.77,.35) if metal else Color(1,.4,.2)
	flash.omni_range=1.2
	flash.light_energy=.7
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash,"light_energy",0.0,.14)
	tween.tween_callback(flash.queue_free)
	if metal:
		var sound := AudioStreamPlayer3D.new()
		sound.stream=load("res://assets/audio/smith_hammer_anvil_01.ogg")
		sound.volume_db=-15
		sound.pitch_scale=rng.randf_range(1.1,1.35)
		sound.position=flash.position
		add_child(sound)
		sound.play()
		sound.finished.connect(sound.queue_free)
func build_hud() -> void:
	hud=CanvasLayer.new()
	hud.layer=20
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position=Vector2(24,142)
	panel.custom_minimum_size=Vector2(380,0)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",UiKit.flat(Color(.035,.045,.043,.9),Color(.60,.47,.25),1))
	hud.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	status=Label.new()
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size",17)
	column.add_child(status)
	meters=Label.new()
	meters.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(meters)
	stamina_bar=bar(column,Color(.28,.64,.43))
	exhaustion_bar=bar(column,Color(.94,.57,.24))
	var compass=preload("res://scripts/combat_compass.gd").new()
	compass.combat=self
	compass.anchor_left=.5
	compass.anchor_top=.5
	compass.position=Vector2(-64,-64)
	compass.size=Vector2(128,128)
	hud.add_child(compass)
	hints=Label.new()
	hints.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hints.text="LMB Light   Q Heavy   RMB Guard\nSpace Quickstep   F End sparring\nDirection: arrows / RMB + mouse swipe\nGold: your lane   Blue: guard   Red: attack"
	hints.add_theme_font_size_override("font_size",14)
	column.add_child(hints)
	skill_panel=PanelContainer.new()
	skill_panel.anchor_left=.15
	skill_panel.anchor_right=.85
	skill_panel.anchor_top=.10
	skill_panel.anchor_bottom=.9
	skill_panel.theme=UiKit.theme()
	skill_panel.add_theme_stylebox_override("panel",UiKit.flat(Color(.045,.055,.05,.98),UiKit.GOLD,1,8,Vector2(24,20)))
	hud.add_child(skill_panel)
	skill_panel.hide()
func bar(parent: Node,color: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.custom_minimum_size=Vector2(0,7)
	meter.show_percentage=false
	meter.add_theme_stylebox_override("background",UiKit.flat(Color(.10,.13,.12),Color.TRANSPARENT,0,2,Vector2.ZERO))
	meter.add_theme_stylebox_override("fill",UiKit.flat(color,Color.TRANSPARENT,0,2,Vector2.ZERO))
	parent.add_child(meter)
	return meter
func _process(_delta: float) -> void:
	var near_yard: bool=game.player.position.distance_to(CENTER)<8
	hud.get_child(0).visible=active and not game.input_blocked
	enemy_label.text=("SWORDSMAN\nF  Spar   •   K  Combat skills" if respawn<=0 else "Resting…") if not active else (("ATTACK: "+RULES.DIRECTIONS[foe.attack_dir]) if foe.phase=="windup" else ("EXHAUSTED" if foe.phase=="exhausted" else "Guard: "+RULES.DIRECTIONS[foe.guard]))
	enemy_label.modulate=Color(1,.42,.23) if active and foe.phase=="windup" else Color(.95,.85,.58)
	enemy_label.visible=near_yard and not game.menus.home
	if not active: return
	stamina_bar.max_value=hero.max_stamina
	stamina_bar.value=hero.stamina
	exhaustion_bar.value=foe.exhaust
	var cue: String="Incoming "+RULES.DIRECTIONS[foe.attack_dir] if foe.phase=="windup" else ("Enemy exhausted" if foe.phase=="exhausted" else "Enemy guard: "+RULES.DIRECTIONS[foe.guard])
	status.text=cue+"\nYour guard: "+RULES.DIRECTIONS[hero.guard]
	if hero.counter>0: status.text="COUNTER WINDOW: "+RULES.DIRECTIONS[hero.counter_dir]+(" • critical" if has_skill("riposte") else "")
	meters.text="You  HP %d/%d   Stamina %d/%d\nSwordsman  HP %d/140   Exhaustion %d/100\nLevel %d   XP %d/%d   Skill points %d"%[hero.health,hero.max_health,hero.stamina,hero.max_stamina,foe.health,foe.exhaust,game.equipment.level,game.equipment.xp,RULES.xp_needed(game.equipment.level),game.equipment.skill_points]
func open_skills() -> void:
	if active: return
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
	info.text="XP %d / %d   |   Each level: +6 health, +4 stamina, +4%% damage, +1 protection\nEarn 60 XP and 25 gold per training victory. Each skill costs one point."%[game.equipment.xp,RULES.xp_needed(game.equipment.level)]
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
				refresh_skills())
			content.add_child(button)
	var close := Button.new()
	close.text="Return   [K]"
	UiKit.skin(close,"primary")
	close.pressed.connect(close_skills)
	column.add_child(close)
func close_skills() -> void:
	skill_panel.hide()
	game.input_blocked=false
	game.sync_camera_mouse()

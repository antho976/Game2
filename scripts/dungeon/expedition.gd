extends Node3D
const OFFSET := Vector3(180,0,0)
const GATE := Vector3(22,0,-1.2)
const RETURN := Vector3(22,.1,1.25)
var game: Node3D
var active := false
var transitioning := false
var banking := false
var ready_to_fight := false
var mine: Node3D
var battle: Node3D
var trainer: Node3D
var hub_environment: WorldEnvironment
var environment_resource: Environment
var return_position := RETURN
var resume_state: Dictionary = {}
var pending := {"gold":0,"diamonds":0,"xp":0,"essence":0}
var health := 100.0
var cleared: Array[int] = []
var harvested: Array[int] = []
var foes: Array[Dictionary] = []
var target := -1
var returning := false
var cooldown := 0.0
var aim_candidate:=-1
var aim_dwell:=0.0
var gather := -1
var gather_time := 0.0
var gather_origin := Vector3.ZERO
var navigation: AStarGrid2D
var path := PackedVector2Array()
var path_due := 0.0
var hud: CanvasLayer
var haul: Label
var sounds: Dictionary = {}

func _ready() -> void:
	build_gate()
	hud=CanvasLayer.new()
	add_child(hud)
	haul=Label.new()
	haul.position=Vector2(30,73)
	haul.add_theme_font_size_override("font_size",14)
	haul.modulate=Color(.91,.85,.67)
	hud.add_child(haul)
	hud.hide()

func build_gate() -> void:
	var gate: Node3D=load("res://assets/dungeon/first_portal/portal_frame.glb").instantiate()
	gate.name="MinePortal"
	gate.position=GATE
	game.world.add_child(gate)
	for side in [-1,1]:
		var body:=StaticBody3D.new()
		body.position=Vector3(side*1.85,2.05,0)
		var shape:=CollisionShape3D.new()
		var box:=BoxShape3D.new()
		box.size=Vector3(.94,4.1,1.1)
		shape.shape=box
		body.add_child(shape)
		gate.add_child(body)
	var veil:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(2.88,3.58)
	veil.mesh=quad
	veil.position=Vector3(0,1.8,-.06)
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode unshaded,cull_disabled;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float arch=length(vec2(p.x,max(0.0,-p.y*1.25-.23)));
 if(arch>.99)discard;
 float ripple=sin(UV.y*19.0+sin(UV.x*12.0+TIME*.4)-TIME*.5)*.5+.5;
 ALBEDO=mix(vec3(.03,.09,.11),vec3(.25,.47,.45),ripple*.25+pow(arch,12.0)*.65);
}
"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	veil.material_override=mat
	gate.add_child(veil)

func at_gate() -> bool:
	return not active and game.player.position.distance_to(GATE+Vector3(0,0,1))<2.3

func safe_position(pos: Variant,fallback: Vector3) -> Vector3:
	if not pos is Vector3 or not pos.is_finite():return fallback
	if not mine.cells.has(Vector2i(floori(pos.x/2),floori(pos.z/2))) or pos.y<-.2 or pos.y>2:return fallback
	return pos

func enter(state: Dictionary={}) -> void:
	if active or transitioning or game.combat.active:return
	transitioning=true
	game.input_blocked=true
	return_position=RETURN
	resume_state={}
	trainer=game.combat
	trainer.process_mode=Node.PROCESS_MODE_DISABLED
	trainer.hide()
	trainer.hud.hide()
	trainer.clear_weapon()
	hub_environment=game.world.find_children("*","WorldEnvironment",true,false)[0]
	environment_resource=hub_environment.environment
	hub_environment.environment=null
	game.world.hide()
	game.world.process_mode=Node.PROCESS_MODE_DISABLED
	game.village_day.process_mode=Node.PROCESS_MODE_DISABLED
	game.village_day.clock_label.hide()
	sounds.clear()
	for sound in game.audio.beds.values()+game.audio.loops.values()+game.world.find_children("*","AudioStreamPlayer3D",true,false):
		sounds[sound]=sound.stream_paused
		sound.stream_paused=true
	active=true
	mine=preload("res://scripts/dungeon/mine_walkthrough.gd").new()
	mine.embedded=true
	mine.position=OFFSET
	add_child(mine)
	battle=preload("res://scripts/combat.gd").new()
	battle.encounter_mode=true
	battle.game=game
	game.combat=battle
	add_child(battle)
	battle.refresh_weapon()
	battle.encounter_finished.connect(finished,CONNECT_DEFERRED)
	battle.encounter_disengaged.connect(disengaged,CONNECT_DEFERRED)
	foes.clear()
	cleared.clear()
	harvested.clear()
	for id in state.get("cleared",[]):
		if int(id) in range(mine.defenders.size()) and int(id) not in cleared:cleared.append(int(id))
	for id in state.get("harvested",[]):
		if int(id) in range(mine.markers.size()) and mine.markers[int(id)].kind=="seam" and int(id) not in harvested:harvested.append(int(id))
	var saved_foes: Array=state.get("foes",[])
	for i in mine.defenders.size():
		var actor: Dictionary=mine.defenders[i]
		actor["health"]=-1.0
		if i<saved_foes.size() and saved_foes[i] is Dictionary:
			actor.health=maxf(-1,float(saved_foes[i].get("health",-1)))
			actor.model.position=safe_position(saved_foes[i].get("position",actor.pos),actor.pos)
		foes.append(actor)
		if i in cleared:corpse(i,actor.model.global_position)
	for key in pending:pending[key]=clampi(int(state.get("pending",{}).get(key,0)),0,100000)
	health=clampf(float(state.get("health",battle.stats().health)),1,battle.stats().health)
	game.menus.reset_player(OFFSET+safe_position(state.get("position",mine.SPAWN),mine.SPAWN))
	game.overview=false
	target=-1
	returning=false
	cooldown=.8
	gather=-1
	path=PackedVector2Array()
	path_due=0
	hud.show()
	game.hub_subtitle.text="The Spent Works • Bank your haul at the return gate"
	game.blend_doorway_view()
	await get_tree().physics_frame
	build_navigation()
	ready_to_fight=true
	transitioning=false
	game.input_blocked=false
	game.sync_camera_mouse()
	game.toast("The Spent Works. Defeat loses your unbanked haul. F gathers loose fragments.")

func corpse(index: int,where: Vector3) -> void:
	var actor:=foes[index]
	actor.collider.process_mode=Node.PROCESS_MODE_DISABLED
	actor.animation.stop()
	actor.model.global_position=Vector3(where.x,.23,where.z)
	actor.model.rotation.z=PI/2
	actor.model.show()

func engage(index: int) -> void:
	if not active or transitioning or battle.active or index in cleared:return
	target=index
	returning=false
	var actor:=foes[index]
	var pos: Vector3=battle.enemy.position if battle.enemy.visible else actor.model.global_position
	actor.model.hide()
	actor.collider.process_mode=Node.PROCESS_MODE_DISABLED
	battle.begin_encounter(pos,mini(1+index,3),health,actor.health)
	battle.encounter_origin=OFFSET+actor.pos
	path=PackedVector2Array()
	path_due=0

func target_position(index: int) -> Vector3:
	return battle.enemy.position if index==target and (battle.active or returning) else foes[index].model.global_position

func aim_target(point: Vector2) -> int:
	var candidate:=-1
	var best:=95.0
	for i in foes.size():
		if i in cleared:continue
		var position:=target_position(i)
		if position.distance_to(game.player.position)>8:continue
		var chest:=position+Vector3(0,1.2,0)
		if game.camera.is_position_behind(chest):continue
		var d: float=game.camera.unproject_position(chest).distance_to(point)
		if d>=best:continue
		var ray:=PhysicsRayQueryParameters3D.create(game.player.position+Vector3.UP,chest,1,[foes[i].collider.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		best=d
		candidate=i
	return candidate

func update_targeting(delta: float) -> void:
	if game.lock_mode!=0 or not game.lock_enabled:return
	var point: Vector2=game.get_viewport().get_mouse_position() if game.camera_mode in [0,3] else game.get_viewport().get_visible_rect().size*.5
	var candidate:=aim_target(point)
	if candidate!=aim_candidate:
		aim_candidate=candidate
		aim_dwell=0
	else:aim_dwell+=delta
	if candidate>=0 and candidate!=target and aim_dwell>.16 and battle.active:
		# Never redirect a committed strike halfway through its animation.
		if battle.hero.phase=="idle" and battle.dodge_time<=0:switch_target(candidate)

func switch_target(index: int,explicit:=false) -> void:
	if not battle.active or index==target or index in cleared or (game.lock_mode==1 and not explicit) or not game.lock_enabled:return
	if battle.hero.phase!="idle":return
	var old:=foes[target]
	old.health=battle.foe.health
	old["combat_state"]=battle.foe.duplicate(true)
	old.model.global_position=battle.enemy.position
	old.model.rotation.y=battle.enemy_model.rotation.y
	old.model.show()
	old.collider.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=foes[index]
	battle.enemy.position=actor.model.global_position
	actor.model.hide()
	actor.collider.process_mode=Node.PROCESS_MODE_DISABLED
	target=index
	battle.encounter_rank=mini(index+1,3)
	battle.encounter_origin=OFFSET+actor.pos
	battle.profile=CombatRules.partner(battle.encounter_rank)
	battle.foe=actor.get("combat_state",CombatRules.state(battle.profile.health,100)).duplicate(true)
	if actor.health>0:battle.foe.health=actor.health
	battle.foe_ghost=battle.foe.health
	battle.decision=.4
	battle.salute=0
	battle.play_enemy("idle")
	path=PackedVector2Array()
	path_due=0

func vein_guarded() -> bool:
	for i in foes.size():
		if foes[i].pos.z<-52 and i not in cleared:return true
	return false

func finished(won: bool,remaining_health: float) -> void:
	if not active or transitioning or target<0:return
	health=remaining_health
	if not won:
		pending={"gold":0,"diamonds":0,"xp":0,"essence":0}
		resume_state={}
		leave()
		game.menus.save_game()
		game.toast("The gate returns you to the village. Your expedition haul was lost; owned gear is safe.")
		return
	if target not in cleared:
		cleared.append(target)
		pending.gold+=25+target*10
		pending.xp+=60+target*15
		if target==2:pending.diamonds+=1
		corpse(target,battle.enemy.position)
	battle.enemy.hide()
	battle.enemy.collision_layer=0
	target=-1
	cooldown=2
	game.menus.save_game()

func disengaged(remaining_health: float,foe_health: float) -> void:
	if not active or target<0:return
	health=remaining_health
	foes[target].health=foe_health
	returning=true
	cooldown=3
	path=PackedVector2Array()
	path_due=0

func nearest_marker() -> int:
	var nearest:=-1
	var distance:=2.5
	for i in mine.markers.size():
		var d: float=game.player.position.distance_to(OFFSET+mine.markers[i].pos)
		if d<distance:
			nearest=i
			distance=d
	return nearest

func interaction_text() -> String:
	if transitioning:return "Crossing the threshold…"
	if battle.active:return ""
	if gather>=0:return "Gathering loose fragments…"
	var index:=nearest_marker()
	if index<0:return ""
	var entry: Dictionary=mine.markers[index]
	if entry.kind=="return":return "F  ·  Return to the village and bank your haul"
	if entry.kind=="seam":
		if index in harvested:return "Loose fragments gathered. The living vein remains."
		return "The vein is guarded by a Warden." if vein_guarded() else "F  ·  Gather loose living fragments"
	return "F  ·  "+str(entry.label)

func interact() -> void:
	if transitioning or battle.active or gather>=0:return
	var index:=nearest_marker()
	if index<0:return
	var entry: Dictionary=mine.markers[index]
	if entry.kind=="return":bank_and_return()
	elif entry.kind=="seam":
		if index in harvested or vein_guarded():return
		gather=index
		gather_time=1.5
		gather_origin=game.player.position
		game.player.act("pet",OFFSET+entry.pos,1.5)
	else:game.toast(entry.text)

func bank_and_return() -> bool:
	if not active or transitioning or battle.active:return false
	banking=true
	var summary:="Returned with %d gold, %d diamond(s), %d living essence and %d XP."%[pending.gold,pending.diamonds,pending.essence,pending.xp]
	var result: String=game.equipment.award_combat(pending.xp,pending.gold,pending.diamonds,pending.essence)
	banking=false
	if not result.is_empty():
		game.toast("Could not bank the haul. It is still with you; try again. "+result)
		return false
	pending={"gold":0,"diamonds":0,"xp":0,"essence":0}
	resume_state={}
	leave()
	game.toast(summary)
	return true

func snapshot() -> Dictionary:
	if banking:return {}
	if not active:return resume_state.duplicate(true)
	var records: Array=[]
	for i in foes.size():
		var actor:=foes[i]
		records.append({"health":battle.foe.health if battle.active and target==i else actor.health,"position":battle.enemy.position-OFFSET if target==i and (battle.active or returning) else actor.model.global_position-OFFSET})
	return {"active":true,"health":battle.hero.health if battle.active else health,"position":game.player.last_safe-OFFSET,"pending":pending.duplicate(),"cleared":cleared.duplicate(),"harvested":harvested.duplicate(),"foes":records}

func suspend() -> void:
	if not active:return
	resume_state=snapshot()
	leave()

func restore(state: Dictionary) -> void:
	if active:leave()
	resume_state=state.duplicate(true)

func resume_saved() -> void:
	if resume_state.get("active",false):enter(resume_state.duplicate(true))

func leave() -> void:
	if not active:return
	transitioning=true
	ready_to_fight=false
	if battle.skill_panel.visible:battle.close_skills()
	if battle.active:battle.stop("")
	Engine.time_scale=1.0
	# Clear the mine environment before restoring the hub's WorldEnvironment.
	for env in mine.find_children("*","WorldEnvironment",true,false):env.environment=null
	mine.hide()
	mine.process_mode=Node.PROCESS_MODE_DISABLED
	mine.queue_free()
	battle.hud.hide()
	battle.process_mode=Node.PROCESS_MODE_DISABLED
	battle.queue_free()
	game.combat=trainer
	trainer.process_mode=Node.PROCESS_MODE_INHERIT
	trainer.show()
	trainer.hud.show()
	game.world.process_mode=Node.PROCESS_MODE_INHERIT
	game.world.show()
	hub_environment.environment=environment_resource
	game.village_day.process_mode=Node.PROCESS_MODE_INHERIT
	game.village_day.clock_label.show()
	for sound in sounds:
		if is_instance_valid(sound):sound.stream_paused=sounds[sound]
	sounds.clear()
	active=false
	gather=-1
	target=-1
	returning=false
	hud.hide()
	game.menus.reset_player(return_position)
	game.title.text="THE VILLAGE"
	game.hub_subtitle.text="A quiet place to return to"
	game.refresh_equipment()
	game.input_blocked=false
	transitioning=false
	game.sync_camera_mouse()

func build_navigation() -> void:
	navigation=AStarGrid2D.new()
	navigation.region=Rect2i(-17,-73,33,91)
	navigation.cell_size=Vector2.ONE
	navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.35
	capsule.height=1.7
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule
	query.collision_mask=1
	var excluded: Array[RID]=[]
	for actor in foes:excluded.append(actor.collider.get_rid())
	query.exclude=excluded
	for x in range(-17,16):
		for z in range(-73,18):
			var id:=Vector2i(x,z)
			var solid: bool=not mine.cells.has(Vector2i(floori(x/2.0),floori(z/2.0)))
			if not solid:
				query.transform=Transform3D(Basis.IDENTITY,OFFSET+Vector3(x,.90,z))
				solid=not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
			navigation.set_point_solid(id,solid)

func nav_point(pos: Vector3) -> Vector2i:
	var local:=pos-OFFSET
	var origin:=Vector2i(roundi(local.x),roundi(local.z))
	for radius in range(4):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var cell:=origin+Vector2i(x,z)
				if navigation.is_in_boundsv(cell) and not navigation.is_point_solid(cell):return cell
	return origin

func chase_direction(from: Vector3,to: Vector3) -> Vector3:
	if navigation==null:return Vector3.ZERO
	if path_due<=0 or path.is_empty():
		path_due=.4
		var start:=nav_point(from)
		var end:=nav_point(to)
		if not navigation.is_in_boundsv(start) or not navigation.is_in_boundsv(end):return Vector3.ZERO
		path=navigation.get_point_path(start,end)
	while not path.is_empty():
		var next:=OFFSET+Vector3(path[0].x,from.y,path[0].y)
		var delta:=next-from
		delta.y=0
		if delta.length()<.35:path.remove_at(0)
		else:return delta.normalized()
	return Vector3.ZERO

func _process(delta: float) -> void:
	if not active or transitioning:return
	var first: bool=game.camera_mode==1
	mine.roof.visible=first
	mine.shell.scale.y=1.0 if first else .42
	mine.ceiling_light.light_energy=0 if first else .5
	mine.cave_environment.ambient_light_energy=.80 if first else .65
	var area_name:="THE SPENT WORKS"
	for area in mine.AREAS:
		if area[1].has_point(Vector2(game.player.position.x-OFFSET.x,game.player.position.z)):
			area_name=area[0]
			break
	game.title.text=area_name
	haul.text="Unbanked: %d gold • %d diamond(s) • %d essence • %d XP"%[pending.gold,pending.diamonds,pending.essence,pending.xp]
	hud.visible=not game.menus.home and game.ui.visible
	if game.input_blocked:return
	cooldown=maxf(0,cooldown-delta)
	path_due=maxf(0,path_due-delta)
	if gather>=0:
		gather_time-=delta
		if game.player.position.distance_to(gather_origin)>.6 or battle.active:gather=-1
		elif gather_time<=0:
			if gather not in harvested:
				harvested.append(gather)
				pending.essence+=4
				pending.diamonds+=1
				game.toast("Gathered 4 living essence and a diamond. Return through the gate to bank them.")
			gather=-1
			game.menus.save_game()

func _physics_process(delta: float) -> void:
	if not active or not ready_to_fight or transitioning or game.input_blocked:return
	if battle.active:
		update_targeting(delta)
		return
	if returning and target>=0:
		var home: Vector3=OFFSET+foes[target].pos
		if battle.enemy.position.distance_to(home)<.55:
			foes[target].model.position=foes[target].pos
			foes[target].model.show()
			foes[target].collider.process_mode=Node.PROCESS_MODE_INHERIT
			battle.enemy.hide()
			battle.enemy.collision_layer=0
			target=-1
			returning=false
		else:
			var direction:=chase_direction(battle.enemy.position,home)
			battle.enemy.velocity=direction*1.7+Vector3.DOWN*2
			battle.enemy.move_and_slide()
			battle.enemy_model.rotation.y=lerp_angle(battle.enemy_model.rotation.y,atan2(direction.x,direction.z),minf(8*delta,1))
			battle.play_enemy("walk")
	if cooldown>0:return
	for i in foes.size():
		if i in cleared:continue
		if returning and i!=target:continue
		var pos: Vector3=battle.enemy.position if returning else foes[i].model.global_position
		if game.player.position.distance_to(pos)>5.2:continue
		var query:=PhysicsRayQueryParameters3D.create(game.player.position+Vector3.UP,pos+Vector3.UP,1,[foes[i].collider.get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			engage(i)
			break

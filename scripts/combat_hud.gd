extends Control
var combat: Node
var dock: PanelContainer
var enemy_plate: PanelContainer
var skill_slots: Array[Label]=[]
var stamina_caption: Label
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dock=UiKit.panel(self,UiKit.flat(Color(.025,.038,.035,.94),UiKit.tinted(UiKit.GOLD,.45),1,8,Vector2(12,8)))
	dock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dock.grow_horizontal=Control.GROW_DIRECTION_BOTH
	dock.grow_vertical=Control.GROW_DIRECTION_BEGIN
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	dock.add_child(column)
	combat.status=UiKit.label(column,"",13)
	combat.status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	combat.status.autowrap_mode=TextServer.AUTOWRAP_OFF
	var vitals:=HBoxContainer.new()
	vitals.add_theme_constant_override("separation",18)
	column.add_child(vitals)
	var hp:=VBoxContainer.new()
	hp.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	vitals.add_child(hp)
	combat.you_caption=UiKit.label(hp,"HEALTH",12)
	combat.health_bar=combat.bar(hp,Color(.73,.24,.22),8)
	combat.hero_exhaust_bar=combat.bar(hp,UiKit.EMBER,3)
	var sp:=VBoxContainer.new()
	sp.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	vitals.add_child(sp)
	stamina_caption=UiKit.label(sp,"STAMINA",12)
	combat.stamina_bar=combat.bar(sp,Color(.32,.65,.43),8)
	combat.meters=UiKit.label(column,"",11,UiKit.MUTED)
	combat.meters.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	combat.meters.autowrap_mode=TextServer.AUTOWRAP_OFF
	combat.status.hide()
	combat.meters.hide()
	enemy_plate=UiKit.panel(self,UiKit.flat(Color(.025,.028,.026,.9),UiKit.tinted(UiKit.GOLD,.5),1,4,Vector2(8,5)))
	enemy_plate.custom_minimum_size=Vector2(196,0)
	var foe:=VBoxContainer.new()
	foe.add_theme_constant_override("separation",3)
	enemy_plate.add_child(foe)
	combat.foe_caption=UiKit.label(foe,"",11,UiKit.PARCH)
	combat.foe_caption.autowrap_mode=TextServer.AUTOWRAP_OFF
	combat.foe_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	combat.foe_health_bar=combat.bar(foe,Color(.77,.26,.20),8)
	combat.exhaustion_bar=combat.bar(foe,UiKit.EMBER,3)
	ignore_mouse(self)
func ignore_mouse(node: Node) -> void:
	if node is Control:node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():ignore_mouse(child)
func refresh(delta: float) -> void:
	var game: Node=combat.game
	var visible_game: bool=game.ui.visible and not game.menus.home and not game.input_blocked and not game.overview
	dock.visible=visible_game
	var width:=minf(460,get_viewport_rect().size.x-32)
	dock.offset_left=-width/2
	dock.offset_right=width/2
	dock.offset_top=-74
	dock.offset_bottom=-16
	enemy_plate.hide()
	if combat.active and visible_game:
		var head: Vector3=combat.enemy.global_position+Vector3(0,2.65,0)
		var camera: Camera3D=game.camera
		if not camera.is_position_behind(head):
			var screen:=camera.unproject_position(head)
			var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,head,1)
			var body_screen:=camera.unproject_position(combat.enemy.global_position+Vector3.UP)
			if (get_viewport_rect().has_point(screen) or get_viewport_rect().has_point(body_screen)) and game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				screen.x=clampf(screen.x,enemy_plate.size.x/2+8,get_viewport_rect().size.x-enemy_plate.size.x/2-8)
				screen.y=maxf(screen.y,enemy_plate.size.y+16)
				enemy_plate.position=screen-Vector2(enemy_plate.size.x/2,enemy_plate.size.y+8)
				enemy_plate.show()
	if not combat.active:
		var stats: Dictionary=combat.stats()
		var hp: float=game.expedition.health if is_instance_valid(game.expedition) and game.expedition.active else stats.health
		combat.health_bar.max_value=stats.health
		combat.health_bar.value=hp
		combat.stamina_bar.max_value=stats.stamina
		combat.stamina_bar.value=stats.stamina
		combat.hero_exhaust_bar.value=0
		combat.you_caption.text="HEALTH   %d / %d"%[ceili(hp),stats.health]
		combat.status.text=""
		combat.meters.text="LEVEL %d    ·    %d / %d XP    ·    %d SKILL POINTS"%[game.equipment.level,game.equipment.xp,CombatRules.xp_needed(game.equipment.level),game.equipment.skill_points]
		for bar in [combat.health_bar,combat.stamina_bar,combat.hero_exhaust_bar]:combat.settle(bar,delta)
	stamina_caption.text="STAMINA   %d / %d"%[ceili(combat.stamina_bar.value),combat.stamina_bar.max_value]

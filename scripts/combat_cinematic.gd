extends Node
# The execution. When the stagger bar fills, the fighter is exhausted and a mark shows on his
# body; a heavy cut into that lane hands the bout to this node for a couple of seconds. Both rigs
# are authored frame by frame from CombatChoreo, the camera leaves the player's shoulder for a
# low side shot of the wind-up and an over-the-shoulder shot of the cut, and the blow lands with
# a long freeze, a white flash and the biggest number in the game. Then everyone is let go.
const LENGTH := 2.4
const LAND := .56 # Fraction of the timeline at which the edge meets the mark.
var combat: Node
var time := -1.0
var lane := 0
var damage := 0.0
var landed := false
var from_camera: Transform3D
var from_fov := 75.0
var shake := 0.0
func active() -> bool: return time>=0
func begin(weak_lane: int,blow: float) -> void:
	lane=weak_lane
	damage=blow
	time=0.0
	landed=false
	shake=0.0
	var camera: Camera3D=combat.game.camera
	from_camera=camera.global_transform
	from_fov=camera.fov if camera.projection==Camera3D.PROJECTION_PERSPECTIVE else 70.0
	for fighter in [combat.hero,combat.foe]:
		fighter.phase="cinematic"
		fighter.blocking=false
		fighter.knock=Vector3.ZERO
	combat.game.player.velocity=Vector3.ZERO
	combat.enemy.velocity=Vector3.ZERO
	combat.hero.attack_dir=lane
	combat.audio.play("hero_effort",combat.game.player.position+Vector3.UP*1.5,-8,.85)
	combat.game.audio.set_ducked(true)
# Stepped by the combat node's physics process while active, after the player has moved.
func step(delta: float) -> void:
	if time<0: return
	time+=delta
	shake=maxf(0,shake-delta*2.5)
	var u: float=clampf(time/LENGTH,0,1)
	var clock: float=combat.clock
	var hero: Dictionary=CombatChoreo.execution(lane,u,clock)
	var foe: Dictionary=CombatChoreo.executed(lane,u,clock)
	if is_instance_valid(combat.hero_sword): combat.apply_blade(combat.hero_sword,hero.xf,60.0,delta,true,false)
	if is_instance_valid(combat.enemy_sword): combat.apply_blade(combat.enemy_sword,foe.xf,30.0,delta,false,false)
	if is_instance_valid(combat.hero_stance): combat.hero_stance.pose(hero.pose,40.0)
	if is_instance_valid(combat.enemy_stance): combat.enemy_stance.pose(foe.pose,26.0)
	# The whole body turns through the cut: the model yaw carries what the spine cannot.
	var yaw: float=0.0
	if u<.42: yaw=-CombatChoreo.SIDE[lane]*.55*smoothstep(0,1,u/.42)
	elif u<.56: yaw=lerpf(-CombatChoreo.SIDE[lane]*.55,CombatChoreo.SIDE[lane]*.45,pow((u-.42)/.14,1.5))
	elif u<.72: yaw=CombatChoreo.SIDE[lane]*.45
	else: yaw=lerpf(CombatChoreo.SIDE[lane]*.45,0,smoothstep(0,1,(u-.72)/.28))
	combat.game.player.model.rotation.y=combat.game.player.facing-yaw
	if u>=.30 and u<.42 and not combat.foe.get("wound_cue",false):
		combat.foe.wound_cue=true
		combat.audio.play("heavy_whoosh",combat.game.player.position+Vector3.UP*1.3,-10,.7)
	if not landed and u>=LAND:
		landed=true
		shake=1.0
		combat.execution_hit(damage,lane)
	if u>=1.0: finish()
func finish() -> void:
	time=-1.0
	combat.foe.erase("wound_cue")
	combat.end_execution()
	combat.game.audio.set_ducked(false)
# Places the camera for the current beat; called from the game's camera update while active.
func place_camera(camera: Camera3D,delta: float) -> void:
	var u: float=clampf(time/LENGTH,0,1)
	var hero_pos: Vector3=combat.game.player.position
	var foe_pos: Vector3=combat.enemy.position
	var forward: Vector3=(foe_pos-hero_pos)
	forward.y=0
	forward=forward.normalized() if forward.length()>.01 else Vector3.FORWARD
	var side: Vector3=forward.cross(Vector3.UP)*(-1.0 if lane==1 else 1.0)
	var pivot: Vector3=(hero_pos+foe_pos)*.5+Vector3.UP*1.15
	var pos: Vector3
	var look: Vector3
	var fov := 50.0
	if u<.42:
		# The wind-up from low on the far side, drifting in as the blade goes back.
		var c: float=u/.42
		pos=pivot+side*(2.9-.5*c)-forward*(.9-.3*c)+Vector3.UP*(-.35+.15*c)
		look=pivot+Vector3.UP*(.05-.1*c)
		fov=48.0
	else:
		# Over the shoulder for the cut, pushed in on the hit and eased out again afterwards.
		var c: float=smoothstep(0,1,(u-.42)/.10)
		var a: Vector3=pivot+side*2.4-forward*.6+Vector3.UP*-.2
		var b: Vector3=hero_pos-forward*1.35+side*.75+Vector3.UP*1.75
		pos=a.lerp(b,c)
		look=(pivot+Vector3.UP*-.05).lerp(foe_pos+Vector3.UP*1.2,c)
		fov=lerpf(48.0,56.0,c)
		if landed:
			var after: float=clampf((u-LAND)/.16,0,1)
			pos+=forward*.22*(1-after)
			fov+=8.0*(1-after)
		if u>.80:
			# Hand the view back to the player without a cut.
			var back: float=smoothstep(0,1,(u-.80)/.20)
			pos=pos.lerp(from_camera.origin,back)
			fov=lerpf(fov,from_fov,back)
			var target := Transform3D(Basis.looking_at(look-pos),pos)
			camera.global_transform=target.interpolate_with(from_camera,back)
			camera.fov=fov
			return
	if shake>0:
		var rng: RandomNumberGenerator=combat.rng
		pos+=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))*shake*shake*.06
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.near=.04
	camera.global_position=pos
	camera.look_at(look)
	camera.fov=fov

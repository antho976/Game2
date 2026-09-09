class_name CombatChoreo
extends RefCounted
# Blade and body choreography for the duel, authored once in the player's screen space
# (+x screen right, +y up, +z toward the opponent, hilt positions relative to the fighter's feet)
# and mirrored onto each rig by the caller. A pose is a Transform3D for the sword root: its +y
# runs up the blade and its +x is the edge, so every key is written as a hilt point, a direction
# the tip points in and a direction the edge faces. Cuts follow an arc through a mid point with
# the edge leading, accelerate into contact and carry through past it; guards are the hanging
# and vertical covers of two-handed fencing rather than a blade parked in a lane.
#
# Handedness: the lead hand (nearest the cross) belongs to the shoulder on the +x side of this
# space, so a Right cut is the forehand thrown from the lead shoulder and a Left cut the backhand
# drawn across the body. Every hilt below is placed so both hands reach it on the villager rig,
# whose arms are short (about half a metre from shoulder to wrist).
# Every hilt below also keeps the whole grip, pommel included, outside the body: the villager's
# torso is about a quarter of a metre wide and fifteen centimetres deep, and a pommel that ends
# inside the chest reads as a blade through the body from any close camera.
const READY_HILT := Vector3(-.01,1.31,.38)
const READY_TIP := Vector3(-.05,.55,.83)
# Covers, one per lane, each built to meet that lane's cut edge on: High is a horizontal roof
# held above the head, the point to the lead side so the arms stay uncrossed; Right and Left are
# tall covers on that side, the blade climbing outward from the chest with the edge turned out
# toward the incoming cut; Low is a hanging point, the blade dropped in front of the belly and
# thighs with the edge forward to meet the rising cut.
const GUARD_HILT := [Vector3(-.02,1.70,.24),Vector3(.14,1.34,.26),Vector3(.04,1.42,.32),Vector3(-.14,1.34,.26)]
const GUARD_TIP := [Vector3(.82,.24,.52),Vector3(.32,.90,.28),Vector3(-.10,-.78,.62),Vector3(-.32,.90,.28)]
const GUARD_EDGE := [Vector3(0,1,.3),Vector3(1,0,.35),Vector3(0,-.35,1),Vector3(-1,0,.35)]
# The direction a cut in each lane travels across the screen at contact: an overhead falls, a
# Right cut sweeps from screen right to left, a Low cut rises, a Left cut sweeps from left to
# right. The same for both fighters, since lanes are read from the player's side. A block is
# driven this way and a hit thrown this way; a perfect parry beats the blade back against it.
const TRAVEL := [Vector3(0,-1,0),Vector3(-1,-.25,0),Vector3(0,1,0),Vector3(1,-.25,0)]
# Where a freshly raised guard overshoots before it settles: past the cover, outward.
const RAISE_OVER := [Vector3(0,.08,.04),Vector3(.06,.05,.03),Vector3(0,-.06,.06),Vector3(-.06,.05,.03)]
# Cuts. High: an overhead cut, the hilt raised above the head and the blade laid back over it.
# Right and Left: diagonal cuts from a chamber beside the head, the blade over that shoulder.
# Low: a rising cut chambered from the fool's guard, the blade pointed at the ground in front of
# the lead hip (the arms are too short to draw a pommel behind the hip and keep it out of the body).
const CHAMBER_HILT := [Vector3(.06,1.84,.06),Vector3(.20,1.60,.08),Vector3(.16,1.12,.30),Vector3(-.20,1.60,.08)]
const CHAMBER_TIP := [Vector3(.06,.70,-.71),Vector3(.50,.72,-.48),Vector3(.62,-.72,.30),Vector3(-.50,.72,-.48)]
const CHAMBER_EDGE := [Vector3(0,.3,1),Vector3(-1,-.2,.4),Vector3(0,1,.6),Vector3(1,-.2,.4)]
const MID_HILT := [Vector3(.06,1.62,.20),Vector3(.14,1.46,.22),Vector3(.14,1.02,.30),Vector3(-.14,1.46,.22)]
const STRIKE_HILT := [Vector3(.02,1.30,.40),Vector3(-.04,1.26,.34),Vector3(.08,1.24,.41),Vector3(.04,1.26,.34)]
const STRIKE_TIP := [Vector3(0,-.36,.93),Vector3(-.76,-.14,.63),Vector3(-.06,-.22,.97),Vector3(.76,-.14,.63)]
const STRIKE_EDGE := [Vector3(0,-1,.4),Vector3(-1,-.3,.3),Vector3(0,1,.2),Vector3(1,-.3,.3)]
const FOLLOW_HILT := [Vector3(-.02,1.14,.32),Vector3(-.10,1.24,.26),Vector3(.02,1.46,.36),Vector3(.10,1.24,.26)]
const FOLLOW_TIP := [Vector3(-.18,-.86,.48),Vector3(-.92,-.30,.26),Vector3(-.22,.70,.68),Vector3(.92,-.30,.26)]
const FOLLOW_EDGE := [Vector3(0,-1,0),Vector3(-1,-.5,0),Vector3(0,1,0),Vector3(1,-.5,0)]
const SIDE := [0.0,1.0,.35,-1.0] # How far to the screen right each lane's motion leans.
const CUT_AT := .62 # Fraction of a windup at which the chamber releases into the cut.
const FLASH := .30 # Seconds a block or parry reaction lasts; matches the flash the bout sets.
static func frame(hilt: Vector3,tip: Vector3,edge: Vector3) -> Transform3D:
	var y := tip.normalized()
	var x := (edge-y*edge.dot(y))
	if x.length()<.01: x=Vector3(1,0,0)-y*y.x
	x=x.normalized()
	return Transform3D(Basis(x,y,x.cross(y)),hilt)
static func blend(a: Transform3D,b: Transform3D,t: float) -> Transform3D:
	return a.interpolate_with(b,clampf(t,0,1))
# Rotation slerps while the hilt follows a quadratic curve through `mid`, so a cut travels an arc.
static func arc(a: Transform3D,mid: Vector3,b: Transform3D,t: float) -> Transform3D:
	t=clampf(t,0,1)
	var result := a.interpolate_with(b,t)
	result.origin=a.origin.lerp(mid,t).lerp(mid.lerp(b.origin,t),t)
	return result
static func ready(breath: float) -> Transform3D:
	# The point hovers at the opponent's face and circles a little: a live blade, not a parked one.
	var hilt := READY_HILT+Vector3(0,.012*breath,.01*breath)
	var tip := READY_TIP+Vector3(.05*sin(breath*2.7),.03*breath,0)
	return frame(hilt,tip,Vector3(0,1,-.2))
static func guard(lane: int) -> Transform3D: return frame(GUARD_HILT[lane],GUARD_TIP[lane],GUARD_EDGE[lane])
# A held guard breathes: the hilt rides the chest and the point wavers, so the cover is a
# fighter holding a blade, not a statue.
static func held_guard(lane: int,breath: float) -> Transform3D:
	var xf := guard(lane)
	xf.origin+=Vector3(0,.008*breath,.006*breath)
	xf.basis=xf.basis*Basis(Vector3(0,0,1),.02*sin(breath*2.3))
	return xf
static func chamber(lane: int,heavy: bool) -> Transform3D:
	var hilt: Vector3=CHAMBER_HILT[lane]
	var tip: Vector3=CHAMBER_TIP[lane]
	if heavy:
		# A heavy cut is chambered farther back and higher, so the blade has farther to fall; the
		# High and Low chambers already sit against the head and the chest, so they only rise.
		hilt+=[Vector3(.04,.02,.02),Vector3(.03,.06,-.06),Vector3(.01,.06,0),Vector3(-.03,.06,-.06)][lane]
		tip+=Vector3(0,.15,-.2)
	return frame(hilt,tip,CHAMBER_EDGE[lane])
static func strike(lane: int,heavy: bool) -> Transform3D:
	var hilt: Vector3=STRIKE_HILT[lane]+(Vector3(0,-.03,.04) if heavy else Vector3.ZERO)
	return frame(hilt,STRIKE_TIP[lane],STRIKE_EDGE[lane])
static func follow(lane: int,heavy: bool) -> Transform3D:
	var hilt: Vector3=FOLLOW_HILT[lane]+(Vector3(-SIDE[lane]*.04,-.04,-.02) if heavy else Vector3.ZERO)
	return frame(hilt,FOLLOW_TIP[lane],FOLLOW_EDGE[lane])
# Where a swing starts: the pose the blade was last shown in, recorded by the bout as `from_xf`
# when the swing (or a feint) began, so a chamber is drawn from wherever the blade already is.
static func swing_start(f: Dictionary,lane: int,breath: float) -> Transform3D:
	if f.has("from_xf"): return f.from_xf
	return guard(lane) if f.get("from_guard",false) else ready(breath)
# The sword pose for a fighter's current state and a rate at which the rig should follow it.
static func blade(f: Dictionary,progress: float,breath: float,clock: float) -> Dictionary:
	var lane: int=f.attack_dir if f.phase in ["windup","recovery","open"] else f.guard
	var heavy: bool=f.heavy
	var rate := 22.0
	var xf: Transform3D
	match f.phase:
		"windup":
			var t: float=progress
			var from_at: float=clampf(float(f.get("from_at",0.0)),0,.56)
			var coil: float=smoothstep(from_at,.58,t)
			var start: Transform3D=swing_start(f,lane,breath)
			var lift: Vector3=(start.origin+CHAMBER_HILT[lane])*.5+Vector3(SIDE[lane]*.03,.08,.04)
			xf=arc(start,lift,chamber(lane,heavy),coil*coil*(3-2*coil))
			if t>=CUT_AT:
				# The cut: the blade accelerates through an arc and is at full speed at contact.
				var u: float=(t-CUT_AT)/(1.0-CUT_AT)
				xf=arc(chamber(lane,heavy),MID_HILT[lane],strike(lane,heavy),pow(u,1.7))
				rate=70.0
			elif heavy and t>.46:
				# The heavy blade trembles at the top of its chamber before it drops.
				var tremor: float=(t-.46)/.16
				xf.origin+=Vector3(sin(clock*90)*.012,sin(clock*70)*.01,0)*tremor
		"recovery":
			var t: float=progress
			var through: float=1.0-pow(1.0-clampf(t/.30,0,1),2.2) # Leaves contact at full speed.
			var back: float=smoothstep(.30,1.0,t)
			var rest: Transform3D=held_guard(lane,breath) if f.blocking else blend(ready(breath),guard(lane),.25)
			var carried: Transform3D=blend(strike(lane,heavy),follow(lane,heavy),through)
			if f.get("bounce",false):
				# Met steel: the edge stops short and springs back off the guard instead of carrying on.
				carried=blend(strike(lane,heavy),follow(lane,heavy),through*.30)
				carried.origin+=(Vector3(0,.02,-.12)-TRAVEL[lane]*.08)*(1.0-back)
				carried.basis=carried.basis*Basis(Vector3(1,0,0),.18*(1.0-back))
			if f.get("whiff",false):
				# Nothing met the edge: the blade overreaches and drags the shoulders after it.
				carried.origin+=Vector3(-SIDE[lane]*.08,-.06,.10)*(1.0-back)
			if f.total>=1.0:
				# Parried: the blade is flung wide and takes its time coming back.
				carried.origin+=Vector3(.10 if lane!=1 else -.10,.08,-.10)*(1.0-back)
				carried.basis=carried.basis*Basis(Vector3(0,0,1),(.6 if lane!=1 else -.6)*(1.0-back))
			xf=blend(carried,rest,back*back)
			rate=18.0
		"open":
			# Turned aside by a perfect parry: the blade is stuck out where it was met, the wrists
			# straining against it, and only creeps back over the length of the opening.
			var held: float=clampf(f.open/maxf(f.get("open_total",1.0),.01),0,1)
			var jarred: Transform3D=strike(lane,heavy)
			jarred.origin+=Vector3(SIDE[lane]*.12+(.08 if lane==0 else (-.04 if lane==2 else 0.0)),.04 if lane!=0 else -.08,-.06)
			jarred.basis=jarred.basis*Basis(Vector3(0,0,1),-SIDE[lane]*.8 if lane%2==1 else 0.0)*Basis(Vector3(1,0,0),.55 if lane==0 else (-.45 if lane==2 else 0.0))
			jarred.origin+=Vector3(sin(clock*38)*.012,sin(clock*47)*.01,0)*held
			xf=blend(guard(lane),jarred,smoothstep(0,.35,held))
			rate=14.0
		"hurt":
			# Struck: the blade is knocked along the blow that landed and the point drops.
			var reel: float=1.6 if f.get("staggered",false) else 1.0
			var from: int=int(f.get("hit_from",lane))
			xf=guard(lane) if f.blocking else ready(breath)
			xf.origin+=(TRAVEL[from]*.08+Vector3(SIDE[lane]*.03,-.06,-.06))*reel
			xf.basis=xf.basis*Basis(Vector3(1,0,0),-.45*reel)*Basis(Vector3(0,0,1),-SIDE[from]*.25*reel)
			rate=30.0
		"exhausted":
			# Spent: bent double, the point dropped to the ground, shoulders heaving.
			var heave: float=sin(clock*4.2)
			xf=frame(Vector3(.06+heave*.01,1.05+heave*.02,.26),Vector3(.12,-1,.42),Vector3(1,0,0))
			rate=7.0
		_:
			if f.blocking:
				xf=held_guard(lane,breath)
				if f.flash>0:
					var k: float=clampf(f.flash/FLASH,0,1)
					if f.get("counter",0.0)>0:
						# A perfect parry: the blade beats out against the cut and the hilt punches forward.
						xf.origin+=(-TRAVEL[lane]*.09+Vector3(0,.02,.10))*k
						xf.basis=xf.basis*Basis(Vector3(0,0,1),-SIDE[lane]*.30*k)*Basis(Vector3(1,0,0),(-.25 if lane==0 else (.25 if lane==2 else 0.0))*k)
					else:
						# A block: the guard is driven along the cut, gives, and springs back.
						xf.origin+=(TRAVEL[lane]*.10+Vector3(0,-.02,-.08))*k
						xf.basis=xf.basis*Basis(Vector3(0,0,1),SIDE[lane]*.22*k)*Basis(Vector3(1,0,0),(.20 if lane==0 else (-.20 if lane==2 else 0.0))*k)
					rate=40.0
				var raise: float=f.get("raise",0.0)
				if raise>0:
					# A freshly raised guard snaps past its mark and settles.
					var k: float=raise/.14
					xf.origin+=RAISE_OVER[lane]*k
					xf.basis=xf.basis*Basis(Vector3(0,0,1),-SIDE[lane]*.18*k)
					rate=34.0
			else: xf=blend(ready(breath),guard(lane),.25) # The point drifts toward the chosen lane.
	return {"xf":xf,"rate":rate}
# Body posture for the stance layer, in the same screen space; `s` mirrors the sideways channels.
static func body(f: Dictionary,progress: float,s: float,clock: float) -> Dictionary:
	var lane: int=f.attack_dir if f.phase in ["windup","recovery","open"] else f.guard
	var side: float=SIDE[lane]*s
	var heavy: bool=f.heavy
	var pose := {}
	var speed := 12.0
	match f.phase:
		"windup":
			var t: float=progress
			if t<CUT_AT:
				# Coil: hips lead, the chest follows, weight settles over the back foot.
				var c: float=smoothstep(0,.58,t)
				pose={"lean":(-.22 if heavy else -.14)*c,"twist":side*.55*c,"hips":side*.35*c,"roll":-side*.06*c,"crouch":.05*c,"shift_z":-.05*c,"look":-side*.15*c}
				speed=14.0
			else:
				# Drive: the hips snap through first, the shoulders and the blade after them.
				var u: float=(t-CUT_AT)/(1.0-CUT_AT)
				pose={"lean":(.55 if heavy else .40)*u,"twist":-side*.60*u,"hips":-side*.40*u,"roll":side*.05*u,"crouch":.06+.08*u,"shift_z":.10*u+(.05 if heavy else 0.0),"nod":.10*u}
				speed=34.0
		"recovery":
			var t: float=progress
			pose={"lean":lerpf(.32,.10,t),"twist":lerpf(-side*.45,side*.10,t),"hips":lerpf(-side*.3,0,t),"crouch":lerpf(.10,.04,t),"shift_z":lerpf(.10,.02,t)}
			if f.get("whiff",false): pose.lean+=.12*(1-t)
			if f.get("bounce",false):
				# Stopped by steel: the chest is checked and rocks back before the shoulders recover.
				pose.lean-=.22*(1-t)
				pose.shift_z-=.08*(1-t)
			speed=10.0
		"open":
			# Off balance where the parry left him: weight thrown onto the back foot, arms out.
			var held: float=clampf(f.open/maxf(f.get("open_total",1.0),.01),0,1)
			pose={"lean":-.18*held,"twist":side*.35*held,"hips":side*.15*held,"roll":side*.08*held,"crouch":.03,"shift_z":-.12*held,"nod":-.08*held}
			speed=16.0
		"hurt":
			var reel: float=1.6 if f.get("staggered",false) else 1.0
			var from: float=SIDE[int(f.get("hit_from",lane))]*s
			pose={"lean":-.30*reel,"roll":(.14*s if lane%2==0 else -from*.14)*reel,"twist":from*.12*reel,"crouch":.06*reel,"shift_z":-.10*reel,"shift_x":-from*.04*reel,"nod":-.18*reel,"look":from*.2}
			speed=24.0
		"exhausted":
			var heave: float=sin(clock*4.2)
			pose={"lean":.42+heave*.03,"crouch":.12,"shift_z":.03,"nod":.12,"roll":heave*.02}
			speed=5.0
		_:
			var sway: float=sin(clock*1.7)
			if f.blocking:
				# Each cover has its own stance: ducked under the roof, turned into a side cover,
				# folded over the hanging point.
				match lane:
					0: pose={"lean":-.03,"twist":side*.10,"crouch":.10,"nod":.12,"shift_z":.01}
					2: pose={"lean":.18,"crouch":.15,"nod":.06,"shift_z":.03}
					_: pose={"lean":.08,"twist":side*.30,"hips":side*.12,"roll":-side*.05,"crouch":.10,"shift_x":side*.03,"shift_z":.02}
				speed=16.0
				if f.flash>0:
					var k: float=clampf(f.flash/FLASH,0,1)
					if f.get("counter",0.0)>0:
						# Driving into the parry: the chest goes forward behind the beat.
						pose.lean=float(pose.get("lean",0.0))+.14*k
						pose.shift_z=float(pose.get("shift_z",0.0))+.06*k
						pose.nod=float(pose.get("nod",0.0))+.05*k
					else:
						# Absorbing the blow: checked back onto the heels, knees giving.
						pose.lean=float(pose.get("lean",0.0))-.12*k
						pose.crouch=float(pose.get("crouch",0.0))+.05*k
						pose.shift_z=float(pose.get("shift_z",0.0))-.05*k
						pose.roll=float(pose.get("roll",0.0))-side*.06*k
					speed=30.0
			else: pose={"lean":.10+.01*sway,"twist":side*.12,"crouch":.06+.008*sway,"shift_x":.012*sway*s,"shift_z":.02}
	return {"pose":pose,"speed":speed}
# The execution: a full-body turning cut into the weak spot, authored over one unit of time.
# 0-.42 the wind: a deep coil with the blade drawn far behind the shoulder, from wherever the
# blade was (the strike that found the mark). .42-.56 the cut. .56-.72 the blade held at full
# extension through the hit. .72-1 the follow-through and reset.
static func execution(lane: int,u: float,breath: float,start := Transform3D()) -> Dictionary:
	if start==Transform3D(): start=ready(breath)
	var deep: Transform3D=chamber(lane,true)
	deep.origin+=Vector3(0,.05,-.06)
	deep.basis=deep.basis*Basis(Vector3(1,0,0),-.25)
	var hit: Transform3D=strike(lane,true)
	hit.origin+=Vector3(0,-.02,.05)
	var carried: Transform3D=follow(lane,true)
	var xf: Transform3D
	var pose := {}
	var side: float=SIDE[lane]
	if u<.42:
		var c: float=smoothstep(0,1,u/.42)
		var lift: Vector3=(start.origin+deep.origin)*.5+Vector3(side*.04,.16,.02)
		xf=arc(start,lift,deep,c)
		pose={"lean":-.32*c,"twist":side*.85*c,"hips":side*.55*c,"crouch":.12*c,"shift_z":-.08*c,"look":-side*.25*c,"nod":-.05*c}
	elif u<.56:
		var c: float=pow((u-.42)/.14,1.5)
		xf=arc(deep,MID_HILT[lane]+Vector3(0,.04,.06),hit,c)
		pose={"lean":lerpf(-.32,.62,c),"twist":lerpf(side*.85,-side*.75,c),"hips":lerpf(side*.55,-side*.5,c),"crouch":lerpf(.12,.16,c),"shift_z":lerpf(-.08,.26,c),"nod":.12*c}
	elif u<.72:
		xf=hit
		xf.origin+=Vector3(sin(breath*40)*.006,0,0)
		pose={"lean":.62,"twist":-side*.75,"hips":-side*.5,"crouch":.16,"shift_z":.26,"nod":.12}
	else:
		var c: float=smoothstep(0,1,(u-.72)/.28)
		xf=blend(blend(hit,carried,minf(c*2,1)),ready(breath),c*c)
		pose={"lean":lerpf(.62,.10,c),"twist":lerpf(-side*.75,0,c),"hips":lerpf(-side*.5,0,c),"crouch":lerpf(.16,.06,c),"shift_z":lerpf(.26,.02,c)}
	return {"xf":xf,"pose":pose}
# The victim of an execution: braced for nothing, then thrown by the blow and down on a knee.
static func executed(lane: int,u: float,clock: float) -> Dictionary:
	var heave: float=sin(clock*4.2)
	var side: float=SIDE[lane]
	if u<.56:
		return {"xf":frame(Vector3(.06,1.05+heave*.02,.26),Vector3(.12,-1,.42),Vector3(1,0,0)),"pose":{"lean":.42+heave*.03,"crouch":.12,"nod":.12}}
	var c: float=smoothstep(0,1,(u-.56)/.30)
	var xf := frame(Vector3(.06+side*.12*c,1.05-.10*c,.26-.16*c),Vector3(.3+side*.4,-.9,-.2),Vector3(1,0,0))
	return {"xf":xf,"pose":{"lean":lerpf(.42,-.35,c),"roll":side*.28*c,"twist":-side*.30*c,"crouch":.12+.22*c,"shift_z":-.32*c,"nod":lerpf(.12,-.3,c),"look":side*.3*c}}

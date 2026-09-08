extends RefCounted
var world: HubWorld
var kit: HubKit
var timber: Material
var pale: Material
var dark: Material
var brick: Material
func build(hub: HubKit) -> void:
	kit = hub
	world = kit.world
	timber = world.rough_material(Color(.19,.115,.058))
	pale = world.rough_material(Color(.48,.43,.30))
	dark = world.rough_material(Color(.12,.16,.17))
	brick = world.rough_material(Color(.36,.20,.12))
	forge_yard()
	archive()
func block(p: Vector3,s: Vector3,m: Material,solid := false) -> Node3D:
	return world.box(p,s,m,solid)
func beam(a: Vector3,b: Vector3,width: float,m: Material) -> void:
	var node = block((a+b)*.5,Vector3(width,a.distance_to(b),width),m)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
func forge_yard() -> void:
	# Back wall and chimney frame an open working court, without a roof over the anvil.
	for row in 5:
		for col in 10:
			block(Vector3(-10.8+col*.56+(row%2)*.10,.23+row*.42,-1.65),Vector3(.53,.39,.28),world.stone[(row+col)%6])
	world.block(Vector3(-8.2,1.05,-1.65),Vector3(6,2.1,.3))
	for x in [-10.8,-5.5]:
		block(Vector3(x,1.55,-1.4),Vector3(.23,3.1,.23),timber,true)
		block(Vector3(x,1.55,.9),Vector3(.23,3.1,.23),timber,true)
		beam(Vector3(x,2.3,.9),Vector3(x,3,-.0),.14,timber)
	block(Vector3(-8.15,3.15,-.25),Vector3(5.9,.16,3.2),dark).rotation.x = -.10
	var slates: Array[Material] = []
	for tint in [Color(.17,.21,.22),Color(.20,.24,.25),Color(.14,.18,.20)]: slates.append(world.rough_material(tint))
	for row in 7:
		for col in 10:
			var z := -1.65+row*.45
			block(Vector3(-10.75+col*.57+(row%2)*.08,3.26+sin(.10)*(z+.25),z),Vector3(.55,.045,.50),slates[(row*3+col)%3]).rotation.x = -.10
	for x in [-10.7,-9.8,-8.9,-8,-7.1,-6.2,-5.6]:
		block(Vector3(x,3.05,-.2),Vector3(.10,.15,3.25),timber).rotation.x = -.10
	# Fire chamber, open mouth, soot-dark lintel and tapering chimney.
	for x in [-9.85,-8.55]:
		block(Vector3(x,.65,-.65),Vector3(.34,1.3,1.2),brick,true)
	block(Vector3(-9.2,.2,-.65),Vector3(1.6,.4,1.3),world.stone[2],true)
	block(Vector3(-9.2,1.25,-.65),Vector3(1.7,.24,1.4),dark)
	block(Vector3(-9.2,.72,-1.2),Vector3(1.4,1,.18),dark)
	block(Vector3(-9.2,2,-.82),Vector3(1.2,1.3,.95),brick)
	block(Vector3(-9.2,3.2,-.82),Vector3(.78,1.3,.72),world.stone[2])
	block(Vector3(-9.2,3.91,-.82),Vector3(.94,.16,.88),dark)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(.85,.24,.025)
	glow.emission_enabled = true
	glow.emission = Color(1,.25,.02)
	glow.emission_energy_multiplier = 2
	for i in 12:
		block(Vector3(-9.65+(i%4)*.28,.45+(i/4)*.045,-.92+(i/4)*.22),Vector3(.20,.10,.17),glow)
	# Tool bench and stock rack leave the smith's approach unobstructed.
	block(Vector3(-5.95,.92,-.4),Vector3(.8,.12,2.1),timber,true)
	for z in [-1.2,.4]: block(Vector3(-5.95,.46,z),Vector3(.55,.85,.15),timber,true)
	for i in 5:
		block(Vector3(-6.15+i*.11,1.02,-.25),Vector3(.075,.075,.8),dark)
	for i in 4:
		block(Vector3(-10.2+i*.34,.26,1.4),Vector3(.23,.30,1.25),timber)
	for i in 5:
		beam(Vector3(-8.2+i*.35,1.8,-1.43),Vector3(-8.2+i*.35,1.25,-1.43),.04,timber)
		block(Vector3(-8.2+i*.35,1.78,-1.43),Vector3(.21,.12,.12),dark)
func archive() -> void:
	# A raised stone-backed reading garden with an open slatted pergola.
	block(Vector3(10,-.01,-4.1),Vector3(5.9,.12,4.5),pale)
	for row in 6:
		for col in 8:
			block(Vector3(7.45+col*.73,.066,-5.95+row*.72),Vector3(.70,.045,.69),world.stone[(row+col)%6])
	block(Vector3(10,.42,-6.1),Vector3(5.9,.84,.34),world.stone[3],true)
	for x in [7.35,12.65]:
		for z in [-5.85,-2.5]:
			block(Vector3(x,.18,z),Vector3(.46,.36,.46),pale,true)
			block(Vector3(x,1.7,z),Vector3(.20,3.05,.20),timber,true)
		block(Vector3(x,3.2,-4.1),Vector3(.24,.25,3.9),timber)
	for z in [-5.9,-2.35]: block(Vector3(10,3.25,z),Vector3(5.8,.25,.22),timber)
	for i in 12:
		block(Vector3(7.3+i*.49,3.38,-4.1),Vector3(.20,.09,4.2),timber)
	# Rear archive cabinets, shelves and differently sized folios.
	for x in [8.25,11.4]:
		block(Vector3(x,1,-5.55),Vector3(1.65,2,.16),dark,true)
		for dx in [-.8,.8]:block(Vector3(x+dx,1,-5.3),Vector3(.10,2,.65),timber,true)
		for y in [.15,.7,1.3,1.95]:block(Vector3(x,y,-5.3),Vector3(1.7,.09,.65),timber)
		for row in 3:
			for i in 7:
				block(Vector3(x-.65+i*.20,.38+row*.6,-5.23),Vector3(.13,.30+(i%3)*.055,.37),[pale,dark,brick][i%3]).rotation.z = .04*(i%3-1)
	# A solid writing desk facing the visitor, with layered papers and specimen jars.
	block(Vector3(10,.92,-1.8),Vector3(2.5,.15,1.05),timber,true)
	for x in [8.95,11.05]:block(Vector3(x,.43,-1.8),Vector3(.16,.85,.75),timber,true)
	# One sheet sits clear of the jars; overlapping thick sheets intersected at grazing angles.
	var parchment := StandardMaterial3D.new()
	parchment.albedo_color = Color(.66,.59,.39)
	parchment.roughness = .96
	block(Vector3(10.03,1.000,-1.67),Vector3(.66,.006,.44),parchment)
	# Fine route markings make this read as a map from close up.
	for i in 6:
		var mark = block(Vector3(9.81+i*.074,1.004,-1.68+sin(i*.9)*.09),Vector3(.075,.001,.006),dark)
		mark.rotation.y = -.6*cos(i*.9)
	for p in [Vector3(9.81,1.004,-1.68),Vector3(10.18,1.004,-1.76)]:
		block(p,Vector3(.024,.001,.024),brick)
	block(Vector3(10.5,1.08,-1.95),Vector3(.14,.16,.14),dark)
	beam(Vector3(10.5,1.12,-1.95),Vector3(10.58,1.43,-1.93),.018,pale)
	for i in 3:
		var jar := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = .09
		cylinder.bottom_radius = .13
		cylinder.height = .3+i*.05
		jar.mesh = cylinder
		jar.material_override = world.rough_material(Color(.18+i*.04,.32,.30))
		jar.position = Vector3(8.99+i*.27,.995+cylinder.height*.5,-1.95)
		kit.add_child(jar)
		block(jar.position+Vector3(0,cylinder.height*.5,0),Vector3(.2,.035,.2),timber)
	block(Vector3(12,.48,-2.2),Vector3(.7,.96,.7),world.stone[4],true)
	kit.asset("armillary",Vector3(12,.97,-2.2))

extends Node3D
## A small sewn superhero pigeon. Local +Z is its face; Y=0 is the seat.
## Static decoration: the well owns collision and lifetime.

func _ready() -> void:
	var charcoal = fabric(Color("353b3b"))
	var wing = fabric(Color("424848"))
	var neck = fabric(Color("30463f"))
	var red = fabric(Color("a72b20"))
	var cape_red = fabric(Color("831d17"))
	var gold = fabric(Color("d6a335"))
	var beak = fabric(Color("44433c"))
	var cere = fabric(Color("b8b09a"))
	var orange = fabric(Color("ec8b22"))
	var black = fabric(Color("111515"))
	var stitch = fabric(Color("746b58"))

	ellipsoid("StuffedBody",Vector3(0,.29,0),Vector3(.245,.32,.18),red)
	ellipsoid("Neck",Vector3(0,.59,.005),Vector3(.19,.20,.17),neck)
	ellipsoid("PigeonHead",Vector3(0,.79,.035),Vector3(.24,.245,.215),charcoal)
	# Separate soft wings and forward-facing feet give a seated toy silhouette.
	for side in [-1.0,1.0]:
		var arm = ellipsoid("Wing",Vector3(side*.25,.29,.015),Vector3(.10,.25,.115),wing)
		arm.rotation.z = side*.12
		ellipsoid("Foot",Vector3(side*.13,.015,.19),Vector3(.10,.065,.17),charcoal)
		for toe in [-1.0,0.0,1.0]:
			line("ToeSeam",Vector3(side*.13+toe*.035,.05,.245),Vector3(side*.13+toe*.035,.04,.31),.0035,stitch)
		# Eyes sit on the forward sides of the head, as on the reference pigeon.
		var eye = Node3D.new()
		eye.name = "Eye"
		eye.position = Vector3(side*.175,.815,.175)
		eye.rotation.y = side*.60
		add_child(eye)
		ellipsoid("EyeSocket",Vector3.ZERO,Vector3(.075,.082,.030),black,eye)
		ellipsoid("OrangeIris",Vector3(0,0,.025),Vector3(.057,.065,.012),orange,eye)
		ellipsoid("Pupil",Vector3(0,0,.036),Vector3(.029,.039,.010),black,eye)
		ellipsoid("Catchlight",Vector3(-.012,.024,.045),Vector3(.009,.012,.005),cere,eye)
		for seam in 5:
			var y = .16+seam*.046
			line("WingStitch",Vector3(side*.31,y,.075),Vector3(side*.315,y+.019,.074),.0025,stitch)

	var bill = ellipsoid("SoftBeak",Vector3(0,.717,.253),Vector3(.078,.053,.125),beak)
	bill.rotation.x = .22
	ellipsoid("PaleCere",Vector3(0,.757,.227),Vector3(.065,.035,.047),cere)
	line("BeakSeam",Vector3(-.060,.709,.285),Vector3(.060,.709,.285),.003,black)

	# Thick cloth collar and a scalloped cape draped behind the seated body.
	for side in [-1.0,1.0]:
		line("CapeCollar",Vector3(0,.51,.152),Vector3(side*.23,.535,-.025),.032,red)
		line("GoldNeckTrim",Vector3(0,.475,.173),Vector3(side*.135,.51,.127),.013,gold)
	build_cape(cape_red)
	var belt = TorusMesh.new()
	belt.inner_radius = .207
	belt.outer_radius = .242
	belt.rings = 32
	belt.ring_segments = 8
	var belt_node = mesh_node("GoldBelt",belt,Vector3(0,.145,0),gold)
	belt_node.scale = Vector3(1,1.7,.77)
	ellipsoid("BeltBuckle",Vector3(0,.145,.186),Vector3(.050,.043,.015),gold)
	ellipsoid("BuckleInset",Vector3(0,.145,.201),Vector3(.031,.025,.005),cape_red)

	# Raised fabric shield and letters, with no billboard or floating text.
	var badge = Node3D.new()
	badge.name = "APBadge"
	badge.position = Vector3(0,.34,.177)
	badge.rotation.x = -.10
	add_child(badge)
	shield("ShieldBorder",.18,.17,0,charcoal,badge)
	shield("ShieldCloth",.153,.143,.003,gold,badge)
	shield("ShieldInset",.132,.122,.005,red,badge)
	var letters = TextMesh.new()
	letters.text = "AP"
	letters.font_size = 64
	letters.pixel_size = .0020
	letters.depth = .004
	var label = mesh_node("EmbroideredAP",letters,Vector3(0,.010,.012),gold,badge)
	label.scale.x = 1.06

func fabric(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	# Fine deterministic weave, shared across the surface without external files.
	var weave = FastNoiseLite.new()
	weave.seed = 714
	weave.frequency = .8
	var texture = NoiseTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.noise = weave
	texture.as_normal_map = true
	texture.bump_strength = .35
	texture.seamless = true
	material.normal_enabled = true
	material.normal_texture = texture
	material.normal_scale = .35
	material.uv1_scale = Vector3(5,5,5)
	return material

func mesh_node(id: String, mesh: Mesh, pos: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = id
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	parent.add_child(node)
	return node

func ellipsoid(id: String, pos: Vector3, radius: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var sphere = SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 24
	sphere.rings = 12
	var node = mesh_node(id,sphere,pos,material,parent)
	node.scale = radius
	return node

func line(id: String, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 8
	var node = mesh_node(id,cylinder,(a+b)*.5,material)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func shield(id: String, width: float, height: float, z: float, material: Material, parent: Node3D) -> void:
	var points = PackedVector3Array([
		Vector3(-width*.72,height*.7,z),Vector3(width*.72,height*.7,z),
		Vector3(width,height*.22,z),Vector3(0,-height,z),Vector3(-width,height*.22,z)])
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,4):
		for index in [0,i,i+1]:
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(points[index])
	mesh_node(id,surface.commit(),Vector3.ZERO,material,parent)

func build_cape(material: StandardMaterial3D) -> void:
	var cloth = material.duplicate() as StandardMaterial3D
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 8:
		for col in 12:
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var u = (col+offset.x)/12.0
				var v = (row+offset.y)/8.0
				var x = (u*2-1)*lerpf(.21,.31,v)
				var y = lerpf(.53,.018,v)+sin(u*PI*5)*.015*v
				var z = -.11-.14*sin(v*PI*.6)+cos(u*PI*6)*.018*v
				surface.set_uv(Vector2(u,v))
				surface.add_vertex(Vector3(x,y,z))
	surface.generate_normals()
	mesh_node("DrapedCape",surface.commit(),Vector3.ZERO,cloth)

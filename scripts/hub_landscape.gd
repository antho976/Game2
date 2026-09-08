extends Node3D
## Seeded planting beds and a continuous landscape beyond the playable walls.
var kit: HubKit
var rng := RandomNumberGenerator.new()
var grass_material: ShaderMaterial
var tree_points: Array[Vector3] = []
var hamlet_centers: Array[Vector3] = [Vector3(35,0,7),Vector3(32,0,-4),Vector3(-33,0,-9),Vector3(12,0,-27),Vector3(-13,0,-30)]
const POND := Vector3(-12,0,8.7)
const GRASS_CHUNK := 8.0
static var bark_shader: Shader

func build(hub: HubKit) -> void:
	kit = hub
	rng.seed = 74129
	lighting()
	build_outskirts()
	build_hamlet()
	var planting := [Vector3(-16,0,-12),Vector3(-10,0,-13.8),Vector3(-17,0,-3),
		Vector3(-16.8,0,2.7),Vector3(-16.8,0,5.7),Vector3(-10.2,0,14.6),
		Vector3(-4.3,0,13.8),Vector3(17.8,0,14.0),Vector3(20.2,0,12.2),
		Vector3(28.5,0,6),Vector3(28.7,0,-.7),Vector3(20.5,0,-13.6),
		Vector3(9.7,0,-14.4),Vector3(3.1,0,12.7),Vector3(-17.4,0,11.5)]
	for i in planting.size():
		plant_tree(planting[i],rng.randf_range(.7,1.14),i)
	# Uneven stands outside the walls, with openings, saplings and distant ridges.
	for i in 90:
		var angle := rng.randf()*TAU
		var radius := rng.randf_range(22,55)
		var p := Vector3(cos(angle)*radius,0,sin(angle)*radius*.84)
		if (p.x>-21 and p.x<28 and absf(p.z)<18) or outside_water(p) or (absf(p.x) < 4 and p.z < 0): continue
		if plantable(p): plant_tree(p,rng.randf_range(.65,1.65),i)
	for i in 16:
		conifer(Vector3(-34+i*4.5+rng.randf_range(-1,1),0,-23-rng.randf_range(0,13)),rng.randf_range(.8,1.5))
	pond()
	plant_grass()
	leaves()
	# Low stones and flower clumps stitch the large trees into the ground.
	for i in 80:
		var p := Vector3(rng.randf_range(-18,18),0,rng.randf_range(-15,14))
		if not plantable(p): continue
		if i % 3 == 0:
			shape(self,p+Vector3(0,.09,0),Vector3(.2,.18,.28)*rng.randf_range(.7,1.8),Color(.40,.43,.35))
		else:
			flowers(p,i)
	for p in [Vector3(-17,0,4),Vector3(-7,0,11),Vector3(15,0,9),Vector3(16,0,-5),Vector3(8,0,-14)]:
		flowers(p,int(absf(p.x)))

func plant_tree(p: Vector3, size: float, index: int) -> void:
	p.y = terrain_height(p)
	var tree := kit.asset("birch_tree" if index % 4 == 0 else "oak_tree",p)
	tree.rotation.y = rng.randf()*TAU
	tree.scale *= size
	# Trees sway each frame, so they keep their own imported meshes and level-of-detail data.
	tree.set_meta(StaticBatcher.NO_BATCH,true)
	if index % 4 == 0: birch_root_material(tree)
	kit.trees.append(tree)
	tree_points.append(p)
	if p.x > -19 and p.x < 26 and p.z > -16 and p.z < 15:
		kit.world.block(p+Vector3(0,1,0),Vector3(.65,2,.65)*size)

func plantable(p: Vector3) -> bool:
	if outside_water(p): return false
	if absf(p.x+9.1)<1.8 and absf(p.z-8.2)<1.2: return false
	for center in hamlet_centers:
		if absf(p.x-center.x)<3.4 and absf(p.z-center.z)<3.6: return false
	if absf(p.x) < 2.2 and p.z < -16: return false
	if kit.on_path(Vector2(p.x,p.z)): return false
	if Vector2(p.x-POND.x,(p.z-POND.z)*1.25).length() < 3.3: return false
	for c in [Vector3(-6.5,0,-10),Vector3(4.6,0,-12.2),Vector3(-13.1,0,-6.8),Vector3(13.5,0,-11.6),Vector3(-8,0,0),Vector3(10,0,-3.5)]:
		if absf(p.x-c.x) < 2.9 and absf(p.z-c.z) < 2.8: return false
	return true

func plant_grass() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 player_position = vec3(0.0);
varying float tip;
void vertex() {
	tip = clamp(VERTEX.y / 0.65, 0.0, 1.0);
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wind = sin(w.x * 0.43 + w.z * 0.37 + TIME * 1.7) * 0.14
		+ sin(w.z * 1.1 + TIME * 3.2) * 0.045;
	vec2 away = w.xz - player_position.xz;
	float bend = (1.0 - smoothstep(0.0, 1.2, length(away))) * 0.33;
	VERTEX.xz += (vec2(wind, wind * 0.45) + normalize(away + vec2(0.001)) * bend) * tip * tip;
}
void fragment() {
	ALBEDO = COLOR.rgb * mix(vec3(0.45,0.60,0.37), vec3(0.90,1.0,0.70), tip);
	ROUGHNESS = 0.87;
	BACKLIGHT = vec3(0.18,0.24,0.08) * tip;
}
"""
	grass_material = ShaderMaterial.new()
	grass_material.shader = shader
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0,1.05,2.1]:
		var right := Vector3(cos(angle),0,sin(angle))
		for v in [-right*.035, right*.035, right*.024+Vector3(.025,.3,.015), -right*.035, right*.024+Vector3(.025,.3,.015), -right*.024+Vector3(.025,.3,.015), -right*.024+Vector3(.025,.3,.015), right*.024+Vector3(.025,.3,.015), Vector3(.1,.65,.05)]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(v)
	var mesh := surface.commit()
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 90000:
		var p := Vector3(rng.randf_range(-43,43),.015,rng.randf_range(-35,35))
		if i > 34000: p = Vector3(rng.randf_range(-18.5,25.5),.015,rng.randf_range(-15,14.5))
		if not plantable(p): continue
		# Keep a trimmed verge beside paving instead of rectangular walls of tall grass.
		var verge := false
		for offset in [Vector2(.4,0),Vector2(-.4,0),Vector2(0,.4),Vector2(0,-.4)]:
			if kit.on_path(Vector2(p.x,p.z)+offset): verge = true
		if verge and rng.randf() < .8: continue
		p.y += terrain_height(p)
		# Irregular density gives patches and breathing room instead of a lawn grid.
		var density := sin(p.x*.63+cos(p.z*.31))*sin(p.z*.57)
		if density < -.4 and rng.randf() > .18: continue
		var scale_y := rng.randf_range(.14,.48) if verge else rng.randf_range(.22,.68)
		transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(1,scale_y,1)),p))
		colors.append(Color(.26+rng.randf()*.13,.39+rng.randf()*.14,.13+rng.randf()*.06))
	# One meadow-wide batch could never be culled, so every camera, sun-split and lamp shadow
	# pass drew all of it. Ground-grid chunks let each pass draw only the blades it can see.
	var chunks := {}
	for i in transforms.size():
		var cell := Vector2i(floori(transforms[i].origin.x/GRASS_CHUNK),floori(transforms[i].origin.z/GRASS_CHUNK))
		if not chunks.has(cell): chunks[cell] = []
		chunks[cell].append(i)
	for cell in chunks:
		var members: Array = chunks[cell]
		var batch := MultiMeshInstance3D.new()
		batch.name = "WindMeadow_%d_%d" % [cell.x,cell.y]
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.use_colors = true
		batch.multimesh.mesh = mesh
		batch.multimesh.instance_count = members.size()
		batch.material_override = grass_material
		var bounds := AABB(transforms[members[0]].origin,Vector3.ZERO)
		for i in members.size():
			batch.multimesh.set_instance_transform(i,transforms[members[i]])
			batch.multimesh.set_instance_color(i,colors[members[i]])
			bounds = bounds.expand(transforms[members[i]].origin)
		# Blades bend in the shader, so the bounds include the tallest wind-blown tip reach.
		batch.multimesh.custom_aabb = bounds.grow(1.2)
		add_child(batch)

func pond() -> void:
	var rim := PackedVector3Array()
	for i in 56:
		var angle := i*TAU/56
		var radius := 1.0+.055*sin(angle*3+.4)+.035*sin(angle*7)
		rim.append(Vector3(cos(angle)*3.08*radius,0,sin(angle)*2.15*radius))
	var bank := polygon_surface(rim,1.10,.035,Color(.37,.36,.23))
	bank.name = "PondShore"
	bank.position += POND
	var water := polygon_surface(rim,.94,.085,Color(.17,.34,.30))
	water.name = "GardenPond"
	water.position += POND
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
void fragment() {
	float edge = smoothstep(0.26,0.5,length(UV-vec2(0.5)));
	float waves = sin(UV.x*36.0+UV.y*19.0+TIME*0.65)*sin(UV.y*28.0-TIME*0.45);
	ALBEDO = mix(vec3(0.10,0.24,0.24),vec3(0.22,0.32,0.18),edge*0.72) + waves*0.002;
	ROUGHNESS = 0.44;
	METALLIC = 0.0;
	SPECULAR = 0.18;
	NORMAL_MAP = vec3(0.5+waves*0.06,0.5+sin(UV.x*27.0-TIME*.7)*.04,1.0);
	NORMAL_MAP_DEPTH = 0.35;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	water.material_override = material
	# Rounded, irregular collision follows the shore rather than a hidden box.
	var body := StaticBody3D.new()
	body.name = "PondBasinCollision"
	body.position = POND
	var collider := CollisionShape3D.new()
	var shape_resource := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for p in rim:
		points.append(p*.91+Vector3(0,-.1,0))
		points.append(p*.91+Vector3(0,.5,0))
	shape_resource.points = points
	collider.shape = shape_resource
	body.add_child(collider)
	add_child(body)
	for i in 34:
		var angle := i*TAU/34
		# Leave shallow planted sections instead of a perfect ring of identical rocks.
		if i in [4,5,6,15,16,26]: continue
		var radius := 1.0+.055*sin(angle*3+.4)+.035*sin(angle*7)
		var pos := POND+Vector3(cos(angle)*3.12*radius,.12,sin(angle)*2.20*radius)
		var stone := shape(self,pos,Vector3(rng.randf_range(.22,.50),rng.randf_range(.12,.29),rng.randf_range(.20,.38)),Color(.37,.41,.32))
		stone.rotation.y = rng.randf()*TAU
	for i in 7:
		var pos := POND+Vector3(rng.randf_range(-1.65,1.5),.103,rng.randf_range(-1.1,1.1))
		var pad_rim := PackedVector3Array()
		for j in 15:
			var angle := .3+j*(TAU-.6)/14
			pad_rim.append(Vector3(cos(angle)*.22,0,sin(angle)*.18))
		pad_rim.append(Vector3.ZERO)
		var pad := polygon_surface(pad_rim,1,0,Color(.30,.43,.18))
		pad.position = pos
		pad.rotation.y = rng.randf()*TAU
		if i%3 == 0:
			for j in 6:
				var angle := j*TAU/6
				shape(self,pos+Vector3(cos(angle)*.055,.035,sin(angle)*.055),Vector3(.06,.035,.025),Color(.86,.68,.57))
	for center in [POND+Vector3(-2.5,0,-.9),POND+Vector3(1.8,0,1.9),POND+Vector3(-1.3,0,2.1)]:
		for j in 9:
			var pos: Vector3 = center+Vector3(rng.randf_range(-.38,.38),0,rng.randf_range(-.25,.25))
			var height := rng.randf_range(.42,.86)
			shape(self,pos+Vector3(0,height*.5,0),Vector3(.015,height*.5,.015),Color(.28,.38,.16))
			if j%2 == 0: shape(self,pos+Vector3(0,height,0),Vector3(.036,.10,.036),Color(.32,.22,.12))
			var blade := shape(self,pos+Vector3(.08,height*.32,0),Vector3(.03,height*.34,.012),Color(.34,.44,.17))
			blade.rotation.z = -.28
	# A small stone spring feeds the western bank.
	var spring := POND+Vector3(-2.65,0,-.3)
	for i in 7:
		shape(self,spring+Vector3(rng.randf_range(-.4,.2),.15+i*.075,rng.randf_range(-.35,.35)),Vector3(.48,.23,.38),Color(.34,.38,.31))
	var fall := MeshInstance3D.new()
	var stream := BoxMesh.new()
	stream.size = Vector3(.20,.53,.06)
	fall.mesh = stream
	fall.position = spring+Vector3(.42,.34,0)
	fall.rotation.z = -.35
	var stream_material := StandardMaterial3D.new()
	stream_material.albedo_color = Color(.43,.63,.57)
	stream_material.roughness = .4
	fall.material_override = stream_material
	add_child(fall)
	for i in 3:
		var ripple := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = .18+i*.13
		torus.outer_radius = .195+i*.13
		torus.rings = 24
		torus.ring_segments = 4
		ripple.mesh = torus
		ripple.position = spring+Vector3(.55,.107,0)
		ripple.scale = Vector3(1,.12,.65)
		ripple.material_override = stream_material
		# Tweened rings must stay individual nodes.
		ripple.set_meta(StaticBatcher.NO_BATCH,true)
		add_child(ripple)
		var tween := create_tween().set_loops()
		tween.tween_property(ripple,"scale",Vector3(1.35,.12,.9),1.5).from(Vector3(.55,.12,.35)).set_delay(i*.18)

func polygon_surface(rim: PackedVector3Array, size_factor: float, height: float, color: Color) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rim.size():
		var a: Vector3 = rim[i]*size_factor
		var b: Vector3 = rim[(i+1)%rim.size()]*size_factor
		for p in [Vector3.ZERO,a,b]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(.5+p.x/(6.6*size_factor),.5+p.z/(4.6*size_factor)))
			surface.add_vertex(p+Vector3(0,height,0))
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .95
	mesh.material_override = material
	add_child(mesh)
	return mesh

func flowers(p: Vector3, index: int) -> void:
	var colors := [Color(.73,.59,.28),Color(.62,.49,.70),Color(.86,.82,.59)]
	for i in 5:
		var offset := Vector3(rng.randf_range(-.35,.35),rng.randf_range(.18,.34),rng.randf_range(-.35,.35))
		shape(self,p+Vector3(offset.x,offset.y*.5,offset.z),Vector3(.012,offset.y*.5,.012),Color(.22,.35,.11))
		for petal in 5:
			var a := petal*TAU/5
			shape(self,p+offset+Vector3(cos(a)*.045,0,sin(a)*.045),Vector3(.045,.025,.035),colors[index%3])
		shape(self,p+offset+Vector3(0,.018,0),Vector3(.022,.02,.022),Color(.74,.49,.13))

func leaves() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "WindblownLeaves"
	particles.position = Vector3(0,5,0)
	particles.amount = 160
	particles.lifetime = 12
	particles.preprocess = 8
	particles.visibility_aabb = AABB(Vector3(-26,-9,-25),Vector3(60,20,55))
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(19,2,15)
	motion.direction = Vector3(1,-.25,.35)
	motion.spread = 28
	motion.initial_velocity_min = .5
	motion.initial_velocity_max = 1.5
	motion.gravity = Vector3(.025,-.12,.015)
	motion.angular_velocity_min = -160
	motion.angular_velocity_max = 160
	motion.turbulence_enabled = true
	motion.turbulence_noise_strength = .65
	motion.scale_min = .6
	motion.scale_max = 1.2
	particles.process_material = motion
	var leaf := SphereMesh.new()
	leaf.radius = .07
	leaf.height = .018
	leaf.radial_segments = 5
	leaf.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.58,.44,.16)
	material.roughness = .9
	leaf.material = material
	particles.draw_pass_1 = leaf
	add_child(particles)

func lighting() -> void:
	for child in kit.world.get_children():
		if child is DirectionalLight3D:
			child.rotation_degrees = Vector3(-38,-48,0)
			child.light_color = Color(1,.96,.87)
			child.light_energy = 1.15
			child.light_angular_distance = 1.4
			child.directional_shadow_max_distance = 100
			child.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		if child is WorldEnvironment:
			var env: Environment = child.environment
			env.ambient_light_color = Color(.57,.70,.83)
			env.ambient_light_energy = .72
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.ssao_enabled = true
			env.ssao_radius = 1.4
			env.ssao_intensity = .75
			env.ssil_enabled = false
			env.ssil_intensity = .65
			env.glow_enabled = false
			env.glow_intensity = 0.0
			env.fog_enabled = true
			env.fog_light_color = Color(.64,.73,.68)
			env.fog_density = .0007
			env.volumetric_fog_enabled = false
			env.volumetric_fog_density = .006
			env.volumetric_fog_albedo = Color(.79,.85,.74)
			env.volumetric_fog_length = 100
			env.volumetric_fog_sky_affect = .25

func _process(_delta: float) -> void:
	if grass_material and is_instance_valid(kit.world.game.player):
		grass_material.set_shader_parameter("player_position",kit.world.game.player.global_position)

# Every blob is the same unit sphere; sharing it and one material per color lets the renderer
# treat thousands of them as a few objects instead of thousands of unique meshes and materials.
static var blob_mesh: SphereMesh
static var blob_materials := {}

static func shape(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if blob_mesh == null:
		blob_mesh = SphereMesh.new()
		blob_mesh.radius = 1
		blob_mesh.height = 2
		blob_mesh.radial_segments = 8
		blob_mesh.rings = 3
	if not blob_materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = .87
		blob_materials[color] = material
	var node := MeshInstance3D.new()
	node.mesh = blob_mesh
	node.position = pos
	node.scale = size
	node.material_override = blob_materials[color]
	parent.add_child(node)
	return node

func conifer(p: Vector3, size: float) -> void:
	p.y = terrain_height(p)
	var root := Node3D.new()
	root.position = p
	root.scale = Vector3.ONE*size
	add_child(root)
	shape(root,Vector3(0,1.8,0),Vector3(.20,1.8,.20),Color(.25,.19,.12))
	for i in 4:
		var mesh := CylinderMesh.new()
		mesh.top_radius = .08
		mesh.bottom_radius = 1.9-i*.35
		mesh.height = 2.2
		mesh.radial_segments = 9
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position.y = 2.0+i*.8
		node.rotation.y = i*.6
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(.17+i*.018,.28+i*.015,.19+i*.012)
		material.roughness = .95
		node.material_override = material
		root.add_child(node)

func birch_root_material(tree: Node3D) -> void:
	for mesh in tree.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.mesh.surface_get_material(surface)
			if not original is StandardMaterial3D or original.resource_name.to_lower() != "bark": continue
			# One compiled shader serves every birch; only the per-tree parameters differ.
			if bark_shader == null:
				bark_shader = Shader.new()
				bark_shader.code = """
shader_type spatial;
uniform vec4 bark_color : source_color;
uniform sampler2D bark_texture : source_color;
uniform bool textured = false;
uniform float ground_height = 0.0;
varying float height;
void vertex() { height = (MODEL_MATRIX*vec4(VERTEX,1.0)).y-ground_height; }
void fragment() {
	vec3 base = bark_color.rgb;
	if (textured) base *= texture(bark_texture,UV).rgb;
	vec3 root = mix(vec3(.28,.29,.24),vec3(.66,.64,.53),smoothstep(-.02,.19,height));
	ALBEDO = height < .32 ? pow(root,vec3(2.2)) : base;
	ROUGHNESS = .95;
}
"""
			var material := ShaderMaterial.new()
			material.shader = bark_shader
			material.set_shader_parameter("bark_color",original.albedo_color)
			material.set_shader_parameter("ground_height",tree.position.y)
			if original.albedo_texture:
				material.set_shader_parameter("textured",true)
				material.set_shader_parameter("bark_texture",original.albedo_texture)
			mesh.set_surface_override_material(surface,material)

func stream_x(z: float) -> float:
	return -25.5+sin(z*.12)*2.4

func outside_water(p: Vector3) -> bool:
	return absf(p.x-stream_x(p.z)) < 2.3 and absf(p.z) < 47

func terrain_height(p: Vector3) -> float:
	var distance := maxf(maxf(p.x-27,-p.x-20),absf(p.z)-17)
	if distance <= 0: return 0
	var hills := 1.8+sin(p.x*.14+p.z*.05)*1.2+cos(p.z*.17-p.x*.08)*.8
	if p.z < -23: hills += (1.0-smoothstep(-48,-23,p.z))*4
	var rise := smoothstep(0,9,distance)*maxf(.4,hills)
	if absf(p.z) < 49:
		rise *= smoothstep(2.1,4.8,absf(p.x-stream_x(p.z)))
	if p.z < -16:
		rise *= smoothstep(1.8,4.3,absf(p.x))
	return rise

func build_outskirts() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-48,48):
		for z in range(-48,48):
			var origin := Vector3(x*1.5,0,z*1.5)
			if origin.x > -19 and origin.x < 26 and origin.z > -16 and origin.z < 15: continue
			for offset in [Vector3.ZERO,Vector3(1.5,0,0),Vector3(0,0,1.5),Vector3(1.5,0,0),Vector3(1.5,0,1.5),Vector3(0,0,1.5)]:
				var p: Vector3 = origin+offset
				p.y = terrain_height(p)+.008
				var tint := .025*sin(p.x*.47)*cos(p.z*.31)
				surface.set_color(Color(.27+tint,.34+tint,.21+tint).darkened(clampf(p.y*.022,0,.13)))
				surface.add_vertex(p)
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "RollingOutskirts"
	terrain.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = .98
	terrain.material_override = material
	add_child(terrain)
	# A winding stream and earthen banks make the left edge a place, not empty lawn.
	var water_surface := SurfaceTool.new()
	water_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(-47,47):
		var z := float(i)
		var a := Vector3(stream_x(z)-2,.035,z)
		var b := Vector3(stream_x(z)+2,.035,z)
		var c := Vector3(stream_x(z+1)-2,.035,z+1)
		var d := Vector3(stream_x(z+1)+2,.035,z+1)
		for p in [a,b,c,b,d,c]:
			water_surface.set_normal(Vector3.UP)
			water_surface.set_uv(Vector2(p.x*.2,p.z*.12))
			water_surface.add_vertex(p)
	var water := MeshInstance3D.new()
	water.name = "WoodlandStream"
	water.mesh = water_surface.commit()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
void fragment() {
	float flow = sin(UV.y*23.0-TIME*.9+sin(UV.x*12.0))*.009;
	ALBEDO = vec3(.018,.072,.070)+flow*.2;
	SPECULAR = .18;
	ROUGHNESS = .5;
}
"""
	var water_material := ShaderMaterial.new()
	water_material.shader = shader
	water.material_override = water_material
	add_child(water)
	for i in 95:
		var z := rng.randf_range(-37,37)
		var side := -1 if i%2 else 1
		var p := Vector3(stream_x(z)+side*rng.randf_range(2.3,3.5),0,z)
		p.y = terrain_height(p)
		shape(self,p,Vector3(rng.randf_range(.3,.8),rng.randf_range(.2,.65),rng.randf_range(.3,.7)),Color(.34,.40,.32))
	# Dressed near-field beds fill the visible strip just behind the village walls.
	for i in 150:
		var p := Vector3(rng.randf_range(-35,35),0,rng.randf_range(-29,29))
		if p.x > -20.8 and p.x < 27.8 and absf(p.z) < 17.4: continue
		if outside_water(p) or (absf(p.x) < 3 and p.z < -16): continue
		p.y = terrain_height(p)
		var shrub := Node3D.new()
		shrub.position = p
		add_child(shrub)
		for j in 3:
			shape(shrub,Vector3(j*.27-.27,.25+j*.07,0),Vector3(.45,.40,.4)*rng.randf_range(.7,1.4),Color(.24+j*.025,.35+j*.02,.18))
	# Low dry-stone ruins on the eastern rise; varied masonry keeps the skyline broken.
	var ruin := Vector3(32,0,-15)
	ruin.y = terrain_height(ruin)
	for ring in 5:
		for segment in 12:
			if (segment+ring)%7 == 0 or (ring > 2 and segment in [0,1,2,7]): continue
			var angle := (segment+(ring%2)*.5)*TAU/12
			var stone := kit.world.box(ruin+Vector3(cos(angle)*2.2,.25+ring*.49,sin(angle)*2.2),Vector3(1.03,.47,.48),kit.world.stone[ring%6])
			stone.rotation.y = -angle+PI/2
	for i in 18:
		var p := ruin+Vector3(rng.randf_range(-3.6,3.6),0,rng.randf_range(-3.2,3.2))
		p.y = terrain_height(p)+.18
		shape(self,p,Vector3(.52,.32,.40),Color(.39,.41,.33)).rotation.y = rng.randf()*TAU
	# The road continues beyond the gate toward a weathered marker, then disappears.
	for z in range(-42,-16):
		for side in [-1,0,1]:
			var p := Vector3(side*.72+sin(z*.16)*.12,.02,z)
			kit.world.box(p,Vector3(.65,.07,.85),kit.world.stone[(z+42)%6])
	for x in [-1.8,1.8]:
		for y in 5:
			kit.world.box(Vector3(x,.3+y*.52,-28),Vector3(.7,.5,.75),kit.world.stone[y])
	# A timber footbridge, fallen trunks and field fencing supply smaller silhouettes.
	for i in 12:
		var p := Vector3(stream_x(3)-2.4+i*.43,.20,3)
		kit.world.box(p,Vector3(.40,.14,1.6),kit.world.wood)
	for side in [-1,1]:
		kit.world.box(Vector3(stream_x(3),.73,3+side*.77),Vector3(5,.10,.10),kit.world.wood)
		for x in [-2.1,0,2.1]:
			kit.world.box(Vector3(stream_x(3)+x,.45,3+side*.77),Vector3(.12,.9,.12),kit.world.wood)
	for center in [Vector3(-21.5,0,-13),Vector3(30,0,-19)]:
		center.y = terrain_height(center)
		var log := shape(self,center+Vector3(0,.35,0),Vector3(1.9,.30,.34),Color(.25,.19,.12))
		log.rotation.y = rng.randf()*PI
	for i in 10:
		var p := Vector3(23+i*.95,0,17+sin(i*.4))
		p.y = terrain_height(p)
		kit.world.box(p+Vector3(0,.5,0),Vector3(.13,1,.13),kit.world.wood)
		if i < 9: kit.world.box(p+Vector3(.45,.66,.10),Vector3(1,.09,.10),kit.world.wood)

func build_hamlet() -> void:
	for i in hamlet_centers.size():
		var p := hamlet_centers[i]
		p.y = terrain_height(p)
		var house := kit.asset("cottage" if i%2 == 0 else "townhouse",p)
		house.rotation.y = [-.3,.2,.5,-.12,.18][i]
		kit.world.box(p+Vector3(0,-.25,0),Vector3(5.5,.55,4.8),kit.world.stone[2])
		for j in 8:
			var path := p+Vector3(sin(j*.3)*.4,0,2.4+j*.65)
			path.y = terrain_height(path)+.04
			kit.world.box(path,Vector3(1.35,.09,.59),kit.world.stone[(j+i)%6])
		for j in 6:
			var fence := p+Vector3(-3.5+j*1.25,0,7.8)
			fence.y = terrain_height(fence)
			kit.world.box(fence+Vector3(0,.55,0),Vector3(.12,1.1,.12),kit.world.wood)
			if j<5: kit.world.box(fence+Vector3(.6,.7,0),Vector3(1.3,.1,.1),kit.world.wood)

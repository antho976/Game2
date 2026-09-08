extends Node3D
var kit: HubKit
var rng := RandomNumberGenerator.new()

func build(hub: HubKit) -> void:
	kit = hub
	rng.seed = 561
	# Surface wear follows the building, not a repeated decal stamped on every wall.
	for child in kit.get_children():
		if child.name.begins_with("cottage") or child.name.begins_with("townhouse"):
			weather_house(child)
	var homes := [Vector3(-6.5,0,-10),Vector3(4.6,0,-12.2),Vector3(-13.1,0,-6.8),Vector3(13.5,0,-11.6)]
	for i in homes.size():
		var p: Vector3 = homes[i]
		# Stacked firewood belongs beside a wall; the door and lane remain clear.
		for j in 9:
			var log := kit.world.box(p+Vector3(1.65+(j%3)*.17,.13+(j/3)*.16,2.22),Vector3(.14,.14,.65),kit.world.wood)
			log.rotation.z = rng.randf_range(-.08,.08)
		var pot := CylinderMesh.new()
		pot.top_radius = .20
		pot.bottom_radius = .14
		pot.height = .34
		pot.radial_segments = 10
		var mesh := MeshInstance3D.new()
		mesh.mesh = pot
		mesh.position = p+Vector3(-1.75,.18,2.35)
		mesh.material_override = kit.world.rough_material([Color(.44,.25,.15),Color(.25,.34,.31),Color(.49,.37,.24),Color(.38,.24,.20)][i])
		add_child(mesh)
		kit.landscape.flowers(p+Vector3(-1.75,.3,2.35),i)
		# Different threshold details identify each household.
		if i == 0:
			for j in 4:
				kit.world.box(p+Vector3(.8,.3+j*.18,2.45),Vector3(.65,.08,.1),kit.world.wood).rotation.z = -.14
		elif i == 1:
			kit.landscape.flowers(p+Vector3(2.2,0,1.2),1)
		elif i == 2:
			for j in 2:
				kit.world.box(p+Vector3(-2.45,.24+j*.4,1.3),Vector3(.65,.4,.55),kit.world.wood).rotation.y = j*.18
		else:
			var mat := kit.world.rough_material(Color(.33,.4,.36))
			kit.world.box(p+Vector3(.3,2.1,2.5),Vector3(1.6,.08,.7),mat).rotation.x = -.12
	# Moss and leaf litter collect at seams and edges, with clear walking centers.
	var moss := kit.world.rough_material(Color(.23,.29,.16))
	var leaf := kit.world.rough_material(Color(.42,.30,.13))
	for i in 250:
		var p := Vector2(rng.randf_range(-17,17),rng.randf_range(-14,13))
		if not kit.on_path(p): continue
		var edge := not kit.on_path(p+Vector2(.65,0)) or not kit.on_path(p+Vector2(0,.65))
		if not edge and rng.randf()>.12: continue
		var node := kit.world.box(Vector3(p.x,.054,p.y),Vector3(rng.randf_range(.06,.18),.007,rng.randf_range(.035,.10)),moss if i%3 else leaf)
		node.rotation.y = rng.randf()*TAU
	# Vines soften the joined boundary without hiding the walkable entrances.
	for i in 30:
		var p := Vector3(-18.5 if i%2 else 18.5,0,-14+i)
		for j in 3:
			kit.landscape.shape(self,p+Vector3(0,.4+j*.3,sin(i+j)*.2),Vector3(.22,.25,.30),Color(.22,.31,.17))

func weather_house(house: Node3D) -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform sampler2D paint : source_color;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool textured = false;
uniform float base_height = 0.0;
uniform float plaster = 0.0;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec3 base=tint.rgb;
 if(textured)base*=texture(paint,UV).rgb;
 float h=world.y-base_height;
 float age=noise(world.xz*2.0+world.yy*.7);
 float damp=(1.0-smoothstep(.1,.8+age*.3,h))*.36;
 float patch=smoothstep(.62,.88,noise(world.xy*3.0+world.zy))*.19;
 base*=1.0-damp-patch;
 base=mix(base,base*vec3(.67,.81,.57),damp);
 float crack=1.0-smoothstep(.012,.036,abs(sin(world.x*6.0+world.z*5.0+noise(world.xy*3.0)*2.0)));
 base*=1.0-crack*plaster*.18*smoothstep(.48,.65,age);
 ALBEDO=base;ROUGHNESS=.94;
}
"""
	for mesh in house.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var original: Material = mesh.mesh.surface_get_material(i)
			if not original is StandardMaterial3D: continue
			var id := original.resource_name.to_lower()
			if not id in ["plaster","stone","oak","dark_oak","slate","red_slate"]: continue
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("tint",original.albedo_color)
			material.set_shader_parameter("base_height",house.position.y)
			material.set_shader_parameter("plaster",1.0 if id == "plaster" else 0.0)
			if original.albedo_texture:
				material.set_shader_parameter("paint",original.albedo_texture)
				material.set_shader_parameter("textured",true)
			mesh.set_surface_override_material(i,material)

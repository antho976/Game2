extends RefCounted
static var rock_material: StandardMaterial3D
static func ground() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 float patch=noise(p*.65)*.65+noise(p*2.2)*.35;
 float fibers=noise(p*vec2(65.,14.));
 float grain=noise(p*105.);
 vec3 turf=mix(vec3(.16,.22,.075),vec3(.32,.36,.15),patch);
 vec3 earth=vec3(.25,.20,.105);
 ALBEDO=mix(turf,earth,smoothstep(.62,.84,noise(p*1.5+12.))*.55);
 ALBEDO*=.83+fibers*.24+grain*.10;
 ROUGHNESS=.96;
 NORMAL_MAP=vec3(.5+(fibers-.5)*.13,.5+(grain-.5)*.10,1.);
 NORMAL_MAP_DEPTH=.3;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

static func rock(parent: Node3D,pos: Vector3,size: Vector3,seed_value: int) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 9
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var v := vertices[i]
		var n := sin(v.x*13+seed_value)*sin(v.y*17+seed_value*.7)*cos(v.z*11)
		vertices[i] = v*(1+n*.12)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var tool := SurfaceTool.new()
	tool.create_from(mesh,0)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.position = pos
	node.scale = size*2
	if rock_material==null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(.36,.38,.32)
		mat.roughness = .94
		var noise := FastNoiseLite.new()
		noise.seed = 71
		noise.frequency = .08
		var texture := NoiseTexture2D.new()
		texture.width = 128
		texture.height = 128
		texture.noise = noise
		texture.seamless = true
		mat.albedo_texture = texture
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE*2
		rock_material = mat
	node.material_override = rock_material
	parent.add_child(node)
	return node

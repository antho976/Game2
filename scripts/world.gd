class_name HubWorld
extends Node3D
var game: Node3D
var stone: Array[StandardMaterial3D] = []
var wood: StandardMaterial3D
var beveled_box: Mesh
var interactions: Array[Dictionary] = []
func _ready() -> void:
	var model: Node3D = load("res://assets/models/stone_block.glb").instantiate()
	beveled_box = model.find_children("*","MeshInstance3D",true,false)[0].mesh
	model.free()
	for i in 6: stone.append(rough_material(Color(.31+i*.02,.32+i*.019,.27+i*.016)))
	wood = rough_material(Color(.23,.13,.065))

func rough_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .92
	var noise = FastNoiseLite.new()
	noise.seed = 71
	noise.frequency = .065
	noise.fractal_octaves = 5
	var texture = NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.noise = noise
	texture.seamless = true
	var ramp = Gradient.new()
	ramp.set_color(0, Color(.72, .71, .68))
	ramp.set_color(1, Color(.96, .94, .89))
	texture.color_ramp = ramp
	material.albedo_texture = texture
	var normal = NoiseTexture2D.new()
	normal.width = 128
	normal.height = 128
	normal.noise = noise
	normal.seamless = true
	normal.as_normal_map = true
	normal.bump_strength = 1.8
	material.normal_enabled = true
	material.normal_texture = normal
	material.normal_scale = .8
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * .9
	return material

func box(pos: Vector3, size: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	mesh.mesh = beveled_box
	mesh.scale = size
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)
	if solid:
		block(pos, size)
	return mesh

const BLOCK_CHUNK := 16.0
static var block_shader: Shader
var block_materials := {}

## Merges every stone or wood block into one mesh per material and ground-grid chunk.
## The rough material projects its textures in each block's own object space, and the
## squashed blocks need inverse-transpose normals, so each vertex also carries the block's
## original position, normal and tangent frame. The batch shader is the material's own
## generated code reading those baked values, so blocks look exactly as they did alone.
func merge_blocks() -> void:
	var unit := unit_block()
	var groups := {}
	var consumed: Array[MeshInstance3D] = []
	for child in get_children():
		if not child is MeshInstance3D or child.mesh != beveled_box: continue
		if child.get_child_count() > 0 or not child.visible or child.has_meta(StaticBatcher.NO_BATCH): continue
		if child.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON or child.transparency > 0: continue
		var material: Material = child.material_override
		if not plain_triplanar(material): continue
		var placement: Transform3D = child.transform
		if placement.basis.determinant() <= 1e-9: continue
		var key := "%d:%d:%d" % [material.get_instance_id(),floori(placement.origin.x/BLOCK_CHUNK),floori(placement.origin.z/BLOCK_CHUNK)]
		if not groups.has(key):
			groups[key] = {"material":material,"cell":Vector2i(floori(placement.origin.x/BLOCK_CHUNK),floori(placement.origin.z/BLOCK_CHUNK)),
				"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"object_positions":PackedVector3Array(),
				"object_normals":PackedVector3Array(),"tangents":PackedVector3Array(),"binormals":PackedVector3Array()}
		var group: Dictionary = groups[key]
		var normal_transform := Transform3D(placement.basis.inverse().transposed(),Vector3.ZERO)
		group.vertices.append_array(placement*unit.positions)
		group.normals.append_array(normal_transform*unit.normals)
		group.object_positions.append_array(unit.positions)
		group.object_normals.append_array(unit.normals)
		group.tangents.append_array(normal_transform*unit.tangents)
		group.binormals.append_array(normal_transform*unit.binormals)
		consumed.append(child)
	var batches := {}
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var group: Dictionary = groups[key]
		if not batches.has(group.cell):
			var node := MeshInstance3D.new()
			node.name = "BlockBatch_%d_%d" % [group.cell.x,group.cell.y]
			node.mesh = ArrayMesh.new()
			node.set_meta(StaticBatcher.NO_BATCH,true)
			add_child(node)
			batches[group.cell] = node
		var mesh: ArrayMesh = batches[group.cell].mesh
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = group.vertices
		arrays[Mesh.ARRAY_NORMAL] = group.normals
		arrays[Mesh.ARRAY_CUSTOM0] = group.object_positions.to_byte_array().to_float32_array()
		arrays[Mesh.ARRAY_CUSTOM1] = group.object_normals.to_byte_array().to_float32_array()
		arrays[Mesh.ARRAY_CUSTOM2] = group.tangents.to_byte_array().to_float32_array()
		arrays[Mesh.ARRAY_CUSTOM3] = group.binormals.to_byte_array().to_float32_array()
		var format := (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) \
			| (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},format)
		mesh.surface_set_material(mesh.get_surface_count()-1,block_material(group.material))
	for child in consumed: child.free()

## Non-indexed unit block with the object-space tangent frame the triplanar material builds
## per vertex, so the batch can bake exactly what the material would have computed.
func unit_block() -> Dictionary:
	var arrays: Array = beveled_box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices == null: indices = range(vertices.size())
	var result := {"positions":PackedVector3Array(),"normals":PackedVector3Array(),"tangents":PackedVector3Array(),"binormals":PackedVector3Array()}
	for index in indices:
		var n: Vector3 = normals[index]
		var a := n.abs()
		result.positions.append(vertices[index])
		result.normals.append(n)
		result.tangents.append((Vector3(0,0,-1)*a.x+Vector3(1,0,0)*a.y+Vector3(1,0,0)*a.z).normalized())
		result.binormals.append((Vector3(0,1,0)*a.x+Vector3(0,0,-1)*a.y+Vector3(0,1,0)*a.z).normalized())
	return result

## True for a rough_material configuration: opaque, per-pixel, object-space triplanar albedo
## and normal map with default blending, culling and filtering. Anything else keeps its node.
func plain_triplanar(material: Material) -> bool:
	if not material is StandardMaterial3D: return false
	var m: StandardMaterial3D = material
	if not m.uv1_triplanar or m.uv1_world_triplanar or m.uv2_triplanar: return false
	if not m.normal_enabled or m.albedo_texture == null or m.normal_texture == null: return false
	if m.metallic_texture != null or m.roughness_texture != null: return false
	if m.roughness_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_RED: return false
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.blend_mode != BaseMaterial3D.BLEND_MODE_MIX: return false
	if m.depth_draw_mode != BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY or m.cull_mode != BaseMaterial3D.CULL_BACK: return false
	if m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL or m.diffuse_mode != BaseMaterial3D.DIFFUSE_BURLEY: return false
	if m.specular_mode != BaseMaterial3D.SPECULAR_SCHLICK_GGX or m.next_pass != null or m.render_priority != 0: return false
	if m.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS or not m.texture_repeat: return false
	if m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or m.fixed_size or m.use_point_size or m.grow: return false
	if m.emission_enabled or m.rim_enabled or m.clearcoat_enabled or m.anisotropy_enabled or m.ao_enabled: return false
	if m.heightmap_enabled or m.subsurf_scatter_enabled or m.backlight_enabled or m.refraction_enabled or m.detail_enabled: return false
	if m.proximity_fade_enabled or m.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED: return false
	if m.vertex_color_use_as_albedo or m.vertex_color_is_srgb or m.no_depth_test or m.disable_receive_shadows: return false
	if m.disable_ambient_light or m.disable_fog or m.shadow_to_opacity or m.albedo_texture_msdf: return false
	return true

func block_material(original: StandardMaterial3D) -> ShaderMaterial:
	if block_materials.has(original): return block_materials[original]
	if block_shader == null:
		block_shader = Shader.new()
		# Godot's generated StandardMaterial3D code for this configuration, with the block's
		# baked object-space position, normal and tangent frame replacing the per-node values.
		block_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0);
varying vec3 uv1_triplanar_pos;

uniform float uv1_blend_sharpness : hint_range(0.0, 150.0, 0.001);
varying vec3 uv1_power_normal;

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;

void vertex() {
	vec3 normal = CUSTOM1.xyz;
	TANGENT = CUSTOM2.xyz;
	BINORMAL = CUSTOM3.xyz;

	// UV1 Triplanar: Enabled
	uv1_power_normal = pow(abs(normal), vec3(uv1_blend_sharpness));
	uv1_triplanar_pos = CUSTOM0.xyz * uv1_scale + uv1_offset;
	uv1_power_normal /= dot(uv1_power_normal, vec3(1.0));
	uv1_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}

void fragment() {
	vec4 albedo_tex = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos);
	ALBEDO = albedo.rgb * albedo_tex.rgb;

	float metallic_tex = dot(triplanar_texture(texture_metallic, uv1_power_normal, uv1_triplanar_pos), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(triplanar_texture(texture_roughness, uv1_power_normal, uv1_triplanar_pos), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;

	// Normal Map: Enabled
	NORMAL_MAP = triplanar_texture(texture_normal, uv1_power_normal, uv1_triplanar_pos).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
"""
	var material := ShaderMaterial.new()
	material.shader = block_shader
	material.set_shader_parameter("albedo",original.albedo_color)
	material.set_shader_parameter("texture_albedo",original.albedo_texture)
	material.set_shader_parameter("roughness",original.roughness)
	material.set_shader_parameter("metallic_texture_channel",channel_mask(original.metallic_texture_channel))
	material.set_shader_parameter("specular",original.metallic_specular)
	material.set_shader_parameter("metallic",original.metallic)
	material.set_shader_parameter("texture_normal",original.normal_texture)
	material.set_shader_parameter("normal_scale",original.normal_scale)
	material.set_shader_parameter("uv1_blend_sharpness",original.uv1_triplanar_sharpness)
	material.set_shader_parameter("uv1_scale",original.uv1_scale)
	material.set_shader_parameter("uv1_offset",original.uv1_offset)
	block_materials[original] = material
	return material

static func channel_mask(channel: int) -> Vector4:
	match channel:
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN: return Vector4(0,1,0,0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE: return Vector4(0,0,1,0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA: return Vector4(0,0,0,1)
		BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE: return Vector4(.333333,.333333,.333333,0)
	return Vector4(1,0,0,0)

func block(pos: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

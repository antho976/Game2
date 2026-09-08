class_name StaticBatcher
extends RefCounted
## Merges rigid MeshInstance3D descendants of a node into a few multi-surface meshes, so the
## renderer culls, sorts and draws a handful of objects instead of thousands of tiny ones.
##
## Geometry is baked into the root's local space with the exact materials, normals (using the
## inverse transpose for non-uniform scale), tangents and shadow settings the individual nodes
## had, so the rendered picture is unchanged; only the object count drops.
##
## A node and its subtree are left alone when it carries the "no_batch" meta or moves on its
## own (physics bodies, skeletons, bone attachments, particles). Individual meshes are also
## skipped when their look depends on the original object transform or on per-object sorting:
## triplanar or billboard materials, screen-space fades, transparency, custom shaders, skinning,
## blend shapes, custom vertex data, or non-default geometry settings.

const NO_BATCH := "no_batch"

static func merge(root: Node3D, chunk_size: float = 0.0) -> int:
	var chunks := {}
	var consumed: Array[MeshInstance3D] = []
	var cache := {}
	for child in root.get_children():
		_collect(child,Transform3D.IDENTITY,chunk_size,chunks,consumed,cache)
	if consumed.is_empty(): return 0
	var cells := chunks.keys()
	cells.sort()
	for cell in cells:
		var mesh := ArrayMesh.new()
		var keys: Array = chunks[cell].keys()
		keys.sort()
		for key in keys:
			var group: Dictionary = chunks[cell][key]
			if group.has("tool"):
				var tool: SurfaceTool = group.tool
				tool.set_material(group.material)
				tool.commit(mesh)
			else:
				var arrays := []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = group.vertices
				arrays[Mesh.ARRAY_NORMAL] = group.normals
				if group.has("colors"): arrays[Mesh.ARRAY_COLOR] = group.colors
				if group.has("uvs"): arrays[Mesh.ARRAY_TEX_UV] = group.uvs
				if group.has("uv2s"): arrays[Mesh.ARRAY_TEX_UV2] = group.uv2s
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				mesh.surface_set_material(mesh.get_surface_count()-1,group.material)
		var node := MeshInstance3D.new()
		node.name = "StaticBatch_%d_%d" % [cell.x,cell.z]
		node.mesh = mesh
		node.set_meta(NO_BATCH,true)
		root.add_child(node)
	for node in consumed:
		if node.get_child_count() == 0:
			node.free()
		else:
			node.mesh = null
			node.material_override = null
	return consumed.size()

static func _collect(node: Node, parent: Transform3D, chunk: float, chunks: Dictionary, consumed: Array[MeshInstance3D], cache: Dictionary) -> void:
	if not node is Node3D or node.has_meta(NO_BATCH) or not node.visible: return
	if node is PhysicsBody3D or node is Skeleton3D or node is BoneAttachment3D or node is GPUParticles3D or node is CPUParticles3D: return
	var local: Transform3D = parent*node.transform
	if node is MeshInstance3D:
		var materials := _surface_materials(node,local)
		if not materials.is_empty():
			_append(node,local,materials,chunk,chunks,cache)
			consumed.append(node)
	for child in node.get_children():
		_collect(child,local,chunk,chunks,consumed,cache)

## Returns one material per surface when every surface of the node can be baked, else [].
static func _surface_materials(node: MeshInstance3D, local: Transform3D) -> Array[Material]:
	var result: Array[Material] = []
	var mesh: Mesh = node.mesh
	if mesh == null or node.skin != null: return result
	# Imported meshes carry level-of-detail index sets and compressed vertex data that a
	# baked copy would lose, so only meshes generated at runtime are merged.
	if not mesh.resource_path.is_empty(): return result
	if mesh is ArrayMesh and mesh.get_blend_shape_count() > 0: return result
	if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON: return result
	if node.gi_mode != GeometryInstance3D.GI_MODE_STATIC or node.layers != 1: return result
	if node.transparency > 0 or node.material_overlay != null: return result
	if node.visibility_range_begin > 0 or node.visibility_range_end > 0: return result
	if node.lod_bias != 1.0 or node.extra_cull_margin != 0 or node.custom_aabb != AABB(): return result
	if local.basis.determinant() <= 1e-9: return result
	var uniform := _is_conformal(local.basis)
	for surface in mesh.get_surface_count():
		# Primitive meshes are always triangle lists; only ArrayMesh exposes other primitives.
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: return []
		var material: Material = node.material_override
		if material == null: material = node.get_surface_override_material(surface)
		if material == null: material = mesh.surface_get_material(surface)
		if not _bakeable_material(material): return []
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_BONES] != null or arrays[Mesh.ARRAY_WEIGHTS] != null: return []
		for custom in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:
			if arrays[custom] != null: return []
		if arrays[Mesh.ARRAY_NORMAL] == null: return []
		# Squashed shapes get inverse-transpose normals, which is only exact without tangents.
		if not uniform and _uses_tangents(material): return []
		result.append(material)
	return result

static func _bakeable_material(material: Material) -> bool:
	if not material is BaseMaterial3D: return false
	var m: BaseMaterial3D = material
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.next_pass != null: return false
	if m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or m.fixed_size or m.use_point_size: return false
	if m.uv1_triplanar or m.uv2_triplanar or m.heightmap_enabled: return false
	if m.proximity_fade_enabled or m.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED: return false
	if m.grow or m.refraction_enabled: return false
	return true

static func _uses_tangents(material: Material) -> bool:
	var m: BaseMaterial3D = material
	return m.normal_enabled or m.anisotropy_enabled or m.detail_enabled or m.bent_normal_enabled

static func _is_conformal(basis: Basis) -> bool:
	var x := basis.x
	var y := basis.y
	var z := basis.z
	var size := x.length()
	if absf(y.length()-size) > 1e-5 or absf(z.length()-size) > 1e-5: return false
	var limit := 1e-5*size*size
	return absf(x.dot(y)) < limit and absf(x.dot(z)) < limit and absf(y.dot(z)) < limit

static func _append(node: MeshInstance3D, local: Transform3D, materials: Array[Material], chunk: float, chunks: Dictionary, cache: Dictionary) -> void:
	var cell := Vector3i.ZERO
	if chunk > 0: cell = Vector3i(floori(local.origin.x/chunk),0,floori(local.origin.z/chunk))
	if not chunks.has(cell): chunks[cell] = {}
	var groups: Dictionary = chunks[cell]
	var mesh: Mesh = node.mesh
	if _is_conformal(local.basis):
		for surface in mesh.get_surface_count():
			var key := "%d:%d" % [materials[surface].get_instance_id(),_format(mesh,surface)]
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"tool":tool,"material":materials[surface]}
			groups[key].tool.append_from(mesh,surface,local)
		return
	var normal_transform := Transform3D(local.basis.inverse().transposed(),Vector3.ZERO)
	for surface in mesh.get_surface_count():
		var source: Dictionary = _flat_surface(mesh,surface,cache)
		var key := "%d:flat:%d" % [materials[surface].get_instance_id(),_format(mesh,surface)]
		if not groups.has(key):
			var group := {"material":materials[surface],"vertices":PackedVector3Array(),"normals":PackedVector3Array()}
			if source.has("colors"): group.colors = PackedColorArray()
			if source.has("uvs"): group.uvs = PackedVector2Array()
			if source.has("uv2s"): group.uv2s = PackedVector2Array()
			groups[key] = group
		var group: Dictionary = groups[key]
		group.vertices.append_array(local*source.vertices)
		group.normals.append_array(normal_transform*source.normals)
		if source.has("colors"): group.colors.append_array(source.colors)
		if source.has("uvs"): group.uvs.append_array(source.uvs)
		if source.has("uv2s"): group.uv2s.append_array(source.uv2s)

static func _format(mesh: Mesh, surface: int) -> int:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var bits := 0
	for i in [Mesh.ARRAY_TANGENT,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
		if arrays[i] != null: bits |= 1 << i
	return bits

## Non-indexed copy of a surface (tangents dropped), computed once per mesh surface.
static func _flat_surface(mesh: Mesh, surface: int, cache: Dictionary) -> Dictionary:
	var key := "%d:%d" % [mesh.get_instance_id(),surface]
	if cache.has(key): return cache[key]
	var arrays: Array = mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors = arrays[Mesh.ARRAY_COLOR]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var uv2s = arrays[Mesh.ARRAY_TEX_UV2]
	var result := {}
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices == null:
		result = {"vertices":vertices,"normals":normals}
		if colors != null: result.colors = colors
		if uvs != null: result.uvs = uvs
		if uv2s != null: result.uv2s = uv2s
	else:
		var flat_vertices := PackedVector3Array()
		var flat_normals := PackedVector3Array()
		var flat_colors := PackedColorArray()
		var flat_uvs := PackedVector2Array()
		var flat_uv2s := PackedVector2Array()
		for index in indices:
			flat_vertices.append(vertices[index])
			flat_normals.append(normals[index])
			if colors != null: flat_colors.append(colors[index])
			if uvs != null: flat_uvs.append(uvs[index])
			if uv2s != null: flat_uv2s.append(uv2s[index])
		result = {"vertices":flat_vertices,"normals":flat_normals}
		if colors != null: result.colors = flat_colors
		if uvs != null: result.uvs = flat_uvs
		if uv2s != null: result.uv2s = flat_uv2s
	cache[key] = result
	return result

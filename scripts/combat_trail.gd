extends MeshInstance3D
# A fading ribbon behind the blade while a cut is in the air; shows where the edge travelled.
var sword: Node3D
var active := false
var samples: Array = [] # [tip, base, age]
var color := Color(1,.92,.72)
func _ready() -> void:
	mesh=ImmediateMesh.new()
	top_level=true
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo=true
	material.no_depth_test=false
	material_override=material
func _physics_process(delta: float) -> void:
	for sample in samples: sample[2]+=delta
	while not samples.is_empty() and samples[0][2]>.22: samples.pop_front()
	if active and is_instance_valid(sword) and sword.is_visible_in_tree():
		samples.append([sword.to_global(Vector3(0,1.25,0)),sword.to_global(Vector3(0,.30,0)),0.0])
		if samples.size()>14: samples.pop_front()
	global_transform=Transform3D.IDENTITY
	var ribbon: ImmediateMesh=mesh
	ribbon.clear_surfaces()
	if samples.size()<2: return
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for sample in samples:
		var alpha: float=clampf(1.0-sample[2]/.22,0,1)
		ribbon.surface_set_color(Color(color.r,color.g,color.b,alpha*.55))
		ribbon.surface_add_vertex(sample[0])
		ribbon.surface_set_color(Color(color.r,color.g,color.b,alpha*.08))
		ribbon.surface_add_vertex(sample[1])
	ribbon.surface_end()

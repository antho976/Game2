extends Node3D
var kit: HubKit
func _ready() -> void:
	name = "VillagePortal"
	# A walk-through stone threshold, with a restrained veil recessed behind the arch.
	for side in [-1,1]:
		for row in 4:
			stone(Vector3(side*1.95,.3+row*.57,0),Vector3(.82,.55,.88),row)
	for i in 9:
		var angle := i*PI/8
		var block := stone(Vector3(cos(angle)*1.95,2.05+sin(angle)*1.95,0),Vector3(.73,.82,.88),i)
		block.rotation.z = angle-PI/2
	stone(Vector3(0,.07,.4),Vector3(4.5,.14,2),3)
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	mesh.mesh.size = Vector2(3.3,3.7)
	mesh.position = Vector3(0,1.85,-.05)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*2.0-1.0;
 float arch=length(vec2(p.x,max(0.0,-p.y)));
 float edge=1.0-smoothstep(.87,1.0,arch);
 float mist=noise(UV*vec2(4.0,7.0)+vec2(TIME*.06,-TIME*.16))*.65+noise(UV*vec2(9.0,13.0)+vec2(-TIME*.09,TIME*.1))*.35;
 float rim=pow(abs(p.x),8.0)*.3;
 ALBEDO=mix(vec3(.035,.085,.11),vec3(.16,.34,.36),mist*.5+rim);
 ALPHA=edge*.87;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.material_override = material
	add_child(mesh)
	var light := OmniLight3D.new()
	light.position = Vector3(0,1.6,.7)
	light.light_color = Color(.45,.7,.73)
	light.light_energy = .65
	light.omni_range = 7
	light.omni_attenuation = 1.8
	add_child(light)
func stone(pos: Vector3,size: Vector3,index: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = kit.world.beveled_box
	node.scale = size
	node.position = pos
	node.material_override = kit.world.stone[index%6]
	add_child(node)
	return node

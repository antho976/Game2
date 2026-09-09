shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/dungeon/mine_soil.gdshaderinc"
uniform float tone=1.0;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float grainy=texture(grain,p.xz*.65).r;
	float stain=texture(grain,p.xz*.045).r;
	vec3 stone=vec3(.345,.328,.283)*tone*(.70+grainy*.27+stain*.28);
	ALBEDO=mix(stone,soil(p),silt(p)*.86);
	ROUGHNESS=.94;
}

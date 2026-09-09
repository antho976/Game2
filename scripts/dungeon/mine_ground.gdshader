shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/dungeon/mine_soil.gdshaderinc"
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	ALBEDO=soil(p);
	float h=texture(grain,p.xz*.73).r;
	vec2 slope=vec2(texture(grain,(p.xz+vec2(.007,0.0))*.73).r-h,texture(grain,(p.xz+vec2(0.0,.007))*.73).r-h);
	NORMAL=normalize(NORMAL-mat3(VIEW_MATRIX)*vec3(slope.x,0,slope.y)*.42);
	ROUGHNESS=.96;
}

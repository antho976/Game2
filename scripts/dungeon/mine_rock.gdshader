shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
varying vec3 p;
varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=abs(MODEL_NORMAL_MATRIX*NORMAL);}
float stone_noise(vec3 position,vec3 weights,float scale){
	return texture(grain,position.yz*scale).r*weights.x+texture(grain,position.xz*scale).r*weights.y+texture(grain,position.xy*scale).r*weights.z;
}
void fragment(){
	vec3 w=pow(n,vec3(3));w/=max(w.x+w.y+w.z,.001);
	float fine=stone_noise(p,w,.06);
	float broken=stone_noise(p+vec3(13,7,21),w,.008);
	float broad=stone_noise(p,w,.0009);
	// Subtle strata belong on vertical faces, not long stripes across the cutaway.
	float strata=sin(p.y*8.0+broken*11.0)*.5+.5;
	vec3 stone=mix(vec3(.205,.221,.216),vec3(.34,.322,.279),broad);
	ALBEDO=stone*(.86+fine*.16)*(.96+broken*.08)*(1.0-strata*.045*(1.0-w.y));
	ROUGHNESS=.94;
}

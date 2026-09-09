uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
vec3 soil(vec3 p){
	float grains=texture(grain,p.xz*.73).r;
	float grit=texture(grain,p.xz*.17).r;
	float packed=texture(grain,p.xz*.024).r;
	return vec3(.265,.238,.197)*(.72+grit*.24+grains*.18+packed*.12);
}
float silt(vec3 p){
	return smoothstep(.38,.68,texture(grain,p.xz*.012).r);
}

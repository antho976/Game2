shader_type canvas_item;
// The armory page: warm vellum ground, forge light from the lower right, a
// cold window from the upper left, ink grain and a closing vignette.
uniform vec3 ink : source_color = vec3(.036,.034,.033);
uniform vec3 forge_color : source_color = vec3(.26,.11,.03);
uniform vec3 window_color : source_color = vec3(.05,.065,.095);
uniform vec2 forge_at = vec2(1.02,1.06);
uniform vec2 window_at = vec2(.04,-.05);
uniform float grain = 1.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment(){
	vec2 uv=UV;
	vec3 col=ink;
	float d=length((uv-forge_at)*vec2(1.0,1.35));
	col+=forge_color*exp(-d*d*3.4);
	float w=length((uv-window_at)*vec2(1.0,1.25));
	col+=window_color*exp(-w*w*3.0);
	// Laid paper: fine tooth, broad blotches and faint vertical fibres.
	float tooth=noise(uv*vec2(940.0,540.0));
	float blotch=noise(uv*vec2(11.0,7.0));
	float fibre=noise(vec2(uv.x*430.0,uv.y*26.0));
	col*=1.0+((tooth-.5)*.30+(blotch-.5)*.16+(fibre-.5)*.09)*grain;
	float v=smoothstep(1.05,.20,length((uv-.5)*vec2(1.10,1.0)));
	col*=mix(.16,1.0,v);
	COLOR=vec4(col,1.0);
}

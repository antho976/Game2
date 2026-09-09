shader_type canvas_item;
uniform sampler2D illustration : filter_linear;
uniform float clock = 0.0;
uniform float reveal = 0.0;
uniform float progress = 0.0;
uniform int chapter = 0;
uniform vec2 gate = vec2(.65,.46);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 uv=(UV-.5)/(1.015+progress*.045)+.5;
 uv.x+=.006*sin(progress*2.0);
 vec2 base=uv;
 // Local motion only: water, branches, banners and the dissolving cloak.
 if(chapter==0){
  float river=smoothstep(.88,.94,uv.y)*smoothstep(.52,.62,uv.x)*(1.0-smoothstep(.77,.85,uv.x));
  uv.x+=sin(uv.y*310.0-clock*1.6)*.0017*river;
  float branches=smoothstep(.80,.98,uv.x)*(1.0-smoothstep(.55,.90,uv.y));
  uv.x+=sin(clock*.6+uv.y*8.0)*.0018*branches;
 }else if(chapter==1){
  float flag=(1.0-smoothstep(.06,.18,uv.x))*smoothstep(.15,.28,uv.y)*(1.0-smoothstep(.38,.49,uv.y));
  uv.x+=sin(clock*1.2+uv.y*24.0)*.004*flag;
 }else if(chapter==2){
  float cloak=(1.0-smoothstep(.20,.43,uv.x))*smoothstep(.22,.36,uv.y);
  uv.y+=sin(clock*.75+uv.x*15.0)*.0025*cloak;
 }
 if(chapter==4){
  float blanket=exp(-dot((uv-vec2(.77,.53))*vec2(9,14),(uv-vec2(.77,.53))*vec2(9,14)));
  uv.y+=sin(clock*1.1)*.0008*blanket;
 }
 vec3 art=texture(illustration,uv).rgb;
 vec2 px=1.0/vec2(textureSize(illustration,0));
 float edge=length(texture(illustration,uv+vec2(px.x,0)).rgb-texture(illustration,uv-vec2(px.x,0)).rgb)+length(texture(illustration,uv+vec2(0,px.y)).rgb-texture(illustration,uv-vec2(0,px.y)).rgb);
 float grain=noise(base*130.0);
 vec3 paper=vec3(.78,.70,.55)+(grain-.5)*.045;
 float order=base.x*.42+(1.0-base.y)*.25+noise(base*8.0)*.22+grain*.045;
 float ink=smoothstep(order-.06,order+.03,reveal);
 float fill=smoothstep(order+.09,order+.27,reveal);
 vec3 line=mix(paper,vec3(.18,.13,.085),smoothstep(.045,.23,edge)*ink*.85);
 vec3 col=mix(line,art,fill);
 float fx=smoothstep(.9,1.2,reveal);
 // Soft smoke emerges from the actual chimney and drifts upwards.
 if(chapter==0){
  float smoke=0.0;
  for(int i=0;i<10;i++){
   float age=fract(clock*.10+float(i)*.1);
   vec2 center=vec2(.081+age*.045+sin(age*8.0+clock*.25)*.006,.342-age*.24);
   vec2 d=(base-center)/vec2(.007+age*.023,.014+age*.023);
   smoke+=exp(-dot(d,d)*1.5)*sin(age*3.14159)*.085;
  }
  col=mix(col,vec3(.53,.49,.41),smoke*fx);
  float window=exp(-dot((base-vec2(.067,.835))*vec2(65,35),(base-vec2(.067,.835))*vec2(65,35)));
  col+=vec3(.10,.052,.012)*window*(.8+.2*sin(clock*2.9))*fx;
 }
 if(chapter==2){
  float flame=exp(-dot((base-vec2(.988,.306))*vec2(85,55),(base-vec2(.988,.306))*vec2(85,55)));
  col+=vec3(.22,.12,.025)*flame*(.75+.15*sin(clock*7.1)+.1*sin(clock*13.0))*fx;
 }
 if(chapter==4){
  float candle=exp(-dot((base-vec2(.932,.307))*vec2(65,50),(base-vec2(.932,.307))*vec2(65,50)));
  col+=vec3(.15,.08,.015)*candle*(.8+.12*sin(clock*6.2)+.08*sin(clock*11.))*fx;
 }
 if(chapter==3){
  vec2 d=(base-gate)*vec2(1.6,1.0);
  float halo=exp(-dot(d,d)*35.0);
  float wave=.5+.5*sin(length(d)*110.0-clock*1.3);
  col+=vec3(.07,.055,.018)*halo*(.6+wave*.4)*fx;
 }
 // Sparse drifting ink/ember particles, with independent paths.
 for(int i=0;i<16;i++){
  float f=float(i);
  vec2 p=vec2(fract(f*.618+clock*.003),1.0-fract(f*.373+clock*(.012+fract(f*.3)*.015)));
  if(chapter==2){p.x*=.42;}
  float mote=1.0-smoothstep(.0007,.0022,length((base-p)*vec2(1.78,1.0)));
  col=mix(col,chapter==1?vec3(.7,.28,.10):vec3(.85,.72,.43),mote*.55*fx);
 }
 float vignette=1.0-.26*pow(length((UV-.5)*vec2(1.15,1.0)),1.4);
 COLOR=vec4(col*vignette,1.0);
}

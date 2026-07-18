#version 100

precision highp float;
uniform float time;
uniform vec2 resolution;

#define TIME time
#define RES  resolution

const int MSG_LEN  = 265;
const int LOGO_LEN = 7;

float hash(vec2 p){ return fract(sin(dot(p, vec2(41.3, 289.7))) * 43758.5453); }

float rowByte(int g, int r){
  if(g==0) return r==0?51.0:(r==1?51.0:(r==2?51.0:(r==3?63.0:(r==4?51.0:(r==5?51.0:(r==6?51.0:(0.0)))))));
  if(g==1) return r==0?51.0:(r==1?51.0:(r==2?51.0:(r==3?51.0:(r==4?51.0:(r==5?51.0:(r==6?63.0:(0.0)))))));
  if(g==2) return r==0?99.0:(r==1?119.0:(r==2?127.0:(r==3?127.0:(r==4?107.0:(r==5?99.0:(r==6?99.0:(0.0)))))));
  if(g==3) return r==0?12.0:(r==1?30.0:(r==2?51.0:(r==3?51.0:(r==4?63.0:(r==5?51.0:(r==6?51.0:(0.0)))))));
  if(g==4) return r==0?99.0:(r==1?103.0:(r==2?111.0:(r==3?123.0:(r==4?115.0:(r==5?99.0:(r==6?99.0:(0.0)))))));
  if(g==5) return r==0?30.0:(r==1?12.0:(r==2?12.0:(r==3?12.0:(r==4?12.0:(r==5?12.0:(r==6?30.0:(0.0)))))));
  if(g==6) return r==0?99.0:(r==1?99.0:(r==2?54.0:(r==3?28.0:(r==4?28.0:(r==5?54.0:(r==6?99.0:(0.0)))))));
  if(g==7) return r==0?0.0:(r==1?0.0:(r==2?0.0:(r==3?0.0:(r==4?0.0:(r==5?0.0:(r==6?0.0:(0.0)))))));
  if(g==8) return r==0?60.0:(r==1?102.0:(r==2?3.0:(r==3?3.0:(r==4?3.0:(r==5?102.0:(r==6?60.0:(0.0)))))));
  if(g==9) return r==0?63.0:(r==1?102.0:(r==2?102.0:(r==3?62.0:(r==4?54.0:(r==5?102.0:(r==6?103.0:(0.0)))))));
  if(g==10) return r==0?103.0:(r==1?102.0:(r==2?54.0:(r==3?30.0:(r==4?54.0:(r==5?102.0:(r==6?103.0:(0.0)))))));
  if(g==11) return r==0?63.0:(r==1?45.0:(r==2?12.0:(r==3?12.0:(r==4?12.0:(r==5?12.0:(r==6?30.0:(0.0)))))));
  if(g==12) return r==0?28.0:(r==1?54.0:(r==2?99.0:(r==3?99.0:(r==4?99.0:(r==5?54.0:(r==6?28.0:(0.0)))))));
  if(g==13) return r==0?30.0:(r==1?51.0:(r==2?48.0:(r==3?28.0:(r==4?6.0:(r==5?51.0:(r==6?63.0:(0.0)))))));
  if(g==14) return r==0?62.0:(r==1?99.0:(r==2?115.0:(r==3?123.0:(r==4?111.0:(r==5?103.0:(r==6?62.0:(0.0)))))));
  if(g==15) return r==0?28.0:(r==1?6.0:(r==2?3.0:(r==3?31.0:(r==4?51.0:(r==5?51.0:(r==6?30.0:(0.0)))))));
  if(g==16) return r==0?0.0:(r==1?0.0:(r==2?0.0:(r==3?0.0:(r==4?0.0:(r==5?12.0:(r==6?12.0:(0.0)))))));
  if(g==17) return r==0?31.0:(r==1?54.0:(r==2?102.0:(r==3?102.0:(r==4?102.0:(r==5?54.0:(r==6?31.0:(0.0)))))));
  if(g==18) return r==0?127.0:(r==1?70.0:(r==2?22.0:(r==3?30.0:(r==4?22.0:(r==5?70.0:(r==6?127.0:(0.0)))))));
  if(g==19) return r==0?63.0:(r==1?102.0:(r==2?102.0:(r==3?62.0:(r==4?102.0:(r==5?102.0:(r==6?63.0:(0.0)))))));
  if(g==20) return r==0?51.0:(r==1?51.0:(r==2?51.0:(r==3?30.0:(r==4?12.0:(r==5?12.0:(r==6?30.0:(0.0)))))));
  if(g==21) return r==0?60.0:(r==1?102.0:(r==2?3.0:(r==3?3.0:(r==4?115.0:(r==5?102.0:(r==6?124.0:(0.0)))))));
  if(g==22) return r==0?56.0:(r==1?60.0:(r==2?54.0:(r==3?51.0:(r==4?127.0:(r==5?48.0:(r==6?120.0:(0.0)))))));
  if(g==23) return r==0?30.0:(r==1?51.0:(r==2?7.0:(r==3?14.0:(r==4?56.0:(r==5?51.0:(r==6?30.0:(0.0)))))));
  if(g==24) return r==0?127.0:(r==1?70.0:(r==2?22.0:(r==3?30.0:(r==4?22.0:(r==5?6.0:(r==6?15.0:(0.0)))))));
  if(g==25) return r==0?0.0:(r==1?0.0:(r==2?0.0:(r==3?63.0:(r==4?0.0:(r==5?0.0:(r==6?0.0:(0.0)))))));
  if(g==26) return r==0?99.0:(r==1?99.0:(r==2?99.0:(r==3?107.0:(r==4?127.0:(r==5?119.0:(r==6?99.0:(0.0)))))));
  if(g==27) return r==0?15.0:(r==1?6.0:(r==2?6.0:(r==3?6.0:(r==4?70.0:(r==5?102.0:(r==6?127.0:(0.0)))))));
  if(g==28) return r==0?63.0:(r==1?102.0:(r==2?102.0:(r==3?62.0:(r==4?6.0:(r==5?6.0:(r==6?15.0:(0.0)))))));
  if(g==29) return r==0?127.0:(r==1?99.0:(r==2?49.0:(r==3?24.0:(r==4?76.0:(r==5?102.0:(r==6?127.0:(0.0)))))));
  if(g==30) return r==0?12.0:(r==1?14.0:(r==2?12.0:(r==3?12.0:(r==4?12.0:(r==5?12.0:(r==6?63.0:(0.0)))))));
  if(g==31) return r==0?30.0:(r==1?51.0:(r==2?51.0:(r==3?62.0:(r==4?48.0:(r==5?24.0:(r==6?14.0:(0.0)))))));
  return 0.0;
}
int charAt(int i){
  if(i==0) return 0;
  if(i==1) return 1;
  if(i==2) return 2;
  if(i==3) return 3;
  if(i==4) return 4;
  if(i==5) return 5;
  if(i==6) return 6;
  if(i==7) return 7;
  if(i==8) return 8;
  if(i==9) return 9;
  if(i==10) return 3;
  if(i==11) return 8;
  if(i==12) return 10;
  if(i==13) return 11;
  if(i==14) return 9;
  if(i==15) return 12;
  if(i==16) return 7;
  if(i==17) return 13;
  if(i==18) return 14;
  if(i==19) return 13;
  if(i==20) return 15;
  if(i==21) return 7;
  if(i==22) return 16;
  if(i==23) return 16;
  if(i==24) return 16;
  if(i==25) return 16;
  if(i==26) return 7;
  if(i==27) return 8;
  if(i==28) return 12;
  if(i==29) return 17;
  if(i==30) return 18;
  if(i==31) return 17;
  if(i==32) return 7;
  if(i==33) return 19;
  if(i==34) return 20;
  if(i==35) return 7;
  if(i==36) return 2;
  if(i==37) return 18;
  if(i==38) return 21;
  if(i==39) return 22;
  if(i==40) return 9;
  if(i==41) return 14;
  if(i==42) return 2;
  if(i==43) return 7;
  if(i==44) return 16;
  if(i==45) return 16;
  if(i==46) return 16;
  if(i==47) return 16;
  if(i==48) return 7;
  if(i==49) return 2;
  if(i==50) return 1;
  if(i==51) return 23;
  if(i==52) return 5;
  if(i==53) return 8;
  if(i==54) return 7;
  if(i==55) return 19;
  if(i==56) return 20;
  if(i==57) return 7;
  if(i==58) return 18;
  if(i==59) return 9;
  if(i==60) return 5;
  if(i==61) return 8;
  if(i==62) return 7;
  if(i==63) return 23;
  if(i==64) return 10;
  if(i==65) return 5;
  if(i==66) return 24;
  if(i==67) return 24;
  if(i==68) return 7;
  if(i==69) return 25;
  if(i==70) return 7;
  if(i==71) return 9;
  if(i==72) return 18;
  if(i==73) return 23;
  if(i==74) return 5;
  if(i==75) return 23;
  if(i==76) return 11;
  if(i==77) return 12;
  if(i==78) return 9;
  if(i==79) return 7;
  if(i==80) return 3;
  if(i==81) return 4;
  if(i==82) return 11;
  if(i==83) return 0;
  if(i==84) return 18;
  if(i==85) return 2;
  if(i==86) return 23;
  if(i==87) return 7;
  if(i==88) return 25;
  if(i==89) return 7;
  if(i==90) return 8;
  if(i==91) return 8;
  if(i==92) return 25;
  if(i==93) return 19;
  if(i==94) return 20;
  if(i==95) return 7;
  if(i==96) return 16;
  if(i==97) return 16;
  if(i==98) return 16;
  if(i==99) return 16;
  if(i==100) return 7;
  if(i==101) return 26;
  if(i==102) return 18;
  if(i==103) return 27;
  if(i==104) return 8;
  if(i==105) return 12;
  if(i==106) return 2;
  if(i==107) return 18;
  if(i==108) return 7;
  if(i==109) return 11;
  if(i==110) return 12;
  if(i==111) return 7;
  if(i==112) return 11;
  if(i==113) return 0;
  if(i==114) return 18;
  if(i==115) return 7;
  if(i==116) return 2;
  if(i==117) return 3;
  if(i==118) return 8;
  if(i==119) return 0;
  if(i==120) return 5;
  if(i==121) return 4;
  if(i==122) return 18;
  if(i==123) return 7;
  if(i==124) return 16;
  if(i==125) return 16;
  if(i==126) return 16;
  if(i==127) return 16;
  if(i==128) return 7;
  if(i==129) return 21;
  if(i==130) return 9;
  if(i==131) return 18;
  if(i==132) return 18;
  if(i==133) return 11;
  if(i==134) return 5;
  if(i==135) return 4;
  if(i==136) return 21;
  if(i==137) return 23;
  if(i==138) return 7;
  if(i==139) return 11;
  if(i==140) return 12;
  if(i==141) return 7;
  if(i==142) return 11;
  if(i==143) return 0;
  if(i==144) return 18;
  if(i==145) return 7;
  if(i==146) return 26;
  if(i==147) return 0;
  if(i==148) return 12;
  if(i==149) return 27;
  if(i==150) return 18;
  if(i==151) return 7;
  if(i==152) return 23;
  if(i==153) return 8;
  if(i==154) return 18;
  if(i==155) return 4;
  if(i==156) return 18;
  if(i==157) return 7;
  if(i==158) return 16;
  if(i==159) return 16;
  if(i==160) return 16;
  if(i==161) return 16;
  if(i==162) return 7;
  if(i==163) return 28;
  if(i==164) return 3;
  if(i==165) return 9;
  if(i==166) return 3;
  if(i==167) return 17;
  if(i==168) return 12;
  if(i==169) return 6;
  if(i==170) return 7;
  if(i==171) return 16;
  if(i==172) return 16;
  if(i==173) return 7;
  if(i==174) return 9;
  if(i==175) return 3;
  if(i==176) return 29;
  if(i==177) return 12;
  if(i==178) return 9;
  if(i==179) return 7;
  if(i==180) return 30;
  if(i==181) return 31;
  if(i==182) return 30;
  if(i==183) return 30;
  if(i==184) return 7;
  if(i==185) return 16;
  if(i==186) return 16;
  if(i==187) return 7;
  if(i==188) return 9;
  if(i==189) return 18;
  if(i==190) return 27;
  if(i==191) return 12;
  if(i==192) return 3;
  if(i==193) return 17;
  if(i==194) return 18;
  if(i==195) return 17;
  if(i==196) return 7;
  if(i==197) return 16;
  if(i==198) return 16;
  if(i==199) return 7;
  if(i==200) return 24;
  if(i==201) return 3;
  if(i==202) return 5;
  if(i==203) return 9;
  if(i==204) return 27;
  if(i==205) return 5;
  if(i==206) return 21;
  if(i==207) return 0;
  if(i==208) return 11;
  if(i==209) return 7;
  if(i==210) return 16;
  if(i==211) return 16;
  if(i==212) return 16;
  if(i==213) return 16;
  if(i==214) return 7;
  if(i==215) return 11;
  if(i==216) return 0;
  if(i==217) return 18;
  if(i==218) return 7;
  if(i==219) return 0;
  if(i==220) return 3;
  if(i==221) return 8;
  if(i==222) return 10;
  if(i==223) return 7;
  if(i==224) return 5;
  if(i==225) return 23;
  if(i==226) return 7;
  if(i==227) return 19;
  if(i==228) return 3;
  if(i==229) return 8;
  if(i==230) return 10;
  if(i==231) return 7;
  if(i==232) return 16;
  if(i==233) return 16;
  if(i==234) return 16;
  if(i==235) return 16;
  if(i==236) return 7;
  if(i==237) return 23;
  if(i==238) return 11;
  if(i==239) return 3;
  if(i==240) return 20;
  if(i==241) return 7;
  if(i==242) return 28;
  if(i==243) return 0;
  if(i==244) return 12;
  if(i==245) return 23;
  if(i==246) return 28;
  if(i==247) return 0;
  if(i==248) return 12;
  if(i==249) return 9;
  if(i==250) return 7;
  if(i==251) return 16;
  if(i==252) return 16;
  if(i==253) return 16;
  if(i==254) return 16;
  if(i==255) return 7;
  if(i==256) return 26;
  if(i==257) return 9;
  if(i==258) return 3;
  if(i==259) return 28;
  if(i==260) return 7;
  if(i==261) return 7;
  if(i==262) return 7;
  if(i==263) return 7;
  if(i==264) return 7;
  return 7;
}
int logoId(int i){
  if(i==0) return 0;
  if(i==1) return 1;
  if(i==2) return 2;
  if(i==3) return 3;
  if(i==4) return 4;
  if(i==5) return 5;
  if(i==6) return 6;
  return 7;
}

// pixel (0/1) du glyphe g aux coords locales (lx,ly) dans [0,1), ly: 0=haut
float glyphPix(int g, float lx, float ly){
  if(lx < 0.0 || lx >= 1.0 || ly < 0.0 || ly >= 1.0) return 0.0;
  int cx = int(floor(lx * 8.0));
  int cy = int(floor(ly * 8.0));
  float rb = rowByte(g, cy);
  return mod(floor(rb / exp2(float(cx))), 2.0);   // bit cx, LSB=gauche
}

// ---- starfield parallax (3 couches) ----
vec3 starfield(vec2 uv, float aspect){
  vec3 c = vec3(0.0);
  for(int i = 0; i < 3; i++){
    float fi = float(i);
    float sp = 0.03 + fi * 0.06;
    vec2 g = vec2(uv.x * aspect + TIME * sp, uv.y) * (10.0 + fi * 14.0);
    vec2 cell = floor(g);
    vec2 f = fract(g) - 0.5;
    float h = hash(cell + fi * 41.0);
    float star = step(0.95 - fi * 0.015, h) * smoothstep(0.42, 0.0, length(f));
    c += star * (0.35 + fi * 0.28) * vec3(0.55, 1.0, 0.7);
  }
  return c;
}

// ---- copper bars (empilees, sinus, glossy, vert->ambre) ----
vec3 copper(vec2 uv){
  vec3 c = vec3(0.0);
  for(int i = 0; i < 5; i++){
    float fi = float(i);
    float cy = 0.80 + 0.10 * sin(TIME * 1.2 + fi * 1.15);
    float d = abs(uv.y - cy);
    float bar = smoothstep(0.040, 0.0, d);
    float gloss = smoothstep(0.012, 0.0, d);
    vec3 bc = mix(vec3(0.0, 0.85, 0.25), vec3(0.9, 0.7, 0.05), fi / 4.0);
    c += bar * bc * 0.55 + gloss * vec3(0.7, 1.0, 0.75) * 0.6;
  }
  return c;
}

// ---- plasma vert subtil ----
vec3 plasma(vec2 uv){
  float p = sin(uv.x * 9.0 + TIME)
          + sin(uv.y * 11.0 - TIME * 1.1)
          + sin((uv.x + uv.y) * 7.0 + TIME * 0.7)
          + sin(length(uv - 0.5) * 13.0 - TIME * 1.3);
  p *= 0.25;
  return (0.5 + 0.5 * cos(vec3(0.0, 1.6, 3.2) + p * 3.0)) * vec3(0.15, 1.0, 0.35);
}

// ---- logo sinus bondissant "HUMANIX" ----
float logo(vec2 uv, float aspect){
  float ch = 0.135;
  float cw = ch / aspect;
  float tw = cw * float(LOGO_LEN);
  float lx = (uv.x - (0.5 - tw * 0.5)) / cw;
  int idx = int(floor(lx));
  if(idx < 0 || idx >= LOGO_LEN) return 0.0;
  float fx = fract(lx);
  float bounce = 0.055 * sin(TIME * 2.0 + float(idx) * 0.6);
  float cy = 0.62 + bounce;
  float ly = 1.0 - (uv.y - (cy - ch * 0.5)) / ch;
  return glyphPix(logoId(idx), fx, ly);
}

// ---- scroller sinus (bas de l'ecran) ----
float scroller(vec2 uv, float aspect){
  float ch = 0.085;
  float cw = ch / aspect;
  float x = uv.x + TIME * 0.16;
  int idx = int(floor(x / cw));
  if(idx < 0) return 0.0;
  int m = idx - (idx / MSG_LEN) * MSG_LEN;   // idx mod MSG_LEN (idx>=0)
  float fx = fract(x / cw);
  float wave = 0.028 * sin(uv.x * 7.0 + TIME * 3.0);
  float cy = 0.11 + wave;
  float ly = 1.0 - (uv.y - (cy - ch * 0.5)) / ch;
  return glyphPix(charAt(m), fx, ly);
}

void main(){
  vec2 uv = gl_FragCoord.xy / RES.xy;
  float aspect = RES.x / RES.y;

  vec3 col = mix(vec3(0.0, 0.012, 0.0), vec3(0.0, 0.05, 0.02), uv.y);
  col += starfield(uv, aspect);
  col += copper(uv);
  col += plasma(uv) * 0.11;

  float lg = logo(uv, aspect);
  col = mix(col, vec3(0.55, 1.0, 0.6), lg);
  col += lg * vec3(0.15, 0.4, 0.2);            // léger halo

  float sc = scroller(uv, aspect);
  col = mix(col, vec3(0.6, 1.0, 0.65), sc);

  float d = distance(uv, vec2(0.5));
  col *= 1.0 - d * 0.55;                        // vignette
  col = clamp(col, 0.0, 1.0);
  gl_FragColor = vec4(col, 1.0);
}

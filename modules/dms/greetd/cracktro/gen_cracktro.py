#!/usr/bin/env python3
# Génère cracktro.frag (glpaper, GLSL ES 1.00) + une variante preview (glslViewer).
# La font 8x8 (domaine public, dhepper/font8x8) et le texte sont encodés en pur
# contrôle de flux (if / ?:) -> aucun tableau, aucune indexation dynamique, aucun
# opérateur bit-a-bit : 100% conforme GLSL ES 1.00 (contexte GLES2 de glpaper).
import re, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_H = os.path.join(HERE, "font8x8_basic.h")

# ---- texte ----
LOGO = "HUMANIX"
MSG = ("HUMANIX CRACKTRO 2026 .... CODED BY MEG4R0M .... "
       "MUSIC BY ERIC SKIFF - RESISTOR ANTHEMS - CC-BY .... "
       "WELCOME TO THE MACHINE .... GREETINGS TO THE WHOLE SCENE .... "
       "PARADOX .. RAZOR 1911 .. RELOADED .. FAIRLIGHT .... "
       "THE HACK IS BACK .... STAY PHOSPHOR .... WRAP     ")

# ---- parse font8x8 ----
rows_by_code = {}
txt = open(FONT_H).read()
# lignes: { 0x.., ...},   // U+00XX
idx = 0
for m in re.finditer(r"\{([^}]*)\}", txt):
    body = m.group(1)
    hexes = re.findall(r"0x[0-9A-Fa-f]{2}", body)
    if len(hexes) != 8:
        continue
    rows_by_code[idx] = [int(h, 16) for h in hexes]
    idx += 1
    if idx >= 128:
        break

def glyph_rows(ch):
    c = ord(ch)
    if c in rows_by_code:
        return rows_by_code[c]
    return [0] * 8

# sanity: rendu ASCII de 'A' (LSB=gauche, 1er octet=haut)
def ascii_art(ch):
    out = []
    for r in glyph_rows(ch):
        out.append("".join('#' if (r >> c) & 1 else '.' for c in range(8)))
    return "\n".join(out)

# ---- charset commun logo+message ----
used = []
for ch in (LOGO + MSG):
    if ch not in used:
        used.append(ch)
gid = {ch: i for i, ch in enumerate(used)}

# ---- génère rowByte(g,r) ----
def emit_rowbyte():
    lines = ["float rowByte(int g, int r){"]
    for ch in used:
        rows = glyph_rows(ch)
        # ternaire imbriqué sur r
        expr = "%.1f" % rows[7]
        for r in range(6, -1, -1):
            expr = "r==%d?%.1f:(%s)" % (r, rows[r], expr)
        lines.append("  if(g==%d) return %s;" % (gid[ch], expr))
    lines.append("  return 0.0;")
    lines.append("}")
    return "\n".join(lines)

# ---- charAt(i) et logoId(i) : if-chain plate ----
def emit_charat():
    lines = ["int charAt(int i){"]
    for i, ch in enumerate(MSG):
        lines.append("  if(i==%d) return %d;" % (i, gid[ch]))
    lines.append("  return %d;" % gid[' '])
    lines.append("}")
    return "\n".join(lines)

def emit_logoid():
    lines = ["int logoId(int i){"]
    for i, ch in enumerate(LOGO):
        lines.append("  if(i==%d) return %d;" % (i, gid[ch]))
    lines.append("  return %d;" % gid[' '])
    lines.append("}")
    return "\n".join(lines)

# ---- corps du shader (tokens @TIME@ / @RES@) ----
BODY = r"""
precision highp float;
@UNIFORMS@

#define TIME @TIME@
#define RES  @RES@

const int MSG_LEN  = @MSGLEN@;
const int LOGO_LEN = @LOGOLEN@;

float hash(vec2 p){ return fract(sin(dot(p, vec2(41.3, 289.7))) * 43758.5453); }

@ROWBYTE@
@CHARAT@
@LOGOID@

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
"""

def build(uniform_block, time_tok, res_tok, header=""):
    s = BODY
    s = s.replace("@UNIFORMS@", uniform_block)
    s = s.replace("@TIME@", time_tok)
    s = s.replace("@RES@", res_tok)
    s = s.replace("@ROWBYTE@", emit_rowbyte())
    s = s.replace("@CHARAT@", emit_charat())
    s = s.replace("@LOGOID@", emit_logoid())
    s = s.replace("@MSGLEN@", str(len(MSG)))
    s = s.replace("@LOGOLEN@", str(len(LOGO)))
    return header + s

# glpaper : #version 100, uniforms time/resolution
frag = build("uniform float time;\nuniform vec2 resolution;",
             "time", "resolution", header="#version 100\n")
open(os.path.join(HERE, "cracktro.frag"), "w").write(frag)

# preview glslViewer : u_time/u_resolution
prev = build("uniform float u_time;\nuniform vec2 u_resolution;",
             "u_time", "u_resolution", header="#ifdef GL_ES\nprecision highp float;\n#endif\n")
open("/tmp/preview.frag", "w").write(prev)

print("glyphes utilises: %d" % len(used))
print("MSG_LEN=%d LOGO_LEN=%d" % (len(MSG), len(LOGO)))
print("taille cracktro.frag: %d o" % len(frag))
print("--- 'A' (verif orientation LSB=gauche, haut->bas) ---")
print(ascii_art("A"))
print("--- 'H' ---")
print(ascii_art("H"))

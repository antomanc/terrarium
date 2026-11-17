// The GPU half of the terrarium: a WebGL2 port of the shading in scene.bend.
// Bend decides the world (which voxel is what, where every light is); this
// file only carries light through it. Keep the constants in step with
// scene.bend: same camera, DDA, ambient occlusion, lights, sky and tone.

const VERT = `#version 300 es
void main() {
  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}`;

const FRAG = `#version 300 es
precision highp float;
precision highp int;
precision highp usampler3D;

uniform usampler3D uVox;
uniform vec2 uRes;
uniform int uDay;
uniform uint uSeed;
uniform uint uStars;
uniform vec3 uC1;
uniform vec3 uC2;
uniform vec3 uC3;
uniform int uNL;
uniform vec3 uLP[64];
uniform vec3 uLC[64];
out vec4 outColor;

const vec3 D = vec3(-0.57735);
const vec3 MOON = vec3(-0.48, 0.8, 0.36);

uint hash3(uint x, uint y, uint z) {
  uint h0 = (x * 73856093u) ^ (y * 19349663u) ^ (z * 83492791u);
  uint h1 = h0 ^ (h0 >> 13);
  uint h2 = h1 * 1540483477u;
  return h2 ^ (h2 >> 15);
}

uint vox(vec3 c) {
  if (any(lessThan(c, vec3(0.0))) || any(greaterThanEqual(c, vec3(64.0)))) return 255u;
  return texelFetch(uVox, ivec3(c), 0).r;
}

// Ray.cast (march here: cast is reserved in GLSL): the slab entry, then Amanatides-Woo steps; m = 255 is a miss.
void march(vec3 o, vec3 d, out uint m, out int ax, out float t) {
  vec3 inv = 1.0 / d;
  vec3 a = -o * inv;
  vec3 b = (vec3(64.0) - o) * inv;
  vec3 lo = min(a, b);
  vec3 hi = max(a, b);
  float t0 = max(max(lo.x, lo.y), max(lo.z, 0.0));
  float t1 = min(hi.x, min(hi.y, hi.z));
  ax = (lo.x >= lo.y && lo.x >= lo.z) ? 0 : (lo.y >= lo.z ? 1 : 2);
  t = t0;
  m = 255u;
  if (!(t0 < t1)) return;
  float te = t0 + 0.0001;
  vec3 c = clamp(floor(o + d * te), 0.0, 63.0);
  vec3 st = vec3(d.x > 0.0 ? 1.0 : -1.0, d.y > 0.0 ? 1.0 : -1.0, d.z > 0.0 ? 1.0 : -1.0);
  vec3 tm = (c + vec3(d.x > 0.0 ? 1.0 : 0.0, d.y > 0.0 ? 1.0 : 0.0, d.z > 0.0 ? 1.0 : 0.0) - o) * inv;
  vec3 dt = abs(inv);
  m = vox(c);
  for (int i = 0; i < 200; i++) {
    if (m != 0u) return;
    if (tm.x < tm.y && tm.x < tm.z) { c.x += st.x; t = tm.x; tm.x += dt.x; ax = 0; }
    else if (tm.y < tm.z) { c.y += st.y; t = tm.y; tm.y += dt.y; ax = 1; }
    else { c.z += st.z; t = tm.z; tm.z += dt.z; ax = 2; }
    m = vox(c);
  }
  m = 255u;
}

bool isCry(uint m) { return m == 8u || m == 13u || m == 14u; }
vec3 cryCol(uint m) { return m == 8u ? uC1 : (m == 13u ? uC2 : uC3); }

vec3 albedo(uint m) {
  if (isCry(m)) return cryCol(m);
  if (m == 1u) return vec3(0.24, 0.56, 0.30);
  if (m == 2u) return vec3(0.42, 0.28, 0.18);
  if (m == 3u) return vec3(0.32, 0.32, 0.38);
  if (m == 4u) return vec3(0.38, 0.24, 0.14);
  if (m == 5u) return vec3(0.10, 0.36, 0.30);
  if (m == 7u) return vec3(0.85, 0.80, 0.72);
  if (m == 9u) return vec3(0.95, 0.48, 0.70);
  if (m == 10u) return vec3(0.98, 0.85, 0.30);
  if (m == 11u) return vec3(0.95, 0.95, 0.95);
  if (m == 12u) return vec3(0.70, 0.50, 0.95);
  if (m == 15u) return vec3(0.92, 0.95, 1.0);
  if (m == 16u) return vec3(0.18, 0.46, 0.24);
  return vec3(0.9);
}

vec3 glowMat(uint m) {
  vec3 e = isCry(m) ? cryCol(m) * 0.75 : (m == 6u ? vec3(1.8, 0.45, 1.0) : vec3(0.0));
  return e * (uDay == 1 ? 0.35 : 1.0);
}

float solid(vec3 c) {
  uint m = vox(c);
  return (m != 0u && m != 255u) ? 1.0 : 0.0;
}

float ao(vec3 p, vec3 n, int ax) {
  vec3 c = floor(p + n * 0.5);
  vec3 u = ax == 0 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
  vec3 v = ax == 2 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0);
  float pu = dot(p, u);
  float pv = dot(p, v);
  float fu = pu - floor(pu);
  float fv = pv - floor(pv);
  float iu = 1.0 - fu;
  float iv = 1.0 - fv;
  float o = solid(c - u) * iu * iu + solid(c + u) * fu * fu
    + solid(c - v) * iv * iv + solid(c + v) * fv * fv
    + solid(c - u - v) * iu * iu * iv * iv + solid(c + u - v) * fu * fu * iv * iv
    + solid(c - u + v) * iu * iu * fv * fv + solid(c + u + v) * fu * fu * fv * fv;
  return 1.0 - 0.6 * clamp(o, 0.0, 1.0);
}

float jit(vec3 p, vec3 n) {
  vec3 c = floor(p - n * 0.5);
  uint h = hash3(uint(c.x), uint(c.y), uint(c.z));
  return 0.84 + float(h % 64u) * 0.004;
}

vec3 surf(uint m, int ax, float t, vec3 o) {
  vec3 p = o + D * t;
  vec3 n = vec3(ax == 0 ? 1.0 : 0.0, ax == 1 ? 1.0 : 0.0, ax == 2 ? 1.0 : 0.0);
  uint sm; int sax; float st;
  march(p + n * 0.01, MOON, sm, sax, st);
  float sh = sm == 255u ? 1.0 : 0.0;
  float s = max(0.0, dot(n, MOON)) * sh;
  vec3 l;
  if (uDay == 1) {
    float da = 0.22 + 0.22 * n.y;
    l = vec3(da * 0.55 + 1.85 * s, da * 0.75 + 1.55 * s, da * 1.15 + 1.05 * s);
  } else {
    float na = 0.03 + 0.03 * n.y;
    l = vec3(na + 0.14 * s, na * 1.1 + 0.19 * s, na * 1.6 + 0.34 * s);
  }
  for (int i = 0; i < 64; i++) {
    if (i >= uNL) break;
    vec3 v = uLP[i] - p;
    float d2 = dot(v, v);
    float ndl = max(0.0, dot(n, v) / sqrt(d2));
    l += uLC[i] * (ndl * 2.2 / (1.0 + d2 * 0.22));
  }
  float k = ao(p, n, ax) * jit(p, n);
  return albedo(m) * l * k + glowMat(m);
}

vec3 glow(vec3 o, float tmax) {
  vec3 acc = vec3(0.0);
  for (int i = 0; i < 64; i++) {
    if (i >= uNL) break;
    vec3 q = uLP[i] - o;
    float tp = dot(q, D);
    float d2 = max(0.0, dot(q, q) - tp * tp);
    float f = tp < tmax ? 0.9 * exp(-d2 * 17.0) + 0.16 * exp(-d2 * 0.6) : 0.0;
    acc += uLC[i] * f;
  }
  return acc;
}

float star(float fx, float fy, float cell, float s, uint ncell) {
  float cx = floor(fx / cell);
  float cy = floor(fy / cell);
  uint h = hash3(uint(cx), uint(cy), uSeed ^ 777u);
  if (h % ncell >= uStars) return 0.0;
  float sx = (cx + 0.125 + float((h / 7u) % 30u) * 0.025) * cell;
  float sy = (cy + 0.125 + float((h / 210u) % 30u) * 0.025) * cell;
  float d2 = ((fx - sx) * (fx - sx) + (fy - sy) * (fy - sy)) / (s * s);
  return (0.35 + float((h / 6300u) % 64u) * 0.012) * exp(-d2 * 0.6);
}

// View.make and Px.color.
vec3 sample1(float fx, float fy) {
  float fw = uRes.x;
  float fh = uRes.y;
  float upp = max(65.5 / fw, 75.6 / fh);
  float s = 0.063 / upp;
  float cell = 40.0 * s;
  uint ncell = uint(ceil(fw / cell)) * uint(ceil(fh / cell));
  float cy = fh * (fh > fw * 1.6 ? 0.59 : 0.54);
  float sx = (fx - fw * 0.5) * upp;
  float sy = (cy - fy) * upp;
  vec3 o = vec3(107.06 + sx * 0.70711 - sy * 0.40825, 101.06 + sy * 0.8165,
    107.06 - sx * 0.70711 - sy * 0.40825);
  uint m; int ax; float t;
  march(o, D, m, ax, t);
  bool miss = m == 255u;
  vec3 c = miss ? vec3(0.0) : surf(m, ax, t, o);
  if (uDay == 0) c += glow(o, miss ? 100000.0 : t);
  if (miss) {
    float v = clamp(fy / fh, 0.0, 1.0);
    if (uDay == 1) c += vec3(0.10 + 0.95 * v * v, 0.30 + 0.50 * v * v, 0.80 - 0.15 * v * v);
    else { float st = star(fx, fy, cell, s, ncell); c += vec3(st * 0.9, st * 0.95, st); }
  }
  return c;
}

float tone(float c) {
  float v = max(0.0, c - 0.003);
  float e = clamp(1.0 - exp(-v * 1.5), 0.0, 1.0);
  return floor(255.0 * pow(e, 0.4545) + 0.5) / 255.0;
}

void main() {
  float x = floor(gl_FragCoord.x);
  float y = uRes.y - 1.0 - floor(gl_FragCoord.y);
  vec3 c = (sample1(x + 0.25, y + 0.25) + sample1(x + 0.75, y + 0.25)
    + sample1(x + 0.25, y + 0.75) + sample1(x + 0.75, y + 0.75)) * 0.25;
  outColor = vec4(tone(c.r), tone(c.g), tone(c.b), 1.0);
}`;

function compile(gl, type, src) {
  const sh = gl.createShader(type);
  gl.shaderSource(sh, src);
  gl.compileShader(sh);
  if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(sh));
  return sh;
}

export class Renderer {
  constructor(canvas) {
    const gl = canvas.getContext("webgl2", { preserveDrawingBuffer: true, antialias: false });
    if (!gl) throw new Error("This browser has no WebGL2.");
    this.gl = gl;
    this.canvas = canvas;
    const prog = gl.createProgram();
    gl.attachShader(prog, compile(gl, gl.VERTEX_SHADER, VERT));
    gl.attachShader(prog, compile(gl, gl.FRAGMENT_SHADER, FRAG));
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog));
    this.prog = prog;
    this.u = name => gl.getUniformLocation(prog, name);
    gl.bindVertexArray(gl.createVertexArray());
    this.tex = gl.createTexture();
  }

  // The 64^3 voxel grid, one material byte per voxel, x fastest.
  setWorld(voxels) {
    const gl = this.gl;
    gl.bindTexture(gl.TEXTURE_3D, this.tex);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    gl.texParameteri(gl.TEXTURE_3D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_3D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texImage3D(gl.TEXTURE_3D, 0, gl.R8UI, 64, 64, 64, 0, gl.RED_INTEGER, gl.UNSIGNED_BYTE, voxels);
  }

  // Draws the frame in bands, one per animation frame, so a slow phone GPU
  // never sees a single long draw call. Resolves when the frame is done.
  async render({ width, height, day, seed, stars, colors, lights }, onProgress) {
    const { gl, canvas } = this;
    canvas.width = width;
    canvas.height = height;
    gl.viewport(0, 0, width, height);
    gl.useProgram(this.prog);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_3D, this.tex);
    gl.uniform1i(this.u("uVox"), 0);
    gl.uniform2f(this.u("uRes"), width, height);
    gl.uniform1i(this.u("uDay"), day ? 1 : 0);
    gl.uniform1ui(this.u("uSeed"), seed >>> 0);
    gl.uniform1ui(this.u("uStars"), stars >>> 0);
    gl.uniform3fv(this.u("uC1"), colors[0]);
    gl.uniform3fv(this.u("uC2"), colors[1]);
    gl.uniform3fv(this.u("uC3"), colors[2]);
    const n = Math.min(64, lights.length);
    const lp = new Float32Array(64 * 3);
    const lc = new Float32Array(64 * 3);
    for (let i = 0; i < n; i++) {
      lp.set(lights[i].pos, i * 3);
      lc.set(lights[i].col, i * 3);
    }
    gl.uniform1i(this.u("uNL"), n);
    gl.uniform3fv(this.u("uLP"), lp);
    gl.uniform3fv(this.u("uLC"), lc);
    gl.enable(gl.SCISSOR_TEST);
    const band = Math.max(32, Math.floor(400000 / width));
    for (let y = 0; y < height; y += band) {
      gl.scissor(0, y, width, Math.min(band, height - y));
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      gl.finish();
      onProgress?.(Math.min(1, (y + band) / height));
      await new Promise(r => requestAnimationFrame(r));
    }
    gl.disable(gl.SCISSOR_TEST);
  }
}

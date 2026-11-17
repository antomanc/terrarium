# Terrarium: a floating voxel island that grows from a GitHub profile,
# ray traced into a phone wallpaper. Night is AMOLED: a pure black sky,
# light only from the moon and the island's own emitters.
#
#   bend scene.bend -o scene
#   ./scene <day> <seed> <total> <active> <last30> <streak> <longest> <prs>
#           <stars> <rgb1> <rgb2> <rgb3>          (writes day.ppm or night.ppm)
import Base

type Stats is Data:
  Stats{day: U32, seed: U32, total: U32, active: U32, last30: U32,
    streak: U32, longest: U32, prs: U32, stars: U32, c1: U32, c2: U32, c3: U32}

# What the stats grow into. Every field is read by the voxel function.
type Garden is Data:
  Garden{day: Bool, seed: U32, trunk: F32, ccy: F32, cr2: F32, bloom: U32,
    mush: U32, flow: U32, snow: Bool, c1: U32, c2: U32, c3: U32}

type Hit is Data:
  Hit{m: U32, ax: U32, t: F32}

type Rgb is Data:
  Rgb{r: F32, g: F32, b: F32}

type Lt is Data:
  Lt{x: F32, y: F32, z: F32, r: F32, g: F32, b: F32}

type Rows is Data:
  RLeaf{bs: List<&2, U32>}
  RNode{a: Rows, b: Rows}

# Helpers
# -------

def T.pick(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def T.word(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def T.not(c: Bool) -> Bool:
  match c:
    case True{}:
      False{}
    case False{}:
      True{}

def T.fmin(+a: F32, +b: F32) -> F32:
  T.pick((a < b : F32), a, b)

def T.fmax(+a: F32, +b: F32) -> F32:
  T.pick((a < b : F32), b, a)

def T.umin(+a: U32, +b: U32) -> U32:
  T.word((a < b : U32), a, b)

def T.clamp01(+x: F32) -> F32:
  T.fmin(1.0, T.fmax(0.0, x))

def T.hash(+x: U32, +y: U32, +z: U32) -> U32:
  +h0 = ((x * 73856093) .^. (y * 19349663) .^. (z * 83492791) : U32)
  +h1 = (h0 .^. (h0 >> 13n) : U32)
  +h2 = (h1 * 1540483477 : U32)
  (h2 .^. (h2 >> 15n) : U32)

def Rgb.add(a: Rgb, b: Rgb) -> Rgb:
  Rgb{ar, ag, ab} = a
  Rgb{br, bg, bb} = b
  Rgb{(ar + br : F32), (ag + bg : F32), (ab + bb : F32)}

def Rgb.pick(c: Bool, a: Rgb, b: Rgb) -> Rgb:
  match c:
    case True{}:
      a
    case False{}:
      b

def Rgb.scale(c: Rgb, +k: F32) -> Rgb:
  Rgb{r, g, b} = c
  Rgb{(r * k : F32), (g * k : F32), (b * k : F32)}

def Rgb.hex(+c: U32) -> Rgb:
  Rgb{(U32.to_f32(((c >> 16n) .&. 255 : U32)) / 255.0 : F32),
    (U32.to_f32(((c >> 8n) .&. 255 : U32)) / 255.0 : F32),
    (U32.to_f32((c .&. 255 : U32)) / 255.0 : F32)}

# Growth: stats -> garden
# -----------------------

def Grow.log2(+n: U32) -> F32:
  U32.to_f32(U32.from_nat(U32.log2((n + 1 : U32))))

def Grow.garden(+s: Stats) -> Garden:
  Stats{day, seed, total, active, last30, streak, longest, prs, stars, c1, c2, c3} = s
  +size = T.fmin(3.0, (Grow.log2(total) * 0.3 : F32))
  +cr = ((2.4 + size) * 2.0 : F32)
  +trunk = ((3.0 + size * 1.3) * 2.0 : F32)
  Garden{U32.is_ne(day, 0), seed, trunk, (28.0 + trunk + cr * 0.55 : F32),
    (cr * cr : F32), T.umin(14, longest), T.umin(130, (active * 3 / 2 : U32)),
    T.umin(90, (prs / 2 : U32)), U32.is_eq(last30, 0), c1, c2, c3}

# Camera (isometric, orthographic), moon and sun
# ----------------------------------------------

def Cam.dx() -> F32:
  (0.0 - 0.57735 : F32)

def Cam.dy() -> F32:
  (0.0 - 0.57735 : F32)

def Cam.dz() -> F32:
  (0.0 - 0.57735 : F32)

def Moon.x() -> F32:
  (0.0 - 0.48 : F32)

def Moon.y() -> F32:
  0.8

def Moon.z() -> F32:
  0.36

# Island (a 64^3 grid)
# ---------------------

def Isl.noise(+seed: U32, +x: U32, +z: U32) -> F32:
  (U32.to_f32((T.hash((x / 6 : U32), seed, (z / 6 : U32)) % 1024 : U32)) / 1024.0 : F32)

def Isl.r(+x: U32, +z: U32) -> F32:
  +fx = (U32.to_f32(x) - 31.5 : F32)
  +fz = (U32.to_f32(z) - 31.5 : F32)
  F32.sqrt((fx * fx + fz * fz : F32))

def Isl.top(+seed: U32, +x: U32, +z: U32) -> F32:
  F32.floor((28.0 - Isl.r(x, z) * 0.12 + Isl.noise(seed, x, z) * 1.8 : F32))

def Isl.rad(+seed: U32, +x: U32, +z: U32) -> F32:
  (22.0 + Isl.noise(seed, x, z) * 3.0 : F32)

def Isl.bot(+seed: U32, +x: U32, +z: U32) -> F32:
  F32.floor((28.0 - (Isl.rad(seed, x, z) - Isl.r(x, z)) * 1.0 - Isl.noise(seed, x, z) * 4.0 : F32))

def Vox.isl(+snow: Bool, +y: F32, +top: F32, +bot: F32, +r: F32, +rad: F32) -> U32:
  +inside = ((r < rad : F32) && (y <= top : F32)) && (y >= bot : F32)
  +t3 = (top - 3.0 : F32)
  T.word(inside, T.word((y >= top : F32), T.word(snow, 15, 1), T.word((y >= t3 : F32), 2, 3)), 0)

def Vox.at2(+x: U32, +z: U32, +a: U32, +b: U32) -> Bool:
  U32.is_eq(x, a) && U32.is_eq(z, b)

def T.near(+x: U32, +z: U32, +cx: U32, +cz: U32, +r2: F32) -> Bool:
  +dx = (U32.to_f32(x) - U32.to_f32(cx) : F32)
  +dz = (U32.to_f32(z) - U32.to_f32(cz) : F32)
  (dx * dx + dz * dz < r2 : F32)

# The crystal clusters of the three top languages: centers on a ring.
def Kc.x(+seed: U32, +k: U32) -> U32:
  +a = (U32.to_f32((seed % 628 : U32)) * 0.01 + U32.to_f32(k) * 2.1 : F32)
  F32.to_u32((31.5 + 14.0 * F32.cos(a) : F32))

def Kc.z(+seed: U32, +k: U32) -> U32:
  +a = (U32.to_f32((seed % 628 : U32)) * 0.01 + U32.to_f32(k) * 2.1 : F32)
  F32.to_u32((31.5 + 14.0 * F32.sin(a) : F32))

# A shard of cluster k: the center, and sparser shards around it (a bigger
# cluster for the first language).
def Kc.in(+seed: U32, +x: U32, +z: U32, +k: U32) -> Bool:
  +cx = Kc.x(seed, k)
  +cz = Kc.z(seed, k)
  +h = (T.hash(x, (seed + k : U32), z) % 16 : U32)
  T.near(x, z, cx, cz, (9.0 - U32.to_f32(k) * 2.5 : F32))
    && (Vox.at2(x, z, cx, cz) || (h < 6 : U32))

def Kc.of(+seed: U32, +x: U32, +z: U32) -> U32:
  T.word(Kc.in(seed, x, z, 0), 8, T.word(Kc.in(seed, x, z, 1), 13,
    T.word(Kc.in(seed, x, z, 2), 14, 0)))

def Tree.near(+x: U32, +z: U32) -> Bool:
  T.near(x, z, 24, 28, 20.0)

# Mushroom anchors: one candidate per 4x4 block of columns.
def Mush.ok(+g: Garden, +cx: U32, +cz: U32) -> Bool:
  Garden{day, seed, trunk, ccy, cr2, bloom, mush, flow, snow, c1, c2, c3} = g
  +ax = (cx * 4 + 1 : U32)
  +az = (cz * 4 + 1 : U32)
  +room = (Isl.r(ax, az) < (Isl.rad(seed, ax, az) - 2.5 : F32) : F32)
  +h = (T.hash(cx, (seed .^. 99 : U32), cz) % 1024 : U32)
  ((room && T.not(Tree.near(ax, az))) && U32.is_eq(Kc.of(seed, ax, az), 0))
    && (h < mush : U32)

# A mushroom: a stem two voxels tall, a 3x3 cap, a plus-shaped dome on top.
def Mush.at(+g: Garden, +x: U32, +y: F32, +z: U32) -> U32:
  Garden{day, seed, trunk, ccy, cr2, bloom, mush, flow, snow, c1, c2, c3} = g
  +cx = (x / 4 : U32)
  +cz = (z / 4 : U32)
  +ax = (cx * 4 + 1 : U32)
  +az = (cz * 4 + 1 : U32)
  +ox = ((x + 1 - ax) < 3 : U32)
  +oz = ((z + 1 - az) < 3 : U32)
  +foot = ox && oz
  +plus = (ox && U32.is_eq(z, az)) || (oz && U32.is_eq(x, ax))
  +mid = Vox.at2(x, z, ax, az)
  +h = (y - Isl.top(seed, ax, az) : F32)
  +stem = mid && ((h > 0.5 : F32) && (h < 2.5 : F32))
  +cap = (foot && F32.is_eq(h, 3.0)) || (plus && F32.is_eq(h, 4.0))
  T.word(Mush.ok(g, cx, cz) && (stem || cap), T.word(stem, 7, 6), 0)

def Vox.feat(+g: Garden, +x: U32, +y: U32, +z: U32, +fy: F32, +top: F32) -> U32:
  Garden{day, seed, trunk, ccy, cr2, bloom, mush, flow, snow, c1, c2, c3} = g
  +above = (fy > top : F32)
  +col = (Isl.r(x, z) < Isl.rad(seed, x, z) : F32)
  +tx = (U32.to_f32(x) - 24.5 : F32)
  +tz = (U32.to_f32(z) - 28.5 : F32)
  +trunkv = ((tx * tx + tz * tz : F32) < 1.0 : F32) && (fy < (28.0 + trunk : F32) : F32)
  +ly = (fy - ccy : F32)
  +ld = (tx * tx + ly * ly * 1.5 + tz * tz : F32)
  +hl = T.hash((x / 2 : U32), (y / 2 : U32), (z / 2 : U32))
  +leaf = (ld < cr2 : F32) && U32.is_ne((hl % 6 : U32), 0)
  +blossom = ((hl / 7 % 24) < bloom : U32)
  +h = (fy - top : F32)
  +on1 = F32.is_eq(h, 1.0)
  +kc = Kc.of(seed, x, z)
  +ch = (2.0 + U32.to_f32((T.hash(z, x, seed) % 5 : U32)) : F32)
  +crys = (col && U32.is_ne(kc, 0)) && (h < ch : F32)
  +hf = (T.hash(x, (seed .^. 5 : U32), z) % 1024 : U32)
  +flower = (col && on1) && (hf < flow : U32)
  +tuft = (col && on1) && (hf > 985 : U32)
  +fc = (10 + T.hash(x, seed, z) % 3 : U32)
  +mu = Mush.at(g, x, fy, z)
  T.word(above, T.word(trunkv, 4, T.word(U32.is_ne(mu, 0), mu, T.word(crys, kc,
    T.word(flower, fc, T.word(tuft, T.word(snow, 15, 16), T.word(leaf, T.word(blossom, 9, 5), 0)))))), 0)

def Vox.at(+g: Garden, +x: U32, +y: U32, +z: U32) -> U32:
  Garden{day, seed, trunk, ccy, cr2, bloom, mush, flow, snow, c1, c2, c3} = g
  +fy = U32.to_f32(y)
  +top = Isl.top(seed, x, z)
  +m = Vox.isl(snow, fy, top, Isl.bot(seed, x, z), Isl.r(x, z), Isl.rad(seed, x, z))
  T.word(U32.is_eq(m, 0), Vox.feat(g, x, y, z, fy, top), m)

def Vox.safe2(inb: Bool, +g: Garden, +x: F32, +y: F32, +z: F32) -> U32:
  match inb:
    case True{}:
      Vox.at(g, F32.to_u32(x), F32.to_u32(y), F32.to_u32(z))
    case False{}:
      255

def Vox.safe(+g: Garden, +x: F32, +y: F32, +z: F32) -> U32:
  +ix = (x >= 0.0 : F32) && (x < 64.0 : F32)
  +iy = (y >= 0.0 : F32) && (y < 64.0 : F32)
  +iz = (z >= 0.0 : F32) && (z < 64.0 : F32)
  Vox.safe2((ix && iy) && iz, g, x, y, z)

# Ray traversal (Amanatides-Woo DDA over the 64^3 grid)
# -----------------------------------------------------
# m = 255 means the ray left the grid (a miss).

def Ray.walk(
  i: Nat, stop: Bool, +g: Garden, +cx: F32, +cy: F32, +cz: F32, +tx: F32,
  +ty: F32, +tz: F32, +ax: U32, +t: F32, +m: U32, +sx: F32, +sy: F32,
  +sz: F32, +ix: F32, +iy: F32, +iz: F32
) -> Hit:
  match i:
    case 0n:
      Hit{255, ax, t}
    case 1n+k:
      match stop:
        case True{}:
          Hit{m, ax, t}
        case False{}:
          +bx = (tx < ty : F32) && (tx < tz : F32)
          +by = T.not(bx) && (ty < tz : F32)
          +bz = T.not(bx || by)
          +nx = (cx + T.pick(bx, sx, 0.0) : F32)
          +ny = (cy + T.pick(by, sy, 0.0) : F32)
          +nz = (cz + T.pick(bz, sz, 0.0) : F32)
          +nt = T.pick(bx, tx, T.pick(by, ty, tz))
          +m2 = Vox.safe(g, nx, ny, nz)
          Ray.walk(k, U32.is_ne(m2, 0), g, nx, ny, nz,
            (tx + T.pick(bx, ix, 0.0) : F32),
            (ty + T.pick(by, iy, 0.0) : F32),
            (tz + T.pick(bz, iz, 0.0) : F32),
            T.word(bx, 0, T.word(by, 1, 2)), nt, m2, sx, sy, sz, ix, iy, iz)

def Ray.cell(+o: F32, +d: F32, +te: F32) -> F32:
  T.fmin(63.0, T.fmax(0.0, F32.floor((o + d * te : F32))))

def Ray.sign(+d: F32) -> F32:
  T.pick((d > 0.0 : F32), 1.0, (0.0 - 1.0 : F32))

def Ray.next(+c: F32, +o: F32, +d: F32, +inv: F32) -> F32:
  ((c + T.pick((d > 0.0 : F32), 1.0, 0.0) - o) * inv : F32)

def Ray.start(
  ok: Bool, +g: Garden, +ox: F32, +oy: F32, +oz: F32, +dx: F32, +dy: F32,
  +dz: F32, +ix: F32, +iy: F32, +iz: F32, +t0: F32, +ax: U32
) -> Hit:
  match ok:
    case False{}:
      Hit{255, 0, 0.0}
    case True{}:
      +te = (t0 + 0.0001 : F32)
      +cx = Ray.cell(ox, dx, te)
      +cy = Ray.cell(oy, dy, te)
      +cz = Ray.cell(oz, dz, te)
      +m0 = Vox.safe(g, cx, cy, cz)
      Ray.walk(200n, U32.is_ne(m0, 0), g, cx, cy, cz, Ray.next(cx, ox, dx, ix),
        Ray.next(cy, oy, dy, iy), Ray.next(cz, oz, dz, iz), ax, t0, m0,
        Ray.sign(dx), Ray.sign(dy), Ray.sign(dz), F32.abs(ix), F32.abs(iy),
        F32.abs(iz))

def Ray.cast(
  +g: Garden, +ox: F32, +oy: F32, +oz: F32, +dx: F32, +dy: F32, +dz: F32
) -> Hit:
  +ix = (1.0 / dx : F32)
  +iy = (1.0 / dy : F32)
  +iz = (1.0 / dz : F32)
  +ax0 = ((0.0 - ox) * ix : F32)
  +bx0 = ((64.0 - ox) * ix : F32)
  +ay0 = ((0.0 - oy) * iy : F32)
  +by0 = ((64.0 - oy) * iy : F32)
  +az0 = ((0.0 - oz) * iz : F32)
  +bz0 = ((64.0 - oz) * iz : F32)
  +lox = T.fmin(ax0, bx0)
  +loy = T.fmin(ay0, by0)
  +loz = T.fmin(az0, bz0)
  +t0 = T.fmax(T.fmax(lox, loy), T.fmax(loz, 0.0))
  +t1 = T.fmin(T.fmax(ax0, bx0), T.fmin(T.fmax(ay0, by0), T.fmax(az0, bz0)))
  +ax = T.word((lox >= loy : F32) && (lox >= loz : F32), 0, T.word((loy >= loz : F32), 1, 2))
  Ray.start((t0 < t1 : F32), g, ox, oy, oz, dx, dy, dz, ix, iy, iz, t0, ax)

# Materials
# ---------

def Mat.alb(m: U32) -> Rgb:
  match m:
    case 1:
      Rgb{0.24, 0.56, 0.30}
    case 2:
      Rgb{0.42, 0.28, 0.18}
    case 3:
      Rgb{0.32, 0.32, 0.38}
    case 4:
      Rgb{0.38, 0.24, 0.14}
    case 5:
      Rgb{0.10, 0.36, 0.30}
    case 7:
      Rgb{0.85, 0.80, 0.72}
    case 9:
      Rgb{0.95, 0.48, 0.70}
    case 10:
      Rgb{0.98, 0.85, 0.30}
    case 11:
      Rgb{0.95, 0.95, 0.95}
    case 12:
      Rgb{0.70, 0.50, 0.95}
    case 15:
      Rgb{0.92, 0.95, 1.0}
    case 16:
      Rgb{0.18, 0.46, 0.24}
    case _:
      Rgb{0.9, 0.9, 0.9}

def Mat.albg(+g: Garden, +m: U32) -> Rgb:
  Garden{day, seed, trunk, ccy, cr2, bloom, mush, flow, snow, c1, c2, c3} = g
  +cr = (U32.is_eq(m, 8) || U32.is_eq(m, 13)) || U32.is_eq(m, 14)
  Rgb.pick(cr, Rgb.hex(T.word(U32.is_eq(m, 8), c1, T.word(U32.is_eq(m, 13), c2, c3))), Mat.alb(m))

def Mat.glow(+g: Garden, +m: U32) -> Rgb:
  Garden{day, seed, trunk, ccy, cr2, bloom, mush, flow, snow, c1, c2, c3} = g
  +cry = Rgb.scale(Rgb.hex(T.word(U32.is_eq(m, 8), c1, T.word(U32.is_eq(m, 13), c2, c3))), 0.75)
  +cr = (U32.is_eq(m, 8) || U32.is_eq(m, 13)) || U32.is_eq(m, 14)
  +e = Rgb.pick(cr, cry, Rgb.pick(U32.is_eq(m, 6), Rgb{1.8, 0.45, 1.0}, Rgb{0.0, 0.0, 0.0}))
  Rgb.scale(e, T.pick(day, 0.35, 1.0))

# Lights: every mushroom cap and crystal, plus a firefly per streak day
# ---------------------------------------------------------------------

def Lights.put(lit: Bool, l: Lt, acc: List<&2, Lt>) -> List<&2, Lt>:
  match lit:
    case False{}:
      acc
    case True{}:
      l <> acc

def Mush.cx(+k: Nat) -> U32:
  (U32.from_nat(k) % 16 : U32)

def Mush.cz(+k: Nat) -> U32:
  (U32.from_nat(k) / 16 : U32)

# The light above the mushroom anchored at block k.
def Mush.light(+g: Garden, +k: Nat) -> Lt:
  Garden{day, seed, trunk, ccy, cr2, bloom, mush, flow, snow, c1, c2, c3} = g
  +ax = (Mush.cx(k) * 4 + 1 : U32)
  +az = (Mush.cz(k) * 4 + 1 : U32)
  Lt{(U32.to_f32(ax) + 0.5 : F32), (Isl.top(seed, ax, az) + 5.5 : F32),
    (U32.to_f32(az) + 0.5 : F32), 1.0, 0.25, 0.6}

# A light for every mushroom among the first i anchors.
def Lights.scan(+i: Nat, +g: Garden) -> List<&2, Lt>:
  match i:
    case 0n:
      []
    case 1n+k:
      Lights.put(Mush.ok(g, Mush.cx(k), Mush.cz(k)), Mush.light(g, k), Lights.scan(k, g))

def Mush.add(b: Bool, n: Nat) -> Nat:
  match b:
    case True{}:
      1n+n
    case False{}:
      n

# How many mushrooms grow among the first i anchors.
def Mush.count(+i: Nat, +g: Garden) -> Nat:
  match i:
    case 0n:
      0n
    case 1n+k:
      Mush.add(Mush.ok(g, Mush.cx(k), Mush.cz(k)), Mush.count(k, g))

def Lights.at(c: Rgb, +x: F32, +y: F32, +z: F32) -> Lt:
  Rgb{r, g, b} = c
  Lt{x, y, z, r, g, b}

def Lights.kc(+seed: U32, +k: U32, +c: U32, acc: List<&2, Lt>) -> List<&2, Lt>:
  +x = Kc.x(seed, k)
  +z = Kc.z(seed, k)
  Lights.at(Rgb.scale(Rgb.hex(c), 1.6), (U32.to_f32(x) + 0.5 : F32),
    (Isl.top(seed, x, z) + 7.0 : F32), (U32.to_f32(z) + 0.5 : F32)) <> acc

# One firefly per light: n of them, scattered by the seed.
def Lights.flies(+n: Nat, +seed: U32) -> List<&2, Lt>:
  match n:
    case 0n:
      []
    case 1n+k:
      +h = T.hash(U32.from_nat(k), seed, 4242)
      +x = (10.0 + U32.to_f32((h % 44 : U32)) : F32)
      +z = (10.0 + U32.to_f32((h / 44 % 44 : U32)) : F32)
      +y = (32.0 + U32.to_f32((h / 1936 % 200 : U32)) * 0.1 : F32)
      Lt{x, y, z, 1.0, 0.85, 0.35} <> Lights.flies(k, seed)

# Fireflies come out at night, one per day of the current streak (up to 16).
def Lights.nflies(day: Bool, +streak: U32) -> Nat:
  match day:
    case True{}:
      0n
    case False{}:
      U32.to_nat(T.umin(16, streak))

def Lights.all(+g: Garden, +streak: U32) -> List<&2, Lt>:
  Garden{day, seed, trunk, ccy, cr2, bloom, mush, flow, snow, c1, c2, c3} = g
  List.append(&2, Lt, Lights.scan(256n, g), Lights.kc(seed, 0, c1, Lights.kc(seed, 1, c2,
    Lights.kc(seed, 2, c3, Lights.flies(Lights.nflies(day, streak), seed)))))

def Light.one(
  l: Lt, +px: F32, +py: F32, +pz: F32, +nx: F32, +ny: F32, +nz: F32
) -> Rgb:
  Lt{lx, ly, lz, lr, lg, lb} = l
  +vx = (lx - px : F32)
  +vy = (ly - py : F32)
  +vz = (lz - pz : F32)
  +d2 = (vx * vx + vy * vy + vz * vz : F32)
  +ndl = T.fmax(0.0, ((nx * vx + ny * vy + nz * vz) / F32.sqrt(d2) : F32))
  +f = (ndl * 2.2 / (1.0 + d2 * 0.22) : F32)
  Rgb{(lr * f : F32), (lg * f : F32), (lb * f : F32)}

def Light.sum(
  ls: List<&2, Lt>, +px: F32, +py: F32, +pz: F32, +nx: F32, +ny: F32, +nz: F32,
  acc: Rgb
) -> Rgb:
  match ls:
    case []:
      acc
    case l <> rest:
      Light.sum(rest, px, py, pz, nx, ny, nz,
        Rgb.add(acc, Light.one(l, px, py, pz, nx, ny, nz)))

def Glow.one(l: Lt, +ox: F32, +oy: F32, +oz: F32, +tmax: F32) -> Rgb:
  Lt{lx, ly, lz, lr, lg, lb} = l
  +qx = (lx - ox : F32)
  +qy = (ly - oy : F32)
  +qz = (lz - oz : F32)
  +tp = (qx * Cam.dx() + qy * Cam.dy() + qz * Cam.dz() : F32)
  +d2 = T.fmax(0.0, (qx * qx + qy * qy + qz * qz - tp * tp : F32))
  +core = (0.9 * F32.exp((0.0 - d2 * 17.0 : F32)) : F32)
  +halo = (0.16 * F32.exp((0.0 - d2 * 0.6 : F32)) : F32)
  +f = T.pick((tp < tmax : F32), (core + halo : F32), 0.0)
  Rgb{(lr * f : F32), (lg * f : F32), (lb * f : F32)}

# The glow of each light seen along the view ray, if it sits before the hit.
def Glow.sum(ls: List<&2, Lt>, +ox: F32, +oy: F32, +oz: F32, +tmax: F32, acc: Rgb) -> Rgb:
  match ls:
    case []:
      acc
    case l <> rest:
      Glow.sum(rest, ox, oy, oz, tmax, Rgb.add(acc, Glow.one(l, ox, oy, oz, tmax)))

# Shading
# -------

def Vox.solid(+g: Garden, +x: F32, +y: F32, +z: F32) -> F32:
  +m = Vox.safe(g, x, y, z)
  T.pick(U32.is_ne(m, 0) && U32.is_ne(m, 255), 1.0, 0.0)

def Ao.s(
  +g: Garden, +cx: F32, +cy: F32, +cz: F32, +ux: F32, +uy: F32, +vy: F32,
  +vz: F32, +du: F32, +dv: F32
) -> F32:
  Vox.solid(g, (cx + du * ux : F32), (cy + du * uy + dv * vy : F32), (cz + dv * vz : F32))

def Ao.at(
  +g: Garden, +px: F32, +py: F32, +pz: F32, +nx: F32, +ny: F32, +nz: F32,
  +ax: U32
) -> F32:
  +cx = F32.floor((px + nx * 0.5 : F32))
  +cy = F32.floor((py + ny * 0.5 : F32))
  +cz = F32.floor((pz + nz * 0.5 : F32))
  +ux = T.pick(U32.is_eq(ax, 0), 0.0, 1.0)
  +uy = T.pick(U32.is_eq(ax, 0), 1.0, 0.0)
  +vy = T.pick(U32.is_eq(ax, 2), 1.0, 0.0)
  +vz = T.pick(U32.is_eq(ax, 2), 0.0, 1.0)
  +pu = (px * ux + py * uy : F32)
  +pv = (py * vy + pz * vz : F32)
  +u = (pu - F32.floor(pu) : F32)
  +v = (pv - F32.floor(pv) : F32)
  +iu = (1.0 - u : F32)
  +iv = (1.0 - v : F32)
  +m1 = (0.0 - 1.0 : F32)
  +o = (Ao.s(g, cx, cy, cz, ux, uy, vy, vz, m1, 0.0) * iu * iu
    + Ao.s(g, cx, cy, cz, ux, uy, vy, vz, 1.0, 0.0) * u * u
    + Ao.s(g, cx, cy, cz, ux, uy, vy, vz, 0.0, m1) * iv * iv
    + Ao.s(g, cx, cy, cz, ux, uy, vy, vz, 0.0, 1.0) * v * v
    + Ao.s(g, cx, cy, cz, ux, uy, vy, vz, m1, m1) * iu * iu * iv * iv
    + Ao.s(g, cx, cy, cz, ux, uy, vy, vz, 1.0, m1) * u * u * iv * iv
    + Ao.s(g, cx, cy, cz, ux, uy, vy, vz, m1, 1.0) * iu * iu * v * v
    + Ao.s(g, cx, cy, cz, ux, uy, vy, vz, 1.0, 1.0) * u * u * v * v : F32)
  (1.0 - 0.6 * T.clamp01(o) : F32)

def Shd.jit(+px: F32, +py: F32, +pz: F32, +nx: F32, +ny: F32, +nz: F32) -> F32:
  +h = T.hash(F32.to_u32(F32.floor((px - nx * 0.5 : F32))),
    F32.to_u32(F32.floor((py - ny * 0.5 : F32))),
    F32.to_u32(F32.floor((pz - nz * 0.5 : F32))))
  (0.84 + U32.to_f32((h % 64 : U32)) * 0.0040 : F32)

def Shd.mix(+k: F32, l: Rgb, a: Rgb, e: Rgb) -> Rgb:
  Rgb{lr, lg, lb} = l
  Rgb{ar, ag, ab} = a
  Rgb{er, eg, eb} = e
  Rgb{(ar * lr * k + er : F32), (ag * lg * k + eg : F32), (ab * lb * k + eb : F32)}

def Shd.lit(h: Hit) -> F32:
  Hit{m, ax, t} = h
  T.pick(U32.is_eq(m, 255), 1.0, 0.0)

# The light that reaches a surface before the island's emitters: the moon at
# night, the sun and a bright sky by day.
def Shd.base(+day: Bool, +sh: F32, +ndl: F32, +ny: F32) -> Rgb:
  +s = (ndl * sh : F32)
  +na = (0.03 + 0.03 * ny : F32)
  +da = (0.22 + 0.22 * ny : F32)
  Rgb.pick(day,
    Rgb{(da * 0.55 + 1.85 * s : F32), (da * 0.75 + 1.55 * s : F32), (da * 1.15 + 1.05 * s : F32)},
    Rgb{(na + 0.14 * s : F32), (na * 1.1 + 0.19 * s : F32), (na * 1.6 + 0.34 * s : F32)})

def Shd.surf(
  miss: Bool, +g: Garden, +ls: List<&2, Lt>, +m: U32, +ax: U32, +t: F32,
  +ox: F32, +oy: F32, +oz: F32
) -> Rgb:
  match miss:
    case True{}:
      Rgb{0.0, 0.0, 0.0}
    case False{}:
      Garden{day, seed, trunk, ccy, cr2, bloom, mush, flow, snow, c1, c2, c3} = g
      +px = (ox + Cam.dx() * t : F32)
      +py = (oy + Cam.dy() * t : F32)
      +pz = (oz + Cam.dz() * t : F32)
      +nx = T.pick(U32.is_eq(ax, 0), 1.0, 0.0)
      +ny = T.pick(U32.is_eq(ax, 1), 1.0, 0.0)
      +nz = T.pick(U32.is_eq(ax, 2), 1.0, 0.0)
      +sh = Shd.lit(Ray.cast(g, (px + nx * 0.01 : F32), (py + ny * 0.01 : F32),
        (pz + nz * 0.01 : F32), Moon.x(), Moon.y(), Moon.z()))
      +ndl = T.fmax(0.0, (nx * Moon.x() + ny * Moon.y() + nz * Moon.z() : F32))
      +k = (Ao.at(g, px, py, pz, nx, ny, nz, ax) * Shd.jit(px, py, pz, nx, ny, nz) : F32)
      Shd.mix(k, Light.sum(ls, px, py, pz, nx, ny, nz, Shd.base(day, sh, ndl, ny)),
        Mat.albg(g, m), Mat.glow(g, m))

# The sky: black with a star per GitHub star at night; a soft gradient by day.
def Sky.star(+fx: F32, +fy: F32, +seed: U32, +stars: U32) -> F32:
  +cx = F32.floor((fx / 40.0 : F32))
  +cy = F32.floor((fy / 40.0 : F32))
  +h = T.hash(F32.to_u32(cx), F32.to_u32(cy), (seed .^. 777 : U32))
  +on = ((h % 1566 : U32) < stars : U32)
  +sx = (cx * 40.0 + 5.0 + U32.to_f32((h / 1566 % 30 : U32)) : F32)
  +sy = (cy * 40.0 + 5.0 + U32.to_f32((h / 46980 % 30 : U32)) : F32)
  +d2 = ((fx - sx) * (fx - sx) + (fy - sy) * (fy - sy) : F32)
  +b = (0.35 + U32.to_f32((h / 1409400 % 64 : U32)) * 0.012 : F32)
  T.pick(on, (b * F32.exp((0.0 - d2 * 0.6 : F32)) : F32), 0.0)

def Sky.at(+g: Garden, +stars: U32, +fx: F32, +fy: F32) -> Rgb:
  Garden{day, seed, trunk, ccy, cr2, bloom, mush, flow, snow, c1, c2, c3} = g
  +v = T.clamp01((fy / 2340.0 : F32))
  +s = Sky.star(fx, fy, seed, stars)
  Rgb.pick(day,
    Rgb{(0.10 + 0.95 * v * v : F32), (0.30 + 0.50 * v * v : F32), (0.80 - 0.15 * v * v : F32)},
    Rgb{(s * 0.9 : F32), (s * 0.95 : F32), s})

def Shd.hit(
  h: Hit, +g: Garden, +ls: List<&2, Lt>, +stars: U32, +fx: F32, +fy: F32,
  +ox: F32, +oy: F32, +oz: F32
) -> Rgb:
  Hit{+m, +ax, +t} = h
  Garden{day, seed, trunk, ccy, cr2, bloom, mush, flow, snow, c1, c2, c3} = g
  +miss = U32.is_eq(m, 255)
  +tmax = T.pick(miss, 100000.0, t)
  +glow = Rgb.pick(day, Rgb{0.0, 0.0, 0.0}, Glow.sum(ls, ox, oy, oz, tmax, Rgb{0.0, 0.0, 0.0}))
  +back = Rgb.pick(miss, Sky.at(g, stars, fx, fy), Rgb{0.0, 0.0, 0.0})
  Rgb.add(Rgb.add(Shd.surf(miss, g, ls, m, ax, t, ox, oy, oz), glow), back)

# Pixels
# ------
# Screen 1080 x 2340; 34 world units across; the island sits at 59% height.

def Px.color(+g: Garden, +ls: List<&2, Lt>, +stars: U32, +fx: F32, +fy: F32) -> Rgb:
  +sx = ((fx - 540.0) * 0.063 : F32)
  +sy = ((1380.0 - fy) * 0.063 : F32)
  +ox = (107.06 + sx * 0.70711 - sy * 0.40825 : F32)
  +oy = (101.06 + sy * 0.8165 : F32)
  +oz = (107.06 - sx * 0.70711 - sy * 0.40825 : F32)
  Shd.hit(Ray.cast(g, ox, oy, oz, Cam.dx(), Cam.dy(), Cam.dz()), g, ls, stars,
    fx, fy, ox, oy, oz)

def Rgb.quarter(c: Rgb) -> Rgb:
  Rgb.scale(c, 0.25)

# 2x2 supersampling
def Px.aa(+g: Garden, +ls: List<&2, Lt>, +stars: U32, +x: U32, +y: U32) -> Rgb:
  +fx = U32.to_f32(x)
  +fy = U32.to_f32(y)
  +a = Px.color(g, ls, stars, (fx + 0.25 : F32), (fy + 0.25 : F32))
  +b = Px.color(g, ls, stars, (fx + 0.75 : F32), (fy + 0.25 : F32))
  +c = Px.color(g, ls, stars, (fx + 0.25 : F32), (fy + 0.75 : F32))
  +d = Px.color(g, ls, stars, (fx + 0.75 : F32), (fy + 0.75 : F32))
  Rgb.quarter(Rgb.add(Rgb.add(a, b), Rgb.add(c, d)))

def Tone.ch(+c: F32) -> U32:
  +v = T.fmax(0.0, (c - 0.003 : F32))
  +e = T.clamp01((1.0 - F32.exp((0.0 - v * 1.5 : F32)) : F32))
  F32.to_u32((255.0 * F32.pow(e, 0.4545) + 0.5 : F32))

def Tone.push(c: Rgb, acc: List<&2, U32>) -> List<&2, U32>:
  Rgb{r, g, b} = c
  Tone.ch(r) <> Tone.ch(g) <> Tone.ch(b) <> acc

def Row.go(
  +n: Nat, +g: Garden, +ls: List<&2, Lt>, +stars: U32, +y: U32,
  acc: List<&2, U32>
) -> List<&2, U32>:
  match n:
    case 0n:
      acc
    case 1n+k:
      Row.go(k, g, ls, stars, y, Tone.push(Px.aa(g, ls, stars, U32.from_nat(k), y), acc))

def Rows.leaf(ok: Bool, +g: Garden, +ls: List<&2, Lt>, +stars: U32, +y: U32) -> Rows:
  match ok:
    case True{}:
      RLeaf{Row.go(1080n, g, ls, stars, y, [])}
    case False{}:
      RLeaf{[]}

def Rows.go(+d: Nat, +g: Garden, +ls: List<&2, Lt>, +stars: U32, +y: U32) -> Rows:
  match d:
    case 0n:
      Rows.leaf((y < 2340 : U32), g, ls, stars, y)
    case 1n+e:
      +h = U32.shln(1, e)
      a b = Rows.go(e, g, ls, stars, y) Rows.go(e, g, ls, stars, (y + h : U32))
      RNode{a, b}

def Render.go(+s: Stats) -> Rows:
  Stats{day, seed, total, active, last30, streak, longest, prs, stars, c1, c2, c3} = s
  +g = Grow.garden(s)
  Rows.go(12n, g, Lights.all(g, streak), stars, 0)

# Input and output
# ----------------

def Args.nums(xs: List<String>) -> List<&2, U32>:
  match xs:
    case []:
      []
    case h <> t:
      Maybe.default(&2, U32, U32.read(h), 0) <> Args.nums(t)

def Args.at(+ns: List<&2, U32>, n: Nat) -> U32:
  Maybe.default(&2, U32, List.get(&2, U32, ns, n), 0)

def Args.stats(+ns: List<&2, U32>) -> Stats:
  Stats{Args.at(ns, 1n), Args.at(ns, 2n), Args.at(ns, 3n), Args.at(ns, 4n),
    Args.at(ns, 5n), Args.at(ns, 6n), Args.at(ns, 7n), Args.at(ns, 8n),
    Args.at(ns, 9n), Args.at(ns, 10n), Args.at(ns, 11n), Args.at(ns, 12n)}

def Out.pick(night: Bool) -> String:
  match night:
    case True{}:
      "night.ppm"
    case False{}:
      "day.ppm"

def Out.name(+s: Stats) -> String:
  Stats{day, seed, total, active, last30, streak, longest, prs, stars, c1, c2, c3} = s
  Out.pick(U32.is_eq(day, 0))

def Out.fst(p: File & Result<&1, &1, U32 & String, Unit>) -> File:
  (f, r) = p
  f

def Out.go(r: Rows, f: File) -> IO(File):
  match r:
    case RLeaf{bs}:
      do IO<File>:
        p : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(f, bs)
        return Out.fst(p)
    case RNode{a, b}:
      do IO<File>:
        f2 : File <- Out.go(a, f)
        Out.go(b, f2)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +s : Stats = Args.stats(Args.nums(args))
    f : File <- IO.try(File, File.open(Out.name(s), "w"))
    p : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, "P6\n1080 2340\n255\n")
    rows : Rows = Render.go(s)
    f3 : File <- Out.go(rows, Out.fst(p))
    File.close(f3)

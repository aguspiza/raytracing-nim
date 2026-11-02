# Ray tracing in a weekend, laid out as raytracing-goose.
# Renders the random sphere scene to ray.tga (and ray.ppm with "ppm").
#
#   nim c -o:ray main.nim      (flags in config.nims)
#   ./ray [samples] [ppm] [--threads n]
#
# The math, the random numbers and the scene are those of raytracing-bend2
# and raytracing-goose, operation by operation and all in float32, so all
# three write the same image. The hit test reads the spheres as four flat
# float32 arrays in a branch-free pass the C compiler vectorizes, and worker
# threads take rows from a shared counter and send each one back on a channel.

import std/[math, os, strutils, times, atomics, typedthreads, cpuinfo]
import image

# No fused multiply-add: gcc would fuse other pairs than in the Goose C,
# and the image would differ from Bend's and Goose's in a few low bits.
{.passC: "-ffp-contract=off".}

const
  W = 1200
  H = 600
  Far = 1000000000f32
  TMin = 0.01f32
  MaxSpheres = 512

type
  Vec3 = object
    x, y, z: float32
  Ray = object
    a, b: Vec3
  MatKind = enum Lambertian, Metalic, Dielectric
  Mat = object
    kind: MatKind
    albedo: Vec3
    param: float32 # fuzzy or refraction
  Cam = object
    origin, corner, hor, vert, u, v: Vec3
    lens: float32

# Vec
# ---

func vec(x, y, z: float32): Vec3 {.inline.} = Vec3(x: x, y: y, z: z)
func `+`(a, b: Vec3): Vec3 {.inline.} = vec(a.x + b.x, a.y + b.y, a.z + b.z)
func `-`(a, b: Vec3): Vec3 {.inline.} = vec(a.x - b.x, a.y - b.y, a.z - b.z)
func `*`(a, b: Vec3): Vec3 {.inline.} = vec(a.x * b.x, a.y * b.y, a.z * b.z)
func `*`(v: Vec3, k: float32): Vec3 {.inline.} = vec(v.x * k, v.y * k, v.z * k)
func `/`(v: Vec3, k: float32): Vec3 {.inline.} = vec(v.x / k, v.y / k, v.z / k)
func neg(v: Vec3): Vec3 {.inline.} = vec(0f - v.x, 0f - v.y, 0f - v.z)
func dot(a, b: Vec3): float32 {.inline.} = a.x * b.x + a.y * b.y + a.z * b.z
func cross(a, b: Vec3): Vec3 {.inline.} =
  vec(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
func len(v: Vec3): float32 {.inline.} = sqrt(dot(v, v))
func unitOf(v: Vec3): Vec3 {.inline.} = v * (1f / (len(v) + 0.0001f))
func reflect(v, n: Vec3): Vec3 {.inline.} = v - n * (dot(v, n) * 2f)

const zero = Vec3()
const one = Vec3(x: 1f, y: 1f, z: 1f)

# Random
# ------
# As in the Bend port: a xorshift32 state, and each pixel seeds its own
# from its index. A state is fresh until read: u reads it, next steps past it.

func rngHash(x: uint32): uint32 =
  let a = (x xor (x shr 16)) * 2146121005'u32
  let b = (a xor (a shr 15)) * 2221713035'u32
  b xor (b shr 16)

func next(s: uint32): uint32 {.inline.} =
  result = s xor (s shl 13)
  result = result xor (result shr 17)
  result = result xor (result shl 5)

func next2(s: uint32): uint32 {.inline.} = next(next(s))
func next3(s: uint32): uint32 {.inline.} = next(next(next(s)))

# rand(1f): the float in [0, 1) of a state
func u(s: uint32): float32 {.inline.} = float32(s shr 8) / 16777216f32
func at(h, j: uint32): float32 = u(rngHash(h + j))

# the point in [-1, 1]^3 drawn from s, next(s) and next2(s)
func vec3Of(s: uint32): Vec3 {.inline.} =
  let s1 = next(s)
  vec(2f * u(s) - 1f, 2f * u(s1) - 1f, 2f * u(next(s1)) - 1f)

func vec2Of(s: uint32): Vec3 {.inline.} = vec(2f * u(s) - 1f, 2f * u(next(s)) - 1f, 0f)

# randInSphere and randInDisk: the state whose point is accepted. As in the
# old v3.nim, a point is accepted when it lies outside the unit ball, and
# the search gives up after 64 redraws.
func inSphere(s: uint32): uint32 =
  result = s
  for _ in 0 ..< 64:
    let p = vec3Of(result)
    if dot(p, p) >= 1f: return
    result = next3(result)

func inDisk(s: uint32): uint32 =
  result = s
  for _ in 0 ..< 64:
    let p = vec2Of(result)
    if dot(p, p) >= 1f: return
    result = next2(result)

# Camera
# ------

func newCam(lookFrom, lookAt: Vec3): Cam =
  let vup = vec(0f, 1f, 0f)
  let dist = lookFrom - lookAt
  let w = unitOf(dist)
  let u = unitOf(cross(vup, w))
  let v = cross(w, u)
  let fd = len(dist)
  let pi = 3.14159265f32
  let hh = tan(20f * pi / 180f / 2f)
  let hw = 2f * hh
  # v points up; rows go top to bottom, so the corner is the top left
  # and the vertical span points down
  let corner = lookFrom - u * (hw * fd) + v * (hh * fd) - w * fd
  let lens = 0.005f32
  Cam(origin: lookFrom, corner: corner, hor: u * (hw * fd * 2f),
      vert: v * (0f - hh * fd * 2f), u: u, v: v, lens: lens / 2f)

# d: the randInDisk() point for the lens
func camRay(c: Cam, pu, pv: float32, d: Vec3): Ray {.inline.} =
  let offset = c.u * (d.x * c.lens) + c.v * (d.y * c.lens)
  let uh = c.hor * pu
  let vv = c.vert * pv - c.origin - offset
  Ray(a: c.origin - offset, b: c.corner + (uh + vv))

# Scene
# -----
# Plain arrays, no GC'ed memory: every thread reads them without locks.

var
  n = 0
  ox, oy, oz, rr, rad: array[MaxSpheres, float32] # the hot loop reads ox..rr
  mats: array[MaxSpheres, Mat]

proc add(o: Vec3, r: float32, m: Mat) =
  ox[n] = o.x; oy[n] = o.y; oz[n] = o.z
  rr[n] = r * r; rad[n] = r; mats[n] = m
  inc n

# a cell's material from its random numbers h + 3, h + 4, ..
func pickMat(mp: float32, h: uint32): Mat =
  if mp < 0.8f:
    Mat(kind: Lambertian, albedo: vec(at(h, 3) * at(h, 4), at(h, 5) * at(h, 6), at(h, 7) * at(h, 8)))
  elif mp < 0.95f:
    Mat(kind: Metalic, albedo: vec(0.5f * (at(h, 3) + 1f), 0.5f * (at(h, 4) + 1f),
        0.5f * (at(h, 5) + 1f)), param: 0.01f)
  else:
    Mat(kind: Dielectric, param: 1.5f)

# The Bend scene is a list built by prepending: the ground, the kept cells
# from the last to the first, then the three big spheres. Same order here,
# so a tie between two spheres goes the same way.
proc buildScene() =
  add(vec(0f, -1000f, 0f), 1000f, Mat(kind: Lambertian, albedo: vec(0.5f, 0.5f, 0.5f)))
  let tilt = 0.2f32
  # an int counter: countdown on uint32 never stops at 0
  for c in countdown(483, 0):
    let k = uint32(c)
    # the 22 x 22 grid, cell k at (k div 22 - 11, k mod 22 - 11)
    let h = k * 16 + 1000
    let mp = at(h, 0)
    let cx = float32(k div 22) - 11f + 0.9f + at(h, 1)
    let cz = float32(k mod 22) - 11f + 0.9f + at(h, 2)
    let c = vec(cx, 0.2f, cz)
    if len(c - vec(4f, 0.2f, 0f)) > 0.9f:
      let cy = 0.2f - tilt / 45f * len(c)
      add(vec(cx, cy, cz), 0.2f, pickMat(mp, h))
  add(vec(0f, 1f, 0f), 1f, Mat(kind: Dielectric, param: 1.5f))
  add(vec(-4f, 1f, 0f), 1f, Mat(kind: Lambertian, albedo: vec(0.4f, 0.2f, 0.1f)))
  add(vec(4f, 1f, 0f), 1f, Mat(kind: Metalic, albedo: vec(0.7f, 0.6f, 0.5f), param: 0.01f))

# Hits
# ----

# The nearest sphere in (0.01, Far): its index (-1 on a miss) and t.
# Same arithmetic as Sphere.hit in Bend, in two passes. The first has no
# branches, so the C compiler vectorizes it: qb and disc for every sphere.
# The second only takes the sqrt of the few with disc > 0.
proc hit(r: Ray): tuple[i: int, t: float32] =
  var qbs {.noinit.}, discs {.noinit.}: array[MaxSpheres, float32]
  let a = r.a
  let b = r.b
  let qa = dot(b, b)
  for i in 0 ..< n:
    let cx = a.x - ox[i]
    let cy = a.y - oy[i]
    let cz = a.z - oz[i]
    let qb = cx * b.x + cy * b.y + cz * b.z
    let qc = cx * cx + cy * cy + cz * cz - rr[i]
    qbs[i] = qb
    discs[i] = qb * qb - qa * qc
  result = (-1, Far)
  for i in 0 ..< n:
    let disc = discs[i]
    if disc > 0f:
      let qb = qbs[i]
      let sq = sqrt(disc)
      let tm = (0f - qb - sq) / qa
      if tm > TMin and tm < result.t:
        result = (i, tm)
      else:
        let tp = (0f - qb + sq) / qa
        if tp > TMin and tp < result.t:
          result = (i, tp)

# Color
# -----

func sky(d: Vec3): Vec3 =
  let t = 0.5f * (unitOf(d).y + 1f)
  one * (1f - t) + vec(0.5f, 0.7f, 1f) * t

func schlick(cosine, ri: float32): float32 =
  let r0 = (1f - ri) / (1f + ri)
  let r = r0 * r0
  r + (1f - r) * pow(1f - cosine, 5f32)

# Up to 49 bounces, then a last hit test, whose hit is black.
# Returns the color and the generator state after it.
proc color(r0: Ray, s0: uint32): (Vec3, uint32) =
  var ray = r0
  var acc = one
  var s = s0
  for _ in 0 ..< 49:
    let (i, t) = hit(ray)
    if i < 0: return (acc * sky(ray.b), s)
    let b = ray.b
    let p = ray.a + b * t
    let nrm = (p - vec(ox[i], oy[i], oz[i])) / rad[i]
    let m = mats[i]
    case m.kind
    of Lambertian:
      let c = inSphere(s)
      let target = p + nrm + vec3Of(c)
      ray = Ray(a: p, b: target - p)
      acc = acc * m.albedo
      s = next3(c)
    of Metalic:
      let c = inSphere(s)
      let d = reflect(unitOf(b), nrm) + vec3Of(c) * m.param
      s = next3(c)
      if dot(d, nrm) <= 0f: return (zero, s)
      ray = Ray(a: p, b: d)
      acc = acc * m.albedo
    of Dielectric:
      let refraction = m.param
      let bn = dot(b, nrm)
      let inside = bn > 0f
      let outN = if inside: neg(nrm) else: nrm
      let ni = if inside: refraction else: 1f / refraction
      let cos0 = 0f - bn / len(b)
      let cosine = if inside: 0f - cos0 * refraction else: cos0
      let nv = unitOf(b)
      let dt = dot(nv, outN)
      let disc = 1f - ni * ni * (1f - dt * dt)
      let through = disc > 0f and u(s) > schlick(cosine, refraction)
      let d = if through: (nv - outN * dt) * ni - outN * sqrt(disc)
              else: reflect(b, nrm)
      ray = Ray(a: p, b: d)
      s = next(s)
  let (i, _) = hit(ray)
  if i < 0: return (acc * sky(ray.b), s)
  (zero, s)

func toByte(x: float32): uint8 = uint8(uint32(255.99f * sqrt(x)) and 255)

# Render
# ------

let cam = newCam(vec(-1f, 1f, 18f), vec(0f, 1f, -1f))

proc renderRow(y, ns: int): seq[Rgb] =
  result = newSeq[Rgb](W)
  for x in 0 ..< W:
    var s = rngHash(uint32(y * W + x + 1))
    var sum = zero
    for _ in 0 ..< ns:
      let d = inDisk(next2(s))
      let r = camRay(cam, (float32(x) + u(s)) / float32(W),
                     (float32(y) + u(next(s))) / float32(H), vec2Of(d))
      let (col, s2) = color(r, next2(d))
      sum = sum + col
      s = s2
    let m = sum / float32(ns)
    result[x] = (r: toByte(m.x), g: toByte(m.y), b: toByte(m.z))

var nextRow: Atomic[int]           # the next row to take
var done: Channel[(int, seq[Rgb])] # finished rows, sent back to main

proc worker(ns: int) {.thread.} =
  while true:
    let y = nextRow.fetchAdd(1)
    if y >= H: break
    done.send((y, renderRow(y, ns)))

# Main
# ----

proc main() =
  var ns = 64
  var wantPpm = false
  var threads = max(1, countProcessors())
  let args = commandLineParams()
  var i = 0
  while i < args.len:
    if args[i] == "ppm":
      wantPpm = true
    elif args[i] == "--threads" and i + 1 < args.len:
      inc i
      threads = max(1, parseInt(args[i]))
    else:
      ns = max(1, parseInt(args[i]))
    inc i
  echo "rendering ", W, "x", H, " at ", ns, " samples per pixel"
  buildScene()
  let t0 = epochTime()
  var pixels = newSeq[Rgb](W * H)
  done.open()
  var pool = newSeq[Thread[int]](threads)
  for t in pool.mitems: createThread(t, worker, ns)
  for _ in 0 ..< H:
    let (y, row) = done.recv()
    for x in 0 ..< W: pixels[y * W + x] = row[x]
  joinThreads(pool)
  echo "rendered in ", int((epochTime() - t0) * 1000), " ms"
  newTarga(W, H, pixels).writeTo("ray.tga")
  echo "wrote ray.tga"
  if wantPpm:
    newPpm(W, H, pixels).writeTo("ray.ppm")
    echo "wrote ray.ppm"

main()

import os, streams, strformat, math, v3, image, options, sequtils, random, times
import material

let rows : int32 = 300
let cols : int32 = 600
const nsamples = 32
const maxBounces = 16
const hasThreadSupport = compileOption("threads")

template toRgb(v: Vec3) : Rgb =
    let r = uint8(255.99f32 * v.x)
    let g = uint8(255.99f32 * v.y)
    let b = uint8(255.99f32 * v.z)
    (r: r, g: g, b: b)

proc toGamma2(v: Vec3) : Vec3 =
    Vec3(x: v.x.sqrt, y: v.y.sqrt, z: v.z.sqrt)

proc skyColor(ray: Ray): Vec3 =
    let unitV = ray.b.normalize()
    let t = 0.5f * (unitV.y + 1f)
    let start = unit*(1.0f - t)
    let final = Vec3(x: 0.5f, y: 0.7f, z: 1f)*t
    result = start + final

proc color (ray: Ray, world: openarray[Hitable]) : Vec3 =
    var newRay = ray
    var bounces = 0
    result = vec3Unit()
    while true:
        let hitted = newRay.hit(world)
        if not hitted.isSome:
          break
        let hitdata = hitted.get()
        inc bounces
        result = result * hitdata.material.attenuation()
        let scattered = hitdata.material.scatter(newRay, hitdata)
        if bounces < maxBounces and scattered.isSome:
          newRay = scattered.get()
        else:
          return Vec3(x: 0f, y: 0f, z: 0f)

    result = result * newRay.skyColor()

let sphere = Sphere(o: Vec3(x: 0f, y: 0f, z: -1f), r: 0.5f, mat: Lambertian(albedo: Vec3(x: 0.1f, y: 0.2f, z: 0.5f )))
let sphere2 = Sphere(o: Vec3(x: 0f, y: -100.5f, z: -1f), r: 100f, mat: Lambertian(albedo: Vec3(x: 0.8f, y: 0.8f, z: 0.0f)))
let sphere3 = Sphere(o: Vec3(x: 1f, y: 0f, z: -1f), r: 0.5f, mat: Metalic(fuzzy: 0.1f, albedo: Vec3(x: 0.8f, y: 0.6f, z: 0.2f)))
let sphere4 = Sphere(o: Vec3(x: -1f, y: 0f, z: -1f), r: 0.5f, mat: Dielectric(refraction: 1.5f))
let sphere5 = Sphere(o: Vec3(x: -1f, y: 0f, z: -1f), r: -0.45f, mat: Dielectric(refraction: 1.5f))
#let world = [sphere, sphere2]
let world = [sphere, sphere2, sphere3, sphere4, sphere5]

proc doSample(j, i: int32) : Vec3 =
    let u = (float32(i) + rand(1f)) / float32(cols)
    let v = (float32(j) + rand(1f)) / float32(rows)
    let ray = newRay(u, v)
    return ray.color(world)

when hasThreadSupport:
    import threadpool
    proc sample4 (j, i: int32): tuple[a: Vec3, b: Vec3, c: Vec3, d: Vec3] =
        let st0 = spawn doSample(j, i)
        let st1 = spawn doSample(j, i)
        let st2 = spawn doSample(j, i)
        let st3 = spawn doSample(j, i)
        result = (^st0, ^st1, ^st2, ^st3)
else:
    proc sample4 (j, i: int32): tuple[a: Vec3, b: Vec3, c: Vec3, d: Vec3] =
        let st0 = doSample(j, i)
        let st1 = doSample(j, i)
        let st2 = doSample(j, i)
        let st3 = doSample(j, i)
        result = (st0, st1, st2, st3)

var pixels = newSeq[Rgb]()
for j in 0 ..< rows:
    for i in 0 ..< cols:
        var s = 0i32
        var col = Vec3()
        while s < nsamples:
            let sm = doSample(j, i)
            col = col + sm
            inc s

        col = col / nsamples.float32
        let rgb = col.toGamma2().toRgb()
        pixels.add rgb
        if int(cpuTime()*1000) mod 15 == 0:
            stdout.write($j, "                 ", "\r")
            stdout.flushFile()

#write file
let tga = newTarga(cols, rows, pixels)
tga.writeTo("ray.tga")

when defined(ppm):
    let ppm = newPpm(cols, rows, pixels)
    ppm.writeTo("ray.ppm")

when defined(tests):
    let v1 = Vec3(x: 0f, y: 1f, z:2f)
    let v2 = Vec3(x: 0f, y: 1f, z:2f)
    echo v1.dot(v2)
    echo v1.cross(v2)
    echo -vec3Unit()
    echo (1u8, 2u8, 3u8).toOpenArray()
    let b = @[ (0u8,0u8,0u8),  (0u8,255u8,255u8), (255u8,0u8,255u8), (255u8,255u8,0u8), (255u8,255u8,255u8), (255u8,0u8,0u8), (0u8,255u8,0u8), (0u8,0u8,255u8) ]
    newTarga(4, 2, b).writeTo("test.tga")
    newPpm(4, 2, b).writeTo("test.ppm")

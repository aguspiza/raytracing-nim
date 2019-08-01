import os, streams, strformat, math, v3, image, options, sequtils, random, times

let rows : int32 = 400
let cols : int32 = 800
const nsamples = 32
let unit = vec3Unit()
const hasThreadSupport = compileOption("threads")

template toRgb(v: Vec3) : Rgb =
    let r = uint8(255.99f32 * v.x)
    let g = uint8(255.99f32 * v.y)
    let b = uint8(255.99f32 * v.z)
    (r: r, g: g, b: b)

proc randInSphere() : Vec3 =
    result = Vec3()
    while true:
        let x = rand(1f)
        let y = rand(1f)
        let z = rand(1f)
        let v = Vec3(x: x, y: y, z: z)
        let v2 = v * 2f
        result = v2 - unit
        if result.sqlen() >= 1f:
            break

proc color (ray: Ray, world: openarray[Hitable]) : Vec3 =
    var bounce = ray
    var hitted = bounce.hit(world)
    let unitV = bounce.b.normalize()
    let t = 0.5f * (unitV.y + 1f)
    let start = unit*(1.0f - t)
    let final = Vec3(x: 0.5f, y: 0.7f, z: 1f)*t
    let sky = start + final
    result = sky
    var maxBounces = 20
    while hitted.isSome and maxBounces > 0:
        result = result * 0.5f
        let hitdata = hitted.get()
        let pointNormal = hitdata.point + hitdata.normal
        let randV = randInSphere()
        let target =  pointNormal + randV
        bounce = Ray(a: hitdata.point, b: target - hitdata.point)
        hitted = bounce.hit(world)
        dec maxBounces

let sphere = Sphere(o: Vec3(x: 0f, y: 0f, z: -1f), r: 0.5f)
let sphere2 = Sphere(o: Vec3(x: 0f, y: -100.5f, z: -1f), r: 100f)
let sphere3 = Sphere(o: Vec3(x: 1f, y: 0f, z: -1f), r: 0.5f)
let world = [sphere, sphere2, sphere3]

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
        var r = Vec3()
        while s < nsamples:
            let sm = doSample(j, i)
            r = r + sm
            inc s

        let col = r / nsamples.float32
        let rgb = col.toRgb()
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

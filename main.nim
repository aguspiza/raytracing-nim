import os, streams, strformat, math, v3, image, options, sequtils, random

let rows : int32 = 400
let cols : int32 = 800
let nsamples = 100


template toRgb(v: Vec3) : Rgb = 
    (r: uint8(255.99f32 * v.x), g: uint8(255.99f32 * v.y), b: uint8(255.99f32 * v.z) )

proc color (ray: Ray, world: openarray[Hitable]) : Vec3 =
    let hitted = ray.hit(world)
    if hitted.isSome:
        let hitdata = hitted.get() 
        return Vec3(x: hitdata.normal.x + 1f, y: hitdata.normal.y + 1f, z: hitdata.normal.z + 1f)*0.5
    let unitV = ray.b.normalize()
    let t = 0.5f * (unitV.y + 1f)
    return (vec3Unit()*(1.0f - t)) + ((Vec3(x: 0.5f, y: 0.7f, z: 1f)*t))

let sphere = Sphere(o: Vec3(x: 0f, y: 0f, z: -1f), r: 0.5f)
let sphere2 = Sphere(o: Vec3(x: 0f, y: -100.5f, z: -1f), r: 100f)
let sphere3 = Sphere(o: Vec3(x: 1f, y: 0f, z: -1f), r: 0.5f)
let world = [sphere, sphere2, sphere3]

var pixels = newSeq[Rgb]()
for j in 0 ..< rows:
    for i in 0 ..< cols:
        var samples = newSeq[Vec3]()
        for s in 0 ..< nsamples:
            let u = (float32(i) + rand(1f)) / float32(cols)
            let v = (float32(j) + rand(1f)) / float32(rows)
            let ray = newRay(u, v)
            samples.add(ray.color(world))
        let col = samples.foldl( a + b ) * (1f/nsamples.float32)
        pixels.add col.toRgb()
        samples.clear()

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
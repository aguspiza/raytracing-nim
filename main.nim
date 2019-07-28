import os, streams, strformat, math, v3, image

let rows : int32 = 400
let cols : int32 = 800

#top left
let scrOrigin = Vec3(x: -2f, y: 1f, z: -1f)
let hor = Vec3(x: 4f, y: 0f, z: 0f)
let vert = Vec3(x: 0.0f, y: -2f, z: 0f)
let origin = Vec3(x: 0f, y: 0f, z: 0f)

template toRgb(v: Vec3) : Rgb = 
    (r: uint8(255.99f32 * v.x), g: uint8(255.99f32 * v.y), b: uint8(255.99f32 * v.z) )

proc color (ray: Ray) : Vec3 =
    let sphere = Sphere(o: Vec3(x: 0f, y: 0f, z: -1f), r: 0.5f)
    let hitted = ray.hit(sphere)
    if hitted > 0f:
        let u = normalize(ray.pointAt(hitted) + -Vec3(x: 0f, y: 0f, z: -1f))
        return Vec3(x: u.x + 1f, y: u.y + 1f, z: u.z + 1f)*0.5
    let unitV = ray.b.normalize()
    let t = 0.5f * (unitV.y + 1f)
    return (vec3Unit()*(1.0f - t)) + ((Vec3(x: 0.5f, y: 0.7f, z: 1f)*t))

var pixels = newSeq[Rgb]()
for j in 0 ..< rows:
    for i in 0 ..< cols:
        let vec = Vec3(x: float32(i) / float32(cols), y: float32(j) / float32(rows), z: 0.2f32)
        let ray = Ray(a: origin, b: scrOrigin + (hor * vec.x) + (vert * vec.y))
        let col = ray.color().toRgb()
        pixels.add col

#write file
let tga = newTarga(cols, rows, pixels)
tga.writeTo("ray.tga")
let ppm = newPpm(cols, rows, pixels)
ppm.writeTo("ray.ppm")

when defined(tests):
    let v1 = Vec3(x: 0f, y: 1f, z:2f)
    let v2 = Vec3(x: 0f, y: 1f, z:2f)
    echo v1.dot(v2)
    echo v1.cross(v2)
    echo -vec3Unit()
    echo (1u8, 2u8, 3u8).toOpenArray()
    let b = @[ (0u8,0u8,0u8), (255u8,0u8,255u8), (0u8,255u8,255u8), (255u8,0u8,0u8), (0u8,255u8,0u8), (0u8,0u8,255u8) ]
    newTarga(3, 2, b).writeTo("test.tga")
    newPpm(3, 2, b).writeTo("test.ppm")
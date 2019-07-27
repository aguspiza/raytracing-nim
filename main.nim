import os, strformat, math, v3


let rows : int = 400
let cols : int = 800

let scrOrigin = Vec3(x: -2f, y: -1f, z: -1f)
let hor = Vec3(x: 4f, y: 0f, z: 0f)
let vert = Vec3(x: 0.0f, y: 2f, z: 0f)
let origin = Vec3(x: 0f, y: 0f, z: 0f)

proc color (ray: Ray) : Vec3 =
    let sphere = Sphere(o: Vec3(x: 0f, y: 0f, z: -1f), r: 0.5f)
    let hitted = ray.hit(sphere)
    if hitted > 0f:
        let u = normalize(ray.pointAt(hitted) + -Vec3(x: 0f, y: 0f, z: -1f))
        return Vec3(x: u.x + 1f, y: u.y + 1f, z: u.z + 1f)*0.5
    let unitV = ray.b.normalize()
    let t = 0.5f32 * (unitV.y + 1f)
    return (vec3Unit()*(1.0f - t)) + ((Vec3(x: 0.5f, y: 0.7f, z: 1f)*t))

var lines = newSeq[string]()
#header
lines.add "P3"
lines.add fmt"{cols} {rows}"
lines.add "255"

#pixels
for j in countdown(rows-1,0):
    for i in 0 ..< cols:
        let vec = Vec3(x: float32(i) / float32(cols), y: float32(j) / float32(rows), z: 0.2f32)
        let ray = Ray(a: origin, b: scrOrigin + (hor * vec.x) + (vert * vec.y))
        let col = ray.color()
        let ir = uint8(255.99f32 * col.x)
        let ig = uint8(255.99f32 * col.y)
        let ib = uint8(255.99f32 * col.z)
        lines.add fmt"{ir} {ig} {ib}"

#write file
let file = open("ray.ppm", FileMode.fmReadWrite)
for line in lines:
    file.writeLine(line)
file.flushFile()
file.close()

when defined(tests):
    let v1 = Vec3(x: 0f, y: 1f, z:2f)
    let v2 = Vec3(x: 0f, y: 1f, z:2f)
    echo v1.dot(v2)
    echo v1.cross(v2)
    echo -vec3Unit()
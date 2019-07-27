import math

type
    Vec3* = object
        x*, y*, z*: float32
    Ray* = object
        a*, b*: Vec3
    Sphere* = object
        o*: Vec3
        r*: float32

template `+`*(v1: Vec3, v2: Vec3): Vec3 =
    Vec3(x: v1.x + v2.x, y: v1.y + v2.y, z: v1.z + v2.z)

template `-`*(v1: Vec3): Vec3 =
    Vec3(x: -v1.x, y: -v1.y, z: -v1.z)

template `+`*(v1: Vec3, f: float32): Vec3 =
    Vec3(x: v1.x + f, y: v1.y + f, z: v1.z + f)

template `*`*(v1: Vec3, f: float32): Vec3 =
    Vec3(x: v1.x * f, y: v1.y * f, z: v1.z * f)

template dot*(v1: Vec3, v2: Vec3 ) : float32 =
    v1.x * v2.x + v1.y * v2.y + v1.z * v2.z

template cross*(v1: Vec3, v2: Vec3 ) : Vec3 =
    Vec3(x: v1.y * v2.z - v1.z * v2.y, y: -v1.x * v2.z - v1.z * v2.x, z: v1.x * v2.y - v1.y * v2.x )

template sqlen*(vec: Vec3) : float32 =
    vec.x * vec.x + vec.y * vec.y + vec.z * vec.z

template len*(vec: Vec3) : float32 =
    sqrt(vec.sqlen)

template pointAt*(ray: Ray, t: float32) : Vec3 =
    Vec3(x: ray.a.x + t*ray.b.x, y: ray.a.y + t*ray.b.y, z: ray.a.z + t*ray.b.z)

proc normalize*(vec: Vec3) : Vec3 =
    let k = 1f32 / (vec.len+0.000001f)
    result = Vec3(x: vec.x * k, y: vec.y * k, z: vec.z * k)
    assert result.len <= 1.0f
    assert result.len > 0.99f

proc vec3Unit*() : Vec3 = Vec3(x: 1f, y: 1f, z: 1f)

proc hit*(ray: Ray, s: Sphere) : float =
    let oc = ray.a + -s.o
    let a = ray.b.dot(ray.b)
    let b = oc.dot(ray.b) * 2f
    let c = oc.dot(oc) - s.r*s.r
    let res = b*b - 4*a*c
    result = if res < 0: -1f else: (-b - sqrt(res)) / (2f*a)
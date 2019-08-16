import math, options, random

type
    Vec3* = object
        x*, y*, z*: float32
    Ray* = object
        a*, b*: Vec3
    MayScatter* = concept mat
        var ray:Ray
        var hitdata: HitData
        var scattered = mat.scatter(ray, hitdata)
        scattered is Option[Ray]
    Material* = object of RootObj
    Sphere* = object
        o*: Vec3
        r*: float32
        mat*: ref Material
    HitData* = object
        point*: Vec3
        normal*: Vec3
        distance*: float32
        material*: ref Material
    MinMax* = tuple[min: float32, max: float32]
    Hitable* = concept h
        var ray: Ray
        var minmax: MinMax
        var hd = ray.hit(h, minmax)
        hd is Option[HitData]
    Camera* = object
        origin: Vec3
        upLeftCorner: Vec3
        hor: Vec3
        vert: Vec3
        u, v, w: Vec3
        lensRadius: float32


#top left
const 
    scrOrigin = Vec3(x: -2f, y: 1f, z: -1f)
    hor = Vec3(x: 4f, y: 0f, z: 0f)
    vert = Vec3(x: 0.0f, y: -2f, z: 0f)
    origin* = Vec3(x: 0f, y: 0f, z: 0f)

template `+`*(v1: Vec3, v2: Vec3): Vec3 =
    Vec3(x: v1.x + v2.x, y: v1.y + v2.y, z: v1.z + v2.z)

template `*`*(v1: Vec3, v2: Vec3): Vec3 =
    Vec3(x: v1.x * v2.x, y: v1.y * v2.y, z: v1.z * v2.z)

template `-`*(v1: Vec3, v2: Vec3): Vec3 =
    Vec3(x: v1.x - v2.x, y: v1.y - v2.y, z: v1.z - v2.z)

template `-`*(v1: Vec3): Vec3 =
    Vec3(x: -v1.x, y: -v1.y, z: -v1.z)

template `+`*(v1: Vec3, f: float32): Vec3 =
    Vec3(x: v1.x + f, y: v1.y + f, z: v1.z + f)

template `*`*(v1: Vec3, f: float32): Vec3 =
    Vec3(x: v1.x * f, y: v1.y * f, z: v1.z * f)

template `/`*(v1: Vec3, f: float32): Vec3 =
    Vec3(x: v1.x / f, y: v1.y / f, z: v1.z / f)

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
    let k = 1f32 / (vec.len+0.0001f)
    result = Vec3(x: vec.x * k, y: vec.y * k, z: vec.z * k)
    #echo result, k, " ", result.len
    #assert result.len <= 1.0f
    #assert result.len > 0.999f

proc vec3Unit*() : Vec3 = Vec3(x: 1f, y: 1f, z: 1f)

proc newHitData(ray: Ray, t: float, s: Sphere) : HitData =
    let point = ray.pointAt(t)
    let normal = point - s.o
    result = HitData( point: point, normal: normal / s.r, distance: t, material: s.mat)

proc hit*(ray: Ray, s: Sphere, margin: MinMax = (0.01f, float32.high)) : Option[HitData] =
    let oc = ray.a - s.o
    let a = ray.b.dot(ray.b)
    let b = oc.dot(ray.b)
    let c = oc.dot(oc) - s.r*s.r
    let res = b*b - a*c
    result = none(HitData)
    if res > 0:
        let tminus = (-b - sqrt(res)) / a
        if tminus > margin.min and tminus < margin.max:
            let hd = newHitData(ray, tminus, s)
            result = some(hd)
        else:
            let tplus = (-b + sqrt(res)) / a
            if tplus > margin.min and tplus < margin.max:
                let hd = newHitData(ray, tplus, s)
                result = some(hd)
 
proc hit*(ray: Ray, list: openarray[Hitable], margin: MinMax = (0.01f, float32.high)) : Option[HitData] =
    var closest = margin.max
    result = none(HitData)
    for h in list:
        let hd = ray.hit(h, (margin.min, closest))
        if hd.isSome:
            result = hd
            closest = hd.get().distance


proc newRay*(u: float32, v: float32) : Ray =
    let uh = hor * u
    let vv = vert * v
    let uv = uh + vv
    Ray(a: origin, b: scrOrigin + uv)

let unit* = vec3Unit()

proc randInSphere*() : Vec3 =
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

proc randInDisk*() : Vec3 =
    result = Vec3()
    while true:
        let x = rand(1f)
        let y = rand(1f)
        let z = 0f
        let v = Vec3(x: x, y: y, z: z)
        let v2 = v * 2f
        result = v2 - Vec3(x:1f, y:1f, z: 0f)
        if result.sqlen() >= 1f:
            break

proc reflect*(v: Vec3, target: Vec3): Vec3 =
    result = v - target * (v.dot(target) * 2f)

proc refract*(v: Vec3, target: Vec3, niOverNt: float32): Option[Vec3] =
    let nv = v.normalize()
    let dt = nv.dot(target)
    let discriminant = 1f - niOverNt * niOverNt * (1f - dt * dt)
    if discriminant > 0:
        result = some((nv - target*dt)*niOverNt - target*sqrt(discriminant))
    else:
        result = none(Vec3)

proc schlick* (cosine: float32, refraction: float32) : float32 =
  let r0 = (1f - refraction) / (1f + refraction)
  let r = r0*r0
  result = r + (1f - r) * pow((1f - cosine), 5)

proc newCamera*(lookFrom: Vec3, lookAt: Vec3) : Camera =
    let down = Vec3(x: 0f, y: 1f, z: 0f)
    let vFov = 20f
    let aperture = 2f
    let aspect = 2f
    let dist = lookFrom - lookAt
    let w = dist.normalize()
    let u = down.cross(w).normalize()
    let v = w.cross(u)
    let focusDist = dist.len()
    let tetha = vFov * PI / 180
    let halfHeight = tan(tetha/2)
    let halfWidth = aspect * halfHeight
    let leftCorner = lookFrom - u * halfWidth * focusDist - v * halfHeight * focusDist - w * focusDist
    let horz = u*halfWidth*focusDist*2
    let vertz = v*halfHeight*focusDist*2
    result = Camera(origin: lookfrom,
      upLeftCorner: leftCorner,
      lensRadius: aperture/2,
      u: u, 
      v: v,
      w: w,
      hor: horz,
      vert: vertz)

proc newRay*(cam: Camera, u, v: float32) : Ray =
    let uh = cam.hor * u
    let vv = cam.vert * v - cam.origin
    let uv = uh + vv
    result = Ray(a: cam.origin, b: cam.upLeftCorner + uv)

proc newRay1*(cam: Camera, u, v: float32) : Ray =
    let rd = randInDisk() * cam.lensRadius
    let offset = cam.u * rd.x + cam.v * rd.y
    let uh = cam.hor * u
    let vv = cam.vert * v - cam.origin - offset
    let uv = uh + vv
    result = Ray(a: cam.origin - offset, b: cam.upLeftCorner + uv)
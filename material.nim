import v3, options
type
  Material* = object
    scatter* = proc(ray: Ray, hitdata: HitData, attenuation: Vec3) : Option[Ray] 

Lambertian* = Material(scatter: proc(ray: Ray, hitdata: HitData, attenuation: Vec3) : Option[Ray] =
  if ray.b.x < 0:
    none(Ray)
  else:
    some(Ray(a: vec3Unit(), b: vec3Unit())

Dielectric* = Material(scatter: proc(ray: Ray, hitdata: HitData, attenuation: Vec3) : Option[Ray] =
  if ray.b.x < 0:
    none(Ray)
  else:
    some(Ray(a: vec3Unit(), b: vec3Unit())

Metalic* = Material(scatter: proc(ray: Ray, hitdata: HitData, attenuation: Vec3) : Option[Ray] =
  if ray.b.x < 0:
    none(Ray)
  else:
    some(Ray(a: vec3Unit(), b: vec3Unit())

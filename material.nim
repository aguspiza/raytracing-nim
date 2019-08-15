import v3, options, random

type
  Lambertian* = ref object of Material
    albedo*: Vec3
  Dielectric* = ref object of Material
    refraction*: float32
  Metalic* = ref object of Material
    fuzzy*: float32
    albedo*: Vec3

method scatter*(mat: ref Material, ray: Ray, hitdata: HitData) : Option[Ray] {.base.} =
  echo mat.repr

method attenuation*(mat: ref Material) : Vec3{.base.} =
  unit

method scatter*(mat: Lambertian, ray: Ray, hitdata: HitData) : Option[Ray] =
  let target = (hitdata.point + hitdata.normal) + randInSphere()
  let scattered = Ray(a: hitdata.point, b: target - hitdata.point)
  result = some(scattered)

method attenuation*(mat: Lambertian) : Vec3 = mat.albedo

method scatter*(mat: Dielectric, ray: Ray, hitdata: HitData) : Option[Ray] =
  let reflected = ray.b.reflect(hitdata.normal)
  var outNormal = hitdata.normal
  var niOverNt = 1f / mat.refraction
  var cosine = -1f * (ray.b.dot(hitdata.normal) / ray.b.len())
  if ray.b.dot(hitdata.normal) > 0:
    outNormal = -outNormal
    niOverNt = mat.refraction
    cosine = cosine * -1f * mat.refraction
  let refracted = ray.b.refract(outNormal, niOverNt)
  if refracted.isSome:
    let refractProbability = cosine.schlick(mat.refraction)
    if rand(1f) > refractProbability:
      let scatteredRefract = Ray(a: hitdata.point, b: refracted.get())
      return some(scatteredRefract)
  let scatteredReflect = Ray(a: hitdata.point, b: reflected)
  result = some(scatteredReflect) 

method attenuation*(mat: Dielectric) : Vec3 = unit

method scatter*(mat: Metalic, ray: Ray, hitdata: HitData) : Option[Ray] =
  let reflected = ray.b.normalize().reflect(hitdata.normal)
  let scattered = Ray(a: hitdata.point, b: reflected + randInSphere() * mat.fuzzy)
  if scattered.b.dot(hitdata.normal) > 0:
    result = some(scattered)
  else:
    result = none(Ray)

method attenuation*(mat: Metalic) : Vec3 = mat.albedo
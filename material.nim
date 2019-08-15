import v3, options, random

type
  Lambertian* = ref object of Material
    albedo*: Vec3
  Dielectric* = ref object of Material
    refraction*: float32
  Metalic* = ref object of Material
    fuzzy*: float32
    albedo*: Vec3

method scatter*(mat: ref Material, ray: Ray, hitdata: HitData) : Option[ScatteredRay] {.base.} =
  echo mat.repr

method scatter*(mat: Lambertian, ray: Ray, hitdata: HitData) : Option[ScatteredRay] =
  let target = (hitdata.point + hitdata.normal) + randInSphere()
  let scattered = ScatteredRay(ray: Ray(a: hitdata.point, b: target - hitdata.point), attenuation: mat.albedo)
  result = some(scattered)

method scatter*(mat: Dielectric, ray: Ray, hitdata: HitData) : Option[ScatteredRay] =
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
      let scatteredRefract = ScatteredRay(ray: Ray(a: hitdata.point, b: refracted.get()), attenuation: unit)
      return some(scatteredRefract)
  let scatteredReflect = ScatteredRay(ray: Ray(a: hitdata.point, b: reflected), attenuation: unit)
  result = some(scatteredReflect) 


method scatter*(mat: Metalic, ray: Ray, hitdata: HitData) : Option[ScatteredRay] =
  let reflected = ray.b.normalize().reflect(hitdata.normal)
  let scattered = ScatteredRay(ray: Ray(a: hitdata.point, b: reflected + randInSphere() * mat.fuzzy), attenuation: mat.albedo)
  if scattered.ray.b.dot(hitdata.normal) > 0.001:
    result = some(scattered)
  else:
    result = none(ScatteredRay)


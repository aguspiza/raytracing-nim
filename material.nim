import v3, options, random

proc Lambertian*(albedo: Vec3) : Material =
  Material(kind: mkLambertian, albedo: albedo)

proc Metalic*(albedo: Vec3, fuzzy: float32) : Material =
  Material(kind: mkMetalic, albedo: albedo, fuzzy: fuzzy)

proc Dielectric*(refraction: float32) : Material =
  Material(kind: mkDielectric, albedo: unit, refraction: refraction)

proc scatterLambertian(mat: Material, ray: Ray, hitdata: HitData) : Option[Ray] =
  let target = (hitdata.point + hitdata.normal) + randInSphere()
  let scattered = Ray(a: hitdata.point, b: target - hitdata.point)
  result = some(scattered)

proc scatterDielectric(mat: Material, ray: Ray, hitdata: HitData) : Option[Ray] =
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

proc scatterMetalic(mat: Material, ray: Ray, hitdata: HitData) : Option[Ray] =
  let reflected = ray.b.normalize().reflect(hitdata.normal)
  let scattered = Ray(a: hitdata.point, b: reflected + randInSphere() * mat.fuzzy)
  if scattered.b.dot(hitdata.normal) > 0:
    result = some(scattered)
  else:
    result = none(Ray)

proc scatter*(mat: Material, ray: Ray, hitdata: HitData) : Option[Ray] =
  case mat.kind
  of mkLambertian: scatterLambertian(mat, ray, hitdata)
  of mkMetalic: scatterMetalic(mat, ray, hitdata)
  of mkDielectric: scatterDielectric(mat, ray, hitdata)

# Dielectric's albedo is unit, as its old attenuation method returned
proc attenuation*(mat: Material) : Vec3 = mat.albedo

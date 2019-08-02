import v3, options

type
  Lambertian* = ref object of Material
    albedo*: Vec3
  Dielectric* = ref object of Material
  Metalic* = ref object of Material
    albedo*: Vec3

method scatter*(mat: ref Material, ray: Ray, hitdata: HitData) : Option[ScatteredRay] =
  echo mat.repr

method scatter*(mat: Lambertian, ray: Ray, hitdata: HitData) : Option[ScatteredRay] =
  let target = (hitdata.point + hitdata.normal) + randInSphere()
  let scattered = ScatteredRay(ray: Ray(a: hitdata.point, b: target - hitdata.point), attenuation: mat.albedo)
  result = some(scattered)

method scatter*(mat: Dielectric, ray: Ray, hitdata: HitData) : Option[ScatteredRay] =
  result = none(ScatteredRay)

method scatter*(mat: Metalic, ray: Ray, hitdata: HitData) : Option[ScatteredRay] =
  let reflected = ray.b.normalize().reflect(hitdata.normal)
  let scattered = ScatteredRay(ray: Ray(a: hitdata.point, b: reflected), attenuation: mat.albedo)
  if scattered.ray.b.dot(hitdata.normal) > 0:
    result = some(scattered)
  else:
    result = none(ScatteredRay)


class_name NoiseModel
extends RefCounted
## Alcance del ruido. Cada acción tiene un nivel (Rules.NOISE_*) y cada nivel un radio.


## Radio en metros de un nivel de ruido (0 si el nivel no existe).
static func radius_for(level: int) -> float:
	if level < 0 or level >= Rules.NOISE_RADII.size():
		return 0.0
	return Rules.NOISE_RADII[level]


## Verdadero si un oyente en listener oye un ruido de ese nivel en origin.
## hearing multiplica el radio (oyentes más sensibles > 1).
static func can_hear(listener: Vector3, origin: Vector3, level: int, hearing: float = 1.0) -> bool:
	var radius := radius_for(level) * maxf(hearing, 0.0)
	if radius <= 0.0:
		return false
	return listener.distance_to(origin) <= radius

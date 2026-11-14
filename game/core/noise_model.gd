class_name NoiseModel
extends RefCounted
## Alcance del ruido. Cada acción tiene un nivel (Rules.NOISE_*) y cada nivel un radio.
## El radio se multiplica por la sensibilidad de quien escucha y se reduce por cada pared
## que haya en medio. La intensidad percibida es el alcance que le sobra al ruido: un disparo
## lejano puede pesar más que un paso cercano.


## Radio en metros de un nivel de ruido (0 si el nivel no existe).
static func radius_for(level: int) -> float:
	if level < 0 or level >= Rules.NOISE_RADII.size():
		return 0.0
	return Rules.NOISE_RADII[level]


## Radio efectivo para un oyente con esa sensibilidad y esa cantidad de paredes en medio.
static func effective_radius(level: int, hearing: float = 1.0, walls: int = 0) -> float:
	var factor := pow(Rules.NOISE_WALL_FACTOR, float(maxi(walls, 0)))
	return radius_for(level) * maxf(hearing, 0.0) * factor


## Verdadero si un oyente en listener oye un ruido de ese nivel en origin.
## hearing multiplica el radio (oyentes más sensibles > 1).
static func can_hear(
	listener: Vector3, origin: Vector3, level: int, hearing: float = 1.0, walls: int = 0
) -> bool:
	var radius := effective_radius(level, hearing, walls)
	if radius <= 0.0:
		return false
	return listener.distance_to(origin) <= radius


## Intensidad con que se percibe: metros de alcance que le sobran al ruido (0 si no se oye).
## Baja con la distancia y con las paredes; sirve para decidir qué ruido importa más.
static func loudness(
	listener: Vector3, origin: Vector3, level: int, hearing: float = 1.0, walls: int = 0
) -> float:
	var radius := effective_radius(level, hearing, walls)
	if radius <= 0.0:
		return 0.0
	return maxf(radius - listener.distance_to(origin), 0.0)

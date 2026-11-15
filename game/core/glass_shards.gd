class_name GlassShards
extends RefCounted
## Trozos de un cristal roto en el suelo: dónde caen y de qué tamaño, siempre igual para el
## mismo panel (semilla fija), a los dos lados del cristal. Lógica pura.

const COUNT: int = 9
## Hasta dónde se reparten a cada lado del cristal (metros).
const SPREAD: float = 0.9
const MIN_SIZE: float = 0.06
const MAX_SIZE: float = 0.22
const THICKNESS: float = 0.012


## Trozos de un panel de centro y tamaño dados (el lado fino es el grosor del cristal):
## [{"position": Vector3, "size": Vector3, "yaw": float}], apoyados en el suelo (y = 0).
static func layout(center: Vector3, size: Vector3, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var result: Array[Dictionary] = []
	for _index: int in COUNT:
		var along := rng.randf_range(-0.5, 0.5) * length
		var across := rng.randf_range(-SPREAD, SPREAD)
		var offset := Vector3(along, 0.0, across) if along_x else Vector3(across, 0.0, along)
		var side := rng.randf_range(MIN_SIZE, MAX_SIZE)
		var spot := Vector3(center.x + offset.x, THICKNESS * 0.5, center.z + offset.z)
		var shard_size := Vector3(side, THICKNESS, side * rng.randf_range(0.5, 1.0))
		result.append({"position": spot, "size": shard_size, "yaw": rng.randf_range(0.0, TAU)})
	return result


## Clave estable de un panel en el estado del mundo.
static func key(room_id: String, index: int) -> String:
	return "glass_%s_%d" % [room_id, index]

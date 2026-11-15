class_name SaveCodec
extends RefCounted
## Códec del guardado: JSON con campo "version" y migración por versión. La partida usa
## CURRENT_VERSION y migra desde versiones anteriores; los ajustes y la mejor marca tienen su
## propia versión (sin migración: lo que no se reconoce vuelve a los valores por defecto).
## Nunca usa recursos del motor (.tres, .res, escenas): solo tipos JSON, que no ejecutan código.
## Solo decodifica y migra; el esquema campo por campo lo comprueba boundary/validation.gd.

const CURRENT_VERSION: int = 4
## Tamaño máximo aceptado del texto guardado (bytes UTF-8).
const MAX_BYTES: int = 262144
## Profundidad máxima de anidación aceptada.
const MAX_DEPTH: int = 8


## Convierte un diccionario en texto JSON con la versión dada (por defecto, la de la partida).
static func encode(data: Dictionary, version: int = CURRENT_VERSION) -> String:
	var copy: Dictionary = data.duplicate(true)
	copy["version"] = version
	return JSON.stringify(copy)


## Decodifica texto JSON y comprueba tamaño, profundidad y versión. Con la versión de la
## partida migra los guardados antiguos; con otra versión solo acepta exactamente esa o menor.
static func decode(text: String, expected_version: int = CURRENT_VERSION) -> DataResult:
	if text.is_empty():
		return DataResult.failure("empty")
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return DataResult.failure("too_large")
	var json := JSON.new()
	if json.parse(text) != OK:
		return DataResult.failure("bad_json")
	var root: Variant = json.data
	if not root is Dictionary:
		return DataResult.failure("not_object")
	var dict: Dictionary = root
	if _depth(dict, 0) > MAX_DEPTH:
		return DataResult.failure("too_deep")
	var raw_version: Variant = dict.get("version")
	if not (raw_version is float or raw_version is int):
		return DataResult.failure("no_version")
	var version_number: float = raw_version
	if version_number != floorf(version_number):
		return DataResult.failure("bad_version")
	var version := int(version_number)
	if version < 1:
		return DataResult.failure("bad_version")
	if version > expected_version:
		return DataResult.failure("future_version")
	if expected_version != CURRENT_VERSION:
		return DataResult.success(dict)
	return DataResult.success(_migrate(dict, version))


## Aplica las migraciones en cadena desde la versión dada hasta la actual. Cada paso solo
## cambia la forma de los datos; los valores los valida después el borde de validación.
static func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var current: Dictionary = data
	var version := from_version
	while version < CURRENT_VERSION:
		if version == 1:
			current = _migrate_1_to_2(current)
		elif version == 2:
			current = _migrate_2_to_3(current)
		elif version == 3:
			current = _migrate_3_to_4(current)
		version += 1
	current["version"] = CURRENT_VERSION
	return current


## Versión 1 (corte de la planta baja) a 2: piso por identificador, punto de reaparición,
## infección con su estado, objetos clave, reloj del rescate y estado del mundo.
static func _migrate_1_to_2(old: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var floor_raw: Variant = old.get("floor")
	var floor_id := SaveSchema.V1_FLOORS[0]
	if floor_raw is float or floor_raw is int:
		var floor_number: float = floor_raw
		var index := int(floor_number)
		if index >= 0 and index < SaveSchema.V1_FLOORS.size():
			floor_id = SaveSchema.V1_FLOORS[index]
	result["floor"] = floor_id
	var safe_zone: Variant = old.get("safe_zone")
	if safe_zone is String and not (safe_zone as String).is_empty():
		result["spawn_kind"] = "safe"
		result["spawn_id"] = safe_zone
	else:
		result["spawn_kind"] = "start"
	for key: String in ["health", "inventory", "vest", "equipped", "seed"]:
		if old.has(key):
			result[key] = old[key]
	var left: Variant = old.get("infection_left")
	var seconds: float = left if (left is float or left is int) else 0.0
	result["infection"] = {"infected": seconds > 0.0, "time_left": seconds}
	result["keys"] = old.get("phone_pieces", [])
	var called: Variant = old.get("phone_called")
	var clock: Variant = old.get("rescue_clock", 0.0)
	result["rescue"] = {"state": 1 if called is bool and called else 0, "time_left": clock}
	result["world"] = {"flags": old.get("shortcuts", []), "floors": {}}
	var stats: Variant = old.get("stats")
	if stats is Dictionary:
		var old_stats: Dictionary = stats
		result["stats"] = {
			"time": old_stats.get("time", 0.0),
			"damage_taken": old_stats.get("damage_taken", 0.0),
			"weapons_broken": old_stats.get("weapons_broken", 0),
			"crafted": old_stats.get("crafted", 0),
		}
	return result


## Versión 2 (pisos separados) a 3 (edificio continuo): la planta cambió, así que lo anotado
## por piso (enemigos muertos, objetos recogidos, contenedores y objetos en el suelo) ya no
## corresponde a nada y se descarta. Se conservan el jugador, las marcas (rejas y atajos
## abiertos), el rescate y las estadísticas.
static func _migrate_2_to_3(old: Dictionary) -> Dictionary:
	var result := old.duplicate(true)
	var world: Variant = old.get("world")
	var flags: Variant = []
	if world is Dictionary:
		var old_world: Dictionary = world
		flags = old_world.get("flags", [])
	result["world"] = {"flags": flags, "floors": {}}
	return result


## Versión 3 a 4 (dificultades): las partidas anteriores se jugaban con los valores de Fácil.
static func _migrate_3_to_4(old: Dictionary) -> Dictionary:
	var result := old.duplicate(true)
	result["difficulty"] = Difficulty.EASY
	return result


## Calcula la profundidad de anidación de diccionarios y listas.
static func _depth(value: Variant, level: int) -> int:
	if level > MAX_DEPTH:
		return level
	var deepest := level
	if value is Dictionary:
		var dict: Dictionary = value
		for key: Variant in dict:
			deepest = maxi(deepest, _depth(dict[key], level + 1))
	elif value is Array:
		var list: Array = value
		for item: Variant in list:
			deepest = maxi(deepest, _depth(item, level + 1))
	return deepest

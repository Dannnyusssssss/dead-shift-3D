class_name Validation
extends RefCounted
## Borde único de validación: toda entrada externa (guardado, ajustes, URL) pasa por aquí
## antes de llegar a la lógica. Validación por lista blanca: tipo, rango, longitud y formato.
## Lo que no se reconoce se descarta; lo dañado vuelve a su valor por defecto.

## Semilla máxima admitida (entero positivo de 31 bits).
const SEED_MAX: int = 2147483647
## Longitud máxima de la cadena de consulta de la URL que se analiza.
const QUERY_MAX_LENGTH: int = 512
## Formato de los identificadores internos (objetos, zonas, enemigos).
const ID_PATTERN: String = "^[a-z0-9_]{1,32}$"

static var _id_regex: RegEx = null


## Analiza el texto guardado de los ajustes. Nunca falla: lo inválido vuelve al valor por defecto.
static func parse_settings(text: String) -> Dictionary:
	var result: Dictionary = SettingsSchema.defaults()
	var decoded: DataResult = SaveCodec.decode(text)
	if not decoded.ok:
		return result
	var source: Dictionary = decoded.data
	for key: String in SettingsSchema.FLOATS:
		var spec: Array = SettingsSchema.FLOATS[key]
		var low: float = spec[0]
		var high: float = spec[1]
		var fallback: float = spec[2]
		result[key] = read_float(source, key, low, high, fallback)
	for key: String in SettingsSchema.INTS:
		var spec: Array = SettingsSchema.INTS[key]
		var low: int = spec[0]
		var high: int = spec[1]
		var fallback: int = spec[2]
		result[key] = read_int(source, key, low, high, fallback)
	for key: String in SettingsSchema.BOOLS:
		var fallback: bool = SettingsSchema.BOOLS[key]
		result[key] = read_bool(source, key, fallback)
	return result


## Analiza el texto de una partida guardada. Falla solo si el texto no es un guardado
## reconocible (vacío, gigante, JSON inválido, sin versión o de una versión futura);
## cada campo dañado vuelve a su valor por defecto. known_items son los objetos válidos.
static func parse_save(text: String, known_items: PackedStringArray) -> DataResult:
	var decoded: DataResult = SaveCodec.decode(text)
	if not decoded.ok:
		return decoded
	var source: Dictionary = decoded.data
	var result: Dictionary = {"version": SaveCodec.CURRENT_VERSION}
	result["floor"] = read_int(source, "floor", 0, SaveSchema.MAX_FLOOR, 0)
	result["safe_zone"] = read_id(source, "safe_zone")
	result["health"] = read_float(
		source, "health", 0.0, Rules.PLAYER_MAX_HEALTH, Rules.PLAYER_MAX_HEALTH
	)
	result["infection_left"] = read_float(
		source, "infection_left", 0.0, SaveSchema.MAX_INFECTION_SECONDS, 0.0
	)
	result["inventory"] = _read_inventory(source, known_items)
	result["vest"] = _read_vest(source, known_items)
	result["equipped"] = read_int(source, "equipped", -1, SaveSchema.MAX_SLOT_INDEX, -1)
	result["phone_pieces"] = read_id_list(source, "phone_pieces", SaveSchema.MAX_PHONE_PIECES)
	result["phone_called"] = read_bool(source, "phone_called", false)
	result["rescue_clock"] = read_float(
		source, "rescue_clock", 0.0, SaveSchema.MAX_RESCUE_SECONDS, 0.0
	)
	result["shortcuts"] = read_id_list(source, "shortcuts", SaveSchema.MAX_SHORTCUTS)
	result["killed"] = read_id_list(source, "killed", SaveSchema.MAX_KILLED)
	result["seed"] = read_int(source, "seed", 0, SEED_MAX, 0)
	result["stats"] = _read_stats(source)
	return DataResult.success(result)


## Extrae el parámetro "seed" de una cadena de consulta de URL ("?seed=123").
## Devuelve -1 si no existe o no es válido (solo dígitos, dentro del rango).
static func parse_seed(query: String) -> int:
	if query.length() > QUERY_MAX_LENGTH:
		return -1
	var trimmed := query.trim_prefix("?")
	for pair: String in trimmed.split("&", false):
		var parts: PackedStringArray = pair.split("=", true, 1)
		if parts.size() != 2 or parts[0] != "seed":
			continue
		var value: String = parts[1]
		if value.is_empty() or value.length() > 10 or not value.is_valid_int():
			return -1
		if value.begins_with("-") or value.begins_with("+"):
			return -1
		var number := value.to_int()
		if number < 0 or number > SEED_MAX:
			return -1
		return number
	return -1


## Comprueba si un texto es un identificador interno válido.
static func is_valid_id(value: Variant) -> bool:
	if not value is String:
		return false
	if _id_regex == null:
		_id_regex = RegEx.create_from_string(ID_PATTERN)
	var text: String = value
	return _id_regex.search(text) != null


## Lee un número decimal; si no es número o no es finito devuelve el valor por defecto,
## y si está fuera de rango lo ajusta al límite.
static func read_float(
	source: Dictionary, key: String, min_value: float, max_value: float, fallback: float
) -> float:
	var raw: Variant = source.get(key)
	if not (raw is float or raw is int):
		return fallback
	var number: float = raw
	if is_nan(number) or is_inf(number):
		return fallback
	return clampf(number, min_value, max_value)


## Lee un entero; JSON solo tiene decimales, así que exige que no tenga parte fraccionaria.
static func read_int(
	source: Dictionary, key: String, min_value: int, max_value: int, fallback: int
) -> int:
	var raw: Variant = source.get(key)
	if not (raw is float or raw is int):
		return fallback
	var number: float = raw
	if is_nan(number) or is_inf(number) or number != floorf(number):
		return fallback
	if number < float(min_value):
		return min_value
	if number > float(max_value):
		return max_value
	return int(number)


## Lee un booleano estricto (no acepta 0, 1 ni textos).
static func read_bool(source: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = source.get(key)
	if raw is bool:
		return raw
	return fallback


## Lee un identificador; si no es válido devuelve "".
static func read_id(source: Dictionary, key: String) -> String:
	var raw: Variant = source.get(key)
	if is_valid_id(raw):
		return raw
	return ""


## Lee un subdiccionario; si no lo es devuelve uno vacío.
static func read_dict(source: Dictionary, key: String) -> Dictionary:
	var raw: Variant = source.get(key)
	if raw is Dictionary:
		return raw
	return {}


## Lee una lista de identificadores válidos, sin repetidos y con un máximo de elementos.
static func read_id_list(source: Dictionary, key: String, max_items: int) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = source.get(key)
	if not raw is Array:
		return result
	var list: Array = raw
	for item: Variant in list:
		if result.size() >= max_items:
			break
		if is_valid_id(item):
			var text: String = item
			if not result.has(text):
				result.append(text)
	return result


## Casillas del inventario: solo objetos conocidos, casillas sin repetir y un máximo de entradas.
static func _read_inventory(
	source: Dictionary, known_items: PackedStringArray
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = source.get("inventory")
	if not raw is Array:
		return result
	var list: Array = raw
	var used_slots: Array[int] = []
	for entry: Variant in list:
		if result.size() >= SaveSchema.MAX_INVENTORY_ENTRIES:
			break
		if not entry is Dictionary:
			continue
		var item: Dictionary = entry
		var item_id := read_id(item, "id")
		var slot := read_int(item, "slot", -1, SaveSchema.MAX_SLOT_INDEX, -1)
		if item_id.is_empty() or not known_items.has(item_id) or slot < 0:
			continue
		if used_slots.has(slot):
			continue
		used_slots.append(slot)
		(
			result
			. append(
				{
					"slot": slot,
					"id": item_id,
					"count": read_int(item, "count", 1, SaveSchema.MAX_STACK_COUNT, 1),
					"durability": read_float(item, "durability", 0.0, 1.0, 1.0),
					"ammo": read_int(item, "ammo", 0, SaveSchema.MAX_LOADED_AMMO, 0),
				}
			)
		)
	return result


## Chaleco equipado: objeto conocido y fracción de durabilidad, o vacío.
static func _read_vest(source: Dictionary, known_items: PackedStringArray) -> Dictionary:
	var vest := read_dict(source, "vest")
	var item_id := read_id(vest, "id")
	if item_id.is_empty() or not known_items.has(item_id):
		return {}
	return {"id": item_id, "durability": read_float(vest, "durability", 0.0, 1.0, 1.0)}


## Estadísticas de la partida, cada una en su rango.
static func _read_stats(source: Dictionary) -> Dictionary:
	var stats := read_dict(source, "stats")
	return {
		"time": read_float(stats, "time", 0.0, SaveSchema.MAX_STAT_TIME, 0.0),
		"damage_taken": read_float(stats, "damage_taken", 0.0, SaveSchema.MAX_STAT_DAMAGE, 0.0),
		"weapons_broken": read_int(stats, "weapons_broken", 0, SaveSchema.MAX_STAT_COUNT, 0),
		"crafted": read_int(stats, "crafted", 0, SaveSchema.MAX_STAT_COUNT, 0),
		"ammo_left": read_int(stats, "ammo_left", 0, SaveSchema.MAX_STAT_COUNT, 0),
	}

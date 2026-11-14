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
	var decoded: DataResult = SaveCodec.decode(text, SettingsSchema.VERSION)
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
	result["bindings"] = parse_bindings(read_dict(source, "bindings"))
	return result


## Teclas reasignadas: solo acciones reasignables y teclas permitidas, y ninguna tecla usada
## por dos acciones (contando las de fábrica de las acciones no reasignadas). Ante un conflicto
## gana la acción que va antes en SettingsSchema.REBINDABLE; la otra vuelve a su tecla de fábrica.
static func parse_bindings(source: Dictionary) -> Dictionary:
	var wanted: Dictionary = {}
	for action: String in SettingsSchema.REBINDABLE:
		var raw: Variant = source.get(action)
		if not (raw is float or raw is int):
			continue
		var number: float = raw
		if is_nan(number) or is_inf(number) or number != floorf(number):
			continue
		var keycode := int(number)
		if SettingsSchema.is_allowed_key(keycode):
			wanted[action] = keycode
	var used: Array[int] = []
	for action: String in SettingsSchema.REBINDABLE:
		if not wanted.has(action):
			var defaults: Array = SettingsSchema.DEFAULT_BINDINGS[action]
			for keycode: Variant in defaults:
				var key_value: int = keycode
				used.append(key_value)
	var result: Dictionary = {}
	for action: String in SettingsSchema.REBINDABLE:
		if not wanted.has(action):
			continue
		var keycode: int = wanted[action]
		if used.has(keycode):
			continue
		used.append(keycode)
		result[action] = keycode
	return result


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

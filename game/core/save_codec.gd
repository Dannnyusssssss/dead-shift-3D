class_name SaveCodec
extends RefCounted
## Códec del guardado: JSON con campo "version" y migración por versión.
## Nunca usa recursos del motor (.tres, .res, escenas): solo tipos JSON, que no ejecutan código.
## Solo decodifica y migra; el esquema campo por campo lo comprueba boundary/validation.gd.

const CURRENT_VERSION: int = 1
## Tamaño máximo aceptado del texto guardado (bytes UTF-8).
const MAX_BYTES: int = 262144
## Profundidad máxima de anidación aceptada.
const MAX_DEPTH: int = 8


## Convierte un diccionario en texto JSON con la versión actual.
static func encode(data: Dictionary) -> String:
	var copy: Dictionary = data.duplicate(true)
	copy["version"] = CURRENT_VERSION
	return JSON.stringify(copy)


## Decodifica texto JSON, comprueba tamaño, profundidad y versión, y migra a la actual.
static func decode(text: String) -> DataResult:
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
	if version > CURRENT_VERSION:
		return DataResult.failure("future_version")
	return DataResult.success(_migrate(dict, version))


## Aplica las migraciones en cadena desde la versión dada hasta la actual.
## Hoy solo existe la versión 1; cada versión nueva añade aquí su paso.
static func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var current: Dictionary = data
	var version := from_version
	while version < CURRENT_VERSION:
		version += 1
	current["version"] = CURRENT_VERSION
	return current


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

class_name WorldState
extends RefCounted
## Estado del mundo que sobrevive al cambiar de piso: qué enemigos murieron, qué se recogió,
## qué contenedores se registraron (y qué les queda), qué objetos quedaron en el suelo y las
## marcas globales (rejas y atajos abiertos). Cada elemento de un piso se identifica por una
## clave estable que sale de sus datos. Lógica pura.

## Piso donde está el jugador.
var current_floor: String = ""
## Marcas globales (identificador -> verdadero).
var flags: Dictionary = {}
## Por piso: {"killed": {clave: true}, "taken": {clave: true}, "containers": {clave: lista},
## "drops": [entradas]}.
var _floors: Dictionary = {}


func set_flag(flag_id: String) -> void:
	if not flag_id.is_empty():
		flags[flag_id] = true


func has_flag(flag_id: String) -> bool:
	return flags.has(flag_id)


func mark_killed(floor_id: String, key: String) -> void:
	_bucket(floor_id, "killed")[key] = true


func is_killed(floor_id: String, key: String) -> bool:
	return _bucket(floor_id, "killed").has(key)


## Un objeto suelto colocado en el piso fue recogido.
func mark_taken(floor_id: String, key: String) -> void:
	_bucket(floor_id, "taken")[key] = true


func is_taken(floor_id: String, key: String) -> bool:
	return _bucket(floor_id, "taken").has(key)


## Guarda lo que le queda a un contenedor registrado ("id:cantidad"; vacío = registrado entero).
func set_container(floor_id: String, key: String, remaining: PackedStringArray) -> void:
	_bucket(floor_id, "containers")[key] = remaining


func has_container(floor_id: String, key: String) -> bool:
	return _bucket(floor_id, "containers").has(key)


func container_contents(floor_id: String, key: String) -> PackedStringArray:
	var stored: Variant = _bucket(floor_id, "containers").get(key, PackedStringArray())
	if stored is PackedStringArray:
		return stored
	return PackedStringArray()


## Objetos que quedaron en el suelo de un piso (botín, objetos soltados o lanzados).
## Cada entrada: {"id", "count", "durability", "ammo", "x", "z"}.
func set_drops(floor_id: String, entries: Array[Dictionary]) -> void:
	_record(floor_id)["drops"] = entries.duplicate(true)


func drops(floor_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stored: Variant = _record(floor_id).get("drops", [])
	if stored is Array:
		var list: Array = stored
		for entry: Variant in list:
			if entry is Dictionary:
				result.append(entry)
	return result


## Datos para el guardado (solo tipos JSON).
func to_data() -> Dictionary:
	var floors: Dictionary = {}
	for floor_id: String in _floors:
		var record: Dictionary = _floors[floor_id]
		var containers: Dictionary = {}
		var stored: Dictionary = record["containers"]
		for key: String in stored:
			var remaining: PackedStringArray = stored[key]
			containers[key] = Array(remaining)
		var killed: Dictionary = record["killed"]
		var taken: Dictionary = record["taken"]
		floors[floor_id] = {
			"killed": killed.keys(),
			"taken": taken.keys(),
			"containers": containers,
			"drops": drops(floor_id),
		}
	return {"flags": flags.keys(), "floors": floors}


## Restaura desde datos ya validados por boundary/save_validation.gd.
func load_data(data: Dictionary) -> void:
	flags.clear()
	_floors.clear()
	var flag_list: Array = data.get("flags", [])
	for flag_id: Variant in flag_list:
		if flag_id is String:
			var flag_text: String = flag_id
			set_flag(flag_text)
	var floors: Dictionary = data.get("floors", {})
	for floor_id: Variant in floors:
		if not floor_id is String:
			continue
		var id: String = floor_id
		var record: Dictionary = floors[floor_id]
		var killed: Array = record.get("killed", [])
		for key: Variant in killed:
			mark_killed(id, str(key))
		var taken: Array = record.get("taken", [])
		for key: Variant in taken:
			mark_taken(id, str(key))
		var containers: Dictionary = record.get("containers", {})
		for key: Variant in containers:
			var remaining := PackedStringArray()
			var list: Variant = containers[key]
			if list is PackedStringArray:
				remaining = list
			elif list is Array:
				for entry: Variant in list:
					remaining.append(str(entry))
			set_container(id, str(key), remaining)
		var entries: Array[Dictionary] = []
		var raw_drops: Array = record.get("drops", [])
		for entry: Variant in raw_drops:
			if entry is Dictionary:
				entries.append(entry)
		set_drops(id, entries)


## Pisos con algún registro (para el guardado).
func floor_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for floor_id: String in _floors:
		result.append(floor_id)
	return result


func _record(floor_id: String) -> Dictionary:
	if not _floors.has(floor_id):
		_floors[floor_id] = {"killed": {}, "taken": {}, "containers": {}, "drops": []}
	var record: Dictionary = _floors[floor_id]
	return record


func _bucket(floor_id: String, bucket_name: String) -> Dictionary:
	var bucket: Dictionary = _record(floor_id)[bucket_name]
	return bucket

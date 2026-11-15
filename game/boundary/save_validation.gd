class_name SaveValidation
extends RefCounted
## Borde de validación de la partida guardada (versión actual de SaveCodec). Primero cada campo
## por separado (tipo, rango, longitud, lista blanca de identificadores) y después la coherencia
## entre campos: piso y punto de reaparición que existan, inventario dentro del límite y sin
## casillas repetidas, objetos clave sin repetir y del tipo correcto, teléfono armado solo con
## todas las piezas, helicóptero llamado solo con teléfono, reloj nunca negativo. Lo inválido se
## corrige o se descarta: un guardado manipulado nunca deja la partida en un estado imposible.
##
## El contexto lo arma GameCatalog.save_context() (o una prueba):
##   {"items": {id: {"category", "max_stack", "magazine"}}, "floors": {id: {"exits": [...],
##    "safe_rooms": [...]}}, "start_floor": id, "capacity": int, "phone_parts": [...]}

const SPAWN_START: String = "start"
const SPAWN_EXIT: String = "exit"
const SPAWN_SAFE: String = "safe"


## Decodifica, migra y valida. Falla solo si el texto no se puede leer como guardado.
static func parse(text: String, context: Dictionary) -> DataResult:
	var decoded: DataResult = SaveCodec.decode(text)
	if not decoded.ok:
		return decoded
	return DataResult.success(sanitize(decoded.data, context))


## Valida un diccionario ya decodificado y migrado.
static func sanitize(source: Dictionary, context: Dictionary) -> Dictionary:
	var items: Dictionary = context.get("items", {})
	var floors: Dictionary = context.get("floors", {})
	var capacity: int = context.get("capacity", Rules.INVENTORY_SLOTS)
	var result: Dictionary = {"version": SaveCodec.CURRENT_VERSION}
	_read_location(source, context, floors, result)
	result["health"] = Validation.read_float(
		source, "health", 1.0, Rules.PLAYER_MAX_HEALTH, Rules.PLAYER_MAX_HEALTH
	)
	result["infection"] = _read_infection(source)
	var inventory := _read_inventory(source, items, capacity)
	result["inventory"] = inventory
	result["vest"] = _read_vest(source, items)
	result["equipped"] = _read_equipped(source, inventory, items, capacity)
	var keys := _read_keys(source, items)
	result["keys"] = keys
	var parts: Array = context.get("phone_parts", Rules.PHONE_PARTS)
	var all_parts := true
	for part: Variant in parts:
		if not keys.has(part):
			all_parts = false
	var assembled := Validation.read_bool(source, "phone_assembled", false) and all_parts
	result["phone_assembled"] = assembled
	result["rescue"] = _read_rescue(source, assembled)
	result["world"] = _read_world(source, items, floors)
	result["seed"] = Validation.read_int(source, "seed", 0, Validation.SEED_MAX, 0)
	result["stats"] = _read_stats(source)
	return result


## Piso y punto de reaparición. Si el piso no existe, el de inicio; si el punto no existe en
## ese piso, el inicio (piso inicial) o la primera salida del piso.
static func _read_location(
	source: Dictionary, context: Dictionary, floors: Dictionary, result: Dictionary
) -> void:
	var start: String = context.get("start_floor", "")
	var floor_id := Validation.read_id(source, "floor")
	if not floors.has(floor_id):
		floor_id = start
	var info: Dictionary = floors.get(floor_id, {})
	var exits: Array = info.get("exits", [])
	var safe_rooms: Array = info.get("safe_rooms", [])
	var kind: Variant = source.get("spawn_kind")
	var spawn_id := Validation.read_id(source, "spawn_id")
	if kind is String and kind == SPAWN_EXIT and exits.has(spawn_id):
		result["spawn_kind"] = SPAWN_EXIT
	elif kind is String and kind == SPAWN_SAFE and safe_rooms.has(spawn_id):
		result["spawn_kind"] = SPAWN_SAFE
	elif floor_id == start or exits.is_empty():
		result["spawn_kind"] = SPAWN_START
		spawn_id = ""
	else:
		result["spawn_kind"] = SPAWN_EXIT
		spawn_id = exits[0]
	result["floor"] = floor_id
	result["spawn_id"] = spawn_id


static func _read_infection(source: Dictionary) -> Dictionary:
	var raw := Validation.read_dict(source, "infection")
	var infected := Validation.read_bool(raw, "infected", false)
	if not infected:
		return {"infected": false, "time_left": 0.0}
	# Nunca a cero: cargar no debe convertir al jugador en el acto.
	return {
		"infected": true,
		"time_left":
		Validation.read_float(raw, "time_left", 1.0, Rules.INFECTION_TIME, Rules.INFECTION_TIME),
	}


## Una casilla de objeto: objeto conocido, cantidad dentro de su máximo, durabilidad y balas.
static func _read_stack(entry: Dictionary, items: Dictionary, allow_keys: bool) -> Dictionary:
	var item_id := Validation.read_id(entry, "id")
	if not items.has(item_id):
		return {}
	var info: Dictionary = items[item_id]
	var category: int = info.get("category", 0)
	if category == ItemData.CATEGORY_KEY and not allow_keys:
		return {}
	var stack_limit: int = info.get("max_stack", 1)
	var max_stack := maxi(stack_limit, 1)
	var magazine: int = info.get("magazine", 0)
	var durability := Validation.read_float(entry, "durability", 0.0, 1.0, 1.0)
	return {
		"id": item_id,
		"count": Validation.read_int(entry, "count", 1, max_stack, 1),
		"durability": durability,
		"ammo": Validation.read_int(entry, "ammo", 0, magazine, 0),
	}


static func _read_inventory(
	source: Dictionary, items: Dictionary, capacity: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = source.get("inventory")
	if not raw is Array:
		return result
	var list: Array = raw
	var used: Array[int] = []
	for entry: Variant in list:
		if result.size() >= capacity:
			break
		if not entry is Dictionary:
			continue
		var data: Dictionary = entry
		var slot := Validation.read_int(data, "slot", -1, capacity - 1, -1)
		if slot < 0 or used.has(slot) or Validation.read_int(data, "slot", -1, 9999, -1) != slot:
			continue
		var stack := _read_stack(data, items, false)
		if stack.is_empty():
			continue
		used.append(slot)
		stack["slot"] = slot
		result.append(stack)
	return result


static func _read_vest(source: Dictionary, items: Dictionary) -> Dictionary:
	var raw := Validation.read_dict(source, "vest")
	var item_id := Validation.read_id(raw, "id")
	if not items.has(item_id):
		return {}
	var info: Dictionary = items[item_id]
	if info.get("category", -1) != ItemData.CATEGORY_VEST:
		return {}
	var durability := Validation.read_float(raw, "durability", 0.0, 1.0, 1.0)
	if durability <= 0.0:
		return {}
	return {"id": item_id, "durability": durability}


## El arma equipada debe ser una casilla del inventario que contenga un arma; si no, ninguna.
static func _read_equipped(
	source: Dictionary, inventory: Array[Dictionary], items: Dictionary, capacity: int
) -> int:
	var slot := Validation.read_int(source, "equipped", -1, capacity - 1, -1)
	for entry: Dictionary in inventory:
		if entry["slot"] == slot:
			var info: Dictionary = items[entry["id"]]
			if info.get("category", -1) == ItemData.CATEGORY_WEAPON:
				return slot
	return -1


static func _read_keys(source: Dictionary, items: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for item_id: String in Validation.read_id_list(source, "keys", SaveSchema.MAX_KEY_ITEMS):
		var info: Dictionary = items.get(item_id, {})
		if info.get("category", -1) == ItemData.CATEGORY_KEY:
			result.append(item_id)
	return result


## Reloj del rescate: estado conocido, sin llamada si no hay teléfono, nunca negativo, y un
## guardado no puede estar «ya rescatado».
static func _read_rescue(source: Dictionary, assembled: bool) -> Dictionary:
	var raw := Validation.read_dict(source, "rescue")
	var state := Validation.read_int(
		raw, "state", RescueClock.STATE_IDLE, RescueClock.STATE_BOARDED, RescueClock.STATE_IDLE
	)
	if not assembled or state == RescueClock.STATE_BOARDED:
		state = RescueClock.STATE_IDLE
	var limit := (
		Rules.HELICOPTER_ARRIVAL_TIME
		if state == RescueClock.STATE_INBOUND
		else Rules.HELICOPTER_WAIT_TIME
	)
	var seconds := 0.0
	if state == RescueClock.STATE_INBOUND or state == RescueClock.STATE_WAITING:
		seconds = Validation.read_float(raw, "time_left", 0.0, limit, limit)
	return {"state": state, "time_left": seconds}


static func _read_world(source: Dictionary, items: Dictionary, floors: Dictionary) -> Dictionary:
	var raw := Validation.read_dict(source, "world")
	var result_floors: Dictionary = {}
	var floors_raw := Validation.read_dict(raw, "floors")
	for floor_id: Variant in floors_raw:
		if (
			not floor_id is String
			or not floors.has(floor_id)
			or result_floors.size() >= floors.size()
		):
			continue
		var record_raw: Variant = floors_raw[floor_id]
		if not record_raw is Dictionary:
			continue
		var record: Dictionary = record_raw
		result_floors[floor_id] = {
			"killed": Validation.read_id_list(record, "killed", SaveSchema.MAX_KILLED),
			"taken": Validation.read_id_list(record, "taken", SaveSchema.MAX_KILLED),
			"containers": _read_containers(record, items),
			"drops": _read_drops(record, items),
		}
	return {
		"flags": Validation.read_id_list(raw, "flags", SaveSchema.MAX_FLAGS),
		"floors": result_floors,
	}


## Contenido restante de contenedores: clave válida -> lista de "id:cantidad" conocidos.
static func _read_containers(record: Dictionary, items: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var raw := Validation.read_dict(record, "containers")
	for key: Variant in raw:
		if result.size() >= SaveSchema.MAX_CONTAINERS or not Validation.is_valid_id(key):
			continue
		var entries: Variant = raw[key]
		if not entries is Array:
			continue
		var list: Array = entries
		var clean := PackedStringArray()
		for entry: Variant in list:
			if clean.size() >= SaveSchema.MAX_CONTAINER_ENTRIES or not entry is String:
				continue
			var text: String = entry
			var parts := text.split(":")
			if parts.size() != 2 or not items.has(parts[0]) or not parts[1].is_valid_int():
				continue
			var info: Dictionary = items[parts[0]]
			var stack_limit: int = info.get("max_stack", 1)
			var count := clampi(parts[1].to_int(), 1, maxi(stack_limit, 1))
			clean.append("%s:%d" % [parts[0], count])
		result[key] = clean
	return result


## Objetos en el suelo: casillas válidas con una posición dentro de límites razonables.
static func _read_drops(record: Dictionary, items: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = record.get("drops")
	if not raw is Array:
		return result
	var list: Array = raw
	for entry: Variant in list:
		if result.size() >= SaveSchema.MAX_DROPS or not entry is Dictionary:
			continue
		var data: Dictionary = entry
		var stack := _read_stack(data, items, true)
		if stack.is_empty():
			continue
		var limit := SaveSchema.MAX_COORDINATE
		stack["x"] = Validation.read_float(data, "x", -limit, limit, 0.0)
		stack["z"] = Validation.read_float(data, "z", -limit, limit, 0.0)
		result.append(stack)
	return result


static func _read_stats(source: Dictionary) -> Dictionary:
	var stats := Validation.read_dict(source, "stats")
	return {
		"time": Validation.read_float(stats, "time", 0.0, SaveSchema.MAX_STAT_TIME, 0.0),
		"damage_taken":
		Validation.read_float(stats, "damage_taken", 0.0, SaveSchema.MAX_STAT_DAMAGE, 0.0),
		"weapons_broken":
		Validation.read_int(stats, "weapons_broken", 0, SaveSchema.MAX_STAT_COUNT, 0),
		"crafted": Validation.read_int(stats, "crafted", 0, SaveSchema.MAX_STAT_COUNT, 0),
		"kills": Validation.read_int(stats, "kills", 0, SaveSchema.MAX_STAT_COUNT, 0),
	}

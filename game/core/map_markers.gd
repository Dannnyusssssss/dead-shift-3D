class_name MapMarkers
extends RefCounted
## Dónde están las cosas importantes del edificio según los datos de los pisos: piezas del
## teléfono y llaves que el jugador todavía no tiene, y zonas seguras. Lo usan el mapa y el
## cuaderno. Marca la sala, no el punto exacto. Lógica pura.

## Objeto clave que permite abrir el mapa.
const MAP_ITEM: String = "mall_map"
## Llaves que se marcan en el mapa mientras el jugador no las tenga.
const KEYS: Array[String] = ["security_key", "roof_key"]
## Nombre de los tramos del pasillo (salas sin nombre propio).
const HALL_KEY: String = "map_hall"


## Cosas importantes que faltan: [{"item_id", "floor_id", "room_id", "room_key", "floor_key",
## "carrier_key"}], primero las piezas del teléfono (si no está armado) y luego las llaves.
## «carrier_key» es el nombre del jefe que la lleva encima ("" si está en la sala).
static func missing(
	floors: Array[FloorData], keys: KeyItems, plan: LootPlan = null
) -> Array[Dictionary]:
	var wanted: Array[String] = []
	if not keys.phone_assembled:
		for part: String in Rules.PHONE_PARTS:
			if not keys.has(part):
				wanted.append(part)
	for key_id: String in KEYS:
		if not keys.has(key_id):
			wanted.append(key_id)
	return locations(floors, wanted, plan)


## Sala y piso donde está cada objeto pedido en esta partida (el reparto del plan; sin plan, los
## datos), en el orden pedido; un objeto que no está en ningún piso no aparece. Si lo lleva un
## jefe, la sala donde espera.
static func locations(
	floors: Array[FloorData], item_ids: Array[String], plan: LootPlan = null
) -> Array[Dictionary]:
	var found: Dictionary = {}
	for floor_data: FloorData in floors:
		for room: RoomData in floor_data.rooms:
			for item_id: String in _room_items(room, floor_data.id, plan):
				if item_ids.has(item_id) and not found.has(item_id):
					found[item_id] = _entry(item_id, floor_data, room, "")
		for spawn: EnemySpawn in floor_data.enemies:
			var boss := spawn.enemy.boss if spawn.enemy != null else null
			if boss == null or not item_ids.has(boss.drop_key_item):
				continue
			if not found.has(boss.drop_key_item):
				var room := _room_at(floor_data, Vector2(spawn.position.x, spawn.position.z))
				found[boss.drop_key_item] = _entry(
					boss.drop_key_item, floor_data, room, spawn.enemy.name_key
				)
	var result: Array[Dictionary] = []
	for item_id: String in item_ids:
		if found.has(item_id):
			result.append(found[item_id])
	return result


## Salas que son zona segura en un piso.
static func safe_rooms(floor_data: FloorData) -> Array[RoomData]:
	var result: Array[RoomData] = []
	for room: RoomData in floor_data.rooms:
		if room.safe_zone:
			result.append(room)
	return result


static func _entry(
	item_id: String, floor_data: FloorData, room: RoomData, carrier_key: String
) -> Dictionary:
	return {
		"item_id": item_id,
		"floor_id": floor_data.id,
		"room_id": room.id if room != null else "",
		"room_key": _room_key(room),
		"floor_key": floor_data.name_key,
		"carrier_key": carrier_key,
	}


## Nombre de la sala para mostrar; los tramos del pasillo no tienen nombre propio («Pasillo»).
static func _room_key(room: RoomData) -> String:
	if room == null:
		return ""
	return room.name_key if not room.name_key.is_empty() else HALL_KEY


## Sala que contiene un punto (x, z) del piso, o null.
static func _room_at(floor_data: FloorData, point: Vector2) -> RoomData:
	for room: RoomData in floor_data.rooms:
		if room.rect.has_point(point):
			return room
	return null


## Objetos que los datos ponen en una sala (sueltos o dentro de contenedores).
static func _room_items(room: RoomData, floor_id: String, plan: LootPlan) -> Array[String]:
	var ids: Array[String] = []
	var spots := room.loot if plan == null else plan.loot_for(floor_id, room)
	for spot: LootSpot in spots:
		if spot.kind == LootSpot.KIND_PICKUP:
			ids.append(spot.item_id)
		for entry: String in spot.contents:
			ids.append(entry.split(":")[0])
	return ids

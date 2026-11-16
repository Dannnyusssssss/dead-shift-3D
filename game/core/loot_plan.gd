class_name LootPlan
extends RefCounted
## Reparto del botín de una partida según su semilla. Dentro de cada piso se barajan los
## objetos sueltos entre sí (salvo armas y chalecos, que se quedan para no cambiar el
## equilibrio de cada piso) y el contenido de los contenedores entre sí. Los puntos son siempre
## los mismos y cada objeto sigue en su piso; solo cambia qué hay en cada punto.
##
## Siempre se puede completar: ningún objeto clave (piezas del teléfono, llaves, plano) cae en
## una sala cuya puerta pide una llave. Si una mezcla no lo cumple se prueba otra; si ninguna
## lo cumple, el piso se queda como en los datos. Sin «shuffled» (partidas guardadas antes del
## reparto) todo queda como en los datos. Lógica pura: los pisos, el mapa, el cuaderno y la
## nota del técnico leen el botín de aquí.

## Objetos clave que nunca van detrás de una puerta con llave.
const KEY_ITEMS: Array[String] = [
	"phone_antenna", "phone_battery", "phone_board", "security_key", "roof_key", "mall_map"
]
## Curas de la infección: se quedan en su sitio (la primera dosis en la sala de seguridad del
## inicio es parte del diseño; moverlas podría dejar una partida sin salida a tiempo).
## Un contenedor que guarde alguna no entra en la mezcla.
const FIXED_ITEMS: Array[String] = ["neutrax", "antibiotics"]
## Intentos de mezcla por piso antes de dejarlo como en los datos.
const MAX_ATTEMPTS: int = 32
## Distancia (m) de una reja con llave al borde de una sala para considerarla su puerta.
const GATE_REACH: float = 0.8

var shuffled: bool = false
## floor_id -> room_id -> Array[LootSpot] (copias; nunca se tocan los datos del catálogo).
var _loot: Dictionary = {}


static func build(
	floors: Array[FloorData], seed_value: int, shuffle: bool, items: ItemCatalog
) -> LootPlan:
	var plan := LootPlan.new()
	plan.shuffled = shuffle
	for floor_data: FloorData in floors:
		plan._plan_floor(floor_data, seed_value, shuffle, items)
	return plan


## Botín efectivo de una sala (los datos tal cual si no hay plan para ella).
func loot_for(floor_id: String, room: RoomData) -> Array[LootSpot]:
	var rooms: Dictionary = _loot.get(floor_id, {})
	if rooms.has(room.id):
		var spots: Array[LootSpot] = rooms[room.id]
		return spots
	return room.loot


## Salas cuya puerta tiene una reja que pide un objeto (allí no pueden ir objetos clave).
static func locked_rooms(floor_data: FloorData) -> Array[String]:
	var result: Array[String] = []
	for gate: GateSpec in floor_data.gates:
		if gate.required_item.is_empty():
			continue
		var spot := Vector2(gate.position.x, gate.position.z)
		for room: RoomData in floor_data.rooms:
			if (
				room.rect.grow(GATE_REACH).has_point(spot)
				and not room.rect.grow(-GATE_REACH).has_point(spot)
			):
				if not result.has(room.id):
					result.append(room.id)
	return result


## Si un contenedor guarda alguna cura que no se mueve.
static func _holds_fixed(spot: LootSpot) -> bool:
	for entry: String in spot.contents:
		if FIXED_ITEMS.has(entry.get_slice(":", 0)):
			return true
	return false


## Si un punto lleva algún objeto clave.
static func holds_key_item(spot: LootSpot) -> bool:
	if spot.kind == LootSpot.KIND_PICKUP:
		return KEY_ITEMS.has(spot.item_id)
	for entry: String in spot.contents:
		if KEY_ITEMS.has(entry.get_slice(":", 0)):
			return true
	return false


func _plan_floor(floor_data: FloorData, seed_value: int, shuffle: bool, items: ItemCatalog) -> void:
	var rooms: Dictionary = {}
	# Copias de cada punto, en el orden de los datos.
	var owners: Array[String] = []
	var copies: Array[LootSpot] = []
	for room: RoomData in floor_data.rooms:
		var list: Array[LootSpot] = []
		for spot: LootSpot in room.loot:
			var copy: LootSpot = spot.duplicate()
			copy.contents = PackedStringArray(spot.contents)
			list.append(copy)
			owners.append(room.id)
			copies.append(copy)
		rooms[room.id] = list
	_loot[floor_data.id] = rooms
	if not shuffle:
		return
	var locked := locked_rooms(floor_data)
	var loose: Array[int] = []
	var boxes: Array[int] = []
	for i: int in copies.size():
		var spot := copies[i]
		if spot.kind == LootSpot.KIND_PICKUP:
			if _moves(spot.item_id, items):
				loose.append(i)
		elif not _holds_fixed(spot):
			boxes.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [seed_value, floor_data.id])
	var original: Array[LootSpot] = []
	for spot: LootSpot in copies:
		var keep: LootSpot = spot.duplicate()
		keep.contents = PackedStringArray(spot.contents)
		original.append(keep)
	for attempt: int in MAX_ATTEMPTS:
		_apply(copies, original, loose, _permutation(rng, loose.size()))
		_apply(copies, original, boxes, _permutation(rng, boxes.size()))
		if _valid(copies, owners, locked):
			return
	# Ninguna mezcla válida: el piso se queda como en los datos.
	_apply(copies, original, loose, range(loose.size()))
	_apply(copies, original, boxes, range(boxes.size()))


## Copia el contenido de original[group[order[k]]] en copies[group[k]].
static func _apply(
	copies: Array[LootSpot], original: Array[LootSpot], group: Array[int], order: Array
) -> void:
	for k: int in group.size():
		var target := copies[group[k]]
		var source := original[group[order[k]]]
		target.item_id = source.item_id
		target.count = source.count
		target.durability = source.durability
		target.contents = PackedStringArray(source.contents)


static func _permutation(rng: RandomNumberGenerator, size: int) -> Array:
	var order: Array = range(size)
	# Fisher-Yates con el azar de la partida.
	for i: int in range(size - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = order[i]
		order[i] = order[j]
		order[j] = tmp
	return order


static func _valid(copies: Array[LootSpot], owners: Array[String], locked: Array[String]) -> bool:
	for i: int in copies.size():
		if locked.has(owners[i]) and holds_key_item(copies[i]):
			return false
	return true


## Si un objeto suelto entra en la mezcla (armas, chalecos, curas de la infección y
## desconocidos se quedan).
static func _moves(item_id: String, items: ItemCatalog) -> bool:
	var item := items.get_item(item_id) if items != null else null
	if item == null or FIXED_ITEMS.has(item_id):
		return false
	return item.category != ItemData.CATEGORY_WEAPON and item.category != ItemData.CATEGORY_VEST

class_name GameCatalog
extends Resource
## Catálogo único de datos del juego: todos los objetos, recetas, enemigos y pisos se
## registran aquí.

@export var items: Array[ItemData] = []
@export var recipes: Array[RecipeData] = []
@export var enemies: Array[EnemyData] = []
@export var floors: Array[FloorData] = []
## Piso donde empieza una partida nueva.
@export var start_floor: String = "ground_floor"


## Registro de objetos por identificador para la lógica.
func item_catalog() -> ItemCatalog:
	return ItemCatalog.new(items)


## Contexto para validar una partida guardada: objetos, pisos con sus salidas y zonas seguras.
func save_context() -> Dictionary:
	var item_info: Dictionary = {}
	for item: ItemData in items:
		var magazine := item.weapon.magazine_size if item.weapon != null else 0
		item_info[item.id] = {
			"category": item.category, "max_stack": item.max_stack, "magazine": magazine
		}
	var floor_info: Dictionary = {}
	for floor_data: FloorData in floors:
		var exits: Array[String] = []
		for floor_exit: FloorExit in floor_data.exits:
			exits.append(floor_exit.id)
		var safe_rooms: Array[String] = []
		for room: RoomData in floor_data.rooms:
			if room.safe_zone:
				safe_rooms.append(room.id)
		floor_info[floor_data.id] = {"exits": exits, "safe_rooms": safe_rooms}
	return {
		"items": item_info,
		"floors": floor_info,
		"start_floor": start_floor,
		"capacity": Rules.INVENTORY_SLOTS,
		"phone_parts": Rules.PHONE_PARTS,
	}


func find_floor(floor_id: String) -> FloorData:
	for floor_data: FloorData in floors:
		if floor_data.id == floor_id:
			return floor_data
	return null


func find_enemy(enemy_id: String) -> EnemyData:
	for enemy: EnemyData in enemies:
		if enemy.id == enemy_id:
			return enemy
	return null

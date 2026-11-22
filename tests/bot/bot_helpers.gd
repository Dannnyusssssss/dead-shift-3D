class_name BotHelpers
extends RefCounted
## Consultas del bot de recorrido que solo leen el estado de la partida (mochila, armas,
## combinaciones, enemigos cercanos y a dónde huir); las decisiones las toma bot_session.gd.

## Diferencia de altura a partir de la cual algo está en otro piso.
const SAME_FLOOR: float = 2.0

## Huida sin armas: radios y direcciones que prueba, alejamiento mínimo, ángulo máximo respecto
## a la dirección contraria al enemigo (producto escalar mínimo) y castigo por metro que el
## punto elegido queda fuera del suelo navegable (contra un borde o una pared: arrincona).
const FLEE_RADII: Array[float] = [3.0, 6.0]
const FLEE_DIRECTIONS: int = 16
const FLEE_MIN_STEP: float = 1.5
const FLEE_MIN_DOT: float = -0.2
const EDGE_PENALTY: float = 3.0
## En un espacio abierto conocido (el helipuerto), huye girando en un círculo de este radio a su
## alrededor; prefiere los puntos cercanos con este peso.
const CIRCLE_RADIUS: float = 7.0
const CIRCLE_POINTS: int = 16
const CIRCLE_NEAR_WEIGHT: float = 0.4
## Distancia mínima entre el camino de huida y cualquier enemigo.
const PATH_CLEARANCE: float = 1.6
## Repara con cinta un arma por debajo de esta fracción de durabilidad.
const REPAIR_BELOW: float = 0.5


## Resumen de la mochila («id x cantidad (balas cargadas)») para diagnosticar.
static func inventory_text() -> String:
	var parts: Array[String] = []
	var inventory := GameState.player.inventory
	for index: int in inventory.capacity():
		var stack := inventory.get_slot(index)
		if stack == null:
			continue
		var text := "%s x%d" % [stack.id(), stack.count]
		if stack.is_weapon() and stack.item.weapon.kind == WeaponData.KIND_RANGED:
			text += " (%d cargadas)" % stack.ammo_loaded
		parts.append(text)
	return ", ".join(parts)


static func slot_with(item_id: String) -> int:
	return GameState.player.inventory.find_slot(item_id)


## Balas cargadas más las de reserva para un arma de fuego.
static func ammo_for(stack: ItemStack) -> int:
	if stack == null or stack.item.weapon == null:
		return 0
	return stack.ammo_loaded + GameState.player.inventory.count_of(stack.item.weapon.ammo_item_id)


## Casilla del arma cuerpo a cuerpo sana con más daño (sin contar las que aturden ni la porra,
## que es la reserva débil: con ella el bot no se acerca a pelear), o -1.
static func best_melee_slot() -> int:
	var state := GameState.player
	var best := -1
	var best_damage := 0.0
	for index: int in state.inventory.capacity():
		var stack := state.inventory.get_slot(index)
		if stack == null or not stack.is_weapon() or stack.durability.is_broken():
			continue
		if stack.item.bound:
			continue
		var weapon := stack.item.weapon
		if (
			weapon.kind == WeaponData.KIND_MELEE
			and not weapon.stuns
			and weapon.damage > best_damage
		):
			best = index
			best_damage = weapon.damage
	return best


## Tiene un arma cuerpo a cuerpo sana o un arma de fuego con munición.
static func has_usable_weapon() -> bool:
	var state := GameState.player
	for index: int in state.inventory.capacity():
		var stack := state.inventory.get_slot(index)
		if stack == null or not stack.is_weapon() or stack.durability.is_broken():
			continue
		if stack.item.weapon.kind == WeaponData.KIND_MELEE or ammo_for(stack) > 0:
			return true
	return false


## Verdadero si la única arma que sirve es la porra (no se rompe, pero golpea poco).
static func only_bound_weapon() -> bool:
	var state := GameState.player
	for index: int in state.inventory.capacity():
		var stack := state.inventory.get_slot(index)
		if stack == null or not stack.is_weapon() or stack.item.bound:
			continue
		if stack.durability.is_broken():
			continue
		if stack.item.weapon.kind == WeaponData.KIND_MELEE or ammo_for(stack) > 0:
			return false
	return true


static func weapon_count() -> int:
	var count := 0
	for index: int in GameState.player.inventory.capacity():
		var stack := GameState.player.inventory.get_slot(index)
		if stack != null and stack.is_weapon():
			count += 1
	return count


## Primera combinación que vale la pena hacer ya: [receta, casilla] o vacío. Las reparaciones
## solo si el arma perdió buena parte de su durabilidad; los señuelos no (el bot no los usa).
static func crafting_option() -> Array:
	var crafting := Crafting.new(GameState.CATALOG.recipes, GameState.items)
	var inventory := GameState.player.inventory
	for option: Dictionary in crafting.options(inventory):
		if option["problem"] != Crafting.ERROR_NONE:
			continue
		var recipe: RecipeData = option["recipe"]
		var slot: int = option["slot"]
		if recipe.is_repair():
			if inventory.get_slot(slot).durability.fraction() >= REPAIR_BELOW:
				continue
		else:
			var result := GameState.items.get_item(recipe.result_id)
			if result != null and result.lure_time > 0.0:
				continue
		return [recipe, slot]
	return []


## Enemigos normales vivos en el mismo piso a menos de la distancia dada.
static func enemies_near(player: Player, radius: float, same_floor: float) -> int:
	var count := 0
	for node: Node in player.get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or enemy is Boss:
			continue
		if absf(enemy.global_position.y - player.global_position.y) > same_floor:
			continue
		if enemy.global_position.distance_to(player.global_position) <= radius:
			count += 1
	return count


## Verdadero mientras el jefe exista y no esté vencido.
static func boss_alive(tree: SceneTree) -> bool:
	var boss := tree.get_first_node_in_group("boss") as Boss
	return boss != null and not boss.is_dead()


## Punto al que huir sin armas: solo puntos que de verdad lo alejan (no hacia el enemigo, ni
## proyectados sobre su propia posición contra un borde) y dentro del suelo navegable.
## Vector3.INF si no hay ninguno.
## Posiciones (en planta) de los enemigos normales vivos del piso a menos de la distancia dada.
static func threats_near(player: Player, radius: float, same_floor: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for node: Node in player.get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or enemy is Boss:
			continue
		if absf(enemy.global_position.y - player.global_position.y) > same_floor:
			continue
		if enemy.global_position.distance_to(player.global_position) <= radius:
			result.append(Vector2(enemy.global_position.x, enemy.global_position.z))
	return result


## Punto al que huir girando alrededor de un centro abierto: el del círculo más lejos de todos
## los enemigos cercanos, sin ir demasiado lejos y con un camino que no pase junto a ninguno,
## dentro del suelo navegable. INF si ninguno sirve.
static func circle_point(player: Player, center: Vector3, threats: Array[Vector2]) -> Vector3:
	var map := player.get_world_3d().navigation_map
	var here := Vector2(player.global_position.x, player.global_position.z)
	var best := Vector3.INF
	var best_score := -INF
	for step: int in CIRCLE_POINTS:
		var angle := TAU * float(step) / float(CIRCLE_POINTS)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * CIRCLE_RADIUS
		var candidate := Vector3(center.x, player.global_position.y, center.z) + offset
		var reachable := NavigationServer3D.map_get_closest_point(map, candidate)
		var flat := Vector2(reachable.x, reachable.z)
		if flat.distance_to(Vector2(candidate.x, candidate.z)) > 1.0:
			continue
		if flat.distance_to(here) < FLEE_MIN_STEP:
			continue
		var nearest := INF
		var blocked := false
		for threat: Vector2 in threats:
			nearest = minf(nearest, flat.distance_to(threat))
			var on_path := Geometry2D.get_closest_point_to_segment(threat, here, flat)
			if on_path.distance_to(threat) < PATH_CLEARANCE and threat.distance_to(here) > 0.5:
				blocked = true
		if blocked:
			continue
		var score := nearest - flat.distance_to(here) * CIRCLE_NEAR_WEIGHT
		if score > best_score:
			best = reachable
			best_score = score
	return best


static func flee_point(player: Player, threat: Vector3) -> Vector3:
	var map := player.get_world_3d().navigation_map
	var here := Vector2(player.global_position.x, player.global_position.z)
	var threat_flat := Vector2(threat.x, threat.z)
	var away := (here - threat_flat).normalized()
	var best := Vector3.INF
	var best_score := -INF
	for radius: float in FLEE_RADII:
		for step: int in FLEE_DIRECTIONS:
			var angle := TAU * float(step) / float(FLEE_DIRECTIONS)
			var direction := Vector2(cos(angle), sin(angle))
			if away.length() > 0.0 and direction.dot(away) < FLEE_MIN_DOT:
				continue
			var candidate := (
				player.global_position + Vector3(direction.x, 0.0, direction.y) * radius
			)
			var reachable := NavigationServer3D.map_get_closest_point(map, candidate)
			if absf(reachable.y - player.global_position.y) > 1.0:
				continue
			var flat := Vector2(reachable.x, reachable.z)
			if flat.distance_to(here) < FLEE_MIN_STEP:
				continue
			var score := flat.distance_to(threat_flat)
			score -= flat.distance_to(Vector2(candidate.x, candidate.z)) * EDGE_PENALTY
			if score > best_score:
				best = reachable
				best_score = score
	return best


## Objetos del suelo que le interesan: munición, curas, objetos clave y armas si le faltan.
static func wants(stack: ItemStack) -> bool:
	var category := stack.item.category
	if category == ItemData.CATEGORY_WEAPON:
		return weapon_count() < 4
	# El vial y la jeringa preparan la segunda dosis de Neutrax.
	return (
		category == ItemData.CATEGORY_AMMO
		or category == ItemData.CATEGORY_CONSUMABLE
		or category == ItemData.CATEGORY_KEY
		or stack.id() in ["antiviral_vial", "syringe"]
	)


## Casilla que soltar para hacer sitio a la cura: el arma cuerpo a cuerpo más débil que no sea
## la porra ni la equipada (-1 si no hay ninguna).
static func slot_to_free_for_cure() -> int:
	var state := GameState.player
	var weakest := -1
	for index: int in state.inventory.capacity():
		var stack := state.inventory.get_slot(index)
		if stack == null or not stack.is_weapon() or stack.item.bound:
			continue
		if stack.item.weapon.kind != WeaponData.KIND_MELEE or index == state.equipped_slot:
			continue
		if (
			weakest < 0
			or stack.item.weapon.damage < state.inventory.get_slot(weakest).item.weapon.damage
		):
			weakest = index
	return weakest


## Si hace falta la cura y la mochila está llena, suelta el arma cuerpo a cuerpo más débil.
static func free_room_for_cure(player: Player) -> void:
	if not needs_cure() or not GameState.player.inventory.is_full():
		return
	var spare := slot_to_free_for_cure()
	if spare >= 0:
		player.drop_stack(GameState.player.inventory.take_slot(spare))


## Contenedor al que ir: el del Neutrax si está infectado y sin cura (antes que nada); si no,
## uno marcado en el mapa en su piso. null si no hay.
static func container_to_open(
	building: Building, player_position: Vector3, ignored: Array
) -> LootContainer:
	if needs_cure():
		var cure := cure_container(building, player_position)
		if cure != null:
			return cure
	return marked_container(building.section_at(player_position), player_position, ignored)


## Contenedor de cualquier piso que todavía guarda Neutrax (la farmacia), o null. El bot va a
## por él si se infecta y no lleva cura, como haría un jugador.
static func cure_container(building: Building, player_position: Vector3) -> LootContainer:
	var best: LootContainer = null
	var best_distance := INF
	for section: FloorSection in building.sections:
		for node: Node in section.get_children():
			var box := node as LootContainer
			if box == null or not box.enabled:
				continue
			var has_cure := false
			for entry: String in box.remaining_entries():
				if entry.get_slice(":", 0) == "neutrax":
					has_cure = true
			if not has_cure:
				continue
			var distance := box.global_position.distance_to(player_position)
			if distance < best_distance:
				best = box
				best_distance = distance
	return best


## Infectado y sin nada con qué curarse o ganar tiempo.
static func needs_cure() -> bool:
	var state := GameState.player
	if not state.infection.infected or state.infection.is_converted():
		return false
	return state.inventory.count_of("neutrax") == 0 and state.inventory.count_of("antibiotics") == 0


## Contenedor sin vaciar en una sala que el mapa marca para una pieza o llave que falta, en el
## piso del bot (como un jugador que lee el mapa o la nota y va a buscar allí). null si no hay.
static func marked_container(
	section: FloorSection, player_position: Vector3, ignored: Array
) -> LootContainer:
	if section == null:
		return null
	var keys := GameState.player.keys
	var rooms: Array[String] = []
	for entry: Dictionary in MapMarkers.missing(
		GameState.CATALOG.floors, keys, GameState.loot_plan
	):
		var carrier: String = entry["carrier_key"]
		if entry["floor_id"] == section.floor_data.id and carrier.is_empty():
			rooms.append(entry["room_id"])
	if rooms.is_empty():
		return null
	var best: LootContainer = null
	var best_distance := INF
	for node: Node in section.get_children():
		var box := node as LootContainer
		if box == null or not box.enabled or box.is_empty() or ignored.has(box.get_instance_id()):
			continue
		if not rooms.has(room_of(section.floor_data, box.position)):
			continue
		var distance := box.global_position.distance_to(player_position)
		if distance < best_distance:
			best = box
			best_distance = distance
	return best


## Sala de un piso que contiene un punto (coordenadas del piso), o "".
static func room_of(floor_data: FloorData, local: Vector3) -> String:
	for room: RoomData in floor_data.rooms:
		if room.rect.has_point(Vector2(local.x, local.z)):
			return room.id
	return ""


## Objeto útil cercano en el suelo (munición, curas, objetos clave y armas si faltan), en el
## mismo piso. Un objeto clave se va a buscar a cualquier distancia del piso.
static func nearby_loot(
	tree: SceneTree, player_position: Vector3, ignored: Array, loot_range: float
) -> Pickup:
	var best: Pickup = null
	var best_distance := loot_range
	for node: Node in tree.get_nodes_in_group("pickup"):
		var pickup := node as Pickup
		if pickup == null or not pickup.enabled or pickup.stack == null:
			continue
		if (
			ignored.has(pickup.get_instance_id())
			or not pickup.is_inside_tree()
			or not wants(pickup.stack)
			or absf(pickup.global_position.y - player_position.y) > SAME_FLOOR
		):
			continue
		var offset := pickup.global_position - player_position
		var distance := Vector2(offset.x, offset.z).length()
		if pickup.stack.item.category == ItemData.CATEGORY_KEY:
			distance = minf(distance, 0.0)
		if distance < best_distance:
			best = pickup
			best_distance = distance
	return best


## Leer una nota abre su vista y bloquea al jugador: el bot la cierra en seguida.
static func close_notes(game: Node) -> void:
	for node: Node in game.find_children("*", "NoteView", true, false):
		var view := node as NoteView
		if view.is_open():
			view.close()


## Punto alcanzable (en un círculo de 4 m) que más aleja de la amenaza sin acabar en una nube;
## INF si no hay ninguno.
static func open_distance_point(player: Player, threat: Vector3) -> Vector3:
	var map := player.get_world_3d().navigation_map
	var here := player.global_position
	var best := Vector3.INF
	var best_score := -INF
	for step: int in 12:
		var angle := TAU * float(step) / 12.0
		var candidate := here + Vector3(cos(angle), 0.0, sin(angle)) * 4.0
		var reachable := NavigationServer3D.map_get_closest_point(map, candidate)
		if absf(reachable.y - here.y) > 1.0:
			continue
		var score := _flat(reachable).distance_to(_flat(threat))
		score += _flat(reachable).distance_to(_flat(here)) * 0.5
		for node: Node in player.get_tree().get_nodes_in_group("toxic_cloud"):
			var other := node as ToxicCloud
			if other != null and other.contains(reachable):
				score -= 10.0
		if score > best_score:
			best = reachable
			best_score = score
	return best


## Salida alcanzable más cercana de una nube (contra una pared, la dirección contraria al
## centro puede no tener suelo).
static func cloud_exit_point(player: Player, cloud: ToxicCloud) -> Vector3:
	var map := player.get_world_3d().navigation_map
	var best := Vector3.INF
	var best_distance := INF
	for step: int in 12:
		var angle := TAU * float(step) / 12.0
		var candidate := (
			cloud.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (cloud.radius + 1.5)
		)
		var reachable := NavigationServer3D.map_get_closest_point(map, candidate)
		if _flat(reachable).distance_to(_flat(cloud.global_position)) < cloud.radius + 0.8:
			continue
		var distance := _flat(reachable).distance_to(_flat(player.global_position))
		if distance < best_distance:
			best = reachable
			best_distance = distance
	if best == Vector3.INF:
		best = player.global_position + Vector3.RIGHT * (cloud.radius + 1.5)
	return best


static func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)

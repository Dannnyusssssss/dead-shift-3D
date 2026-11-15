extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Coherencia de los datos del juego (.tres): identificadores válidos y únicos, recetas y botín
## que apuntan a objetos existentes, y límites de accesibilidad de las armas.

const CATALOG_PATH: String = "res://game/data/catalog.tres"

var _catalog: GameCatalog


func before_all() -> void:
	_catalog = load(CATALOG_PATH)


func test_catalog_loads() -> void:
	assert_not_null(_catalog)
	assert_gt(_catalog.items.size(), 0)


func test_item_ids_are_valid_and_unique() -> void:
	var seen: Array[String] = []
	for item: ItemData in _catalog.items:
		assert_true(Validation.is_valid_id(item.id), "id válido: " + item.id)
		assert_false(seen.has(item.id), "id repetido: " + item.id)
		seen.append(item.id)
		assert_false(item.name_key.is_empty(), "nombre por clave: " + item.id)


func test_required_items_exist() -> void:
	var items := _catalog.item_catalog()
	for item_id: String in [
		"pistol", "pistol_ammo", "pipe", "bat", "knife", "nails", "tape", "rag"
	]:
		assert_true(items.has(item_id), "existe " + item_id)
	assert_not_null(_catalog.find_enemy("walker"))
	assert_not_null(_catalog.find_enemy("police_zombie"))


func test_recipes_point_to_existing_items() -> void:
	var items := _catalog.item_catalog()
	for recipe: RecipeData in _catalog.recipes:
		assert_true(items.has(recipe.input_a), recipe.id + ": entrada A")
		if recipe.is_repair():
			assert_lt(recipe.repair_fraction, 1.01, recipe.id + ": reparación parcial")
		else:
			assert_true(items.has(recipe.input_b), recipe.id + ": entrada B")
			assert_true(items.has(recipe.result_id), recipe.id + ": resultado")
		assert_gt(recipe.craft_time, 0.0, recipe.id + ": combinar toma tiempo")


func test_enemy_loot_points_to_existing_items() -> void:
	var items := _catalog.item_catalog()
	for enemy: EnemyData in _catalog.enemies:
		if enemy.ammo_max > 0:
			assert_true(items.has(enemy.ammo_item_id), enemy.id + ": munición")
		if enemy.vest_chance > 0.0:
			assert_true(items.has(enemy.vest_item_id), enemy.id + ": chaleco")


func test_walker_drops_nothing_by_data() -> void:
	var walker := _catalog.find_enemy("walker")
	assert_eq(walker.ammo_max, 0)
	assert_eq(walker.vest_chance, 0.0)


func test_firearms_respect_flash_limit() -> void:
	# Un destello por disparo: con 0.34 s o más entre disparos nunca hay más de 3 por segundo.
	for item: ItemData in _catalog.items:
		if item.weapon != null and item.weapon.kind == WeaponData.KIND_RANGED:
			assert_gte(item.weapon.attack_interval, 0.34, item.id)
			assert_true(
				_catalog.item_catalog().has(item.weapon.ammo_item_id), item.id + ": munición"
			)


func test_combined_weapons_wear_differently() -> void:
	var items := _catalog.item_catalog()
	var bat := items.get_item("bat").weapon
	var bat_nails := items.get_item("bat_nails").weapon
	assert_gt(bat_nails.damage, bat.damage, "más daño")
	assert_lt(
		bat_nails.max_durability / bat_nails.wear_per_hit, bat.max_durability / bat.wear_per_hit
	)
	var pipe := items.get_item("pipe").weapon
	var pipe_grip := items.get_item("pipe_grip").weapon
	assert_lt(pipe_grip.attack_interval, pipe.attack_interval, "golpea más rápido")


func test_knife_is_silent_and_pistol_very_loud() -> void:
	var items := _catalog.item_catalog()
	assert_eq(items.get_item("knife").weapon.noise_level, Rules.NOISE_SILENT)
	assert_eq(items.get_item("pistol").weapon.noise_level, Rules.NOISE_VERY_HIGH)


## Todos los identificadores de objeto que aparecen en un piso (sueltos y en contenedores).
func _floor_items(floor_data: FloorData) -> Dictionary:
	var counts: Dictionary = {}
	for room: RoomData in floor_data.rooms:
		for spot: LootSpot in room.loot:
			if spot.kind == LootSpot.KIND_PICKUP:
				counts[spot.item_id] = int(counts.get(spot.item_id, 0)) + spot.count
			for entry: String in spot.contents:
				var parts := entry.split(":")
				var amount := parts[1].to_int() if parts.size() > 1 else 1
				counts[parts[0]] = int(counts.get(parts[0], 0)) + amount
	return counts


func test_floors_are_registered_and_start_floor_exists() -> void:
	assert_gt(_catalog.floors.size(), 1)
	assert_not_null(_catalog.find_floor(_catalog.start_floor))


func test_floor_loot_points_to_existing_items() -> void:
	var items := _catalog.item_catalog()
	for floor_data: FloorData in _catalog.floors:
		for item_id: String in _floor_items(floor_data):
			assert_true(items.has(item_id), "%s: %s" % [floor_data.id, item_id])


func _in_any(rects: Array[Rect2], point: Vector3) -> bool:
	for rect: Rect2 in rects:
		if rect.has_point(Vector2(point.x, point.z)):
			return true
	return false


func _on_floor(floor_data: FloorData, point: Vector3) -> bool:
	var rooms: Array[Rect2] = []
	for room: RoomData in floor_data.rooms:
		if room.has_floor or room.outdoor:
			rooms.append(room.rect)
	return _in_any(rooms, point) and not _in_any(floor_data.holes, point)


func _floor_at_level(index: int) -> FloorData:
	for floor_data: FloorData in _catalog.floors:
		if floor_data.level_index == index:
			return floor_data
	return null


func test_floors_stack_without_gaps() -> void:
	var seen: Array[int] = []
	for floor_data: FloorData in _catalog.floors:
		assert_false(seen.has(floor_data.level_index), floor_data.id + ": índice repetido")
		seen.append(floor_data.level_index)
	for index: int in seen.size():
		assert_true(seen.has(index), "falta el piso %d" % index)


func test_landings_and_spawn_stand_on_solid_floor() -> void:
	for floor_data: FloorData in _catalog.floors:
		assert_true(_on_floor(floor_data, floor_data.player_spawn), floor_data.id + ": inicio")
		for floor_exit: FloorExit in floor_data.exits:
			var where := "%s/%s" % [floor_data.id, floor_exit.id]
			assert_true(_on_floor(floor_data, floor_exit.arrival), where)


func test_ramps_have_headroom_and_land_on_the_floor_above() -> void:
	for floor_data: FloorData in _catalog.floors:
		var above := _floor_at_level(floor_data.level_index + 1)
		for index: int in floor_data.ramps.size():
			var ramp: RampSpec = floor_data.ramps[index]
			var where := "%s/rampa %d" % [floor_data.id, index]
			assert_not_null(above, where + ": no hay piso arriba")
			if above == null:
				continue
			for step: int in range(1, 20):
				var t := float(step) / 20.0
				var point := ramp.start + ramp.forward() * (ramp.run * t)
				var height := ramp.start.y + ramp.rise * t
				if height + Rules.PLAYER_EYE_HEIGHT + 0.3 > Rules.ROOM_HEIGHT:
					assert_true(_in_any(above.holes, point), where + ": sin hueco encima")
			var top := ramp.start.y + ramp.rise
			if is_equal_approx(top, Rules.FLOOR_HEIGHT):
				var landing := ramp.start + ramp.forward() * (ramp.run + 0.4)
				assert_true(_on_floor(above, landing), where + ": no llega a un suelo")


func test_neutrax_has_exactly_two_doses_in_the_whole_game() -> void:
	var total := 0
	for floor_data: FloorData in _catalog.floors:
		total += int(_floor_items(floor_data).get("neutrax", 0))
	assert_eq(total, 2)


func test_gates_needing_a_key_have_that_key_in_the_game() -> void:
	var available: Dictionary = {}
	for floor_data: FloorData in _catalog.floors:
		available.merge(_floor_items(floor_data))
		for spawn: EnemySpawn in floor_data.enemies:
			if spawn.enemy.boss != null:
				available[spawn.enemy.boss.drop_key_item] = 1
	for floor_data: FloorData in _catalog.floors:
		for gate: GateSpec in floor_data.gates:
			assert_false(gate.flag.is_empty(), gate.id + ": marca")
			if not gate.required_item.is_empty():
				assert_true(available.has(gate.required_item), gate.id + ": llave en el juego")


func test_key_items_are_single_and_phone_parts_exist() -> void:
	var items := _catalog.item_catalog()
	for item_id: String in ["security_key", "phone_antenna", "phone_battery", "phone_board"]:
		var item := items.get_item(item_id)
		assert_not_null(item, item_id)
		if item != null:
			assert_eq(item.category, ItemData.CATEGORY_KEY, item_id)


func test_boss_exists_once_and_drops_an_existing_key() -> void:
	var bosses := 0
	for floor_data: FloorData in _catalog.floors:
		for spawn: EnemySpawn in floor_data.enemies:
			if spawn.enemy.boss != null:
				bosses += 1
				assert_true(_catalog.item_catalog().has(spawn.enemy.boss.drop_key_item))
	assert_eq(bosses, 1)


func test_shotgun_shells_are_nearly_exact_for_the_boss() -> void:
	# Con todos los cartuchos del juego se puede vencer al jefe acertando al tanque, pero no
	# disparándole siempre de frente: la escopeta es la mejor opción, no una victoria segura.
	var shells := 0
	for floor_data: FloorData in _catalog.floors:
		shells += int(_floor_items(floor_data).get("shotgun_shells", 0))
	var boss := _catalog.find_enemy("technician").boss
	var shotgun := _catalog.item_catalog().get_item("shotgun").weapon
	var total := boss.phase_one_health + boss.phase_two_health
	assert_gte(shells * shotgun.damage * boss.tank_multiplier, total, "alcanza acertando al tanque")
	var front := shells * shotgun.damage * boss.phase_one_front_multiplier
	assert_lt(front, total, "de frente no alcanza")
	assert_lte(shells, 10, "pocos cartuchos")

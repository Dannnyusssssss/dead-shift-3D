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

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Dificultades: Fácil deja todo exactamente igual; Medio y Difícil aplican su tabla (enemigos,
## munición, vendas, contagio, jefe, helicóptero, oleadas y autoguardado). Los datos reales del
## catálogo cumplen la tabla del plan.

const Fixtures = preload("res://tests/helpers/fixtures.gd")
const CATALOG: GameCatalog = preload("res://game/data/catalog.tres")


func _difficulty(difficulty_id: String) -> Difficulty:
	return Difficulty.new(CATALOG.find_difficulty(difficulty_id))


func test_catalog_offers_the_three_difficulties_in_order() -> void:
	assert_eq(CATALOG.difficulty_ids(), Difficulty.IDS)
	assert_eq(CATALOG.find_difficulty("desconocida").id, Difficulty.EASY, "desconocida = Fácil")


func test_easy_keeps_every_current_value() -> void:
	for difficulty: Difficulty in [_difficulty(Difficulty.EASY), Difficulty.new()]:
		assert_eq(difficulty.enemy_health(110.0), 110.0)
		assert_eq(difficulty.enemy_damage(18.0), 18.0)
		assert_eq(difficulty.infection_chance(0.15), 0.15)
		assert_eq(difficulty.boss_health_multiplier(), 1.0)
		assert_eq(difficulty.helicopter_wait_time(), Rules.HELICOPTER_WAIT_TIME)
		assert_eq(difficulty.waves([2, 2, 3, 3, 4, 4]), [2, 2, 3, 3, 4, 4])
		assert_true(difficulty.autosave_on_floor_change())
		for count: int in [1, 2, 3, 4, 6, 8]:
			assert_eq(difficulty.ammo_found(count), count)
		var loot := difficulty.floor_loot()
		assert_eq(loot.adjust("bandage", ItemData.CATEGORY_CONSUMABLE, 1), 1, "vendas iguales")


func test_medium_values() -> void:
	var medium := _difficulty(Difficulty.MEDIUM)
	assert_almost_eq(medium.enemy_health(100.0), 125.0, 0.001)
	assert_almost_eq(medium.enemy_damage(20.0), 25.0, 0.001)
	assert_gt(medium.infection_chance(0.2), 0.2)
	assert_almost_eq(medium.boss_health_multiplier(), 1.2, 0.001)
	assert_eq(medium.helicopter_wait_time(), 60.0)
	assert_eq(medium.ammo_found(8), 6, "−25 %")
	assert_eq(medium.ammo_found(4), 3)
	assert_eq(medium.ammo_found(1), 1, "nunca menos de 1")
	assert_true(medium.autosave_on_floor_change())
	var loot := medium.floor_loot()
	assert_eq(loot.adjust("bandage", ItemData.CATEGORY_CONSUMABLE, 1), 1, "vendas iguales")


func test_hard_values() -> void:
	var hard := _difficulty(Difficulty.HARD)
	var medium := _difficulty(Difficulty.MEDIUM)
	assert_almost_eq(hard.enemy_health(100.0), 150.0, 0.001)
	assert_almost_eq(hard.enemy_damage(20.0), 30.0, 0.001)
	assert_gt(hard.infection_chance(0.2), medium.infection_chance(0.2))
	assert_almost_eq(hard.boss_health_multiplier(), 1.4, 0.001)
	assert_eq(hard.helicopter_wait_time(), 45.0)
	assert_eq(hard.ammo_found(10), 6, "−40 %")
	assert_false(hard.autosave_on_floor_change(), "solo zonas seguras")


func test_infection_chance_never_exceeds_one() -> void:
	assert_eq(_difficulty(Difficulty.HARD).infection_chance(0.9), 1.0)
	assert_eq(_difficulty(Difficulty.HARD).infection_chance(0.0), 0.0)


func test_waves_grow_and_never_shrink() -> void:
	var base: Array[int] = [2, 2, 3, 3, 4, 4]
	var medium := _difficulty(Difficulty.MEDIUM).waves(base)
	var hard := _difficulty(Difficulty.HARD).waves(base)
	assert_eq(medium, [2, 2, 3, 3, 5, 5])
	assert_eq(hard, [3, 3, 5, 5, 6, 6])
	for index: int in base.size():
		assert_true(hard[index] >= medium[index] and medium[index] >= base[index])


func test_hard_removes_one_bandage_per_floor_in_order() -> void:
	var loot := _difficulty(Difficulty.HARD).floor_loot()
	assert_eq(loot.adjust("rag", ItemData.CATEGORY_MATERIAL, 1), 1, "otros objetos iguales")
	assert_eq(loot.adjust("bandage", ItemData.CATEGORY_CONSUMABLE, 2), 1, "la primera pierde una")
	assert_eq(loot.adjust("bandage", ItemData.CATEGORY_CONSUMABLE, 1), 1, "las demás se quedan")
	var next_floor := _difficulty(Difficulty.HARD).floor_loot()
	assert_eq(next_floor.adjust("bandage", ItemData.CATEGORY_CONSUMABLE, 1), 0, "otro piso, otra")


func test_container_contents_are_adjusted() -> void:
	var items := CATALOG.item_catalog()
	var loot := _difficulty(Difficulty.HARD).floor_loot()
	var contents := PackedStringArray(["pistol_ammo:8", "bandage:1", "tape:1", "nada:3"])
	assert_eq(
		loot.adjust_contents(contents, items),
		PackedStringArray(["pistol_ammo:4", "tape:1", "nada:3"]),
		"munición −40 %, venda quitada, desconocido sin tocar"
	)
	var easy := _difficulty(Difficulty.EASY).floor_loot()
	assert_eq(easy.adjust_contents(contents, items), contents, "Fácil: igual")


func test_enemy_health_and_boss_scale() -> void:
	var walker: EnemyData = load("res://game/data/enemies/walker.tres")
	var hard := _difficulty(Difficulty.HARD)
	var rng := RandomNumberGenerator.new()
	var health := EnemyHealth.new(walker, rng, 100.0, 0, hard.enemy_health(1.0))
	assert_almost_eq(health.health, walker.max_health * 1.5, 0.001)
	var boss_data: EnemyData = load("res://game/data/enemies/technician.tres")
	var boss := BossModel.new(boss_data.boss, hard.boss_health_multiplier())
	assert_almost_eq(boss.health, boss_data.boss.phase_one_health * 1.4, 0.001)
	assert_eq(boss.health_fraction(), 1.0)
	boss.take_hit(boss.health + 1.0, true)
	assert_eq(boss.phase, BossModel.PHASE_TWO)
	assert_almost_eq(boss.health, boss_data.boss.phase_two_health * 1.4, 0.001)


func test_police_drops_less_ammo_on_hard() -> void:
	var police: EnemyData = load("res://game/data/enemies/police_zombie.tres")
	var items := CATALOG.item_catalog()
	var easy_total := 0
	var hard_total := 0
	for seed_value: int in 20:
		var enemy := EnemyHealth.new(police, Fixtures.rng(seed_value), 100.0, 0)
		var easy_rng := Fixtures.rng(seed_value)
		var hard_rng := Fixtures.rng(seed_value)
		for stack: ItemStack in LootRoller.roll(enemy, items, easy_rng, _difficulty("easy")):
			easy_total += stack.count
		for stack: ItemStack in LootRoller.roll(enemy, items, hard_rng, _difficulty("hard")):
			hard_total += stack.count
	assert_gt(easy_total, 0)
	assert_lt(hard_total, easy_total)


func test_rescue_clock_uses_the_difficulty_wait() -> void:
	var clock := RescueClock.new(10.0, _difficulty(Difficulty.HARD).helicopter_wait_time())
	clock.call_helicopter()
	clock.tick(10.0, false)
	assert_eq(clock.state, RescueClock.STATE_WAITING)
	assert_eq(clock.time_left, 45.0)

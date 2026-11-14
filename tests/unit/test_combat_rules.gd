extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Daño con y sin chaleco, chaleco del policía y botín.

const Fixtures = preload("res://tests/helpers/fixtures.gd")


func _police(vest_chance: float = 1.0) -> EnemyData:
	var data := EnemyData.new()
	data.id = "police_zombie"
	data.max_health = 100.0
	data.ammo_item_id = "ammo"
	data.ammo_min = 3
	data.ammo_max = 8
	data.vest_chance = vest_chance
	data.vest_item_id = "vest"
	data.vest_damage_reduction = 0.5
	data.vest_wear_per_damage = 2.0
	return data


func _catalog() -> ItemCatalog:
	return ItemCatalog.new([Fixtures.material("ammo", 60), Fixtures.vest()])


func _with_vest(seed_value: int = 1) -> EnemyHealth:
	return EnemyHealth.new(_police(), Fixtures.rng(seed_value), 100.0, 1)


func test_player_damage_without_vest() -> void:
	assert_eq(DamageModel.player_damage(20.0, null), 20.0)


func test_player_damage_with_vest_reduces_and_wears() -> void:
	var vest := ItemStack.new(Fixtures.vest(0.5, 1.0))
	assert_eq(DamageModel.player_damage(20.0, vest), 10.0)
	assert_eq(vest.durability.current, 90.0, "se desgasta lo absorbido")


func test_broken_vest_does_not_protect() -> void:
	var vest := ItemStack.new(Fixtures.vest(), 1, 0.0)
	assert_eq(DamageModel.player_damage(20.0, vest), 20.0)


func test_negative_damage_is_zero() -> void:
	assert_eq(DamageModel.player_damage(-5.0, null), 0.0)


func test_shooting_police_vest_reduces_damage_and_wears_vest() -> void:
	var police := _with_vest()
	assert_eq(police.take_hit(20.0, Rules.ZONE_VEST, true), 10.0)
	assert_eq(police.vest_durability.current, 80.0)


func test_knife_on_vest_does_not_wear_it() -> void:
	var police := _with_vest()
	assert_eq(police.take_hit(20.0, Rules.ZONE_VEST, false), 20.0)
	assert_eq(police.vest_durability.fraction(), 1.0)


func test_headshot_multiplier_and_death() -> void:
	var police := EnemyHealth.new(_police(), Fixtures.rng(), 100.0, 0)
	police.take_hit(50.0, Rules.ZONE_HEAD, true)
	assert_true(police.is_dead())
	assert_eq(police.take_hit(10.0, Rules.ZONE_BODY, true), 0.0, "muerto no recibe más")


func test_vest_override_and_random_vest() -> void:
	assert_false(EnemyHealth.new(_police(), Fixtures.rng(), 100.0, 0).has_vest)
	assert_true(_with_vest().has_vest)
	var never := EnemyHealth.new(_police(0.0), Fixtures.rng(), 100.0, 1)
	assert_false(never.has_vest, "sin chaleco posible")


func test_police_loot_is_reproducible_with_seed() -> void:
	var first := LootRoller.roll(_with_vest(7), _catalog(), Fixtures.rng(7))
	var second := LootRoller.roll(_with_vest(7), _catalog(), Fixtures.rng(7))
	assert_eq(first.size(), 2)
	assert_eq(first[0].count, second[0].count)
	assert_between(first[0].count, 3, 8)


func test_police_vest_keeps_condition_after_shots() -> void:
	var police := _with_vest()
	police.take_hit(20.0, Rules.ZONE_VEST, true)
	var drops := LootRoller.roll(police, _catalog(), Fixtures.rng())
	assert_almost_eq(drops[1].durability.fraction(), 0.8, 0.0001)


func test_knife_kill_leaves_better_vest_than_shots() -> void:
	var by_knife := _with_vest()
	var by_gun := _with_vest()
	while not by_knife.is_dead():
		by_knife.take_hit(20.0, Rules.ZONE_VEST, false)
	while not by_gun.is_dead():
		by_gun.take_hit(20.0, Rules.ZONE_VEST, true)
	assert_gt(by_knife.vest_durability.fraction(), by_gun.vest_durability.fraction())


func test_broken_vest_is_not_dropped() -> void:
	var police := _with_vest()
	police.vest_durability.wear(1000.0)
	var drops := LootRoller.roll(police, _catalog(), Fixtures.rng())
	assert_eq(drops.size(), 1, "solo balas")


func test_walker_drops_nothing() -> void:
	var walker := EnemyData.new()
	walker.id = "walker"
	var drops := LootRoller.roll(
		EnemyHealth.new(walker, Fixtures.rng()), _catalog(), Fixtures.rng()
	)
	assert_eq(drops.size(), 0)

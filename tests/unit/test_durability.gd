extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Desgaste: estados en tres pasos, rotura en el momento exacto y reparación.


func test_unbreakable_never_breaks() -> void:
	var durability := Durability.new(0.0)
	assert_true(durability.is_unbreakable())
	assert_false(durability.wear(1000.0))
	assert_false(durability.is_broken())
	assert_eq(durability.state(), Durability.STATE_GOOD)
	assert_eq(durability.fraction(), 1.0)


func test_states_follow_thresholds() -> void:
	var durability := Durability.new(100.0)
	assert_eq(durability.state(), Durability.STATE_GOOD)
	durability.wear(100.0 * (1.0 - Rules.DURABILITY_DAMAGED) + 1.0)
	assert_eq(durability.state(), Durability.STATE_DAMAGED)
	durability.current = 100.0 * Rules.DURABILITY_CRITICAL - 1.0
	assert_eq(durability.state(), Durability.STATE_CRITICAL)


func test_wear_reports_break_only_once() -> void:
	var durability := Durability.new(10.0)
	assert_false(durability.wear(9.0))
	assert_true(durability.wear(5.0), "se rompe en este golpe")
	assert_true(durability.is_broken())
	assert_eq(durability.state(), Durability.STATE_BROKEN)
	assert_false(durability.wear(1.0), "ya estaba rota")


func test_negative_wear_is_ignored() -> void:
	var durability := Durability.new(10.0)
	durability.wear(-5.0)
	assert_eq(durability.current, 10.0)


func test_repair_adds_fraction_and_caps() -> void:
	var durability := Durability.new(100.0, 0.2)
	durability.repair(0.5)
	assert_almost_eq(durability.fraction(), 0.7, 0.0001)
	durability.repair(1.0)
	assert_eq(durability.fraction(), 1.0)


func test_broken_item_cannot_be_repaired() -> void:
	var durability := Durability.new(10.0, 0.0)
	durability.repair(0.5)
	assert_true(durability.is_broken())


func test_initial_fraction_is_clamped() -> void:
	assert_eq(Durability.new(10.0, 5.0).fraction(), 1.0)
	assert_eq(Durability.new(10.0, -1.0).fraction(), 0.0)

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Linterna: se gasta solo encendida, baja poco a poco con poca carga, deja una luz mínima al
## agotarse, cambia las pilas de la bolsa sola y guarda su estado.

const Fixtures = preload("res://tests/helpers/fixtures.gd")


func _bag(batteries: int) -> MaterialBag:
	var bag := MaterialBag.new()
	if batteries > 0:
		bag.add(Fixtures.material(Flashlight.BATTERY_ITEM, 6), batteries)
	return bag


func test_starts_off_and_full() -> void:
	var torch := Flashlight.new()
	assert_false(torch.on)
	assert_eq(torch.charge, Rules.FLASHLIGHT_SECONDS)
	assert_eq(torch.level(), 0.0, "apagada no alumbra")


func test_drains_only_while_on() -> void:
	var torch := Flashlight.new()
	torch.tick(10.0, _bag(0))
	assert_eq(torch.charge, Rules.FLASHLIGHT_SECONDS, "apagada no gasta")
	assert_true(torch.toggle())
	torch.tick(10.0, _bag(0))
	assert_eq(torch.charge, Rules.FLASHLIGHT_SECONDS - 10.0)
	assert_false(torch.toggle())


func test_level_dims_when_low_and_keeps_an_emergency_light() -> void:
	var torch := Flashlight.new()
	torch.on = true
	assert_eq(torch.level(), 1.0)
	torch.charge = Flashlight.LOW_CHARGE * 0.5
	assert_between(torch.level(), Flashlight.LOW_LEVEL, 1.0, "baja poco a poco")
	torch.charge = 0.0
	assert_true(torch.is_empty())
	assert_eq(torch.level(), Flashlight.EMERGENCY_LEVEL, "nunca a ciegas")


func test_swaps_batteries_from_the_bag_when_empty() -> void:
	var torch := Flashlight.new()
	torch.on = true
	torch.charge = 1.0
	var bag := _bag(2)
	assert_true(torch.tick(2.0, bag), "cambió las pilas")
	assert_eq(torch.charge, Rules.FLASHLIGHT_SECONDS)
	assert_eq(bag.count(Flashlight.BATTERY_ITEM), 1)


func test_without_batteries_stays_empty() -> void:
	var torch := Flashlight.new()
	torch.on = true
	torch.charge = 1.0
	assert_false(torch.tick(5.0, _bag(0)))
	assert_eq(torch.charge, 0.0)
	assert_false(torch.tick(5.0, null), "sin bolsa tampoco falla")


func test_save_data_round_trip_and_clamp() -> void:
	var torch := Flashlight.new()
	torch.on = true
	torch.charge = 33.0
	var copy := Flashlight.new()
	copy.load_data(torch.to_data())
	assert_true(copy.on)
	assert_eq(copy.charge, 33.0)
	copy.load_data({"charge": 99999.0})
	assert_eq(copy.charge, Rules.FLASHLIGHT_SECONDS, "nunca más de una carga")


func test_fraction_for_the_hud() -> void:
	var torch := Flashlight.new()
	torch.charge = Rules.FLASHLIGHT_SECONDS * 0.25
	assert_almost_eq(torch.fraction(), 0.25, 0.0001)

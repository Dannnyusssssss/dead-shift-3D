extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Infección: exposición que se llena con cada golpe y baja sola, cuenta regresiva,
## antibióticos que frenan, Neutrax que cura y conversión al llegar a cero.

const Fixtures = preload("res://tests/helpers/fixtures.gd")


func _infected() -> Infection:
	var infection := Infection.new()
	infection.add_exposure(1.0)
	return infection


func test_exposure_fills_with_each_bite_and_infects_when_full() -> void:
	var infection := Infection.new()
	assert_eq(infection.hits_left(0.25), 4, "caminante: cuatro golpes")
	for _bite: int in 3:
		assert_false(infection.add_exposure(0.25))
	assert_eq(infection.hits_left(0.25), 1)
	assert_true(infection.add_exposure(0.25), "el cuarto infecta")
	assert_true(infection.infected)
	assert_eq(infection.time_left, Rules.INFECTION_TIME)
	assert_eq(infection.exposure, 0.0, "con infección la barra deja paso a la cuenta")
	assert_eq(infection.hits_left(0.25), 0)


func test_no_exposure_never_infects() -> void:
	var infection := Infection.new()
	for _bite: int in 50:
		infection.add_exposure(0.0)
	assert_false(infection.infected)
	assert_eq(infection.exposure, 0.0)


func test_exposure_decays_only_after_a_while_without_hits() -> void:
	var infection := Infection.new()
	infection.add_exposure(0.5)
	infection.tick(Rules.EXPOSURE_DECAY_DELAY - 1.0)
	assert_eq(infection.exposure, 0.5, "justo después de un golpe no baja")
	infection.tick(2.0)
	assert_lt(infection.exposure, 0.5, "después baja sola")
	infection.add_exposure(0.1)
	var after_hit := infection.exposure
	infection.tick(1.0)
	assert_eq(infection.exposure, after_hit, "un golpe nuevo vuelve a esperar")
	infection.tick(1000.0)
	assert_eq(infection.exposure, 0.0, "nunca baja de cero")


func test_new_bite_does_not_reset_the_countdown() -> void:
	var infection := _infected()
	infection.tick(30.0)
	assert_false(infection.add_exposure(1.0))
	assert_almost_eq(infection.time_left, Rules.INFECTION_TIME - 30.0, 0.001)


func test_countdown_reaches_zero_and_converts_once() -> void:
	var infection := _infected()
	assert_false(infection.tick(Rules.INFECTION_TIME - 1.0))
	assert_true(infection.tick(2.0), "llega a cero")
	assert_true(infection.is_converted())
	assert_false(infection.tick(1.0), "solo avisa una vez")


func test_antibiotics_add_time_without_passing_the_full_countdown() -> void:
	var infection := _infected()
	assert_false(infection.can_add_time(), "recién contagiado no hay nada que sumar")
	assert_eq(infection.add_time(Rules.ANTIBIOTIC_BONUS), 0.0)
	infection.tick(150.0)
	assert_true(infection.can_add_time())
	var gained := infection.add_time(Rules.ANTIBIOTIC_BONUS)
	assert_almost_eq(gained, Rules.ANTIBIOTIC_BONUS, 0.001, "suma todo")
	assert_almost_eq(infection.time_left, Rules.INFECTION_TIME - 60.0, 0.001)
	gained = infection.add_time(Rules.ANTIBIOTIC_BONUS)
	assert_almost_eq(gained, 60.0, 0.001, "solo hasta la cuenta inicial")
	assert_almost_eq(infection.time_left, Rules.INFECTION_TIME, 0.001)
	infection.tick(10.0)
	assert_almost_eq(infection.time_left, Rules.INFECTION_TIME - 10.0, 0.001, "ritmo normal")


func test_antibiotics_and_cure_need_an_infection() -> void:
	var healthy := Infection.new()
	assert_eq(healthy.add_time(Rules.ANTIBIOTIC_BONUS), 0.0)
	assert_false(healthy.cure())


func test_neutrax_cures() -> void:
	var infection := _infected()
	infection.tick(100.0)
	infection.add_time(Rules.ANTIBIOTIC_BONUS)
	assert_true(infection.cure())
	assert_false(infection.infected)
	assert_eq(infection.exposure, 0.0, "la exposición queda a cero")
	assert_false(infection.tick(Rules.INFECTION_TIME * 2.0), "ya no hay cuenta")


func test_cannot_cure_after_conversion() -> void:
	var infection := _infected()
	infection.tick(Rules.INFECTION_TIME)
	assert_false(infection.cure())

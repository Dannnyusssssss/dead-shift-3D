extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Infección: contagio con azar inyectado, cuenta regresiva, antibióticos que frenan, Neutrax
## que cura y conversión al llegar a cero.

const Fixtures = preload("res://tests/helpers/fixtures.gd")


func _infected() -> Infection:
	var infection := Infection.new()
	infection.try_infect(1.0, Fixtures.rng())
	return infection


func test_chance_zero_never_and_one_always_infects() -> void:
	var rng := Fixtures.rng()
	var safe := Infection.new()
	for _bite: int in 50:
		safe.try_infect(0.0, rng)
	assert_false(safe.infected)
	var sure := Infection.new()
	assert_true(sure.try_infect(1.0, rng))
	assert_eq(sure.time_left, Rules.INFECTION_TIME)


func test_same_seed_gives_same_result() -> void:
	var results: Array[bool] = []
	for _run: int in 2:
		var rng := Fixtures.rng(77)
		var infection := Infection.new()
		var bites := 0
		while not infection.try_infect(0.3, rng) and bites < 100:
			bites += 1
		results.append(bites < 100)
		assert_true(infection.infected)
	assert_eq(results[0], results[1])


func test_new_bite_does_not_reset_the_countdown() -> void:
	var infection := _infected()
	infection.tick(30.0)
	assert_false(infection.try_infect(1.0, Fixtures.rng()))
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
	assert_false(infection.tick(Rules.INFECTION_TIME * 2.0), "ya no hay cuenta")


func test_cannot_cure_after_conversion() -> void:
	var infection := _infected()
	infection.tick(Rules.INFECTION_TIME)
	assert_false(infection.cure())

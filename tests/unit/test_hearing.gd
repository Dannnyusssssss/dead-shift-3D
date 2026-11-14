extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Memoria de ruido de un enemigo: prioridad entre ruidos, olvido con el tiempo y sordera.


func test_deaf_listener_ignores_everything() -> void:
	var hearing := Hearing.new(0.0)
	assert_true(hearing.is_deaf())
	assert_false(hearing.hear(Vector3.ZERO, Vector3(1, 0, 0), Rules.NOISE_VERY_HIGH))
	assert_false(hearing.has_target)


func test_hears_noise_in_range_and_ignores_out_of_range() -> void:
	var hearing := Hearing.new(1.0)
	assert_false(hearing.hear(Vector3.ZERO, Vector3(20, 0, 0), Rules.NOISE_MEDIUM))
	assert_true(hearing.hear(Vector3.ZERO, Vector3(5, 0, 0), Rules.NOISE_MEDIUM))
	assert_eq(hearing.target, Vector3(5, 0, 0))


func test_louder_noise_takes_priority() -> void:
	var hearing := Hearing.new(1.0)
	hearing.hear(Vector3.ZERO, Vector3(3, 0, 0), Rules.NOISE_LOW)
	assert_true(hearing.hear(Vector3.ZERO, Vector3(-12, 0, 0), Rules.NOISE_VERY_HIGH))
	assert_eq(hearing.target, Vector3(-12, 0, 0), "el disparo gana")


func test_weaker_noise_does_not_replace_current() -> void:
	var hearing := Hearing.new(1.0)
	hearing.hear(Vector3.ZERO, Vector3(5, 0, 0), Rules.NOISE_HIGH)
	assert_false(hearing.hear(Vector3.ZERO, Vector3(2, 0, 0), Rules.NOISE_LOW))
	assert_eq(hearing.target, Vector3(5, 0, 0))


func test_memory_fades_so_newer_weaker_noise_wins_later() -> void:
	var hearing := Hearing.new(1.0)
	hearing.hear(Vector3.ZERO, Vector3(5, 0, 0), Rules.NOISE_HIGH)
	for _second: int in 20:
		hearing.tick(1.0)
	assert_true(hearing.hear(Vector3.ZERO, Vector3(2, 0, 0), Rules.NOISE_LOW))
	assert_eq(hearing.target, Vector3(2, 0, 0))


func test_wall_makes_noise_weaker() -> void:
	var hearing := Hearing.new(1.0)
	hearing.hear(Vector3.ZERO, Vector3(6, 0, 0), Rules.NOISE_HIGH, 1)
	var behind_wall := hearing.strength
	hearing.clear()
	hearing.hear(Vector3.ZERO, Vector3(6, 0, 0), Rules.NOISE_HIGH, 0)
	assert_gt(hearing.strength, behind_wall)


func test_clear_forgets_the_noise() -> void:
	var hearing := Hearing.new(1.0)
	hearing.hear(Vector3.ZERO, Vector3(1, 0, 0), Rules.NOISE_MEDIUM)
	hearing.clear()
	assert_false(hearing.has_target)
	assert_eq(hearing.strength, 0.0)

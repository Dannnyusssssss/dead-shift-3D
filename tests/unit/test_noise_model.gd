extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Ruido: radio por nivel, silencio y niveles fuera de rango.


func test_radius_grows_with_level() -> void:
	assert_eq(NoiseModel.radius_for(Rules.NOISE_SILENT), 0.0)
	assert_lt(NoiseModel.radius_for(Rules.NOISE_LOW), NoiseModel.radius_for(Rules.NOISE_MEDIUM))
	assert_lt(NoiseModel.radius_for(Rules.NOISE_HIGH), NoiseModel.radius_for(Rules.NOISE_VERY_HIGH))


func test_invalid_level_is_silent() -> void:
	assert_eq(NoiseModel.radius_for(-1), 0.0)
	assert_eq(NoiseModel.radius_for(99), 0.0)


func test_can_hear_inside_radius_only() -> void:
	var radius := NoiseModel.radius_for(Rules.NOISE_MEDIUM)
	var near := Vector3(radius - 0.1, 0, 0)
	var far := Vector3(radius + 0.1, 0, 0)
	assert_true(NoiseModel.can_hear(Vector3.ZERO, near, Rules.NOISE_MEDIUM))
	assert_false(NoiseModel.can_hear(Vector3.ZERO, far, Rules.NOISE_MEDIUM))


func test_silent_is_never_heard() -> void:
	assert_false(NoiseModel.can_hear(Vector3.ZERO, Vector3.ZERO, Rules.NOISE_SILENT, 10.0))


func test_actions_have_expected_order() -> void:
	assert_lt(Rules.NOISE_CROUCH, Rules.NOISE_WALK)
	assert_lt(Rules.NOISE_WALK, Rules.NOISE_SPRINT)
	assert_eq(Rules.NOISE_CRAFT, Rules.NOISE_MEDIUM)

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


func test_loudness_drops_with_distance() -> void:
	var near := NoiseModel.loudness(Vector3.ZERO, Vector3(2, 0, 0), Rules.NOISE_HIGH)
	var far := NoiseModel.loudness(Vector3.ZERO, Vector3(12, 0, 0), Rules.NOISE_HIGH)
	assert_gt(near, far, "más cerca se oye más")
	assert_eq(NoiseModel.loudness(Vector3.ZERO, Vector3(50, 0, 0), Rules.NOISE_HIGH), 0.0)


func test_walls_shrink_the_radius() -> void:
	var radius := NoiseModel.radius_for(Rules.NOISE_MEDIUM)
	var spot := Vector3(radius * 0.75, 0, 0)
	assert_true(NoiseModel.can_hear(Vector3.ZERO, spot, Rules.NOISE_MEDIUM, 1.0, 0))
	assert_false(NoiseModel.can_hear(Vector3.ZERO, spot, Rules.NOISE_MEDIUM, 1.0, 1), "pared")
	assert_almost_eq(
		NoiseModel.effective_radius(Rules.NOISE_MEDIUM, 1.0, 2),
		radius * Rules.NOISE_WALL_FACTOR * Rules.NOISE_WALL_FACTOR,
		0.001
	)


func test_sensitivity_extends_the_radius() -> void:
	var radius := NoiseModel.radius_for(Rules.NOISE_LOW)
	var spot := Vector3(radius * 1.2, 0, 0)
	assert_false(NoiseModel.can_hear(Vector3.ZERO, spot, Rules.NOISE_LOW, 1.0))
	assert_true(NoiseModel.can_hear(Vector3.ZERO, spot, Rules.NOISE_LOW, 1.3))
	assert_false(NoiseModel.can_hear(Vector3.ZERO, Vector3.ZERO, Rules.NOISE_HIGH, 0.0), "sordo")


func test_distant_gunshot_beats_close_footstep() -> void:
	var shot := NoiseModel.loudness(Vector3.ZERO, Vector3(15, 0, 0), Rules.NOISE_VERY_HIGH)
	var step := NoiseModel.loudness(Vector3.ZERO, Vector3(1, 0, 0), Rules.NOISE_LOW)
	assert_gt(shot, step)


func test_thrown_object_is_louder_when_it_breaks() -> void:
	assert_gt(Rules.NOISE_THROW_BREAK, Rules.NOISE_THROW_LAND)
	assert_gt(NoiseModel.radius_for(Rules.NOISE_THROW_LAND), 0.0)

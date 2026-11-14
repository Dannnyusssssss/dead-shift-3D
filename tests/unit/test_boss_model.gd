extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Reglas del jefe: daño de frente reducido con el traje, tanque como punto débil, golpes
## aturdido como tanque, segunda fase, extintor con inmunidad y esperas de sus ataques.

var _data: BossData


func before_each() -> void:
	_data = BossData.new()


func test_front_is_reduced_and_tank_is_weak_point() -> void:
	var model := BossModel.new(_data)
	assert_eq(model.take_hit(100.0, false), 100.0 * _data.phase_one_front_multiplier)
	var before := model.health
	assert_eq(model.take_hit(40.0, true), 40.0 * _data.tank_multiplier)
	assert_eq(model.health, before - 40.0 * _data.tank_multiplier)


func test_any_hit_counts_as_tank_while_stunned() -> void:
	var model := BossModel.new(_data)
	model.stun(2.0)
	assert_eq(model.take_hit(10.0, false), 10.0 * _data.tank_multiplier)


func test_phase_two_starts_when_suit_breaks() -> void:
	var model := BossModel.new(_data)
	model.take_hit(10000.0, true)
	assert_eq(model.phase, BossModel.PHASE_TWO)
	assert_true(model.phase_changed)
	assert_eq(model.health, _data.phase_two_health, "el sobrante se pierde")
	assert_true(model.is_stunned(), "se tambalea al romperse el traje")
	assert_false(model.is_dead())
	assert_gt(model.speed(), _data.phase_one_speed, "más rápido")
	model.tick(_data.phase_change_stun + 0.1)
	assert_eq(model.damage_multiplier(false), _data.phase_two_front_multiplier, "menos resistente")


func test_dies_at_end_of_phase_two() -> void:
	var model := BossModel.new(_data)
	model.take_hit(10000.0, true)
	model.take_hit(10000.0, true)
	assert_true(model.is_dead())
	assert_eq(model.take_hit(50.0, true), 0.0)


func test_extinguisher_stuns_then_grants_immunity() -> void:
	var model := BossModel.new(_data)
	assert_true(model.stun_by_extinguisher())
	assert_false(model.stun_by_extinguisher(), "ya aturdido")
	model.tick(_data.extinguisher_stun + 0.01)
	assert_false(model.is_stunned())
	assert_false(model.stun_by_extinguisher(), "inmune un rato")
	model.tick(_data.extinguisher_immunity + 0.01)
	assert_true(model.stun_by_extinguisher(), "vuelve a aturdirse")


func test_panel_stun_works_during_immunity() -> void:
	var model := BossModel.new(_data)
	model.stun_by_extinguisher()
	model.tick(_data.extinguisher_stun + 0.01)
	model.stun(_data.panel_stun)
	assert_true(model.is_stunned(), "el tablero no tiene inmunidad")


func test_charge_needs_distance_and_cooldown() -> void:
	var model := BossModel.new(_data)
	model.tick(_data.charge_cooldown)
	assert_false(model.can_charge(_data.charge_min_distance - 0.5), "demasiado cerca")
	assert_false(model.can_charge(_data.charge_max_distance + 0.5), "demasiado lejos")
	assert_true(model.can_charge(8.0))
	model.start_charge()
	assert_false(model.can_charge(8.0), "espera entre embestidas")
	model.tick(_data.charge_cooldown + 0.01)
	assert_true(model.can_charge(8.0))


func test_no_attacks_while_stunned_and_clouds_faster_in_phase_two() -> void:
	var model := BossModel.new(_data)
	model.tick(30.0)
	model.stun(1.0)
	assert_false(model.can_charge(8.0))
	assert_false(model.can_cloud())
	assert_false(model.can_swipe(1.0))
	model.take_hit(10000.0, true)
	model.tick(10.0)
	model.start_cloud()
	model.tick(_data.cloud_cooldown_phase_two + 0.01)
	assert_true(model.can_cloud())
	assert_gt(model.cloud_dps(), _data.cloud_dps_phase_one)

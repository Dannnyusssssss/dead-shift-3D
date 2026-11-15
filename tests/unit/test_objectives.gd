extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Objetivo actual: piezas, armar el teléfono, llave de la azotea, llamar y el reloj del rescate.

const Fixtures = preload("res://tests/helpers/fixtures.gd")


func _state() -> PlayerState:
	return PlayerState.new(ItemCatalog.new([]))


func test_follows_the_road_to_the_rescue() -> void:
	var state := _state()
	var rescue := RescueClock.new()
	var objective := Objectives.current(state, rescue, false)
	assert_eq(objective["key"], "objective_find_parts")
	assert_eq(objective["args"], [0, Rules.PHONE_PARTS.size()])
	for part: String in Rules.PHONE_PARTS:
		state.keys.add(part)
	assert_eq(Objectives.current(state, rescue, false)["key"], "objective_assemble")
	state.keys.assemble_phone()
	assert_eq(Objectives.current(state, rescue, false)["key"], "objective_roof_key")
	state.keys.add("roof_key")
	assert_eq(Objectives.current(state, rescue, false)["key"], "objective_call")
	rescue.call_helicopter()
	assert_eq(Objectives.current(state, rescue, true)["key"], "objective_inbound")
	rescue.load_data(RescueClock.STATE_WAITING, 30.0)
	objective = Objectives.current(state, rescue, true)
	assert_eq(objective["key"], "objective_waiting")
	assert_eq(objective["args"], ["0:30"])
	rescue.load_data(RescueClock.STATE_DEPARTED, 0.0)
	assert_eq(Objectives.current(state, rescue, true)["key"], "objective_lost")


func test_open_roof_counts_as_having_the_key() -> void:
	var state := _state()
	for part: String in Rules.PHONE_PARTS:
		state.keys.add(part)
	state.keys.assemble_phone()
	assert_eq(Objectives.current(state, RescueClock.new(), true)["key"], "objective_call")


func test_infection_is_a_warning() -> void:
	var state := _state()
	assert_eq(Objectives.warning(state), {})
	state.infection.try_infect(1.0, Fixtures.rng())
	assert_eq(Objectives.warning(state)["key"], "objective_infected")


func test_clock_format() -> void:
	assert_eq(Objectives.clock(150.0), "2:30")
	assert_eq(Objectives.clock(0.2), "0:01")
	assert_eq(Objectives.clock(-5.0), "0:00")

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Reloj del rescate con tiempo inyectado: todos los caminos (sin llamar, llegada, espera,
## subida a tiempo, llegada con el jugador ya esperando, partida sin él) y datos guardados.


func test_nothing_happens_until_called() -> void:
	var clock := RescueClock.new(10.0, 5.0)
	assert_eq(clock.tick(100.0, true), RescueClock.EVENT_NONE)
	assert_eq(clock.state, RescueClock.STATE_IDLE)
	assert_false(clock.is_called())


func test_call_only_once() -> void:
	var clock := RescueClock.new(10.0, 5.0)
	assert_true(clock.call_helicopter())
	assert_false(clock.call_helicopter())
	assert_eq(clock.time_left, 10.0)


func test_arrives_after_countdown() -> void:
	var clock := RescueClock.new(10.0, 5.0)
	clock.call_helicopter()
	assert_eq(clock.tick(9.0, false), RescueClock.EVENT_NONE)
	assert_almost_eq(clock.time_left, 1.0, 0.001)
	assert_eq(clock.tick(1.0, false), RescueClock.EVENT_ARRIVED)
	assert_eq(clock.state, RescueClock.STATE_WAITING)
	assert_eq(clock.time_left, 5.0, "empieza la espera")


func test_player_on_helipad_does_not_board_before_arrival() -> void:
	var clock := RescueClock.new(10.0, 5.0)
	clock.call_helicopter()
	assert_eq(clock.tick(5.0, true), RescueClock.EVENT_NONE, "aguanta hasta que llegue")
	assert_eq(clock.tick(5.0, true), RescueClock.EVENT_ARRIVED)
	assert_eq(clock.tick(0.016, true), RescueClock.EVENT_BOARDED, "sube en cuanto llega")
	assert_true(clock.is_finished())


func test_boards_while_waiting() -> void:
	var clock := RescueClock.new(1.0, 5.0)
	clock.call_helicopter()
	clock.tick(1.0, false)
	clock.tick(4.0, false)
	assert_eq(clock.tick(0.5, true), RescueClock.EVENT_BOARDED)
	assert_eq(clock.state, RescueClock.STATE_BOARDED)


func test_departs_without_player() -> void:
	var clock := RescueClock.new(1.0, 5.0)
	clock.call_helicopter()
	clock.tick(1.0, false)
	assert_eq(clock.tick(4.99, false), RescueClock.EVENT_NONE)
	assert_eq(clock.tick(0.02, false), RescueClock.EVENT_DEPARTED)
	assert_eq(clock.state, RescueClock.STATE_DEPARTED)
	assert_eq(clock.tick(10.0, true), RescueClock.EVENT_NONE, "ya no vuelve")


func test_negative_time_is_ignored() -> void:
	var clock := RescueClock.new(10.0, 5.0)
	clock.call_helicopter()
	clock.tick(-50.0, false)
	assert_eq(clock.time_left, 10.0)


func test_saved_data_round_trip_and_hostile_values() -> void:
	var clock := RescueClock.new(10.0, 5.0)
	clock.call_helicopter()
	clock.tick(3.0, false)
	var data := clock.to_data()
	var restored := RescueClock.new(10.0, 5.0)
	restored.load_data(data["state"], data["time_left"])
	assert_eq(restored.state, RescueClock.STATE_INBOUND)
	assert_almost_eq(restored.time_left, 7.0, 0.001)
	restored.load_data(RescueClock.STATE_INBOUND, 9999.0)
	assert_eq(restored.time_left, 10.0, "no supera la cuenta completa")
	restored.load_data(RescueClock.STATE_WAITING, -5.0)
	assert_eq(restored.time_left, 0.0, "nunca negativo")
	restored.load_data(42, 3.0)
	assert_eq(restored.state, RescueClock.STATE_IDLE, "estado desconocido")

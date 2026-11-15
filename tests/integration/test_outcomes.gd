extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Desenlaces con la partida completa: rescate al subir en el helipuerto, rescate perdido con
## oleadas que nunca superan el tope y rendición, muerte, conversión y muerte tras perder el
## rescate (que es el final de rescate perdido).

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")

var _game: Game
var _outcomes: Array[int] = []


func before_each() -> void:
	GameState.forced_seed = 11
	_outcomes.clear()
	_game = GAME_SCRIPT.new()
	add_child_autofree(_game)
	EventBus.run_finished.connect(_on_finished)
	await wait_physics_frames(3)


func after_each() -> void:
	EventBus.run_finished.disconnect(_on_finished)
	GameState.forced_seed = -1
	GameState.set_paused(false)
	InputRouter.gameplay_active = false
	InputRouter.release_capture()


func _on_finished(outcome: int) -> void:
	_outcomes.append(outcome)


## Lleva al jugador a un descansillo y espera a que el edificio note el cambio de piso.
func _travel(floor_id: String, exit_id: String) -> void:
	assert_true(_game.level.place_player_at_exit(floor_id, exit_id), floor_id + "/" + exit_id)
	await wait_physics_frames(24)


func test_boarding_the_helicopter_is_the_rescue() -> void:
	await _travel("rooftop", "stairs_down")
	assert_true(_game.level.floor_data.has_helipad)
	GameState.rescue.call_helicopter()
	GameState.rescue.time_left = 0.05
	await wait_frames(6)
	assert_eq(GameState.rescue.state, RescueClock.STATE_WAITING)
	var data := _game.level.floor_data
	_game.level.player.global_position = data.helipad_position + Vector3.UP * data.elevation()
	await wait_frames(6)
	assert_eq(_outcomes, [RunStats.OUTCOME_RESCUED] as Array[int])
	assert_true(_game.won)
	var huds := _game.find_children("*", "Hud", true, false)
	assert_false((huds[0] as Hud).visible, "el HUD no se ve detrás del resultado")


func test_lost_rescue_brings_capped_waves_and_surrender_ends_it() -> void:
	await _travel("rooftop", "stairs_down")
	GameState.rescue.call_helicopter()
	GameState.rescue.load_data(RescueClock.STATE_WAITING, 0.05)
	await wait_frames(6)
	assert_eq(GameState.rescue.state, RescueClock.STATE_DEPARTED)
	var waves := _game.level.get_node_or_null("Actors/Waves") as WaveSpawner
	assert_not_null(waves, "empiezan las oleadas")
	# El jugador no muere durante la prueba; se comprueba el tope mientras aparecen.
	GameState.player.health = 100000.0
	var most := 0
	for _step: int in 40:
		await wait_physics_frames(10)
		most = maxi(most, waves.alive_count())
	assert_gt(most, 0)
	assert_lte(most, waves.cap, "nunca más enemigos vivos que el tope")
	GameState.set_paused(true)
	EventBus.surrender_requested.emit()
	await wait_frames(3)
	assert_eq(_outcomes, [RunStats.OUTCOME_LOST] as Array[int])


func test_death_and_conversion_have_their_own_outcome() -> void:
	GameState.player.take_damage(10000.0)
	_game.level.player.receive_damage(1.0)
	EventBus.player_died.emit()
	await wait_frames(2)
	assert_eq(_outcomes, [RunStats.OUTCOME_DEAD] as Array[int])


func test_conversion_outcome() -> void:
	GameState.player.infection.try_infect(1.0, GameState.rng)
	GameState.player.infection.time_left = 0.1
	await wait_physics_frames(20)
	assert_eq(_outcomes, [RunStats.OUTCOME_CONVERTED] as Array[int])


func test_dying_after_losing_the_rescue_is_the_lost_ending() -> void:
	GameState.rescue.call_helicopter()
	GameState.rescue.load_data(RescueClock.STATE_DEPARTED, 0.0)
	GameState.player.take_damage(10000.0)
	EventBus.player_died.emit()
	await wait_frames(2)
	assert_eq(_outcomes, [RunStats.OUTCOME_LOST] as Array[int])


func test_surrender_is_ignored_before_losing_the_rescue() -> void:
	EventBus.surrender_requested.emit()
	await wait_frames(2)
	assert_true(_outcomes.is_empty())


func test_calling_the_helicopter_brings_capped_waves_while_waiting() -> void:
	await _travel("rooftop", "stairs_down")
	GameState.player.health = 100000.0
	GameState.rescue.call_helicopter()
	await wait_physics_frames(10)
	var waves := _game.level.get_node_or_null("Actors/CallWaves") as WaveSpawner
	assert_not_null(waves, "la llamada atrae enemigos a la azotea")
	var most := 0
	for _step: int in 30:
		await wait_physics_frames(10)
		most = maxi(most, waves.alive_count())
	assert_gt(most, 0)
	assert_lte(most, WaveSpawner.CALL_CAP)
	GameState.rescue.load_data(RescueClock.STATE_WAITING, 0.05)
	await wait_frames(6)
	assert_not_null(
		_game.level.get_node_or_null("Actors/Waves"), "al irse, las del rescate perdido"
	)
	assert_null(_game.level.get_node_or_null("Actors/CallWaves"), "y las de la espera se retiran")

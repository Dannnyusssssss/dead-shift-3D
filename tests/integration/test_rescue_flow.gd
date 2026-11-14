extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Teléfono, helicóptero, cámaras y mapa con la partida completa: armar el teléfono con las tres
## piezas, llamar (una sola vez), llegada y partida sin el jugador, aviso de las cámaras en la
## zona segura, informe de los monitores y mapa solo con el plano.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")

var _game: Game


func before_each() -> void:
	GameState.forced_seed = 7
	_game = GAME_SCRIPT.new()
	add_child_autofree(_game)
	await wait_physics_frames(3)


func after_each() -> void:
	GameState.forced_seed = -1
	InputRouter.gameplay_active = false
	InputRouter.menu_open = false
	InputRouter.release_capture()


func test_phone_needs_all_parts_and_call_happens_once() -> void:
	var state := GameState.player
	state.keys.add("phone_antenna")
	state.keys.add("phone_battery")
	assert_false(state.keys.can_assemble_phone(), "faltan piezas")
	assert_false(state.keys.assemble_phone())
	state.keys.add("phone_board")
	assert_true(state.keys.assemble_phone())
	assert_false(state.keys.assemble_phone(), "ya armado")
	assert_true(GameState.rescue.call_helicopter())
	assert_false(GameState.rescue.call_helicopter(), "una sola llamada")


func test_helicopter_arrives_and_leaves_without_player() -> void:
	watch_signals(EventBus)
	GameState.rescue.call_helicopter()
	GameState.rescue.time_left = 0.05
	await wait_frames(10)
	assert_eq(GameState.rescue.state, RescueClock.STATE_WAITING, "llegó")
	GameState.rescue.time_left = 0.05
	await wait_frames(10)
	assert_eq(GameState.rescue.state, RescueClock.STATE_DEPARTED, "se fue sin el jugador")
	assert_signal_emitted(EventBus, "rescue_lost")


func test_rescue_clock_stops_while_paused() -> void:
	GameState.rescue.call_helicopter()
	var before := GameState.rescue.time_left
	GameState.set_paused(true)
	await wait_frames(20)
	assert_eq(GameState.rescue.time_left, before, "la pausa detiene el reloj")
	GameState.set_paused(false)


func test_cameras_warn_when_an_enemy_nears_the_safe_room() -> void:
	watch_signals(EventBus)
	var player := _game.level.player
	player.global_position = Vector3(-4.0, 0.0, 0.0)
	var enemy: Enemy = null
	for node: Node in _game.level.get_children():
		if node is Enemy:
			enemy = node
			break
	enemy.global_position = Vector3(2.0, 0.0, 0.0)
	await wait_frames(45)
	assert_signal_emitted_with_parameters(EventBus, "camera_alert", [true])


func test_monitors_report_enemies_per_floor() -> void:
	var report := SecurityMonitor.report()
	for floor_data: FloorData in GameState.CATALOG.floors:
		assert_string_contains(report, tr(floor_data.name_key))
	assert_string_contains(report, tr("cameras_boss"))


func test_map_needs_the_plan() -> void:
	var map: MapView = null
	for node: Node in _game.get_node("UI").get_children():
		if node is MapView:
			map = node
	map.open()
	assert_false(map.is_open(), "sin plano no se abre")
	GameState.player.keys.add("mall_map")
	map.open()
	assert_true(map.is_open())
	assert_false(_game.level.player.controls_enabled, "con el mapa abierto queda quieto")
	map.close()
	assert_true(_game.level.player.controls_enabled)

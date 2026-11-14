class_name Game
extends Node
## Partida en curso: carga el piso actual y monta la interfaz (HUD, táctil, inventario, pausa,
## fin, carga y rendimiento). Cambia de piso con una pantalla de carga conservando el estado
## del jugador y del mundo. Termina al morir o al llegar a la meta final.

signal restart_requested
## Volver al último autoguardado (desde la pantalla de muerte).
signal continue_requested

## Distancia a la que las cámaras de una zona segura avisan de un enemigo.
const CAMERA_RANGE: float = 10.0

## Partida guardada ya validada con la que empezar (vacío = partida nueva).
var start_data: Dictionary = {}
var level: FloorLevel = null
var elapsed: float = 0.0
var finished: bool = false
var won: bool = false
## Verdadero mientras se carga otro piso.
var changing_floor: bool = false

var _hud: Hud = null
var _inventory: InventoryPanel = null
var _end_screen: EndScreen = null
var _loading: LoadingScreen = null
var _map: MapView = null
var _camera_timer: float = 0.0
var _camera_alert: bool = false
var _waves: WaveSpawner = null
var _safe_room: String = ""


func _ready() -> void:
	var start := GameState.CATALOG.find_floor(GameState.CATALOG.start_floor)
	if start_data.is_empty():
		GameState.start_new_run()
		_build_level(start, "")
	else:
		GameState.load_run(start_data)
		var saved_floor: String = start_data.get("floor", "")
		var saved := GameState.CATALOG.find_floor(saved_floor)
		start = saved if saved != null else start
		var stats: Dictionary = start_data.get("stats", {})
		elapsed = stats.get("time", 0.0)
		var kind: String = start_data.get("spawn_kind", "")
		var spawn_id: String = start_data.get("spawn_id", "")
		_build_level(
			start,
			spawn_id if kind == SaveValidation.SPAWN_EXIT else "",
			spawn_id if kind == SaveValidation.SPAWN_SAFE else ""
		)
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	_hud = Hud.new()
	ui.add_child(_hud)
	ui.add_child(TouchControls.new())
	_inventory = InventoryPanel.new()
	ui.add_child(_inventory)
	_map = MapView.new()
	ui.add_child(_map)
	ui.add_child(PauseMenu.new())
	_end_screen = EndScreen.new()
	ui.add_child(_end_screen)
	_end_screen.restart_requested.connect(func() -> void: restart_requested.emit())
	_end_screen.continue_requested.connect(func() -> void: continue_requested.emit())
	_loading = LoadingScreen.new()
	ui.add_child(_loading)
	ui.add_child(PerfOverlay.new())
	_bind_player()
	EventBus.player_died.connect(_on_player_died)
	EventBus.goal_reached.connect(_on_goal_reached)
	EventBus.floor_change_requested.connect(change_floor)
	EventBus.rescue_lost.connect(_maybe_start_waves)
	EventBus.floor_changed.connect(func(_floor_id: String) -> void: _maybe_start_waves())
	EventBus.surrender_requested.connect(_on_surrender)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.save_requested.connect(_on_save_requested)
	InputRouter.gameplay_active = true
	EventBus.floor_changed.emit(start.id)


func _process(delta: float) -> void:
	if finished or GameState.paused or changing_floor:
		return
	elapsed += delta
	_tick_rescue(delta)
	_tick_cameras(delta)


## Avanza el reloj del rescate y reacciona a sus momentos.
func _tick_rescue(delta: float) -> void:
	var player := level.player
	var on_pad := level.on_helipad(player.global_position) and not player.is_dead()
	match GameState.rescue.tick(delta, on_pad):
		RescueClock.EVENT_ARRIVED:
			EventBus.user_message.emit("msg_helicopter_arrived")
			EventBus.sound_cue.emit("cue_helicopter", player.global_position + Vector3.UP * 20.0)
			EventBus.rescue_changed.emit()
		RescueClock.EVENT_DEPARTED:
			EventBus.user_message.emit("msg_helicopter_left")
			EventBus.rescue_changed.emit()
			EventBus.rescue_lost.emit()
		RescueClock.EVENT_BOARDED:
			EventBus.rescue_changed.emit()
			EventBus.goal_reached.emit()


## En una zona segura, las cámaras avisan si algún enemigo se acerca.
func _tick_cameras(delta: float) -> void:
	_camera_timer -= delta
	if _camera_timer > 0.0:
		return
	_camera_timer = 0.5
	var player := level.player
	var alert := false
	var room := level.safe_room_at(player.global_position)
	var room_id := room.id if room != null else ""
	if room_id != _safe_room:
		_safe_room = room_id
		# Autoguardado al entrar en una zona segura.
		if not room_id.is_empty() and not player.is_dead():
			save_game(SaveValidation.SPAWN_SAFE, room_id, false)
	if room != null:
		for node: Node in get_tree().get_nodes_in_group("enemy"):
			var enemy := node as Enemy
			if enemy != null and not enemy.is_dead():
				if enemy.global_position.distance_to(player.global_position) <= CAMERA_RANGE:
					alert = true
					break
	if alert != _camera_alert:
		_camera_alert = alert
		EventBus.camera_alert.emit(alert)


## Carga otro piso y coloca al jugador en la salida indicada. El estado del jugador y del
## mundo se conserva; los objetos que quedaron en el suelo se recuerdan.
func change_floor(floor_id: String, exit_id: String) -> void:
	if changing_floor or finished:
		return
	var data := GameState.CATALOG.find_floor(floor_id)
	if data == null or data.find_exit(exit_id) == null:
		ErrorLog.report("unknown_floor", "%s/%s" % [floor_id, exit_id])
		EventBus.user_message.emit("msg_generic_error")
		return
	changing_floor = true
	_inventory.close()
	_map.close()
	level.player.set_blocked("loading", true)
	_loading.show_floor(data.name_key)
	# Dos fotogramas para que la pantalla de carga se dibuje antes del trabajo pesado.
	await get_tree().process_frame
	await get_tree().process_frame
	level.store_world_state()
	remove_child(level)
	level.queue_free()
	_build_level(data, exit_id)
	_bind_player()
	await get_tree().process_frame
	_loading.visible = false
	changing_floor = false
	EventBus.floor_changed.emit(floor_id)
	_safe_room = ""
	save_game(SaveValidation.SPAWN_EXIT, exit_id, false)


func _build_level(data: FloorData, exit_id: String, safe_room: String = "") -> void:
	level = FloorLevel.new()
	level.name = "Level"
	level.floor_data = data
	level.arrival_exit = exit_id
	level.arrival_safe_room = safe_room
	add_child(level)
	move_child(level, 0)


func _bind_player() -> void:
	_hud.bind_player(level.player)
	_inventory.bind_player(level.player)
	_map.bind_player(level.player)


## Si el helicóptero ya se fue y el jugador está en la azotea, empiezan las oleadas.
func _maybe_start_waves() -> void:
	if _waves != null or finished or GameState.rescue.state != RescueClock.STATE_DEPARTED:
		return
	if not level.floor_data.has_helipad:
		return
	_waves = WaveSpawner.new()
	_waves.name = "Waves"
	for point: Vector3 in level.floor_data.wave_spawn_points:
		_waves.spawn_points.append(point)
	level.add_child(_waves)
	_waves.waves_cleared.connect(func() -> void: _finish(RunStats.OUTCOME_LOST))


## Guarda la partida (una sola ranura). Devuelve verdadero si se pudo.
func save_game(spawn_kind: String, spawn_id: String, manual: bool) -> bool:
	if finished or changing_floor or level.player.is_dead():
		return false
	level.store_world_state()
	var data := SaveGame.capture(
		GameState.player,
		GameState.world,
		GameState.rescue,
		level.floor_data.id,
		spawn_kind,
		spawn_id,
		GameState.run_seed,
		elapsed
	)
	if not SaveStore.save_game(data):
		return false
	EventBus.game_saved.emit(manual)
	return true


## Guardado manual: solo en una zona segura.
func _on_save_requested() -> void:
	var room := level.safe_room_at(level.player.global_position)
	if room == null:
		EventBus.user_message.emit("msg_save_safe_only")
		return
	if save_game(SaveValidation.SPAWN_SAFE, room.id, true):
		EventBus.user_message.emit("msg_saved")


func _on_enemy_died(_origin: Vector3, _drops: Array[ItemStack]) -> void:
	if GameState.player != null:
		GameState.player.kills += 1


func _on_surrender() -> void:
	if GameState.rescue.state == RescueClock.STATE_DEPARTED:
		GameState.set_paused(false)
		_finish(RunStats.OUTCOME_LOST)


## Muerte: tras perder el rescate es el final de «rescate perdido»; si no, conversión o muerte.
func _on_player_died() -> void:
	if GameState.rescue.state == RescueClock.STATE_DEPARTED:
		_finish(RunStats.OUTCOME_LOST)
	elif GameState.player.death_cause == PlayerState.CAUSE_INFECTION:
		_finish(RunStats.OUTCOME_CONVERTED)
	else:
		_finish(RunStats.OUTCOME_DEAD)


func _on_goal_reached() -> void:
	_finish(RunStats.OUTCOME_RESCUED)


func _finish(outcome: int) -> void:
	if finished:
		return
	finished = true
	won = outcome == RunStats.OUTCOME_RESCUED
	level.player.set_blocked("finished", true)
	var stats := RunStats.from_state(GameState.player, outcome, elapsed)
	if outcome == RunStats.OUTCOME_RESCUED:
		SaveStore.save_best(stats.grade())
	if outcome == RunStats.OUTCOME_RESCUED or outcome == RunStats.OUTCOME_LOST:
		# La historia terminó: no queda nada que continuar.
		SaveStore.delete_game()
	_end_screen.show_result(stats, SaveStore.has_game())
	EventBus.run_finished.emit(outcome)

class_name Game
extends Node
## Partida en curso: construye el edificio entero y monta la interfaz (HUD, táctil, inventario,
## pausa, fin y rendimiento). El jugador pasa de un piso a otro caminando por las escaleras; al
## cambiar de piso se autoguarda. Termina con un desenlace.

signal restart_requested
## Volver al último autoguardado (desde la pantalla de muerte).
signal continue_requested
## Volver al menú principal (desde la pausa o la pantalla final).
signal menu_requested

## Distancia a la que las cámaras de una zona segura avisan de un enemigo.
const CAMERA_RANGE: float = 10.0
## Fundido a negro tras morir, antes de la pantalla final.
const DEATH_FADE_SECONDS: float = 1.2

## Partida guardada ya validada con la que empezar (vacío = partida nueva).
var start_data: Dictionary = {}
var level: Building = null
var elapsed: float = 0.0
var finished: bool = false
var won: bool = false

var _hud: Hud = null
var _inventory: InventoryPanel = null
var _end_screen: EndScreen = null
var _map: MapView = null
var _note: NoteView = null
var _cameras: CameraView = null
var _camera_timer: float = 0.0
var _camera_alert: bool = false
var _waves: WaveSpawner = null
## Oleadas de la espera del helicóptero (atraídas por la llamada).
var _call_waves: WaveSpawner = null
var _safe_room: String = ""
var _started: bool = false


func _ready() -> void:
	level = Building.new()
	level.name = "Level"
	if start_data.is_empty():
		GameState.start_new_run()
		level.start_floor = GameState.CATALOG.start_floor
	else:
		GameState.load_run(start_data)
		level.start_floor = start_data.get("floor", "")
		var stats: Dictionary = start_data.get("stats", {})
		elapsed = stats.get("time", 0.0)
		var kind: String = start_data.get("spawn_kind", "")
		var spawn_id: String = start_data.get("spawn_id", "")
		level.arrival_exit = spawn_id if kind == SaveValidation.SPAWN_EXIT else ""
		level.arrival_safe_room = spawn_id if kind == SaveValidation.SPAWN_SAFE else ""
	add_child(level)
	move_child(level, 0)
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
	_inventory.map_requested.connect(_map.open)
	_note = NoteView.new()
	ui.add_child(_note)
	_cameras = CameraView.new()
	ui.add_child(_cameras)
	ui.add_child(PauseMenu.new())
	_end_screen = EndScreen.new()
	ui.add_child(_end_screen)
	_end_screen.restart_requested.connect(func() -> void: restart_requested.emit())
	_end_screen.continue_requested.connect(func() -> void: continue_requested.emit())
	_end_screen.menu_requested.connect(func() -> void: menu_requested.emit())
	ui.add_child(PerfOverlay.new())
	_bind_player()
	EventBus.player_died.connect(_on_player_died)
	EventBus.goal_reached.connect(_on_goal_reached)
	EventBus.rescue_lost.connect(_maybe_start_waves)
	EventBus.rescue_changed.connect(_maybe_start_waves)
	EventBus.floor_changed.connect(_on_floor_changed)
	EventBus.surrender_requested.connect(_on_surrender)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.save_requested.connect(_on_save_requested)
	EventBus.main_menu_requested.connect(func() -> void: menu_requested.emit())
	InputRouter.gameplay_active = true
	EventBus.floor_changed.emit(level.floor_data.id)
	_started = true


func _process(delta: float) -> void:
	if finished or GameState.paused:
		return
	elapsed += delta
	_tick_rescue(delta)
	_tick_cameras(delta)


## Avanza el reloj del rescate y reacciona a sus momentos.
func _tick_rescue(delta: float) -> void:
	var player := level.player
	if _call_waves == null and _waves == null and _is_waiting_for_rescue():
		_maybe_start_waves()
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
		for enemy: Enemy in level.active_enemies():
			if enemy.is_dead() or absf(enemy.global_position.y - player.global_position.y) > 2.5:
				continue
			if enemy.global_position.distance_to(player.global_position) <= CAMERA_RANGE:
				alert = true
				break
	if alert != _camera_alert:
		_camera_alert = alert
		EventBus.camera_alert.emit(alert)


## El jugador pasó a otro piso: autoguardado en el descansillo más cercano (salvo en las
## dificultades que solo guardan en zonas seguras) y, en la azotea tras perder el rescate,
## oleadas.
func _on_floor_changed(_floor_id: String) -> void:
	_maybe_start_waves()
	if not _started or finished or level.player.is_dead():
		return
	_safe_room = ""
	if not GameState.difficulty.autosave_on_floor_change():
		return
	var exit_id := level.nearest_exit_id()
	if not exit_id.is_empty():
		save_game(SaveValidation.SPAWN_EXIT, exit_id, false)


func _bind_player() -> void:
	_hud.bind_player(level.player)
	_inventory.bind_player(level.player)
	_map.bind_player(level.player)
	_note.bind_player(level.player)
	_cameras.bind_player(level.player)


## Oleadas en la azotea (con el jugador en ella): durante la espera del helicóptero, las que
## atrae la llamada; si el helicóptero se fue, las del rescate perdido hasta el final.
func _maybe_start_waves() -> void:
	if finished or not level.floor_data.has_helipad:
		return
	var state := GameState.rescue.state
	if state == RescueClock.STATE_DEPARTED and _waves == null:
		if _call_waves != null:
			_call_waves.queue_free()
			_call_waves = null
		_waves = _make_spawner("Waves")
		_waves.waves_cleared.connect(func() -> void: _finish(RunStats.OUTCOME_LOST))
	elif _is_waiting_for_rescue() and _call_waves == null and _waves == null:
		_call_waves = _make_spawner("CallWaves", true)


func _is_waiting_for_rescue() -> bool:
	var state := GameState.rescue.state
	return state == RescueClock.STATE_INBOUND or state == RescueClock.STATE_WAITING


func _make_spawner(spawner_name: String, call_waves: bool = false) -> WaveSpawner:
	var spawner := WaveSpawner.new()
	spawner.name = spawner_name
	if call_waves:
		spawner.use_call_waves()
	spawner.apply_difficulty(GameState.difficulty)
	var lift := Vector3.UP * level.floor_data.elevation()
	for point: Vector3 in level.floor_data.wave_spawn_points:
		spawner.spawn_points.append(point + lift)
	level.add_actor(spawner)
	return spawner


## Guarda la partida (una sola ranura). Devuelve verdadero si se pudo.
func save_game(spawn_kind: String, spawn_id: String, manual: bool) -> bool:
	if finished or level.player.is_dead():
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
		elapsed,
		GameState.difficulty.id()
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


## Subió al helicóptero: rescate, o caída si sigue infectado.
func _on_goal_reached() -> void:
	_finish(RunStats.boarding_outcome(GameState.player.infection))


func _finish(outcome: int) -> void:
	if finished:
		return
	finished = true
	won = outcome == RunStats.OUTCOME_RESCUED
	level.player.set_blocked("finished", true)
	var stats := RunStats.from_state(GameState.player, outcome, elapsed)
	if outcome == RunStats.OUTCOME_RESCUED:
		SaveStore.save_best(stats.grade(), GameState.difficulty.id())
	var story_over := (
		outcome in [RunStats.OUTCOME_RESCUED, RunStats.OUTCOME_LOST, RunStats.OUTCOME_CRASHED]
	)
	if story_over:
		# La historia terminó: no queda nada que continuar.
		SaveStore.delete_game()
	EventBus.run_finished.emit(outcome)
	var with_scene := story_over
	var died := outcome == RunStats.OUTCOME_DEAD or outcome == RunStats.OUTCOME_CONVERTED
	if died and DisplayServer.get_name() != "headless":
		await _play_death()
	if with_scene and DisplayServer.get_name() != "headless":
		# Escena corta antes de las estadísticas (sin ventana, bot y tests, se omite).
		_hud.visible = false
		var outro := Outro.new()
		outro.setup(level, level.helipad_point(), level.player.global_position, outcome)
		add_child(outro)
		await outro.finished
		outro.queue_free()
	_end_screen.show_result(stats, SaveStore.has_game(), GameState.difficulty)


## Muerte: la cámara cae al suelo y la imagen se funde a negro (sin ventana se omite). Con
## «Reducir movimiento» solo hay fundido.
func _play_death() -> void:
	_hud.visible = false
	var fall := level.player.play_death_fall()
	var black := ColorRect.new()
	black.color = Color(0.0, 0.0, 0.0, 0.0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.get_parent().add_child(black)
	_hud.get_parent().move_child(black, _end_screen.get_index())
	var tween := create_tween()
	tween.tween_interval(fall * 0.5)
	tween.tween_property(black, "color:a", 1.0, DEATH_FADE_SECONDS)
	await tween.finished

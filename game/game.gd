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
## Despertar tras la intro: distancia (m) a los monitores de la sala de seguridad, fundido
## desde negro, volumen de la alarma (dB) y lo que tarda en apagarse.
const WAKE_DESK_DISTANCE: float = 1.1
const WAKE_FADE_SECONDS: float = 0.8
const WAKE_ALARM_DB: float = -14.0
const WAKE_ALARM_FADE: float = 3.0
## Herramientas de desarrollo opcionales: una carpeta local que no se publica ni se exporta.
const DEV_TOOLS_PATH: String = "res://dev/dev_tools.gd"

## Partida guardada ya validada con la que empezar (vacío = partida nueva).
var start_data: Dictionary = {}
## Partida nueva justo después de la intro: empieza con el guardia despertando en la sala de
## seguridad (sin ventana no se hace).
var wake_up_on_start: bool = false
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
var _wake_black: ColorRect = null
var _wake_caption: Label = null
var _pause_menu: PauseMenu = null


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
	_pause_menu = PauseMenu.new()
	ui.add_child(_pause_menu)
	_end_screen = EndScreen.new()
	ui.add_child(_end_screen)
	_end_screen.restart_requested.connect(func() -> void: restart_requested.emit())
	_end_screen.continue_requested.connect(func() -> void: continue_requested.emit())
	_end_screen.menu_requested.connect(func() -> void: menu_requested.emit())
	ui.add_child(PerfOverlay.new())
	_add_dev_tools(ui)
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
	if wake_up_on_start and start_data.is_empty() and DisplayServer.get_name() != "headless":
		_begin_wake_up(ui)


## Herramientas de desarrollo desde «path», o null si no existen. Solo se crean en el editor o en
## una versión de depuración y con ventana: la versión publicada nunca las busca.
static func dev_tools_from(path: String) -> Node:
	if not OS.is_debug_build() or DisplayServer.get_name() == "headless":
		return null
	if not ResourceLoader.exists(path):
		return null
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		return null
	return script.new() as Node


func _add_dev_tools(ui: CanvasLayer) -> void:
	var tools := dev_tools_from(DEV_TOOLS_PATH)
	if tools == null:
		return
	tools.set("game", self)
	ui.add_child(tools)


## El guardia despierta con la cabeza sobre la mesa de los monitores de la sala de seguridad
## (la real, donde empieza la partida), se incorpora y se pone de pie, con la alarma sonando
## y apagándose. Se salta con una tecla, clic o toque; con «Reducir movimiento» solo hay
## fundido desde negro.
func _begin_wake_up(ui: CanvasLayer) -> void:
	var player := level.player
	_face_security_desk(player)
	_wake_black = ColorRect.new()
	_wake_black.color = Color.BLACK
	_wake_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wake_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_wake_black)
	_wake_caption = Label.new()
	_wake_caption.text = tr("intro_6")
	_wake_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_wake_caption.offset_top = -140
	_wake_caption.offset_bottom = -60
	_wake_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wake_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wake_caption.add_theme_font_size_override("font_size", 30)
	_wake_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_wake_caption.add_theme_constant_override("outline_size", 8)
	ui.add_child(_wake_caption)
	# Debajo de la pausa: si se pausa mientras despierta, el menú se ve encima del negro.
	ui.move_child(_wake_black, _pause_menu.get_index())
	ui.move_child(_wake_caption, _pause_menu.get_index())
	# La interfaz se esconde mientras despierta (parada: si no, se vuelve a mostrar sola).
	_hud.visible = false
	_hud.process_mode = Node.PROCESS_MODE_DISABLED
	AudioDirector.play_loop("alarm_loop", WAKE_ALARM_DB)
	var seconds := WAKE_FADE_SECONDS
	if not Settings.get_bool("reduce_motion"):
		seconds = maxf(player.play_wake_up(), WAKE_FADE_SECONDS)
	else:
		player.set_blocked(Player.WAKE_BLOCK, true)
	var tween := create_tween()
	tween.tween_property(_wake_black, "color:a", 0.0, WAKE_FADE_SECONDS)
	tween.tween_interval(maxf(seconds - WAKE_FADE_SECONDS, 0.0))
	tween.tween_callback(_end_wake_up)


## Termina el despertar (al acabar o al saltarlo): controles, interfaz y la alarma se apaga.
func _end_wake_up() -> void:
	if _wake_black == null:
		return
	_wake_black.queue_free()
	_wake_black = null
	_wake_caption.queue_free()
	_wake_caption = null
	_hud.process_mode = Node.PROCESS_MODE_INHERIT
	_hud.visible = true
	level.player.finish_wake_up()
	AudioDirector.stop_loop(WAKE_ALARM_FADE)


## Coloca al jugador delante de los monitores de la sala de seguridad, mirándolos (si no hay
## monitores en el piso, se queda donde está).
func _face_security_desk(player: Player) -> void:
	var best: SecurityMonitor = null
	for node: Node in level.find_children("*", "SecurityMonitor", true, false):
		var monitor := node as SecurityMonitor
		var same_floor := absf(monitor.global_position.y - player.global_position.y) < 1.0
		if not same_floor:
			continue
		if (
			best == null
			or (
				monitor.global_position.distance_to(player.global_position)
				< best.global_position.distance_to(player.global_position)
			)
		):
			best = monitor
	if best == null:
		return
	var desk := Vector3(best.global_position.x, player.global_position.y, best.global_position.z)
	var toward_room := player.global_position - desk
	toward_room.y = 0.0
	if toward_room.length() < 0.01:
		return
	player.global_position = desk + toward_room.normalized() * WAKE_DESK_DISTANCE
	var look := desk - player.global_position
	player.rotation.y = atan2(-look.x, -look.z)


func _unhandled_input(event: InputEvent) -> void:
	if _wake_black == null:
		return
	var key := event as InputEventKey
	var pressed := key != null and key.pressed and not key.echo
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pressed = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		pressed = true
	if pressed:
		get_viewport().set_input_as_handled()
		_end_wake_up()


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
		# Escena final: las estadísticas salen encima de ella mientras el helicóptero vuela, y
		# la escena sigue detrás hasta cerrar la partida (sin ventana, bot y tests, se omite).
		_hud.visible = false
		var outro := Outro.new()
		outro.setup(level, level.helipad_point(), level.player.global_position, outcome)
		add_child(outro)
		await outro.results_time
		_end_screen.show_result(stats, SaveStore.has_game(), GameState.difficulty, true)
		return
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

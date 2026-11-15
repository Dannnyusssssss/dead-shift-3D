extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Guardado con la partida completa: autoguardado al cambiar de piso y al entrar en una zona
## segura, guardado manual solo en zona segura, y continuar después en una partida nueva con
## el mismo piso, punto de llegada, salud, objetos clave y mundo. Escribe en user:// y lo borra.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")

var _game: Game
var _messages: Array[String] = []


func before_each() -> void:
	SaveStore.delete_game()
	GameState.forced_seed = 5
	_messages.clear()
	EventBus.user_message.connect(_on_message)


func after_each() -> void:
	EventBus.user_message.disconnect(_on_message)
	GameState.forced_seed = -1
	GameState.next_difficulty = Difficulty.EASY
	GameState.set_paused(false)
	InputRouter.gameplay_active = false
	InputRouter.release_capture()
	SaveStore.delete_game()


func _on_message(key: String) -> void:
	_messages.append(key)


func _start(data: Dictionary = {}) -> void:
	_game = GAME_SCRIPT.new()
	_game.start_data = data
	add_child_autofree(_game)
	await wait_physics_frames(3)


## Lleva al jugador a un descansillo y espera a que el edificio note el cambio de piso.
func _travel(floor_id: String, exit_id: String) -> void:
	assert_true(_game.level.place_player_at_exit(floor_id, exit_id), floor_id + "/" + exit_id)
	await wait_physics_frames(24)


func _load_saved() -> Dictionary:
	var result := SaveStore.load_game(GameState.CATALOG.save_context())
	assert_true(result.ok, "el guardado se puede leer")
	return result.data if result.ok else {}


func test_entering_the_safe_room_autosaves() -> void:
	await _start()
	await wait_frames(40)
	assert_true(SaveStore.has_game(), "la partida empieza en la sala de seguridad")
	var data := _load_saved()
	assert_eq(data["spawn_kind"], "safe")
	assert_eq(data["spawn_id"], "security_room")


func test_floor_change_autosaves_and_continue_restores_the_run() -> void:
	await _start()
	var enemies := _game.level.enemies_on_floor("ground_floor")
	var victim := enemies[0]
	while not victim.is_dead():
		victim.take_hit(50.0, victim.global_position + Vector3.UP * 0.5, true)
	GameState.player.take_damage(25.0)
	GameState.player.keys.add("security_key")
	var health := GameState.player.health
	await _travel("level_1", "stairs_down")
	var data := _load_saved()
	assert_eq(data["floor"], "level_1")
	assert_eq(data["spawn_kind"], "exit")
	assert_eq(data["spawn_id"], "stairs_down")
	_game.queue_free()
	await wait_frames(2)
	await _start(data)
	assert_eq(_game.level.floor_data.id, "level_1", "continúa en el mismo piso")
	var arrival := _game.level.floor_data.find_exit("stairs_down").arrival + Vector3.UP * 5.0
	assert_lt(_game.level.player.global_position.distance_to(arrival), 0.6)
	assert_eq(GameState.player.health, health)
	assert_true(GameState.player.keys.has("security_key"))
	await _travel("ground_floor", "stairs_up")
	var alive := _game.level.enemies_on_floor("ground_floor").size()
	assert_eq(alive, enemies.size() - 1, "el enemigo muerto sigue muerto tras continuar")


func test_manual_save_only_in_safe_zone() -> void:
	await _start()
	_game.level.player.global_position = Vector3(20.0, 0.0, 0.0)
	await wait_frames(2)
	EventBus.save_requested.emit()
	assert_true(_messages.has("msg_save_safe_only"))
	_game.level.player.global_position = Vector3(-28.0, 0.0, -2.0)
	await wait_frames(2)
	EventBus.save_requested.emit()
	assert_true(_messages.has("msg_saved"))


func test_rescue_or_lost_ending_clears_the_save() -> void:
	await _start()
	await wait_frames(40)
	assert_true(SaveStore.has_game())
	EventBus.goal_reached.emit()
	await wait_frames(2)
	assert_false(SaveStore.has_game(), "la historia terminó")


func test_hard_saves_only_in_safe_zones_and_keeps_difficulty() -> void:
	GameState.next_difficulty = Difficulty.HARD
	await _start()
	await wait_frames(40)
	var data := _load_saved()
	assert_eq(data["difficulty"], Difficulty.HARD, "la dificultad va en el guardado")
	SaveStore.delete_game()
	await _travel("level_1", "stairs_down")
	assert_false(SaveStore.has_game(), "en Difícil no se guarda al cambiar de piso")
	_game.save_game(SaveValidation.SPAWN_SAFE, "security_room", false)
	_game.queue_free()
	await wait_physics_frames(2)
	GameState.next_difficulty = Difficulty.EASY
	await _start(_load_saved())
	assert_eq(GameState.difficulty.id(), Difficulty.HARD, "continuar conserva la dificultad")
	assert_eq(GameState.rescue.time_left, 0.0)
	assert_eq(GameState.next_difficulty, Difficulty.HARD, "«Jugar de nuevo» repite la dificultad")

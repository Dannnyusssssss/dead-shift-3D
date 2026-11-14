extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Viaje entre pisos con la partida completa: se conserva el estado del jugador, lo muerto
## sigue muerto, lo registrado sigue vacío, lo soltado sigue en el suelo y el atajo solo se
## abre desde arriba.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")

var _game: Game


func before_each() -> void:
	GameState.forced_seed = 99
	_game = GAME_SCRIPT.new()
	add_child_autofree(_game)
	await wait_physics_frames(3)


func after_each() -> void:
	GameState.forced_seed = -1
	InputRouter.gameplay_active = false
	InputRouter.release_capture()


func _travel(floor_id: String, exit_id: String) -> void:
	_game.change_floor(floor_id, exit_id)
	for _step: int in 60:
		await wait_frames(2)
		if not _game.changing_floor:
			break
	await wait_physics_frames(2)


func _enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node: Node in _game.level.get_children():
		if node is Enemy and not (node as Enemy).is_dead():
			result.append(node)
	return result


func _first_container() -> LootContainer:
	for node: Node in _game.level.get_children():
		if node is LootContainer:
			return node
	return null


func test_state_survives_going_up_and_back_down() -> void:
	assert_eq(_game.level.floor_data.id, "ground_floor")
	var enemies := _enemies()
	var total := enemies.size()
	var victim := enemies[0]
	while not victim.is_dead():
		victim.take_hit(50.0, victim.global_position + Vector3.UP * 0.5, true)
	var container := _first_container()
	var container_spot := container.global_position
	container.interact(_game.level.player)
	assert_false(container.enabled, "registrado")
	EventBus.item_dropped.emit(
		Vector3(2.0, 0.0, 0.0), ItemStack.new(GameState.items.get_item("rag"))
	)
	GameState.player.take_damage(30.0)
	var health := GameState.player.health

	await _travel("level_1", "stairs_down")
	assert_eq(_game.level.floor_data.id, "level_1")
	assert_eq(GameState.world.current_floor, "level_1")
	assert_eq(GameState.player.health, health, "la salud viaja con el jugador")
	var arrival := _game.level.floor_data.find_exit("stairs_down").arrival
	assert_lt(_game.level.player.global_position.distance_to(arrival), 0.5, "llega a la escalera")

	await _travel("ground_floor", "stairs_up")
	assert_eq(_game.level.floor_data.id, "ground_floor")
	assert_eq(_enemies().size(), total - 1, "el muerto sigue muerto")
	var again: LootContainer = null
	for node: Node in _game.level.get_children():
		var candidate := node as LootContainer
		if candidate != null and candidate.global_position.distance_to(container_spot) < 0.1:
			again = candidate
	assert_not_null(again)
	if again != null:
		assert_true(again.is_empty(), "sigue vacío")
		assert_false(again.enabled)
	var rag_found := false
	for node: Node in get_tree().get_nodes_in_group("pickup"):
		var pickup := node as Pickup
		if (
			pickup.item_id == "rag"
			and (
				Vector2(pickup.global_position.x, pickup.global_position.z).distance_to(
					Vector2(2.0, 0.0)
				)
				< 0.1
			)
		):
			rag_found = true
	assert_true(rag_found, "lo soltado sigue en el suelo")


func test_shortcut_opens_only_from_above() -> void:
	var service: FloorExitZone = null
	for node: Node in _game.level.get_children():
		if node is FloorExitZone and (node as FloorExitZone).spec.id == "service_door":
			service = node
	assert_not_null(service)
	assert_false(service.is_open(), "cerrada desde el otro lado")
	await _travel("level_1", "stairs_down")
	var gate: Gate = null
	for node: Node in _game.level.get_children():
		if node is Gate and (node as Gate).spec.id == "shortcut_gate":
			gate = node
	assert_not_null(gate)
	assert_eq(gate.get_prompt_key(), "prompt_open_gate", "se abre sin llave desde arriba")
	gate.interact(_game.level.player)
	assert_true(gate.is_open)
	assert_true(GameState.world.has_flag("shortcut_l1"))
	await _travel("ground_floor", "service_door")
	assert_eq(_game.level.floor_data.id, "ground_floor")
	var arrival := _game.level.floor_data.find_exit("service_door").arrival
	assert_lt(_game.level.player.global_position.distance_to(arrival), 0.5, "bajó por el atajo")


func test_security_post_gate_needs_the_key() -> void:
	await _travel("level_1", "stairs_down")
	var gate: Gate = null
	for node: Node in _game.level.get_children():
		if node is Gate and (node as Gate).spec.id == "security_post_gate":
			gate = node
	assert_eq(gate.get_prompt_key(), "prompt_gate_locked")
	gate.interact(_game.level.player)
	assert_false(gate.is_open, "sin llave no abre")
	GameState.player.keys.add("security_key")
	gate.interact(_game.level.player)
	assert_true(gate.is_open)

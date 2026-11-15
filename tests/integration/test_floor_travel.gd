extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Edificio continuo con la partida completa: se sube caminando por la escalera mecánica y por
## la escalera de servicio, el cambio de piso se nota por la altura (autoguardado y pisos
## lejanos dormidos), el estado del mundo se conserva y los atajos solo se abren desde un lado.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")

var _game: Game


func before_each() -> void:
	SaveStore.delete_game()
	GameState.forced_seed = 99
	_game = GAME_SCRIPT.new()
	add_child_autofree(_game)
	await wait_physics_frames(3)


func after_each() -> void:
	Input.action_release("move_forward")
	GameState.forced_seed = -1
	InputRouter.gameplay_active = false
	InputRouter.release_capture()
	SaveStore.delete_game()


func _travel(floor_id: String, exit_id: String) -> void:
	assert_true(_game.level.place_player_at_exit(floor_id, exit_id), floor_id + "/" + exit_id)
	await wait_physics_frames(24)


func _kill_all(floor_id: String) -> void:
	for enemy: Enemy in _game.level.enemies_on_floor(floor_id):
		while not enemy.is_dead():
			enemy.take_hit(80.0, enemy.global_position + Vector3.UP * 0.5, true)


func _node_on(floor_id: String, check: Callable) -> Node:
	var section := _game.level.find_section(floor_id)
	for node: Node in section.get_children():
		if check.call(node):
			return node
	return null


func _gate(floor_id: String, gate_id: String) -> Gate:
	var section := _game.level.find_section(floor_id)
	for node: Node in section.get_children():
		var gate := node as Gate
		if gate != null and gate.spec.id == gate_id:
			return gate
	return null


func _walk_forward(frames: int) -> void:
	Input.action_press("move_forward")
	await wait_physics_frames(frames)
	Input.action_release("move_forward")
	await wait_physics_frames(20)


func test_walking_up_the_escalator_reaches_level_1() -> void:
	_kill_all("ground_floor")
	var player := _game.level.player
	player.global_position = Vector3(7.0, 0.0, -0.9)
	player.rotation.y = deg_to_rad(-90.0)
	await wait_physics_frames(5)
	await _walk_forward(240)
	assert_almost_eq(player.global_position.y, 5.0, 0.3, "arriba, en el suelo del Nivel 1")
	assert_gt(player.global_position.x, 18.0)
	assert_eq(_game.level.floor_data.id, "level_1")
	assert_eq(GameState.world.current_floor, "level_1")


func test_navigation_connects_every_floor() -> void:
	await wait_physics_frames(10)
	var map := _game.level.player.get_world_3d().navigation_map
	var legs: Array[Array] = [
		[Vector3(7.0, 0.0, -0.9), Vector3(20.0, 5.0, -0.9)],
		[Vector3(-8.8, 5.0, 0.9), Vector3(-20.0, 10.0, 0.9)],
		[Vector3(22.0, 10.0, -4.0), Vector3(25.0, 10.0, -5.0)],
		[Vector3(25.0, 10.0, -5.0), Vector3(31.0, 12.5, -4.0)],
		[Vector3(31.0, 12.5, -4.0), Vector3(25.0, 15.0, -3.0)],
		[Vector3(25.0, 15.0, -3.0), Vector3(21.0, 15.0, -4.0)],
		[Vector3(22.0, 10.0, -4.0), Vector3(21.0, 15.0, -4.0)],
		[Vector3(-22.0, 0.0, 4.0), Vector3(-22.0, 10.0, 4.0)],
		[Vector3(-25.0, 0.0, 4.0), Vector3(-31.0, 2.5, 4.0)],
		[Vector3(-31.0, 2.5, 4.0), Vector3(-25.0, 5.0, 5.0)],
		[Vector3(-22.0, 5.0, 4.0), Vector3(-22.0, 0.0, 4.0)],
	]
	for leg: Array in legs:
		var from: Vector3 = leg[0]
		var to: Vector3 = leg[1]
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		assert_gt(path.size(), 1, "%s -> %s" % [from, to])
		if path.size() > 1:
			var last := path[path.size() - 1]
			assert_lt(last.distance_to(to), 1.0, "%s -> %s llega a %s" % [from, to, last])


func test_walking_down_a_service_flight_reaches_the_half_landing() -> void:
	var player := _game.level.player
	player.global_position = Vector3(-24.8, 5.0, 5.0)
	player.rotation.y = deg_to_rad(90.0)
	await wait_physics_frames(5)
	await _walk_forward(120)
	assert_lt(player.global_position.x, -30.0, "bajó el tramo entero")
	assert_almost_eq(player.global_position.y, 2.5, 0.3, "en el descansillo intermedio")
	assert_eq(_game.level.floor_data.id, "ground_floor", "la mitad de abajo es la planta baja")


func test_walking_up_the_last_roof_flight_reaches_the_roof() -> void:
	var player := _game.level.player
	player.global_position = Vector3(31.0, 12.5, -3.0)
	player.rotation.y = deg_to_rad(90.0)
	await wait_physics_frames(5)
	await _walk_forward(150)
	assert_almost_eq(player.global_position.y, 15.0, 0.3, "en la azotea")
	assert_lt(player.global_position.x, 26.0)


func test_floor_change_autosaves_and_far_floors_sleep() -> void:
	await _travel("level_2", "stairs_down")
	assert_eq(_game.level.floor_data.id, "level_2")
	var result := SaveStore.load_game(GameState.CATALOG.save_context())
	assert_true(result.ok)
	if result.ok:
		assert_eq(result.data["floor"], "level_2")
		assert_eq(result.data["spawn_id"], "stairs_down")
	var ground := _game.level.enemies_on_floor("ground_floor")
	assert_gt(ground.size(), 0)
	for enemy: Enemy in ground:
		assert_eq(enemy.process_mode, Node.PROCESS_MODE_DISABLED, "dos pisos más abajo, dormido")
		assert_false(enemy.visible)
	assert_false(_game.level.find_section("ground_floor").visible)
	assert_true(_game.level.find_section("level_1").visible, "el piso de abajo se ve por el atrio")


func test_state_survives_going_up_and_back_down() -> void:
	var enemies := _game.level.enemies_on_floor("ground_floor")
	var total := enemies.size()
	var victim := enemies[0]
	while not victim.is_dead():
		victim.take_hit(50.0, victim.global_position + Vector3.UP * 0.5, true)
	var container := (
		_node_on("ground_floor", func(node: Node) -> bool: return node is LootContainer)
		as LootContainer
	)
	container.interact(_game.level.player)
	assert_false(container.enabled, "registrado")
	EventBus.item_dropped.emit(
		Vector3(2.0, 0.5, 4.5), ItemStack.new(GameState.items.get_item("rag"))
	)
	GameState.player.take_damage(30.0)
	var health := GameState.player.health
	await _travel("level_2", "stairs_down")
	assert_eq(GameState.player.health, health, "la salud viaja con el jugador")
	await _travel("ground_floor", "stairs_up")
	assert_eq(_game.level.enemies_on_floor("ground_floor").size(), total - 1, "sigue muerto")
	assert_true(container.is_empty(), "sigue vacío")
	_game.level.store_world_state()
	var drops := GameState.world.drops("ground_floor")
	var rag_found := false
	for entry: Dictionary in drops:
		if entry.get("id", "") == "rag":
			rag_found = true
	assert_true(rag_found, "lo soltado queda anotado en su piso")


func test_shortcut_opens_only_from_the_stairwell() -> void:
	var gate := _gate("ground_floor", "shortcut_gate")
	assert_not_null(gate)
	var player := _game.level.player
	player.global_position = Vector3(-22.0, 0.0, 4.0)
	await wait_physics_frames(2)
	assert_eq(gate.get_prompt_key(), "prompt_gate_other_side")
	gate.interact(player)
	assert_false(gate.is_open, "desde el pasillo no se abre")
	player.global_position = Vector3(-25.2, 0.0, 3.0)
	await wait_physics_frames(2)
	assert_eq(gate.get_prompt_key(), "prompt_open_gate", "desde la escalera se abre sin llave")
	gate.interact(player)
	assert_true(gate.is_open)
	assert_true(GameState.world.has_flag("shortcut_l1"))


func test_upper_shortcut_opens_only_from_level_2() -> void:
	var gate := _gate("level_2", "shortcut_gate")
	var player := _game.level.player
	player.global_position = Vector3(-25.2, 10.0, 5.0)
	await wait_physics_frames(2)
	assert_eq(gate.get_prompt_key(), "prompt_gate_other_side", "desde la escalera, no")
	player.global_position = Vector3(-22.0, 10.0, 4.0)
	await wait_physics_frames(2)
	gate.interact(player)
	assert_true(gate.is_open)
	assert_true(GameState.world.has_flag("shortcut_l2"))


func test_security_post_gate_needs_the_key() -> void:
	await _travel("level_1", "stairs_down")
	var gate := _gate("level_1", "security_post_gate")
	assert_not_null(gate)
	assert_eq(gate.get_prompt_key(), "prompt_gate_locked")
	gate.interact(_game.level.player)
	assert_false(gate.is_open, "sin llave no abre")
	GameState.player.keys.add("security_key")
	gate.interact(_game.level.player)
	assert_true(gate.is_open)

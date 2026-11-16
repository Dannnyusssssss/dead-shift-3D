extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Menú principal: «Nueva partida» muestra la elección de dificultad (sin empezar todavía),
## «Volver» regresa al menú y elegir una dificultad empieza la partida con ella.

const MAIN_SCRIPT: GDScript = preload("res://game/main.gd")


func after_each() -> void:
	GameState.next_difficulty = Difficulty.EASY
	GameState.forced_seed = -1
	GameState.set_paused(false)
	InputRouter.gameplay_active = false
	InputRouter.release_capture()
	SaveStore.delete_game()


func _make_menu() -> Control:
	SaveStore.delete_game()
	GameState.forced_seed = 3
	var menu: Control = MAIN_SCRIPT.new()
	add_child_autofree(menu)
	await wait_frames(2)
	return menu


func test_new_game_asks_for_difficulty_then_starts_with_it() -> void:
	var menu := await _make_menu()
	var main_box: Control = menu.get("_main_box")
	var choice: Control = menu.get("_difficulty_box")
	assert_true(main_box.visible)
	assert_false(choice.visible)
	menu.call("_on_new_game")
	assert_false(main_box.visible, "el menú se esconde")
	assert_true(choice.visible, "se elige la dificultad")
	assert_null(menu.get("_game"), "todavía no empieza")
	menu.call("_refresh_menu")
	assert_true(main_box.visible, "«Volver» regresa al menú")
	menu.call("_on_new_game")
	menu.call("_on_difficulty", Difficulty.MEDIUM)
	await wait_physics_frames(2)
	# Primero la intro de la historia; se salta y empieza la partida.
	var intro: Intro = null
	for child: Node in menu.get_children():
		if child is Intro:
			intro = child
	assert_not_null(intro, "antes de la partida va la intro")
	assert_null(menu.get("_game"), "durante la intro todavía no hay partida")
	intro.skip()
	await wait_physics_frames(3)
	assert_not_null(menu.get("_game"), "la partida empezó")
	assert_eq(GameState.difficulty.id(), Difficulty.MEDIUM)
	assert_eq(GameState.rescue.state, RescueClock.STATE_IDLE)


## Morir y volver al último guardado: la partida nueva no hereda nada de la anterior. Antes, la
## partida vieja seguía en el árbol al crear la nueva y la barra del jefe de la planta baja
## mostraba al jefe herido de la partida anterior.
func test_continue_after_death_starts_clean() -> void:
	var menu := await _make_menu()
	menu.call("_on_new_game")
	menu.call("_on_difficulty", Difficulty.EASY)
	await wait_physics_frames(2)
	for child: Node in menu.get_children():
		if child is Intro:
			(child as Intro).skip()
	await wait_frames(40)
	var old_game: Game = menu.get("_game")
	assert_not_null(old_game)
	assert_true(SaveStore.has_game(), "autoguardado en la sala de seguridad")
	var old_boss := get_tree().get_first_node_in_group("boss") as Boss
	old_boss.boss_state = Boss.B_CHASE
	old_boss.take_hit(120.0, old_boss.global_position, true)
	EventBus.boss_changed.emit()
	old_game.level.player.receive_toxic_damage(1000.0)
	await wait_physics_frames(3)
	assert_true(old_game.finished, "el jugador murió")
	menu.call("_continue_from_save")
	await wait_physics_frames(6)
	assert_false(is_instance_valid(old_game), "la partida vieja se liberó")
	var new_game: Game = menu.get("_game")
	assert_not_null(new_game)
	assert_ne(new_game, old_game)
	var bosses := get_tree().get_nodes_in_group("boss")
	assert_eq(bosses.size(), 1, "solo existe el jefe de la partida cargada")
	var boss := bosses[0] as Boss
	assert_eq(boss.boss_state, Boss.B_IDLE)
	assert_almost_eq(boss.model.health_fraction(), 1.0, 0.001, "vida completa")
	var bar := _find_boss_bar(new_game)
	assert_not_null(bar)
	var name_label: Label = bar.get("_name")
	assert_false(name_label.visible, "sin barra del jefe en la planta baja")
	assert_false(new_game.finished)
	assert_gt(GameState.player.health, 0.0)
	assert_eq(GameState.rescue.state, RescueClock.STATE_IDLE)


func _find_boss_bar(root: Node) -> BossBar:
	for node: Node in root.find_children("*", "VBoxContainer", true, false):
		if node is BossBar:
			return node
	return null


## «Volver al inicio» en la pausa pide un segundo toque y después cierra la partida y muestra
## el menú principal.
func test_pause_returns_to_main_menu_after_confirming() -> void:
	var menu := await _make_menu()
	menu.call("_on_new_game")
	menu.call("_on_difficulty", Difficulty.EASY)
	await wait_physics_frames(2)
	for child: Node in menu.get_children():
		if child is Intro:
			(child as Intro).skip()
	await wait_physics_frames(3)
	var game: Game = menu.get("_game")
	assert_not_null(game)
	GameState.set_paused(true)
	var pause: PauseMenu = null
	for node: Node in game.find_children("*", "Control", true, false):
		if node is PauseMenu:
			pause = node
	pause.call("_on_main_menu")
	await wait_frames(2)
	assert_eq(menu.get("_game"), game, "el primer toque solo pide confirmación")
	pause.call("_on_main_menu")
	await wait_physics_frames(4)
	assert_null(menu.get("_game"), "la partida se cerró")
	assert_false(is_instance_valid(game))
	var main_box: Control = menu.get("_main_box")
	assert_true(main_box.visible, "se ve el menú principal")
	assert_false(GameState.paused)

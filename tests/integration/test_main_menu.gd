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
	await wait_physics_frames(3)
	assert_not_null(menu.get("_game"), "la partida empezó")
	assert_eq(GameState.difficulty.id(), Difficulty.MEDIUM)
	assert_eq(GameState.rescue.state, RescueClock.STATE_IDLE)

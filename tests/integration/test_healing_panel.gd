extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Curación visible con la partida completa: el panel lateral muestra qué se usa y qué hará
## (antes y después), y los antibióticos suman tiempo a la cuenta de la infección.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")

var _game: Game


func before_each() -> void:
	SaveStore.delete_game()
	GameState.forced_seed = 3
	_game = GAME_SCRIPT.new()
	add_child_autofree(_game)
	await wait_physics_frames(3)


func after_each() -> void:
	GameState.forced_seed = -1
	InputRouter.gameplay_active = false
	InputRouter.release_capture()
	SaveStore.delete_game()


func _panel() -> HealingPanel:
	var found := _game.find_children("*", "HealingPanel", true, false)
	return found[0] as HealingPanel if not found.is_empty() else null


func test_antibiotics_show_their_effect_and_add_time() -> void:
	var state := GameState.player
	state.infection.add_exposure(1.0)
	state.infection.time_left = 100.0
	state.inventory.add_item(GameState.items.get_item("antibiotics"), 1)
	var slot := state.inventory.find_slot("antibiotics")
	assert_eq(_game.level.player.healing.start(slot), PlayerState.USE_OK)
	await wait_process_frames(5)
	var panel := _panel()
	assert_not_null(panel)
	assert_true(panel.visible, "se ve mientras dura")
	var shown := panel.find_children("*", "Label", true, false)
	var texts := ""
	for label: Node in shown:
		texts += (label as Label).text + "\n"
	assert_string_contains(texts, "+90 s")
	assert_string_contains(texts, tr("heal_exposed"))
	await wait_seconds(2.5)
	assert_false(_game.level.player.healing.active)
	assert_gt(state.infection.time_left, 180.0, "sumó 90 s (menos lo que pasó usándolos)")
	assert_eq(state.inventory.count_of("antibiotics"), 0)


func test_bandage_shows_health_before_and_after() -> void:
	var state := GameState.player
	state.take_damage(50.0)
	state.inventory.add_item(GameState.items.get_item("bandage"), 1)
	var slot := state.inventory.find_slot("bandage")
	assert_eq(_game.level.player.healing.start(slot), PlayerState.USE_OK)
	await wait_process_frames(5)
	var texts := ""
	for label: Node in _panel().find_children("*", "Label", true, false):
		texts += (label as Label).text + "\n"
	assert_string_contains(texts, "(50 → 85)")


## Regresión: con decimales, (cuenta + 90) - cuenta da 90,00000000000001 y se mostraba «+91 s».
func test_added_time_is_rounded_not_ceiled() -> void:
	var state := GameState.player
	state.infection.add_exposure(1.0)
	state.infection.time_left = 38.08108108108108
	var panel := HealingPanel.new()
	add_child_autofree(panel)
	var text: String = panel.call("_effect_text", GameState.items.get_item("antibiotics"))
	assert_string_contains(text, "+90 s")


## Al terminar de combinar (bate con clavos) el panel «Combinando…» se oculta solo.
func test_crafting_panel_hides_when_done() -> void:
	var inventory := GameState.player.inventory
	inventory.add_stack(ItemStack.new(GameState.items.get_item("bat")))
	inventory.add_item(GameState.items.get_item("nails"), 5)
	var recipe: RecipeData = null
	for candidate: RecipeData in GameState.CATALOG.recipes:
		if candidate.id == "bat_nails":
			recipe = candidate
	var crafting := _game.level.player.crafting
	assert_eq(crafting.start(recipe, inventory.find_slot("bat")), Crafting.ERROR_NONE)
	await wait_process_frames(5)
	var panel := _panel()
	assert_true(panel.visible, "se ve mientras combina")
	for _step: int in 60:
		await wait_physics_frames(10)
		if not crafting.active:
			break
	assert_false(crafting.active)
	await wait_process_frames(3)
	assert_false(panel.visible, "se oculta al terminar")

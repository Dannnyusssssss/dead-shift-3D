extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Recoger, registrar contenedores, cambiar de chaleco y combinar en juego (con tiempo, ruido
## y jugador indefenso), en una escena mínima.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")

var _world: Node3D
var _player: Player
var _spawner: LootSpawner


func before_each() -> void:
	GameState.start_new_run()
	_world = Node3D.new()
	add_child_autofree(_world)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(shape)
	_world.add_child(ground)
	_spawner = LootSpawner.new()
	_world.add_child(_spawner)
	_player = PLAYER_SCENE.instantiate()
	_world.add_child(_player)


func _pickup(item_id: String, count: int = 1, fraction: float = 1.0) -> Pickup:
	var pickup := Pickup.new()
	pickup.item_id = item_id
	pickup.count = count
	pickup.durability_fraction = fraction
	_world.add_child(pickup)
	return pickup


func test_pickup_goes_to_inventory() -> void:
	var pickup := _pickup("nails", 3)
	await wait_physics_frames(1)
	pickup.interact(_player)
	assert_eq(GameState.player.inventory.count_of("nails"), 3)
	assert_true(pickup.is_queued_for_deletion())


func test_full_inventory_keeps_pickup() -> void:
	var nails := GameState.items.get_item("nails")
	while not GameState.player.inventory.is_full():
		GameState.player.inventory.add_stack(ItemStack.new(GameState.items.get_item("pipe")))
	watch_signals(EventBus)
	var pickup := _pickup("bat")
	await wait_physics_frames(1)
	pickup.interact(_player)
	assert_signal_emitted_with_parameters(EventBus, "user_message", ["msg_inventory_full"])
	assert_false(pickup.is_queued_for_deletion())
	assert_not_null(nails)


func test_container_gives_hidden_ammo() -> void:
	var drawer := LootContainer.new()
	drawer.contents = PackedStringArray(["pistol_ammo:6", "tape:1", "unknown_thing:3"])
	_world.add_child(drawer)
	await wait_physics_frames(1)
	var before := GameState.player.inventory.count_of("pistol_ammo")
	drawer.interact(_player)
	assert_eq(GameState.player.inventory.count_of("pistol_ammo"), before + 6)
	assert_eq(GameState.player.inventory.count_of("tape"), 1)
	assert_true(drawer.is_empty())
	assert_eq(drawer.get_prompt_key(), "", "registrado ya no ofrece interacción")


func test_vest_swap_leaves_old_vest_on_floor() -> void:
	var first := _pickup("vest", 1, 0.3)
	await wait_physics_frames(1)
	first.interact(_player)
	assert_almost_eq(GameState.player.vest.durability.fraction(), 0.3, 0.001)
	var better := _pickup("vest", 1, 0.9)
	await wait_physics_frames(1)
	assert_eq(better.get_prompt_key(), "prompt_swap_vest")
	better.interact(_player)
	await wait_physics_frames(1)
	assert_almost_eq(GameState.player.vest.durability.fraction(), 0.9, 0.001)
	var on_floor := get_tree().get_nodes_in_group("pickup").filter(
		func(node: Node) -> bool: return not node.is_queued_for_deletion()
	)
	assert_eq(on_floor.size(), 1, "el chaleco viejo queda en el suelo")
	var old: Pickup = on_floor[0]
	assert_almost_eq(old.stack.durability.fraction(), 0.3, 0.001)


func test_crafting_takes_time_blocks_and_makes_noise() -> void:
	var inventory := GameState.player.inventory
	inventory.add_stack(ItemStack.new(GameState.items.get_item("bat")))
	inventory.add_item(GameState.items.get_item("nails"), 5)
	var bat_slot := inventory.find_slot("bat")
	NoiseSystem.last_level = -1
	assert_eq(_player.crafting.start(_recipe("bat_nails"), bat_slot), Crafting.ERROR_NONE)
	await wait_physics_frames(3)
	assert_true(_player.crafting.active)
	assert_true(_player.hands_busy, "manos ocupadas mientras combina")
	assert_true(_player.controls_enabled, "pero puede mirar y caminar")
	assert_eq(NoiseSystem.last_level, Rules.NOISE_CRAFT, "combinar hace ruido")
	assert_eq(inventory.count_of("bat_nails"), 0, "todavía no terminó")
	for _step: int in 60:
		await wait_physics_frames(10)
		if not _player.crafting.active:
			break
	assert_false(_player.crafting.active)
	assert_true(_player.controls_enabled)
	assert_eq(inventory.count_of("bat_nails"), 1)
	assert_eq(inventory.count_of("nails"), 1, "gasta 4 clavos de la bolsa")
	assert_eq(GameState.player.items_crafted, 1)


func test_phone_is_assembled_by_hand_over_time() -> void:
	var keys := GameState.player.keys
	assert_eq(_player.crafting.start_phone(), Crafting.ERROR_NO_RECIPE, "sin piezas no se arma")
	for part: String in Rules.PHONE_PARTS:
		keys.add(part)
	GameState.world.set_flag(Discovery.NOTE_FLAG)
	NoiseSystem.last_level = -1
	assert_eq(_player.crafting.start_phone(), Crafting.ERROR_NONE)
	assert_eq(_player.crafting.start_phone(), PlayerCrafting.ERROR_BUSY, "ya está armándolo")
	await wait_physics_frames(3)
	assert_true(_player.crafting.is_phone())
	assert_true(_player.hands_busy, "manos ocupadas mientras lo arma")
	assert_eq(_player.arms.current_action(), "craft_assemble", "las manos lo ensamblan")
	assert_eq(NoiseSystem.last_level, Rules.NOISE_CRAFT, "armarlo hace ruido")
	assert_false(keys.phone_assembled, "todavía no terminó")
	assert_eq(_player.crafting.description()[2], "phone")
	for _step: int in 60:
		await wait_physics_frames(10)
		if not _player.crafting.active:
			break
	assert_false(_player.crafting.active)
	assert_true(keys.phone_assembled)
	assert_false(_player.crafting.is_phone())


func test_cancelled_phone_stays_in_parts() -> void:
	var keys := GameState.player.keys
	for part: String in Rules.PHONE_PARTS:
		keys.add(part)
	GameState.world.set_flag(Discovery.NOTE_FLAG)
	assert_eq(_player.crafting.start_phone(), Crafting.ERROR_NONE)
	await wait_physics_frames(3)
	_player.crafting.cancel()
	assert_false(_player.crafting.active)
	assert_false(keys.phone_assembled, "cancelado: sigue en piezas")
	assert_eq(_player.crafting.start_phone(), Crafting.ERROR_NONE, "se puede volver a empezar")
	_player.crafting.cancel()


func test_crafting_rejects_missing_material_and_wrong_slot() -> void:
	var inventory := GameState.player.inventory
	inventory.add_item(GameState.items.get_item("rag"), 1)
	inventory.add_item(GameState.items.get_item("tape"), 1)
	var problem := _player.crafting.start(_recipe("improvised_bandage"), -1)
	assert_eq(problem, Crafting.ERROR_MISSING, "la venda improvisada pide 2 trapos")
	var pistol_slot := inventory.find_slot("pistol")
	assert_eq(_player.crafting.start(_recipe("bat_nails"), pistol_slot), Crafting.ERROR_NO_RECIPE)
	assert_false(_player.crafting.active)
	assert_true(_player.controls_enabled)


func test_crafting_the_weapon_in_hand_equips_the_result() -> void:
	var inventory := GameState.player.inventory
	inventory.add_stack(ItemStack.new(GameState.items.get_item("pipe")))
	inventory.add_item(GameState.items.get_item("nails"), 4)
	var pipe_slot := inventory.find_slot("pipe")
	assert_true(GameState.player.select_slot(pipe_slot))
	assert_eq(_player.crafting.start(_recipe("pipe_nails"), pipe_slot), Crafting.ERROR_NONE)
	for _step: int in 60:
		await wait_physics_frames(10)
		if not _player.crafting.active:
			break
	assert_eq(GameState.player.equipped().id(), "pipe_nails")
	assert_eq(inventory.count_of("nails"), 0)


func test_noise_bottle_is_made_from_materials_and_lures() -> void:
	var inventory := GameState.player.inventory
	inventory.add_item(GameState.items.get_item("bottle"), 1)
	inventory.add_item(GameState.items.get_item("rag"), 1)
	assert_eq(_player.crafting.start(_recipe("noise_bottle"), -1), Crafting.ERROR_NONE)
	for _step: int in 60:
		await wait_physics_frames(10)
		if not _player.crafting.active:
			break
	assert_eq(inventory.bag.count("noise_bottle"), 1, "la botella ruidosa va a la bolsa")
	assert_true(_player.throw_material("noise_bottle"))
	var heard := 0
	for _step: int in 40:
		NoiseSystem.last_level = -1
		await wait_physics_frames(15)
		if NoiseSystem.last_level == Rules.NOISE_HIGH:
			heard += 1
	assert_gt(heard, 2, "sigue sonando unos segundos donde cae")


func _recipe(recipe_id: String) -> RecipeData:
	for recipe: RecipeData in GameState.CATALOG.recipes:
		if recipe.id == recipe_id:
			return recipe
	return null


func test_open_inventory_blocks_pointer_capture() -> void:
	# Regresión: un clic en un botón de la mochila capturaba el puntero y escondía el cursor.
	var panel := InventoryPanel.new()
	add_child_autofree(panel)
	panel.bind_player(_player)
	InputRouter.gameplay_active = true
	InputRouter.touch_mode = false
	panel.open()
	assert_true(panel.is_open())
	assert_false(InputRouter.can_capture(), "con la mochila abierta no se captura")
	assert_false(_player.controls_enabled)
	panel.close()
	assert_true(InputRouter.can_capture(), "al cerrarla se puede volver a capturar")
	assert_true(_player.controls_enabled)
	InputRouter.gameplay_active = false


func test_combine_tab_lists_ready_recipes_and_starts_with_one_tap() -> void:
	var inventory := GameState.player.inventory
	inventory.add_stack(ItemStack.new(GameState.items.get_item("bat")))
	inventory.add_item(GameState.items.get_item("nails"), 4)
	inventory.add_item(GameState.items.get_item("rag"), 1)
	var panel := InventoryPanel.new()
	add_child_autofree(panel)
	panel.bind_player(_player)
	InputRouter.gameplay_active = true
	panel.open(InventoryPanel.TAB_COMBINE)
	await wait_frames(2)
	var buttons: Array[TapButton] = []
	var texts := ""
	for node: Node in panel.find_children("*", "", true, false):
		var label := node as Label
		if label != null and label.is_visible_in_tree():
			texts += label.text + "\n"
		var button := node as TapButton
		if button != null and button.is_visible_in_tree() and not button.disabled:
			if button.text.begins_with(tr("inventory_combine")) and button.text.ends_with(" s)"):
				buttons.append(button)
	assert_string_contains(texts, tr("item_bat_nails"), "lo que se puede hacer ya")
	assert_string_contains(texts, tr("combine_missing") % tr("item_pipe"), "y lo que falta")
	var partial := tr("combine_missing") % (tr("item_rag") + " (1/2), " + tr("item_tape"))
	assert_string_contains(texts, partial, "con las cantidades que faltan")
	assert_eq(buttons.size(), 1, "un botón por combinación posible")
	buttons[0].pressed.emit()
	assert_true(_player.crafting.active, "un toque empieza a combinar")
	assert_false(panel.is_open(), "y la mochila se cierra")
	_player.crafting.cancel()
	InputRouter.gameplay_active = false


func test_enemy_loot_spawns_pickups() -> void:
	var drops: Array[ItemStack] = [ItemStack.new(GameState.items.get_item("pistol_ammo"), 5)]
	EventBus.enemy_died.emit(Vector3(3.0, 0.0, 3.0), drops)
	await wait_physics_frames(1)
	var pickups := get_tree().get_nodes_in_group("pickup")
	assert_eq(pickups.size(), 1)


func test_healing_takes_time_and_leaves_player_exposed() -> void:
	GameState.player.take_damage(40.0)
	GameState.player.inventory.add_item(GameState.items.get_item("bandage"), 1)
	var slot := GameState.player.inventory.find_slot("bandage")
	var before := GameState.player.health
	assert_eq(_player.healing.start(slot), PlayerState.USE_OK)
	assert_true(_player.hands_busy, "curarse ocupa las manos")
	assert_true(_player.controls_enabled, "pero puede mirar y caminar despacio")
	await wait_physics_frames(30)
	assert_eq(GameState.player.health, before, "todavía no termina")
	for _step: int in 20:
		await wait_physics_frames(10)
		if not _player.healing.active:
			break
	assert_false(_player.healing.active)
	assert_gt(GameState.player.health, before)
	assert_true(_player.controls_enabled)
	assert_eq(GameState.player.inventory.count_of("bandage"), 0)


func test_infection_countdown_ends_the_run() -> void:
	watch_signals(EventBus)
	GameState.player.infection.add_exposure(1.0)
	GameState.player.infection.time_left = 0.2
	await wait_physics_frames(30)
	assert_signal_emitted(EventBus, "player_died")
	assert_eq(GameState.player.death_cause, PlayerState.CAUSE_INFECTION)
	assert_false(_player.controls_enabled)


func test_healing_allows_slow_walking_but_not_shooting() -> void:
	GameState.player.take_damage(40.0)
	GameState.player.inventory.add_item(GameState.items.get_item("bandage"), 1)
	var slot := GameState.player.inventory.find_slot("bandage")
	var loaded := GameState.player.equipped().ammo_loaded
	assert_eq(_player.healing.start(slot), PlayerState.USE_OK)
	await wait_physics_frames(3)
	var start := _player.global_position
	Input.action_press("move_forward")
	Input.action_press("attack")
	await wait_physics_frames(30)
	Input.action_release("attack")
	Input.action_release("move_forward")
	var moved := _player.global_position.distance_to(start)
	assert_gt(moved, 0.3, "puede caminar")
	assert_lt(moved, Rules.PLAYER_BUSY_SPEED * 0.6, "pero despacio")
	assert_eq(GameState.player.equipped().ammo_loaded, loaded, "no dispara mientras se cura")


func _tap(action: String) -> void:
	Input.action_press(action)
	await wait_physics_frames(2)
	Input.action_release(action)
	await wait_physics_frames(2)


func test_throw_readies_with_an_arc_then_throws_without_firing() -> void:
	GameState.player.inventory.add_item(GameState.items.get_item("bottle"), 2)
	var loaded := GameState.player.equipped().ammo_loaded
	await _tap("throw")
	assert_eq(_player.throw.ready_item, "bottle", "la G deja el objeto listo")
	assert_eq(GameState.player.inventory.count_of("bottle"), 2, "todavía no lo lanza")
	await _tap("aim")
	assert_eq(_player.throw.ready_item, "", "clic derecho cancela")
	await _tap("throw")
	await _tap("attack")
	assert_eq(_player.throw.ready_item, "")
	assert_eq(GameState.player.inventory.count_of("bottle"), 1, "el clic lo lanza")
	assert_eq(GameState.player.equipped().ammo_loaded, loaded, "y no dispara la pistola")


func test_heal_key_uses_a_bandage_without_opening_the_bag() -> void:
	GameState.player.take_damage(40.0)
	GameState.player.inventory.add_item(GameState.items.get_item("bandage"), 1)
	await _tap("heal")
	assert_true(_player.healing.active, "la H empieza a curar")
	assert_eq(_player.healing.current_item().id, "bandage")


func test_pickup_prompt_names_the_item() -> void:
	var pickup := _pickup("bandage", 2)
	await wait_physics_frames(1)
	assert_eq(pickup.get_prompt_detail(), tr("item_bandage") + " x2")

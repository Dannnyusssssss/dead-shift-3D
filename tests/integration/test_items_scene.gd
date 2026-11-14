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
	inventory.add_item(GameState.items.get_item("nails"), 2)
	var bat_slot := inventory.find_slot("bat")
	var nails_slot := inventory.find_slot("nails")
	NoiseSystem.last_level = -1
	assert_eq(_player.crafting.start(bat_slot, nails_slot), Crafting.ERROR_NONE)
	await wait_physics_frames(3)
	assert_true(_player.crafting.active)
	assert_false(_player.controls_enabled, "indefenso mientras combina")
	assert_eq(NoiseSystem.last_level, Rules.NOISE_CRAFT, "combinar hace ruido")
	assert_eq(inventory.count_of("bat_nails"), 0, "todavía no terminó")
	for _step: int in 60:
		await wait_physics_frames(10)
		if not _player.crafting.active:
			break
	assert_false(_player.crafting.active)
	assert_true(_player.controls_enabled)
	assert_eq(inventory.count_of("bat_nails"), 1)
	assert_eq(inventory.count_of("nails"), 1)
	assert_eq(GameState.player.items_crafted, 1)


func test_crafting_rejects_invalid_pair() -> void:
	var inventory := GameState.player.inventory
	inventory.add_item(GameState.items.get_item("nails"), 1)
	inventory.add_item(GameState.items.get_item("rag"), 1)
	var problem := _player.crafting.start(inventory.find_slot("nails"), inventory.find_slot("rag"))
	assert_eq(problem, Crafting.ERROR_NO_RECIPE)
	assert_true(_player.controls_enabled)


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


func test_enemy_loot_spawns_pickups() -> void:
	var drops: Array[ItemStack] = [ItemStack.new(GameState.items.get_item("pistol_ammo"), 5)]
	EventBus.enemy_died.emit(Vector3(3.0, 0.0, 3.0), drops)
	await wait_physics_frames(1)
	var pickups := get_tree().get_nodes_in_group("pickup")
	assert_eq(pickups.size(), 1)

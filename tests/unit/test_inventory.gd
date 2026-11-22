extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Inventario limitado: apilado, casillas llenas, quitar, sacar y guardar.

const Fixtures = preload("res://tests/helpers/fixtures.gd")


func test_stackable_items_merge_until_max() -> void:
	var inventory := Inventory.new(3)
	var nails := Fixtures.stackable("nails", 5)
	assert_eq(inventory.add_item(nails, 7), 0)
	assert_eq(inventory.used_slots(), 2)
	assert_eq(inventory.count_of("nails"), 7)
	inventory.add_item(nails, 2)
	assert_eq(inventory.used_slots(), 2, "se completa la casilla de 2 antes de abrir otra")


func test_full_inventory_returns_leftover() -> void:
	var inventory := Inventory.new(2)
	var nails := Fixtures.stackable("nails", 5)
	assert_eq(inventory.add_item(nails, 12), 2)
	assert_true(inventory.is_full())


func test_weapons_take_one_slot_each() -> void:
	var inventory := Inventory.new(2)
	assert_true(inventory.add_stack(ItemStack.new(Fixtures.melee("pipe"))))
	assert_true(inventory.add_stack(ItemStack.new(Fixtures.melee("bat"))))
	assert_false(inventory.add_stack(ItemStack.new(Fixtures.melee("knife"))))


func test_remove_count_spans_slots() -> void:
	var inventory := Inventory.new(3)
	inventory.add_item(Fixtures.stackable("ammo", 5), 8)
	assert_eq(inventory.remove_count("ammo", 6), 6)
	assert_eq(inventory.count_of("ammo"), 2)
	assert_eq(inventory.remove_count("ammo", 10), 2, "solo quita lo que hay")
	assert_eq(inventory.used_slots(), 0)


func test_take_and_put_slot() -> void:
	var inventory := Inventory.new(2)
	inventory.add_stack(ItemStack.new(Fixtures.melee("pipe")))
	var stack := inventory.take_slot(0)
	assert_not_null(stack)
	assert_null(inventory.get_slot(0))
	assert_true(inventory.put_slot(1, stack))
	assert_false(inventory.put_slot(1, stack), "casilla ocupada")
	assert_false(inventory.put_slot(9, stack), "fuera de rango")


func test_out_of_range_slot_is_null() -> void:
	var inventory := Inventory.new(2)
	assert_null(inventory.get_slot(-1))
	assert_null(inventory.get_slot(5))


func test_remove_broken_weapons() -> void:
	var inventory := Inventory.new(3)
	inventory.add_stack(ItemStack.new(Fixtures.melee("pipe"), 1, 0.0))
	inventory.add_stack(ItemStack.new(Fixtures.melee("bat")))
	assert_eq(inventory.remove_broken(), 1)
	assert_eq(inventory.used_slots(), 1)


func test_save_round_trip_keeps_wear_and_ammo() -> void:
	var pipe := Fixtures.melee("pipe")
	var pistol := Fixtures.pistol()
	var nails := Fixtures.stackable("nails", 20)
	var catalog := ItemCatalog.new([pipe, pistol, nails])
	var inventory := Inventory.new(4)
	inventory.add_stack(ItemStack.new(pipe, 1, 0.4))
	var gun := ItemStack.new(pistol)
	gun.ammo_loaded = 5
	inventory.add_stack(gun)
	inventory.add_item(nails, 7)
	var restored := Inventory.new(4)
	restored.load_data(inventory.to_data(), catalog)
	assert_almost_eq(restored.get_slot(0).durability.fraction(), 0.4, 0.0001)
	assert_eq(restored.get_slot(1).ammo_loaded, 5)
	assert_eq(restored.count_of("nails"), 7)


func test_load_ignores_unknown_items() -> void:
	var catalog := ItemCatalog.new([Fixtures.stackable("nails")])
	var inventory := Inventory.new(2)
	var entries: Array[Dictionary] = [{"slot": 0, "id": "rocket", "count": 1}]
	inventory.load_data(entries, catalog)
	assert_eq(inventory.used_slots(), 0)


func test_bound_item_uses_fixed_slot_not_space() -> void:
	var inventory := Inventory.new(2)
	var baton := Fixtures.melee("baton")
	baton.bound = true
	assert_true(inventory.add_stack(ItemStack.new(baton)))
	assert_eq(inventory.find_slot("baton"), inventory.fixed_slot())
	assert_eq(inventory.used_slots(), 0, "la porra no ocupa casilla")
	assert_true(inventory.add_stack(ItemStack.new(Fixtures.melee("pipe"))))
	assert_true(inventory.add_stack(ItemStack.new(Fixtures.melee("bat"))))
	assert_true(inventory.is_full())
	assert_false(inventory.add_stack(ItemStack.new(Fixtures.melee("knife"))))
	assert_eq(inventory.capacity(), inventory.space() + 1, "se recorre con la posición fija")


func test_fixed_slot_only_takes_bound_items_and_is_not_saved() -> void:
	var inventory := Inventory.new(2)
	assert_false(inventory.put_fixed(ItemStack.new(Fixtures.melee("pipe"))))
	assert_false(inventory.put_slot(inventory.fixed_slot(), ItemStack.new(Fixtures.melee("pipe"))))
	var baton := Fixtures.melee("baton")
	baton.bound = true
	inventory.add_stack(ItemStack.new(baton))
	assert_eq(inventory.to_data().size(), 0, "la porra se repone al cargar, no se guarda")

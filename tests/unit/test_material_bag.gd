extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Bolsa de materiales: tope por material, quitar, orden, ida y vuelta del guardado, datos
## hostiles al cargar y su integración con el inventario (no ocupa casillas).

const Fixtures = preload("res://tests/helpers/fixtures.gd")

var _nails: ItemData
var _rag: ItemData
var _ammo: ItemData
var _catalog: ItemCatalog


func before_each() -> void:
	_nails = Fixtures.material("nails", 30)
	_rag = Fixtures.material("rag", 10)
	_ammo = Fixtures.stackable("ammo", 60)
	_catalog = ItemCatalog.new([_nails, _rag, _ammo])


func test_cap_per_material_and_leftover() -> void:
	var bag := MaterialBag.new()
	assert_eq(bag.add(_nails, 6), 0)
	assert_eq(bag.add(_nails, 30), 6, "no pasa de 30")
	assert_eq(bag.count("nails"), 30)
	assert_eq(bag.space_for(_nails), 0)
	assert_eq(bag.add(_rag, 3), 0, "otro material tiene su propio tope")
	assert_eq(bag.add(_ammo, 5), 5, "lo que no es material no entra")
	assert_eq(bag.add(_rag, -2), 0, "cantidad negativa: nada")
	assert_eq(bag.count("rag"), 3)


func test_remove_never_goes_below_zero() -> void:
	var bag := MaterialBag.new()
	bag.add(_rag, 3)
	assert_eq(bag.remove("rag", 2), 2)
	assert_eq(bag.remove("rag", 5), 1, "solo lo que hay")
	assert_eq(bag.count("rag"), 0)
	assert_true(bag.is_empty())
	assert_eq(bag.remove("nada", 1), 0)
	assert_eq(bag.remove("rag", -1), 0)


func test_ids_follow_catalog_order() -> void:
	var bag := MaterialBag.new()
	bag.add(_rag, 1)
	bag.add(_nails, 1)
	assert_eq(bag.ids(_catalog), ["nails", "rag"])


func test_save_round_trip_and_hostile_data() -> void:
	var bag := MaterialBag.new()
	bag.add(_nails, 12)
	bag.add(_rag, 2)
	var restored := MaterialBag.new()
	restored.load_data(bag.to_data(), _catalog)
	assert_eq(restored.count("nails"), 12)
	assert_eq(restored.count("rag"), 2)
	var hostile := MaterialBag.new()
	hostile.load_data({"nails": 999, "ammo": 4, "nada": 3, 7: 2, "rag": "x", "rag2": -1}, _catalog)
	assert_eq(hostile.count("nails"), 30, "recortado al tope")
	assert_eq(hostile.count("ammo"), 0, "no es material")
	assert_eq(hostile.count("nada"), 0, "desconocido")
	assert_eq(hostile.count("rag"), 0, "tipo erróneo")


func test_inventory_routes_materials_to_the_bag() -> void:
	var inventory := Inventory.new(2)
	inventory.add_item(_nails, 6)
	inventory.add_stack(ItemStack.new(_rag, 3))
	assert_eq(inventory.used_slots(), 0, "no ocupan casillas")
	assert_eq(inventory.count_of("nails"), 6)
	assert_true(inventory.can_fit(_nails, 24))
	assert_false(inventory.can_fit(_nails, 25))
	assert_eq(inventory.remove_count("nails", 4), 4)
	assert_eq(inventory.bag.count("nails"), 2)


func test_old_material_slots_load_into_the_bag() -> void:
	var inventory := Inventory.new(4)
	var entries: Array[Dictionary] = [{"slot": 0, "id": "nails", "count": 5}]
	inventory.load_data(entries, _catalog)
	assert_eq(inventory.used_slots(), 0)
	assert_eq(inventory.bag.count("nails"), 5)

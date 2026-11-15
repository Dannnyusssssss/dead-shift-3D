extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Crafteo: recetas de dos objetos en cualquier orden, gasto de lo usado, herencia del
## desgaste, reparación con cinta y casos de error.

const Fixtures = preload("res://tests/helpers/fixtures.gd")

var _bat: ItemData
var _nails: ItemData
var _tape: ItemData
var _bat_nails: ItemData
var _crafting: Crafting


func before_each() -> void:
	_bat = Fixtures.melee("bat", 60.0, 4.0)
	_nails = Fixtures.material("nails", 20)
	_tape = Fixtures.material("tape", 5)
	_bat_nails = Fixtures.melee("bat_nails", 45.0, 5.0)
	var catalog := ItemCatalog.new([_bat, _nails, _tape, _bat_nails])
	var recipes: Array[RecipeData] = [
		Fixtures.recipe("bat", "nails", "bat_nails"),
		Fixtures.recipe("tape", "", "", 0.5),
	]
	_crafting = Crafting.new(recipes, catalog)


func test_combines_in_any_order_and_consumes_inputs() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(_nails, 3)
	inventory.add_stack(ItemStack.new(_bat))
	assert_eq(_crafting.craft(inventory, 0, 1), Crafting.ERROR_NONE)
	assert_eq(inventory.count_of("bat"), 0)
	assert_eq(inventory.count_of("nails"), 2, "gasta un clavo")
	assert_eq(inventory.count_of("bat_nails"), 1)


func test_result_inherits_weapon_wear_fraction() -> void:
	var inventory := Inventory.new(4)
	inventory.add_stack(ItemStack.new(_bat, 1, 0.5))
	inventory.add_item(_nails, 1)
	_crafting.craft(inventory, 0, 1)
	var result := inventory.get_slot(inventory.find_slot("bat_nails"))
	assert_almost_eq(result.durability.fraction(), 0.5, 0.0001)
	assert_eq(result.durability.max_value, 45.0, "usa la durabilidad propia del resultado")


func test_no_recipe() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(_nails, 1)
	inventory.add_item(_tape, 1)
	assert_eq(_crafting.craft(inventory, 0, 1), Crafting.ERROR_NO_RECIPE)
	assert_eq(inventory.used_slots(), 2, "no gasta nada")


func test_same_or_empty_slot() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(_nails, 2)
	assert_eq(_crafting.check(inventory, 0, 0), Crafting.ERROR_SAME_SLOT)
	assert_eq(_crafting.check(inventory, 0, 3), Crafting.ERROR_EMPTY_SLOT)


func test_no_space_when_both_inputs_remain() -> void:
	var stacked_bat := Fixtures.material("bat", 5)
	var catalog := ItemCatalog.new([stacked_bat, _nails, _bat_nails])
	var recipes: Array[RecipeData] = [Fixtures.recipe("bat", "nails", "bat_nails")]
	var crafting := Crafting.new(recipes, catalog)
	var inventory := Inventory.new(2)
	inventory.add_item(stacked_bat, 2)
	inventory.add_item(_nails, 2)
	assert_eq(crafting.craft(inventory, 0, 1), Crafting.ERROR_NO_SPACE)
	assert_eq(inventory.count_of("nails"), 2, "no gasta nada si no hay sitio")


func test_tape_repairs_damaged_weapon_in_place() -> void:
	var inventory := Inventory.new(4)
	inventory.add_stack(ItemStack.new(_bat, 1, 0.2))
	inventory.add_item(_tape, 2)
	assert_eq(_crafting.craft(inventory, 1, 0), Crafting.ERROR_NONE)
	assert_almost_eq(inventory.get_slot(0).durability.fraction(), 0.7, 0.0001)
	assert_eq(inventory.count_of("tape"), 1)


func test_tape_does_not_repair_full_or_broken_weapon() -> void:
	var inventory := Inventory.new(4)
	inventory.add_stack(ItemStack.new(_bat))
	inventory.add_stack(ItemStack.new(_bat, 1, 0.0))
	inventory.add_item(_tape, 1)
	assert_eq(_crafting.check(inventory, 0, 2), Crafting.ERROR_NO_RECIPE, "entera")
	assert_eq(_crafting.check(inventory, 1, 2), Crafting.ERROR_NO_RECIPE, "rota")


func test_unknown_result_is_rejected() -> void:
	var recipes: Array[RecipeData] = [Fixtures.recipe("bat", "nails", "missing")]
	var crafting := Crafting.new(recipes, ItemCatalog.new([_bat, _nails]))
	var inventory := Inventory.new(4)
	inventory.add_stack(ItemStack.new(_bat))
	inventory.add_item(_nails, 1)
	assert_eq(crafting.craft(inventory, 0, 1), Crafting.ERROR_UNKNOWN_RESULT)


func test_options_list_every_pair_that_has_a_recipe() -> void:
	var inventory := Inventory.new(4)
	inventory.add_stack(ItemStack.new(_bat, 1, 0.5))
	inventory.add_item(_nails, 3)
	inventory.add_item(_tape, 1)
	var options := _crafting.options(inventory)
	assert_eq(options.size(), 2, "bate + clavos y cinta + bate gastado")
	var results: Array[String] = []
	for option: Dictionary in options:
		var recipe: RecipeData = option["recipe"]
		results.append(recipe.id)
		assert_eq(option["problem"], Crafting.ERROR_NONE)
	assert_true(results.has("bat_nails"))


func test_options_report_no_space() -> void:
	var inventory := Inventory.new(2)
	inventory.add_stack(ItemStack.new(_bat))
	inventory.add_item(_nails, 3)
	var options := _crafting.options(inventory)
	assert_eq(options.size(), 1)
	assert_eq(options[0]["problem"], Crafting.ERROR_NONE, "el bate libera su casilla")


func test_hints_name_the_missing_half() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(_nails, 2)
	var hints := _crafting.hints(inventory)
	assert_eq(hints.size(), 1)
	assert_eq(hints[0]["have"], "nails")
	assert_eq(hints[0]["missing"], "bat")
	inventory.add_stack(ItemStack.new(_bat))
	assert_eq(_crafting.hints(inventory).size(), 0, "con las dos partes ya no es una pista")

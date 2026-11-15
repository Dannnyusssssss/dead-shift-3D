extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Combinar: recetas con cantidades (los materiales salen de la bolsa), gasto de lo usado,
## herencia del desgaste, reparación con cinta, recetas solo de materiales, falta de material o
## de sitio, opciones y pistas con lo que falta.

const Fixtures = preload("res://tests/helpers/fixtures.gd")

var _bat: ItemData
var _nails: ItemData
var _tape: ItemData
var _rag: ItemData
var _bat_nails: ItemData
var _patch: ItemData
var _bat_recipe: RecipeData
var _repair: RecipeData
var _patch_recipe: RecipeData
var _crafting: Crafting


func before_each() -> void:
	_bat = Fixtures.melee("bat", 60.0, 4.0)
	_nails = Fixtures.material("nails", 30)
	_tape = Fixtures.material("tape", 6)
	_rag = Fixtures.material("rag", 10)
	_bat_nails = Fixtures.melee("bat_nails", 45.0, 5.0)
	_patch = Fixtures.consumable("patch", ItemData.EFFECT_HEAL, 20.0)
	var catalog := ItemCatalog.new([_bat, _nails, _tape, _rag, _bat_nails, _patch])
	_bat_recipe = Fixtures.recipe_amounts("bat", "nails", "bat_nails", 1, 4)
	_repair = Fixtures.recipe("tape", "", "", 0.5)
	_patch_recipe = Fixtures.recipe_amounts("rag", "tape", "patch", 2, 1)
	var recipes: Array[RecipeData] = [_bat_recipe, _repair, _patch_recipe]
	_crafting = Crafting.new(recipes, catalog)


func test_materials_go_to_the_bag_not_to_slots() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(_nails, 6)
	assert_eq(inventory.used_slots(), 0)
	assert_eq(inventory.count_of("nails"), 6)


func test_weapon_recipe_spends_its_amounts() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(_nails, 6)
	inventory.add_stack(ItemStack.new(_bat))
	assert_eq(_crafting.slot_input(_bat_recipe), "bat")
	assert_eq(_crafting.craft(inventory, _bat_recipe, 0), Crafting.ERROR_NONE)
	assert_eq(inventory.count_of("bat"), 0)
	assert_eq(inventory.count_of("nails"), 2, "gasta 4 clavos")
	assert_eq(inventory.count_of("bat_nails"), 1)


func test_not_enough_material() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(_nails, 3)
	inventory.add_stack(ItemStack.new(_bat))
	assert_eq(_crafting.check(inventory, _bat_recipe, 0), Crafting.ERROR_MISSING)
	assert_eq(_crafting.craft(inventory, _bat_recipe, 0), Crafting.ERROR_MISSING)
	assert_eq(inventory.count_of("nails"), 3, "no gasta nada")
	assert_eq(inventory.count_of("bat"), 1)


func test_result_inherits_weapon_wear_fraction() -> void:
	var inventory := Inventory.new(4)
	inventory.add_stack(ItemStack.new(_bat, 1, 0.5))
	inventory.add_item(_nails, 4)
	_crafting.craft(inventory, _bat_recipe, 0)
	var result := inventory.get_slot(inventory.find_slot("bat_nails"))
	assert_almost_eq(result.durability.fraction(), 0.5, 0.0001)
	assert_eq(result.durability.max_value, 45.0, "usa la durabilidad propia del resultado")


func test_wrong_or_empty_slot() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(_nails, 4)
	inventory.add_stack(ItemStack.new(_bat_nails))
	assert_eq(_crafting.check(inventory, _bat_recipe, 3), Crafting.ERROR_EMPTY_SLOT)
	assert_eq(_crafting.check(inventory, _bat_recipe, -1), Crafting.ERROR_EMPTY_SLOT)
	assert_eq(_crafting.check(inventory, _bat_recipe, 0), Crafting.ERROR_NO_RECIPE, "otro objeto")
	assert_eq(_crafting.check(inventory, null, 0), Crafting.ERROR_NO_RECIPE)
	var foreign := Fixtures.recipe("bat", "nails", "bat_nails")
	assert_eq(_crafting.check(inventory, foreign, 0), Crafting.ERROR_NO_RECIPE, "receta ajena")


func test_material_only_recipe_needs_no_slot() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(_rag, 3)
	inventory.add_item(_tape, 1)
	assert_eq(_crafting.slot_input(_patch_recipe), "")
	assert_eq(_crafting.craft(inventory, _patch_recipe, -1), Crafting.ERROR_NONE)
	assert_eq(inventory.count_of("rag"), 1, "gasta 2 trapos")
	assert_eq(inventory.count_of("tape"), 0)
	assert_eq(inventory.count_of("patch"), 1)


func test_material_only_recipe_needs_space_for_the_result() -> void:
	var inventory := Inventory.new(1)
	inventory.add_stack(ItemStack.new(_bat))
	inventory.add_item(_rag, 2)
	inventory.add_item(_tape, 1)
	assert_eq(_crafting.check(inventory, _patch_recipe, -1), Crafting.ERROR_NO_SPACE)
	assert_eq(_crafting.craft(inventory, _patch_recipe, -1), Crafting.ERROR_NO_SPACE)
	assert_eq(inventory.count_of("rag"), 2, "no gasta nada si no hay sitio")


func test_tape_repairs_damaged_weapon_in_place() -> void:
	var inventory := Inventory.new(4)
	inventory.add_stack(ItemStack.new(_bat, 1, 0.2))
	inventory.add_item(_tape, 2)
	assert_eq(_crafting.craft(inventory, _repair, 0), Crafting.ERROR_NONE)
	assert_almost_eq(inventory.get_slot(0).durability.fraction(), 0.7, 0.0001)
	assert_eq(inventory.count_of("tape"), 1, "un uso de cinta")


func test_tape_does_not_repair_full_or_broken_weapon() -> void:
	var inventory := Inventory.new(4)
	inventory.add_stack(ItemStack.new(_bat))
	inventory.add_stack(ItemStack.new(_bat, 1, 0.0))
	inventory.add_item(_tape, 1)
	assert_eq(_crafting.check(inventory, _repair, 0), Crafting.ERROR_NO_RECIPE, "entera")
	assert_eq(_crafting.check(inventory, _repair, 1), Crafting.ERROR_NO_RECIPE, "rota")


func test_unknown_result_is_rejected() -> void:
	var broken := Fixtures.recipe_amounts("bat", "nails", "missing", 1, 1)
	var recipes: Array[RecipeData] = [broken]
	var crafting := Crafting.new(recipes, ItemCatalog.new([_bat, _nails]))
	var inventory := Inventory.new(4)
	inventory.add_stack(ItemStack.new(_bat))
	inventory.add_item(_nails, 1)
	assert_eq(crafting.craft(inventory, broken, 0), Crafting.ERROR_UNKNOWN_RESULT)


func test_options_list_what_can_be_made_now() -> void:
	var inventory := Inventory.new(4)
	inventory.add_stack(ItemStack.new(_bat, 1, 0.5))
	inventory.add_item(_nails, 4)
	inventory.add_item(_tape, 1)
	inventory.add_item(_rag, 1)
	var options := _crafting.options(inventory)
	var ids: Array[String] = []
	for option: Dictionary in options:
		var recipe: RecipeData = option["recipe"]
		ids.append(recipe.id)
		assert_eq(option["problem"], Crafting.ERROR_NONE)
	assert_eq(ids.size(), 2, "bate con clavos y reparar; la venda pide 2 trapos")
	assert_true(ids.has(_bat_recipe.id))
	assert_true(ids.has(_repair.id))


func test_options_report_no_space() -> void:
	var inventory := Inventory.new(1)
	inventory.add_stack(ItemStack.new(_bat))
	inventory.add_item(_rag, 2)
	inventory.add_item(_tape, 1)
	var options := _crafting.options(inventory)
	assert_eq(options.size(), 1)
	assert_eq(options[0]["problem"], Crafting.ERROR_NO_SPACE)


func test_hints_list_what_is_missing_with_amounts() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(_nails, 2)
	var hints := _crafting.hints(inventory)
	assert_eq(hints.size(), 1)
	assert_eq(hints[0]["have"], "nails")
	var missing: Array[Dictionary] = hints[0]["missing"]
	assert_eq(missing.size(), 2, "faltan el bate y 2 clavos")
	inventory.add_stack(ItemStack.new(_bat))
	inventory.add_item(_nails, 2)
	assert_eq(_crafting.hints(inventory).size(), 0, "con todo ya no es una pista")


func test_recipes_with_an_item() -> void:
	assert_eq(_crafting.recipes_with("tape").size(), 2, "reparar y venda")
	assert_eq(_crafting.recipes_with("bat").size(), 1)
	assert_eq(_crafting.recipes_with("nada").size(), 0)


func test_real_catalog_recipes_are_coherent() -> void:
	var catalog: GameCatalog = load("res://game/data/catalog.tres")
	var items := catalog.item_catalog()
	var crafting := Crafting.new(catalog.recipes, items)
	for recipe: RecipeData in catalog.recipes:
		assert_not_null(items.get_item(recipe.input_a), recipe.id)
		if recipe.is_repair():
			continue
		assert_not_null(items.get_item(recipe.input_b), recipe.id)
		assert_not_null(items.get_item(recipe.result_id), recipe.id)
		var wanted := crafting.materials(recipe)
		for item_id: String in wanted:
			var amount: int = wanted[item_id]
			assert_true(amount <= MaterialBag.cap_of(items.get_item(item_id)), "cabe en la bolsa")

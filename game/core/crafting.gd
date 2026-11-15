class_name Crafting
extends RefCounted
## Combinación de dos objetos según recetas. Las recetas son datos; el orden de los
## objetos no importa. El tiempo y el ruido de combinar los aplica la capa de juego.

const ERROR_NONE: String = ""
const ERROR_EMPTY_SLOT: String = "empty_slot"
const ERROR_SAME_SLOT: String = "same_slot"
const ERROR_NO_RECIPE: String = "no_recipe"
const ERROR_UNKNOWN_RESULT: String = "unknown_result"
const ERROR_NO_SPACE: String = "no_space"

var _recipes: Array[RecipeData] = []
var _catalog: ItemCatalog = null


func _init(recipes: Array[RecipeData], catalog: ItemCatalog) -> void:
	_recipes = recipes
	_catalog = catalog


## Busca la receta que combina dos casillas, o null si no hay ninguna.
func find_recipe(first: ItemStack, second: ItemStack) -> RecipeData:
	if first == null or second == null:
		return null
	for recipe: RecipeData in _recipes:
		if recipe.is_repair():
			if _matches_repair(recipe, first, second) or _matches_repair(recipe, second, first):
				return recipe
		elif _matches(recipe, first.id(), second.id()):
			return recipe
	return null


## Comprueba si dos casillas del inventario se pueden combinar. Devuelve un código de error
## o ERROR_NONE.
func check(inventory: Inventory, slot_a: int, slot_b: int) -> String:
	if slot_a == slot_b:
		return ERROR_SAME_SLOT
	var first := inventory.get_slot(slot_a)
	var second := inventory.get_slot(slot_b)
	if first == null or second == null:
		return ERROR_EMPTY_SLOT
	var recipe := find_recipe(first, second)
	if recipe == null:
		return ERROR_NO_RECIPE
	return _check_result(inventory, recipe, first, second)


## Combina dos casillas. Gasta lo usado y deja el resultado en el inventario.
## Un arma combinada hereda la fracción de desgaste del arma usada, con la durabilidad
## propia del resultado. Una reparación gasta el material y repara el arma en su sitio.
## Devuelve un código de error o ERROR_NONE.
func craft(inventory: Inventory, slot_a: int, slot_b: int) -> String:
	var problem := check(inventory, slot_a, slot_b)
	if problem != ERROR_NONE:
		return problem
	var first := inventory.get_slot(slot_a)
	var second := inventory.get_slot(slot_b)
	var recipe := find_recipe(first, second)
	if recipe.is_repair():
		var weapon_is_first := first.is_repairable() and first.id() != recipe.input_a
		var weapon_stack := first if weapon_is_first else second
		var material_slot := slot_b if weapon_is_first else slot_a
		weapon_stack.durability.repair(recipe.repair_fraction)
		inventory.consume_one(material_slot)
		return ERROR_NONE
	var inherited := 1.0
	if first.is_weapon():
		inherited = first.durability.fraction()
	elif second.is_weapon():
		inherited = second.durability.fraction()
	var result_data := _catalog.get_item(recipe.result_id)
	# Se gastan primero las entradas para liberar casilla para el resultado.
	var high := maxi(slot_a, slot_b)
	var low := mini(slot_a, slot_b)
	inventory.consume_one(high)
	inventory.consume_one(low)
	# check() ya garantizó que hay casilla para el resultado.
	inventory.add_stack(ItemStack.new(result_data, 1, inherited))
	return ERROR_NONE


## Combinaciones posibles ahora con lo que hay en el inventario: una entrada por par de casillas
## que tiene receta, con "recipe", "slot_a", "slot_b" y "problem" (ERROR_NONE si se puede ya).
func options(inventory: Inventory) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for a: int in inventory.capacity():
		var first := inventory.get_slot(a)
		if first == null:
			continue
		for b: int in range(a + 1, inventory.capacity()):
			var second := inventory.get_slot(b)
			var recipe := find_recipe(first, second)
			if recipe == null:
				continue
			var problem := _check_result(inventory, recipe, first, second)
			result.append({"recipe": recipe, "slot_a": a, "slot_b": b, "problem": problem})
	return result


## Recetas (no de reparación) de las que se lleva una parte: "recipe", "have" y "missing".
func hints(inventory: Inventory) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe: RecipeData in _recipes:
		if recipe.is_repair():
			continue
		var has_a := inventory.count_of(recipe.input_a) > 0
		var has_b := inventory.count_of(recipe.input_b) > 0
		if has_a != has_b:
			var have := recipe.input_a if has_a else recipe.input_b
			var missing := recipe.input_b if has_a else recipe.input_a
			result.append({"recipe": recipe, "have": have, "missing": missing})
	return result


func _check_result(
	inventory: Inventory, recipe: RecipeData, first: ItemStack, second: ItemStack
) -> String:
	if recipe.is_repair():
		return ERROR_NONE
	if _catalog.get_item(recipe.result_id) == null:
		return ERROR_UNKNOWN_RESULT
	# El resultado necesita una casilla: queda libre si alguna entrada es la última unidad.
	if first.count > 1 and second.count > 1 and inventory.is_full():
		return ERROR_NO_SPACE
	return ERROR_NONE


func _matches(recipe: RecipeData, a: String, b: String) -> bool:
	return (
		(recipe.input_a == a and recipe.input_b == b)
		or (recipe.input_a == b and recipe.input_b == a)
	)


func _matches_repair(recipe: RecipeData, material: ItemStack, weapon: ItemStack) -> bool:
	return material.id() == recipe.input_a and weapon.is_repairable()

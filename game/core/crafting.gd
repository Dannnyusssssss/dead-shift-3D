class_name Crafting
extends RefCounted
## Combinación según recetas. Las recetas son datos con dos entradas y cuántas unidades gasta
## cada una; los materiales salen de la bolsa y como mucho una entrada es un objeto de casilla
## (el bate, el tubo; en las reparaciones, el arma dañada). El tiempo y el ruido de combinar los
## aplica la capa de juego.

const ERROR_NONE: String = ""
const ERROR_EMPTY_SLOT: String = "empty_slot"
const ERROR_NO_RECIPE: String = "no_recipe"
const ERROR_UNKNOWN_RESULT: String = "unknown_result"
const ERROR_NO_SPACE: String = "no_space"
const ERROR_MISSING: String = "missing"

var _recipes: Array[RecipeData] = []
var _catalog: ItemCatalog = null


func _init(recipes: Array[RecipeData], catalog: ItemCatalog) -> void:
	_recipes = recipes
	_catalog = catalog


## Entrada de la receta que va en una casilla ("" si las dos son materiales). En una reparación
## es el arma (cualquiera que se pueda reparar), que no tiene identificador fijo.
func slot_input(recipe: RecipeData) -> String:
	if recipe.is_repair():
		return ""
	if not _is_material(recipe.input_a):
		return recipe.input_a
	if not _is_material(recipe.input_b):
		return recipe.input_b
	return ""


## Materiales que gasta la receta: {id: unidades}.
func materials(recipe: RecipeData) -> Dictionary:
	var result: Dictionary = {}
	if _is_material(recipe.input_a):
		result[recipe.input_a] = maxi(recipe.amount_a, 1)
	if not recipe.is_repair() and _is_material(recipe.input_b):
		var previous: int = result.get(recipe.input_b, 0)
		result[recipe.input_b] = previous + maxi(recipe.amount_b, 1)
	return result


## Comprueba si se puede hacer la receta ahora con la casilla dada (-1 si no usa casilla).
## Devuelve un código de error o ERROR_NONE.
func check(inventory: Inventory, recipe: RecipeData, slot: int) -> String:
	if recipe == null or not _recipes.has(recipe):
		return ERROR_NO_RECIPE
	var slot_problem := _check_slot(inventory, recipe, slot)
	if slot_problem != ERROR_NONE:
		return slot_problem
	var wanted := materials(recipe)
	for item_id: String in wanted:
		var amount: int = wanted[item_id]
		if inventory.bag.count(item_id) < amount:
			return ERROR_MISSING
	return _check_result(inventory, recipe)


## Hace la receta: gasta los materiales y la casilla usada y deja el resultado (un arma
## combinada hereda la fracción de desgaste del arma usada). Una reparación gasta el material y
## repara el arma en su sitio. Devuelve un código de error o ERROR_NONE.
func craft(inventory: Inventory, recipe: RecipeData, slot: int) -> String:
	var problem := check(inventory, recipe, slot)
	if problem != ERROR_NONE:
		return problem
	var wanted := materials(recipe)
	for item_id: String in wanted:
		var amount: int = wanted[item_id]
		inventory.bag.remove(item_id, amount)
	if recipe.is_repair():
		inventory.get_slot(slot).durability.repair(recipe.repair_fraction)
		return ERROR_NONE
	var inherited := 1.0
	if not slot_input(recipe).is_empty():
		var used := inventory.take_slot(slot)
		if used.is_weapon():
			inherited = used.durability.fraction()
	var result_data := _catalog.get_item(recipe.result_id)
	var result_count := maxi(recipe.result_count, 1)
	if MaterialBag.is_material(result_data) or result_data.max_stack > 1:
		inventory.add_item(result_data, result_count)
	else:
		# check() ya garantizó que hay casilla para el resultado.
		inventory.add_stack(ItemStack.new(result_data, 1, inherited))
	return ERROR_NONE


## Combinaciones que se pueden hacer con lo que se lleva: una entrada por receta (y por casilla
## que sirva) con "recipe", "slot" (-1 si no usa casilla) y "problem" (ERROR_NONE si se puede ya;
## ERROR_NO_SPACE si falta sitio para el resultado). Las que no tienen todo, en hints().
func options(inventory: Inventory) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe: RecipeData in _recipes:
		for slot: int in _candidate_slots(inventory, recipe):
			var problem := check(inventory, recipe, slot)
			if problem == ERROR_NONE or problem == ERROR_NO_SPACE:
				result.append({"recipe": recipe, "slot": slot, "problem": problem})
	return result


## Recetas (no de reparación) de las que se lleva algo pero no todo: "recipe", "have" (un
## objeto que sí se lleva) y "missing" (lista de {"id", "have", "need"} de lo que falta).
func hints(inventory: Inventory) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe: RecipeData in _recipes:
		if recipe.is_repair():
			continue
		var needs: Dictionary = materials(recipe)
		var holder := slot_input(recipe)
		if not holder.is_empty():
			needs[holder] = 1
		var have := ""
		var missing: Array[Dictionary] = []
		for item_id: String in needs:
			var need: int = needs[item_id]
			var owned := inventory.count_of(item_id)
			if owned > 0 and have.is_empty():
				have = item_id
			if owned < need:
				missing.append({"id": item_id, "have": owned, "need": need})
		if not have.is_empty() and not missing.is_empty():
			result.append({"recipe": recipe, "have": have, "missing": missing})
	return result


## Recetas en las que interviene un objeto (para «Se combina con…»).
func recipes_with(item_id: String) -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	for recipe: RecipeData in _recipes:
		if recipe.input_a == item_id or (not recipe.is_repair() and recipe.input_b == item_id):
			result.append(recipe)
	return result


## Casillas que pueden servir para la receta: las del objeto que pide, las armas reparables
## (reparación) o solo -1 si no usa casilla.
func _candidate_slots(inventory: Inventory, recipe: RecipeData) -> Array[int]:
	var result: Array[int] = []
	var needed := slot_input(recipe)
	if not recipe.is_repair() and needed.is_empty():
		result.append(-1)
		return result
	for index: int in inventory.capacity():
		var stack := inventory.get_slot(index)
		if stack == null:
			continue
		if recipe.is_repair() and stack.is_repairable():
			result.append(index)
		elif not recipe.is_repair() and stack.id() == needed:
			result.append(index)
	return result


## La casilla sirve para la receta: un arma reparable (reparación), el objeto que pide o
## ninguna si la receta solo usa materiales.
func _check_slot(inventory: Inventory, recipe: RecipeData, slot: int) -> String:
	var stack := inventory.get_slot(slot)
	var needed := slot_input(recipe)
	if not recipe.is_repair() and needed.is_empty():
		return ERROR_NONE
	if stack == null:
		return ERROR_EMPTY_SLOT
	if recipe.is_repair():
		return ERROR_NONE if stack.is_repairable() else ERROR_NO_RECIPE
	return ERROR_NONE if stack.id() == needed else ERROR_NO_RECIPE


func _check_result(inventory: Inventory, recipe: RecipeData) -> String:
	if recipe.is_repair():
		return ERROR_NONE
	var result_data := _catalog.get_item(recipe.result_id)
	if result_data == null:
		return ERROR_UNKNOWN_RESULT
	var result_count := maxi(recipe.result_count, 1)
	if MaterialBag.is_material(result_data) or result_data.max_stack > 1:
		return ERROR_NONE if inventory.can_fit(result_data, result_count) else ERROR_NO_SPACE
	# Si la receta gasta un objeto de casilla, su sitio queda libre para el resultado.
	if not slot_input(recipe).is_empty() or not inventory.is_full():
		return ERROR_NONE
	return ERROR_NO_SPACE


func _is_material(item_id: String) -> bool:
	return MaterialBag.is_material(_catalog.get_item(item_id))

class_name Discovery
extends RefCounted
## Lo que el jugador ya descubrió, guardado como marcas del mundo: si leyó la nota del técnico y
## qué materiales de combinación llegó a tener. El cuaderno solo muestra lo descubierto. Lógica
## pura.

## Marca de la nota del técnico leída.
const NOTE_FLAG: String = "tech_note_read"
## Prefijo de la marca de un objeto visto («seen_rag»).
const SEEN_PREFIX: String = "seen_"


static func seen_flag(item_id: String) -> String:
	return SEEN_PREFIX + item_id


## Marca como vistos los objetos del inventario (casillas y bolsa) que sirven para alguna receta.
## Devuelve cuántas marcas nuevas puso.
static func mark_seen(world: WorldState, inventory: Inventory, recipes: Array[RecipeData]) -> int:
	var added := 0
	for item_id: String in recipe_inputs(recipes):
		if world.has_flag(seen_flag(item_id)):
			continue
		if inventory.count_of(item_id) > 0:
			world.set_flag(seen_flag(item_id))
			added += 1
	return added


## Identificadores (sin repetir) de todo lo que entra en alguna receta.
static func recipe_inputs(recipes: Array[RecipeData]) -> Array[String]:
	var result: Array[String] = []
	for recipe: RecipeData in recipes:
		for item_id: String in [recipe.input_a, recipe.input_b]:
			if not item_id.is_empty() and not result.has(item_id):
				result.append(item_id)
	return result


## Una receta se conoce cuando el jugador ya tuvo alguno de sus ingredientes.
static func knows_recipe(world: WorldState, recipe: RecipeData) -> bool:
	for item_id: String in [recipe.input_a, recipe.input_b]:
		if not item_id.is_empty() and world.has_flag(seen_flag(item_id)):
			return true
	return false


## Sabe que tiene que armar un teléfono: leyó la nota, ya encontró alguna pieza o ya lo armó.
static func knows_phone(world: WorldState, keys: KeyItems) -> bool:
	return world.has_flag(NOTE_FLAG) or keys.phone_parts_count() > 0 or keys.phone_assembled


## Sabe dónde buscar las piezas: lo dice la nota del técnico y lo marca el plano.
static func knows_part_zones(world: WorldState, keys: KeyItems) -> bool:
	return world.has_flag(NOTE_FLAG) or keys.has(MapMarkers.MAP_ITEM)

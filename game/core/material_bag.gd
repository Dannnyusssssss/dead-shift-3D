class_name MaterialBag
extends RefCounted
## Bolsa de materiales (clavos, trapos, cinta, botellas): no ocupa casillas de la mochila. Cada
## material tiene un tope de unidades (su max_stack); lo que no cabe se queda donde estaba.

## Unidades por identificador de material (solo los que hay, siempre más de 0).
var _counts: Dictionary = {}
## Datos de cada material que pasó por la bolsa (para conocer su tope).
var _items: Dictionary = {}


static func is_material(data: ItemData) -> bool:
	return data != null and data.category == ItemData.CATEGORY_MATERIAL


## Tope de unidades de un material.
static func cap_of(data: ItemData) -> int:
	return maxi(data.max_stack, 1)


func count(item_id: String) -> int:
	var amount: int = _counts.get(item_id, 0)
	return amount


## Unidades que todavía caben de un material.
func space_for(data: ItemData) -> int:
	return maxi(cap_of(data) - count(data.id), 0)


## Añade unidades. Devuelve cuántas no cupieron (o todas, si no es un material).
func add(data: ItemData, amount: int) -> int:
	var wanted := maxi(amount, 0)
	if not is_material(data) or wanted == 0:
		return wanted
	var moved := mini(space_for(data), wanted)
	if moved > 0:
		_counts[data.id] = count(data.id) + moved
		_items[data.id] = data
	return wanted - moved


## Quita unidades. Devuelve cuántas quitó.
func remove(item_id: String, amount: int) -> int:
	var taken := mini(count(item_id), maxi(amount, 0))
	if taken <= 0:
		return 0
	var left := count(item_id) - taken
	if left > 0:
		_counts[item_id] = left
	else:
		_counts.erase(item_id)
	return taken


## Datos del material (null si nunca estuvo en la bolsa).
func item(item_id: String) -> ItemData:
	var data: Variant = _items.get(item_id)
	return data if data is ItemData else null


## Materiales que hay, en el orden del catálogo dado.
func ids(catalog: ItemCatalog) -> Array[String]:
	var result: Array[String] = []
	for item_id: String in catalog.ids():
		if count(item_id) > 0:
			result.append(item_id)
	return result


func is_empty() -> bool:
	return _counts.is_empty()


## Para el guardado: {id: unidades}.
func to_data() -> Dictionary:
	return _counts.duplicate()


## Restaura desde datos ya validados; lo desconocido o que no es material se descarta.
func load_data(data: Dictionary, catalog: ItemCatalog) -> void:
	_counts.clear()
	_items.clear()
	for key: Variant in data:
		if not key is String:
			continue
		var item_id: String = key
		var amount: Variant = data[item_id]
		if amount is int or amount is float:
			var units: float = amount
			add(catalog.get_item(item_id), int(units))

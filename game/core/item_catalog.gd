class_name ItemCatalog
extends RefCounted
## Registro de objetos por identificador. Se arma con los .tres del catálogo del juego.

var _items: Dictionary = {}


func _init(items: Array[ItemData] = []) -> void:
	for data: ItemData in items:
		add(data)


func add(data: ItemData) -> void:
	_items[data.id] = data


func has(item_id: String) -> bool:
	return _items.has(item_id)


## Devuelve el objeto o null si no existe.
func get_item(item_id: String) -> ItemData:
	var found: Variant = _items.get(item_id)
	if found is ItemData:
		return found
	return null


func ids() -> PackedStringArray:
	var result := PackedStringArray()
	for key: String in _items:
		result.append(key)
	return result

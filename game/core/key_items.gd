class_name KeyItems
extends RefCounted
## Objetos clave del jugador (llaves, plano y piezas del teléfono): no ocupan casilla, no se
## repiten, no se sueltan ni se lanzan. También guarda si el teléfono ya está armado.

var items: PackedStringArray = PackedStringArray()
## Verdadero cuando ya armó el teléfono con todas las piezas.
var phone_assembled: bool = false


## Guarda un objeto clave. Devuelve falso si ya lo tenía.
func add(item_id: String) -> bool:
	if item_id.is_empty() or items.has(item_id):
		return false
	items.append(item_id)
	return true


func has(item_id: String) -> bool:
	return items.has(item_id)


func phone_parts_count() -> int:
	var count := 0
	for part: String in Rules.PHONE_PARTS:
		if items.has(part):
			count += 1
	return count


func can_assemble_phone() -> bool:
	return not phone_assembled and phone_parts_count() == Rules.PHONE_PARTS.size()


## Arma el teléfono si tiene todas las piezas. Devuelve verdadero si lo armó.
func assemble_phone() -> bool:
	if not can_assemble_phone():
		return false
	phone_assembled = true
	return true

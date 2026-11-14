class_name Inventory
extends RefCounted
## Inventario limitado por casillas. Los objetos apilables se juntan hasta su máximo;
## armas y chalecos ocupan una casilla cada uno con su propia durabilidad.

var _slots: Array[ItemStack] = []


func _init(capacity: int = Rules.INVENTORY_SLOTS) -> void:
	_slots.resize(maxi(capacity, 1))


func capacity() -> int:
	return _slots.size()


## Casilla en la posición dada, o null si está vacía o fuera de rango.
func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


func used_slots() -> int:
	var used := 0
	for stack: ItemStack in _slots:
		if stack != null:
			used += 1
	return used


func is_full() -> bool:
	return used_slots() >= _slots.size()


func count_of(item_id: String) -> int:
	var total := 0
	for stack: ItemStack in _slots:
		if stack != null and stack.id() == item_id:
			total += stack.count
	return total


## Primera casilla que contiene el objeto, o -1.
func find_slot(item_id: String) -> int:
	for index: int in _slots.size():
		var stack: ItemStack = _slots[index]
		if stack != null and stack.id() == item_id:
			return index
	return -1


## Añade unidades de un objeto nuevo. Devuelve cuántas no cupieron.
func add_item(data: ItemData, amount: int) -> int:
	var left := maxi(amount, 0)
	if data.max_stack > 1:
		for stack: ItemStack in _slots:
			if left == 0:
				break
			if stack != null and stack.id() == data.id and stack.space_left() > 0:
				var moved := mini(stack.space_left(), left)
				stack.count += moved
				left -= moved
	while left > 0:
		var free := _free_slot()
		if free < 0:
			break
		var moved := mini(maxi(data.max_stack, 1), left)
		_slots[free] = ItemStack.new(data, moved)
		left -= moved
	return left


## Añade una casilla ya creada (arma con desgaste, chaleco). Devuelve falso si no cabe.
func add_stack(stack: ItemStack) -> bool:
	if stack.item.max_stack > 1:
		var leftover := add_item(stack.item, stack.count)
		stack.count = leftover
		return leftover == 0
	var free := _free_slot()
	if free < 0:
		return false
	_slots[free] = stack
	return true


## Quita unidades de un objeto, empezando por las primeras casillas. Devuelve cuántas quitó.
func remove_count(item_id: String, amount: int) -> int:
	var left := maxi(amount, 0)
	for index: int in _slots.size():
		if left == 0:
			break
		var stack: ItemStack = _slots[index]
		if stack == null or stack.id() != item_id:
			continue
		var taken := mini(stack.count, left)
		stack.count -= taken
		left -= taken
		if stack.count == 0:
			_slots[index] = null
	return amount - left


## Quita una unidad de la casilla dada. Devuelve falso si estaba vacía.
func consume_one(index: int) -> bool:
	var stack := get_slot(index)
	if stack == null:
		return false
	stack.count -= 1
	if stack.count <= 0:
		_slots[index] = null
	return true


## Saca la casilla entera (para soltarla o cambiarla). Devuelve null si estaba vacía.
func take_slot(index: int) -> ItemStack:
	var stack := get_slot(index)
	if stack != null:
		_slots[index] = null
	return stack


## Pone una casilla en una posición vacía concreta. Devuelve falso si está ocupada.
func put_slot(index: int, stack: ItemStack) -> bool:
	if index < 0 or index >= _slots.size() or _slots[index] != null:
		return false
	_slots[index] = stack
	return true


## Elimina las armas rotas y devuelve cuántas quitó.
func remove_broken() -> int:
	var removed := 0
	for index: int in _slots.size():
		var stack: ItemStack = _slots[index]
		if stack != null and stack.durability.is_broken():
			_slots[index] = null
			removed += 1
	return removed


## Representación para el guardado: lista de casillas ocupadas.
func to_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in _slots.size():
		var stack: ItemStack = _slots[index]
		if stack == null:
			continue
		(
			result
			. append(
				{
					"slot": index,
					"id": stack.id(),
					"count": stack.count,
					"durability": stack.durability.fraction(),
					"ammo": stack.ammo_loaded,
				}
			)
		)
	return result


## Reconstruye el inventario desde datos ya validados por boundary/validation.gd.
## Lo que no encaje (objeto desconocido, casilla ocupada o fuera de rango) se descarta.
func load_data(entries: Array[Dictionary], catalog: ItemCatalog) -> void:
	_slots.fill(null)
	for entry: Dictionary in entries:
		var item_id: String = entry.get("id", "")
		var data := catalog.get_item(item_id)
		if data == null:
			continue
		var count: int = entry.get("count", 1)
		var fraction_left: float = entry.get("durability", 1.0)
		var stack := ItemStack.new(data, count, fraction_left)
		if data.weapon != null:
			var ammo: int = entry.get("ammo", 0)
			stack.ammo_loaded = clampi(ammo, 0, data.weapon.magazine_size)
		var slot: int = entry.get("slot", -1)
		if not put_slot(slot, stack):
			add_stack(stack)


func _free_slot() -> int:
	for index: int in _slots.size():
		if _slots[index] == null:
			return index
	return -1

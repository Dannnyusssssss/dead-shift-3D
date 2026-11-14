class_name PlayerState
extends RefCounted
## Estado del jugador en la partida: salud, inventario, arma equipada, chaleco y estadísticas.
## Lógica pura: la escena del jugador y la interfaz lo leen y le piden cambios.

## Equipo inicial: la pistola con el cargador lleno y poca munición de reserva.
const STARTING_WEAPON: String = "pistol"
const STARTING_RESERVE_AMMO: int = 4

var health: float = Rules.PLAYER_MAX_HEALTH
var inventory: Inventory = null
var vest: ItemStack = null
var equipped_slot: int = -1
var weapons_broken: int = 0
var items_crafted: int = 0
var damage_taken: float = 0.0

var _items: ItemCatalog = null


func _init(items: ItemCatalog, capacity: int = Rules.INVENTORY_SLOTS) -> void:
	_items = items
	inventory = Inventory.new(capacity)


func give_starting_kit() -> void:
	var pistol_data := _items.get_item(STARTING_WEAPON)
	if pistol_data == null or pistol_data.weapon == null:
		return
	var pistol := ItemStack.new(pistol_data)
	pistol.ammo_loaded = pistol_data.weapon.magazine_size
	inventory.add_stack(pistol)
	var ammo := _items.get_item(pistol_data.weapon.ammo_item_id)
	if ammo != null:
		inventory.add_item(ammo, STARTING_RESERVE_AMMO)
	equipped_slot = inventory.find_slot(STARTING_WEAPON)


func is_dead() -> bool:
	return health <= 0.0


## Arma equipada, o null si no hay (o si la casilla ya no tiene un arma).
func equipped() -> ItemStack:
	var stack := inventory.get_slot(equipped_slot)
	if stack == null or not stack.is_weapon():
		return null
	return stack


## Recibe daño pasando por el chaleco. Devuelve la salud perdida.
func take_damage(amount: float) -> float:
	if is_dead():
		return 0.0
	var lost := minf(DamageModel.player_damage(amount, vest), health)
	health -= lost
	damage_taken += lost
	return lost


## Equipa la casilla dada si contiene un arma. Devuelve falso si no.
func select_slot(index: int) -> bool:
	var stack := inventory.get_slot(index)
	if stack == null or not stack.is_weapon() or stack.durability.is_broken():
		return false
	equipped_slot = index
	return true


## Pasa a la siguiente (o anterior) arma del inventario. Devuelve falso si no hay otra.
func cycle_weapon(direction: int) -> bool:
	var size := inventory.capacity()
	var step := 1 if direction >= 0 else -1
	var index := equipped_slot
	for _attempt: int in size:
		index = posmod(index + step, size)
		if index != equipped_slot and select_slot(index):
			return true
	return false


## Retira las armas rotas, cuenta cuántas y equipa otra si la equipada se rompió.
func handle_broken_weapons() -> int:
	var current := inventory.get_slot(equipped_slot)
	var equipped_broke := current != null and current.durability.is_broken()
	var removed := inventory.remove_broken()
	weapons_broken += removed
	if equipped_broke or equipped() == null:
		equipped_slot = -1
		cycle_weapon(1)
	return removed


## Se pone el chaleco dado y devuelve el que llevaba (o null) para dejarlo en el suelo.
func swap_vest(new_vest: ItemStack) -> ItemStack:
	if new_vest != null and not new_vest.is_vest():
		return new_vest
	var old := vest
	vest = new_vest
	return old

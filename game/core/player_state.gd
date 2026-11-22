class_name PlayerState
extends RefCounted
## Estado del jugador en la partida: salud, inventario, arma equipada, chaleco y estadísticas.
## Lógica pura: la escena del jugador y la interfaz lo leen y le piden cambios.

## Equipo inicial: la pistola con el cargador lleno y poca munición de reserva.
const STARTING_WEAPON: String = "pistol"
const STARTING_RESERVE_AMMO: int = 4
## Arma de reserva que el guardia lleva siempre (no se rompe ni se suelta).
const BOUND_WEAPON: String = "baton"
## Causa de la muerte.
const CAUSE_NONE: int = 0
const CAUSE_DAMAGE: int = 1
const CAUSE_INFECTION: int = 2
## Resultado de usar un consumible ("" = se puede).
const USE_OK: String = ""
const USE_NOT_USABLE: String = "not_usable"
const USE_FULL_HEALTH: String = "full_health"
const USE_NOT_INFECTED: String = "not_infected"
const USE_COUNTDOWN_FULL: String = "countdown_full"

var health: float = Rules.PLAYER_MAX_HEALTH
var inventory: Inventory = null
var vest: ItemStack = null
var equipped_slot: int = -1
## Material elegido para la tecla rápida de lanzar ("" = el de siempre: el primero de la bolsa).
var quick_throw_choice: String = ""
var weapons_broken: int = 0
var items_crafted: int = 0
var damage_taken: float = 0.0
var kills: int = 0
var infection: Infection = Infection.new()
var death_cause: int = CAUSE_NONE
## Objetos clave (llaves, plano, piezas del teléfono) y estado del teléfono.
var keys: KeyItems = KeyItems.new()
## Linterna con su carga.
var flashlight: Flashlight = Flashlight.new()

var _items: ItemCatalog = null


func _init(items: ItemCatalog, slots: int = Rules.INVENTORY_SLOTS) -> void:
	_items = items
	inventory = Inventory.new(slots)


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
	ensure_bound_items()
	equipped_slot = inventory.find_slot(STARTING_WEAPON)


## Pone la porra en su posición fija, que no ocupa casilla (partidas nuevas y guardadas antes
## de que existiera). Si estaba en una casilla normal, la pasa a la fija y libera la casilla; si
## estaba equipada, sigue equipada. Devuelve falso si no se pudo.
func ensure_bound_items() -> bool:
	var fixed := inventory.fixed_slot()
	var current := inventory.get_slot(fixed)
	if current != null and current.id() == BOUND_WEAPON:
		return true
	var index := inventory.find_slot(BOUND_WEAPON)
	if index >= 0:
		var moved := inventory.take_slot(index)
		if not inventory.put_fixed(moved):
			inventory.put_slot(index, moved)
			return false
		if equipped_slot == index:
			equipped_slot = fixed
		return true
	var data := _items.get_item(BOUND_WEAPON)
	if data == null:
		return false
	return inventory.put_fixed(ItemStack.new(data))


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
	if is_dead():
		death_cause = CAUSE_DAMAGE
	return lost


## Daño que no pasa por el chaleco (gas tóxico). Devuelve la salud perdida.
func take_raw_damage(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var lost := minf(amount, health)
	health -= lost
	damage_taken += lost
	if is_dead():
		death_cause = CAUSE_DAMAGE
	return lost


## Recibe un golpe de un enemigo que puede infectar. Devuelve la salud perdida.
## Si el golpe hace daño y el jugador sigue vivo, suma su exposición (al llenarse, contagia).
func take_bite(amount: float, exposure: float) -> float:
	var lost := take_damage(amount)
	if lost > 0.0 and not is_dead():
		infection.add_exposure(exposure)
	return lost


## Avanza la infección. Devuelve verdadero si el jugador acaba de convertirse.
func tick_infection(delta: float) -> bool:
	if is_dead():
		return false
	if infection.tick(delta):
		health = 0.0
		death_cause = CAUSE_INFECTION
		return true
	return false


## Comprueba si la casilla se puede usar ahora (curar, frenar o curar la infección).
func check_use(index: int) -> String:
	var stack := inventory.get_slot(index)
	if stack == null or stack.item.category != ItemData.CATEGORY_CONSUMABLE:
		return USE_NOT_USABLE
	match stack.item.use_effect:
		ItemData.EFFECT_HEAL:
			return USE_FULL_HEALTH if health >= Rules.PLAYER_MAX_HEALTH else USE_OK
		ItemData.EFFECT_DELAY_INFECTION:
			if not infection.infected:
				return USE_NOT_INFECTED
			return USE_OK if infection.can_add_time() else USE_COUNTDOWN_FULL
		ItemData.EFFECT_CURE_INFECTION:
			return USE_OK if infection.infected else USE_NOT_INFECTED
	return USE_NOT_USABLE


## Usa una unidad de la casilla y aplica su efecto. Devuelve USE_OK o el motivo del rechazo.
func use_item(index: int) -> String:
	var problem := check_use(index)
	if problem != USE_OK:
		return problem
	var item := inventory.get_slot(index).item
	match item.use_effect:
		ItemData.EFFECT_HEAL:
			health = minf(health + item.heal_amount, Rules.PLAYER_MAX_HEALTH)
		ItemData.EFFECT_DELAY_INFECTION:
			infection.add_time(Rules.ANTIBIOTIC_BONUS)
		ItemData.EFFECT_CURE_INFECTION:
			infection.cure()
	inventory.consume_one(index)
	return USE_OK


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


## Balas y cartuchos que le quedan (en la mochila y cargados en las armas).
func ammo_left() -> int:
	var total := 0
	for index: int in inventory.capacity():
		var stack := inventory.get_slot(index)
		if stack == null:
			continue
		if stack.item.category == ItemData.CATEGORY_AMMO:
			total += stack.count
		elif stack.is_weapon():
			total += stack.ammo_loaded
	return total


## Material que se lanza con la acción rápida: el primero de la bolsa en el orden del catálogo
## (los señuelos solo si no hay otro), o "".
func quick_throw_item() -> String:
	if not quick_throw_choice.is_empty() and inventory.bag.count(quick_throw_choice) > 0:
		return quick_throw_choice
	var lure := ""
	for item_id: String in inventory.bag.ids(_items):
		var data := _items.get_item(item_id)
		if data.lure_time <= 0.0:
			return item_id
		if lure.is_empty():
			lure = item_id
	return lure


## Pasa la tecla rápida de lanzar al siguiente material de la bolsa (en el orden del catálogo,
## dando la vuelta). Devuelve el elegido ("" si la bolsa está vacía).
func cycle_quick_throw() -> String:
	var options := inventory.bag.ids(_items)
	if options.is_empty():
		quick_throw_choice = ""
		return ""
	var current := options.find(quick_throw_item())
	quick_throw_choice = options[(current + 1) % options.size()]
	return quick_throw_choice


## Saca una unidad de un material de la bolsa (para lanzarla). Devuelve null si no hay.
func take_material(item_id: String) -> ItemStack:
	var data := _items.get_item(item_id)
	if data == null or inventory.bag.remove(item_id, 1) != 1:
		return null
	return ItemStack.new(data, 1)


## Saca una unidad de la casilla dada (para lanzarla). Devuelve null si está vacía.
## Si era el arma equipada, equipa otra.
func take_one(index: int) -> ItemStack:
	var stack := inventory.get_slot(index)
	if stack == null:
		return null
	var one: ItemStack = null
	if stack.count > 1:
		one = ItemStack.new(stack.item, 1, stack.durability.fraction())
		inventory.consume_one(index)
	else:
		one = inventory.take_slot(index)
	if index == equipped_slot and equipped() == null:
		equipped_slot = -1
		cycle_weapon(1)
	return one


## Se pone el chaleco dado y devuelve el que llevaba (o null) para dejarlo en el suelo.
func swap_vest(new_vest: ItemStack) -> ItemStack:
	if new_vest != null and not new_vest.is_vest():
		return new_vest
	var old := vest
	vest = new_vest
	return old

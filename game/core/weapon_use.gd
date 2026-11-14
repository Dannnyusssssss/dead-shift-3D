class_name WeaponUse
extends RefCounted
## Reglas de uso de armas: disparar, recargar y desgastar armas cuerpo a cuerpo.

const HIT_NONE: int = 0
const HIT_OK: int = 1
const HIT_BROKE: int = 2


## Verdadero si el arma de fuego tiene al menos una bala cargada.
static func can_fire(stack: ItemStack) -> bool:
	return (
		stack.is_weapon()
		and stack.item.weapon.kind == WeaponData.KIND_RANGED
		and stack.ammo_loaded > 0
	)


## Gasta una bala. Devuelve falso si no había.
static func fire(stack: ItemStack) -> bool:
	if not can_fire(stack):
		return false
	stack.ammo_loaded -= 1
	return true


## Verdadero si el arma de fuego no está llena y hay munición en el inventario.
static func can_reload(stack: ItemStack, inventory: Inventory) -> bool:
	if not stack.is_weapon() or stack.item.weapon.kind != WeaponData.KIND_RANGED:
		return false
	var weapon := stack.item.weapon
	return stack.ammo_loaded < weapon.magazine_size and inventory.count_of(weapon.ammo_item_id) > 0


## Pasa munición del inventario al cargador. Devuelve cuántas balas cargó.
static func reload_from(stack: ItemStack, inventory: Inventory) -> int:
	if not can_reload(stack, inventory):
		return 0
	var weapon := stack.item.weapon
	var wanted := weapon.magazine_size - stack.ammo_loaded
	var loaded := inventory.remove_count(weapon.ammo_item_id, wanted)
	stack.ammo_loaded += loaded
	return loaded


## Aplica el desgaste de un golpe que acierta con un arma cuerpo a cuerpo.
## Puede romperla en pleno golpe: el golpe cuenta igual, pero el arma queda rota.
static func melee_hit(stack: ItemStack) -> int:
	if not stack.is_weapon() or stack.durability.is_broken():
		return HIT_NONE
	if stack.durability.wear(stack.item.weapon.wear_per_hit):
		return HIT_BROKE
	return HIT_OK

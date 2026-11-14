class_name ItemStack
extends RefCounted
## Una casilla del inventario: un objeto, su cantidad y, si se desgasta, su durabilidad.
## Las armas de fuego guardan además las balas cargadas.

var item: ItemData = null
var count: int = 1
var durability: Durability = null
var ammo_loaded: int = 0


func _init(data: ItemData, amount: int = 1, fraction_left: float = 1.0) -> void:
	item = data
	count = clampi(amount, 1, maxi(data.max_stack, 1))
	durability = Durability.new(data.max_durability(), fraction_left)


func id() -> String:
	return item.id


func is_weapon() -> bool:
	return item.weapon != null


func is_vest() -> bool:
	return item.vest != null


## Un arma que se puede romper y que no está entera ni rota (apta para reparar).
func is_repairable() -> bool:
	return (
		is_weapon()
		and not durability.is_unbreakable()
		and not durability.is_broken()
		and durability.fraction() < 1.0
	)


func space_left() -> int:
	return item.max_stack - count

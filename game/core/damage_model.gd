class_name DamageModel
extends RefCounted
## Cálculo del daño que recibe el jugador, con o sin chaleco.


## Aplica un golpe al jugador. vest puede ser null. Devuelve la salud que pierde y desgasta
## el chaleco según el daño absorbido. Un chaleco roto no protege.
static func player_damage(amount: float, vest: ItemStack) -> float:
	var incoming := maxf(amount, 0.0)
	if vest == null or not vest.is_vest() or vest.durability.is_broken():
		return incoming
	var absorbed := incoming * clampf(vest.item.vest.damage_reduction, 0.0, 1.0)
	vest.durability.wear(absorbed * vest.item.vest.wear_per_damage)
	return incoming - absorbed

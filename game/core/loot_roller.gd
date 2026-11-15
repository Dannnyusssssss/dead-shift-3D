class_name LootRoller
extends RefCounted
## Botín al morir un enemigo. Los enemigos normales no sueltan nada; el policía zombi
## suelta balas y, si llevaba chaleco sin romper, el chaleco en el estado en que quedó.


## Devuelve las casillas que suelta el enemigo. El azar se inyecta para poder reproducirlo; la
## dificultad (opcional) reduce la munición.
static func roll(
	enemy: EnemyHealth,
	catalog: ItemCatalog,
	rng: RandomNumberGenerator,
	difficulty: Difficulty = null
) -> Array[ItemStack]:
	var drops: Array[ItemStack] = []
	var data := enemy.data
	var ammo := catalog.get_item(data.ammo_item_id)
	if ammo != null and data.ammo_max > 0:
		var amount := rng.randi_range(maxi(data.ammo_min, 0), maxi(data.ammo_max, data.ammo_min))
		if amount > 0 and difficulty != null:
			amount = difficulty.ammo_found(amount)
		if amount > 0:
			drops.append(ItemStack.new(ammo, mini(amount, ammo.max_stack)))
	var vest := catalog.get_item(data.vest_item_id)
	if vest != null and enemy.has_vest and not enemy.vest_durability.is_broken():
		drops.append(ItemStack.new(vest, 1, enemy.vest_durability.fraction()))
	return drops

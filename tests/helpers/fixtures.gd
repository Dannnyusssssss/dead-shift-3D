extends RefCounted
## Datos de prueba construidos en código, independientes de los valores de los .tres.


static func melee(item_id: String, max_durability: float = 10.0, wear: float = 1.0) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.category = ItemData.CATEGORY_WEAPON
	data.max_stack = 1
	data.weapon = WeaponData.new()
	data.weapon.kind = WeaponData.KIND_MELEE
	data.weapon.damage = 20.0
	data.weapon.max_durability = max_durability
	data.weapon.wear_per_hit = wear
	return data


static func pistol(magazine: int = 8) -> ItemData:
	var data := ItemData.new()
	data.id = "pistol"
	data.category = ItemData.CATEGORY_WEAPON
	data.weapon = WeaponData.new()
	data.weapon.kind = WeaponData.KIND_RANGED
	data.weapon.damage = 30.0
	data.weapon.magazine_size = magazine
	data.weapon.ammo_item_id = "ammo"
	return data


static func material(item_id: String, max_stack: int = 5) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.category = ItemData.CATEGORY_MATERIAL
	data.max_stack = max_stack
	return data


## Objeto apilable que ocupa casillas (munición): para probar pilas en la mochila, porque los
## materiales van a la bolsa.
static func stackable(item_id: String, max_stack: int = 5) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.category = ItemData.CATEGORY_AMMO
	data.max_stack = max_stack
	return data


static func recipe_amounts(
	a: String, b: String, result: String, amount_a: int, amount_b: int
) -> RecipeData:
	var data := recipe(a, b, result)
	data.amount_a = amount_a
	data.amount_b = amount_b
	return data


static func vest(reduction: float = 0.5, wear_per_damage: float = 1.0) -> ItemData:
	var data := ItemData.new()
	data.id = "vest"
	data.category = ItemData.CATEGORY_VEST
	data.vest = VestData.new()
	data.vest.max_durability = 100.0
	data.vest.damage_reduction = reduction
	data.vest.wear_per_damage = wear_per_damage
	return data


static func consumable(item_id: String, effect: int, heal: float = 0.0) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.category = ItemData.CATEGORY_CONSUMABLE
	data.max_stack = 3
	data.use_effect = effect
	data.heal_amount = heal
	data.use_time = 1.0
	return data


static func recipe(a: String, b: String, result: String, repair: float = 0.0) -> RecipeData:
	var data := RecipeData.new()
	data.id = a + "_" + b
	data.input_a = a
	data.input_b = b
	data.result_id = result
	data.repair_fraction = repair
	return data


static func rng(seed_value: int = 1234) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator

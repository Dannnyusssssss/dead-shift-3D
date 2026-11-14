class_name EnemyHealth
extends RefCounted
## Salud de un enemigo y, si lleva, el estado de su chaleco. Disparar al chaleco reduce el
## daño pero lo desgasta; los golpes cuerpo a cuerpo y los disparos fuera del chaleco no.

var data: EnemyData = null
var health: float = 0.0
var has_vest: bool = false
## Durabilidad del chaleco que lleva (solo si has_vest), en la escala del chaleco que suelta.
var vest_durability: Durability = null


## Crea la salud de un enemigo. Si puede llevar chaleco, el azar inyectado decide si lo lleva,
## salvo que el nivel lo fije con vest_override (0 = sin chaleco, 1 = con chaleco).
func _init(
	enemy: EnemyData, rng: RandomNumberGenerator, vest_max: float = 100.0, vest_override: int = -1
) -> void:
	data = enemy
	health = enemy.max_health
	if vest_override >= 0:
		has_vest = vest_override == 1 and enemy.vest_chance > 0.0
	else:
		has_vest = enemy.vest_chance > 0.0 and rng.randf() < enemy.vest_chance
	vest_durability = Durability.new(vest_max if has_vest else 0.0)


func is_dead() -> bool:
	return health <= 0.0


## Aplica un impacto. zone es Rules.ZONE_*; is_bullet indica si fue un disparo.
## Devuelve el daño aplicado.
func take_hit(damage: float, zone: int, is_bullet: bool) -> float:
	if is_dead():
		return 0.0
	var amount := maxf(damage, 0.0)
	if zone == Rules.ZONE_HEAD:
		amount *= Rules.HEAD_MULTIPLIER
	elif zone == Rules.ZONE_VEST and is_bullet and has_vest and not vest_durability.is_broken():
		var absorbed := amount * clampf(data.vest_damage_reduction, 0.0, 1.0)
		vest_durability.wear(absorbed * data.vest_wear_per_damage)
		amount -= absorbed
	health = maxf(health - amount, 0.0)
	return amount

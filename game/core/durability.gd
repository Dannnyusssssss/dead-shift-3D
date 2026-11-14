class_name Durability
extends RefCounted
## Desgaste de un arma o chaleco. Con máximo 0 el objeto no se rompe nunca.
## Estados en tres pasos más roto, para el icono de estado (no solo color).

const STATE_GOOD: int = 0
const STATE_DAMAGED: int = 1
const STATE_CRITICAL: int = 2
const STATE_BROKEN: int = 3

var max_value: float = 0.0
var current: float = 0.0


func _init(maximum: float = 0.0, fraction_left: float = 1.0) -> void:
	max_value = maxf(maximum, 0.0)
	current = max_value * clampf(fraction_left, 0.0, 1.0)


func is_unbreakable() -> bool:
	return max_value <= 0.0


func is_broken() -> bool:
	return not is_unbreakable() and current <= 0.0


## Fracción restante (1 en objetos que no se rompen).
func fraction() -> float:
	if is_unbreakable():
		return 1.0
	return current / max_value


func state() -> int:
	if is_unbreakable():
		return STATE_GOOD
	if current <= 0.0:
		return STATE_BROKEN
	var left := fraction()
	if left < Rules.DURABILITY_CRITICAL:
		return STATE_CRITICAL
	if left < Rules.DURABILITY_DAMAGED:
		return STATE_DAMAGED
	return STATE_GOOD


## Aplica desgaste. Devuelve verdadero solo en el momento en que se rompe.
func wear(amount: float) -> bool:
	if is_unbreakable() or is_broken() or amount <= 0.0:
		return false
	current = maxf(current - amount, 0.0)
	return current <= 0.0


## Recupera una fracción de la durabilidad máxima. Un objeto roto no se repara.
func repair(fraction_of_max: float) -> void:
	if is_unbreakable() or is_broken():
		return
	current = minf(current + max_value * maxf(fraction_of_max, 0.0), max_value)

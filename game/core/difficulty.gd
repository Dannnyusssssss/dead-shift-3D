class_name Difficulty
extends RefCounted
## Aplica una dificultad (DifficultyData) a los valores del juego: vida y daño de enemigos,
## contagio, vida del jefe, espera del helicóptero, oleadas, munición y objetos escasos
## encontrados y autoguardado. Lógica pura: recibe valores base y devuelve los ajustados.
## Sin datos (null) se comporta como Fácil: todo igual.

const EASY: String = "easy"
const MEDIUM: String = "medium"
const HARD: String = "hard"
## Identificadores válidos, en el orden en que se ofrecen.
const IDS: Array[String] = [EASY, MEDIUM, HARD]
## Margen para que un multiplicador 1 no pierda una unidad al redondear hacia abajo.
const ROUND_EPSILON: float = 0.0001

var data: DifficultyData = null


func _init(difficulty_data: DifficultyData = null) -> void:
	data = difficulty_data


func id() -> String:
	return data.id if data != null else EASY


func enemy_health(base: float) -> float:
	return base * _value(data.enemy_health_multiplier if data != null else 1.0)


func enemy_damage(base: float) -> float:
	return base * _value(data.enemy_damage_multiplier if data != null else 1.0)


## Exposición que suma una mordida, entre 0 y 1.
func infection_exposure(base: float) -> float:
	var factor := _value(data.infection_chance_multiplier if data != null else 1.0)
	return clampf(base * factor, 0.0, 1.0)


func boss_health_multiplier() -> float:
	return _value(data.boss_health_multiplier if data != null else 1.0)


func helicopter_wait_time() -> float:
	if data == null:
		return Rules.HELICOPTER_WAIT_TIME
	return maxf(data.helicopter_wait_time, 1.0)


## Tamaño de cada oleada (al entero más cercano; nunca menos que la base, ni menos de 1).
func waves(base: Array[int]) -> Array[int]:
	var factor := _value(data.wave_size_multiplier if data != null else 1.0)
	var result: Array[int] = []
	for size: int in base:
		result.append(maxi(maxi(roundi(float(size) * factor), size), 1))
	return result


func autosave_on_floor_change() -> bool:
	return data == null or data.autosave_on_floor_change


## Munición encontrada en un punto de botín: hacia abajo, con un mínimo de 1.
func ammo_found(count: int) -> int:
	if count <= 0:
		return 0
	var factor := _value(data.ammo_found_multiplier if data != null else 1.0)
	return maxi(floori(float(count) * factor + ROUND_EPSILON), 1)


## Ajustador del botín de un piso: se crea uno por piso y se le pasan los puntos en el orden
## de las salas, siempre (también los ya recogidos), para que lo quitado no dependa de lo que
## el jugador haya hecho antes.
func floor_loot() -> FloorLoot:
	var removed := 0
	var scarce := ""
	if data != null:
		removed = maxi(data.scarce_removed_per_floor, 0)
		scarce = data.scarce_item_id
	return FloorLoot.new(self, scarce, removed)


static func _value(factor: float) -> float:
	return maxf(factor, 0.0)


## Ajusta las cantidades del botín de un piso: munición según la dificultad y el objeto escaso
## quitado en las primeras apariciones.
class FloorLoot:
	extends RefCounted

	var _difficulty: Difficulty = null
	var _scarce_id: String = ""
	var _to_remove: int = 0

	func _init(difficulty: Difficulty, scarce_id: String, to_remove: int) -> void:
		_difficulty = difficulty
		_scarce_id = scarce_id
		_to_remove = to_remove

	## Cantidad ajustada de un objeto (0 = no aparece).
	func adjust(item_id: String, category: int, count: int) -> int:
		var result := count
		if category == ItemData.CATEGORY_AMMO:
			result = _difficulty.ammo_found(count)
		if item_id == _scarce_id and _to_remove > 0 and result > 0:
			var taken := mini(_to_remove, result)
			_to_remove -= taken
			result -= taken
		return result

	## Contenido de un contenedor ("id:cantidad") con las cantidades ajustadas. Las entradas
	## que no se reconocen se dejan como están (el contenedor las rechaza al leerlas).
	func adjust_contents(contents: PackedStringArray, items: ItemCatalog) -> PackedStringArray:
		var result := PackedStringArray()
		for entry: String in contents:
			var parts := entry.split(":")
			var item := items.get_item(parts[0]) if not parts.is_empty() else null
			if item == null:
				result.append(entry)
				continue
			var count := 1
			if parts.size() > 1 and parts[1].is_valid_int():
				count = parts[1].to_int()
			var adjusted := adjust(item.id, item.category, count)
			if adjusted > 0:
				result.append("%s:%d" % [item.id, adjusted])
		return result

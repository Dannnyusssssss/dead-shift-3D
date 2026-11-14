class_name RecipeData
extends Resource
## Receta de dos objetos. Si repair_fraction > 0 es una reparación: input_a es el material
## (por ejemplo, cinta) y el segundo objeto puede ser cualquier arma dañada que se pueda romper.

@export var id: String = ""
@export var input_a: String = ""
@export var input_b: String = ""
@export var result_id: String = ""
## Segundos que dura la combinación (el jugador queda indefenso).
@export var craft_time: float = 3.0
## Fracción de la durabilidad máxima que recupera (solo reparaciones).
@export var repair_fraction: float = 0.0


func is_repair() -> bool:
	return repair_fraction > 0.0

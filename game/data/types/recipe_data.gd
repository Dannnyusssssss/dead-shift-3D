class_name RecipeData
extends Resource
## Receta de dos objetos. Si repair_fraction > 0 es una reparación: input_a es el material
## (por ejemplo, cinta) y el segundo objeto puede ser cualquier arma dañada que se pueda romper.
## Los materiales salen de la bolsa en las cantidades indicadas.

@export var id: String = ""
@export var input_a: String = ""
@export var input_b: String = ""
@export var result_id: String = ""
## Unidades que gasta cada entrada si es un material (un objeto de casilla siempre gasta 1).
@export var amount_a: int = 1
@export var amount_b: int = 1
## Unidades del resultado.
@export var result_count: int = 1
## Segundos que dura la combinación (el jugador queda indefenso).
@export var craft_time: float = 3.0
## Fracción de la durabilidad máxima que recupera (solo reparaciones).
@export var repair_fraction: float = 0.0


func is_repair() -> bool:
	return repair_fraction > 0.0

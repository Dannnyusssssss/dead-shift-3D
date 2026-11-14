class_name ItemData
extends Resource
## Un objeto del juego: material, munición, arma o chaleco.

const CATEGORY_MATERIAL: int = 0
const CATEGORY_AMMO: int = 1
const CATEGORY_WEAPON: int = 2
const CATEGORY_VEST: int = 3

## Identificador interno (minúsculas, dígitos y guion bajo).
@export var id: String = ""
## Clave de traducción del nombre visible.
@export var name_key: String = ""
@export var category: int = CATEGORY_MATERIAL
## Cuántas unidades caben en una casilla (armas y chalecos: 1).
@export var max_stack: int = 1
## Datos de arma (solo categoría arma).
@export var weapon: WeaponData = null
## Datos de chaleco (solo categoría chaleco).
@export var vest: VestData = null


## Durabilidad máxima del objeto (0 si no se desgasta).
func max_durability() -> float:
	if weapon != null:
		return weapon.max_durability
	if vest != null:
		return vest.max_durability
	return 0.0

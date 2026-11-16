class_name ItemData
extends Resource
## Un objeto del juego: material, munición, arma o chaleco.

const CATEGORY_MATERIAL: int = 0
const CATEGORY_AMMO: int = 1
const CATEGORY_WEAPON: int = 2
const CATEGORY_VEST: int = 3
const CATEGORY_CONSUMABLE: int = 4
## Objeto clave (llaves, piezas del teléfono): no ocupa casilla ni se suelta ni se lanza.
const CATEGORY_KEY: int = 5

## Efecto al usar un consumible.
const EFFECT_NONE: int = 0
const EFFECT_HEAL: int = 1
const EFFECT_DELAY_INFECTION: int = 2
const EFFECT_CURE_INFECTION: int = 3

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
## Consumible: efecto, salud que recupera y segundos que tarda en usarse.
@export var use_effect: int = EFFECT_NONE
@export var heal_amount: float = 0.0
@export var use_time: float = 0.0
## Se rompe al caer cuando se lanza (más ruido y no se puede recoger).
@export var fragile: bool = false
## Señuelo: segundos que sigue haciendo ruido donde cae al lanzarlo (0 = no es señuelo).
@export var lure_time: float = 0.0
## Va siempre con el guardia: no se suelta (la porra).
@export var bound: bool = false
## Materiales: unidades que trae cada punto de botín (bote, paquete, rollo) si no se indica otra
## cantidad; solo lo usa el generador de pisos y la descripción.
@export var pack_size: int = 1


## Durabilidad máxima del objeto (0 si no se desgasta).
func max_durability() -> float:
	if weapon != null:
		return weapon.max_durability
	if vest != null:
		return vest.max_durability
	return 0.0

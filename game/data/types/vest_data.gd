class_name VestData
extends Resource
## Parámetros de un chaleco: cuánto daño absorbe y cuánto se desgasta.

@export var max_durability: float = 100.0
## Fracción del daño que absorbe mientras no está roto (0 a 1).
@export var damage_reduction: float = 0.5
## Desgaste por cada punto de daño absorbido.
@export var wear_per_damage: float = 1.0

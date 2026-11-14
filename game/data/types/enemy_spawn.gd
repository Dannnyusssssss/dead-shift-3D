class_name EnemySpawn
extends Resource
## Un enemigo colocado en un piso.

@export var enemy: EnemyData = null
@export var position: Vector3 = Vector3.ZERO
## -1 = el azar decide si lleva chaleco; 0 = sin chaleco; 1 = con chaleco.
@export var vest_override: int = -1
@export var rng_seed: int = 1

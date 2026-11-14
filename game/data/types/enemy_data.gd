class_name EnemyData
extends Resource
## Parámetros de un tipo de enemigo y de su botín.

@export var id: String = ""
@export var name_key: String = ""
@export var max_health: float = 100.0
@export var move_speed: float = 1.5
@export var attack_damage: float = 10.0
@export var attack_interval: float = 1.5
@export var attack_range: float = 1.6
## Distancia a la que ve al jugador.
@export var sight_range: float = 14.0
## Clave del comportamiento registrado en la tabla de comportamientos.
@export var behavior: String = "walker"
## Botín de munición (0 y 0 = no suelta).
@export var ammo_item_id: String = ""
@export var ammo_min: int = 0
@export var ammo_max: int = 0
## Probabilidad de llevar chaleco (0 a 1) y objeto de chaleco que suelta.
@export var vest_chance: float = 0.0
@export var vest_item_id: String = ""
## Fracción del daño que absorbe su chaleco cuando se le dispara en el chaleco.
@export var vest_damage_reduction: float = 0.6
## Desgaste de su chaleco por cada punto de daño recibido en el chaleco.
@export var vest_wear_per_damage: float = 1.5

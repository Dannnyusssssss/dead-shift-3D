class_name WeaponData
extends Resource
## Parámetros de un arma. Un arma con max_durability 0 no se rompe.

const KIND_MELEE: int = 0
const KIND_RANGED: int = 1

@export var kind: int = KIND_MELEE
## Daño por golpe o por bala.
@export var damage: float = 10.0
## Segundos mínimos entre ataques. En armas de fuego, 0.34 o más limita
## los destellos del disparo a 3 por segundo.
@export var attack_interval: float = 0.6
## Alcance en metros.
@export var attack_range: float = 2.0
## Durabilidad máxima (0 = no se rompe).
@export var max_durability: float = 0.0
## Desgaste por cada golpe que acierta.
@export var wear_per_hit: float = 0.0
## Nivel de ruido al atacar (Rules.NOISE_*).
@export var noise_level: int = 1
## Aturde al enemigo al golpear.
@export var stuns: bool = false
## Solo armas de fuego: balas por cargador, tiempo de recarga y objeto de munición.
@export var magazine_size: int = 0
@export var reload_time: float = 0.0
@export var ammo_item_id: String = ""

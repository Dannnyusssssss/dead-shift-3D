class_name BossData
extends Resource
## Parámetros del jefe: vida por fase, daño según dónde se golpea, aturdimientos y ataques.

## Vida de cada fase (la segunda empieza al romperse el traje).
@export var phase_one_health: float = 600.0
@export var phase_two_health: float = 250.0
## Multiplicador del daño de frente en cada fase (el traje protege en la primera).
@export var phase_one_front_multiplier: float = 0.5
@export var phase_two_front_multiplier: float = 1.0
## Multiplicador al golpear el tanque de la espalda o mientras está aturdido.
@export var tank_multiplier: float = 2.5
## Velocidad al caminar en cada fase.
@export var phase_one_speed: float = 1.8
@export var phase_two_speed: float = 2.6
## Aturdimientos (segundos): extintor, tablero eléctrico, choque contra una pared, cambio de fase.
@export var extinguisher_stun: float = 3.0
@export var panel_stun: float = 5.0
@export var wall_stun: float = 2.5
@export var phase_change_stun: float = 2.0
## Tras recuperarse de un aturdimiento, segundos en que el extintor no lo vuelve a aturdir.
@export var extinguisher_immunity: float = 6.0
## Embestida: distancias en que la usa, preparación visible, velocidad, duración, daño y espera.
@export var charge_min_distance: float = 4.0
@export var charge_max_distance: float = 14.0
@export var charge_windup: float = 1.1
@export var charge_speed: float = 9.0
@export var charge_duration: float = 1.6
@export var charge_damage: float = 35.0
@export var charge_cooldown: float = 6.0
## Golpe cercano.
@export var swipe_range: float = 2.2
@export var swipe_windup: float = 0.6
@export var swipe_damage: float = 22.0
@export var swipe_cooldown: float = 1.8
## Nube tóxica: espera entre nubes por fase, radio, aviso, duración y daño por segundo por fase.
@export var cloud_cooldown_phase_one: float = 10.0
@export var cloud_cooldown_phase_two: float = 7.0
@export var cloud_radius: float = 3.0
@export var cloud_warning: float = 1.0
@export var cloud_duration: float = 6.0
@export var cloud_dps_phase_one: float = 6.0
@export var cloud_dps_phase_two: float = 8.0
## Objeto clave que suelta al morir.
@export var drop_key_item: String = "roof_key"

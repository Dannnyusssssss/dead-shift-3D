extends EnemyBehavior
## Acechador: rápido y frágil. No entra de frente: rodea al jugador por un lado hasta quedar a su
## espalda o a un flanco y solo entonces ataca. Si el jugador lo mira de frente, se retira un
## momento. Si no tiene ruta para rodear (pasillo cerrado), ataca igualmente.

## Ángulo (grados desde donde mira el jugador) dentro del cual se siente observado.
const WATCHED_CONE_DEG: float = 35.0
## Distancia máxima a la que mirarlo lo hace retirarse (más lejos, sigue rodeando).
const WATCHED_DISTANCE: float = 7.0
## Ángulo mínimo respecto a la mirada del jugador para atacar (flanco o espalda).
const ATTACK_CONE_DEG: float = 70.0
## Radio del círculo por el que rodea y cuánto avanza en cada paso (grados).
const CIRCLE_RADIUS: float = 4.0
const CIRCLE_STEP_DEG: float = 70.0
## Distancia del punto final de ataque, detrás o al lado del jugador.
const CLOSE_DISTANCE: float = 1.2
const RETREAT_TIME: float = 1.4
const RETREAT_DISTANCE: float = 6.0
## Grados que se desvía la retirada hacia su lado de rodeo (no huye en línea recta).
const RETREAT_SWERVE_DEG: float = 50.0
## Segundos tras una retirada en los que no vuelve a retirarse (para poder rodear).
const RETREAT_COOLDOWN: float = 1.2

## Segundos que le quedan de retirada.
var retreat_left: float = 0.0
## Lado por el que rodea (1 o -1); se elige al empezar según dónde está.
var side: float = 0.0

var _cooldown: float = 0.0


func target_position(enemy: Enemy, player: Player) -> Vector3:
	var to_enemy := _flat(enemy.global_position - player.global_position)
	if to_enemy.length() < 0.01:
		to_enemy = Vector3.FORWARD
	var facing := _facing(player)
	var angle := rad_to_deg(facing.signed_angle_to(to_enemy.normalized(), Vector3.UP))
	if side == 0.0:
		side = 1.0 if angle >= 0.0 else -1.0
	if retreat_left > 0.0:
		var away := to_enemy.normalized().rotated(Vector3.UP, deg_to_rad(side * RETREAT_SWERVE_DEG))
		return enemy.global_position + away * RETREAT_DISTANCE
	if absf(angle) >= ATTACK_CONE_DEG + 20.0:
		# Ya está en el flanco o detrás: se acerca a la espalda para golpear.
		return player.global_position + to_enemy.normalized() * CLOSE_DISTANCE
	# Sigue rodeando: el siguiente punto del círculo, alejándose de la mirada.
	var next_angle := deg_to_rad(angle + side * CIRCLE_STEP_DEG)
	var direction := facing.rotated(Vector3.UP, next_angle)
	return player.global_position + direction * CIRCLE_RADIUS


func can_attack(enemy: Enemy, player: Player) -> bool:
	if retreat_left > 0.0:
		return false
	if not enemy.has_route():
		return true
	var to_enemy := _flat(enemy.global_position - player.global_position)
	if to_enemy.length() < 0.01:
		return true
	return rad_to_deg(_facing(player).angle_to(to_enemy.normalized())) >= ATTACK_CONE_DEG


func update(enemy: Enemy, player: Player, delta: float) -> void:
	if retreat_left > 0.0:
		retreat_left = maxf(retreat_left - delta, 0.0)
		if retreat_left <= 0.0:
			_cooldown = RETREAT_COOLDOWN
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown <= 0.0 and is_watched(enemy, player):
		retreat_left = RETREAT_TIME


## Verdadero si el jugador lo está mirando de frente y lo tiene a la vista.
func is_watched(enemy: Enemy, player: Player) -> bool:
	if not enemy.sees_player:
		return false
	var to_enemy := _flat(enemy.global_position - player.global_position)
	if to_enemy.length() > WATCHED_DISTANCE or to_enemy.length() < 0.01:
		return false
	return rad_to_deg(_facing(player).angle_to(to_enemy.normalized())) <= WATCHED_CONE_DEG


func _facing(player: Player) -> Vector3:
	var forward := _flat(player.aim_direction())
	return forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)

class_name EnemyBehavior
extends RefCounted
## Comportamiento de un tipo de enemigo mientras persigue: a dónde se mueve, si puede atacar
## ahora y qué hace cada fotograma. La máquina de estados común (Enemy) hace el resto. Un tipo
## nuevo hereda de aquí y se registra en EnemyBehaviors.


## Punto al que debe dirigirse. Por defecto, directo hacia el jugador.
func target_position(_enemy: Enemy, player: Player) -> Vector3:
	return player.global_position


## Verdadero si puede empezar un ataque ahora (ya está a distancia de golpe).
func can_attack(_enemy: Enemy, _player: Player) -> bool:
	return true


## Se llama cada fotograma de física mientras persigue (temporizadores propios).
func update(_enemy: Enemy, _player: Player, _delta: float) -> void:
	pass

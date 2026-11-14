class_name EnemyBehavior
extends RefCounted
## Comportamiento de un tipo de enemigo: decide hacia dónde se mueve mientras persigue.
## La máquina de estados común (Enemy) hace el resto. Un tipo nuevo hereda de aquí y se
## registra en EnemyBehaviors.


## Punto al que debe dirigirse. Por defecto, directo hacia el jugador.
func target_position(_enemy: Enemy, player: Player) -> Vector3:
	return player.global_position

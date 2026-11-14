class_name EnemyBehaviors
extends RefCounted
## Tabla única de comportamientos de enemigos: clave del .tres -> script.

const TABLE: Dictionary = {
	"walker": preload("res://game/actors/enemies/behaviors/walker_behavior.gd"),
}


## Crea el comportamiento de la clave dada; si no existe, usa el de caminante.
static func create(key: String) -> EnemyBehavior:
	var script: GDScript = TABLE.get(key, TABLE["walker"])
	var behavior: EnemyBehavior = script.new()
	return behavior

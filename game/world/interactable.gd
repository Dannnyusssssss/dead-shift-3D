class_name Interactable
extends Area3D
## Algo con lo que el jugador puede interactuar apuntando y pulsando «interactuar».
## Las subclases sobrescriben interact(). Va en la capa de interactuables.

## Se emitió una interacción (para que otros nodos reaccionen sin buscarse).
signal used(player: Player)

## Clave del texto que se muestra al apuntarlo.
@export var prompt_key: String = "prompt_use"
var enabled: bool = true


func _ready() -> void:
	collision_layer = Rules.LAYER_INTERACTABLE
	collision_mask = 0
	monitoring = false


## Clave del texto de ayuda, o "" si ahora no se puede usar.
func get_prompt_key() -> String:
	return prompt_key if enabled else ""


func interact(player: Player) -> void:
	used.emit(player)

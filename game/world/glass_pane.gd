class_name GlassPane
extends StaticBody3D
## Cuerpo de colisión de un panel de cristal de escaparate. Un disparo, un golpe o un objeto
## lanzado que lo alcanza llama a shatter(); el dibujo lo hace su GlassPanes (una sola malla
## por sala).

var group: GlassPanes = null
var index: int = -1


func _init() -> void:
	collision_layer = Rules.LAYER_WORLD
	collision_mask = 0


## Rompe el panel. Devuelve verdadero si estaba entero.
func shatter() -> bool:
	return group != null and group.break_pane(index)

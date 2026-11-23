class_name DrawDistance
extends RefCounted
## Distancia de dibujo de las piezas sueltas según la calidad: lo que queda lejos (casi siempre
## en otro piso o al fondo del pasillo) deja de dibujarse y ahorra llamadas de dibujo. Se marca
## cada pieza al crearla y se vuelve a aplicar al cambiar la calidad.

const SMALL: StringName = &"draw_distance_small"
const LARGE: StringName = &"draw_distance_large"


## Distancia para un tamaño y una calidad (0 = sin límite).
static func range_for(kind: StringName, quality: int) -> float:
	var table := Rules.DRAW_DISTANCE_LARGE if kind == LARGE else Rules.DRAW_DISTANCE_SMALL
	return table[clampi(quality, 0, table.size() - 1)]


## Marca una pieza (y todo lo que dibuja debajo) con su tamaño y le aplica la distancia actual.
static func mark(node: Node, kind: StringName) -> void:
	node.add_to_group(kind)
	_apply(node, range_for(kind, Settings.get_int("quality")))


## Vuelve a aplicar la distancia a todas las piezas marcadas (al cambiar la calidad).
static func refresh(tree: SceneTree) -> void:
	var quality := Settings.get_int("quality")
	for kind: StringName in [SMALL, LARGE]:
		var distance := range_for(kind, quality)
		for node: Node in tree.get_nodes_in_group(kind):
			_apply(node, distance)


static func _apply(node: Node, distance: float) -> void:
	var geometry := node as GeometryInstance3D
	if geometry != null:
		geometry.visibility_range_end = distance
		# Margen para que no parpadee al moverse justo en el límite.
		geometry.visibility_range_end_margin = 1.0 if distance > 0.0 else 0.0
	for child: Node in node.get_children():
		_apply(child, distance)

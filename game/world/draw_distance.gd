class_name DrawDistance
extends RefCounted
## Distancia de dibujo de las piezas sueltas según la calidad: lo que queda lejos (casi siempre
## en otro piso o al fondo del pasillo) deja de dibujarse y ahorra llamadas de dibujo. Se marca
## cada pieza al crearla y se vuelve a aplicar al cambiar la calidad.

const SMALL: StringName = &"draw_distance_small"
const LARGE: StringName = &"draw_distance_large"
## Luces de las salas: se apagan con un fundido a partir de la distancia de su calidad.
const LIGHT: StringName = &"draw_distance_light"
## Metros en los que se desvanece una luz lejana antes de dejar de calcularse.
const LIGHT_FADE_LENGTH: float = 4.0


## Distancia para un tamaño y una calidad (0 = sin límite).
static func range_for(kind: StringName, quality: int) -> float:
	var table := Rules.DRAW_DISTANCE_LARGE if kind == LARGE else Rules.DRAW_DISTANCE_SMALL
	return table[clampi(quality, 0, table.size() - 1)]


## Marca una pieza (y todo lo que dibuja debajo) con su tamaño y le aplica la distancia actual.
static func mark(node: Node, kind: StringName) -> void:
	node.add_to_group(kind)
	_apply(node, range_for(kind, Settings.get_int("quality")))


## Distancia a la que se apagan las luces de las salas en una calidad (0 = nunca).
static func light_fade_for(quality: int) -> float:
	var table := Rules.LIGHT_FADE_DISTANCE
	return table[clampi(quality, 0, table.size() - 1)]


## Marca una luz de sala y le aplica el fundido por distancia de la calidad actual.
static func mark_light(light: Light3D) -> void:
	light.add_to_group(LIGHT)
	_apply_light(light, light_fade_for(Settings.get_int("quality")))


## Vuelve a aplicar la distancia a todas las piezas y luces marcadas (al cambiar la calidad).
static func refresh(tree: SceneTree) -> void:
	var quality := Settings.get_int("quality")
	for kind: StringName in [SMALL, LARGE]:
		var distance := range_for(kind, quality)
		for node: Node in tree.get_nodes_in_group(kind):
			_apply(node, distance)
	var fade := light_fade_for(quality)
	for node: Node in tree.get_nodes_in_group(LIGHT):
		var light := node as Light3D
		if light != null:
			_apply_light(light, fade)


## Quita todos los límites de distancia y los fundidos de luz (la preparación de materiales
## antes de jugar); refresh() los vuelve a poner.
static func apply_unlimited(tree: SceneTree) -> void:
	for kind: StringName in [SMALL, LARGE]:
		for node: Node in tree.get_nodes_in_group(kind):
			_apply(node, 0.0)
	for node: Node in tree.get_nodes_in_group(LIGHT):
		var light := node as Light3D
		if light != null:
			_apply_light(light, 0.0)


static func _apply_light(light: Light3D, distance: float) -> void:
	light.distance_fade_enabled = distance > 0.0
	light.distance_fade_begin = distance
	light.distance_fade_length = LIGHT_FADE_LENGTH


static func _apply(node: Node, distance: float) -> void:
	var geometry := node as GeometryInstance3D
	if geometry != null:
		geometry.visibility_range_end = distance
		# Margen para que no parpadee al moverse justo en el límite.
		geometry.visibility_range_end_margin = 1.0 if distance > 0.0 else 0.0
	for child: Node in node.get_children():
		_apply(child, distance)

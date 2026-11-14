class_name Kit
extends RefCounted
## Kit modular provisional (gris): suelo, techo, paredes con puertas y escaparates, cristal.
## Las piezas de una sala se funden en una sola malla por material para ahorrar llamadas
## de dibujo; las colisiones van por segmento. El arte final reemplazará estas mallas.

const WALL_THICKNESS: float = 0.2
const DOOR_HEIGHT: float = 2.3
const WINDOW_SILL: float = 0.9
const WINDOW_TOP: float = 2.6
const GLASS_THICKNESS: float = 0.04

static var _materials: Dictionary = {}


## Material mate compartido por color (se reutiliza entre salas).
static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = 0.95
	_materials[key] = made
	return made


static func glass_material() -> StandardMaterial3D:
	var key := "glass"
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = Color(0.6, 0.75, 0.8, 0.22)
	made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	made.roughness = 0.1
	_materials[key] = made
	return made


## Acumulador de cajas: una malla por material y colisiones por caja.
class Builder:
	extends RefCounted
	var _tools: Dictionary = {}
	var _shapes: Array[Array] = []

	func add_box(
		center: Vector3, size: Vector3, mat: StandardMaterial3D, solid: bool = true
	) -> void:
		if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
			return
		var tool: SurfaceTool = _tools.get(mat)
		if tool == null:
			tool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(mat)
			_tools[mat] = tool
		var box := BoxMesh.new()
		box.size = size
		tool.append_from(box, 0, Transform3D(Basis.IDENTITY, center))
		if solid:
			_shapes.append([center, size])

	## Crea el cuerpo estático con todas las mallas y colisiones acumuladas.
	func build(name: String) -> StaticBody3D:
		var body := StaticBody3D.new()
		body.name = name
		body.collision_layer = Rules.LAYER_WORLD
		body.collision_mask = 0
		for mat: StandardMaterial3D in _tools:
			var tool: SurfaceTool = _tools[mat]
			tool.generate_normals()
			var instance := MeshInstance3D.new()
			instance.mesh = tool.commit()
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(instance)
		for spec: Array in _shapes:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = spec[1]
			shape.shape = box
			shape.position = spec[0]
			body.add_child(shape)
		return body


## Añade una pared recta de start a end (en el suelo) con aberturas.
## Cada abertura es [desde, hasta, abajo, arriba, cristal] medida a lo largo de la pared.
static func add_wall(
	builder: Builder,
	start: Vector3,
	end: Vector3,
	height: float,
	openings: Array[Array],
	wall_mat: StandardMaterial3D
) -> void:
	var length := start.distance_to(end)
	var along := (end - start).normalized()
	var across_x := absf(along.x) > 0.5
	var cursor := 0.0
	openings.sort_custom(_opening_before)
	for opening: Array in openings:
		var raw_from: float = opening[0]
		var raw_to: float = opening[1]
		var bottom: float = opening[2]
		var top: float = opening[3]
		var glass: bool = opening[4]
		var from := clampf(raw_from, 0.0, length)
		var to := clampf(raw_to, from, length)
		_segment(builder, start, along, across_x, cursor, from, 0.0, height, wall_mat)
		_segment(builder, start, along, across_x, from, to, 0.0, bottom, wall_mat)
		_segment(builder, start, along, across_x, from, to, top, height, wall_mat)
		if glass:
			var center := start + along * ((from + to) * 0.5) + Vector3.UP * ((bottom + top) * 0.5)
			var size := Vector3(to - from, top - bottom, GLASS_THICKNESS)
			if not across_x:
				size = Vector3(GLASS_THICKNESS, top - bottom, to - from)
			builder.add_box(center, size, glass_material())
		cursor = maxf(cursor, to)
	_segment(builder, start, along, across_x, cursor, length, 0.0, height, wall_mat)


static func _opening_before(a: Array, b: Array) -> bool:
	var a_from: float = a[0]
	var b_from: float = b[0]
	return a_from < b_from


static func _segment(
	builder: Builder,
	start: Vector3,
	along: Vector3,
	across_x: bool,
	from: float,
	to: float,
	bottom: float,
	top: float,
	mat: StandardMaterial3D
) -> void:
	if to - from <= 0.001 or top - bottom <= 0.001:
		return
	var center := start + along * ((from + to) * 0.5) + Vector3.UP * ((bottom + top) * 0.5)
	var size := Vector3(to - from, top - bottom, WALL_THICKNESS)
	if not across_x:
		size = Vector3(WALL_THICKNESS, top - bottom, to - from)
	builder.add_box(center, size, mat)

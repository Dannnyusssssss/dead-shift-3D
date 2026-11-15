class_name Kit
extends RefCounted
## Kit modular provisional (gris): forjados con huecos, techos, paredes con puertas y
## escaparates, cristal, escaleras, barandillas y bloques de decorado. Las piezas de una sala se
## funden en una sola malla por material para ahorrar llamadas de dibujo; las colisiones van por
## pieza. El arte final reemplazará estas mallas.

const WALL_THICKNESS: float = 0.2
const DOOR_HEIGHT: float = 2.3
const WINDOW_SILL: float = 0.9
const WINDOW_TOP: float = 2.6
const GLASS_THICKNESS: float = 0.04
## Grosor del suelo y del techo de cada sala (el resto del forjado queda oculto entre ambos).
const SLAB_THICKNESS: float = 0.1
## Barandillas: alto del cristal y del pasamanos, y frente de forjado bajo el suelo.
const RAIL_HEIGHT: float = 1.1
const FASCIA_DEPTH: float = 0.4
## Escaleras: alto de cada peldaño (aprox.), grosor de la losa y alto del pasamanos lateral.
const STEP_RISE: float = 0.2
const RAMP_THICKNESS: float = 0.25
const BALUSTRADE_HEIGHT: float = 1.0
## Hueco libre al pie y a la cabeza de cada pasamanos (para no tropezar al entrar de lado).
const RAIL_END_GAP: float = 0.4

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


## Gris de un tono dado (0 = negro, 1 = blanco).
static func gray(shade: float) -> StandardMaterial3D:
	var value := clampf(shade, 0.0, 1.0)
	return material(Color(value, value, value * 1.03))


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
		add_oriented_box(Transform3D(Basis.IDENTITY, center), size, mat, solid)

	## Caja con giro arbitrario (rampas, piezas inclinadas).
	func add_oriented_box(
		xform: Transform3D, size: Vector3, mat: StandardMaterial3D, solid: bool = true
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
		tool.append_from(box, 0, xform)
		if solid:
			_shapes.append([xform, size])

	func is_empty() -> bool:
		return _tools.is_empty()

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
			shape.transform = spec[0]
			body.add_child(shape)
		return body


## Trozos rectangulares de un rectángulo menos sus huecos (cuadrícula por los bordes de los
## huecos, con las celdas contiguas de cada fila unidas).
static func subtract_holes(rect: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var xs: Array[float] = [rect.position.x, rect.end.x]
	var zs: Array[float] = [rect.position.y, rect.end.y]
	var touching: Array[Rect2] = []
	for hole: Rect2 in holes:
		var clipped := rect.intersection(hole)
		if clipped.size.x <= 0.001 or clipped.size.y <= 0.001:
			continue
		touching.append(clipped)
		for x: float in [clipped.position.x, clipped.end.x]:
			if not xs.has(x):
				xs.append(x)
		for z: float in [clipped.position.y, clipped.end.y]:
			if not zs.has(z):
				zs.append(z)
	if touching.is_empty():
		return [rect]
	xs.sort()
	zs.sort()
	var pieces: Array[Rect2] = []
	for row: int in zs.size() - 1:
		var run_start := -1
		for column: int in xs.size():
			var inside := false
			if column < xs.size() - 1:
				var cell_center := Vector2(
					(xs[column] + xs[column + 1]) * 0.5, (zs[row] + zs[row + 1]) * 0.5
				)
				inside = true
				for hole: Rect2 in touching:
					if hole.has_point(cell_center):
						inside = false
						break
			if inside and run_start < 0:
				run_start = column
			elif not inside and run_start >= 0:
				var left: float = xs[run_start]
				var right: float = xs[column]
				var top: float = zs[row]
				var bottom: float = zs[row + 1]
				pieces.append(Rect2(left, top, right - left, bottom - top))
				run_start = -1
	return pieces


## Losa horizontal (suelo o techo) con su cara de arriba a la altura top.
static func add_slab(
	builder: Builder,
	rect: Rect2,
	holes: Array[Rect2],
	top: float,
	mat: StandardMaterial3D,
	solid: bool = true
) -> void:
	for piece: Rect2 in subtract_holes(rect, holes):
		var center := Vector3(
			piece.get_center().x, top - SLAB_THICKNESS * 0.5, piece.get_center().y
		)
		builder.add_box(center, Vector3(piece.size.x, SLAB_THICKNESS, piece.size.y), mat, solid)


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


## Escalera o escalera mecánica: losa inclinada sólida (por donde se camina), peldaños
## visuales, pasamanos laterales (y centrales si hay varios carriles; con panel de cristal en las
## mecánicas) y relleno escalonado debajo si nace en planta.
static func add_ramp(
	builder: Builder, spec: RampSpec, step_mat: StandardMaterial3D, side_mat: StandardMaterial3D
) -> void:
	var forward := spec.forward()
	var angle := atan2(spec.rise, spec.run)
	var slope := (forward * cos(angle) + Vector3.UP * sin(angle)).normalized()
	var normal := (-forward * sin(angle) + Vector3.UP * cos(angle)).normalized()
	var lateral := slope.cross(normal).normalized()
	var length := sqrt(spec.run * spec.run + spec.rise * spec.rise)
	var basis := Basis(slope, normal, lateral)
	var mid := spec.start + forward * (spec.run * 0.5) + Vector3.UP * (spec.rise * 0.5)
	builder.add_oriented_box(
		Transform3D(basis, mid - normal * (RAMP_THICKNESS * 0.5)),
		Vector3(length, RAMP_THICKNESS, spec.width),
		side_mat
	)
	# Peldaños: su borde coincide con la rampa a media huella (el pie nunca se hunde mucho).
	var steps := maxi(roundi(spec.rise / STEP_RISE), 2)
	var tread := spec.run / float(steps)
	var riser := spec.rise / float(steps)
	var flat := Basis(forward, Vector3.UP, forward.cross(Vector3.UP).normalized())
	for index: int in steps:
		var top := (float(index) + 0.5) * riser
		var center := (
			spec.start + forward * ((float(index) + 0.5) * tread) + Vector3.UP * (top - riser)
		)
		builder.add_oriented_box(
			Transform3D(flat, center),
			Vector3(tread, riser * 2.0, spec.width - 0.1),
			step_mat,
			false
		)
	var lanes := maxi(spec.lanes, 1)
	# Los pasamanos van inclinados: se acortan para que su canto no sobresalga del primer
	# peldaño (si no, el jugador tropieza con ellos al llegar de lado).
	var rail_length := maxf(length - 2.0 * tan(angle) * BALUSTRADE_HEIGHT - 2.0 * RAIL_END_GAP, 0.5)
	for index: int in lanes + 1:
		var offset := -spec.width * 0.5 + spec.width * float(index) / float(lanes)
		var rail_center := mid + normal * (BALUSTRADE_HEIGHT * 0.5) + lateral * offset
		# Escaleras mecánicas: panel de cristal sólido. Escaleras de servicio: solo pasamanos
		# (las paredes de la caja de escalera ya las cierran y el giro del descansillo queda libre).
		if spec.kind == RampSpec.KIND_ESCALATOR:
			builder.add_oriented_box(
				Transform3D(basis, rail_center),
				Vector3(rail_length, BALUSTRADE_HEIGHT, 0.1),
				glass_material()
			)
		builder.add_oriented_box(
			Transform3D(basis, rail_center + normal * (BALUSTRADE_HEIGHT * 0.5)),
			Vector3(rail_length, 0.08, 0.14),
			gray(0.5),
			false
		)
	if spec.fill_below:
		var segments := maxi(ceili(spec.run), 1)
		for index: int in segments:
			var height := spec.rise * float(index) / float(segments) - RAMP_THICKNESS
			if height <= 0.05:
				continue
			var along := (float(index) + 0.5) * spec.run / float(segments)
			var center := spec.start + forward * along + Vector3.UP * (height * 0.5)
			builder.add_oriented_box(
				Transform3D(flat, center),
				Vector3(spec.run / float(segments), height, spec.width),
				side_mat
			)


## Barandilla de cristal con pasamanos y frente de forjado debajo (tapa el canto del forjado).
static func add_rail(builder: Builder, base: Vector3, yaw_deg: float, length: float) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var glass_center := base + Vector3.UP * (RAIL_HEIGHT * 0.5)
	builder.add_oriented_box(
		Transform3D(basis, glass_center), Vector3(length, RAIL_HEIGHT, 0.06), glass_material()
	)
	builder.add_oriented_box(
		Transform3D(basis, base + Vector3.UP * RAIL_HEIGHT),
		Vector3(length, 0.07, 0.12),
		gray(0.55),
		false
	)
	builder.add_oriented_box(
		Transform3D(basis, base + Vector3.DOWN * (FASCIA_DEPTH * 0.5)),
		Vector3(length, FASCIA_DEPTH, 0.12),
		gray(0.7),
		false
	)


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

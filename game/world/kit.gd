class_name Kit
extends RefCounted
## Kit modular: forjados con huecos, techos, paredes con puertas y escaparates, cristal,
## escaleras, barandillas y bloques de decorado. Cada material del kit es una «pintura» (capa de
## textura y tono): todas las piezas pintadas de una sala se funden en una sola malla con el
## material de superficies (una llamada de dibujo); el cristal va aparte. Las colisiones van por
## pieza. La luz es por vértice: las piezas altas se oscurecen hacia el suelo.

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

## Oscurecimiento de las piezas altas al pie (luz por vértice) y altura en la que desaparece.
const FOOT_SHADE: float = 0.72
const FOOT_FADE_HEIGHT: float = 1.6
## Piezas a partir de esta altura reciben el oscurecimiento al pie.
const TALL_PIECE: float = 0.6

const SURFACE_SHADER: Shader = preload("res://game/world/surfaces.gdshader")
const SURFACE_LAYERS: TextureLayered = preload(
	"res://assets/generated/textures/surfaces_albedo.png"
)

static var _materials: Dictionary = {}
## Pintura de cada material del kit: color lineal en rgb y capa codificada en el alfa.
static var _paints: Dictionary = {}
static var _surface_material: ShaderMaterial = null
## Mallas de los modelos de decorado ya preparadas (capa PLAIN y luz por vértice), por nombre.
static var _models: Dictionary = {}


## Material mate compartido por color (se reutiliza entre salas).
static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = 0.95
	_materials[key] = made
	_paints[made] = paint_code(color, Surfaces.PLAIN)
	return made


## Material con textura: superficie de Surfaces.IDS con el tono dado (casi blanco; ver
## Surfaces.texture_tint). Un id desconocido queda sin textura.
static func surface(id: String, tint: Color) -> StandardMaterial3D:
	var key := "surface:" + id + ":" + tint.to_html()
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = tint
	made.roughness = 0.9
	_materials[key] = made
	_paints[made] = paint_code(tint, Surfaces.layer_of(id))
	return made


## Material que brilla con su color (paneles de luz, carteles): misma superficie compartida.
static func emissive(color: Color) -> StandardMaterial3D:
	var key := "emissive:" + color.to_html()
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.emission_enabled = true
	made.emission = color
	_materials[key] = made
	_paints[made] = paint_code(color, Surfaces.EMISSIVE)
	return made


## Color de vértice de una pintura: tono en lineal y capa en el alfa (centro del dieciseisavo).
static func paint_code(color: Color, layer: int) -> Color:
	var linear := color.srgb_to_linear()
	return Color(linear.r, linear.g, linear.b, (float(layer) + 0.5) / float(Surfaces.MAX_LAYERS))


## Si el material es una pintura del kit (va a la superficie compartida).
static func is_paint(mat: Material) -> bool:
	return _paints.has(mat)


static func paint_of(mat: Material) -> Color:
	return _paints[mat]


## Ruta del modelo de decorado generado por tools/blender/props.py.
static func model_path(model_id: String) -> String:
	return "res://assets/generated/props/%s.glb" % model_id


## Malla de un modelo de decorado lista para fundirse con la sala: su color de vértice pasa a
## pintura sin textura (capa PLAIN) con la luz por vértice. null si el modelo no existe.
static func model_mesh(model_id: String) -> ArrayMesh:
	if _models.has(model_id):
		return _models[model_id]
	var path := model_path(model_id)
	var prepared: ArrayMesh = null
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		var root := scene.instantiate()
		var source := _first_mesh(root)
		if source != null:
			prepared = _prepare_model(source.mesh)
		root.free()
	_models[model_id] = prepared
	return prepared


static func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child: Node in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


static func _prepare_model(source: Mesh) -> ArrayMesh:
	var prepared := ArrayMesh.new()
	var alpha := (float(Surfaces.PLAIN) + 0.5) / float(Surfaces.MAX_LAYERS)
	for surface: int in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if colors.size() != vertices.size():
			colors.resize(vertices.size())
			colors.fill(Color(0.5, 0.5, 0.5))
		for i: int in vertices.size():
			var shade := lerpf(FOOT_SHADE, 1.0, clampf(vertices[i].y / FOOT_FADE_HEIGHT, 0.0, 1.0))
			var c := colors[i]
			colors[i] = Color(c.r * shade, c.g * shade, c.b * shade, alpha)
		var clean: Array = []
		clean.resize(Mesh.ARRAY_MAX)
		clean[Mesh.ARRAY_VERTEX] = vertices
		clean[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
		clean[Mesh.ARRAY_COLOR] = colors
		clean[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		prepared.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, clean)
	return prepared


## Material compartido de todas las piezas pintadas.
static func surface_material() -> ShaderMaterial:
	if _surface_material == null:
		_surface_material = ShaderMaterial.new()
		_surface_material.shader = SURFACE_SHADER
		_surface_material.set_shader_parameter("layers", SURFACE_LAYERS)
		_surface_material.set_shader_parameter("tile_meters", Surfaces.tile_table())
	return _surface_material


## Gris de un tono dado (0 = negro, 1 = blanco).
static func gray(shade: float) -> StandardMaterial3D:
	var value := clampf(shade, 0.0, 1.0)
	return material(Color(value, value, value * 1.03))


## Color de un gris (el mismo tono que gray(), para los bloques con color de vértice).
static func gray_color(shade: float) -> Color:
	var value := clampf(shade, 0.0, 1.0)
	return Color(value, value, value * 1.03)


## Trozos de cristal en el suelo (opacos y claros, para que se vean sin destellos).
static func shard_material() -> StandardMaterial3D:
	var key := "shards"
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = Color(0.72, 0.8, 0.82)
	made.roughness = 0.25
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


## Acumulador de cajas: una malla por material y colisiones por caja. Las cajas se guardan y se
## convierten en malla al final (build), después de separar las caras que coinciden: si dos
## cajas tienen una cara en el mismo plano, mirando al mismo lado y solapada, la más pequeña la
## retrasa unos milímetros. Sin eso, cuál de las dos se veía dependía del ángulo de la cámara
## (marcos, barandillas y escaleras que cambiaban entre dos encuadres casi iguales).
class Builder:
	extends RefCounted
	## Cuánto se retrasa la cara de la caja pequeña y área mínima de solape que se corrige (m²).
	const COPLANAR_RECESS: float = 0.004
	const MIN_OVERLAP: float = 0.0001
	## Distancia entre planos que todavía se considera el mismo plano, y pasos de retraso máximos.
	const PLANE_TOLERANCE: float = 0.0015
	const MAX_RECESS_STEPS: int = 4
	var _tools: Dictionary = {}
	var _shapes: Array[Array] = []
	## Cajas pendientes: [transform, tamaño, material (null si es pintada), código de pintura].
	var _boxes: Array[Array] = []

	## Cara de una caja alineada con un eje del mundo (para separar las coincidentes).
	class Face:
		extends RefCounted
		var box: int = 0
		var local: int = 0
		var side: int = 1
		var outline: PackedVector2Array = PackedVector2Array()
		var plane: float = 0.0
		var volume: float = 0.0
		## Pasos de retraso asignados (-1 = sin recorrer todavía).
		var depth: int = -1
		var touching: Array[Face] = []

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
		if Kit.is_paint(mat):
			_add_painted(xform, size, Kit.paint_of(mat), solid)
			return
		_boxes.append([xform, size, mat, Color()])
		if solid:
			_shapes.append([xform, size])

	## Caja de decorado con su color en los vértices (comparte superficie con las demás).
	func add_colored_box(
		xform: Transform3D, size: Vector3, color: Color, solid: bool = true
	) -> void:
		if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
			return
		_add_painted(xform, size, Kit.paint_code(color, Surfaces.PLAIN), solid)

	## Caja pintada: tono y capa en el color de cada vértice (se convierte en malla en build).
	func _add_painted(xform: Transform3D, size: Vector3, code: Color, solid: bool) -> void:
		_boxes.append([xform, size, null, code])
		if solid:
			_shapes.append([xform, size])

	func _tool_for(mat: Material) -> SurfaceTool:
		var tool: SurfaceTool = _tools.get(mat)
		if tool == null:
			tool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(mat)
			_tools[mat] = tool
		return tool

	## Caja con material propio.
	func _emit_plain(xform: Transform3D, size: Vector3, mat: Material) -> void:
		var box := BoxMesh.new()
		box.size = size
		_tool_for(mat).append_from(box, 0, xform)

	## Caja pintada con la luz por vértice (las piezas altas se oscurecen hacia el suelo).
	func _emit_painted(xform: Transform3D, size: Vector3, code: Color) -> void:
		var box := BoxMesh.new()
		box.size = size
		var arrays := box.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		var tall := size.y >= TALL_PIECE
		for i: int in vertices.size():
			var shade := 1.0
			if tall:
				var height := (xform * vertices[i]).y
				shade = lerpf(FOOT_SHADE, 1.0, clampf(height / FOOT_FADE_HEIGHT, 0.0, 1.0))
			colors[i] = Color(code.r * shade, code.g * shade, code.b * shade, code.a)
		arrays[Mesh.ARRAY_COLOR] = colors
		var painted := ArrayMesh.new()
		painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_tool_for(Kit.surface_material()).append_from(painted, 0, xform)

	## Separa las caras coincidentes. Junta las caras alineadas con los ejes por eje y sentido,
	## las ordena por plano y compara las que distan menos de PLANE_TOLERANCE. Después recorre las
	## cajas de mayor a menor volumen: cada cara solapada con una ya recorrida se retrasa un paso
	## más que ella (así una fila de piezas iguales encadenadas tampoco coincide entre sí).
	func resolve_coplanar() -> void:
		var groups: Dictionary = {}
		for index: int in _boxes.size():
			var xform: Transform3D = _boxes[index][0]
			var size: Vector3 = _boxes[index][1]
			for local: int in 3:
				var direction := xform.basis[local].normalized()
				var axis := -1
				for world: int in 3:
					if absf(direction[world]) > 0.999:
						axis = world
				if axis < 0:
					continue
				for side: int in [-1, 1]:
					var normal := direction * float(side)
					var center := xform.origin + normal * size[local] * 0.5
					var key := "%d|%d" % [axis, signi(roundi(normal[axis]))]
					if not groups.has(key):
						groups[key] = [] as Array[Face]
					var face := Face.new()
					face.box = index
					face.local = local
					face.side = side
					face.outline = _face_polygon(xform, size, local, center, axis)
					face.plane = center[axis]
					face.volume = size.x * size.y * size.z
					(groups[key] as Array[Face]).append(face)
		for key: String in groups:
			var faces: Array[Face] = groups[key]
			_resolve_group(faces)

	func _resolve_group(faces: Array[Face]) -> void:
		faces.sort_custom(func(a: Face, b: Face) -> bool: return a.plane < b.plane)
		# Parejas solapadas en el mismo plano (con tolerancia).
		var any := false
		for i: int in faces.size():
			var first := faces[i]
			for j: int in range(i + 1, faces.size()):
				var second := faces[j]
				if second.plane - first.plane > PLANE_TOLERANCE:
					break
				if first.box == second.box:
					continue
				if _overlap_area(first.outline, second.outline) < MIN_OVERLAP:
					continue
				first.touching.append(second)
				second.touching.append(first)
				any = true
		if not any:
			return
		# De mayor a menor volumen (a igual volumen, por orden de llegada).
		var order: Array[Face] = []
		for face: Face in faces:
			if not face.touching.is_empty():
				order.append(face)
		order.sort_custom(
			func(a: Face, b: Face) -> bool:
				if not is_equal_approx(a.volume, b.volume):
					return a.volume > b.volume
				return a.box < b.box
		)
		for face: Face in order:
			var steps := 0
			for other: Face in face.touching:
				if other.depth >= 0:
					steps = maxi(steps, other.depth + 1)
			face.depth = mini(steps, MAX_RECESS_STEPS)
			if face.depth > 0:
				_recess_face(face, COPLANAR_RECESS * float(face.depth))
		# Las caras se apuntan entre sí: se rompen los ciclos para que se liberen.
		for face: Face in order:
			face.touching.clear()

	## Retrasa una cara (la caja encoge por ese lado) sin dejarla más fina de un tercio.
	func _recess_face(face: Face, amount: float) -> void:
		var xform: Transform3D = _boxes[face.box][0]
		var size: Vector3 = _boxes[face.box][1]
		var applied := minf(amount, size[face.local] / 3.0)
		size[face.local] -= applied
		xform.origin -= xform.basis[face.local].normalized() * float(face.side) * applied * 0.5
		_boxes[face.box][0] = xform
		_boxes[face.box][1] = size

	## Contorno de una cara en los dos ejes del mundo distintos de su normal.
	func _face_polygon(
		xform: Transform3D, size: Vector3, local: int, center: Vector3, axis: int
	) -> PackedVector2Array:
		var first := (local + 1) % 3
		var second := (local + 2) % 3
		var edge_a := xform.basis[first].normalized() * size[first] * 0.5
		var edge_b := xform.basis[second].normalized() * size[second] * 0.5
		var u := (axis + 1) % 3
		var w := (axis + 2) % 3
		var polygon := PackedVector2Array()
		for corner: Vector3 in [
			center - edge_a - edge_b,
			center + edge_a - edge_b,
			center + edge_a + edge_b,
			center - edge_a + edge_b
		]:
			polygon.append(Vector2(corner[u], corner[w]))
		return polygon

	static func _overlap_area(first: PackedVector2Array, second: PackedVector2Array) -> float:
		var box_a := Rect2(first[0], Vector2.ZERO)
		for point: Vector2 in first:
			box_a = box_a.expand(point)
		var box_b := Rect2(second[0], Vector2.ZERO)
		for point: Vector2 in second:
			box_b = box_b.expand(point)
		if not box_a.intersects(box_b):
			return 0.0
		var area := 0.0
		for polygon: PackedVector2Array in Geometry2D.intersect_polygons(first, second):
			var twice := 0.0
			for i: int in polygon.size():
				twice += polygon[i].cross(polygon[(i + 1) % polygon.size()])
			area += absf(twice) * 0.5
		return area

	## Colisión de caja sin malla (la forma visible la pone un modelo).
	func add_collision(xform: Transform3D, size: Vector3) -> void:
		if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
			return
		_shapes.append([xform, size])

	## Modelo de decorado (sin colisión) fundido con la superficie pintada de la sala.
	## Devuelve false si el modelo no existe.
	func add_model(xform: Transform3D, model_id: String) -> bool:
		var mesh := Kit.model_mesh(model_id)
		if mesh == null:
			return false
		var tool := _tool_for(Kit.surface_material())
		for surface: int in mesh.get_surface_count():
			tool.append_from(mesh, surface, xform)
		return true

	func is_empty() -> bool:
		return _tools.is_empty() and _boxes.is_empty()

	## Crea el cuerpo estático con todas las mallas y colisiones acumuladas.
	func build(name: String) -> StaticBody3D:
		var body := StaticBody3D.new()
		body.name = name
		body.collision_layer = Rules.LAYER_WORLD
		body.collision_mask = 0
		resolve_coplanar()
		for box: Array in _boxes:
			var xform: Transform3D = box[0]
			var size: Vector3 = box[1]
			var mat: Material = box[2]
			if mat == null:
				var code: Color = box[3]
				_emit_painted(xform, size, code)
			else:
				_emit_plain(xform, size, mat)
		_boxes.clear()
		for mat: Material in _tools:
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
## Cada abertura es [desde, hasta, abajo, arriba, cristal] medida a lo largo de la pared. Con
## «panes», los cristales van a ese grupo (se pueden romper) en vez de a la malla de la sala.
static func add_wall(
	builder: Builder,
	start: Vector3,
	end: Vector3,
	height: float,
	openings: Array[Array],
	wall_mat: StandardMaterial3D,
	panes: GlassPanes = null
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
			if panes != null:
				panes.add_pane(center, size)
			else:
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

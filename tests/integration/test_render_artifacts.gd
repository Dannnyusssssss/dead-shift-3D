extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Rayas y parpadeos del edificio: dos superficies de mallas distintas en el mismo plano y
## solapadas se pelean por el mismo píxel (cambia cuál se ve según la cámara), y una malla con
## más luces de las que el render admite por objeto pierde algunas según el encuadre.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")
## Distancia entre planos que todavía se considera el mismo plano (m) y solape mínimo (m²).
const PLANE_TOLERANCE: float = 0.002
const MIN_OVERLAP: float = 0.05
## Tope de luces por objeto aceptado (project.godot); más luces cuestan en el celular.
const MAX_LIGHTS_PER_OBJECT: int = 12
## Parte de una cara tapada por otra en contacto a partir de la cual ya no se ve.
const HIDDEN_SHARE: float = 0.9

var _game: Game


func before_each() -> void:
	GameState.forced_seed = 5
	_game = GAME_SCRIPT.new()
	add_child_autofree(_game)
	await wait_physics_frames(3)


func after_each() -> void:
	GameState.forced_seed = -1
	InputRouter.gameplay_active = false
	InputRouter.release_capture()


## Ninguna malla del edificio recibe más luces que las que el render dibuja por objeto.
func test_no_mesh_exceeds_lights_per_object() -> void:
	var limit: int = ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object", 8)
	# El tope del proyecto no se sube a escondidas para que esta prueba pase.
	assert_lte(limit, MAX_LIGHTS_PER_OBJECT, "tope de luces por objeto del proyecto")
	for section: FloorSection in _game.level.sections:
		var lights: Array[OmniLight3D] = []
		for node: Node in _game.level.find_children("*", "OmniLight3D", true, false):
			var light := node as OmniLight3D
			if light.light_cull_mask & section.visual_layer():
				lights.append(light)
		for node: Node in section.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var box := mesh.global_transform * mesh.get_aabb()
			var hits: Array[String] = []
			for light: OmniLight3D in lights:
				if _sphere_hits_box(light.global_position, light.omni_range, box):
					hits.append("%s r=%.1f" % [light.global_position, light.omni_range])
			assert_lte(
				hits.size(),
				limit,
				"%s: %d luces: %s" % [_describe(mesh), hits.size(), ", ".join(hits)]
			)


## Ninguna cara alineada con un eje coincide con otra del mismo piso, de la misma malla o de
## otra: mismo plano, mismo sentido y solapadas en un área que se ve (MIN_OVERLAP). Las caras
## pegadas a otra superficie (la base de un mueble en el suelo, la trasera de un espejo en la
## pared) no se ven y no cuentan.
func test_no_coplanar_faces_between_meshes() -> void:
	for section: FloorSection in _game.level.sections:
		var groups: Dictionary = {}
		var meshes := section.find_children("*", "MeshInstance3D", true, false)
		for mesh_index: int in meshes.size():
			var mesh := meshes[mesh_index] as MeshInstance3D
			if mesh.mesh == null or not mesh.is_visible_in_tree():
				continue
			_collect_faces(mesh, mesh_index, groups)
		for key: String in groups:
			(groups[key] as Array).sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
		_mark_hidden(groups)
		# Área solapada por pareja de mallas y plano (los triángulos de una caja se suman).
		var totals: Dictionary = {}
		for key: String in groups:
			var faces: Array = groups[key]
			for i: int in faces.size():
				var a: Array = faces[i]
				if a[3]:
					continue
				for j: int in range(i + 1, faces.size()):
					var b: Array = faces[j]
					if float(b[1]) - float(a[1]) > PLANE_TOLERANCE:
						break
					if b[3]:
						continue
					var area := _overlap(a[2], b[2])
					if area <= 0.0:
						continue
					var pair := (
						"%s y %s, plano %s %.2f"
						% [
							_describe(meshes[mini(a[0], b[0])]),
							_describe(meshes[maxi(a[0], b[0])]),
							key,
							a[1]
						]
					)
					var point: Vector2 = (a[2] as PackedVector2Array)[0]
					var previous: Array = totals.get(pair, [0.0, point])
					totals[pair] = [float(previous[0]) + area, previous[1]]
		for pair: String in totals:
			var total: Array = totals[pair]
			assert_lt(
				float(total[0]),
				MIN_OVERLAP,
				"%s: %s (cerca de %s)" % [section.name, pair, total[1]]
			)


## Marca como ocultas (cuarto valor) las caras tapadas casi del todo por otra que mira en
## sentido contrario en el mismo plano: están en contacto y no se ven.
func _mark_hidden(groups: Dictionary) -> void:
	for key: String in groups:
		var opposite_key := key[0] + ("-" if key[1] == "+" else "+")
		if not groups.has(opposite_key):
			continue
		var opposite: Array = groups[opposite_key]
		for face: Array in groups[key]:
			var own := _overlap(face[2], face[2])
			if own <= 0.0:
				continue
			var plane: float = face[1]
			var start := opposite.bsearch_custom(
				plane - PLANE_TOLERANCE,
				func(entry: Array, value: float) -> bool: return entry[1] < value
			)
			var covered := 0.0
			for index: int in range(start, opposite.size()):
				var other: Array = opposite[index]
				if float(other[1]) > plane + PLANE_TOLERANCE:
					break
				covered += _overlap(face[2], other[2])
			face[3] = covered >= own * HIDDEN_SHARE


## Junta los triángulos alineados con un eje del mundo por eje y sentido:
## [malla, plano, triángulo en los otros dos ejes, oculta].
func _collect_faces(mesh: MeshInstance3D, mesh_index: int, groups: Dictionary) -> void:
	var xform := mesh.global_transform
	for surface: int in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		)
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for t: int in range(0, count - 2, 3):
			var p0 := xform * vertices[indices[t] if not indices.is_empty() else t]
			var p1 := xform * vertices[indices[t + 1] if not indices.is_empty() else t + 1]
			var p2 := xform * vertices[indices[t + 2] if not indices.is_empty() else t + 2]
			# En Godot la cara delantera va en sentido horario: su normal es (p2 - p0) x (p1 - p0).
			var normal := (p2 - p0).cross(p1 - p0)
			if normal.length() < 0.000001:
				continue
			normal = normal.normalized()
			for axis: int in 3:
				if absf(normal[axis]) < 0.999:
					continue
				var u := (axis + 1) % 3
				var w := (axis + 2) % 3
				var key := "xyz"[axis] + ("+" if normal[axis] > 0.0 else "-")
				if not groups.has(key):
					groups[key] = []
				(groups[key] as Array).append(
					[
						mesh_index,
						p0[axis],
						PackedVector2Array(
							[Vector2(p0[u], p0[w]), Vector2(p1[u], p1[w]), Vector2(p2[u], p2[w])]
						),
						false
					]
				)


## Nombre legible de una malla: la clase con script más cercana y su sala o nombre.
func _describe(node: Node) -> String:
	var current := node
	while current != null:
		var script := current.get_script() as Script
		if script != null and not script.get_global_name().is_empty():
			return "%s(%s)" % [script.get_global_name(), current.name]
		if current.get_parent() is FloorSection:
			return "sala %s" % current.name
		current = current.get_parent()
	return String(node.get_path())


func _overlap(first: PackedVector2Array, second: PackedVector2Array) -> float:
	var area := 0.0
	for polygon: PackedVector2Array in Geometry2D.intersect_polygons(first, second):
		var twice := 0.0
		for i: int in polygon.size():
			twice += polygon[i].cross(polygon[(i + 1) % polygon.size()])
		area += absf(twice) * 0.5
	return area


## El render empareja luces y mallas por sus cajas (la de la luz es el cubo de su alcance), no
## por la esfera: se cuenta igual para no quedarse corto.
func _sphere_hits_box(center: Vector3, radius: float, box: AABB) -> bool:
	var light_box := AABB(center - Vector3.ONE * radius, Vector3.ONE * radius * 2.0)
	return light_box.intersects(box)

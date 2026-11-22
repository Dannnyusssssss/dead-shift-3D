extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Distribución de los pisos: el decorado no tapa puertas ni deja pasos a medias.

## Paso libre mínimo (m) entre dos piezas sólidas: el jugador mide 0,7 m de ancho.
const MIN_PASSAGE: float = 1.0
## Por debajo de esto la rendija ya se ve cerrada y nadie intenta pasar (m).
const MIN_VISIBLE_GAP: float = 0.4
## Una rendija con su centro a menos de esto de una pared es un rincón sin salida, no un paso.
const WALL_MARGIN: float = 1.2
## Distancia máxima (m) del centro de un modelo a los bloques de colisión que lo forman.
const MODEL_REACH: float = 2.5
## Altura mínima de la parte de arriba de un bloque para cortar el paso, y altura máxima de su
## base (lo que cuelga del techo no cuenta).
const SOLID_MIN_TOP: float = 0.3
const SOLID_MAX_BASE: float = 1.0


## Ningún bloque de decorado apoyado en el suelo tapa una puerta (ni 0,5 m delante o detrás):
## un mostrador o el marco del ascensor encima de una puerta deja al bot y al jugador sin paso.
func test_decoration_never_blocks_a_door() -> void:
	for floor_data: FloorData in GameState.CATALOG.floors:
		for room: RoomData in floor_data.rooms:
			for door: DoorSpec in room.doors:
				var zone := _door_zone(room.rect, door)
				for prop: PropSpec in floor_data.props:
					if prop.kind != PropSpec.KIND_BLOCK or prop.position.y > 2.0:
						continue
					assert_false(
						zone.intersects(_footprint(prop)),
						(
							"%s: un bloque en %s tapa una puerta de %s"
							% [floor_data.id, prop.position, room.id]
						)
					)


## Rectángulo (x, z) del hueco de una puerta, ampliado 0,5 m a cada lado de la pared.
func _door_zone(rect: Rect2, door: DoorSpec) -> Rect2:
	var depth := 0.5
	match door.side:
		DoorSpec.SIDE_NORTH, DoorSpec.SIDE_SOUTH:
			var z := rect.position.y if door.side == DoorSpec.SIDE_NORTH else rect.end.y
			return Rect2(
				rect.position.x + door.offset - door.width * 0.5, z - depth, door.width, depth * 2.0
			)
		_:
			var x := rect.position.x if door.side == DoorSpec.SIDE_WEST else rect.end.x
			return Rect2(
				x - depth, rect.position.y + door.offset - door.width * 0.5, depth * 2.0, door.width
			)


## Huella (x, z) de un bloque girado sobre el eje vertical (caja que lo contiene).
func _footprint(prop: PropSpec) -> Rect2:
	var angle := deg_to_rad(prop.rotation_deg)
	var half := (
		Vector2(
			absf(cos(angle)) * prop.size.x + absf(sin(angle)) * prop.size.z,
			absf(sin(angle)) * prop.size.x + absf(cos(angle)) * prop.size.z
		)
		* 0.5
	)
	var center := Vector2(prop.position.x, prop.position.z)
	return Rect2(center - half, half * 2.0)


## Entre dos piezas sólidas apoyadas en el suelo no quedan rendijas que parecen un paso y no lo
## son: si entre ellas queda hueco a la vista (más de MIN_VISIBLE_GAP) tiene que caber el
## jugador con holgura (MIN_PASSAGE). No cuenta si el centro de la rendija está a menos de
## WALL_MARGIN de una pared (rincón contra la pared, sin salida), si las piezas se tocan ni
## entre los bloques de colisión de un mismo modelo (las sillas de una mesa, por ejemplo): cada
## bloque invisible pertenece al modelo más cercano.
func test_furniture_leaves_real_passages() -> void:
	var checked := 0
	for floor_data: FloorData in GameState.CATALOG.floors:
		var solids: Array[PackedVector2Array] = []
		var owners: Array[int] = []
		for prop: PropSpec in floor_data.props:
			if _is_floor_solid(prop):
				solids.append(_corners(prop))
				owners.append(_owner_model(floor_data, prop))
		# Lo que está encima o dentro de otro mueble (frascos en una estantería) no cuenta.
		var inside: Array[bool] = []
		for a: int in solids.size():
			inside.append(_contained(solids, a))
		for a: int in solids.size():
			for b: int in range(a + 1, solids.size()):
				if owners[a] >= 0 and owners[a] == owners[b]:
					continue
				if inside[a] or inside[b]:
					continue
				var gap := _gap(solids[a], solids[b])
				if gap.is_empty():
					continue
				checked += 1
				var width: float = gap[0]
				var middle: Vector2 = gap[1]
				if width <= MIN_VISIBLE_GAP or width >= MIN_PASSAGE:
					continue
				if _near_wall(floor_data, middle):
					continue
				fail_test(
					(
						"%s: entre dos piezas junto a (%.1f, %.1f) quedan %.2f m (ni cerrado ni paso)"
						% [floor_data.id, middle.x, middle.y, width]
					)
				)
	assert_gt(checked, 50, "parejas de piezas revisadas")


func _is_floor_solid(prop: PropSpec) -> bool:
	var kinds := [PropSpec.KIND_BLOCK, PropSpec.KIND_SHELF, PropSpec.KIND_PANEL, PropSpec.KIND_RAIL]
	if not prop.kind in kinds:
		return false
	return prop.position.y <= SOLID_MAX_BASE and prop.position.y + prop.size.y >= SOLID_MIN_TOP


## Si la huella index queda entera dentro de la de otra pieza (con 1 cm de margen).
func _contained(solids: Array[PackedVector2Array], index: int) -> bool:
	for other: int in solids.size():
		if other == index:
			continue
		var grown := Geometry2D.offset_polygon(solids[other], 0.01)
		if grown.is_empty():
			continue
		var all_in := true
		for point: Vector2 in solids[index]:
			if not Geometry2D.is_point_in_polygon(point, grown[0]):
				all_in = false
				break
		if all_in:
			return true
	return false


## Índice del modelo al que pertenece un bloque de colisión invisible (el más cercano), o -1.
func _owner_model(floor_data: FloorData, prop: PropSpec) -> int:
	if not prop.collision_only:
		return -1
	var best := -1
	var best_distance := MODEL_REACH
	for index: int in floor_data.props.size():
		var model := floor_data.props[index]
		if model.kind != PropSpec.KIND_MODEL:
			continue
		var distance := (
			Vector2(model.position.x - prop.position.x, model.position.z - prop.position.z).length()
		)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


## Esquinas (x, z) de un bloque girado sobre el eje vertical.
func _corners(prop: PropSpec) -> PackedVector2Array:
	var basis := Basis(Vector3.UP, deg_to_rad(prop.rotation_deg))
	var result := PackedVector2Array()
	for sign_pair: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var local := Vector3(sign_pair.x * prop.size.x, 0.0, sign_pair.y * prop.size.z) * 0.5
		var world := prop.position + basis * local
		result.append(Vector2(world.x, world.z))
	return result


## [distancia, punto medio] entre dos huellas que no se tocan; vacío si se tocan o están lejos.
func _gap(a: PackedVector2Array, b: PackedVector2Array) -> Array:
	if not Geometry2D.intersect_polygons(a, b).is_empty():
		return []
	var best := INF
	var middle := Vector2.ZERO
	for i: int in a.size():
		for j: int in b.size():
			var points := Geometry2D.get_closest_points_between_segments(
				a[i], a[(i + 1) % a.size()], b[j], b[(j + 1) % b.size()]
			)
			var distance := points[0].distance_to(points[1])
			if distance < best:
				best = distance
				middle = (points[0] + points[1]) * 0.5
	if best < 0.01 or best > MIN_PASSAGE * 2.0:
		return []
	return [best, middle]


## Si el punto está a menos de WALL_MARGIN de una pared cerrada de cualquier sala (los lados
## abiertos de los pasillos no cuentan; las paredes de las tiendas sí, aunque el punto esté en
## el pasillo).
func _near_wall(floor_data: FloorData, point: Vector2) -> bool:
	for room: RoomData in floor_data.rooms:
		var rect := room.rect
		var corners := [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]
		# Lado y sus dos esquinas: norte, este, sur y oeste.
		var sides := [
			[DoorSpec.SIDE_NORTH, 0, 1],
			[DoorSpec.SIDE_EAST, 1, 2],
			[DoorSpec.SIDE_SOUTH, 2, 3],
			[DoorSpec.SIDE_WEST, 3, 0],
		]
		for side: Array in sides:
			if room.open_sides & (1 << int(side[0])) != 0:
				continue
			var a: Vector2 = corners[int(side[1])]
			var b: Vector2 = corners[int(side[2])]
			var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
			if closest.distance_to(point) < WALL_MARGIN:
				return true
	return false

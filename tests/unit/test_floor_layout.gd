extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Distribución de los pisos: el decorado no tapa puertas.


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

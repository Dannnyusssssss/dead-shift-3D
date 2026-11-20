extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Colocación del edificio construido: los rótulos están pegados a una superficie (no flotan en
## el aire) y el botín no queda metido en otra pieza ni en el paso de puertas, ascensores o
## escaleras. Se comprueba con la física de la escena, así vale para cualquier pieza.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")
## Hasta dónde detrás de un rótulo tiene que haber una superficie (m).
const SIGN_BACKING: float = 0.05
## Espacio libre delante de puertas, ascensores y extremos de escaleras (m).
const CLEARANCE: float = 1.0
## Radio de la consulta de solape del botín y altura de su centro sobre el suelo (m).
const LOOT_PROBE_RADIUS: float = 0.12
const LOOT_PROBE_HEIGHT: float = 0.3

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


## Detrás de cada rótulo del edificio (a SIGN_BACKING como mucho) hay una superficie visible:
## pared, placa o pieza. Se mira la geometría que se dibuja (las placas no tienen colisión).
func test_signs_are_mounted_on_a_surface() -> void:
	var checked := 0
	for section: FloorSection in _game.level.sections:
		var meshes: Array[MeshInstance3D] = []
		for node: Node in section.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			# También los pisos inactivos, que están ocultos hasta que el jugador se acerca.
			if mesh.mesh != null:
				meshes.append(mesh)
		for node: Node in section.find_children("*", "Label3D", true, false):
			var label := node as Label3D
			if label.billboard != BaseMaterial3D.BILLBOARD_DISABLED or not label.visible:
				continue
			# El texto se lee desde +Z de la etiqueta: la superficie va detrás, hacia -Z.
			var back := -label.global_transform.basis.z.normalized()
			var from := label.global_position - back * 0.01
			var to := label.global_position + back * SIGN_BACKING
			checked += 1
			assert_true(
				_segment_hits(meshes, from, to),
				(
					"%s: el rótulo «%s» en %s flota (nada detrás)"
					% [section.name, label.text.replace(char(10), " "), label.global_position]
				)
			)
	assert_gt(checked, 10, "rótulos revisados")


## Si el segmento toca algún triángulo de esas mallas.
func _segment_hits(meshes: Array[MeshInstance3D], from: Vector3, to: Vector3) -> bool:
	for mesh: MeshInstance3D in meshes:
		var box := (mesh.global_transform * mesh.get_aabb()).grow(0.01)
		if not box.intersects_segment(from, to):
			continue
		var local_from := mesh.global_transform.affine_inverse() * from
		var local_to := mesh.global_transform.affine_inverse() * to
		for surface: int in mesh.mesh.get_surface_count():
			var faces := (mesh.mesh as Mesh).get_faces()
			for t: int in range(0, faces.size() - 2, 3):
				if (
					Geometry3D.segment_intersects_triangle(
						local_from, local_to, faces[t], faces[t + 1], faces[t + 2]
					)
					!= null
				):
					return true
			break
	return false


## Ningún objeto suelto queda metido dentro de otra pieza del edificio.
func test_pickups_are_not_inside_other_pieces() -> void:
	var space := _space()
	var sphere := SphereShape3D.new()
	sphere.radius = LOOT_PROBE_RADIUS
	for section: FloorSection in _game.level.sections:
		for node: Node in section.find_children("*", "Pickup", true, false):
			var pickup := node as Pickup
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = sphere
			query.collision_mask = Rules.LAYER_WORLD
			query.transform = Transform3D(
				Basis.IDENTITY, pickup.global_position + Vector3.UP * LOOT_PROBE_HEIGHT
			)
			var hits: Array[Dictionary] = space.intersect_shape(query, 4)
			assert_eq(
				hits.size(),
				0,
				(
					"%s: %s en %s está dentro de otra pieza"
					% [section.name, pickup.item_id, _local(pickup)]
				)
			)


## Ningún objeto suelto ni contenedor queda en el paso: a CLEARANCE de una puerta, del frente o
## los lados de un ascensor o del extremo de una escalera.
func test_loot_leaves_passages_clear() -> void:
	for section: FloorSection in _game.level.sections:
		var zones := _passage_zones(section.floor_data)
		for node: Node in section.find_children("*", "Interactable", true, false):
			if not (node is Pickup or node is LootContainer):
				continue
			var spot := _local(node as Node3D)
			var point := Vector2(spot.x, spot.z)
			for zone: Array in zones:
				assert_false(
					(zone[1] as Rect2).has_point(point),
					"%s: botín en %s en el paso de %s" % [section.name, spot, zone[0]]
				)


## Zonas que tienen que quedar libres, en coordenadas del piso: [nombre, Rect2 (x, z)].
func _passage_zones(floor_data: FloorData) -> Array[Array]:
	var zones: Array[Array] = []
	for room: RoomData in floor_data.rooms:
		for door: DoorSpec in room.doors:
			zones.append(["la puerta de %s" % room.id, _door_zone(room.rect, door)])
	for prop: PropSpec in floor_data.props:
		if prop.kind == PropSpec.KIND_MODEL and prop.text_key == "elevator":
			# El ascensor: su bloque de colisión está en el mismo sitio; se usa su huella.
			for block: PropSpec in floor_data.props:
				if block.kind == PropSpec.KIND_BLOCK and block.position == prop.position:
					zones.append(["el ascensor", _footprint(block).grow(CLEARANCE)])
	for ramp: RampSpec in floor_data.ramps:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(ramp.direction_deg))
		for end: Vector3 in [
			ramp.start, ramp.start + direction * ramp.run + Vector3.UP * ramp.rise
		]:
			# Solo los extremos a la altura del suelo de este piso (un tramo que llega a un
			# rellano o al piso de arriba no ocupa el suelo de aquí).
			if absf(end.y) > 0.3:
				continue
			var half := ramp.width * 0.5 + CLEARANCE
			zones.append(
				[
					"una escalera",
					Rect2(Vector2(end.x - half, end.z - half), Vector2(half, half) * 2.0)
				]
			)
	return zones


## Rectángulo (x, z) del hueco de una puerta, ampliado CLEARANCE a cada lado de la pared.
func _door_zone(rect: Rect2, door: DoorSpec) -> Rect2:
	match door.side:
		DoorSpec.SIDE_NORTH, DoorSpec.SIDE_SOUTH:
			var z := rect.position.y if door.side == DoorSpec.SIDE_NORTH else rect.end.y
			return Rect2(
				rect.position.x + door.offset - door.width * 0.5,
				z - CLEARANCE,
				door.width,
				CLEARANCE * 2.0
			)
		_:
			var x := rect.position.x if door.side == DoorSpec.SIDE_WEST else rect.end.x
			return Rect2(
				x - CLEARANCE,
				rect.position.y + door.offset - door.width * 0.5,
				CLEARANCE * 2.0,
				door.width
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


## Posición de un nodo en coordenadas de su piso.
func _local(node: Node3D) -> Vector3:
	var section := node.get_parent()
	while section != null and not section is FloorSection:
		section = section.get_parent()
	return (section as FloorSection).to_local(node.global_position)


func _space() -> PhysicsDirectSpaceState3D:
	return (_game.level.sections[0] as Node3D).get_world_3d().direct_space_state

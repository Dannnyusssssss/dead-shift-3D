extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Cada tienda es una cosa u otra: cerrada (persiana; no se entra, sin botín ni enemigos) o
## abierta y amueblada. Antes había tiendas con la persiana a medias por las que se entraba a una
## sala vacía, y escaparates que dejaban ver la sala vacía de detrás.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")


func _props_inside(floor_data: FloorData, room: RoomData) -> int:
	var count := 0
	for spec: PropSpec in floor_data.props:
		if room.rect.has_point(Vector2(spec.position.x, spec.position.z)):
			count += 1
	return count


func test_every_store_is_closed_or_furnished() -> void:
	for floor_data: FloorData in GameState.CATALOG.floors:
		for room: RoomData in floor_data.rooms:
			if room.storefront_side < 0:
				continue
			var where := "%s/%s" % [floor_data.id, room.id]
			if room.is_closed():
				assert_eq(room.loot.size(), 0, where + ": cerrada y con botín")
				for spawn: EnemySpawn in floor_data.enemies:
					var spot := Vector2(spawn.position.x, spawn.position.z)
					assert_false(room.rect.has_point(spot), where + ": cerrada y con enemigos")
			else:
				assert_gt(_props_inside(floor_data, room), 0, where + ": abierta y vacía")


## En el edificio construido, la puerta de cada tienda cerrada no deja pasar: un rayo desde el
## pasillo hacia dentro choca justo en la puerta, a la altura de las piernas y del pecho.
func test_closed_store_doors_block_the_way() -> void:
	GameState.forced_seed = 5
	var game: Game = GAME_SCRIPT.new()
	add_child_autofree(game)
	await wait_physics_frames(3)
	var space := game.level.get_world_3d().direct_space_state
	var checked := 0
	for section: FloorSection in game.level.sections:
		for room: RoomData in section.floor_data.rooms:
			if not room.is_closed() or room.doors.is_empty():
				continue
			var door: DoorSpec = room.doors[0]
			var local_center: Vector3 = section.call("_door_center", room, door)
			var center := section.global_position + local_center
			var inward := Vector3.ZERO
			match door.side:
				DoorSpec.SIDE_NORTH:
					inward = Vector3.BACK
				DoorSpec.SIDE_SOUTH:
					inward = Vector3.FORWARD
				DoorSpec.SIDE_WEST:
					inward = Vector3.RIGHT
				_:
					inward = Vector3.LEFT
			for height: float in [0.5, 1.4]:
				var from := center - inward * 1.0 + Vector3.UP * height
				var to := center + inward * 2.0 + Vector3.UP * height
				var query := PhysicsRayQueryParameters3D.create(from, to, Rules.LAYER_WORLD)
				var hit := space.intersect_ray(query)
				var where := "%s/%s a %.1f m" % [section.floor_data.id, room.id, height]
				assert_false(hit.is_empty(), where + ": se puede pasar")
				if not hit.is_empty():
					var point: Vector3 = hit["position"]
					assert_lt(point.distance_to(center + Vector3.UP * height), 0.6, where)
			checked += 1
	assert_gt(checked, 0, "hay tiendas cerradas")
	GameState.forced_seed = -1
	InputRouter.gameplay_active = false
	InputRouter.release_capture()

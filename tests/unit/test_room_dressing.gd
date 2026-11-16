extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Mobiliario por código: el desorden nunca cae en puertas, botín, salidas, escaleras ni huecos
## del atrio; los baños se amueblan; las tiendas cerradas llevan escaparate; todas las salas con
## nombre tienen algo dentro; y el ascensor tiene su hueco con cabina y su colisión.


func _floors() -> Array[FloorData]:
	return GameState.CATALOG.floors


func test_clutter_avoids_doors_loot_exits_ramps_and_holes() -> void:
	var total := 0
	for floor_data: FloorData in _floors():
		var blocked := RoomDressing.blocked_points(floor_data)
		for room: RoomData in floor_data.rooms:
			var spots := RoomDressing.scatter_clutter(floor_data, room, Kit.Builder.new(), blocked)
			if not RoomDressing.wants_clutter(room):
				assert_eq(spots.size(), 0, "%s/%s sin desorden" % [floor_data.id, room.id])
			total += spots.size()
			for spot: Vector2 in spots:
				var where := "%s/%s en %s" % [floor_data.id, room.id, spot]
				assert_true(room.rect.has_point(spot), where + ": dentro de su sala")
				for circle: Vector4 in blocked:
					assert_gte(spot.distance_to(Vector2(circle.x, circle.y)), circle.z, where)
				for hole: Rect2 in floor_data.holes:
					assert_false(hole.has_point(spot), where + ": en un hueco")
	assert_gt(total, 20, "hay desorden repartido por el edificio")


func test_clutter_is_the_same_every_time() -> void:
	var floor_data := _floors()[0]
	var blocked := RoomDressing.blocked_points(floor_data)
	for room: RoomData in floor_data.rooms:
		var first := RoomDressing.scatter_clutter(floor_data, room, Kit.Builder.new(), blocked)
		var second := RoomDressing.scatter_clutter(floor_data, room, Kit.Builder.new(), blocked)
		assert_eq(first, second, room.id)


func test_restrooms_get_stalls_sinks_and_urinals() -> void:
	var found := 0
	for floor_data: FloorData in _floors():
		for room: RoomData in floor_data.rooms:
			if room.id != "restrooms":
				continue
			found += 1
			var builder := Kit.Builder.new()
			RoomDressing.furnish_restroom(room, builder)
			var body := builder.build("Test")
			add_child_autofree(body)
			var shapes := 0
			var meshes := 0
			for child: Node in body.get_children():
				if child is CollisionShape3D:
					shapes += 1
				elif child is MeshInstance3D:
					meshes += 1
			# Cubículos (al menos 1), encimera y dos urinarios con colisión.
			assert_gte(shapes, 4, floor_data.id)
			assert_gt(meshes, 0, floor_data.id)
	assert_eq(found, 2, "un baño en la planta baja y otro en el Nivel 1")


func test_every_named_room_has_something_inside() -> void:
	var dressed_by_code: Array[String] = ["restrooms"]
	for floor_data: FloorData in _floors():
		for room: RoomData in floor_data.rooms:
			if room.name_key.is_empty() or room.is_closed() or room.outdoor:
				continue
			if room.id in ["service_stairs", "roof_stairs", "stair_hut"]:
				continue
			if dressed_by_code.has(room.id):
				continue
			var props := 0
			for spec: PropSpec in floor_data.props:
				if room.rect.has_point(Vector2(spec.position.x, spec.position.z)):
					props += 1
			var where := "%s/%s" % [floor_data.id, room.id]
			assert_gt(props + room.loot.size(), 0, where + ": sala vacía")


func test_closed_stores_have_a_window_display() -> void:
	for floor_data: FloorData in _floors():
		for room: RoomData in floor_data.rooms:
			if not room.is_closed() or room.storefront_side < 0:
				continue
			assert_true(
				RoomDressing.DISPLAYS.has(room.name_key),
				"%s/%s sin escaparate" % [floor_data.id, room.id]
			)
			assert_true(
				ResourceLoader.exists(Kit.model_path(RoomDressing.DISPLAYS[room.name_key])),
				room.name_key
			)


func test_elevator_has_depth_and_collision_on_each_floor() -> void:
	for floor_data: FloorData in _floors():
		if floor_data.has_helipad:
			continue
		var model := false
		var collision := false
		for spec: PropSpec in floor_data.props:
			if spec.kind == PropSpec.KIND_MODEL and spec.text_key == "elevator":
				model = true
			if spec.kind == PropSpec.KIND_BLOCK and spec.collision_only and spec.size.z >= 1.8:
				if spec.position.distance_to(Vector3(22.95, 0.0, 3.5)) < 0.1:
					collision = true
		assert_true(model, floor_data.id + ": modelo del ascensor")
		assert_true(collision, floor_data.id + ": colisión del hueco")

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Cámaras de seguridad: salen de los datos de los pisos, en orden de piso, con nombre existente,
## y el monitor las recorre en círculo.


func test_every_floor_has_a_camera_in_order() -> void:
	var spots := CameraSpots.from_floors(GameState.CATALOG.floors)
	assert_eq(spots.size(), 7)
	var last_floor := -1
	var floors_seen: Dictionary = {}
	for spot: Dictionary in spots:
		var floor_index: int = spot["floor_index"]
		assert_gte(floor_index, last_floor, "en orden de piso")
		last_floor = floor_index
		floors_seen[floor_index] = true
		var name_key: String = spot["name_key"]
		assert_ne(tr(name_key), name_key, "nombre con texto: " + name_key)
		var position: Vector3 = spot["position"]
		assert_almost_eq(
			position.y,
			floor_index * Rules.FLOOR_HEIGHT + 4.0,
			1.0,
			"la lente está a la altura de su piso"
		)
	assert_eq(floors_seen.size(), GameState.CATALOG.floors.size(), "una o más por piso")


func test_step_wraps_around() -> void:
	assert_eq(CameraSpots.step(0, 3, 1), 1)
	assert_eq(CameraSpots.step(2, 3, 1), 0, "de la última a la primera")
	assert_eq(CameraSpots.step(0, 3, -1), 2, "de la primera a la última")
	assert_eq(CameraSpots.step(0, 0, 1), -1, "sin cámaras")

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Trozos de cristal: siempre los mismos para el mismo panel, en el suelo y cerca del hueco;
## clave del panel válida para el guardado.

const CENTER: Vector3 = Vector3(4.0, 0.0, -6.0)
const PANE: Vector3 = Vector3(3.0, 1.7, 0.04)


func test_same_seed_same_shards() -> void:
	assert_eq(GlassShards.layout(CENTER, PANE, 7), GlassShards.layout(CENTER, PANE, 7))
	assert_ne(GlassShards.layout(CENTER, PANE, 7), GlassShards.layout(CENTER, PANE, 8))


func test_shards_lie_on_the_floor_near_the_pane() -> void:
	var shards := GlassShards.layout(CENTER, PANE, 3)
	assert_eq(shards.size(), GlassShards.COUNT)
	for shard: Dictionary in shards:
		var spot: Vector3 = shard["position"]
		var size: Vector3 = shard["size"]
		assert_almost_eq(spot.y, GlassShards.THICKNESS * 0.5, 0.0001, "apoyado en el suelo")
		assert_lte(absf(spot.x - CENTER.x), PANE.x * 0.5, "a lo largo del hueco")
		assert_lte(absf(spot.z - CENTER.z), GlassShards.SPREAD, "a un lado u otro")
		assert_between(size.x, GlassShards.MIN_SIZE, GlassShards.MAX_SIZE)


func test_pane_along_z_spreads_along_x() -> void:
	var pane := Vector3(0.04, 1.7, 3.0)
	for shard: Dictionary in GlassShards.layout(CENTER, pane, 5):
		var spot: Vector3 = shard["position"]
		assert_lte(absf(spot.z - CENTER.z), pane.z * 0.5)
		assert_lte(absf(spot.x - CENTER.x), GlassShards.SPREAD)


func test_key_is_a_valid_save_id_for_every_room() -> void:
	for floor_data: FloorData in GameState.CATALOG.floors:
		for room: RoomData in floor_data.rooms:
			var key := GlassShards.key(room.id, 9)
			assert_true(Validation.is_valid_id(key), "clave guardable: " + key)

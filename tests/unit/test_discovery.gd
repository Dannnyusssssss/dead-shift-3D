extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Lo descubierto: ingredientes vistos, combinaciones conocidas, teléfono y zonas de las piezas;
## y dónde marca el mapa las cosas importantes que faltan.

const Fixtures = preload("res://tests/helpers/fixtures.gd")


func _recipes() -> Array[RecipeData]:
	var recipes: Array[RecipeData] = [
		Fixtures.recipe("rag", "tape", "improvised_bandage"),
		Fixtures.recipe("pipe", "nails", "pipe_nails"),
	]
	return recipes


func test_marks_only_recipe_inputs_once() -> void:
	var world := WorldState.new()
	var inventory := Inventory.new()
	inventory.add_item(Fixtures.material("rag", 10), 2)
	inventory.add_stack(ItemStack.new(Fixtures.melee("knife")))
	assert_eq(Discovery.mark_seen(world, inventory, _recipes()), 1)
	assert_true(world.has_flag(Discovery.seen_flag("rag")))
	assert_false(world.has_flag(Discovery.seen_flag("knife")), "no entra en ninguna receta")
	assert_eq(Discovery.mark_seen(world, inventory, _recipes()), 0, "ya estaba marcado")


func test_seen_survives_losing_the_item() -> void:
	var world := WorldState.new()
	var inventory := Inventory.new()
	inventory.add_item(Fixtures.material("rag", 10), 1)
	Discovery.mark_seen(world, inventory, _recipes())
	inventory.bag.remove("rag", 1)
	Discovery.mark_seen(world, inventory, _recipes())
	assert_true(Discovery.knows_recipe(world, _recipes()[0]))


func test_recipe_known_with_either_input() -> void:
	var world := WorldState.new()
	var recipes := _recipes()
	assert_false(Discovery.knows_recipe(world, recipes[1]))
	world.set_flag(Discovery.seen_flag("nails"))
	assert_true(Discovery.knows_recipe(world, recipes[1]))
	assert_false(Discovery.knows_recipe(world, recipes[0]))


func test_recipe_inputs_without_repeats() -> void:
	var recipes := _recipes()
	recipes.append(Fixtures.recipe("pipe", "rag", "pipe_grip"))
	assert_eq(Discovery.recipe_inputs(recipes), ["rag", "tape", "pipe", "nails"])


## El teléfono solo se descubre con la nota del técnico: las piezas sueltas no lo revelan.
func test_phone_known_only_after_the_note() -> void:
	var world := WorldState.new()
	var keys := KeyItems.new()
	assert_false(Discovery.knows_phone(world, keys))
	for part: String in Rules.PHONE_PARTS:
		keys.add(part)
	assert_false(Discovery.knows_phone(world, keys), "con todas las piezas pero sin la nota")
	world.set_flag(Discovery.NOTE_FLAG)
	assert_true(Discovery.knows_phone(world, keys), "con la nota")


## Sin la nota no se puede armar aunque estén todas las piezas; al leerla, sí.
func test_assembling_needs_the_note() -> void:
	var world := WorldState.new()
	var keys := KeyItems.new()
	for part: String in Rules.PHONE_PARTS:
		keys.add(part)
	assert_false(Discovery.can_assemble_phone(world, keys), "sin la nota")
	world.set_flag(Discovery.NOTE_FLAG)
	assert_true(Discovery.can_assemble_phone(world, keys), "con la nota y las piezas")
	keys.assemble_phone()
	assert_false(Discovery.can_assemble_phone(world, keys), "ya armado")


## Una partida guardada con el teléfono ya armado sin haber leído la nota sigue igual.
func test_assembled_phone_counts_as_known() -> void:
	var keys := KeyItems.new()
	for part: String in Rules.PHONE_PARTS:
		keys.add(part)
	keys.assemble_phone()
	assert_true(Discovery.knows_phone(WorldState.new(), keys))


func test_part_zones_known_after_note_or_map() -> void:
	var keys := KeyItems.new()
	var world := WorldState.new()
	assert_false(Discovery.knows_part_zones(world, keys))
	keys.add(MapMarkers.MAP_ITEM)
	assert_true(Discovery.knows_part_zones(world, keys))
	world.set_flag(Discovery.NOTE_FLAG)
	assert_true(Discovery.knows_part_zones(world, KeyItems.new()))


func test_map_lists_missing_parts_then_keys() -> void:
	var floors: Array[FloorData] = GameState.CATALOG.floors
	var keys := KeyItems.new()
	var entries := MapMarkers.missing(floors, keys)
	var ids: Array[String] = []
	for entry: Dictionary in entries:
		ids.append(entry["item_id"])
	var expected: Array[String] = []
	expected.append_array(Rules.PHONE_PARTS)
	expected.append_array(MapMarkers.KEYS)
	assert_eq(ids, expected, "todo lo importante está en algún piso, en orden")
	for entry: Dictionary in entries:
		assert_false(String(entry["room_id"]).is_empty())
		assert_false(String(entry["floor_key"]).is_empty())


func test_map_drops_what_the_player_has() -> void:
	var floors: Array[FloorData] = GameState.CATALOG.floors
	var keys := KeyItems.new()
	keys.add("phone_antenna")
	keys.add("roof_key")
	var ids: Array[String] = []
	for entry: Dictionary in MapMarkers.missing(floors, keys):
		ids.append(entry["item_id"])
	assert_false(ids.has("phone_antenna"))
	assert_false(ids.has("roof_key"))
	assert_true(ids.has("phone_board"))
	for part: String in Rules.PHONE_PARTS:
		keys.add(part)
	keys.assemble_phone()
	ids.clear()
	for entry: Dictionary in MapMarkers.missing(floors, keys):
		ids.append(entry["item_id"])
	assert_eq(ids, ["security_key"], "con el teléfono armado solo queda la llave")


func test_electronics_store_has_the_technician_note() -> void:
	var found := false
	for floor_data: FloorData in GameState.CATALOG.floors:
		for prop: PropSpec in floor_data.props:
			if prop.kind == PropSpec.KIND_NOTE and prop.text_key == "technician":
				found = true
	assert_true(found)
	assert_ne(tr("note_technician_body"), "note_technician_body", "su texto existe")


func test_safe_rooms_on_ground_floor() -> void:
	var ground: FloorData = GameState.CATALOG.floors[0]
	var safe := MapMarkers.safe_rooms(ground)
	assert_gt(safe.size(), 0)
	for room: RoomData in safe:
		assert_true(room.safe_zone)

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## La porra va en una posición fija que no ocupa casilla: guardados antiguos con la porra en una
## casilla normal, porra equipada que se guarda y se carga, mochila llena y validación del arma
## equipada en la posición fija.

const CONTEXT: Dictionary = {
	"items": {"pistol": {"category": 2, "max_stack": 1, "magazine": 8}},
	"floors": {"ground_floor": {"exits": [], "safe_rooms": ["security_room"]}},
	"start_floor": "ground_floor",
	"capacity": 4,
	"phone_parts": [],
}


func _parse(data: Dictionary) -> Dictionary:
	var result := SaveValidation.parse(SaveCodec.encode(data), CONTEXT)
	assert_true(result.ok)
	return result.data


func test_equipped_fixed_slot_is_accepted_and_beyond_is_not() -> void:
	var fixed: int = CONTEXT["capacity"]
	var clean := _parse({"inventory": [], "equipped": fixed})
	assert_eq(clean["equipped"], fixed, "la posición fija (la porra) se acepta")
	clean = _parse({"inventory": [], "equipped": fixed + 1})
	assert_eq(clean["equipped"], -1, "más allá de la posición fija, ninguna")


func test_old_save_with_baton_in_a_slot_frees_the_slot_and_keeps_it_equipped() -> void:
	var items := GameState.items
	var state := PlayerState.new(items)
	state.give_starting_kit()
	var data := SaveGame.capture(
		state, WorldState.new(), RescueClock.new(), "ground_floor", "safe", "security_room", 5, 1.0
	)
	# Como lo guardaba una versión anterior: la porra en la casilla 3 y en la mano.
	var inventory: Array = data["inventory"]
	inventory.append({"slot": 3, "id": "baton", "count": 1, "durability": 1.0, "ammo": 0})
	data["equipped"] = 3
	var parsed := SaveValidation.parse(SaveCodec.encode(data), GameState.CATALOG.save_context())
	assert_true(parsed.ok)
	var restored := SaveGame.restore_player(parsed.data, items)
	var fixed := restored.inventory.fixed_slot()
	assert_eq(restored.inventory.get_slot(fixed).id(), "baton")
	assert_null(restored.inventory.get_slot(3), "la casilla queda libre")
	assert_eq(restored.inventory.count_of("baton"), 1, "una sola porra")
	assert_eq(restored.equipped_slot, fixed, "sigue en la mano")


func test_new_save_with_baton_equipped_round_trips() -> void:
	var items := GameState.items
	var state := PlayerState.new(items)
	state.give_starting_kit()
	assert_true(state.select_slot(state.inventory.fixed_slot()))
	var data := SaveGame.capture(
		state, WorldState.new(), RescueClock.new(), "ground_floor", "safe", "security_room", 5, 1.0
	)
	var parsed := SaveValidation.parse(SaveCodec.encode(data), GameState.CATALOG.save_context())
	assert_true(parsed.ok)
	var restored := SaveGame.restore_player(parsed.data, items)
	assert_eq(restored.equipped().id(), PlayerState.BOUND_WEAPON)
	assert_eq(restored.inventory.used_slots(), state.inventory.used_slots())


func test_full_bag_keeps_the_baton_outside_the_slots() -> void:
	var items := GameState.items
	var state := PlayerState.new(items)
	state.give_starting_kit()
	while not state.inventory.is_full():
		assert_true(state.inventory.add_stack(ItemStack.new(items.get_item("pipe"))))
	assert_eq(state.inventory.used_slots(), Rules.INVENTORY_SLOTS, "todas las casillas para cosas")
	assert_eq(state.inventory.count_of(PlayerState.BOUND_WEAPON), 1)
	assert_true(state.ensure_bound_items())
	assert_eq(state.inventory.count_of(PlayerState.BOUND_WEAPON), 1, "no se duplica")
	var cycled := 0
	var seen_baton := false
	while cycled < Rules.INVENTORY_SLOTS + 2:
		state.cycle_weapon(1)
		seen_baton = seen_baton or state.equipped().id() == PlayerState.BOUND_WEAPON
		cycled += 1
	assert_true(seen_baton, "la rueda llega a la porra")

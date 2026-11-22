extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Guardado de partida (versión actual) con entradas hostiles: cada campo en su rango y la
## coherencia entre campos (piso y punto de reaparición existentes, inventario dentro del límite
## y sin casillas repetidas, objetos clave sin repetir, teléfono armado solo con todas las
## piezas, helicóptero llamado solo con teléfono, reloj nunca negativo). Nada rompe el juego.

const CONTEXT: Dictionary = {
	"items":
	{
		"pistol": {"category": 2, "max_stack": 1, "magazine": 8},
		"pipe": {"category": 2, "max_stack": 1, "magazine": 0},
		"nails": {"category": 0, "max_stack": 10, "magazine": 0},
		"pistol_ammo": {"category": 1, "max_stack": 10, "magazine": 0},
		"vest": {"category": 3, "max_stack": 1, "magazine": 0},
		"phone_antenna": {"category": 5, "max_stack": 1, "magazine": 0},
		"phone_battery": {"category": 5, "max_stack": 1, "magazine": 0},
		"phone_board": {"category": 5, "max_stack": 1, "magazine": 0},
	},
	"floors":
	{
		"ground_floor": {"exits": ["stairs_up"], "safe_rooms": ["security_room"]},
		"level_1": {"exits": ["stairs_down", "stairs_up"], "safe_rooms": []},
	},
	"start_floor": "ground_floor",
	"capacity": 4,
	"phone_parts": ["phone_antenna", "phone_battery", "phone_board"],
}


func _parse(data: Dictionary) -> Dictionary:
	var result := SaveValidation.parse(SaveCodec.encode(data), CONTEXT)
	assert_true(result.ok)
	return result.data


func test_unreadable_text_is_rejected() -> void:
	assert_false(SaveValidation.parse("", CONTEXT).ok)
	assert_false(SaveValidation.parse("no es json", CONTEXT).ok)
	assert_false(SaveValidation.parse('{"version": 99}', CONTEXT).ok, "versión futura")
	assert_false(SaveValidation.parse("x".repeat(SaveCodec.MAX_BYTES + 1), CONTEXT).ok, "gigante")


func test_valid_save_survives() -> void:
	var clean := _parse(
		{
			"floor": "level_1",
			"spawn_kind": "exit",
			"spawn_id": "stairs_up",
			"health": 75.0,
			"infection": {"infected": true, "time_left": 100.0},
			"inventory": [{"slot": 0, "id": "pistol", "count": 1, "durability": 1.0, "ammo": 5}],
			"vest": {"id": "vest", "durability": 0.8},
			"equipped": 0,
			"keys": ["phone_antenna", "phone_battery", "phone_board"],
			"phone_assembled": true,
			"rescue": {"state": RescueClock.STATE_INBOUND, "time_left": 30.0},
			"world": {"flags": ["shortcut_l1"], "floors": {"level_1": {"killed": ["enemy_0"]}}},
			"seed": 42,
			"stats": {"time": 120.0, "kills": 3},
		}
	)
	assert_eq(clean["floor"], "level_1")
	assert_eq(clean["spawn_kind"], "exit")
	assert_eq(clean["spawn_id"], "stairs_up")
	assert_eq(clean["equipped"], 0)
	assert_true(clean["phone_assembled"])
	assert_eq(clean["rescue"]["state"], RescueClock.STATE_INBOUND)
	assert_eq(clean["world"]["floors"]["level_1"]["killed"], ["enemy_0"])
	assert_eq(clean["stats"]["kills"], 3)


func test_unknown_floor_and_spawn_fall_back() -> void:
	var clean := _parse({"floor": "../../etc", "spawn_kind": "exit", "spawn_id": "nowhere"})
	assert_eq(clean["floor"], "ground_floor")
	assert_eq(clean["spawn_kind"], "start")
	var other := _parse({"floor": "level_1", "spawn_kind": "safe", "spawn_id": "security_room"})
	assert_eq(other["spawn_kind"], "exit", "esa zona segura no está en ese piso")
	assert_eq(other["spawn_id"], "stairs_down")


func test_inventory_respects_capacity_slots_and_stack_limits() -> void:
	var entries: Array = []
	for slot: int in 10:
		entries.append({"slot": slot, "id": "pistol_ammo", "count": 99})
	entries.append({"slot": 1, "id": "pipe"})
	entries.append({"slot": 500, "id": "pipe"})
	entries.append({"slot": 2, "id": "rocket_launcher"})
	entries.append({"slot": 3, "id": "phone_board"})
	entries.append("basura")
	var clean := _parse({"inventory": entries})
	var inventory: Array = clean["inventory"]
	assert_eq(inventory.size(), 4, "no supera la capacidad")
	var seen: Array = []
	for entry: Dictionary in inventory:
		assert_false(seen.has(entry["slot"]), "casilla repetida")
		seen.append(entry["slot"])
		assert_lte(entry["count"], 10, "dentro del máximo del objeto")
		assert_ne(entry["id"], "phone_board", "los objetos clave no van en casillas")


func test_equipped_must_point_to_a_weapon() -> void:
	var clean := _parse({"inventory": [{"slot": 0, "id": "nails", "count": 2}], "equipped": 0})
	assert_eq(clean["equipped"], -1)
	clean = _parse({"inventory": [], "equipped": 3})
	assert_eq(clean["equipped"], -1)


func test_keys_are_unique_and_of_key_category() -> void:
	var clean := _parse({"keys": ["phone_antenna", "phone_antenna", "pistol", "nope", 5]})
	assert_eq(clean["keys"], ["phone_antenna"])


func test_phone_and_rescue_need_coherent_state() -> void:
	var clean := _parse(
		{
			"keys": ["phone_antenna"],
			"phone_assembled": true,
			"rescue": {"state": RescueClock.STATE_WAITING, "time_left": 20.0},
		}
	)
	assert_false(clean["phone_assembled"], "sin todas las piezas no hay teléfono")
	assert_eq(clean["rescue"]["state"], RescueClock.STATE_IDLE, "sin teléfono no hay llamada")
	var parts := ["phone_antenna", "phone_battery", "phone_board"]
	var negative := _parse(
		{
			"keys": parts,
			"phone_assembled": true,
			"rescue": {"state": RescueClock.STATE_INBOUND, "time_left": -50.0},
		}
	)
	assert_eq(negative["rescue"]["time_left"], 0.0, "reloj nunca negativo")
	var boarded := _parse(
		{"keys": parts, "phone_assembled": true, "rescue": {"state": RescueClock.STATE_BOARDED}}
	)
	assert_eq(boarded["rescue"]["state"], RescueClock.STATE_IDLE, "no se guarda ya rescatado")


func test_health_and_infection_are_never_lethal_on_load() -> void:
	var clean := _parse({"health": -5, "infection": {"infected": true, "time_left": 0}})
	assert_eq(clean["health"], 1.0)
	assert_eq(clean["infection"]["time_left"], 1.0)
	var healthy := _parse({"infection": {"infected": false, "time_left": 500}})
	assert_eq(healthy["infection"]["time_left"], 0.0)
	assert_eq(healthy["infection"]["exposure"], 0.0, "partida de antes: sin exposición")


## Exposición manipulada: siempre un número por debajo de llena (cargar nunca infecta).
func test_exposure_is_clamped_below_full_on_load() -> void:
	var full := _parse({"infection": {"infected": false, "exposure": 5.0}})
	assert_eq(full["infection"]["exposure"], SaveValidation.MAX_LOADED_EXPOSURE)
	var negative := _parse({"infection": {"infected": false, "exposure": -3}})
	assert_eq(negative["infection"]["exposure"], 0.0)
	var text := _parse({"infection": {"infected": false, "exposure": "0.9"}})
	assert_eq(text["infection"]["exposure"], 0.0, "un texto no es un número")
	var half := _parse({"infection": {"infected": false, "exposure": 0.5}})
	assert_eq(half["infection"]["exposure"], 0.5)
	var infected := _parse({"infection": {"infected": true, "time_left": 50, "exposure": 0.7}})
	assert_eq(infected["infection"]["exposure"], 0.0, "con infección no hay barra")


func test_world_is_limited_to_known_floors_and_valid_entries() -> void:
	var killed: Array = []
	for index: int in 1000:
		killed.append("enemy_%d" % index)
	var clean := _parse(
		{
			"world":
			{
				"flags": ["ok_flag", "<script>", "ok_flag"],
				"floors":
				{
					"level_1":
					{
						"killed": killed,
						"containers": {"shop_0": ["nails:500", "nope:1", 7, "nails:x"]},
						"drops": [{"id": "pipe", "x": 1e9, "z": -3.0}, {"id": "nope"}],
					},
					"secret_floor": {"killed": ["enemy_0"]},
				},
			},
		}
	)
	var world: Dictionary = clean["world"]
	assert_eq(world["flags"], ["ok_flag"])
	var floors: Dictionary = world["floors"]
	assert_false(floors.has("secret_floor"), "piso desconocido")
	var record: Dictionary = floors["level_1"]
	var killed_clean: Array = record["killed"]
	assert_eq(killed_clean.size(), SaveSchema.MAX_KILLED)
	assert_eq(record["containers"]["shop_0"], PackedStringArray(["nails:10"]))
	var drops: Array = record["drops"]
	assert_eq(drops.size(), 1)
	assert_eq(drops[0]["x"], SaveSchema.MAX_COORDINATE)


func test_hostile_text_values_are_just_text() -> void:
	var clean := _parse(
		{
			"floor": "<img src=x onerror=alert(1)>",
			"spawn_id": "' OR 1=1 --",
			"keys": ["\u0000\u0007", "😀"],
			"seed": "../../",
			"stats": {"time": "mucho", "weapons_broken": 3.5},
		}
	)
	assert_eq(clean["floor"], "ground_floor")
	assert_eq(clean["keys"], [])
	assert_eq(clean["seed"], 0)
	assert_eq(clean["stats"]["time"], 0.0)
	assert_eq(clean["stats"]["weapons_broken"], 0)


func test_round_trip_through_core_keeps_the_run() -> void:
	var items := GameState.items
	var state := PlayerState.new(items)
	state.give_starting_kit()
	state.health = 42.0
	state.keys.add("phone_antenna")
	state.kills = 5
	state.infection.add_exposure(1.0)
	var world := WorldState.new()
	world.mark_killed("level_1", "enemy_2")
	world.set_flag("shortcut_l1")
	world.set_container("level_1", "pharmacy_0", PackedStringArray(["neutrax:1"]))
	var rescue := RescueClock.new()
	var data := SaveGame.capture(state, world, rescue, "level_1", "exit", "stairs_down", 77, 321.0)
	var parsed := SaveValidation.parse(SaveCodec.encode(data), GameState.CATALOG.save_context())
	assert_true(parsed.ok)
	var clean := parsed.data
	var restored := SaveGame.restore_player(clean, items)
	assert_eq(restored.health, 42.0)
	assert_true(restored.keys.has("phone_antenna"))
	assert_eq(restored.kills, 5)
	assert_true(restored.infection.infected)
	assert_eq(restored.equipped().id(), "pistol")
	assert_eq(restored.inventory.count_of("pistol_ammo"), PlayerState.STARTING_RESERVE_AMMO)
	var restored_world := SaveGame.restore_world(clean)
	assert_true(restored_world.is_killed("level_1", "enemy_2"))
	assert_true(restored_world.has_flag("shortcut_l1"))
	assert_eq(
		restored_world.container_contents("level_1", "pharmacy_0"), PackedStringArray(["neutrax:1"])
	)
	assert_eq(clean["seed"], 77)
	assert_eq(clean["stats"]["time"], 321.0)


## La exposición sin llenar se guarda y se recupera.
func test_round_trip_keeps_the_exposure() -> void:
	var items := GameState.items
	var state := PlayerState.new(items)
	state.give_starting_kit()
	state.infection.add_exposure(0.5)
	var data := SaveGame.capture(
		state, WorldState.new(), RescueClock.new(), "ground_floor", "start", "", 1, 0.0
	)
	var parsed := SaveValidation.parse(SaveCodec.encode(data), GameState.CATALOG.save_context())
	assert_true(parsed.ok)
	var restored := SaveGame.restore_player(parsed.data, items)
	assert_false(restored.infection.infected)
	assert_almost_eq(restored.infection.exposure, 0.5, 0.0001)


func test_difficulty_is_kept_when_known_and_easy_otherwise() -> void:
	assert_eq(_parse({"difficulty": "hard"})["difficulty"], "hard")
	assert_eq(_parse({"difficulty": "medium"})["difficulty"], "medium")
	assert_eq(_parse({})["difficulty"], Difficulty.EASY, "ausente")
	for hostile: Variant in ["imposible", "HARD", 2, 1.5, true, null, ["hard"], {"id": "hard"}]:
		assert_eq(_parse({"difficulty": hostile})["difficulty"], Difficulty.EASY, str(hostile))
	assert_eq(_parse({"difficulty": "x".repeat(5000)})["difficulty"], Difficulty.EASY, "gigante")


func test_difficulty_must_be_in_the_context_list() -> void:
	var context := CONTEXT.duplicate(true)
	context["difficulties"] = ["easy", "medium"]
	var data := {"difficulty": "hard"}
	var result := SaveValidation.parse(SaveCodec.encode(data), context)
	assert_eq(result.data["difficulty"], Difficulty.EASY)


func test_round_trip_keeps_difficulty_and_its_helicopter_wait() -> void:
	var state := PlayerState.new(GameState.items)
	state.give_starting_kit()
	var rescue := RescueClock.new(Rules.HELICOPTER_ARRIVAL_TIME, 45.0)
	var data := SaveGame.capture(
		state, WorldState.new(), rescue, "ground_floor", "start", "", 5, 10.0, "hard"
	)
	var parsed := SaveValidation.parse(SaveCodec.encode(data), GameState.CATALOG.save_context())
	assert_eq(parsed.data["difficulty"], "hard")
	var hostile: Dictionary = parsed.data.duplicate(true)
	hostile["keys"] = Rules.PHONE_PARTS
	hostile["phone_assembled"] = true
	hostile["rescue"] = {"state": RescueClock.STATE_WAITING, "time_left": 75.0}
	var clean := SaveValidation.sanitize(hostile, GameState.CATALOG.save_context())
	var clock := SaveGame.restore_rescue(clean, 45.0)
	assert_eq(clock.time_left, 45.0, "la espera nunca supera la de la dificultad")


func test_best_grades_per_difficulty() -> void:
	var ids: Array[String] = ["easy", "medium", "hard"]
	var v2 := SaveCodec.encode({"grades": {"easy": "A", "hard": "S", "medium": "Z"}}, 2)
	assert_eq(Validation.parse_best(v2, ids, 2), {"easy": "A", "hard": "S"}, "letra mala fuera")
	var v1 := SaveCodec.encode({"grade": "B"}, 1)
	assert_eq(Validation.parse_best(v1, ids, 2), {"easy": "B"}, "la marca antigua es de Fácil")
	var unknown := SaveCodec.encode({"grades": {"pesadilla": "S", "easy": 3}}, 2)
	assert_eq(Validation.parse_best(unknown, ids, 2), {})
	assert_eq(Validation.parse_best("", ids, 2), {})
	assert_eq(Validation.parse_best('{"version": 3, "grades": {}}', ids, 2), {}, "futura")
	assert_eq(Validation.parse_best('{"version": 2, "grades": [1]}', ids, 2), {})


func test_bag_keeps_known_materials_within_their_cap() -> void:
	var bag_source := {
		"nails": 6,
		"pipe": 1,
		"pistol_ammo": 3,
		"rocket_launcher": 2,
		"NAILS": 4,
	}
	var clean := _parse({"bag": bag_source})
	assert_eq(clean["bag"], {"nails": 6}, "solo materiales conocidos")
	assert_eq(_parse({"bag": {"nails": 999}})["bag"], {"nails": 10}, "tope del material")
	assert_eq(_parse({"bag": {"nails": -5}})["bag"], {}, "negativo")
	assert_eq(_parse({"bag": {"nails": 2.5}})["bag"], {}, "no entero")
	assert_eq(_parse({"bag": {"nails": "6"}})["bag"], {}, "texto")
	assert_eq(_parse({"bag": ["nails"]})["bag"], {}, "no es un diccionario")
	assert_eq(_parse({})["bag"], {}, "ausente")


func test_materials_in_slots_move_to_the_bag() -> void:
	var entries: Array = [
		{"slot": 0, "id": "nails", "count": 4},
		{"slot": 1, "id": "nails", "count": 9},
		{"slot": 2, "id": "pipe"},
	]
	var clean := _parse({"inventory": entries, "bag": {"nails": 2}})
	var inventory: Array = clean["inventory"]
	assert_eq(inventory.size(), 1, "solo el tubo queda en casillas")
	assert_eq(clean["bag"], {"nails": 10}, "se suman sin pasar del tope")


func test_flashlight_charge_is_clamped_and_defaults_to_full() -> void:
	var full := Rules.FLASHLIGHT_SECONDS
	assert_eq(_parse({})["flashlight"], {"on": false, "charge": full}, "ausente: apagada y llena")
	var clean := _parse({"flashlight": {"on": true, "charge": 42.5}})
	assert_eq(clean["flashlight"], {"on": true, "charge": 42.5})
	assert_eq(_parse({"flashlight": {"charge": -30.0}})["flashlight"]["charge"], 0.0, "negativa")
	assert_eq(_parse({"flashlight": {"charge": 1e9}})["flashlight"]["charge"], full, "enorme")
	assert_eq(_parse({"flashlight": {"charge": "lots"}})["flashlight"]["charge"], full, "texto")
	assert_eq(_parse({"flashlight": {"on": "yes"}})["flashlight"]["on"], false, "no booleano")
	assert_eq(_parse({"flashlight": [1, 2]})["flashlight"]["charge"], full, "no es diccionario")

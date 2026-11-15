extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Códec del guardado: ida y vuelta, versión y entradas hostiles (vacío, truncado, gigante,
## anidación excesiva, tipos erróneos, versión futura o inválida).


func test_round_trip_keeps_data_and_sets_version() -> void:
	var text := SaveCodec.encode({"health": 80.0})
	var result := SaveCodec.decode(text)
	assert_true(result.ok)
	assert_eq(result.data.get("health"), 80.0)
	assert_eq(result.data.get("version"), SaveCodec.CURRENT_VERSION)


func test_rejects_future_version() -> void:
	var result := SaveCodec.decode('{"version": 999}')
	assert_false(result.ok)
	assert_eq(result.error, "future_version")


func test_rejects_empty_text() -> void:
	assert_eq(SaveCodec.decode("").error, "empty")


func test_rejects_truncated_json() -> void:
	var text := SaveCodec.encode({"health": 80.0, "inventory": [1, 2, 3]})
	var result := SaveCodec.decode(text.substr(0, text.length() / 2))
	assert_false(result.ok)
	assert_eq(result.error, "bad_json")


func test_rejects_giant_text() -> void:
	var giant := '{"version": 1, "pad": "' + "x".repeat(SaveCodec.MAX_BYTES + 10) + '"}'
	assert_eq(SaveCodec.decode(giant).error, "too_large")


func test_rejects_deep_nesting() -> void:
	var deep := '{"version": 1, "a": ' + "[".repeat(40) + "]".repeat(40) + "}"
	assert_eq(SaveCodec.decode(deep).error, "too_deep")


func test_rejects_non_object_root() -> void:
	assert_eq(SaveCodec.decode("[1, 2, 3]").error, "not_object")
	assert_eq(SaveCodec.decode('"texto"').error, "not_object")


func test_rejects_missing_or_bad_version() -> void:
	assert_eq(SaveCodec.decode('{"health": 1}').error, "no_version")
	assert_eq(SaveCodec.decode('{"version": "1"}').error, "no_version")
	assert_eq(SaveCodec.decode('{"version": 1.5}').error, "bad_version")
	assert_eq(SaveCodec.decode('{"version": 0}').error, "bad_version")
	assert_eq(SaveCodec.decode('{"version": -3}').error, "bad_version")


func test_resource_paths_are_plain_text() -> void:
	# Un guardado manipulado con rutas a recursos del motor se trata como texto: nunca se carga.
	var result := SaveCodec.decode('{"version": 2, "x": "res://evil.tres"}')
	assert_true(result.ok)
	assert_eq(result.data.get("x"), "res://evil.tres")


func test_settings_version_is_independent_and_never_migrated() -> void:
	var text := SaveCodec.encode({"fov": 90.0}, 1)
	var result := SaveCodec.decode(text, 1)
	assert_true(result.ok)
	assert_eq(result.data.get("fov"), 90.0, "sin migrar como si fuera una partida")
	assert_false(SaveCodec.decode('{"version": 2}', 1).ok, "versión futura de ajustes")


func test_version_one_save_is_migrated() -> void:
	var old := '{"version": 1, "floor": 1, "safe_zone": "security_room", "health": 60,'
	old += ' "infection_left": 30, "phone_pieces": ["phone_antenna"], "phone_called": true,'
	old += ' "rescue_clock": 40, "shortcuts": ["shortcut_l1"], "stats": {"time": 99}}'
	var result := SaveCodec.decode(old)
	assert_true(result.ok)
	var data := result.data
	assert_eq(data["version"], SaveCodec.CURRENT_VERSION)
	assert_eq(data["floor"], "level_1")
	assert_eq(data["spawn_kind"], "safe")
	assert_eq(data["infection"]["infected"], true)
	assert_eq(data["keys"], ["phone_antenna"])
	assert_eq(data["rescue"]["state"], 1)
	assert_eq(data["world"]["flags"], ["shortcut_l1"])


func test_version_two_save_drops_the_old_floor_records() -> void:
	var old := '{"version": 2, "floor": "level_1", "spawn_kind": "exit", "spawn_id": "stairs_down",'
	old += ' "health": 70, "world": {"flags": ["shortcut_l1"], "floors": {"level_1":'
	old += ' {"killed": ["enemy_0"], "taken": ["corridor_0"]}}}}'
	var result := SaveCodec.decode(old)
	assert_true(result.ok)
	var data := result.data
	assert_eq(data["version"], SaveCodec.CURRENT_VERSION)
	assert_eq(data["floor"], "level_1")
	assert_eq(data["health"], 70.0)
	assert_eq(data["world"]["flags"], ["shortcut_l1"], "las rejas abiertas siguen abiertas")
	assert_eq(data["world"]["floors"], {}, "la planta antigua ya no existe")


func test_version_two_with_garbage_world_migrates_without_crashing() -> void:
	var result := SaveCodec.decode('{"version": 2, "world": 7}')
	assert_true(result.ok)
	assert_eq(result.data["world"]["floors"], {})


func test_version_one_garbage_migrates_without_crashing() -> void:
	var result := SaveCodec.decode(
		'{"version": 1, "floor": "x", "infection_left": "y", "stats": 5}'
	)
	assert_true(result.ok)
	assert_eq(result.data["floor"], "ground_floor")
	assert_eq(result.data["infection"]["infected"], false)


func test_version_three_save_is_migrated_to_easy() -> void:
	var old := '{"version": 3, "floor": "level_1", "health": 70, "world": {"flags": ["a"]}}'
	var result := SaveCodec.decode(old)
	assert_true(result.ok)
	assert_eq(result.data.get("version"), SaveCodec.CURRENT_VERSION)
	assert_eq(result.data.get("difficulty"), Difficulty.EASY, "partida antigua = Fácil")
	assert_eq(result.data.get("health"), 70.0, "el resto se conserva")
	assert_eq(result.data["world"]["flags"], ["a"])


func test_version_three_migration_overrides_any_difficulty_field() -> void:
	var result := SaveCodec.decode('{"version": 3, "difficulty": "hard"}')
	assert_eq(result.data.get("difficulty"), Difficulty.EASY)

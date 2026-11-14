extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Borde de validación con entradas hostiles: ajustes corruptos, guardado manipulado y semilla
## inválida en la URL. Nada debe romper el juego: lo dañado vuelve a su valor por defecto.

const KNOWN: PackedStringArray = ["pistol", "pipe", "nails", "vest"]


func _settings(json: String) -> Dictionary:
	return Validation.parse_settings(json)


func test_settings_defaults_on_garbage() -> void:
	var defaults := SettingsSchema.defaults()
	assert_eq(_settings(""), defaults)
	assert_eq(_settings("{{{"), defaults)
	assert_eq(_settings("[1,2]"), defaults)
	assert_eq(_settings('{"version": 99, "fov": 90}'), defaults, "versión futura")


func test_settings_wrong_types_fall_back() -> void:
	var result := _settings('{"version":1,"fov":"90","reduce_motion":1,"quality":"alta"}')
	assert_eq(result["fov"], 75.0)
	assert_eq(result["reduce_motion"], false, "1 no es booleano")
	assert_eq(result["quality"], SettingsSchema.QUALITY_MEDIUM)


func test_settings_out_of_range_is_clamped() -> void:
	var result := _settings('{"version":1,"fov":500,"volume_master":-3,"quality":9}')
	assert_eq(result["fov"], 100.0)
	assert_eq(result["volume_master"], 0.0)
	assert_eq(result["quality"], SettingsSchema.QUALITY_HIGH)


func test_settings_fractional_int_and_unknown_keys() -> void:
	var result := _settings('{"version":1,"quality":1.5,"admin":true,"__proto__":{}}')
	assert_eq(result["quality"], SettingsSchema.QUALITY_MEDIUM)
	assert_false(result.has("admin"))
	assert_false(result.has("__proto__"))


func test_settings_valid_values_survive() -> void:
	var result := _settings('{"version":1,"fov":90,"reduce_gore":true,"quality":2}')
	assert_eq(result["fov"], 90.0)
	assert_eq(result["reduce_gore"], true)
	assert_eq(result["quality"], 2)


func test_seed_valid() -> void:
	assert_eq(Validation.parse_seed("?seed=123"), 123)
	assert_eq(Validation.parse_seed("?a=1&seed=0"), 0)
	assert_eq(Validation.parse_seed("seed=2147483647"), Validation.SEED_MAX)


func test_seed_hostile() -> void:
	for query: String in [
		"",
		"?seed=",
		"?seed=-5",
		"?seed=+5",
		"?seed=12a",
		"?seed=1e5",
		"?seed=2147483648",
		"?seed=99999999999999",
		"?seed=<script>",
		"?seed=../../",
		"?seed=" + "9".repeat(600),
		"?other=5",
	]:
		assert_eq(Validation.parse_seed(query), -1, "rechaza: " + query.left(40))


func test_id_validation() -> void:
	assert_true(Validation.is_valid_id("police_zombie"))
	assert_false(Validation.is_valid_id("Mayus"))
	assert_false(Validation.is_valid_id("../x"))
	assert_false(Validation.is_valid_id(""))
	assert_false(Validation.is_valid_id("a".repeat(33)))
	assert_false(Validation.is_valid_id(42))


func test_save_rejects_unreadable_text() -> void:
	assert_false(Validation.parse_save("", KNOWN).ok)
	assert_false(Validation.parse_save("no es json", KNOWN).ok)
	assert_false(Validation.parse_save('{"version": 2}', KNOWN).ok, "versión futura")


func test_save_valid_round_trip() -> void:
	var data := {
		"floor": 1,
		"safe_zone": "security_room",
		"health": 75.0,
		"inventory": [{"slot": 0, "id": "pipe", "count": 1, "durability": 0.5, "ammo": 0}],
		"vest": {"id": "vest", "durability": 0.8},
		"seed": 42,
		"stats": {"time": 120.0, "crafted": 2},
	}
	var result := Validation.parse_save(SaveCodec.encode(data), KNOWN)
	assert_true(result.ok)
	assert_eq(result.data["floor"], 1)
	assert_eq(result.data["safe_zone"], "security_room")
	assert_eq(result.data["seed"], 42)
	var inventory: Array = result.data["inventory"]
	assert_eq(inventory.size(), 1)
	var vest: Dictionary = result.data["vest"]
	assert_eq(vest["durability"], 0.8)


func test_save_hostile_fields_are_sanitized() -> void:
	var data := {
		"floor": 99,
		"safe_zone": "<img onerror=x>",
		"health": 1e30,
		"infection_left": -10,
		"inventory":
		[
			{"slot": 0, "id": "rocket_launcher", "count": 1},
			{"slot": 1, "id": "pipe", "count": 1, "durability": 7},
			{"slot": 1, "id": "nails", "count": 5},
			{"slot": -4, "id": "nails", "count": 5},
			"no soy un objeto",
			{"slot": 2, "id": "nails", "count": 1e9},
		],
		"vest": "fuerte",
		"equipped": 500,
		"phone_pieces": ["piece_a", "piece_a", 5, "../x"],
		"seed": -1,
		"stats": {"time": "mucho", "weapons_broken": 3.5},
	}
	var result := Validation.parse_save(SaveCodec.encode(data), KNOWN)
	assert_true(result.ok, "un guardado manipulado se limpia, no rompe el juego")
	var clean := result.data
	assert_eq(clean["floor"], SaveSchema.MAX_FLOOR)
	assert_eq(clean["safe_zone"], "")
	assert_eq(clean["health"], Rules.PLAYER_MAX_HEALTH)
	assert_eq(clean["infection_left"], 0.0)
	var inventory: Array = clean["inventory"]
	assert_eq(inventory.size(), 2, "descarta desconocidos, repetidos, fuera de rango y basura")
	var pipe: Dictionary = inventory[0]
	assert_eq(pipe["durability"], 1.0)
	var nails: Dictionary = inventory[1]
	assert_eq(nails["count"], SaveSchema.MAX_STACK_COUNT)
	assert_eq(clean["vest"], {})
	assert_eq(clean["equipped"], SaveSchema.MAX_SLOT_INDEX)
	assert_eq(clean["phone_pieces"], ["piece_a"])
	assert_eq(clean["seed"], 0)
	var stats: Dictionary = clean["stats"]
	assert_eq(stats["time"], 0.0)
	assert_eq(stats["weapons_broken"], 0)


func test_save_huge_lists_are_capped() -> void:
	var killed: Array = []
	for index: int in 1000:
		killed.append("enemy_%d" % index)
	var result := Validation.parse_save(SaveCodec.encode({"killed": killed}), KNOWN)
	var clean_killed: Array = result.data["killed"]
	assert_eq(clean_killed.size(), SaveSchema.MAX_KILLED)

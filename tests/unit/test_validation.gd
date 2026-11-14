extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Borde de validación con entradas hostiles: ajustes corruptos y semilla inválida en la
## URL (el guardado de partida se prueba en test_save_validation.gd). Nada debe romper el
## juego: lo dañado vuelve a su valor por defecto.


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

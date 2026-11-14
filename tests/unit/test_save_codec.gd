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
	var result := SaveCodec.decode('{"version": 1, "x": "res://evil.tres"}')
	assert_true(result.ok)
	assert_eq(result.data.get("x"), "res://evil.tres")

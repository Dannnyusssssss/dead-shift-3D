extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Teclas reasignables: validación con entradas hostiles (acciones desconocidas, teclas
## reservadas, tipos erróneos, repetidas o en conflicto con las de fábrica) y teclas de
## fábrica iguales a las del InputMap del proyecto.


func test_valid_binding_survives() -> void:
	var clean := Validation.parse_bindings({"reload": KEY_T, "throw": float(KEY_B)})
	assert_eq(clean, {"reload": KEY_T, "throw": KEY_B})


func test_unknown_actions_and_bad_types_are_dropped() -> void:
	var clean := Validation.parse_bindings(
		{"fly": KEY_T, "pause": KEY_T, "reload": "T", "throw": 66.5, "map": null, "crouch": INF}
	)
	assert_eq(clean, {})


func test_reserved_keys_are_rejected() -> void:
	for keycode: int in [KEY_P, KEY_ESCAPE, KEY_1, KEY_2, KEY_3, KEY_ENTER, KEY_F5, KEY_F12]:
		assert_eq(Validation.parse_bindings({"reload": keycode}), {}, "reservada: %d" % keycode)


func test_key_used_by_another_default_is_rejected() -> void:
	assert_eq(Validation.parse_bindings({"reload": KEY_W}), {}, "W ya es avanzar")
	assert_eq(Validation.parse_bindings({"reload": KEY_C}), {}, "C ya es agacharse")


func test_duplicate_overrides_keep_the_first_in_order() -> void:
	var clean := Validation.parse_bindings({"reload": KEY_T, "interact": KEY_T})
	assert_eq(clean, {"reload": KEY_T}, "la segunda vuelve a su tecla de fábrica")


func test_swapping_two_actions_is_allowed() -> void:
	var clean := Validation.parse_bindings({"move_forward": KEY_S, "move_back": KEY_W})
	assert_eq(clean, {"move_forward": KEY_S, "move_back": KEY_W})


func test_settings_parse_keeps_valid_bindings_only() -> void:
	var text := SaveCodec.encode({"bindings": {"reload": KEY_T, "x": 5}}, SettingsSchema.VERSION)
	var settings := Validation.parse_settings(text)
	assert_eq(settings["bindings"], {"reload": KEY_T})
	var junk := Validation.parse_settings(
		SaveCodec.encode({"bindings": "todas"}, SettingsSchema.VERSION)
	)
	assert_eq(junk["bindings"], {})


func test_default_bindings_match_the_project_input_map() -> void:
	for action: String in SettingsSchema.REBINDABLE:
		var expected: Array = SettingsSchema.DEFAULT_BINDINGS[action]
		var actual: Array[int] = []
		for event: InputEvent in ProjectSettings.get_setting("input/" + action)["events"]:
			if event is InputEventKey:
				actual.append((event as InputEventKey).physical_keycode)
		assert_eq(actual, expected, action)

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Opciones aplicadas y conservadas: el menú cambia valores con «−»/«+» y alterna sí/no, los
## ajustes se guardan validados, la tecla reasignada llega al InputMap y vuelve a la de fábrica
## al restaurar, una tecla en uso se intercambia con la otra acción (con aviso junto a las
## teclas) y las reservadas no cambian nada, los volúmenes llegan a los canales de audio y los
## ajustes manipulados vuelven a valores válidos. Deja los ajustes como estaban.

var _saved: Dictionary = {}


func before_each() -> void:
	_saved = SaveStore.load_settings()


func after_each() -> void:
	for key: String in _saved:
		Settings.set_value(key, _saved[key])
	InputRouter.menu_open = false


func _menu() -> OptionsMenu:
	var menu := OptionsMenu.new()
	add_child_autofree(menu)
	return menu


func test_step_buttons_change_and_persist_values() -> void:
	Settings.set_value("fov", 75.0)
	var menu := _menu()
	menu.open()
	menu._on_step("fov", 5.0)
	assert_eq(Settings.get_float("fov"), 80.0)
	assert_eq(SaveStore.load_settings()["fov"], 80.0, "se guarda")
	for _press: int in 20:
		menu._on_step("fov", 5.0)
	assert_eq(Settings.get_float("fov"), 100.0, "no pasa del máximo")
	menu.close()
	assert_false(menu.visible)


func test_toggles_and_quality_cycle() -> void:
	Settings.set_value("reduce_flashes", false)
	var menu := _menu()
	menu._on_toggle("reduce_flashes")
	assert_true(Settings.get_bool("reduce_flashes"))
	var quality := Settings.get_int("quality")
	menu._on_quality()
	assert_eq(Settings.get_int("quality"), (quality + 1) % (SettingsSchema.QUALITY_HIGH + 1))


func test_rebinding_reaches_input_map_and_reset_restores() -> void:
	Settings.reset_bindings()
	assert_true(Settings.set_binding("reload", KEY_T))
	assert_eq(InputRouter.key_label("reload"), OS.get_keycode_string(KEY_T))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_T
	assert_true(InputMap.action_has_event("reload", event))
	assert_true(Settings.set_binding("interact", KEY_T), "ya en uso: se intercambian")
	assert_eq(InputRouter.key_label("interact"), OS.get_keycode_string(KEY_T))
	assert_eq(InputRouter.key_label("reload"), OS.get_keycode_string(KEY_E), "recibe la de usar")
	Settings.reset_bindings()
	assert_eq(InputRouter.key_label("reload"), OS.get_keycode_string(KEY_R))
	var mouse_events := 0
	for existing: InputEvent in InputMap.action_get_events("weapon_next"):
		if existing is InputEventMouseButton:
			mouse_events += 1
	assert_eq(mouse_events, 1, "la rueda del ratón se conserva")


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _has_key(action: String, keycode: Key) -> bool:
	return InputMap.action_has_event(action, _key_event(keycode))


func test_swap_with_secondary_default_key_frees_the_other_defaults() -> void:
	Settings.reset_bindings()
	assert_true(Settings.set_binding("throw", KEY_C), "C es la segunda tecla de agacharse")
	assert_true(_has_key("throw", KEY_C))
	assert_true(_has_key("crouch", KEY_G), "agacharse recibe la de lanzar")
	assert_false(_has_key("crouch", KEY_C))
	assert_false(_has_key("crouch", KEY_CTRL), "una acción reasignada tiene una sola tecla")
	assert_eq(Settings.binding_owner(KEY_CTRL, ""), "", "Ctrl queda libre")
	Settings.reset_bindings()
	assert_true(_has_key("crouch", KEY_CTRL))
	assert_true(_has_key("crouch", KEY_C))


func test_swap_twice_keeps_every_key_unique() -> void:
	Settings.reset_bindings()
	assert_true(Settings.set_binding("move_forward", KEY_S))
	assert_true(Settings.set_binding("move_back", KEY_S), "se deshace el intercambio")
	assert_true(_has_key("move_back", KEY_S))
	assert_true(_has_key("move_forward", KEY_W))
	var seen: Array[int] = []
	for action: String in SettingsSchema.REBINDABLE:
		for keycode: int in Settings.action_keys(action):
			assert_false(seen.has(keycode), "tecla repetida: %d" % keycode)
			seen.append(keycode)
	Settings.reset_bindings()


func test_rejected_keys_change_nothing() -> void:
	Settings.reset_bindings()
	assert_true(Settings.set_binding("reload", KEY_T))
	var rejected: Array[int] = [KEY_P, KEY_ESCAPE, KEY_1, KEY_ENTER, KEY_F5]
	for keycode: int in rejected:
		assert_false(Settings.set_binding("interact", keycode), "reservada: %d" % keycode)
	assert_false(Settings.set_binding("no_existe", KEY_B))
	assert_eq(Settings.get_bindings(), {"reload": KEY_T})
	Settings.reset_bindings()


func test_menu_rebind_flow_shows_the_swap_next_to_the_keys() -> void:
	Settings.reset_bindings()
	var was_touch := InputRouter.touch_mode
	InputRouter.touch_mode = false
	var menu := _menu()
	menu.open()
	menu._on_rebind("interact")
	assert_eq(menu.waiting_action, "interact")
	assert_eq(menu._bindings_status.text, tr("options_press_key_hint"))
	var last_button: TapButton = menu._binding_buttons["weapon_next"]
	var last_row := last_button.get_parent()
	assert_eq(menu._bindings_status.get_index(), last_row.get_index() + 1, "aviso bajo las teclas")
	menu._input(_key_event(KEY_F))
	assert_eq(menu.waiting_action, "")
	assert_true(_has_key("interact", KEY_F))
	assert_true(_has_key("flashlight", KEY_E), "la linterna recibe la de usar")
	assert_string_contains(menu._bindings_status.text, tr("action_flashlight"))
	var interact_button: TapButton = menu._binding_buttons["interact"]
	assert_eq(interact_button.text, OS.get_keycode_string(KEY_F))
	menu._on_rebind("reload")
	menu._input(_key_event(KEY_P))
	assert_eq(menu._bindings_status.text, tr("options_key_reserved"))
	assert_true(_has_key("reload", KEY_R), "la reservada no cambia nada")
	InputRouter.touch_mode = true
	menu._on_rebind("reload")
	assert_eq(menu.waiting_action, "")
	assert_eq(menu._bindings_status.text, tr("options_bindings_keyboard_only"))
	InputRouter.touch_mode = was_touch
	Settings.reset_bindings()


func test_volumes_reach_audio_buses() -> void:
	Settings.set_value("volume_sfx", 0.0)
	var sfx := AudioServer.get_bus_index("SFX")
	assert_gte(sfx, 0, "existe el canal de efectos")
	assert_true(AudioServer.is_bus_mute(sfx), "volumen 0 silencia")
	Settings.set_value("volume_sfx", 0.5)
	assert_false(AudioServer.is_bus_mute(sfx))
	assert_almost_eq(AudioServer.get_bus_volume_db(sfx), linear_to_db(0.5), 0.01)
	for bus_name: String in ["Music", "Ambience"]:
		assert_gte(AudioServer.get_bus_index(bus_name), 0, bus_name)


func test_tampered_values_fall_back_to_valid_ones() -> void:
	Settings.set_value("fov", 9999.0)
	assert_eq(Settings.get_float("fov"), 100.0)
	Settings.set_value("subtitles", "sí")
	assert_true(Settings.get_bool("subtitles") is bool)
	Settings.set_value("no_existe", 5)
	assert_false(SaveStore.load_settings().has("no_existe"))

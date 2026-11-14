extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Opciones aplicadas y conservadas: el menú cambia valores con «−»/«+» y alterna sí/no, los
## ajustes se guardan validados, la tecla reasignada llega al InputMap y vuelve a la de fábrica
## al restaurar, los volúmenes llegan a los canales de audio y los ajustes manipulados vuelven a
## valores válidos. Deja los ajustes como estaban.

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
	assert_eq(Settings.get_int("quality"), (quality + 1) % 3)


func test_rebinding_reaches_input_map_and_reset_restores() -> void:
	Settings.reset_bindings()
	assert_true(Settings.set_binding("reload", KEY_T))
	assert_eq(InputRouter.key_label("reload"), OS.get_keycode_string(KEY_T))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_T
	assert_true(InputMap.action_has_event("reload", event))
	assert_false(Settings.set_binding("interact", KEY_T), "ya en uso")
	assert_eq(InputRouter.key_label("interact"), OS.get_keycode_string(KEY_E))
	Settings.reset_bindings()
	assert_eq(InputRouter.key_label("reload"), OS.get_keycode_string(KEY_R))
	var mouse_events := 0
	for existing: InputEvent in InputMap.action_get_events("weapon_next"):
		if existing is InputEventMouseButton:
			mouse_events += 1
	assert_eq(mouse_events, 1, "la rueda del ratón se conserva")


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

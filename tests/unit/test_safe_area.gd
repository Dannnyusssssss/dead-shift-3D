extends GutTest
## Zona segura que informa la página (dato externo: se valida) y aviso de girar el celular.


func _none() -> PackedFloat32Array:
	return PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func test_valid_insets_are_read() -> void:
	var insets := Validation.parse_safe_insets("0.0500,0.0000,0.0500,0.0300")
	assert_eq(insets.size(), 4)
	assert_almost_eq(insets[0], 0.05, 0.0001)
	assert_almost_eq(insets[3], 0.03, 0.0001)


func test_hostile_insets_mean_no_insets() -> void:
	for text: String in [
		"",
		"0.1,0.1,0.1",
		"0.1,0.1,0.1,0.1,0.1",
		"0.1,0.1,0.1,abc",
		"-0.1,0,0,0",
		"0.9,0,0,0",
		"nan,0,0,0",
		"inf,0,0,0",
		"0.1,0.1,0.1,0.1" + " ".repeat(80),
		"1e9,0,0,0",
		"0.1;alert(1),0,0,0",
	]:
		assert_eq(Validation.parse_safe_insets(text), _none(), "rechaza «%s»" % text.left(30))


func test_outside_the_browser_the_whole_screen_is_safe() -> void:
	if Config.is_web:
		pass_test("solo fuera del navegador")
		return
	assert_eq(Config.safe_rect(Vector2(800.0, 400.0)), Rect2(0.0, 0.0, 800.0, 400.0))


func test_rotation_notice_only_on_touch_portrait() -> void:
	assert_true(OrientationNotice.needs_rotation(true, Vector2(400.0, 800.0)))
	assert_false(OrientationNotice.needs_rotation(true, Vector2(800.0, 400.0)))
	assert_false(OrientationNotice.needs_rotation(false, Vector2(400.0, 800.0)), "en PC nunca")


func test_menu_hides_controls_text_on_short_screens() -> void:
	var main_script: GDScript = load("res://game/main.gd")
	var tight: bool = main_script.call("shows_controls_text", 650.0, 110.0, 720.0)
	var roomy: bool = main_script.call("shows_controls_text", 500.0, 110.0, 720.0)
	assert_false(tight, "si no cabe, sin texto de controles")
	assert_true(roomy, "si cabe, se muestra")

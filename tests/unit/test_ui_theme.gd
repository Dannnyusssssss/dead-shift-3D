extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Tema de la interfaz: contraste AA (4,5:1 el texto, 3:1 el foco y los bordes), foco visible y
## tamaño de la interfaz dentro de su rango.


func test_text_contrast_is_aa() -> void:
	for back: Color in [
		UiTheme.PANEL, UiTheme.BUTTON, UiTheme.BUTTON_HOVER, UiTheme.BUTTON_PRESSED
	]:
		assert_gte(UiTheme.contrast(UiTheme.TEXT, back), 4.5, str(back))
	assert_gte(UiTheme.contrast(UiTheme.TEXT_DIM, UiTheme.BUTTON_DISABLED), 4.5)
	assert_gte(UiTheme.contrast(UiTheme.ACCENT, UiTheme.BUTTON_PRESSED), 4.5)


func test_focus_and_borders_reach_three_to_one() -> void:
	for back: Color in [UiTheme.PANEL, UiTheme.BUTTON, UiTheme.BUTTON_HOVER]:
		assert_gte(UiTheme.contrast(UiTheme.ACCENT, back), 3.0, "foco sobre %s" % back)
	assert_gte(UiTheme.contrast(UiTheme.BORDER, UiTheme.PANEL), 3.0)


func test_contrast_formula() -> void:
	assert_almost_eq(UiTheme.contrast(Color.BLACK, Color.WHITE), 21.0, 0.01)
	assert_almost_eq(UiTheme.contrast(Color.GRAY, Color.GRAY), 1.0, 0.001)


func test_theme_has_a_visible_focus_style() -> void:
	var theme := UiTheme.build()
	var focus := theme.get_stylebox("focus", "Button") as StyleBoxFlat
	assert_not_null(focus)
	assert_gte(focus.border_width_left, 3)
	assert_eq(focus.border_color, UiTheme.ACCENT)


func test_ui_scale_setting_has_a_safe_range() -> void:
	var limits: Array = SettingsSchema.FLOATS["ui_scale"]
	assert_eq(limits[0], 0.8)
	assert_eq(limits[1], 1.5)
	assert_eq(limits[2], 1.0)

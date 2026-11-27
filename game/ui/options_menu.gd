class_name OptionsMenu
extends Control
## Opciones: imagen, sonido, controles (teclas reasignables), táctil y accesibilidad. Cada
## valor numérico se cambia con botones «−» y «+» (no deslizadores) para que todo funcione igual
## con teclado, ratón y toque. Los cambios se aplican y se guardan al momento a través de
## Settings, que los valida. Se abre desde el menú principal y desde la pausa.

signal closed

const QUALITY_KEYS: Array[String] = ["quality_low", "quality_medium", "quality_high"]
## Ajustes numéricos: clave, texto, paso, y si se muestra como porcentaje.
const NUMBERS: Array = [
	["fov", "option_fov", 5.0, false],
	["mouse_sensitivity", "option_mouse_sensitivity", 0.1, false],
	["touch_sensitivity", "option_touch_sensitivity", 0.1, false],
	["volume_master", "option_volume_master", 0.1, true],
	["volume_music", "option_volume_music", 0.1, true],
	["volume_sfx", "option_volume_sfx", 0.1, true],
	["volume_ambience", "option_volume_ambience", 0.1, true],
	["touch_button_scale", "option_touch_button_scale", 0.05, true],
	["touch_opacity", "option_touch_opacity", 0.1, true],
	["ui_scale", "option_ui_scale", 0.1, true],
]
## Ajustes de sí/no: clave y texto.
const TOGGLES: Array = [
	["invert_y", "option_invert_y"],
	["head_bob", "option_head_bob"],
	["show_performance", "pause_performance"],
	["aim_assist", "option_aim_assist"],
	["reduce_motion", "option_reduce_motion"],
	["reduce_flashes", "option_reduce_flashes"],
	["reduce_gore", "option_reduce_gore"],
	["subtitles", "option_subtitles"],
	["tips", "option_tips"],
]
## Secciones: título y qué filas lleva (claves de ajustes o «bindings» o «quality»).
const SECTIONS: Array = [
	["options_image", ["quality", "fov", "show_performance", "head_bob"]],
	["options_sound", ["volume_master", "volume_music", "volume_sfx", "volume_ambience"]],
	["options_controls", ["mouse_sensitivity", "invert_y", "bindings"]],
	["options_touch", ["touch_sensitivity", "touch_button_scale", "touch_opacity", "aim_assist"]],
	[
		"options_accessibility",
		["ui_scale", "reduce_motion", "reduce_flashes", "reduce_gore", "subtitles", "tips"]
	],
]

## Acción que espera una tecla nueva ("" = ninguna).
var waiting_action: String = ""

var _value_labels: Dictionary = {}
var _toggle_buttons: Dictionary = {}
var _binding_buttons: Dictionary = {}
var _quality_button: TapButton = null
var _status: Label = null
## Aviso de la reasignación de teclas, junto a la lista de teclas.
var _bindings_status: Label = null
var _first_focus: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.03, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 16.0
	scroll.offset_bottom = -16.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(760.0, 0.0)
	center.add_child(box)
	var title := Label.new()
	title.text = tr("options_title")
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var close_top := _button(box, tr("options_close"), close)
	_first_focus = close_top
	for section: Array in SECTIONS:
		var heading := Label.new()
		heading.text = tr(str(section[0]))
		heading.add_theme_font_size_override("font_size", 28)
		heading.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
		box.add_child(heading)
		var rows: Array = section[1]
		for key: Variant in rows:
			_add_row(box, str(key))
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 20)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	box.add_child(actions)
	_button(actions, tr("options_reset"), _on_reset)
	_button(actions, tr("options_close"), close)
	EventBus.settings_changed.connect(func(_key: String) -> void: _refresh())


func open() -> void:
	visible = true
	waiting_action = ""
	_status.text = ""
	_bindings_status.text = ""
	InputRouter.menu_open = true
	InputRouter.release_capture()
	_refresh()
	_first_focus.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	waiting_action = ""
	InputRouter.menu_open = false
	closed.emit()


## Espera de una tecla para reasignar: Esc cancela; la tecla se valida en Settings.
func _input(event: InputEvent) -> void:
	if not visible or waiting_action.is_empty():
		return
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var key_event: InputEventKey = event
	var keycode := key_event.physical_keycode
	var action := waiting_action
	waiting_action = ""
	if keycode == KEY_ESCAPE:
		_bindings_status.text = ""
		_refresh()
		return
	if not SettingsSchema.is_allowed_key(keycode):
		_bindings_status.text = tr("options_key_reserved")
		_refresh()
		return
	var owner := Settings.binding_owner(keycode, action)
	var old_label := InputRouter.key_label(action)
	if not Settings.set_binding(action, keycode):
		_bindings_status.text = tr("options_key_in_use")
	elif owner.is_empty():
		_bindings_status.text = (
			tr("options_key_assigned") % [OS.get_keycode_string(keycode), tr("action_" + action)]
		)
	else:
		_bindings_status.text = (
			tr("options_key_swapped")
			% [
				OS.get_keycode_string(keycode),
				tr("action_" + action),
				tr("action_" + owner),
				old_label,
			]
		)
	_refresh()


func _add_row(parent: Control, key: String) -> void:
	if key == "quality":
		var row := _row(parent, tr("pause_quality"))
		_quality_button = _button(row, "", _on_quality)
		return
	if key == "bindings":
		_add_bindings(parent)
		return
	for spec: Array in NUMBERS:
		if spec[0] == key:
			var row := _row(parent, tr(str(spec[1])))
			var step: float = spec[2]
			_button(row, "−", _on_step.bind(key, -step))
			var value := Label.new()
			value.custom_minimum_size = Vector2(90.0, 0.0)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value.add_theme_font_size_override("font_size", 22)
			row.add_child(value)
			_value_labels[key] = value
			_button(row, "+", _on_step.bind(key, step))
			return
	for spec: Array in TOGGLES:
		if spec[0] == key:
			var row := _row(parent, tr(str(spec[1])))
			_toggle_buttons[key] = _button(row, "", _on_toggle.bind(key))
			return


func _add_bindings(parent: Control) -> void:
	var note := Label.new()
	note.text = tr("options_bindings_note")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.add_theme_font_size_override("font_size", 18)
	parent.add_child(note)
	for action: String in SettingsSchema.REBINDABLE:
		var row := _row(parent, tr("action_" + action))
		_binding_buttons[action] = _button(row, "", _on_rebind.bind(action))
	# El aviso va justo debajo de las teclas para que se vea sin desplazarse hasta el final.
	_bindings_status = Label.new()
	_bindings_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bindings_status.add_theme_font_size_override("font_size", 20)
	_bindings_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	parent.add_child(_bindings_status)


func _refresh() -> void:
	if _quality_button == null:
		return
	_quality_button.text = tr(QUALITY_KEYS[clampi(Settings.get_int("quality"), 0, 2)])
	for spec: Array in NUMBERS:
		var key: String = spec[0]
		var label: Label = _value_labels[key]
		var value := Settings.get_float(key)
		var percent: bool = spec[3]
		label.text = "%d %%" % roundi(value * 100.0) if percent else "%.1f" % value
		if key == "fov":
			label.text = "%d°" % roundi(value)
	for key: String in _toggle_buttons:
		var button: TapButton = _toggle_buttons[key]
		button.text = tr("option_on") if Settings.get_bool(key) else tr("option_off")
	for action: String in _binding_buttons:
		var button: TapButton = _binding_buttons[action]
		button.text = (
			tr("options_press_key") if action == waiting_action else InputRouter.key_label(action)
		)


func _on_quality() -> void:
	Settings.set_value("quality", (Settings.get_int("quality") + 1) % 3)


func _on_step(key: String, step: float) -> void:
	Settings.set_value(key, snappedf(Settings.get_float(key) + step, 0.01))


func _on_toggle(key: String) -> void:
	Settings.set_value(key, not Settings.get_bool(key))


func _on_rebind(action: String) -> void:
	if InputRouter.touch_mode:
		_bindings_status.text = tr("options_bindings_keyboard_only")
		return
	waiting_action = action
	_bindings_status.text = tr("options_press_key_hint")
	_refresh()


func _on_reset() -> void:
	for spec: Array in NUMBERS:
		var key: String = spec[0]
		var default_spec: Array = SettingsSchema.FLOATS[key]
		Settings.set_value(key, default_spec[2])
	for spec: Array in TOGGLES:
		var key: String = spec[0]
		Settings.set_value(key, SettingsSchema.BOOLS[key])
	Settings.reset_bindings()
	_bindings_status.text = ""
	_status.text = tr("options_reset_done")


func _row(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(380.0, 0.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 22)
	row.add_child(label)
	parent.add_child(row)
	return row


func _button(parent: Control, text: String, action: Callable) -> TapButton:
	var button := TapButton.new()
	button.text = text
	button.custom_minimum_size = Vector2(72.0, 56.0)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

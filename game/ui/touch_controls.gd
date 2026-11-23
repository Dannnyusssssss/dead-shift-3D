class_name TouchControls
extends Control
## Controles táctiles: palanca virtual a la izquierda, arrastre a la derecha para mirar y
## botones grandes que pulsan acciones del InputMap a través de InputRouter.
## Los botones miden al menos 44 px CSS, respetan el área segura (muescas) y su tamaño y
## opacidad se ajustan en Opciones. Si el dispositivo está en vertical, avisa para girarlo.

## Botones: acción, clave de texto y posición relativa dentro del área segura.
const BUTTONS: Array = [
	["attack", "touch_attack", Vector2(0.92, 0.6)],
	["aim", "touch_aim", Vector2(0.8, 0.78)],
	["reload", "touch_reload", Vector2(0.92, 0.36)],
	["interact", "touch_interact", Vector2(0.78, 0.5)],
	["crouch", "touch_crouch", Vector2(0.94, 0.86)],
	["weapon_next", "touch_weapon", Vector2(0.66, 0.86)],
	["throw", "touch_throw", Vector2(0.64, 0.62)],
	["throw_next", "touch_throw_next", Vector2(0.53, 0.68)],
	["heal", "touch_heal", Vector2(0.66, 0.34)],
	["inventory", "touch_inventory", Vector2(0.4, 0.1)],
	["map", "touch_map", Vector2(0.54, 0.1)],
	["flashlight", "touch_flashlight", Vector2(0.68, 0.1)],
	["pause", "touch_pause", Vector2(0.94, 0.1)],
]
## Tamaño base de un botón en unidades de la interfaz, antes de la escala del jugador.
const BASE_BUTTON_SIZE: float = 84.0
## Radio de la palanca respecto al tamaño de un botón.
const STICK_RADIUS_FACTOR: float = 1.3
## Parte izquierda de la pantalla reservada a la palanca.
const STICK_AREA: float = 0.45

var _buttons: Array[Panel] = []
var _actions: Array[String] = []
## Toques activos: índice del dedo -> acción pulsada.
var _touch_actions: Dictionary = {}
var _stick_index: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _look_index: int = -1
var _button_size: float = BASE_BUTTON_SIZE
var _stick_ring: Panel = null
var _stick_knob: Panel = null
var _rotate_notice: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec: Array in BUTTONS:
		var action: String = spec[0]
		var text_key: String = spec[1]
		_actions.append(action)
		_buttons.append(_make_button(text_key))
	_stick_ring = _make_circle(0.25)
	_stick_knob = _make_circle(0.6)
	_rotate_notice = Label.new()
	_rotate_notice.text = tr("touch_rotate_device")
	_rotate_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotate_notice.autowrap_mode = TextServer.AUTOWRAP_WORD
	_rotate_notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_notice.add_theme_font_size_override("font_size", 36)
	_rotate_notice.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotate_notice.add_theme_constant_override("outline_size", 8)
	add_child(_rotate_notice)
	resized.connect(_layout)
	EventBus.input_mode_changed.connect(_on_mode_changed)
	EventBus.paused_changed.connect(_on_paused_changed)
	EventBus.settings_changed.connect(_on_settings_changed)
	_layout()
	_refresh_visibility()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_on_touch_down(touch.index, touch.position)
		else:
			_on_touch_up(touch.index)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == _stick_index:
			_update_stick(drag.position)
		elif drag.index == _look_index:
			InputRouter.add_touch_look(drag.relative)


## Suelta todo lo pulsado (al ocultarse o pausar), para que no quede una acción atascada.
func release_all() -> void:
	for index: int in _touch_actions:
		var action: String = _touch_actions[index]
		InputRouter.release_action(action)
	_touch_actions.clear()
	_set_stick(Vector2.ZERO)
	_stick_index = -1
	_look_index = -1
	_stick_ring.visible = false
	_stick_knob.visible = false


func _on_touch_down(index: int, at: Vector2) -> void:
	for i: int in _buttons.size():
		if _buttons[i].get_global_rect().grow(4.0).has_point(at):
			var action := _actions[i]
			_touch_actions[index] = action
			InputRouter.press_action(action)
			_buttons[i].modulate = Color(1.4, 1.4, 1.4)
			return
	if at.x < size.x * STICK_AREA and _stick_index < 0:
		_stick_index = index
		_stick_origin = at
		_stick_ring.visible = true
		_stick_knob.visible = true
		_update_stick(at)
	elif _look_index < 0:
		_look_index = index


func _on_touch_up(index: int) -> void:
	if _touch_actions.has(index):
		var action: String = _touch_actions[index]
		InputRouter.release_action(action)
		_touch_actions.erase(index)
		for button: Panel in _buttons:
			button.modulate = Color.WHITE
	if index == _stick_index:
		_stick_index = -1
		_set_stick(Vector2.ZERO)
		_stick_ring.visible = false
		_stick_knob.visible = false
	if index == _look_index:
		_look_index = -1


func _update_stick(at: Vector2) -> void:
	var radius := _button_size * STICK_RADIUS_FACTOR
	var offset := (at - _stick_origin).limit_length(radius)
	var ring_size := Vector2.ONE * radius * 2.0
	_stick_ring.size = ring_size
	_stick_ring.position = _stick_origin - ring_size * 0.5
	var knob_size := Vector2.ONE * _button_size * 0.8
	_stick_knob.size = knob_size
	_stick_knob.position = _stick_origin + offset - knob_size * 0.5
	_set_stick(offset / radius)


## Traduce la palanca a fuerzas de las cuatro acciones de movimiento.
func _set_stick(vector: Vector2) -> void:
	_press_strength("move_right", maxf(vector.x, 0.0))
	_press_strength("move_left", maxf(-vector.x, 0.0))
	_press_strength("move_forward", maxf(-vector.y, 0.0))
	_press_strength("move_back", maxf(vector.y, 0.0))


func _press_strength(action: String, strength: float) -> void:
	if strength > 0.05:
		InputRouter.press_action(action, strength)
	else:
		InputRouter.release_action(action)


func _layout() -> void:
	var scale_setting := Settings.get_float("touch_button_scale")
	_button_size = maxf(BASE_BUTTON_SIZE, _min_button_size()) * scale_setting
	var safe := _safe_rect()
	for i: int in _buttons.size():
		var spec: Array = BUTTONS[i]
		var anchor: Vector2 = spec[2]
		var button := _buttons[i]
		button.size = Vector2.ONE * _button_size
		var center := safe.position + safe.size * anchor
		var half := button.size * 0.5
		center = center.clamp(safe.position + half, safe.end - half)
		button.position = center - half
	modulate.a = Settings.get_float("touch_opacity")
	_rotate_notice.visible = InputRouter.touch_mode and size.y > size.x


## Tamaño mínimo en unidades de la interfaz para que un botón mida 44 px CSS en pantalla.
func _min_button_size() -> float:
	var canvas_scale := get_viewport().get_final_transform().get_scale().x
	var device_ratio := DisplayServer.screen_get_scale()
	if canvas_scale <= 0.0:
		return Rules.TOUCH_MIN_TARGET_PX
	return Rules.TOUCH_MIN_TARGET_PX * maxf(device_ratio, 1.0) / canvas_scale


## Área segura (sin muescas ni bordes curvos) en coordenadas de la interfaz, con margen.
func _safe_rect() -> Rect2:
	# En el navegador la página informa la muesca (el motor no la conoce en web).
	var full := Config.safe_rect(size)
	var margin := size * 0.02
	var safe_px := Rect2(DisplayServer.get_display_safe_area())
	var window := Vector2(DisplayServer.window_get_size())
	if safe_px.size.x > 0.0 and window.x > 0.0 and window.y > 0.0:
		var factor := size / window
		var safe := Rect2(safe_px.position * factor, safe_px.size * factor)
		var usable := full.intersection(safe) if full.intersects(safe) else full
		# Algunos navegadores informan un área segura sin sentido: solo se usa si es razonable.
		if usable.size.x >= size.x * 0.6 and usable.size.y >= size.y * 0.6:
			full = usable
	return full.grow_individual(-margin.x, -margin.y, -margin.x, -margin.y)


func _make_button(text_key: String) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.55)
	style.border_color = Color(0.95, 0.95, 0.95, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(64)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = tr(text_key)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	add_child(panel)
	return panel


func _make_circle(alpha: float) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, alpha * 0.4)
	style.border_color = Color(1.0, 1.0, 1.0, alpha)
	style.set_border_width_all(3)
	style.set_corner_radius_all(512)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _refresh_visibility() -> void:
	var show := InputRouter.touch_mode and not GameState.paused
	if not show:
		release_all()
	visible = show
	_layout()


func _on_mode_changed(_touch: bool) -> void:
	_refresh_visibility()


func _on_paused_changed(_paused: bool) -> void:
	_refresh_visibility()


func _on_settings_changed(_key: String) -> void:
	_layout()

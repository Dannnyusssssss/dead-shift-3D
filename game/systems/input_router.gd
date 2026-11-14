extends Node
## Única puerta de entrada de controles. El juego solo lee acciones del InputMap a través
## de aquí. Teclado, ratón y táctil son traductores a esas acciones: los botones táctiles
## pulsan acciones y la palanca las pulsa con fuerza, así un mando futuro no toca la lógica.

## Verdadero mientras se juega (no en menús ni en pausa): pide capturar el puntero en PC.
var gameplay_active: bool = false
## Verdadero si el último control usado fue táctil.
var touch_mode: bool = false
## Verdadero mientras un menú del juego (mochila) necesita el cursor visible: no se captura.
var menu_open: bool = false

var _look_delta: Vector2 = Vector2.ZERO
var _had_capture: bool = false
## Eventos de fábrica de cada acción reasignable (para volver a ellos).
var _default_events: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch_mode = Config.is_touch
	for action: String in SettingsSchema.REBINDABLE:
		_default_events[action] = InputMap.action_get_events(action)
	apply_bindings()
	EventBus.settings_changed.connect(_on_settings_changed)


## Aplica las teclas reasignadas (ya validadas en los ajustes): cada acción reasignada cambia
## sus teclas por la nueva y conserva los eventos que no son de teclado (ratón).
func apply_bindings() -> void:
	var bindings := Settings.get_bindings()
	for action: String in SettingsSchema.REBINDABLE:
		InputMap.action_erase_events(action)
		var defaults: Array = _default_events.get(action, [])
		for event: Variant in defaults:
			var input_event := event as InputEvent
			if input_event == null:
				continue
			if bindings.has(action) and input_event is InputEventKey:
				continue
			InputMap.action_add_event(action, input_event)
		if bindings.has(action):
			var key := InputEventKey.new()
			var keycode: int = bindings[action]
			key.physical_keycode = keycode as Key
			InputMap.action_add_event(action, key)


## Nombre visible de la tecla principal de una acción.
func key_label(action: String) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event
			return OS.get_keycode_string(key.physical_keycode)
	return "-"


func _on_settings_changed(key: String) -> void:
	if key == "bindings":
		apply_bindings()


## Dirección de movimiento: x = lateral, y = adelante (fuerzas entre -1 y 1).
func move_vector() -> Vector2:
	var vector := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	return vector.limit_length(1.0)


## Devuelve y limpia el giro de cámara acumulado (radianes: x = guiñada, y = cabeceo).
func consume_look() -> Vector2:
	var result := _look_delta
	_look_delta = Vector2.ZERO
	if Settings.get_bool("invert_y"):
		result.y = -result.y
	return result


## Suma giro ya en radianes (x = guiñada, y = cabeceo), sin cambiar el modo de control.
## Lo usan controladores automáticos como el bot de recorrido.
func add_look_radians(radians: Vector2) -> void:
	_look_delta += radians


## Suma giro desde los controles táctiles (píxeles de arrastre).
func add_touch_look(pixels: Vector2) -> void:
	_look_delta += pixels * Rules.LOOK_TOUCH_RADIANS * Settings.get_float("touch_sensitivity")
	_set_touch_mode(true)


func is_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action)


func just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)


## Pulsa o suelta una acción desde un control táctil.
func press_action(action: StringName, strength: float = 1.0) -> void:
	Input.action_press(action, strength)


func release_action(action: StringName) -> void:
	Input.action_release(action)


## Pide capturar el puntero (solo PC y durante el juego). Debe llamarse desde un gesto.
func request_capture() -> void:
	if can_capture():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Se puede capturar el puntero: jugando, con teclado y ratón y sin un menú abierto.
func can_capture() -> bool:
	return gameplay_active and not touch_mode and not menu_open


func release_capture() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_had_capture = false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_touch_mode(true)
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and gameplay_active:
			var factor := Rules.LOOK_MOUSE_RADIANS * Settings.get_float("mouse_sensitivity")
			_look_delta += motion.screen_relative * factor
	elif event is InputEventMouseButton or event is InputEventKey:
		if event.is_pressed():
			_set_touch_mode(false)
		if event is InputEventMouseButton and event.is_pressed():
			request_capture()


func _process(_delta: float) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _had_capture and not captured and gameplay_active and not touch_mode:
		# El navegador soltó el puntero (Esc o cambio de pestaña): se pausa y se explica.
		EventBus.pause_requested.emit()
	_had_capture = captured


func _set_touch_mode(value: bool) -> void:
	if touch_mode == value:
		return
	touch_mode = value
	if touch_mode:
		release_capture()
	EventBus.input_mode_changed.emit(touch_mode)

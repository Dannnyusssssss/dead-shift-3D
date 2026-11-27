extends Node
## Ajustes del jugador en memoria. Se cargan validados al arrancar y se guardan al cambiar.

var _values: Dictionary = {}


func _ready() -> void:
	var first_run := not SaveStore.has_settings()
	_values = SaveStore.load_settings()
	if first_run:
		_values["quality"] = Config.default_quality()
	apply_quality()
	apply_interface()


func get_float(key: String) -> float:
	var value: Variant = _values.get(key, 0.0)
	return value if value is float else 0.0


func get_int(key: String) -> int:
	var value: Variant = _values.get(key, 0)
	return value if value is int else 0


## Teclas reasignadas (acción -> código físico); las demás usan las de fábrica.
func get_bindings() -> Dictionary:
	var value: Variant = _values.get("bindings", {})
	return value if value is Dictionary else {}


## Teclas actuales de una acción reasignable: la reasignada o, si no hay, las de fábrica.
func action_keys(action: String) -> Array[int]:
	var result: Array[int] = []
	var bindings := get_bindings()
	if bindings.has(action):
		var keycode: int = bindings[action]
		result.append(keycode)
		return result
	var defaults: Array = SettingsSchema.DEFAULT_BINDINGS.get(action, [])
	for keycode: Variant in defaults:
		var key_value: int = keycode
		result.append(key_value)
	return result


## Otra acción reasignable que ya usa la tecla ("" si ninguna).
func binding_owner(keycode: int, except_action: String) -> String:
	for other: String in SettingsSchema.REBINDABLE:
		if other != except_action and action_keys(other).has(keycode):
			return other
	return ""


## Reasigna la tecla de una acción. Si otra acción reasignable ya la usa, se intercambian: la
## otra recibe la tecla principal que tenía esta. Devuelve falso si la tecla no se permite (o
## no se pudo guardar el cambio entero) y entonces no cambia nada.
func set_binding(action: String, keycode: int) -> bool:
	if not SettingsSchema.REBINDABLE.has(action):
		return false
	var previous := get_bindings().duplicate()
	var bindings := previous.duplicate()
	var owner := binding_owner(keycode, action)
	if not owner.is_empty():
		var own_keys := action_keys(action)
		if own_keys.is_empty():
			return false
		bindings[owner] = own_keys[0]
	bindings[action] = keycode
	set_value("bindings", bindings)
	var stored := get_bindings()
	var applied: bool = stored.get(action, -1) == keycode
	if applied and not owner.is_empty():
		applied = stored.get(owner, -1) == bindings[owner]
	if not applied:
		set_value("bindings", previous)
	return applied


## Vuelve a las teclas de fábrica.
func reset_bindings() -> void:
	set_value("bindings", {})


func get_bool(key: String) -> bool:
	var value: Variant = _values.get(key, false)
	return value if value is bool else false


## Cambia un ajuste pasando por el mismo esquema que los datos guardados, lo guarda y avisa.
## Las claves desconocidas se ignoran.
func set_value(key: String, value: Variant) -> void:
	if not _values.has(key):
		return
	var candidate: Dictionary = _values.duplicate()
	candidate[key] = value
	var checked: Dictionary = Validation.parse_settings(
		SaveCodec.encode(candidate, SettingsSchema.VERSION)
	)
	_values[key] = checked[key]
	SaveStore.save_settings(_values)
	if key == "quality":
		apply_quality()
	if key == "ui_scale":
		apply_interface()
	EventBus.settings_changed.emit(key)


## Vuelve a los valores por defecto (tras borrar los datos guardados) sin guardarlos.
func reset_to_defaults() -> void:
	_values = SettingsSchema.defaults()
	_values["quality"] = Config.default_quality()
	apply_quality()
	apply_interface()
	for key: String in _values:
		EventBus.settings_changed.emit(key)


## Tema común y tamaño de toda la interfaz (texto y botones) en la ventana principal; no
## afecta a la vista 3D.
func apply_interface() -> void:
	var window := get_tree().root
	if window.theme == null:
		window.theme = UiTheme.build()
	window.content_scale_factor = clampf(get_float("ui_scale"), 0.8, 1.5)


## Aplica el nivel de calidad a la vista principal: escala de resolución 3D y antialiasing.
func apply_quality() -> void:
	var level := clampi(get_int("quality"), 0, Rules.QUALITY_RENDER_SCALE.size() - 1)
	var viewport := get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = Rules.QUALITY_RENDER_SCALE[level]
	viewport.msaa_3d = Rules.QUALITY_MSAA[level] as Viewport.MSAA

extends Node
## Ajustes del jugador en memoria. Se cargan validados al arrancar y se guardan al cambiar.

var _values: Dictionary = {}


func _ready() -> void:
	var first_run := not SaveStore.has_settings()
	_values = SaveStore.load_settings()
	if first_run:
		_values["quality"] = Config.default_quality()
	apply_quality()


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


## Reasigna la tecla de una acción. Devuelve falso si la tecla no se permite o ya está en uso.
func set_binding(action: String, keycode: int) -> bool:
	var bindings := get_bindings().duplicate()
	bindings[action] = keycode
	set_value("bindings", bindings)
	return get_bindings().get(action, -1) == keycode


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
	EventBus.settings_changed.emit(key)


## Vuelve a los valores por defecto (tras borrar los datos guardados) sin guardarlos.
func reset_to_defaults() -> void:
	_values = SettingsSchema.defaults()
	_values["quality"] = Config.default_quality()
	apply_quality()
	for key: String in _values:
		EventBus.settings_changed.emit(key)


## Aplica el nivel de calidad a la vista principal: escala de resolución 3D y antialiasing.
func apply_quality() -> void:
	var level := clampi(get_int("quality"), 0, Rules.QUALITY_RENDER_SCALE.size() - 1)
	var viewport := get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = Rules.QUALITY_RENDER_SCALE[level]
	viewport.msaa_3d = Rules.QUALITY_MSAA[level] as Viewport.MSAA

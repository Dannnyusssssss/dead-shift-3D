class_name TapButton
extends Button
## Botón que también responde a toques. El proyecto no convierte toques en clics de ratón
## (evita disparos accidentales), así que los botones de menú escuchan el toque directamente.
## Mínimo de 44 px CSS de alto y de ancho, igual que los controles táctiles, recalculado si
## cambia el tamaño de la pantalla (por ejemplo, al girar el celular).

var _touch_inside: bool = false
## Tamaño mínimo pedido por quien creó el botón (antes de aplicar el mínimo táctil).
var _base_minimum: Vector2 = Vector2.ZERO


func _ready() -> void:
	_base_minimum = custom_minimum_size
	focus_mode = Control.FOCUS_ALL
	_apply_minimum()
	get_viewport().size_changed.connect(_apply_minimum)


func _apply_minimum() -> void:
	var minimum := _min_height()
	custom_minimum_size = Vector2(maxf(_base_minimum.x, minimum), maxf(_base_minimum.y, minimum))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_touch_inside = true
		elif _touch_inside:
			_touch_inside = false
			if Rect2(Vector2.ZERO, size).has_point(touch.position) and not disabled:
				pressed.emit()
		accept_event()


func _min_height() -> float:
	var canvas_scale := get_viewport().get_final_transform().get_scale().y
	if canvas_scale <= 0.0:
		return Rules.TOUCH_MIN_TARGET_PX
	return Rules.TOUCH_MIN_TARGET_PX * maxf(DisplayServer.screen_get_scale(), 1.0) / canvas_scale

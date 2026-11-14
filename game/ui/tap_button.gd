class_name TapButton
extends Button
## Botón que también responde a toques. El proyecto no convierte toques en clics de ratón
## (evita disparos accidentales), así que los botones de menú escuchan el toque directamente.
## Mínimo de 44 px CSS de alto, igual que los controles táctiles.

var _touch_inside: bool = false


func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, _min_height())
	focus_mode = Control.FOCUS_ALL


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

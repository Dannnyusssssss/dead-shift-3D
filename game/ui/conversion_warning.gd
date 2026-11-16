class_name ConversionWarning
extends Control
## Aviso de que falta poco para convertirse (infección sin curar): en los últimos
## WARNING_SECONDS los bordes de la pantalla se oscurecen en verde y laten despacio (menos de un
## latido por segundo, muy por debajo de 3 destellos) y aparece un texto con la cuenta atrás (se
## entiende sin sonido y sin color). Con «Reducir movimiento» o «Reducir destellos» el borde queda
## fijo. Se quita al curarse.

const WARNING_SECONDS: float = 30.0
const PULSE_RATE: float = 0.8
const EDGE_COLOR: Color = Color(0.12, 0.25, 0.06)

var _vignette: TextureRect = null
var _text: Label = null
var _time: float = 0.0
var _announced: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = TextureRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.texture = _edge_texture()
	add_child(_vignette)
	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 30)
	_text.add_theme_color_override("font_color", Color(0.85, 1.0, 0.6))
	_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_text.add_theme_constant_override("outline_size", 10)
	_text.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_text.offset_left = -420.0
	_text.offset_right = 420.0
	_text.offset_top = -230.0
	_text.offset_bottom = -190.0
	add_child(_text)
	visible = false


## Si el aviso se está mostrando (para las pruebas).
func is_warning() -> bool:
	return visible


func _process(delta: float) -> void:
	var state := GameState.player
	var active := (
		state != null
		and state.infection.infected
		and not state.infection.is_converted()
		and state.infection.time_left <= WARNING_SECONDS
	)
	visible = active
	if not active:
		_announced = false
		return
	if not _announced:
		_announced = true
		EventBus.user_message.emit("msg_conversion_soon")
	_time += delta
	var steady := Settings.get_bool("reduce_motion") or Settings.get_bool("reduce_flashes")
	var strength := 0.75 if steady else 0.6 + 0.3 * sin(_time * TAU * PULSE_RATE)
	_vignette.modulate.a = strength
	_text.text = tr("hud_conversion_soon") % ceili(state.infection.time_left)


## Degradado radial: transparente en el centro y oscuro en los bordes.
func _edge_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(EDGE_COLOR, 0.0))
	gradient.set_color(1, Color(EDGE_COLOR, 0.9))
	gradient.add_point(0.55, Color(EDGE_COLOR, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 256
	texture.height = 256
	return texture

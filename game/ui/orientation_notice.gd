class_name OrientationNotice
extends CanvasLayer
## Aviso en celular con la pantalla en vertical: el juego se juega en horizontal. Tapa la
## pantalla mientras dura y, si había una partida en marcha, la pausa.

const LAYER: int = 120

var _cover: ColorRect = null


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = ColorRect.new()
	_cover.color = Color(0.02, 0.02, 0.03, 0.96)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cover)
	var label := Label.new()
	label.text = tr("orientation_rotate")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 28)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 24.0
	label.offset_right = -24.0
	_cover.add_child(label)
	get_viewport().size_changed.connect(_update)
	_update()


## Verdadero si hay que pedir que se gire: táctil y más alta que ancha.
static func needs_rotation(touch: bool, screen: Vector2) -> bool:
	return touch and screen.y > screen.x


func _update() -> void:
	var show := needs_rotation(Config.is_touch, get_viewport().get_visible_rect().size)
	_cover.visible = show
	if show and InputRouter.gameplay_active:
		EventBus.pause_requested.emit()

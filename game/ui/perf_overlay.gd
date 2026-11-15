class_name PerfOverlay
extends Label
## Overlay de rendimiento: FPS, tiempo de frame, llamadas de dibujo, primitivas y memoria.
## Se activa con el ajuste «Mostrar rendimiento» o la tecla F3 (alterna el ajuste).

const REFRESH: float = 0.5

var _timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -330.0
	offset_top = 12.0
	offset_right = -10.0
	offset_bottom = 152.0
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 6)
	visible = Settings.get_bool("show_performance")
	EventBus.settings_changed.connect(_on_settings_changed)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		Settings.set_value("show_performance", not Settings.get_bool("show_performance"))


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var video := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	text = (
		"FPS %d\nframe %.1f ms\ndraw calls %d\nprimitivas %d\nmemoria de video %.0f MB"
		% [fps, frame_ms, draws, primitives, video]
	)
	# La memoria del programa solo se mide en las versiones de desarrollo (en la exportada es 0).
	var memory := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	if memory > 0.0:
		text += "\nmemoria %.0f MB" % memory


func _on_settings_changed(key: String) -> void:
	if key == "show_performance":
		visible = Settings.get_bool("show_performance")

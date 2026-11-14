class_name Subtitles
extends PanelContainer
## Subtítulos de sonidos clave con dirección («[Gruñido, a la izquierda]»), para poder jugar
## sin audio. Se activan en Opciones. Máximo de líneas a la vez; un mismo sonido desde la
## misma dirección renueva su línea en vez de repetirla.

const MAX_LINES: int = 3
const LINE_TIME: float = 3.0

## Líneas visibles: [clave del sonido, clave de dirección, segundos restantes].
var lines: Array[Array] = []

var _box: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	visible = false
	EventBus.sound_cue.connect(_on_sound_cue)


func _process(delta: float) -> void:
	if lines.is_empty():
		return
	var changed := false
	for line: Array in lines:
		var left: float = line[2]
		line[2] = left - delta
	for index: int in range(lines.size() - 1, -1, -1):
		var left: float = lines[index][2]
		if left <= 0.0:
			lines.remove_at(index)
			changed = true
	if changed:
		_render()


## Añade un subtítulo. Pública para las pruebas; el juego llega aquí por sound_cue.
func show_cue(cue_key: String, direction_key: String) -> void:
	if not Settings.get_bool("subtitles"):
		return
	for line: Array in lines:
		if line[0] == cue_key and line[1] == direction_key:
			line[2] = LINE_TIME
			return
	lines.append([cue_key, direction_key, LINE_TIME])
	while lines.size() > MAX_LINES:
		lines.remove_at(0)
	_render()


func _on_sound_cue(cue_key: String, origin: Vector3) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var direction := SoundDirection.FRONT
	if player != null and player.is_inside_tree():
		direction = SoundDirection.key_for(player.camera.global_transform, origin)
	show_cue(cue_key, direction)


func _render() -> void:
	for child: Node in _box.get_children():
		child.queue_free()
	for line: Array in lines:
		var label := Label.new()
		var cue: String = line[0]
		var direction: String = line[1]
		label.text = "[%s, %s]" % [tr(cue), tr(direction)]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		_box.add_child(label)
	visible = not lines.is_empty()

class_name EndScreen
extends Control
## Pantalla de fin del corte: muerte o planta superada, con estadísticas y «Jugar de nuevo».

signal restart_requested

var _title: Label = null
var _stats: Label = null
var _button: TapButton = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	box.add_child(_title)
	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_theme_font_size_override("font_size", 22)
	box.add_child(_stats)
	_button = TapButton.new()
	_button.text = tr("end_play_again")
	_button.custom_minimum_size = Vector2(300.0, 64.0)
	_button.add_theme_font_size_override("font_size", 26)
	_button.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(_button)


func show_result(won: bool, seconds: float) -> void:
	_title.text = tr("end_floor_cleared") if won else tr("end_dead")
	var state := GameState.player
	_stats.text = (
		"%s %d:%02d\n%s %d\n%s %d"
		% [
			tr("end_time"),
			int(seconds) / 60,
			int(seconds) % 60,
			tr("end_weapons_broken"),
			state.weapons_broken,
			tr("end_crafted"),
			state.items_crafted,
		]
	)
	visible = true
	InputRouter.gameplay_active = false
	InputRouter.release_capture()
	_button.grab_focus()

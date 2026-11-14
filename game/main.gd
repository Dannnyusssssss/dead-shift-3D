extends Control
## Pantalla de inicio: nombre del juego, aviso de contenido (antes de la primera partida) y
## «Jugar». El toque o clic en «Jugar» es el gesto que el navegador exige para capturar el
## puntero y, más adelante, para el audio.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")

var _menu: Control = null
var _game: Game = null
var _play: TapButton = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_menu()
	_play.grab_focus()


func _start_game() -> void:
	_menu.visible = false
	_game = GAME_SCRIPT.new()
	_game.restart_requested.connect(_restart)
	add_child(_game)
	InputRouter.request_capture()


func _restart() -> void:
	if _game != null:
		_game.queue_free()
		_game = null
	GameState.set_paused(false)
	_start_game.call_deferred()


func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var background := ColorRect.new()
	background.color = Color(0.03, 0.03, 0.04)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	var title := Label.new()
	title.text = Meta.GAME_NAME
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	box.add_child(title)
	var notice := Label.new()
	notice.text = tr("start_content_notice")
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD
	notice.custom_minimum_size.x = 640.0
	notice.add_theme_font_size_override("font_size", 22)
	box.add_child(notice)
	var controls := Label.new()
	controls.text = tr("start_controls")
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD
	controls.custom_minimum_size.x = 640.0
	controls.add_theme_font_size_override("font_size", 18)
	box.add_child(controls)
	_play = TapButton.new()
	_play.text = tr("start_play")
	_play.custom_minimum_size = Vector2(300.0, 70.0)
	_play.add_theme_font_size_override("font_size", 30)
	_play.pressed.connect(_start_game)
	box.add_child(_play)

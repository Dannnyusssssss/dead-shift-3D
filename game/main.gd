extends Control
## Pantalla de inicio: nombre del juego, aviso de contenido y menú: «Continuar» (si hay una
## partida guardada válida), «Nueva partida» (pide confirmación si se perdería la guardada) y
## «Borrar datos guardados» (con confirmación). Muestra la mejor nota del dispositivo. El toque
## o clic en un botón es el gesto que el navegador exige para capturar el puntero y, más
## adelante, para el audio.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")

var _menu: Control = null
var _game: Game = null
var _continue: TapButton = null
var _play: TapButton = null
var _delete: TapButton = null
var _options: OptionsMenu = null
var _status: Label = null
var _play_armed: bool = false
var _delete_armed: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_menu()
	_refresh_menu()


## Partida guardada válida, o vacío si no hay o no se puede leer.
func _saved_run() -> Dictionary:
	if not SaveStore.has_game():
		return {}
	var result := SaveStore.load_game(GameState.CATALOG.save_context())
	return result.data if result.ok else {}


func _refresh_menu() -> void:
	var saved := _saved_run()
	_continue.visible = not saved.is_empty()
	_play_armed = false
	_delete_armed = false
	_play.text = tr("start_new_game")
	_delete.text = tr("start_delete_data")
	var best := SaveStore.load_best()
	_status.text = "%s %s" % [tr("start_best_grade"), best] if not best.is_empty() else ""
	if _continue.visible:
		_continue.grab_focus()
	else:
		_play.grab_focus()


func _start_game(data: Dictionary) -> void:
	_menu.visible = false
	_game = GAME_SCRIPT.new()
	_game.start_data = data
	_game.restart_requested.connect(_restart)
	_game.continue_requested.connect(_continue_from_save)
	add_child(_game)
	InputRouter.request_capture()


func _on_continue() -> void:
	var saved := _saved_run()
	if saved.is_empty():
		_status.text = tr("msg_save_unreadable")
		_continue.visible = false
		return
	_start_game(saved)


## Empezar de nuevo sobrescribe la única ranura al primer autoguardado: se confirma.
func _on_new_game() -> void:
	if SaveStore.has_game() and not _play_armed:
		_play_armed = true
		_play.text = tr("start_new_game_confirm")
		return
	_start_game({})


func _on_delete() -> void:
	if not _delete_armed:
		_delete_armed = true
		_delete.text = tr("start_delete_confirm")
		return
	SaveStore.delete_all()
	Settings.reset_to_defaults()
	_refresh_menu()
	_status.text = tr("start_deleted")


func _on_options() -> void:
	_options.open()


func _restart() -> void:
	_close_game()
	_start_game.call_deferred({})


func _continue_from_save() -> void:
	var saved := _saved_run()
	_close_game()
	if saved.is_empty():
		_show_menu.call_deferred()
		return
	_start_game.call_deferred(saved)


func _close_game() -> void:
	if _game != null:
		_game.queue_free()
		_game = null
	GameState.set_paused(false)


func _show_menu() -> void:
	_menu.visible = true
	_refresh_menu()


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
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title := Label.new()
	title.text = Meta.GAME_NAME
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	box.add_child(title)
	box.add_child(_text(tr("start_content_notice"), 22))
	box.add_child(_text(tr("start_controls"), 18))
	_continue = _button(box, "start_continue", _on_continue)
	_play = _button(box, "start_new_game", _on_new_game)
	_button(box, "options_title", _on_options)
	_delete = _button(box, "start_delete_data", _on_delete)
	_delete.add_theme_font_size_override("font_size", 20)
	_status = _text("", 20)
	box.add_child(_status)
	_options = OptionsMenu.new()
	_menu.add_child(_options)
	_options.closed.connect(func() -> void: _refresh_menu())


func _text(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size.x = 640.0
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(parent: Control, text_key: String, action: Callable) -> TapButton:
	var button := TapButton.new()
	button.text = tr(text_key)
	button.custom_minimum_size = Vector2(360.0, 64.0)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

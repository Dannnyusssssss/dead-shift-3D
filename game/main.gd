extends Control
## Pantalla de inicio: nombre del juego, aviso de contenido y menú: «Continuar» (si hay una
## partida guardada válida), «Nueva partida» (pide confirmación si se perdería la guardada y
## luego la dificultad) y «Borrar datos guardados» (con confirmación). Muestra la mejor nota del
## dispositivo en cada dificultad. El toque
## o clic en un botón es el gesto que el navegador exige para capturar el puntero y, más
## adelante, para el audio.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")

var _menu: Control = null
## Botones del menú principal (se esconden mientras se elige la dificultad).
var _main_box: VBoxContainer = null
var _difficulty_box: VBoxContainer = null
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
	_show_difficulties(false)
	_status.text = _best_text()
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


## Empezar de nuevo sobrescribe la única ranura al primer autoguardado: se confirma. Después se
## elige la dificultad.
func _on_new_game() -> void:
	if SaveStore.has_game() and not _play_armed:
		_play_armed = true
		_play.text = tr("start_new_game_confirm")
		return
	_show_difficulties(true)


func _on_difficulty(difficulty_id: String) -> void:
	GameState.next_difficulty = difficulty_id
	_start_game({})


## Cambia entre el menú principal y la elección de dificultad.
func _show_difficulties(choosing: bool) -> void:
	_main_box.visible = not choosing
	_difficulty_box.visible = choosing
	if choosing:
		var first: Control = _difficulty_box.get_child(1)
		first.grab_focus()


## «Mejor nota: Fácil A · Medio B» con las dificultades que tengan nota.
func _best_text() -> String:
	var grades := SaveStore.load_best_all()
	var parts: Array[String] = []
	for difficulty: DifficultyData in GameState.CATALOG.difficulties:
		if grades.has(difficulty.id):
			parts.append("%s %s" % [tr(difficulty.name_key), grades[difficulty.id]])
	if parts.is_empty():
		return ""
	return "%s %s" % [tr("start_best_grade"), " · ".join(parts)]


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
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 16)
	box.add_child(_main_box)
	_continue = _button(_main_box, "start_continue", _on_continue)
	_play = _button(_main_box, "start_new_game", _on_new_game)
	_button(_main_box, "options_title", _on_options)
	_delete = _button(_main_box, "start_delete_data", _on_delete)
	_delete.add_theme_font_size_override("font_size", 20)
	_build_difficulties(box)
	_status = _text("", 20)
	box.add_child(_status)
	_options = OptionsMenu.new()
	_menu.add_child(_options)
	_options.closed.connect(func() -> void: _refresh_menu())


## Elección de dificultad: título, un botón por dificultad con su descripción corta y «Volver».
func _build_difficulties(parent: Control) -> void:
	_difficulty_box = VBoxContainer.new()
	_difficulty_box.add_theme_constant_override("separation", 10)
	_difficulty_box.visible = false
	parent.add_child(_difficulty_box)
	_difficulty_box.add_child(_text(tr("start_choose_difficulty"), 28))
	for difficulty: DifficultyData in GameState.CATALOG.difficulties:
		_button(_difficulty_box, difficulty.name_key, _on_difficulty.bind(difficulty.id))
		_difficulty_box.add_child(_text(tr(difficulty.description_key), 18))
	var back := _button(_difficulty_box, "start_back", _refresh_menu)
	back.add_theme_font_size_override("font_size", 20)


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

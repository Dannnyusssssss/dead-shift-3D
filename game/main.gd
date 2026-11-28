extends Control
## Pantalla de inicio: nombre del juego, aviso de contenido y menú: «Continuar» (si hay una
## partida guardada válida), «Nueva partida» (pide confirmación si se perdería la guardada y
## luego la dificultad) y «Borrar datos guardados» (con confirmación). Muestra la mejor nota del
## dispositivo en cada dificultad. El toque
## o clic en un botón es el gesto que el navegador exige para capturar el puntero y, más
## adelante, para el audio.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")
## Margen (unidades de la interfaz) que debe quedar libre en el menú; si no, se oculta el texto de
## controles (en un celular en horizontal no cabe junto a todos los botones, y allí los
## controles ya se ven en pantalla). El aviso de edad se muestra siempre.
const MENU_MARGIN: float = 24.0
## Sesión de medición del export del banco de rendimiento.
const BENCH_SCRIPT_PATH: String = "res://tests/bench/web_bench.gd"

var _menu: Control = null
## Botones del menú principal (se esconden mientras se elige la dificultad).
var _main_box: VBoxContainer = null
var _difficulty_box: VBoxContainer = null
## Columna del menú principal (para saber si todo cabe en pantalla).
var _menu_column: VBoxContainer = null
## Aviso de contenido y controles: se esconden al elegir la dificultad para que quepa «Volver».
var _info_labels: Array[Label] = []
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
	if OS.has_feature("bench"):
		_start_bench()
		return
	add_child(OrientationNotice.new())
	_build_menu()
	get_viewport().size_changed.connect(_fit_short_screen)
	_refresh_menu()


## Solo en el export del banco de rendimiento (etiqueta «bench», que el export publicado no
## tiene y que además excluye la carpeta de pruebas): sin menú, arranca la sesión de medición.
func _start_bench() -> void:
	var script := load(BENCH_SCRIPT_PATH) as GDScript
	if script != null and script.can_instantiate():
		add_child(script.new() as Node)


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


## wake_up: partida nueva justo después de la intro (empieza con el guardia despertando).
func _start_game(data: Dictionary, wake_up: bool = false) -> void:
	_menu.visible = false
	_game = GAME_SCRIPT.new()
	_game.start_data = data
	_game.wake_up_on_start = wake_up
	_game.restart_requested.connect(_restart)
	_game.continue_requested.connect(_continue_from_save)
	_game.menu_requested.connect(_quit_to_menu)
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
	_play_intro()


## Intro de la historia antes de una partida nueva (se puede saltar); después, la partida.
func _play_intro() -> void:
	_menu.visible = false
	var intro := Intro.new()
	intro.finished.connect(
		func() -> void:
			intro.queue_free()
			_start_game({}, true)
	)
	add_child(intro)


## Verdadero si el menú (alto sin el texto de controles + alto de ese texto) cabe en la pantalla.
static func shows_controls_text(menu_height: float, text_height: float, screen: float) -> bool:
	return menu_height + text_height + MENU_MARGIN * 2.0 <= screen


func _fit_short_screen() -> void:
	if _info_labels.size() < 2 or _menu_column == null:
		return
	var controls := _info_labels[1]
	if _difficulty_box.visible:
		controls.visible = false
		return
	controls.visible = false
	var without := _menu_column.get_combined_minimum_size().y
	var text := controls.get_combined_minimum_size().y + 16.0
	controls.visible = shows_controls_text(without, text, get_viewport_rect().size.y)


## Cambia entre el menú principal y la elección de dificultad.
func _show_difficulties(choosing: bool) -> void:
	_main_box.visible = not choosing
	_difficulty_box.visible = choosing
	for label: Label in _info_labels:
		label.visible = not choosing
	_fit_short_screen()
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


## Esc (o la acción de cancelar) en la elección de dificultad vuelve al menú principal.
func _unhandled_input(event: InputEvent) -> void:
	if not _menu.visible or not _difficulty_box.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_refresh_menu()


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
	await _close_game()
	_start_game({})


func _continue_from_save() -> void:
	var saved := _saved_run()
	await _close_game()
	if saved.is_empty():
		_show_menu()
		return
	_start_game(saved)


## Sale de la partida al menú principal (lo no guardado se pierde; la pausa ya lo confirmó).
func _quit_to_menu() -> void:
	InputRouter.gameplay_active = false
	InputRouter.release_capture()
	await _close_game()
	_show_menu()


## Cierra la partida en curso y espera a que se libere de verdad antes de volver. La partida
## nueva no puede convivir con la vieja ni un cuadro: sus nodos (el jefe, el jugador) seguirían
## en los grupos y conectados a las señales globales, y la interfaz nueva mostraba al jefe herido
## de la partida anterior.
func _close_game() -> void:
	GameState.set_paused(false)
	if _game == null:
		return
	var old := _game
	_game = null
	old.queue_free()
	await old.tree_exited
	# La liberación termina al final de este cuadro: se sigue en el siguiente.
	await get_tree().process_frame


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
	_menu_column = box
	var title := Label.new()
	title.text = Meta.GAME_NAME
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	box.add_child(title)
	if Config.is_software_render():
		var warning := _text(tr("start_software_render"), 20)
		warning.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		box.add_child(warning)
	_info_labels = [_text(tr("start_content_notice"), 22), _text(tr("start_controls"), 18)]
	for label: Label in _info_labels:
		box.add_child(label)
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
	_build_footer(_main_box)
	_options = OptionsMenu.new()
	_menu.add_child(_options)
	_options.closed.connect(func() -> void: _refresh_menu())


## Pie del menú: créditos (con las licencias), privacidad y términos.
func _build_footer(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var credits := CreditsView.new()
	var page := TextPageView.new()
	_menu.add_child(credits)
	_menu.add_child(page)
	var entries: Array[Array] = [
		["credits_button", credits.open],
		["start_privacy", page.open.bind("privacy_title", TextPageView.PRIVACY_KEYS)],
		["start_terms", page.open.bind("terms_title", TextPageView.TERMS_KEYS)],
	]
	for entry: Array in entries:
		var button := TapButton.new()
		button.text = tr(entry[0] as String)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(entry[1] as Callable)
		row.add_child(button)
	credits.closed.connect(func() -> void: (row.get_child(0) as Control).grab_focus())
	page.closed.connect(func() -> void: (row.get_child(1) as Control).grab_focus())


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

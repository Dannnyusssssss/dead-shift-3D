class_name PauseMenu
extends Control
## Menú de pausa. Aparece al pulsar «pausa» o cuando el navegador suelta el puntero
## (Esc, cambio de pestaña) y explica cómo volver. Funciona con ratón, teclado y toque.

const QUALITY_KEYS: Array[String] = ["quality_low", "quality_medium", "quality_high"]

var _continue: TapButton = null
var _quality: TapButton = null
var _performance: TapButton = null
var _hint: Label = null
var _surrender: TapButton = null
var _save: TapButton = null
var _options: OptionsMenu = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := Label.new()
	title.text = tr("pause_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size.x = 560.0
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.add_theme_font_size_override("font_size", 22)
	box.add_child(_hint)
	_continue = TapButton.new()
	_continue.text = tr("pause_continue")
	_continue.custom_minimum_size = Vector2(280.0, 64.0)
	_continue.add_theme_font_size_override("font_size", 26)
	_continue.pressed.connect(_on_continue)
	box.add_child(_continue)
	_quality = _option_button(box, _on_quality)
	_performance = _option_button(box, _on_performance)
	var options_button := _option_button(box, _on_options)
	options_button.text = tr("options_title")
	_save = _option_button(box, _on_save)
	_save.text = tr("pause_save")
	_surrender = _option_button(box, _on_surrender)
	_surrender.text = tr("pause_surrender")
	_surrender.visible = false
	visible = false
	_options = OptionsMenu.new()
	add_child(_options)
	_options.closed.connect(func() -> void: _continue.grab_focus())
	EventBus.paused_changed.connect(_on_paused_changed)


func _process(_delta: float) -> void:
	# Se lee por acción (no por evento) para que también funcione el botón táctil.
	if not GameState.paused and InputRouter.gameplay_active and InputRouter.just_pressed("pause"):
		GameState.set_paused(true)


func _on_paused_changed(paused: bool) -> void:
	visible = paused
	# Rendirse solo existe tras perder el rescate (final de «rescate perdido»).
	_surrender.visible = (
		paused and GameState.rescue != null and GameState.rescue.state == RescueClock.STATE_DEPARTED
	)
	if paused:
		var key := "pause_hint_touch" if InputRouter.touch_mode else "pause_hint_mouse"
		_hint.text = tr(key)
		_refresh_options()
		_continue.grab_focus()


func _option_button(parent: Control, action: Callable) -> TapButton:
	var button := TapButton.new()
	button.custom_minimum_size = Vector2(420.0, 56.0)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _refresh_options() -> void:
	var level := clampi(Settings.get_int("quality"), 0, QUALITY_KEYS.size() - 1)
	_quality.text = "%s: %s" % [tr("pause_quality"), tr(QUALITY_KEYS[level])]
	var shown := Settings.get_bool("show_performance")
	_performance.text = (
		"%s: %s" % [tr("pause_performance"), tr("option_on" if shown else "option_off")]
	)


## Cambia la calidad en ciclo: Baja, Media, Alta.
func _on_quality() -> void:
	Settings.set_value("quality", (Settings.get_int("quality") + 1) % QUALITY_KEYS.size())
	_refresh_options()


func _on_performance() -> void:
	Settings.set_value("show_performance", not Settings.get_bool("show_performance"))
	_refresh_options()


func _on_continue() -> void:
	GameState.set_paused(false)
	# El clic o toque en «Continuar» es un gesto del usuario: el navegador permite capturar.
	InputRouter.request_capture()


func _on_surrender() -> void:
	EventBus.surrender_requested.emit()


func _on_save() -> void:
	EventBus.save_requested.emit()


func _on_options() -> void:
	_options.open()

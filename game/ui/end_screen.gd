class_name EndScreen
extends Control
## Pantalla final: rescate, rescate perdido (con su texto propio), muerte o conversión. Muestra
## las estadísticas y la nota, y ofrece volver al último autoguardado (si existe), empezar una
## partida nueva o volver al menú principal. Funciona con ratón, teclado y toque. Tras el
## rescate (o su pérdida) sale encima de la escena final, con un fondo más claro para que se
## vea el helicóptero detrás.

signal restart_requested
signal continue_requested
signal menu_requested

const TITLE_KEYS: Array[String] = [
	"end_rescued", "end_lost", "end_dead", "end_converted", "end_crashed"
]
const TEXT_KEYS: Array[String] = [
	"end_rescued_text", "end_lost_text", "end_dead_text", "end_converted_text", "end_crashed_text"
]
## Segundos entre línea y línea al mostrar las estadísticas (de arriba abajo).
const LINE_SECONDS: float = 0.35
## Opacidad del fondo: sobre el juego parado o encima de la escena final.
const SHADE_ALPHA: float = 0.85
const SHADE_OVER_SCENE: float = 0.7
## Encima de la escena final todo va en la parte izquierda (fracción del ancho) y la derecha
## queda libre para ver el helicóptero.
const SCENE_PANEL_WIDTH: float = 0.56
const STORY_WIDTH: float = 760.0
const STORY_WIDTH_OVER_SCENE: float = 600.0

var _title: Label = null
var _story: Label = null
var _stats: Label = null
var _continue_button: TapButton = null
var _button: TapButton = null
var _credits: CreditsView = null
var _reveal: Tween = null
var _shade: ColorRect = null
var _center: CenterContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.0, 0.0, SHADE_ALPHA)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_center.add_child(box)
	_title = _label(box, 44)
	_story = _label(box, 22)
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD
	_story.custom_minimum_size = Vector2(STORY_WIDTH, 0.0)
	_stats = _label(box, 20)
	_continue_button = _button_in(box, "end_continue_save")
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	_button = _button_in(box, "end_play_again")
	_button.pressed.connect(func() -> void: restart_requested.emit())
	var menu_button := _button_in(box, "end_main_menu")
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	var credits_button := _button_in(box, "credits_button")
	_credits = CreditsView.new()
	add_child(_credits)
	credits_button.pressed.connect(_credits.open)
	_credits.closed.connect(func() -> void: credits_button.grab_focus())


## Muestra el desenlace con la dificultad jugada. can_continue habilita volver al último
## autoguardado; over_scene aclara el fondo (la escena final sigue detrás).
func show_result(
	stats: RunStats, can_continue: bool, difficulty: Difficulty = null, over_scene: bool = false
) -> void:
	_shade.color.a = SHADE_OVER_SCENE if over_scene else SHADE_ALPHA
	var right := SCENE_PANEL_WIDTH if over_scene else 1.0
	for part: Control in [_shade, _center]:
		part.anchor_right = right
	_story.custom_minimum_size.x = STORY_WIDTH_OVER_SCENE if over_scene else STORY_WIDTH
	var outcome := clampi(stats.outcome, 0, TITLE_KEYS.size() - 1)
	_title.text = tr(TITLE_KEYS[outcome])
	_story.text = tr(TEXT_KEYS[outcome])
	var lines := summary_lines(stats, difficulty)
	lines.append("%s %s" % [tr("end_grade"), stats.grade()])
	_stats.text = "\n".join(lines)
	_reveal_stats(lines.size())
	var dead := (
		stats.outcome == RunStats.OUTCOME_DEAD or stats.outcome == RunStats.OUTCOME_CONVERTED
	)
	_continue_button.visible = dead and can_continue
	visible = true
	InputRouter.gameplay_active = false
	InputRouter.release_capture()
	if _continue_button.visible:
		_continue_button.grab_focus()
	else:
		_button.grab_focus()


## Las estadísticas aparecen una por una de arriba abajo; con «Reducir movimiento», todas a la
## vez.
func _reveal_stats(count: int) -> void:
	if _reveal != null:
		_reveal.kill()
	_stats.visible_characters = -1
	if Settings.get_bool("reduce_motion") or count <= 1:
		return
	_show_lines(0)
	_reveal = create_tween()
	for line: int in count:
		_reveal.tween_interval(LINE_SECONDS)
		_reveal.tween_callback(_show_lines.bind(line + 1))


## Muestra solo las primeras count líneas de las estadísticas.
func _show_lines(count: int) -> void:
	var lines := _stats.text.split("\n")
	if count >= lines.size():
		_stats.visible_characters = -1
		return
	var characters := 0
	for index: int in count:
		characters += lines[index].length() + 1
	_stats.visible_characters = characters


## Resumen de la partida (también lo usa la pausa): dificultad, tiempo, daño recibido, armas
## rotas, combinaciones, munición, enemigos y piezas del teléfono. Sin la nota final.
static func summary_lines(stats: RunStats, difficulty: Difficulty) -> Array[String]:
	var seconds := int(stats.seconds)
	var difficulty_key := "difficulty_easy"
	if difficulty != null and difficulty.data != null:
		difficulty_key = difficulty.data.name_key
	var keys := GameState.player.keys if GameState.player != null else KeyItems.new()
	var parts := Rules.PHONE_PARTS.size() if keys.phone_assembled else keys.phone_parts_count()
	var lines: Array[String] = [
		"%s %s" % [_text("end_difficulty"), _text(difficulty_key)],
		"%s %d:%02d" % [_text("end_time"), seconds / 60, seconds % 60],
		"%s %d" % [_text("end_damage"), roundi(stats.damage_taken)],
		"%s %d" % [_text("end_weapons_broken"), stats.weapons_broken],
		"%s %d" % [_text("end_crafted"), stats.items_crafted],
		"%s %d" % [_text("end_ammo_left"), stats.ammo_left],
		"%s %d" % [_text("end_kills"), stats.kills],
		"%s %d/%d" % [_text("end_phone_parts"), parts, Rules.PHONE_PARTS.size()],
	]
	return lines


static func _text(key: String) -> String:
	return String(TranslationServer.translate(key))


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Borde oscuro: se lee también encima de la escena final.
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button_in(parent: Control, text_key: String) -> TapButton:
	var button := TapButton.new()
	button.text = tr(text_key)
	button.custom_minimum_size = Vector2(360.0, 54.0)
	button.add_theme_font_size_override("font_size", 24)
	parent.add_child(button)
	return button

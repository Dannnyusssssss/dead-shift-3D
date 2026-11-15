class_name EndScreen
extends Control
## Pantalla final: rescate, rescate perdido (con su texto propio), muerte o conversión. Muestra
## las estadísticas y la nota, y ofrece volver al último autoguardado (si existe) o empezar una
## partida nueva. Funciona con ratón, teclado y toque.

signal restart_requested
signal continue_requested

const TITLE_KEYS: Array[String] = ["end_rescued", "end_lost", "end_dead", "end_converted"]
const TEXT_KEYS: Array[String] = [
	"end_rescued_text", "end_lost_text", "end_dead_text", "end_converted_text"
]

var _title: Label = null
var _story: Label = null
var _stats: Label = null
var _continue_button: TapButton = null
var _button: TapButton = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	_title = _label(box, 44)
	_story = _label(box, 22)
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD
	_story.custom_minimum_size = Vector2(760.0, 0.0)
	_stats = _label(box, 22)
	_continue_button = _button_in(box, "end_continue_save")
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	_button = _button_in(box, "end_play_again")
	_button.pressed.connect(func() -> void: restart_requested.emit())


## Muestra el desenlace con la dificultad jugada. can_continue habilita volver al último
## autoguardado.
func show_result(stats: RunStats, can_continue: bool, difficulty: Difficulty = null) -> void:
	var outcome := clampi(stats.outcome, 0, TITLE_KEYS.size() - 1)
	_title.text = tr(TITLE_KEYS[outcome])
	_story.text = tr(TEXT_KEYS[outcome])
	var lines := summary_lines(stats, difficulty)
	lines.append("%s %s" % [tr("end_grade"), stats.grade()])
	_stats.text = "\n".join(lines)
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
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button_in(parent: Control, text_key: String) -> TapButton:
	var button := TapButton.new()
	button.text = tr(text_key)
	button.custom_minimum_size = Vector2(360.0, 64.0)
	button.add_theme_font_size_override("font_size", 24)
	parent.add_child(button)
	return button

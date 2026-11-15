class_name HealingPanel
extends PanelContainer
## Panel lateral de la acción de manos en curso: curación (qué se usa y qué hará, con la cifra
## antes y después) o combinación (los dos objetos y el resultado). Barra de progreso y aviso de
## que mientras tanto no se puede atacar. Al terminar muestra el resultado un momento. No
## depende del color: todo lleva texto.

const RESULT_TIME: float = 1.6

var _player: Player = null
var _title: Label = null
var _item: Label = null
var _effect: Label = null
var _bar: ProgressBar = null
var _warning: Label = null
var _was_active: bool = false
## Verdadero mientras el panel muestra una combinación: al terminar se oculta.
var _crafting_shown: bool = false
var _last_progress: float = 0.0
var _result_timer: float = 0.0
var _last_item: ItemData = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.06, 0.82)
	style.border_color = Color(0.55, 0.85, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_title = _label(column, 24)
	_item = _label(column, 20)
	_effect = _label(column, 20)
	_effect.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0.0, 18.0)
	_bar.show_percentage = false
	column.add_child(_bar)
	_warning = _label(column, 18)
	_warning.text = tr("heal_exposed")
	_warning.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))


func bind_player(player: Player) -> void:
	_player = player


func _process(delta: float) -> void:
	var healing := _player.healing if _player != null else null
	var crafting := _player.crafting if _player != null else null
	var active := healing != null and healing.active
	if crafting != null and crafting.active:
		_show_crafting(crafting.description(), crafting.progress())
		_crafting_shown = true
		_was_active = false
		return
	if _crafting_shown:
		# La combinación terminó o se canceló: el resultado ya lo dice el mensaje de la partida.
		_crafting_shown = false
		visible = false
	if active:
		var item := healing.current_item()
		if item != _last_item or not _was_active:
			_show_item(item)
		_last_progress = healing.progress()
		_bar.value = _last_progress * 100.0
		_result_timer = 0.0
		visible = true
	elif _was_active:
		# Terminó: si llegó al final se muestra el resultado; si se interrumpió, se oculta.
		if _last_progress >= 0.9:
			_show_result()
		else:
			visible = false
	elif _result_timer > 0.0:
		_result_timer -= delta
		if _result_timer <= 0.0:
			visible = false
	_was_active = active


func _show_crafting(parts: Array[String], progress: float) -> void:
	visible = parts.size() == 3
	if not visible:
		return
	_last_item = null
	_title.text = tr("craft_action")
	var names := "%s + %s" % [_name(parts[0]), _name(parts[1])]
	_item.text = names + (" → " + _name(parts[2]) if not parts[2].is_empty() else "")
	_effect.text = tr("craft_noise")
	_bar.visible = true
	_warning.visible = true
	_bar.value = progress * 100.0
	_result_timer = 0.0


func _name(item_id: String) -> String:
	var item := GameState.items.get_item(item_id)
	return tr(item.name_key) if item != null else item_id


func _show_item(item: ItemData) -> void:
	_last_item = item
	_warning.visible = true
	_bar.visible = true
	_title.text = tr(_action_key(item))
	_item.text = tr(item.name_key) if item != null else ""
	_effect.text = _effect_text(item)


func _show_result() -> void:
	_title.text = tr("heal_done")
	_effect.text = _now_text()
	_bar.visible = false
	_warning.visible = false
	_result_timer = RESULT_TIME


func _action_key(item: ItemData) -> String:
	if item == null:
		return "heal_action_heal"
	match item.use_effect:
		ItemData.EFFECT_DELAY_INFECTION:
			return "heal_action_antibiotics"
		ItemData.EFFECT_CURE_INFECTION:
			return "heal_action_cure"
	return "heal_action_heal"


## Lo que hará la cura, con la cifra de ahora y la de después.
func _effect_text(item: ItemData) -> String:
	var state := GameState.player
	if item == null or state == null:
		return ""
	match item.use_effect:
		ItemData.EFFECT_HEAL:
			var after := minf(state.health + item.heal_amount, Rules.PLAYER_MAX_HEALTH)
			return (
				tr("heal_effect_health")
				% [roundi(after - state.health), ceili(state.health), ceili(after)]
			)
		ItemData.EFFECT_DELAY_INFECTION:
			var left := state.infection.time_left
			var later := minf(left + Rules.ANTIBIOTIC_BONUS, Rules.INFECTION_TIME)
			# La diferencia se redondea: con ceili, 189,9 - 99,9 = 90,0000001 mostraba «+91 s».
			return tr("heal_effect_time") % [roundi(later - left), _clock(left), _clock(later)]
		ItemData.EFFECT_CURE_INFECTION:
			return tr("heal_effect_cure")
	return ""


## Cifra después de usarla (salud o cuenta de la infección).
func _now_text() -> String:
	var state := GameState.player
	if state == null or _last_item == null:
		return ""
	if _last_item.use_effect == ItemData.EFFECT_HEAL:
		return "%s %d" % [tr("hud_health"), ceili(state.health)]
	if state.infection.infected:
		return "%s %s" % [tr("hud_infected"), _clock(state.infection.time_left)]
	return tr("msg_infection_cured")


func _clock(seconds: float) -> String:
	var whole := ceili(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(label)
	return label

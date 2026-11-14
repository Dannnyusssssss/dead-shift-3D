class_name BossBar
extends VBoxContainer
## Indicadores del jefe: radiación por cercanía (texto y barras, se anuncia de forma gradual
## antes de verlo) y, durante el combate, su nombre, fase y vida. No dependen del color.

const RADIATION_ICONS: Array[String] = ["", "[#--]", "[##-]", "[###]"]

var _radiation: Label = null
var _name: Label = null
var _bar: ProgressBar = null
var _level: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	_radiation = _label(22)
	_name = _label(24)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(420.0, 18.0)
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	EventBus.boss_proximity.connect(_on_proximity)
	EventBus.boss_changed.connect(_refresh)
	EventBus.floor_changed.connect(func(_floor_id: String) -> void: _on_proximity(0))
	_refresh()


func _on_proximity(level: int) -> void:
	_level = clampi(level, 0, 3)
	if _level == 0:
		_radiation.text = ""
	else:
		_radiation.text = (
			"%s %s %s"
			% [tr("hud_radiation"), RADIATION_ICONS[_level], tr("hud_radiation_%d" % _level)]
		)
	_refresh()


func _refresh() -> void:
	var boss := get_tree().get_first_node_in_group("boss") as Boss
	var fighting := (
		boss != null
		and boss.model != null
		and boss.boss_state != Boss.B_IDLE
		and boss.boss_state != Boss.B_DEAD
	)
	_name.visible = fighting
	_bar.visible = fighting
	if not fighting:
		return
	var text := tr(boss.data.name_key)
	if boss.model.phase == BossModel.PHASE_TWO:
		text += "  (%s)" % tr("hud_boss_phase_two")
	_name.text = text
	_bar.value = boss.model.health_fraction() * 100.0


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	return label

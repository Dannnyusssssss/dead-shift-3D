class_name NoteView
extends Control
## Muestra una nota del mundo a pantalla completa (la del técnico): su texto y, debajo, las
## piezas que hacen falta para armar el teléfono, dónde dejó cada una y si el jugador ya la
## tiene. Se cierra con «Cerrar» o con pausa. Mientras está abierta el jugador queda quieto.

var _player: Player = null
var _title: Label = null
var _body: Label = null
var _close_button: TapButton = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var paper := PanelContainer.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	paper.offset_left = -380.0
	paper.offset_right = 380.0
	paper.offset_top = -260.0
	paper.offset_bottom = 260.0
	add_child(paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	paper.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	box.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 20)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_close_button = TapButton.new()
	_close_button.text = tr("inventory_close")
	_close_button.custom_minimum_size = Vector2(160.0, 60.0)
	_close_button.add_theme_font_size_override("font_size", 20)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(close)
	box.add_child(_close_button)
	EventBus.note_opened.connect(open)


func bind_player(player: Player) -> void:
	_player = player


func is_open() -> bool:
	return visible


func open(note_id: String) -> void:
	if _player == null or _player.is_dead():
		return
	_title.text = tr("note_%s_title" % note_id)
	_body.text = body_text(note_id)
	visible = true
	_player.set_blocked("note", true)
	InputRouter.menu_open = true
	InputRouter.release_capture()
	_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	if _player != null:
		_player.set_blocked("note", false)
	InputRouter.menu_open = false


func _process(_delta: float) -> void:
	if visible and not GameState.paused and InputRouter.just_pressed("pause"):
		close()


## Texto de la nota y la lista de piezas: «[x] Antena — Electrónica, Nivel 1».
static func body_text(note_id: String) -> String:
	var lines: Array[String] = [tr_text("note_%s_body" % note_id), ""]
	var keys := GameState.player.keys
	var places := MapMarkers.locations(GameState.CATALOG.floors, Rules.PHONE_PARTS)
	for part: String in Rules.PHONE_PARTS:
		var mark := "[x]" if keys.has(part) or keys.phone_assembled else "[ ]"
		var line := "%s %s" % [mark, InventoryRows.item_name(part)]
		for place: Dictionary in places:
			if place["item_id"] == part:
				var room_key: String = place["room_key"]
				var floor_key: String = place["floor_key"]
				line += " — %s, %s" % [tr_text(room_key), tr_text(floor_key)]
		lines.append(line)
	lines.append("")
	lines.append(tr_text("note_%s_footer" % note_id))
	return "\n".join(lines)


static func tr_text(key: String) -> String:
	return String(TranslationServer.translate(key))

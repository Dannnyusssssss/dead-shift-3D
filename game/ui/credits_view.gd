class_name CreditsView
extends Control
## Créditos: quién hizo el juego y el inventario de recursos de terceros con su licencia (los
## mismos de docs/LICENSES.md), más el aviso de licencia del motor Godot. Se desplaza con
## rueda, teclado o arrastrando; «Volver» lo cierra.

signal closed

## Recursos de terceros: clave de texto y licencia (orden de docs/LICENSES.md).
const THIRD_PARTY: Array[Array] = [
	["credits_ambientcg", "CC0 1.0"],
	["credits_quaternius", "CC0 1.0"],
	["credits_kenney", "CC0 1.0"],
]

var _text: RichTextLabel = null
var _back: TapButton = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.03, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 48
	box.offset_right = -48
	box.offset_top = 32
	box.offset_bottom = -32
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := Label.new()
	title.text = tr("credits_title")
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	_text = RichTextLabel.new()
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 20)
	_text.scroll_active = true
	_text.focus_mode = Control.FOCUS_ALL
	_text.bbcode_enabled = false
	_text.text = credits_text()
	box.add_child(_text)
	_back = TapButton.new()
	_back.text = tr("credits_back")
	_back.custom_minimum_size = Vector2(220, 56)
	_back.pressed.connect(close)
	box.add_child(_back)


func open() -> void:
	visible = true
	_text.scroll_to_line(0)
	_back.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


## Texto completo de los créditos (sin formato, para que se lea con cualquier tamaño de letra).
static func credits_text() -> String:
	var lines: Array[String] = [TranslationServer.translate("credits_made_by"), ""]
	lines.append(TranslationServer.translate("credits_third_party"))
	for entry: Array in THIRD_PARTY:
		var key: String = entry[0]
		lines.append("· %s — %s" % [TranslationServer.translate(key), entry[1]])
	lines.append("")
	lines.append(TranslationServer.translate("credits_engine"))
	lines.append(Engine.get_license_text())
	return "\n".join(lines)

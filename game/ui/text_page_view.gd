class_name TextPageView
extends Control
## Página de texto a pantalla completa (Privacidad y Términos): título, texto que se desplaza
## con rueda, teclado o arrastrando, y «Volver». El texto sale de las claves de texto, sin
## formato, para que se lea con cualquier tamaño de letra.

signal closed

## Párrafos de cada página (claves de texto, en orden).
const PRIVACY_KEYS: Array[String] = [
	"privacy_1",
	"privacy_2",
	"privacy_3",
	"privacy_4",
	"privacy_5",
	"privacy_6",
	"privacy_7",
	"privacy_8",
]
const TERMS_KEYS: Array[String] = ["terms_1", "terms_2", "terms_3", "terms_4", "terms_5", "terms_6"]

var _title: Label = null
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
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 36)
	box.add_child(_title)
	_text = RichTextLabel.new()
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 20)
	_text.scroll_active = true
	_text.focus_mode = Control.FOCUS_ALL
	_text.bbcode_enabled = false
	box.add_child(_text)
	_back = TapButton.new()
	_back.text = tr("legal_back")
	_back.custom_minimum_size = Vector2(220, 56)
	_back.pressed.connect(close)
	box.add_child(_back)


## Abre la página con un título y sus párrafos (claves de texto).
func open(title_key: String, keys: Array[String]) -> void:
	_title.text = tr(title_key)
	_text.text = page_text(keys)
	visible = true
	_text.scroll_to_line(0)
	_back.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Texto de una página: sus párrafos separados por una línea en blanco y la fecha al final.
static func page_text(keys: Array[String]) -> String:
	var paragraphs: Array[String] = []
	for key: String in keys:
		paragraphs.append(TranslationServer.translate(key))
	paragraphs.append(TranslationServer.translate("legal_updated"))
	return "\n\n".join(paragraphs)

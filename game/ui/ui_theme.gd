class_name UiTheme
extends RefCounted
## Tema común de la interfaz (menús, HUD, mochila, mapa, cámaras, pausa, créditos): paneles
## oscuros, texto claro, acento ámbar y un borde de foco grueso para jugar con teclado. Los
## colores cumplen el contraste AA (lo comprueba un test): 4,5:1 el texto y 3:1 el foco y los
## bordes. El tamaño de toda la interfaz lo da el ajuste «Tamaño de la interfaz».

const TEXT: Color = Color(0.93, 0.92, 0.88)
const TEXT_DIM: Color = Color(0.72, 0.71, 0.68)
const PANEL: Color = Color(0.06, 0.065, 0.08, 0.94)
const BUTTON: Color = Color(0.13, 0.14, 0.17)
const BUTTON_HOVER: Color = Color(0.19, 0.2, 0.24)
const BUTTON_PRESSED: Color = Color(0.25, 0.2, 0.1)
const BUTTON_DISABLED: Color = Color(0.1, 0.1, 0.12)
const ACCENT: Color = Color(0.96, 0.72, 0.26)
const BORDER: Color = Color(0.45, 0.46, 0.5)
const FOCUS_WIDTH: int = 3
const FONT_SIZE: int = 22


## Tema listo para asignar a la ventana principal (lo heredan todos los controles).
static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_outline_color", "Label", Color.BLACK)
	for type_name: String in ["Button", "CheckBox", "CheckButton", "OptionButton"]:
		theme.set_color("font_color", type_name, TEXT)
		theme.set_color("font_hover_color", type_name, TEXT)
		theme.set_color("font_pressed_color", type_name, ACCENT)
		theme.set_color("font_focus_color", type_name, TEXT)
		theme.set_color("font_disabled_color", type_name, TEXT_DIM)
		theme.set_stylebox("normal", type_name, _box(BUTTON, BORDER, 1))
		theme.set_stylebox("hover", type_name, _box(BUTTON_HOVER, BORDER, 1))
		theme.set_stylebox("pressed", type_name, _box(BUTTON_PRESSED, ACCENT, 2))
		theme.set_stylebox("disabled", type_name, _box(BUTTON_DISABLED, BUTTON_DISABLED, 1))
		theme.set_stylebox("focus", type_name, _focus_box())
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 1))
	theme.set_stylebox("panel", "Panel", _box(PANEL, BORDER, 1))
	theme.set_stylebox("focus", "HSlider", _focus_box())
	theme.set_stylebox("focus", "RichTextLabel", _focus_box())
	theme.set_color("default_color", "RichTextLabel", TEXT)
	return theme


## Relación de contraste WCAG entre dos colores (1 a 21).
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := c.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b


static func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


## Foco: solo el borde (se dibuja encima del estado normal), grueso y ámbar.
static func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = ACCENT
	box.set_border_width_all(FOCUS_WIDTH)
	box.set_corner_radius_all(7)
	box.expand_margin_left = 2
	box.expand_margin_right = 2
	box.expand_margin_top = 2
	box.expand_margin_bottom = 2
	return box

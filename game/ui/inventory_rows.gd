class_name InventoryRows
extends RefCounted
## Piezas comunes de la mochila (filas con iconos, textos, títulos y botones) para que las
## pestañas se construyan igual.


static func heading(key: String) -> Label:
	var label := Label.new()
	label.text = String(TranslationServer.translate(key))
	label.add_theme_font_size_override("font_size", 22)
	return label


static func row() -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	return line


static func icon(parent: Control, item_id: String) -> ItemIcon:
	var item_icon := ItemIcon.new()
	item_icon.custom_minimum_size = Vector2(64.0, 64.0)
	item_icon.item_id = item_id
	parent.add_child(item_icon)
	return item_icon


static func text(parent: Control, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(label)
	return label


## Botón táctil de la mochila (mínimo 140 × 56). text_key vacío deja el texto para después.
static func action(
	parent: Control, text_key: String, callback: Callable, disabled: bool = false
) -> TapButton:
	var button := TapButton.new()
	button.text = String(TranslationServer.translate(text_key)) if not text_key.is_empty() else ""
	button.custom_minimum_size = Vector2(140.0, 56.0)
	button.add_theme_font_size_override("font_size", 20)
	button.disabled = disabled
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


static func item_name(item_id: String) -> String:
	var item := GameState.items.get_item(item_id)
	return String(TranslationServer.translate(item.name_key)) if item != null else item_id

class_name MaterialBagView
extends VBoxContainer
## Bolsa de materiales en la pestaña «Mochila»: un botón por material que se lleva, con icono y
## unidades sobre el tope («Clavos 6/30»). No ocupa casillas. Tocar uno lo elige para ver su
## detalle y sus acciones.

signal material_selected(item_id: String)

var _title: Label = null
var _row: HFlowContainer = null


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	add_child(_title)
	_row = HFlowContainer.new()
	_row.add_theme_constant_override("h_separation", 6)
	_row.add_theme_constant_override("v_separation", 6)
	add_child(_row)


## Vuelve a dibujar la bolsa; selected es el material elegido ("" si ninguno).
func refresh(selected: String) -> void:
	for child: Node in _row.get_children():
		child.queue_free()
	var bag := GameState.player.inventory.bag
	var ids := bag.ids(GameState.items)
	_title.text = tr("inventory_materials") if not ids.is_empty() else tr("inventory_no_materials")
	for item_id: String in ids:
		var data := GameState.items.get_item(item_id)
		var button := TapButton.new()
		button.toggle_mode = true
		button.button_pressed = item_id == selected
		button.custom_minimum_size = Vector2(210.0, 56.0)
		button.add_theme_font_size_override("font_size", 16)
		button.text = "%s %d/%d" % [tr(data.name_key), bag.count(item_id), MaterialBag.cap_of(data)]
		button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.pressed.connect(func() -> void: material_selected.emit(item_id))
		var icon := ItemIcon.new()
		icon.item_id = item_id
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(4.0, 4.0)
		icon.size = Vector2(48.0, 48.0)
		button.add_child(icon)
		_row.add_child(button)

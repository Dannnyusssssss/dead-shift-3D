class_name CombineList
extends ScrollContainer
## Pestaña «Combinar» de la mochila: armar el teléfono, lo que se puede combinar ya (una fila por
## receta, con las cantidades que gasta y cuántas veces se puede hacer, a un toque) y lo que
## falta para otras combinaciones.

signal combine_requested(recipe: RecipeData, slot: int)
signal assemble_requested

var _crafting: Crafting = null
var _list: VBoxContainer = null


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_crafting = Crafting.new(GameState.CATALOG.recipes, GameState.items)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	add_child(_list)


## Combinaciones disponibles ahora, sin repetir la misma receta (para el contador de la pestaña).
func available_count() -> int:
	var state := GameState.player
	var count := _crafting.options(state.inventory).size()
	if Discovery.can_assemble_phone(GameState.world, state.keys):
		count += 1
	return count


func refresh() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	var state := GameState.player
	var options := _crafting.options(state.inventory)
	var any := false
	# El teléfono solo se arma después de leer la nota del técnico.
	if Discovery.can_assemble_phone(GameState.world, state.keys):
		any = true
		_list.add_child(_phone_row())
	if not options.is_empty():
		any = true
		_list.add_child(InventoryRows.heading("combine_ready"))
		for option: Dictionary in options:
			_list.add_child(_option_row(option))
	var hints := _crafting.hints(state.inventory)
	if not hints.is_empty():
		_list.add_child(InventoryRows.heading("combine_missing_title"))
		for hint: Dictionary in hints:
			_list.add_child(_hint_row(hint))
	if not any:
		var empty := Label.new()
		empty.text = tr("combine_none")
		empty.add_theme_font_size_override("font_size", 20)
		_list.add_child(empty)
		_list.move_child(empty, 0)
	var note := Label.new()
	note.text = tr("combine_hint")
	note.add_theme_font_size_override("font_size", 16)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_list.add_child(note)


## Una entrada de la receta: icono y, si gasta más de una unidad, «x4».
func _add_input(row: Control, item_id: String, amount: int) -> void:
	InventoryRows.icon(row, item_id)
	if amount > 1:
		InventoryRows.text(row, "x%d" % amount, 20)


func _option_row(option: Dictionary) -> Control:
	var recipe: RecipeData = option["recipe"]
	var slot: int = option["slot"]
	var problem: String = option["problem"]
	var row := InventoryRows.row()
	var wanted := _crafting.materials(recipe)
	var amount_a: int = wanted.get(recipe.input_a, 1)
	var amount_b: int = wanted.get(recipe.input_b, 1)
	var title := ""
	if recipe.is_repair():
		var weapon := GameState.player.inventory.get_slot(slot)
		_add_input(row, recipe.input_a, amount_a)
		InventoryRows.text(row, "+", 28)
		InventoryRows.icon(row, weapon.id())
		InventoryRows.text(row, "→", 28)
		InventoryRows.icon(row, weapon.id())
		title = tr("combine_repair") % tr(weapon.item.name_key)
	else:
		_add_input(row, recipe.input_a, amount_a)
		InventoryRows.text(row, "+", 28)
		_add_input(row, recipe.input_b, amount_b)
		InventoryRows.text(row, "→", 28)
		InventoryRows.icon(row, recipe.result_id)
		title = InventoryRows.item_name(recipe.result_id) + "\n" + tr("desc_" + recipe.result_id)
	var times: int = option.get("times", 1)
	if times > 1:
		title += "\n" + tr("combine_times") % times
	var label := InventoryRows.text(row, title, 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button := InventoryRows.action(
		row, "", func() -> void: combine_requested.emit(recipe, slot)
	)
	button.text = tr("combine_do") % ceili(recipe.craft_time)
	if problem != Crafting.ERROR_NONE:
		button.disabled = true
		button.tooltip_text = tr("combine_no_space")
	return row


func _hint_row(hint: Dictionary) -> Control:
	var recipe: RecipeData = hint["recipe"]
	var have: String = hint["have"]
	var missing: Array[Dictionary] = hint["missing"]
	var row := InventoryRows.row()
	InventoryRows.icon(row, have)
	InventoryRows.text(row, "+", 28)
	InventoryRows.icon(row, "?")
	InventoryRows.text(row, "→", 28)
	InventoryRows.icon(row, recipe.result_id)
	var parts: Array[String] = []
	for entry: Dictionary in missing:
		var item_id: String = entry["id"]
		var owned: int = entry["have"]
		var need: int = entry["need"]
		var part := InventoryRows.item_name(item_id)
		if need > 1:
			part += " (%d/%d)" % [owned, need]
		parts.append(part)
	var text := (
		InventoryRows.item_name(recipe.result_id) + "\n" + tr("combine_missing") % ", ".join(parts)
	)
	var label := InventoryRows.text(row, text, 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _phone_row() -> Control:
	var row := InventoryRows.row()
	for part: String in Rules.PHONE_PARTS:
		InventoryRows.icon(row, part)
	InventoryRows.text(row, "→", 28)
	InventoryRows.icon(row, "phone")
	var label := InventoryRows.text(row, tr("phone_assemble_row"), 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	InventoryRows.action(row, "inventory_assemble_phone", func() -> void: assemble_requested.emit())
	return row

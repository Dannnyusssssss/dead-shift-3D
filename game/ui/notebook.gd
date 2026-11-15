class_name Notebook
extends ScrollContainer
## Cuaderno del guardia (pestaña de la mochila, o tecla N): objetivo actual, cómo armar el
## teléfono (qué piezas faltan y en qué zona buscarlas), todas las combinaciones y los controles.

var _box: VBoxContainer = null


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)


## Texto del objetivo actual (también lo usa el HUD).
static func objective_text() -> String:
	var state := GameState.player
	if state == null or GameState.rescue == null:
		return ""
	var roof_open := GameState.world.has_flag("roof_open")
	var objective := Objectives.current(state, GameState.rescue, roof_open)
	return _format(objective)


static func _format(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var key: String = entry["key"]
	var args: Array = entry["args"]
	return (
		TranslationServer.translate(key) % args
		if not args.is_empty()
		else TranslationServer.translate(key)
	)


func refresh() -> void:
	if _box == null or GameState.player == null:
		return
	for child: Node in _box.get_children():
		child.queue_free()
	var state := GameState.player
	_heading("notebook_objective")
	_text(objective_text(), 22)
	var warning := _format(Objectives.warning(state))
	if not warning.is_empty():
		_text(warning, 20).add_theme_color_override("font_color", Color(0.8, 1.0, 0.6))
	_heading("notebook_phone")
	_text(tr("notebook_phone_intro"), 18)
	var zones := _part_zones()
	for part: String in Rules.PHONE_PARTS:
		var name := tr(GameState.items.get_item(part).name_key)
		var line := ""
		if state.keys.has(part) or state.keys.phone_assembled:
			line = tr("notebook_part_have") % name
		elif zones.has(part):
			line = tr("notebook_part_missing") % [name, zones[part]]
		else:
			line = tr("notebook_part_unknown") % name
		_text(line, 18)
	_heading("notebook_recipes")
	for recipe: RecipeData in GameState.CATALOG.recipes:
		if recipe.is_repair():
			_text(tr("notebook_recipe_repair") % _name(recipe.input_a), 18)
		else:
			_text(
				(
					"%s + %s → %s"
					% [_name(recipe.input_a), _name(recipe.input_b), _name(recipe.result_id)]
				),
				18
			)
	_heading("notebook_controls")
	_text(tr("notebook_controls_text"), 16)


## Zona probable de cada pieza: «tienda — piso», según dónde la colocan los datos del piso.
func _part_zones() -> Dictionary:
	var result: Dictionary = {}
	for floor_data: FloorData in GameState.CATALOG.floors:
		for room: RoomData in floor_data.rooms:
			for spot: LootSpot in room.loot:
				var ids: Array[String] = []
				if spot.kind == LootSpot.KIND_PICKUP:
					ids.append(spot.item_id)
				for entry: String in spot.contents:
					ids.append(entry.split(":")[0])
				for item_id: String in ids:
					if Rules.PHONE_PARTS.has(item_id) and not room.name_key.is_empty():
						result[item_id] = "%s — %s" % [tr(room.name_key), tr(floor_data.name_key)]
	return result


func _name(item_id: String) -> String:
	var item := GameState.items.get_item(item_id)
	return tr(item.name_key) if item != null else item_id


func _heading(key: String) -> void:
	var label := Label.new()
	label.text = tr(key)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_box.add_child(label)


func _text(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_box.add_child(label)
	return label

class_name Notebook
extends ScrollContainer
## Cuaderno del guardia (pestaña de la mochila, o tecla N): objetivo actual, el teléfono y las
## combinaciones, pero solo lo que el jugador ya descubrió (Discovery): el teléfono aparece al
## leer la nota del técnico o encontrar una pieza, la zona de cada pieza al leer la nota o tener
## el plano, y cada combinación cuando ya tuvo alguno de sus ingredientes. Y los controles.

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
	_phone_section(state)
	_heading("notebook_recipes")
	_recipes_section()
	_heading("notebook_controls")
	_text(tr("notebook_controls_text"), 16)


func _phone_section(state: PlayerState) -> void:
	var world := GameState.world
	if not Discovery.knows_phone(world, state.keys):
		_text(tr("notebook_phone_unknown"), 18)
		return
	_text(tr("notebook_phone_intro"), 18)
	var zones := _part_zones() if Discovery.knows_part_zones(world, state.keys) else {}
	for part: String in Rules.PHONE_PARTS:
		var name := _name(part)
		var line := ""
		if state.keys.has(part) or state.keys.phone_assembled:
			line = tr("notebook_part_have") % name
		elif zones.has(part):
			line = tr("notebook_part_missing") % [name, zones[part]]
		else:
			line = tr("notebook_part_unknown") % name
		_text(line, 18)


func _recipes_section() -> void:
	var crafting := Crafting.new(GameState.CATALOG.recipes, GameState.items)
	var shown := 0
	for recipe: RecipeData in GameState.CATALOG.recipes:
		if not Discovery.knows_recipe(GameState.world, recipe):
			continue
		shown += 1
		var wanted := crafting.materials(recipe)
		if recipe.is_repair():
			_text(tr("notebook_recipe_repair") % _amount_name(recipe.input_a, wanted), 18)
		else:
			var first := _amount_name(recipe.input_a, wanted)
			var second := _amount_name(recipe.input_b, wanted)
			_text("%s + %s → %s" % [first, second, _name(recipe.result_id)], 18)
	if shown == 0:
		_text(tr("notebook_recipes_none"), 18)


## Zona de cada pieza: «tienda — piso», según dónde la colocan los datos del piso.
func _part_zones() -> Dictionary:
	var result: Dictionary = {}
	for place: Dictionary in MapMarkers.locations(GameState.CATALOG.floors, Rules.PHONE_PARTS):
		var room_key: String = place["room_key"]
		var floor_key: String = place["floor_key"]
		if not room_key.is_empty():
			result[place["item_id"]] = "%s — %s" % [tr(room_key), tr(floor_key)]
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


## Nombre con las unidades que gasta la receta si son más de una («Clavos x4»).
func _amount_name(item_id: String, wanted: Dictionary) -> String:
	var amount: int = wanted.get(item_id, 1)
	return _name(item_id) + (" x%d" % amount if amount > 1 else "")

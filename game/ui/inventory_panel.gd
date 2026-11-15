class_name InventoryPanel
extends Control
## Mochila tipo maletín, usable con ratón, teclado (flechas, Intro, Tab o I para cerrar) y toque.
## Tres pestañas: «Mochila» (casillas con icono, bolsa de materiales, detalle del objeto elegido
## y sus acciones, chaleco y objetos clave), «Combinar» (CombineList: lo que se puede hacer ahora,
## a un toque, y lo que falta para otras combinaciones) y «Cuaderno» (objetivo y pistas).
## Tocar el plano entre los objetos clave cierra la mochila y pide abrir el mapa.
## Abrirla no pausa el mundo: el jugador queda quieto y expuesto mientras la usa.

## Se tocó el plano: la mochila ya se cerró y quien la contiene abre el mapa.
signal map_requested

const TAB_BAG: int = 0
const TAB_COMBINE: int = 1
const TAB_NOTEBOOK: int = 2
const WEAR_KEYS: Array[String] = ["wear_good", "wear_damaged", "wear_critical", "wear_broken"]
## Icono de estado en tres pasos hecho con forma (no solo color).
const WEAR_ICONS: Array[String] = ["[###]", "[##-]", "[#--]", "[---]"]
const TILE_SIZE: Vector2 = Vector2(150.0, 112.0)

var _player: Player = null
var _crafting: Crafting = null
var _tab: int = TAB_BAG
var _selected: int = -1
## Material de la bolsa elegido ("" si se eligió una casilla o nada).
var _selected_material: String = ""
var _bag_view: MaterialBagView = null
var _call_armed: bool = false
var _tab_buttons: Array[TapButton] = []
var _pages: Array[Control] = []
var _tiles: Array[TapButton] = []
var _tile_icons: Array[ItemIcon] = []
var _tile_labels: Array[Label] = []
var _detail_icon: ItemIcon = null
var _detail_name: Label = null
var _detail_text: Label = null
var _actions: HFlowContainer = null
var _info: Label = null
var _vest_icon: ItemIcon = null
var _vest_label: Label = null
var _keys_row: HFlowContainer = null
var _keys_label: Label = null
var _call_button: TapButton = null
var _combine_list: CombineList = null
var _notebook: Notebook = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_crafting = Crafting.new(GameState.CATALOG.recipes, GameState.items)
	_build()
	EventBus.inventory_changed.connect(_refresh)
	EventBus.key_items_changed.connect(_refresh)
	EventBus.vest_changed.connect(_refresh)
	EventBus.weapon_changed.connect(_refresh)


func bind_player(player: Player) -> void:
	_player = player


func is_open() -> bool:
	return visible


## Abre la mochila en una pestaña (por defecto, la de objetos).
func open(tab: int = TAB_BAG) -> void:
	if _player == null or _player.crafting.active or _player.healing.active or _player.is_dead():
		return
	visible = true
	_selected = -1
	_selected_material = ""
	_call_armed = false
	_player.set_blocked("inventory", true)
	# Con la mochila abierta el cursor queda visible: un clic en sus botones no lo captura.
	InputRouter.menu_open = true
	InputRouter.release_capture()
	_show_tab(tab)


## Cierra la mochila. Con «recapture» falso no pide el puntero (se abre otro panel encima).
func close(recapture: bool = true) -> void:
	if not visible:
		return
	visible = false
	_player.set_blocked("inventory", false)
	InputRouter.menu_open = false
	if recapture:
		InputRouter.request_capture()


func _process(_delta: float) -> void:
	if _player == null or GameState.paused:
		return
	if InputRouter.just_pressed("inventory"):
		if visible:
			close()
		elif InputRouter.gameplay_active:
			open()
	elif InputRouter.just_pressed("notebook"):
		if visible and _tab == TAB_NOTEBOOK:
			close()
		elif visible:
			_show_tab(TAB_NOTEBOOK)
		elif InputRouter.gameplay_active:
			open(TAB_NOTEBOOK)
	elif visible and InputRouter.just_pressed("pause"):
		close()


func _show_tab(tab: int) -> void:
	_tab = tab
	for index: int in _pages.size():
		_pages[index].visible = index == tab
		_tab_buttons[index].button_pressed = index == tab
	_refresh()
	match tab:
		TAB_BAG:
			_tiles[0].grab_focus()
		_:
			_tab_buttons[tab].grab_focus()


# --- Pestaña Mochila ------------------------------------------------------------------------


func _on_tile_pressed(index: int) -> void:
	var stack := GameState.player.inventory.get_slot(index)
	_selected = index if stack != null else -1
	_selected_material = ""
	_call_armed = false
	_refresh()


func _on_equip() -> void:
	if GameState.player.select_slot(_selected):
		EventBus.weapon_changed.emit()


func _on_wear() -> void:
	var state := GameState.player
	var stack := state.inventory.get_slot(_selected)
	if stack == null or not stack.is_vest():
		return
	state.inventory.take_slot(_selected)
	var old := state.swap_vest(stack)
	if old != null and not state.inventory.put_slot(_selected, old):
		_player.drop_stack(old)
	EventBus.vest_changed.emit()
	EventBus.inventory_changed.emit()


func _on_material_selected(item_id: String) -> void:
	_selected_material = item_id
	_selected = -1
	_call_armed = false
	_refresh()


func _on_drop() -> void:
	var state := GameState.player
	if not _selected_material.is_empty():
		# Suelta todas las unidades de ese material juntas.
		var data := GameState.items.get_item(_selected_material)
		var amount := state.inventory.bag.remove(
			_selected_material, state.inventory.bag.count(_selected_material)
		)
		if data != null and amount > 0:
			_player.drop_stack(ItemStack.new(data, amount))
		_selected_material = ""
		EventBus.inventory_changed.emit()
		return
	var stack := state.inventory.take_slot(_selected)
	if stack == null:
		return
	_player.drop_stack(stack)
	if state.equipped() == null:
		state.cycle_weapon(1)
	_selected = -1
	EventBus.inventory_changed.emit()
	EventBus.weapon_changed.emit()


## Cierra la mochila y empieza a usar la cura elegida (o explica por qué no se puede).
func _on_use() -> void:
	var problem := (
		_player.healing.start(_selected) if _player != null else PlayerState.USE_NOT_USABLE
	)
	if problem == PlayerState.USE_OK:
		close()
		return
	_info.text = tr(PlayerHealing.problem_message(problem))


## Cierra la mochila y deja el objeto listo en la mano, con su trayectoria, para lanzarlo.
func _on_throw() -> void:
	var item_id := _selected_material
	if GameState.player.inventory.bag.count(item_id) <= 0:
		return
	close()
	_player.throw.prepare(item_id)


## Llamar es irreversible: el primer toque pide confirmación y el segundo llama.
func _on_call() -> void:
	if not _call_armed:
		_call_armed = true
		_refresh()
		return
	_call_armed = false
	if GameState.rescue.call_helicopter():
		EventBus.user_message.emit("msg_helicopter_called")
		EventBus.rescue_changed.emit()
	close()


func _refresh_bag() -> void:
	var state := GameState.player
	for index: int in _tiles.size():
		var stack := state.inventory.get_slot(index)
		_tile_icons[index].item_id = stack.id() if stack != null else ""
		_tile_labels[index].text = _tile_text(stack, index == state.equipped_slot)
		_tiles[index].button_pressed = index == _selected
		_tiles[index].tooltip_text = tr(stack.item.name_key) if stack != null else ""
	_vest_icon.item_id = state.vest.id() if state.vest != null else ""
	_vest_label.text = "%s\n%s" % [tr("inventory_vest"), _wear_text(state.vest)]
	_refresh_keys()
	if state.inventory.bag.count(_selected_material) <= 0:
		_selected_material = ""
	_bag_view.refresh(_selected_material)
	if not _selected_material.is_empty():
		_refresh_material_detail(_selected_material)
	else:
		_refresh_detail(state.inventory.get_slot(_selected))


func _tile_text(stack: ItemStack, equipped: bool) -> String:
	if stack == null:
		return tr("inventory_empty")
	var text := tr(stack.item.name_key)
	if stack.count > 1:
		text += " x%d" % stack.count
	if stack.is_weapon() and stack.item.weapon.kind == WeaponData.KIND_RANGED:
		text += "  %d/%d" % [stack.ammo_loaded, stack.item.weapon.magazine_size]
	if not stack.durability.is_unbreakable():
		text += "\n" + WEAR_ICONS[stack.durability.state()]
	if equipped:
		text += "\n" + tr("inventory_equipped")
	return text


func _wear_text(stack: ItemStack) -> String:
	if stack == null:
		return tr("hud_none")
	if stack.durability.is_unbreakable():
		return tr(stack.item.name_key)
	var wear := stack.durability.state()
	return "%s %s" % [WEAR_ICONS[wear], tr(WEAR_KEYS[wear])]


func _refresh_keys() -> void:
	for child: Node in _keys_row.get_children():
		child.queue_free()
	var state := GameState.player
	for item_id: String in state.keys.items:
		# Con el teléfono armado, sus piezas ya no se muestran sueltas (solo el teléfono).
		if state.keys.phone_assembled and Rules.PHONE_PARTS.has(item_id):
			continue
		var icon := ItemIcon.new()
		icon.custom_minimum_size = Vector2(48.0, 48.0)
		icon.item_id = item_id
		var item := GameState.items.get_item(item_id)
		icon.tooltip_text = tr(item.name_key) if item != null else item_id
		if item_id == MapMarkers.MAP_ITEM:
			_keys_row.add_child(_map_button(icon))
		else:
			_keys_row.add_child(icon)
	if state.keys.phone_assembled:
		var phone := ItemIcon.new()
		phone.custom_minimum_size = Vector2(48.0, 48.0)
		phone.item_id = "phone"
		_keys_row.add_child(phone)
	var parts := state.keys.phone_parts_count()
	_keys_label.text = (
		tr("inventory_key_items")
		+ " · "
		+ tr("phone_parts_status") % [parts, Rules.PHONE_PARTS.size()]
	)
	if state.keys.phone_assembled:
		_keys_label.text = tr("inventory_key_items") + " · " + tr("item_phone")
	_call_button.visible = state.keys.phone_assembled and not GameState.rescue.is_called()
	_call_button.text = tr("inventory_call_confirm") if _call_armed else tr("inventory_call")


## El plano es un botón (con el tamaño mínimo táctil) que abre el mapa.
func _map_button(icon: ItemIcon) -> TapButton:
	var button := TapButton.new()
	button.custom_minimum_size = Vector2(56.0, 56.0)
	button.tooltip_text = tr("inventory_open_map")
	button.name = "MapButton"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	button.pressed.connect(_on_map)
	return button


func _on_map() -> void:
	close(false)
	map_requested.emit()


## Detalle de un material de la bolsa: descripción, unidades sobre el tope, con qué se combina y
## sus acciones (combinar, lanzar, soltar).
func _refresh_material_detail(item_id: String) -> void:
	for child: Node in _actions.get_children():
		child.queue_free()
	var item := GameState.items.get_item(item_id)
	var bag := GameState.player.inventory.bag
	_detail_icon.item_id = item_id
	_detail_name.text = tr(item.name_key)
	var lines: Array[String] = [tr("desc_" + item_id)]
	lines.append(tr("stat_bag_units") % [bag.count(item_id), MaterialBag.cap_of(item)])
	var partners := _partners(item_id)
	if not partners.is_empty():
		lines.append(tr("stat_combines_with") % ", ".join(partners))
	_detail_text.text = "\n".join(lines)
	if not partners.is_empty():
		_action(_actions, "inventory_combine", func() -> void: _show_tab(TAB_COMBINE))
	_action(_actions, "inventory_throw", _on_throw)
	_action(_actions, "inventory_drop", _on_drop)


func _refresh_detail(stack: ItemStack) -> void:
	for child: Node in _actions.get_children():
		child.queue_free()
	if stack == null:
		_detail_icon.item_id = ""
		_detail_name.text = ""
		_detail_text.text = tr("inventory_select_hint")
		return
	var item := stack.item
	_detail_icon.item_id = item.id
	_detail_name.text = tr(item.name_key)
	var lines: Array[String] = [tr("desc_" + item.id)]
	if stack.count > 1:
		lines.append(tr("stat_count") % stack.count)
	if stack.is_weapon():
		lines.append(tr("stat_damage") % roundi(item.weapon.damage))
		if item.weapon.kind == WeaponData.KIND_RANGED:
			var spare := GameState.player.inventory.count_of(item.weapon.ammo_item_id)
			lines.append(tr("stat_ammo") % [stack.ammo_loaded, item.weapon.magazine_size, spare])
	if not stack.durability.is_unbreakable():
		var wear := stack.durability.state()
		lines.append(tr("stat_wear") % [WEAR_ICONS[wear], tr(WEAR_KEYS[wear])])
	if item.use_effect == ItemData.EFFECT_HEAL:
		lines.append(tr("stat_heal") % roundi(item.heal_amount))
	var partners := _partners(item.id)
	if not partners.is_empty():
		lines.append(tr("stat_combines_with") % ", ".join(partners))
	_detail_text.text = "\n".join(lines)
	if stack.is_weapon():
		_action(_actions, "inventory_equip", _on_equip, _selected == GameState.player.equipped_slot)
	if item.category == ItemData.CATEGORY_CONSUMABLE:
		_action(_actions, "inventory_use", _on_use)
	if stack.is_vest():
		_action(_actions, "inventory_wear", _on_wear)
	if not partners.is_empty():
		_action(_actions, "inventory_combine", func() -> void: _show_tab(TAB_COMBINE))
	_action(_actions, "inventory_drop", _on_drop)


## Nombres de los objetos con los que se combina (según las recetas).
func _partners(item_id: String) -> Array[String]:
	var names: Array[String] = []
	for recipe: RecipeData in _crafting.recipes_with(item_id):
		var other := ""
		if recipe.is_repair():
			if recipe.input_a == item_id:
				other = tr("combine_repair") % tr("item_damaged_weapon")
		elif recipe.input_a == item_id:
			other = _item_name(recipe.input_b)
		elif recipe.input_b == item_id:
			other = _item_name(recipe.input_a)
		if not other.is_empty() and not names.has(other):
			names.append(other)
	return names


# --- Pestaña Combinar -----------------------------------------------------------------------


func _on_combine(recipe: RecipeData, slot: int) -> void:
	var problem := _player.crafting.start(recipe, slot)
	if problem == Crafting.ERROR_NONE:
		close()
	else:
		_info.text = tr("msg_cannot_combine")


func _on_assemble() -> void:
	if GameState.player.keys.assemble_phone():
		_info.text = tr("msg_phone_assembled")
		EventBus.key_items_changed.emit()
		_show_tab(TAB_BAG)


# --- Común ----------------------------------------------------------------------------------


func _refresh() -> void:
	if not visible or GameState.player == null:
		return
	var count := _combine_list.available_count()
	_tab_buttons[TAB_COMBINE].text = (
		tr("tab_combine_count") % count if count > 0 else tr("tab_combine")
	)
	match _tab:
		TAB_BAG:
			_refresh_bag()
		TAB_COMBINE:
			_combine_list.refresh()
		TAB_NOTEBOOK:
			_notebook.refresh()


func _item_name(item_id: String) -> String:
	return InventoryRows.item_name(item_id)


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.035, 0.04, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	for key: String in ["tab_bag", "tab_combine", "tab_notebook"]:
		var tab_index := _tab_buttons.size()
		var tab := _action(header, key, _show_tab.bind(tab_index))
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(170.0, 56.0)
		_tab_buttons.append(tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_action(header, "inventory_close_hint", close)
	_pages.append(_build_bag())
	_combine_list = CombineList.new()
	_combine_list.combine_requested.connect(_on_combine)
	_combine_list.assemble_requested.connect(_on_assemble)
	_pages.append(_combine_list)
	_notebook = Notebook.new()
	_pages.append(_notebook)
	for page: Control in _pages:
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(page)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_info)


func _build_bag() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	# La columna izquierda se desplaza si no cabe (muchos materiales o pantallas bajas): así
	# nada queda fuera de la pantalla.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(left)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	for index: int in Rules.INVENTORY_SLOTS:
		var tile := TapButton.new()
		tile.toggle_mode = true
		tile.custom_minimum_size = TILE_SIZE
		tile.pressed.connect(_on_tile_pressed.bind(index))
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 0)
		tile.add_child(column)
		var icon := ItemIcon.new()
		icon.custom_minimum_size = Vector2(0.0, 64.0)
		column.add_child(icon)
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		column.add_child(label)
		grid.add_child(tile)
		_tiles.append(tile)
		_tile_icons.append(icon)
		_tile_labels.append(label)
	_bag_view = MaterialBagView.new()
	_bag_view.material_selected.connect(_on_material_selected)
	left.add_child(_bag_view)
	var equipment := HBoxContainer.new()
	equipment.add_theme_constant_override("separation", 10)
	left.add_child(equipment)
	_vest_icon = ItemIcon.new()
	_vest_icon.custom_minimum_size = Vector2(56.0, 56.0)
	equipment.add_child(_vest_icon)
	_vest_label = Label.new()
	_vest_label.add_theme_font_size_override("font_size", 16)
	equipment.add_child(_vest_label)
	_keys_label = Label.new()
	_keys_label.add_theme_font_size_override("font_size", 16)
	left.add_child(_keys_label)
	_keys_row = HFlowContainer.new()
	_keys_row.add_theme_constant_override("h_separation", 6)
	_keys_row.add_theme_constant_override("v_separation", 6)
	left.add_child(_keys_row)
	var detail := PanelContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(detail)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 10)
	detail.add_child(detail_box)
	# Llamar al helicóptero: arriba del panel de detalle, ancho y grande, siempre a la vista.
	_call_button = _action(detail_box, "inventory_call", _on_call)
	_call_button.custom_minimum_size = Vector2(0.0, 72.0)
	_call_button.add_theme_font_size_override("font_size", 24)
	_call_button.name = "CallButton"
	_detail_icon = ItemIcon.new()
	_detail_icon.custom_minimum_size = Vector2(0.0, 120.0)
	detail_box.add_child(_detail_icon)
	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 26)
	detail_box.add_child(_detail_name)
	_detail_text = Label.new()
	_detail_text.add_theme_font_size_override("font_size", 18)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_text.custom_minimum_size = Vector2(280.0, 0.0)
	detail_box.add_child(_detail_text)
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 8)
	_actions.add_theme_constant_override("v_separation", 8)
	detail_box.add_child(_actions)
	return page


func _action(
	parent: Control, text_key: String, callback: Callable, disabled: bool = false
) -> TapButton:
	return InventoryRows.action(parent, text_key, callback, disabled)

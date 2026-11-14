class_name InventoryPanel
extends Control
## Inventario y crafteo, usable con ratón, teclado (flechas, Intro, Tab/I para cerrar) y toque.
## Abrirlo no pausa el mundo: el jugador queda quieto y expuesto mientras lo usa.
## Elegir una casilla, «Combinar» y otra casilla empieza la combinación.

const WEAR_KEYS: Array[String] = ["wear_good", "wear_damaged", "wear_critical", "wear_broken"]
## Icono de estado en tres pasos hecho con forma (no solo color).
const WEAR_ICONS: Array[String] = ["[###]", "[##-]", "[#--]", "[---]"]

var _player: Player = null
var _grid: GridContainer = null
var _slot_buttons: Array[TapButton] = []
var _info: Label = null
var _vest_label: Label = null
var _equip_button: TapButton = null
var _combine_button: TapButton = null
var _wear_button: TapButton = null
var _drop_button: TapButton = null
var _close_button: TapButton = null
var _selected: int = -1
var _combine_first: int = -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	EventBus.inventory_changed.connect(_refresh)
	EventBus.vest_changed.connect(_refresh)
	EventBus.weapon_changed.connect(_refresh)


func bind_player(player: Player) -> void:
	_player = player


func is_open() -> bool:
	return visible


func open() -> void:
	if _player == null or _player.crafting.active or _player.is_dead():
		return
	visible = true
	_selected = -1
	_combine_first = -1
	_player.set_blocked("inventory", true)
	# Con la mochila abierta el cursor queda visible: un clic en sus botones no lo captura.
	InputRouter.menu_open = true
	InputRouter.release_capture()
	_refresh()
	if not _slot_buttons.is_empty():
		_slot_buttons[0].grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_player.set_blocked("inventory", false)
	InputRouter.menu_open = false
	InputRouter.request_capture()


func _process(_delta: float) -> void:
	if _player == null or GameState.paused:
		return
	if InputRouter.just_pressed("inventory"):
		if visible:
			close()
		elif InputRouter.gameplay_active:
			open()
	elif visible and InputRouter.just_pressed("pause"):
		close()


func _on_slot_pressed(index: int) -> void:
	var stack := GameState.player.inventory.get_slot(index)
	if _combine_first >= 0 and index != _combine_first and stack != null:
		var problem := _player.crafting.start(_combine_first, index)
		_combine_first = -1
		if problem == Crafting.ERROR_NONE:
			close()
		else:
			_info.text = tr("msg_cannot_combine")
		return
	_selected = index if stack != null else -1
	_refresh()


func _on_equip() -> void:
	if GameState.player.select_slot(_selected):
		EventBus.weapon_changed.emit()


func _on_combine() -> void:
	if _selected < 0:
		return
	_combine_first = _selected
	_info.text = tr("inventory_pick_second")


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


func _on_drop() -> void:
	var state := GameState.player
	var stack := state.inventory.take_slot(_selected)
	if stack == null:
		return
	_player.drop_stack(stack)
	if state.equipped() == null:
		state.cycle_weapon(1)
	_selected = -1
	EventBus.inventory_changed.emit()
	EventBus.weapon_changed.emit()


func _refresh() -> void:
	if not visible or GameState.player == null:
		return
	var state := GameState.player
	for index: int in _slot_buttons.size():
		var button := _slot_buttons[index]
		var stack := state.inventory.get_slot(index)
		button.text = _describe(stack, index == state.equipped_slot)
		button.button_pressed = index == _selected
	var selected := state.inventory.get_slot(_selected)
	_equip_button.disabled = selected == null or not selected.is_weapon()
	_combine_button.disabled = selected == null
	_wear_button.disabled = selected == null or not selected.is_vest()
	_drop_button.disabled = selected == null
	_vest_label.text = tr("inventory_vest") + ": " + _describe(state.vest, false)
	if _combine_first < 0:
		_info.text = tr("inventory_hint")


func _describe(stack: ItemStack, equipped: bool) -> String:
	if stack == null:
		return tr("inventory_empty")
	var text := tr(stack.item.name_key)
	if stack.count > 1:
		text += " x%d" % stack.count
	if stack.is_weapon() and stack.item.weapon.kind == WeaponData.KIND_RANGED:
		text += "  %d/%d" % [stack.ammo_loaded, stack.item.weapon.magazine_size]
	if not stack.durability.is_unbreakable():
		var state := stack.durability.state()
		text += "\n%s %s" % [WEAR_ICONS[state], tr(WEAR_KEYS[state])]
	if equipped:
		text += "\n" + tr("inventory_equipped")
	return text


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = tr("inventory_title")
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	_vest_label = Label.new()
	_vest_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_vest_label)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	box.add_child(_grid)
	for index: int in Rules.INVENTORY_SLOTS:
		var button := TapButton.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(220.0, 96.0)
		button.add_theme_font_size_override("font_size", 18)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD
		button.pressed.connect(_on_slot_pressed.bind(index))
		_grid.add_child(button)
		_slot_buttons.append(button)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 20)
	box.add_child(_info)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	_equip_button = _action_button(actions, "inventory_equip", _on_equip)
	_combine_button = _action_button(actions, "inventory_combine", _on_combine)
	_wear_button = _action_button(actions, "inventory_wear", _on_wear)
	_drop_button = _action_button(actions, "inventory_drop", _on_drop)
	_close_button = _action_button(actions, "inventory_close", close)


func _action_button(parent: Control, text_key: String, action: Callable) -> TapButton:
	var button := TapButton.new()
	button.text = tr(text_key)
	button.custom_minimum_size = Vector2(160.0, 60.0)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

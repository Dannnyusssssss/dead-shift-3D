class_name Hud
extends Control
## HUD mínimo: salud, chaleco, arma con su estado de desgaste (icono de forma y texto, no
## solo color), munición, indicador de interacción, punto de mira, mensajes y progreso
## de la combinación. El aviso de daño es un borde rojo que se desvanece, sin destellos.

const WEAR_KEYS: Array[String] = ["wear_good", "wear_damaged", "wear_critical", "wear_broken"]
const WEAR_ICONS: Array[String] = ["[###]", "[##-]", "[#--]", "[---]"]
const MESSAGE_TIME: float = 3.0
## El borde de daño tarda esto en desvanecerse; con un golpe cada ~1,5 s nunca parpadea.
const DAMAGE_FADE: float = 0.8

var _player: Player = null
var _health: Label = null
var _vest: Label = null
var _weapon: Label = null
var _prompt: Label = null
var _message: Label = null
var _craft_bar: ProgressBar = null
var _damage_edge: ColorRect = null
var _message_timer: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.vest_changed.connect(_refresh)
	EventBus.weapon_changed.connect(_refresh)
	EventBus.inventory_changed.connect(_refresh)
	EventBus.interaction_prompt.connect(_on_prompt)
	EventBus.user_message.connect(_on_message)
	EventBus.player_damaged.connect(_on_damaged)
	EventBus.weapon_broken.connect(_on_weapon_broken)
	_refresh()


func bind_player(player: Player) -> void:
	_player = player


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.text = ""
	if _damage_edge.color.a > 0.0:
		_damage_edge.color.a = maxf(_damage_edge.color.a - delta / DAMAGE_FADE * 0.35, 0.0)
	var crafting := _player != null and _player.crafting.active
	_craft_bar.visible = crafting
	if crafting:
		_craft_bar.value = _player.crafting.progress() * 100.0


func _refresh() -> void:
	var state := GameState.player
	if state == null:
		return
	_health.text = "%s %d" % [tr("hud_health"), ceili(state.health)]
	if state.vest == null:
		_vest.text = "%s: %s" % [tr("inventory_vest"), tr("hud_none")]
	else:
		var vest_state := state.vest.durability.state()
		_vest.text = (
			"%s: %s %s" % [tr("inventory_vest"), WEAR_ICONS[vest_state], tr(WEAR_KEYS[vest_state])]
		)
	var stack := state.equipped()
	if stack == null:
		_weapon.text = tr("hud_unarmed")
		return
	var text := tr(stack.item.name_key)
	var weapon := stack.item.weapon
	if weapon.kind == WeaponData.KIND_RANGED:
		var reserve := state.inventory.count_of(weapon.ammo_item_id)
		text += "   %d / %d" % [stack.ammo_loaded, reserve]
	elif not stack.durability.is_unbreakable():
		var wear := stack.durability.state()
		text += "   %s %s" % [WEAR_ICONS[wear], tr(WEAR_KEYS[wear])]
	_weapon.text = text


func _on_health_changed(_health_value: float) -> void:
	_refresh()


func _on_prompt(text_key: String) -> void:
	if text_key.is_empty():
		_prompt.text = ""
		return
	var key_hint := tr("hud_touch_use") if InputRouter.touch_mode else tr("hud_key_use")
	_prompt.text = "%s  %s" % [key_hint, tr(text_key)]


func _on_message(text_key: String) -> void:
	_message.text = tr(text_key)
	_message_timer = MESSAGE_TIME


func _on_damaged(_amount: float) -> void:
	_damage_edge.color.a = 0.35


func _on_weapon_broken(_item_id: String) -> void:
	_on_message("msg_weapon_broken")


func _build() -> void:
	_damage_edge = ColorRect.new()
	_damage_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_edge.color = Color(0.6, 0.0, 0.0, 0.0)
	add_child(_damage_edge)
	var crosshair := ColorRect.new()
	crosshair.color = Color(1.0, 1.0, 1.0, 0.85)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	_place(crosshair, Control.PRESET_CENTER, Rect2(-3.0, -3.0, 6.0, 6.0))
	var status := VBoxContainer.new()
	status.position = Vector2(24.0, 20.0)
	add_child(status)
	_health = _label(status, 28)
	_vest = _label(status, 22)
	_weapon = _label(self, 26)
	_place(_weapon, Control.PRESET_BOTTOM_LEFT, Rect2(24.0, -72.0, 640.0, 44.0))
	_prompt = _label(self, 26)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_prompt, Control.PRESET_CENTER, Rect2(-320.0, 50.0, 640.0, 40.0))
	_message = _label(self, 24)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	_place(_message, Control.PRESET_CENTER_TOP, Rect2(-360.0, 90.0, 720.0, 70.0))
	_craft_bar = ProgressBar.new()
	_craft_bar.visible = false
	add_child(_craft_bar)
	_place(_craft_bar, Control.PRESET_CENTER, Rect2(-160.0, 100.0, 320.0, 24.0))


## Ancla un control y fija su rectángulo relativo al punto de anclaje.
func _place(control: Control, preset: Control.LayoutPreset, rect: Rect2) -> void:
	control.set_anchors_preset(preset)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	# Contorno oscuro para leerse sobre cualquier fondo 3D (contraste).
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	parent.add_child(label)
	return label

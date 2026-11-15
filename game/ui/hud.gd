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
## Segundos sin puntero capturado antes de pedir un clic.
const CLICK_PROMPT_DELAY: float = 0.4

var _player: Player = null
var _health: Label = null
var _vest: Label = null
var _infection: Label = null
var _infection_seconds: int = -1
var _weapon: Label = null
var _prompt: Label = null
var _message: Label = null
var _damage_edge: ColorRect = null
var _message_timer: float = 0.0
var _noise: NoiseIndicator = null
var _subtitles: Subtitles = null
var _boss: BossBar = null
var _rescue: Label = null
var _camera: Label = null
var _rescue_seconds: int = -2
var _healing: HealingPanel = null
var _throw_hint: Label = null
var _click_prompt: Label = null
var _objective: Label = null
var _objective_timer: float = 0.0
var _click_wait: float = 0.0


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
	EventBus.infection_changed.connect(_refresh_infection)
	EventBus.camera_report.connect(_on_camera_report)
	EventBus.game_saved.connect(_on_game_saved)
	EventBus.camera_alert.connect(_on_camera_alert)
	_refresh()


func bind_player(player: Player) -> void:
	_player = player
	_healing.bind_player(player)


func _process(delta: float) -> void:
	# Con la mochila abierta el HUD se esconde (no se lee a través del fondo).
	visible = not InputRouter.menu_open
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.text = ""
	if _damage_edge.color.a > 0.0:
		_damage_edge.color.a = maxf(_damage_edge.color.a - delta / DAMAGE_FADE * 0.35, 0.0)
	_refresh_infection()
	_refresh_rescue()
	_refresh_throw_hint()
	_refresh_click_prompt(delta)
	_objective_timer -= delta
	if _objective_timer <= 0.0:
		_objective_timer = 0.5
		var text := Notebook.objective_text()
		_objective.text = "%s: %s" % [tr("notebook_objective"), text] if not text.is_empty() else ""


## Si el puntero no se pudo recuperar (el navegador lo impide a veces al cerrar un menú), se
## pide un clic. Espera un momento para no parpadear mientras la captura se completa.
func _refresh_click_prompt(delta: float) -> void:
	var needs := (
		InputRouter.needs_click()
		and not GameState.paused
		and _player != null
		and not _player.is_dead()
	)
	_click_wait = _click_wait + delta if needs else 0.0
	_click_prompt.visible = _click_wait > CLICK_PROMPT_DELAY


## Ayuda mientras hay un objeto listo para lanzar.
func _refresh_throw_hint() -> void:
	var aiming := (
		_player != null and _player.throw != null and not _player.throw.ready_item.is_empty()
	)
	_throw_hint.visible = aiming
	if aiming:
		var key := "throw_hint_touch" if InputRouter.touch_mode else "throw_hint"
		_throw_hint.text = tr(key)


## Línea del helicóptero: cuánto falta para que llegue o para que se vaya.
func _refresh_rescue() -> void:
	var clock := GameState.rescue
	if clock == null:
		return
	var seconds := ceili(clock.time_left)
	var key := ""
	match clock.state:
		RescueClock.STATE_INBOUND:
			key = "hud_helicopter_inbound"
		RescueClock.STATE_WAITING:
			key = "hud_helicopter_waiting"
		RescueClock.STATE_DEPARTED:
			key = "hud_helicopter_gone"
			seconds = -1
		_:
			seconds = -2
	if seconds == _rescue_seconds:
		return
	_rescue_seconds = seconds
	if key.is_empty():
		_rescue.text = ""
	elif seconds < 0:
		_rescue.text = tr(key)
	else:
		_rescue.text = "%s %d:%02d" % [tr(key), seconds / 60, seconds % 60]


func _on_game_saved(manual: bool) -> void:
	if not manual:
		_on_message("msg_autosaved")


func _on_camera_report(text: String) -> void:
	_message.text = text
	_message_timer = MESSAGE_TIME * 2.0


func _on_camera_alert(active: bool) -> void:
	_camera.text = tr("hud_camera_alert") if active else ""


## Línea de infección: icono, texto y cuenta atrás (no depende del color).
func _refresh_infection() -> void:
	var state := GameState.player
	if state == null or not state.infection.infected:
		if _infection_seconds != -1:
			_infection_seconds = -1
			_infection.text = ""
		return
	var seconds := ceili(state.infection.time_left)
	if seconds == _infection_seconds:
		return
	_infection_seconds = seconds
	_infection.text = "(!) %s %d:%02d" % [tr("hud_infected"), seconds / 60, seconds % 60]


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


func _on_prompt(text_key: String, detail: String) -> void:
	if text_key.is_empty():
		_prompt.text = ""
		return
	var key_hint := tr("hud_touch_use") if InputRouter.touch_mode else tr("hud_key_use")
	_prompt.text = "%s  %s" % [key_hint, tr(text_key)]
	if not detail.is_empty():
		_prompt.text += ": " + detail


func _on_message(text_key: String) -> void:
	_message.text = tr(text_key)
	_message_timer = MESSAGE_TIME


func _on_damaged(_amount: float) -> void:
	_damage_edge.color.a = 0.18 if Settings.get_bool("reduce_flashes") else 0.35


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
	var marker := HitMarker.new()
	add_child(marker)
	_place(marker, Control.PRESET_CENTER, Rect2(-30.0, -30.0, 60.0, 60.0))
	var status := VBoxContainer.new()
	status.position = Vector2(24.0, 20.0)
	add_child(status)
	_health = _label(status, 28)
	_vest = _label(status, 22)
	_infection = _label(status, 24)
	_infection.add_theme_color_override("font_color", Color(0.75, 1.0, 0.6))
	_rescue = _label(status, 24)
	_camera = _label(status, 22)
	_objective = _label(status, 18)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD
	_objective.custom_minimum_size = Vector2(440.0, 0.0)
	_objective.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_weapon = _label(self, 26)
	_place(_weapon, Control.PRESET_BOTTOM_LEFT, Rect2(24.0, -72.0, 640.0, 44.0))
	_prompt = _label(self, 26)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_prompt, Control.PRESET_CENTER, Rect2(-320.0, 50.0, 640.0, 40.0))
	_message = _label(self, 24)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	_place(_message, Control.PRESET_CENTER_TOP, Rect2(-360.0, 90.0, 720.0, 70.0))
	_noise = NoiseIndicator.new()
	add_child(_noise)
	_place(_noise, Control.PRESET_BOTTOM_LEFT, Rect2(24.0, -112.0, 520.0, 36.0))
	_subtitles = Subtitles.new()
	add_child(_subtitles)
	_boss = BossBar.new()
	add_child(_boss)
	_place(_boss, Control.PRESET_CENTER_TOP, Rect2(-220.0, 16.0, 440.0, 70.0))
	# Arriba y al centro: lejos de los botones táctiles y de la palanca.
	_place(_subtitles, Control.PRESET_CENTER_TOP, Rect2(-300.0, 170.0, 600.0, 0.0))
	# Curación o combinación en curso: a la izquierda, a media altura (lejos de la mira y de
	# los botones).
	_throw_hint = _label(self, 22)
	_throw_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_throw_hint.visible = false
	_place(_throw_hint, Control.PRESET_CENTER, Rect2(-360.0, 90.0, 720.0, 34.0))
	_click_prompt = _label(self, 30)
	_click_prompt.text = tr("hud_click_to_resume")
	_click_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_prompt.visible = false
	_place(_click_prompt, Control.PRESET_CENTER, Rect2(-360.0, -90.0, 720.0, 44.0))
	_healing = HealingPanel.new()
	add_child(_healing)
	_place(_healing, Control.PRESET_CENTER_LEFT, Rect2(24.0, -60.0, 330.0, 0.0))


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

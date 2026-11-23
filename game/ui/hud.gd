class_name Hud
extends Control
## HUD mínimo: salud, chaleco, arma con su estado de desgaste (icono de forma y texto, no
## solo color), munición, indicador de interacción, punto de mira, mensajes y progreso
## de la combinación. El aviso de daño es un borde rojo que se desvanece, sin destellos.

const WEAR_KEYS: Array[String] = ["wear_good", "wear_damaged", "wear_critical", "wear_broken"]
const WEAR_ICONS: Array[String] = ["[###]", "[##-]", "[#--]", "[---]"]
## Tramos de la barra de exposición.
const EXPOSURE_SEGMENTS: int = 5
const MESSAGE_TIME: float = 3.0
## El borde de daño tarda esto en desvanecerse; con un golpe cada ~1,5 s nunca parpadea.
const DAMAGE_FADE: float = 0.8
## Segundos sin puntero capturado antes de pedir un clic.
const CLICK_PROMPT_DELAY: float = 0.4

var _player: Player = null
var _health: Label = null
var _vest: Label = null
var _infection: Label = null
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
var _flashlight: Label = null
var _quick_throw: Label = null
var _objective_timer: float = 0.0
var _click_wait: float = 0.0
## La partida terminó: el HUD queda oculto bajo la pantalla final.
var _finished: bool = false


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
	EventBus.game_saved.connect(_on_game_saved)
	EventBus.camera_alert.connect(_on_camera_alert)
	EventBus.run_finished.connect(func(_outcome: int) -> void: _finished = true)
	get_viewport().size_changed.connect(_fit_safe_area)
	_fit_safe_area()
	_refresh()


func bind_player(player: Player) -> void:
	_player = player
	_healing.bind_player(player)


func _process(delta: float) -> void:
	# Con la mochila abierta o la partida terminada el HUD se esconde (no se lee a través del
	# fondo de la mochila ni detrás del resultado).
	visible = not InputRouter.menu_open and not _finished
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
	_refresh_flashlight()


## Línea de la linterna mientras está encendida: carga en cuatro pasos con forma («[##--]»), o
## el aviso de que va con la luz mínima.
func _refresh_flashlight() -> void:
	var state := GameState.player
	var text := ""
	if state != null and state.flashlight.on:
		var torch := state.flashlight
		if torch.is_empty():
			text = tr("hud_flashlight_empty")
		else:
			var bars := ceili(torch.fraction() * 4.0)
			text = "%s [%s%s]" % [tr("hud_flashlight"), "#".repeat(bars), "-".repeat(4 - bars)]
			if torch.is_low():
				# Aviso con texto (no depende del color ni del parpadeo del haz).
				text += "  " + tr("hud_flashlight_low")
	if text != _flashlight.text:
		_flashlight.text = text


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


func _on_camera_alert(active: bool) -> void:
	_camera.text = tr("hud_camera_alert") if active else ""


## Línea de infección: con infección, icono, texto y cuenta atrás; sin ella, la exposición
## que llenan los golpes, con barra de texto y porcentaje (no depende del color).
func _refresh_infection() -> void:
	_set_infection_text(infection_text(GameState.player))


## Texto de la línea de infección para un estado (vacío sin infección ni exposición).
static func infection_text(state: PlayerState) -> String:
	if state == null:
		return ""
	var infection := state.infection
	if infection.infected:
		var seconds := ceili(infection.time_left)
		return (
			"(!) %s %d:%02d"
			% [TranslationServer.translate("hud_infected"), seconds / 60, seconds % 60]
		)
	if infection.exposure <= 0.0:
		return ""
	var percent := clampi(ceili(infection.exposure * 100.0), 1, 99)
	var filled := clampi(ceili(infection.exposure * EXPOSURE_SEGMENTS), 1, EXPOSURE_SEGMENTS)
	var bar := "#".repeat(filled) + "-".repeat(EXPOSURE_SEGMENTS - filled)
	return "%s [%s] %d %%" % [TranslationServer.translate("hud_exposure"), bar, percent]


func _set_infection_text(value: String) -> void:
	if _infection.text != value:
		_infection.text = value


## Línea de lanzamiento rápido: el material que sale con la tecla de lanzar y cuántos quedan.
func _refresh_quick_throw() -> void:
	var state := GameState.player
	var text := ""
	if state != null:
		var item_id := state.quick_throw_item()
		var item := GameState.items.get_item(item_id) if not item_id.is_empty() else null
		if item != null:
			# En táctil se nombran los botones; con teclado, las teclas.
			var throw_key := InputRouter.key_label("throw")
			var next_key := InputRouter.key_label("throw_next")
			if InputRouter.touch_mode:
				throw_key = tr("touch_throw")
				next_key = tr("touch_throw_next")
			text = (
				tr("hud_quick_throw")
				% [throw_key, tr(item.name_key), state.inventory.bag.count(item_id), next_key]
			)
	_quick_throw.text = text


func _refresh() -> void:
	_refresh_quick_throw()
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
		if WeaponUse.uses_butt(stack, state.inventory):
			# Sin munición, la escopeta golpea con la culata: se dice con texto.
			text += "  " + tr("hud_butt")
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
	_flashlight = _label(status, 22)
	_objective = _label(status, 18)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Ancho suficiente para que los objetivos habituales quepan en una línea.
	_objective.custom_minimum_size = Vector2(560.0, 0.0)
	_objective.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_weapon = _label(self, 26)
	_place(_weapon, Control.PRESET_BOTTOM_LEFT, Rect2(24.0, -72.0, 640.0, 44.0))
	# Qué se lanza con la tecla rápida (y con qué tecla se cambia).
	_quick_throw = _label(self, 20)
	_place(_quick_throw, Control.PRESET_BOTTOM_LEFT, Rect2(24.0, -150.0, 640.0, 34.0))
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
	# Aviso de conversión inminente (bordes y texto); detrás del resto del HUD.
	var warning := ConversionWarning.new()
	add_child(warning)
	move_child(warning, 0)
	# Lo recogido: arriba a la derecha, por encima de los botones táctiles (el más alto, recargar,
	# está al 36 % de la altura).
	var feed := PickupFeed.new()
	add_child(feed)
	_place(feed, Control.PRESET_TOP_RIGHT, Rect2(-420.0, 64.0, 400.0, 150.0))
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
	# Consejos de primera vez: abajo y al centro, lejos de la mira y de los botones.
	var tips := TipBanner.new()
	add_child(tips)
	_place(tips, Control.PRESET_CENTER_BOTTOM, Rect2(-380.0, -200.0, 760.0, 70.0))
	_healing = HealingPanel.new()
	add_child(_healing)
	_place(_healing, Control.PRESET_CENTER_LEFT, Rect2(24.0, -60.0, 330.0, 0.0))


## Todo el HUD dentro de la zona segura (fuera de la muesca del celular en horizontal).
func _fit_safe_area() -> void:
	var screen := get_viewport_rect().size
	var safe := Config.safe_rect(screen)
	offset_left = safe.position.x
	offset_top = safe.position.y
	offset_right = safe.end.x - screen.x
	offset_bottom = safe.end.y - screen.y


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

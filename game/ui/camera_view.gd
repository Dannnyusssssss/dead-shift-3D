class_name CameraView
extends Control
## Monitores de la sala de seguridad: imagen real de una cámara a la vez (SubViewport de baja
## resolución que solo se renderiza con el visor abierto), su nombre, el informe escrito de
## enemigos por piso y botones para cambiar de cámara (también con las flechas). Se cierra con
## «Cerrar» o pausa. Mientras se mira, el piso de la cámara se hace visible aunque el jugador esté
## lejos (sus enemigos se ven quietos). El jugador queda quieto.

## Cabeceo de las cámaras (miran hacia abajo).
const PITCH_DEG: float = -24.0
const FOV: float = 70.0

var _player: Player = null
## Cuadro en que se abrió (la pulsación de E que lo abre no lo cierra).
var _opened_frame: int = -1
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _name: Label = null
var _report: Label = null
var _spots: Array[Dictionary] = []
var _index: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_viewport = SubViewport.new()
	_viewport.size = Rules.CAMERA_RESOLUTION
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_viewport.add_child(_camera)
	_camera.current = true
	_build_layout()
	EventBus.cameras_requested.connect(open)


func bind_player(player: Player) -> void:
	_player = player


func is_open() -> bool:
	return visible


## Verdadero mientras el SubViewport se está renderizando (solo con el visor abierto).
func is_rendering() -> bool:
	return _viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED


func open() -> void:
	if _player == null or _player.is_dead():
		return
	_spots = CameraSpots.from_floors(GameState.CATALOG.floors)
	if _spots.is_empty():
		return
	visible = true
	_opened_frame = Engine.get_process_frames()
	_player.set_blocked("cameras", true)
	InputRouter.menu_open = true
	InputRouter.release_capture()
	_show(clampi(_index, 0, _spots.size() - 1))


func close() -> void:
	if not visible:
		return
	visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var building := _building()
	if building != null:
		building.set_viewed_floor(-1)
	if _player != null:
		_player.set_blocked("cameras", false)
	InputRouter.menu_open = false
	# Con un clic o con E (gestos) se recupera el puntero sin pedir otro clic.
	InputRouter.request_capture()


## Cambia a la cámara siguiente (1) o anterior (-1).
func cycle(direction: int) -> void:
	if visible:
		_show(CameraSpots.step(_index, _spots.size(), direction))


func current_name_key() -> String:
	return _spots[_index]["name_key"] if not _spots.is_empty() else ""


func _process(_delta: float) -> void:
	if not visible or GameState.paused:
		return
	var reopened := Engine.get_process_frames() == _opened_frame
	if InputRouter.just_pressed("pause") or (InputRouter.just_pressed("interact") and not reopened):
		close()
	elif InputRouter.just_pressed("ui_left"):
		cycle(-1)
	elif InputRouter.just_pressed("ui_right"):
		cycle(1)


func _show(index: int) -> void:
	_index = index
	var spot := _spots[index]
	var position_3d: Vector3 = spot["position"]
	var yaw: float = spot["yaw"]
	var name_key: String = spot["name_key"]
	var floor_index: int = spot["floor_index"]
	_camera.global_transform = Transform3D(
		Basis.from_euler(Vector3(deg_to_rad(PITCH_DEG), deg_to_rad(yaw), 0.0)), position_3d
	)
	_name.text = "%s %d/%d · %s" % [tr("cameras_title"), index + 1, _spots.size(), tr(name_key)]
	_report.text = SecurityMonitor.report()
	var building := _building()
	if building != null:
		building.set_viewed_floor(floor_index)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _building() -> Building:
	return _player.get_parent() as Building if _player != null else null


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 24)
	left.add_child(_name)
	var screen := TextureRect.new()
	screen.texture = _viewport.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(screen)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	left.add_child(buttons)
	_button(buttons, "cameras_prev", cycle.bind(-1))
	_button(buttons, "cameras_next", cycle.bind(1))
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300.0, 0.0)
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)
	_button(right, "inventory_close", close)
	_report = Label.new()
	_report.add_theme_font_size_override("font_size", 18)
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_report)


func _button(parent: Control, text_key: String, callback: Callable) -> TapButton:
	var button := TapButton.new()
	button.text = tr(text_key)
	button.custom_minimum_size = Vector2(150.0, 56.0)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

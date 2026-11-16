class_name Outro
extends Node
## Escena final corta, en la azotea del propio edificio, con un helicóptero y un guardia propios
## (el helicóptero del nivel se esconde mientras tanto). Según el desenlace:
##   - Rescate: el helicóptero baja y se posa, el guardia corre a la puerta y sube, despega y se
##     aleja sobre la ciudad mientras la cámara se retira.
##   - Caída: igual hasta despegar; en pleno vuelo el helicóptero se tambalea, gira y cae detrás
##     del edificio (visto de lejos, sin sangre ni explosión) y la imagen se funde a negro.
##   - Rescate perdido: el helicóptero se va y el guardia se queda mirando desde el helipuerto.
## Texto abajo (se entiende sin sonido); se salta con el botón, una tecla, clic o toque, y con
## «Reducir movimiento» son planos fijos que se funden.

signal finished

const PEOPLE: String = "res://assets/generated/people/"
const VEHICLES: String = "res://assets/generated/vehicles/"
## Tiempos de cada parte (segundos).
const LAND_SECONDS: float = 2.6
const BOARD_SECONDS: float = 1.6
const LIFT_SECONDS: float = 1.6
const AWAY_SECONDS: float = 4.0
const FALL_SECONDS: float = 3.0
const LOST_SECONDS: float = 4.5
const STILL_SECONDS: float = 2.2
const FADE: float = 0.5
## Altura desde la que baja, a la que flota y lado de la puerta (el +Z del modelo).
const START_HEIGHT: float = 12.0
const HOVER_HEIGHT: float = 0.6
const DOOR_OFFSET: Vector3 = Vector3(0.0, 0.0, 2.2)

var outcome: int = RunStats.OUTCOME_RESCUED
var pad: Vector3 = Vector3.ZERO
var guard_start: Vector3 = Vector3.ZERO
## Etapa en curso, para las pruebas: "land", "board", "away", "fall", "lost" o "".
var stage: String = ""
var _level: Node3D = null
var _camera: Camera3D = null
var _heli: Node3D = null
var _rotor: Node3D = null
var _guard: EnemyModel = null
var _caption: Label = null
var _black: ColorRect = null
var _done: bool = false
var _hidden: Array[Node3D] = []


## level: nodo 3D del edificio; pad: helipuerto; guard_from: dónde está el jugador.
func setup(level: Node3D, pad_point: Vector3, guard_from: Vector3, final_outcome: int) -> void:
	_level = level
	pad = pad_point
	guard_start = Vector3(guard_from.x, pad_point.y, guard_from.z)
	outcome = final_outcome


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	if _level == null:
		skip.call_deferred()
		return
	_build_scene()
	_run()


func _process(delta: float) -> void:
	if _rotor != null:
		# Giro constante del rotor (sin destellos).
		_rotor.rotate_y(delta * 7.0)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		skip()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		skip()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip()


func skip() -> void:
	if _done:
		return
	_done = true
	for node: Node3D in [_camera, _heli, _guard]:
		if node != null:
			node.queue_free()
	finished.emit()


func _run() -> void:
	_camera.make_current()
	var still := Settings.get_bool("reduce_motion")
	if outcome == RunStats.OUTCOME_LOST:
		await _run_lost(still)
	else:
		await _run_rescue(still, outcome == RunStats.OUTCOME_CRASHED)
	skip()


func _run_rescue(still: bool, crashes: bool) -> void:
	_caption.text = tr("outro_crashed" if crashes else "outro_rescued")
	var hover := pad + Vector3.UP * HOVER_HEIGHT
	# Baja y se posa.
	stage = "land"
	_look(pad + Vector3(9.0, 4.0, 9.0), pad + Vector3.UP * 1.5)
	if still:
		_heli.global_position = hover
		_guard.global_position = pad + DOOR_OFFSET + Vector3(0.6, 0.0, 0.8)
		await _hold(STILL_SECONDS)
	else:
		_heli.global_position = pad + Vector3.UP * START_HEIGHT
		await _move(_heli, hover, LAND_SECONDS, Tween.EASE_OUT)
	if _done:
		return
	# El guardia corre a la puerta y sube.
	stage = "board"
	var door := pad + DOOR_OFFSET
	if not still:
		_guard.play_named("run")
		_guard.look_at(Vector3(door.x, _guard.global_position.y, door.z), Vector3.UP)
		await _move(_guard, door, BOARD_SECONDS, Tween.EASE_IN_OUT)
	_guard.visible = false
	if _done:
		return
	# Despega y se aleja (la cámara se retira).
	stage = "away"
	var away := pad + Vector3(-40.0, 26.0, -6.0)
	if still:
		await _fade_to(1.0)
		_heli.global_position = pad + Vector3(-14.0, 12.0, -2.0)
		_look(pad + Vector3(16.0, 10.0, 16.0), _heli.global_position)
		await _fade_to(0.0)
		await _hold(STILL_SECONDS)
	else:
		await _move(_heli, hover + Vector3.UP * 6.0, LIFT_SECONDS, Tween.EASE_IN_OUT)
		_follow_camera(pad + Vector3(9.0, 4.0, 9.0), pad + Vector3(22.0, 14.0, 22.0), AWAY_SECONDS)
		var far := away if not crashes else pad + Vector3(-18.0, 14.0, -3.0)
		var leg := AWAY_SECONDS if not crashes else AWAY_SECONDS * 0.55
		await _move(_heli, far, leg, Tween.EASE_IN)
	if _done or not crashes:
		return
	# Caída: se tambalea, gira y baja detrás del edificio; fundido a negro.
	stage = "fall"
	_caption.text = tr("outro_crashed_fall")
	if still:
		await _fade_to(1.0)
		_heli.global_position = pad + Vector3(-22.0, 6.0, 2.0)
		_heli.rotation = Vector3(0.5, 1.2, 0.6)
		await _fade_to(0.0)
		await _hold(STILL_SECONDS)
	else:
		var start := _heli.global_position
		var end := pad + Vector3(-30.0, -10.0, 6.0)
		var tween := create_tween()
		tween.tween_method(
			func(t: float) -> void:
				_heli.global_position = start.lerp(end, t * t)
				_heli.rotation = Vector3(
					sin(t * 9.0) * 0.4 * t, t * TAU * 1.5, sin(t * 7.0) * 0.5 * t
				),
			0.0,
			1.0,
			FALL_SECONDS
		)
		await tween.finished
	await _fade_to(1.0)


func _run_lost(still: bool) -> void:
	_caption.text = tr("outro_lost")
	stage = "lost"
	_guard.global_position = guard_start
	_guard.play_named("idle")
	var behind := guard_start + Vector3(2.2, 1.9, 2.2)
	var hover := pad + Vector3.UP * HOVER_HEIGHT
	var away := pad + Vector3(-38.0, 24.0, -8.0)
	if still:
		_heli.global_position = pad + Vector3(-16.0, 13.0, -4.0)
		_look(behind, _heli.global_position)
		await _hold(STILL_SECONDS + 1.0)
		return
	_heli.global_position = hover + Vector3.UP * 3.0
	_look(behind, _heli.global_position)
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_heli.global_position = (hover + Vector3.UP * 3.0).lerp(away, t * t)
			_camera.look_at(_heli.global_position, Vector3.UP),
		0.0,
		1.0,
		LOST_SECONDS
	)
	await tween.finished


func _look(from: Vector3, target: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(target, Vector3.UP)


## La cámara se retira mientras sigue al helicóptero.
func _follow_camera(from: Vector3, to: Vector3, seconds: float) -> void:
	var tween := create_tween()
	(
		tween
		. tween_method(
			func(t: float) -> void:
				_camera.global_position = from.lerp(to, t)
				_camera.look_at(_heli.global_position, Vector3.UP),
			0.0,
			1.0,
			seconds
		)
		. set_trans(Tween.TRANS_SINE)
	)


func _move(node: Node3D, target: Vector3, seconds: float, ease_type: Tween.EaseType) -> void:
	var tween := create_tween()
	(
		tween
		. tween_property(node, "global_position", target, seconds)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(ease_type)
	)
	await tween.finished


func _hold(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_black, "color:a", alpha, FADE)
	await tween.finished


func _build_scene() -> void:
	# El helicóptero del nivel se esconde: este es el que se ve en la escena.
	for node: Node in _level.find_children("*", "Node3D", true, false):
		if node is Helicopter:
			for child: Node in node.get_children():
				if child is Node3D and (child as Node3D).visible and not child is Label3D:
					(child as Node3D).visible = false
					_hidden.append(child)
	_camera = Camera3D.new()
	_camera.fov = 65.0
	_level.add_child(_camera)
	_heli = Node3D.new()
	_level.add_child(_heli)
	var hull := ItemModels.instance_from_path(VEHICLES + "helicopter_body.glb")
	if hull != null:
		_heli.add_child(hull)
	_rotor = ItemModels.instance_from_path(VEHICLES + "helicopter_rotor.glb")
	if _rotor == null:
		_rotor = Node3D.new()
	_rotor.position = Vector3(0.3, 3.12, 0.0)
	_heli.add_child(_rotor)
	_heli.global_position = pad + Vector3.UP * START_HEIGHT
	_guard = EnemyModel.create_from(PEOPLE + "guard.glb")
	if _guard == null:
		_guard = EnemyModel.new()
	_level.add_child(_guard)
	_guard.global_position = guard_start
	_guard.play_named("idle")


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0, 0.0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_black)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -140
	_caption.offset_bottom = -60
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(_caption)
	var skip_button := TapButton.new()
	skip_button.text = tr("intro_skip")
	skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_button.offset_left = -200
	skip_button.offset_top = 24
	skip_button.offset_right = -24
	skip_button.custom_minimum_size = Vector2(160, 56)
	skip_button.pressed.connect(skip)
	layer.add_child(skip_button)

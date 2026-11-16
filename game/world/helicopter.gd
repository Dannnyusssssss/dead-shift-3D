class_name Helicopter
extends Node3D
## Helicóptero de rescate sobre el helipuerto: aparece mientras espera en la azotea y se va al
## terminar la espera o al subir el jugador. El rotor gira a velocidad constante (sin destellos)
## y el helipuerto lleva una «H» grande y un rótulo.

const HOVER_HEIGHT: float = 0.6
const VEHICLES: String = "res://assets/generated/vehicles/"

var _body: Node3D = null
var _rotor: MeshInstance3D = null
var _tail_rotor: MeshInstance3D = null
var _engine: AudioStreamPlayer3D = null


func _ready() -> void:
	var pad := Label3D.new()
	pad.text = "H"
	pad.font_size = 512
	pad.pixel_size = 0.01
	pad.rotation.x = -PI * 0.5
	pad.position.y = 0.03
	pad.modulate = Color(0.95, 0.9, 0.3)
	add_child(pad)
	_body = Node3D.new()
	_body.visible = false
	add_child(_body)
	# Modelos de tools/blender/vehicles.py: morro hacia -X y puerta abierta en el lado +Z.
	var hull := ItemModels.instance_from_path(VEHICLES + "helicopter_body.glb")
	if hull != null:
		_body.add_child(hull)
	_rotor = ItemModels.instance_from_path(VEHICLES + "helicopter_rotor.glb")
	if _rotor == null:
		_rotor = MeshInstance3D.new()
	_rotor.position = Vector3(0.3, 3.12, 0.0)
	_body.add_child(_rotor)
	_tail_rotor = ItemModels.instance_from_path(VEHICLES + "helicopter_tail_rotor.glb")
	if _tail_rotor == null:
		_tail_rotor = MeshInstance3D.new()
	_tail_rotor.position = Vector3(5.6, 1.9, 0.14)
	_body.add_child(_tail_rotor)
	# Rotor que se oye de lejos (el aviso escrito «Helicóptero» lo da el juego aparte).
	_engine = AudioStreamPlayer3D.new()
	_engine.bus = "SFX"
	_engine.max_distance = 80.0
	_engine.unit_size = 12.0
	_engine.stream = AudioDirector.loop_stream("helicopter_loop")
	_body.add_child(_engine)
	EventBus.rescue_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	if _body.visible:
		# Giro constante: con «Reducir movimiento» igual de lento, sin parpadeo.
		_rotor.rotate_y(delta * 6.0)
		_tail_rotor.rotate_z(delta * 9.0)


func _refresh() -> void:
	var waiting := GameState.rescue != null and GameState.rescue.state == RescueClock.STATE_WAITING
	if waiting and not _body.visible:
		_body.visible = true
		if not AudioDirector.is_silent():
			_engine.play()
		_body.position.y = 12.0
		var tween := create_tween()
		tween.tween_property(_body, "position:y", HOVER_HEIGHT, 3.0)
	elif not waiting and _body.visible:
		var tween := create_tween()
		tween.tween_property(_body, "position:y", 25.0, 3.0)
		tween.tween_callback(
			func() -> void:
				_body.visible = false
				_engine.stop()
		)

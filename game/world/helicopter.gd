class_name Helicopter
extends Node3D
## Helicóptero provisional sobre el helipuerto: aparece mientras espera en la azotea y se va al
## terminar la espera o al subir el jugador. El rotor gira a velocidad constante (sin destellos)
## y el helipuerto lleva una «H» grande y un rótulo.

const HOVER_HEIGHT: float = 0.6

var _body: Node3D = null
var _rotor: MeshInstance3D = null


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
	var hull := MeshInstance3D.new()
	var hull_mesh := CapsuleMesh.new()
	hull_mesh.radius = 1.1
	hull_mesh.height = 4.4
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.25, 0.32, 0.22)
	hull_mesh.material = paint
	hull.mesh = hull_mesh
	hull.rotation.z = PI * 0.5
	hull.position.y = 1.4
	_body.add_child(hull)
	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(4.0, 0.35, 0.35)
	tail_mesh.material = paint
	tail.mesh = tail_mesh
	tail.position = Vector3(3.6, 1.8, 0.0)
	_body.add_child(tail)
	_rotor = MeshInstance3D.new()
	var rotor_mesh := BoxMesh.new()
	rotor_mesh.size = Vector3(8.0, 0.06, 0.3)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.1)
	rotor_mesh.material = dark
	_rotor.mesh = rotor_mesh
	_rotor.position.y = 2.7
	_body.add_child(_rotor)
	EventBus.rescue_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	if _body.visible:
		# Giro constante: con «Reducir movimiento» igual de lento, sin parpadeo.
		_rotor.rotate_y(delta * 6.0)


func _refresh() -> void:
	var waiting := GameState.rescue != null and GameState.rescue.state == RescueClock.STATE_WAITING
	if waiting and not _body.visible:
		_body.visible = true
		_body.position.y = 12.0
		var tween := create_tween()
		tween.tween_property(_body, "position:y", HOVER_HEIGHT, 3.0)
	elif not waiting and _body.visible:
		var tween := create_tween()
		tween.tween_property(_body, "position:y", 25.0, 3.0)
		tween.tween_callback(func() -> void: _body.visible = false)

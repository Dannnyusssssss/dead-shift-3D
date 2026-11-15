class_name Lure
extends Node3D
## Señuelo en el suelo (botella ruidosa): hace ruido alto cada segundo durante un tiempo y atrae
## a los enemigos que oyen hacia ese punto. Después se apaga y desaparece.

## Segundos entre ruidos.
const INTERVAL: float = 1.0

var time_left: float = 0.0

var _timer: float = 0.0


func _ready() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.06
	mesh.height = 0.22
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.62, 0.5)
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = 0.11
	add_child(instance)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = INTERVAL
		NoiseSystem.emit_noise(global_position, Rules.NOISE_HIGH)
		EventBus.sound_cue.emit("cue_lure", global_position)
	time_left -= delta
	if time_left <= 0.0:
		queue_free()

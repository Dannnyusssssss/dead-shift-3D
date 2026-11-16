class_name Lure
extends Node3D
## Señuelo en el suelo (botella ruidosa): hace ruido alto cada segundo durante un tiempo y atrae
## hacia ese punto a todos los enemigos cercanos de su piso (también a los que no oyen el resto
## de ruidos): se ve cómo van hacia él, así sirve para apartarlos de una puerta o de una pieza.
## Después se apaga y desaparece.

## Segundos entre ruidos.
const INTERVAL: float = 1.0
## Radio (m) dentro del que llama a los enemigos.
const PULL_RADIUS: float = 14.0

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
		EventBus.lure_pulled.emit(global_position, PULL_RADIUS)
		EventBus.sound_cue.emit("cue_lure", global_position)
	time_left -= delta
	if time_left <= 0.0:
		queue_free()

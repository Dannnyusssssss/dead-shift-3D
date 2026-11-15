class_name ThrownItem
extends Node3D
## Objeto lanzado por el jugador. Vuela con una trayectoria simple (gravedad y rayo por
## fotograma, sin física de cuerpos para que sea reproducible) y al chocar hace ruido en ese
## punto: los oyentes van hacia allí. Si es frágil se rompe; si es un señuelo sigue haciendo
## ruido unos segundos; si no, queda en el suelo para recogerlo.

const GRAVITY: float = 9.8
## Segundos máximos de vuelo antes de caer donde esté.
const MAX_FLIGHT: float = 4.0

var stack: ItemStack = null
var velocity: Vector3 = Vector3.ZERO

var _ray: PhysicsRayQueryParameters3D = null
var _flight: float = 0.0
var _exclude: Array[RID] = []


## Prepara el lanzamiento: la casilla (una unidad), la velocidad inicial y los cuerpos que el
## objeto atraviesa (el propio jugador).
func setup(new_stack: ItemStack, start_velocity: Vector3, exclude: Array[RID]) -> void:
	stack = new_stack
	velocity = start_velocity
	_exclude = exclude


func _ready() -> void:
	_ray = PhysicsRayQueryParameters3D.create(
		Vector3.ZERO, Vector3.ZERO, Rules.LAYER_WORLD | Rules.LAYER_ENEMY | Rules.LAYER_DOOR
	)
	_ray.exclude = _exclude
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.2)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.75, 0.65) if _is_fragile() else Color(0.75, 0.7, 0.45)
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)


func _physics_process(delta: float) -> void:
	_flight += delta
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	_ray.from = from
	_ray.to = to
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	if not hit.is_empty():
		var point: Vector3 = hit.get("position", to)
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		_land(point + normal * 0.1)
		return
	global_position = to
	if _flight >= MAX_FLIGHT:
		_land(to)


func _land(point: Vector3) -> void:
	set_physics_process(false)
	if stack != null and stack.item.lure_time > 0.0:
		var lure := Lure.new()
		lure.time_left = stack.item.lure_time
		get_parent().add_child(lure)
		lure.global_position = point
	elif _is_fragile():
		NoiseSystem.emit_noise(point, Rules.NOISE_THROW_BREAK)
		EventBus.sound_cue.emit("cue_glass_break", point)
	else:
		NoiseSystem.emit_noise(point, Rules.NOISE_THROW_LAND)
		EventBus.sound_cue.emit("cue_object_fall", point)
		if stack != null:
			EventBus.item_dropped.emit(point, stack)
	queue_free()


func _is_fragile() -> bool:
	return stack != null and stack.item.fragile

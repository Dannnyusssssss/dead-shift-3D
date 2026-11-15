class_name LootSpawner
extends Node3D
## Crea en el mundo los objetos que sueltan los enemigos al morir y los que suelta el jugador.
## Cada objeto se apoya en el suelo que tenga debajo (el edificio tiene varios pisos).

const PICKUP_SCRIPT: GDScript = preload("res://game/world/pickup.gd")
const SPREAD: float = 0.45
## Hasta dónde se busca el suelo hacia abajo desde el punto de origen.
const GROUND_SEARCH: float = 12.0

var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_ray.collision_mask = Rules.LAYER_WORLD
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.item_dropped.connect(_on_item_dropped)


## Crea un objeto suelto. Con snap, lo baja hasta el suelo que tenga debajo; si no, se queda a
## la altura dada (al restaurar una partida, antes de que exista la física del piso).
func spawn(origin: Vector3, stack: ItemStack, snap: bool = true) -> Pickup:
	var pickup: Pickup = PICKUP_SCRIPT.new()
	pickup.setup(stack)
	add_child(pickup)
	pickup.global_position = _ground(origin) if snap else origin
	return pickup


func _ground(origin: Vector3) -> Vector3:
	_ray.from = origin + Vector3.UP * 0.6
	_ray.to = origin + Vector3.DOWN * GROUND_SEARCH
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty():
		return origin
	var point: Vector3 = hit["position"]
	return point


func _on_enemy_died(origin: Vector3, drops: Array[ItemStack]) -> void:
	for index: int in drops.size():
		var angle := TAU * float(index) / maxf(float(drops.size()), 1.0)
		spawn(origin + Vector3(cos(angle), 0.0, sin(angle)) * SPREAD, drops[index])


func _on_item_dropped(origin: Vector3, stack: ItemStack) -> void:
	spawn(origin, stack)

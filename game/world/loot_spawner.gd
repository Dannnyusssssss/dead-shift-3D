class_name LootSpawner
extends Node3D
## Crea en el mundo los objetos que sueltan los enemigos al morir y los que suelta el jugador.

const PICKUP_SCRIPT: GDScript = preload("res://game/world/pickup.gd")
const SPREAD: float = 0.45


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.item_dropped.connect(_on_item_dropped)


func spawn(origin: Vector3, stack: ItemStack) -> Pickup:
	var pickup: Pickup = PICKUP_SCRIPT.new()
	pickup.setup(stack)
	add_child(pickup)
	pickup.global_position = Vector3(origin.x, 0.0, origin.z)
	return pickup


func _on_enemy_died(origin: Vector3, drops: Array[ItemStack]) -> void:
	for index: int in drops.size():
		var angle := TAU * float(index) / maxf(float(drops.size()), 1.0)
		spawn(origin + Vector3(cos(angle), 0.0, sin(angle)) * SPREAD, drops[index])


func _on_item_dropped(origin: Vector3, stack: ItemStack) -> void:
	spawn(origin, stack)

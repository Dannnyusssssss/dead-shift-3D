class_name Pickup
extends Interactable
## Objeto en el suelo. Al usarlo pasa al inventario; un chaleco se viste directamente y el
## que llevaba el jugador queda en el suelo en su lugar (así puede comparar y cambiarlos).
## Se coloca en el nivel con item_id y count, o se crea en juego con setup().

const SIZE_BY_CATEGORY: Dictionary = {
	ItemData.CATEGORY_MATERIAL: Vector3(0.25, 0.12, 0.25),
	ItemData.CATEGORY_AMMO: Vector3(0.2, 0.12, 0.14),
	ItemData.CATEGORY_WEAPON: Vector3(0.12, 0.08, 0.7),
	ItemData.CATEGORY_VEST: Vector3(0.5, 0.12, 0.45),
}
const COLOR_BY_CATEGORY: Dictionary = {
	ItemData.CATEGORY_MATERIAL: Color(0.75, 0.7, 0.45),
	ItemData.CATEGORY_AMMO: Color(0.85, 0.65, 0.2),
	ItemData.CATEGORY_WEAPON: Color(0.6, 0.6, 0.65),
	ItemData.CATEGORY_VEST: Color(0.2, 0.25, 0.2),
}

@export var item_id: String = ""
@export var count: int = 1
## Fracción de durabilidad con que aparece (armas y chalecos).
@export_range(0.0, 1.0) var durability_fraction: float = 1.0

var stack: ItemStack = null


func _ready() -> void:
	super._ready()
	if stack == null:
		var data: ItemData = null
		if Validation.is_valid_id(item_id):
			data = GameState.items.get_item(item_id)
		if data == null:
			ErrorLog.report("unknown_pickup", item_id)
			queue_free()
			return
		stack = ItemStack.new(data, count, durability_fraction)
	_build()
	add_to_group("pickup")


## Prepara el objeto con una casilla creada en juego (botín, objeto soltado).
func setup(new_stack: ItemStack) -> void:
	stack = new_stack
	item_id = new_stack.id()


func get_prompt_key() -> String:
	if not enabled or stack == null:
		return ""
	if stack.is_vest():
		return "prompt_swap_vest" if GameState.player.vest != null else "prompt_wear_vest"
	return "prompt_pick_up"


func interact(player: Player) -> void:
	if stack == null or not enabled:
		return
	var state := GameState.player
	if stack.is_vest():
		var old := state.swap_vest(stack)
		EventBus.vest_changed.emit()
		if old != null:
			player.drop_stack(old)
		_consume(player)
		return
	if not state.inventory.add_stack(stack):
		EventBus.user_message.emit("msg_inventory_full")
		EventBus.inventory_changed.emit()
		return
	EventBus.inventory_changed.emit()
	EventBus.weapon_changed.emit()
	_consume(player)


func _consume(player: Player) -> void:
	enabled = false
	used.emit(player)
	queue_free()


func _build() -> void:
	var category := stack.item.category
	var size: Vector3 = SIZE_BY_CATEGORY.get(category, Vector3(0.25, 0.25, 0.25))
	var color: Color = COLOR_BY_CATEGORY.get(category, Color.WHITE)
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.15 * stack.durability.state())
	material.emission_enabled = true
	material.emission = color * 0.15
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = size.y * 0.5
	add_child(instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size + Vector3(0.3, 0.4, 0.3)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	add_child(shape)

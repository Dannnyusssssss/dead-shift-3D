class_name LootContainer
extends Interactable
## Cajón, caja registradora o casillero con objetos dentro (munición escondida, materiales).
## Al registrarlo pasa al inventario lo que quepa; lo que no, se queda dentro.
## El contenido se define en la escena del nivel como "id:cantidad".

const KIND_DRAWER: int = 0
const KIND_REGISTER: int = 1
const KIND_LOCKER: int = 2
const SIZES: Array[Vector3] = [
	Vector3(0.6, 0.4, 0.5), Vector3(0.5, 0.25, 0.4), Vector3(0.5, 1.8, 0.5)
]
const COLORS: Array[Color] = [Color(0.45, 0.32, 0.2), Color(0.3, 0.3, 0.32), Color(0.35, 0.4, 0.45)]

@export var kind: int = KIND_DRAWER
## Contenido: lista de "id:cantidad" (por ejemplo "pistol_ammo:6").
@export var contents: PackedStringArray = PackedStringArray()

var _remaining: Array[ItemStack] = []
var _body: MeshInstance3D = null
var _material: StandardMaterial3D = null


func _ready() -> void:
	super._ready()
	prompt_key = "prompt_search"
	for entry: String in contents:
		var stack := _parse_entry(entry)
		if stack != null:
			_remaining.append(stack)
	_build()


func is_empty() -> bool:
	return _remaining.is_empty()


func interact(player: Player) -> void:
	if not enabled:
		return
	var inventory := GameState.player.inventory
	var kept: Array[ItemStack] = []
	for stack: ItemStack in _remaining:
		if not inventory.add_stack(stack):
			kept.append(stack)
	_remaining = kept
	if not _remaining.is_empty():
		EventBus.user_message.emit("msg_inventory_full")
	else:
		enabled = false
		_open_visual()
	EventBus.inventory_changed.emit()
	EventBus.weapon_changed.emit()
	used.emit(player)


func _parse_entry(entry: String) -> ItemStack:
	var parts := entry.split(":")
	var item_id := parts[0]
	var amount := 1
	if parts.size() > 1 and parts[1].is_valid_int():
		amount = parts[1].to_int()
	var data: ItemData = null
	if Validation.is_valid_id(item_id):
		data = GameState.items.get_item(item_id)
	if data == null:
		ErrorLog.report("unknown_container_item", item_id)
		return null
	return ItemStack.new(data, clampi(amount, 1, data.max_stack))


func _build() -> void:
	var index := clampi(kind, 0, SIZES.size() - 1)
	var size := SIZES[index]
	_body = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	_material = StandardMaterial3D.new()
	_material.albedo_color = COLORS[index]
	mesh.material = _material
	_body.mesh = mesh
	_body.position.y = size.y * 0.5
	add_child(_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size + Vector3(0.1, 0.1, 0.1)
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	# Cuerpo sólido: no se atraviesa y la navegación lo rodea. El área de interacción es un
	# poco mayor, así que el rayo de interacción la encuentra primero.
	var solid := StaticBody3D.new()
	solid.collision_layer = Rules.LAYER_WORLD
	solid.collision_mask = 0
	var solid_shape := CollisionShape3D.new()
	var solid_box := BoxShape3D.new()
	solid_box.size = size
	solid_shape.shape = solid_box
	solid_shape.position.y = size.y * 0.5
	solid.add_child(solid_shape)
	add_child(solid)


func _open_visual() -> void:
	# Registrado y vacío: se oscurece y se hunde un poco, para distinguirlo sin depender del color.
	var tween := create_tween()
	tween.tween_property(_body, "scale", Vector3(1.0, 0.85, 1.0), 0.25)
	_material.albedo_color = _material.albedo_color.darkened(0.4)

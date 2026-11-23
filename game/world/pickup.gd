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
	ItemData.CATEGORY_CONSUMABLE: Vector3(0.18, 0.1, 0.12),
}
const COLOR_BY_CATEGORY: Dictionary = {
	ItemData.CATEGORY_MATERIAL: Color(0.75, 0.7, 0.45),
	ItemData.CATEGORY_AMMO: Color(0.85, 0.65, 0.2),
	ItemData.CATEGORY_WEAPON: Color(0.6, 0.6, 0.65),
	ItemData.CATEGORY_VEST: Color(0.2, 0.25, 0.2),
	ItemData.CATEGORY_CONSUMABLE: Color(0.85, 0.85, 0.9),
}
## Escala de los objetos pequeños en el suelo (curas, materiales, munición, llaves).
const SMALL_ITEM_SCALE: float = 2.6
const VEST_SCALE: float = 1.2
## Vueltas por segundo (en radianes) del aro que señala el objeto.
const RING_SPIN: float = 0.8
## Distancia (m) a la que aparece el nombre del objeto flotando encima (se lee sin apuntarle).
const NAME_DISTANCE: float = 4.5

@export var item_id: String = ""
@export var count: int = 1
## Fracción de durabilidad con que aparece (armas y chalecos).
@export_range(0.0, 1.0) var durability_fraction: float = 1.0

var stack: ItemStack = null
## Clave del punto de botín del piso ("" si se creó en juego: botín u objeto soltado).
var spot_key: String = ""

var _ring: MeshInstance3D = null
var _name_label: Label3D = null


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
	DrawDistance.mark(self, DrawDistance.SMALL)


## Escala del modelo en el suelo: las armas y el chaleco casi a su tamaño; lo pequeño (curas,
## materiales, munición, llaves) se agranda para que se vea.
static func scale_for(category: int) -> float:
	if category == ItemData.CATEGORY_WEAPON:
		return 1.0
	if category == ItemData.CATEGORY_VEST:
		return VEST_SCALE
	return SMALL_ITEM_SCALE


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


func get_prompt_detail() -> String:
	if not enabled or stack == null:
		return ""
	var name := tr(stack.item.name_key)
	return name + (" x%d" % stack.count if stack.count > 1 else "")


## Datos para guardar este objeto si queda en el suelo al cambiar de piso.
func to_drop_entry() -> Dictionary:
	return {
		"id": stack.id(),
		"count": stack.count,
		"durability": stack.durability.fraction(),
		"ammo": stack.ammo_loaded,
		"x": global_position.x,
		"z": global_position.z,
	}


func interact(player: Player) -> void:
	if stack == null or not enabled:
		return
	var state := GameState.player
	var item_id := stack.id()
	var amount := stack.count
	if stack.item.category == ItemData.CATEGORY_KEY:
		state.keys.add(item_id)
		EventBus.key_items_changed.emit()
		EventBus.user_message.emit("msg_key_item")
		EventBus.item_obtained.emit(item_id, amount)
		_consume(player)
		return
	if stack.is_vest():
		var old := state.swap_vest(stack)
		EventBus.vest_changed.emit()
		if old != null:
			player.drop_stack(old)
		EventBus.item_obtained.emit(item_id, 1)
		_consume(player)
		return
	if not state.inventory.add_stack(stack):
		# Puede que entrara una parte (bolsa o casillas casi llenas): se avisa de esa parte.
		if stack.count < amount:
			EventBus.item_obtained.emit(item_id, amount - stack.count)
		EventBus.user_message.emit("msg_inventory_full")
		EventBus.inventory_changed.emit()
		return
	EventBus.inventory_changed.emit()
	EventBus.weapon_changed.emit()
	EventBus.item_obtained.emit(item_id, amount)
	_consume(player)


func _consume(player: Player) -> void:
	AudioDirector.play("pickup")
	enabled = false
	used.emit(player)
	queue_free()


func _build() -> void:
	var category := stack.item.category
	var size: Vector3 = SIZE_BY_CATEGORY.get(category, Vector3(0.25, 0.25, 0.25))
	var color: Color = COLOR_BY_CATEGORY.get(category, Color.WHITE)
	var model := ItemModels.instance(stack.id(), stack.durability.state(), true)
	if model != null:
		# Modelo del objeto apoyado en el suelo; los pequeños se agrandan para que se vean.
		var bounds := model.mesh.get_aabb()
		var scale_up := scale_for(category)
		model.scale = Vector3.ONE * scale_up
		model.position.y = -bounds.position.y * scale_up + 0.01
		add_child(model)
		size = Vector3(
			maxf(bounds.size.x * scale_up, 0.2), bounds.size.y, maxf(bounds.size.z * scale_up, 0.2)
		)
		_add_ring(color, size)
		_add_shape(size)
		_add_name(size.y * scale_up)
		return
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
	_add_ring(color, size)
	_add_shape(size)
	_add_name(size.y)


## Zona para usar el objeto, algo mayor que él.
func _add_shape(size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size + Vector3(0.3, 0.4, 0.3)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	add_child(shape)


## Aro tenue en el suelo que gira despacio: ayuda a ver los objetos sueltos (sin parpadear).
func _add_ring(color: Color, size: Vector3) -> void:
	var ring := TorusMesh.new()
	var radius := maxf(size.x, size.z) * 0.5 + 0.18
	ring.inner_radius = radius
	ring.outer_radius = radius + 0.05
	ring.rings = 16
	ring.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.lightened(0.4), 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material = material
	_ring = MeshInstance3D.new()
	_ring.mesh = ring
	_ring.position.y = 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


## Nombre del objeto flotando encima, de cara a la cámara; solo se ve de cerca (y no a través
## de las paredes).
func _add_name(height: float) -> void:
	_name_label = Label3D.new()
	_name_label.text = get_prompt_detail()
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 40
	_name_label.outline_size = 12
	_name_label.pixel_size = 0.004
	_name_label.modulate = Color(1.0, 0.97, 0.85)
	_name_label.position.y = height + 0.3
	_name_label.visible = false
	add_child(_name_label)


func _process(delta: float) -> void:
	if _ring != null:
		_ring.rotation.y += delta * RING_SPIN
	if _name_label != null:
		var camera := get_viewport().get_camera_3d()
		_name_label.visible = (
			enabled
			and camera != null
			and camera.global_position.distance_to(global_position) <= NAME_DISTANCE
		)

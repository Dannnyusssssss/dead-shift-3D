class_name LootContainer
extends Interactable
## Arcón, caja registradora o casillero con objetos dentro (munición escondida, materiales).
## Al registrarlo se abre de verdad (la tapa se levanta, el cajón sale, la puerta gira), los
## objetos de dentro asoman con su modelo y suben un momento, y el HUD avisa de cada uno con
## su icono y su nombre. Lo que no quepa en el inventario se queda dentro.
## El contenido se define en la escena del nivel como "id:cantidad". El frente es -Z.

const KIND_DRAWER: int = 0
const KIND_REGISTER: int = 1
const KIND_LOCKER: int = 2
const SIZES: Array[Vector3] = [
	Vector3(0.6, 0.4, 0.5), Vector3(0.5, 0.25, 0.4), Vector3(0.5, 1.8, 0.5)
]
## Colores del cuerpo (arcón de madera, caja gris, casillero azul grisáceo) y del interior.
const COLORS: Array[Color] = [Color(0.45, 0.32, 0.2), Color(0.3, 0.3, 0.32), Color(0.35, 0.4, 0.45)]
const INSIDE_COLOR: Color = Color(0.06, 0.06, 0.07)
const METAL_COLOR: Color = Color(0.7, 0.72, 0.75)
## Lo que tarda en abrirse y cuánto se ven los objetos que salen.
const OPEN_SECONDS: float = 0.35
const REVEAL_RISE: float = 0.45
const REVEAL_SECONDS: float = 1.4
const MAX_REVEALED: int = 4

static var _material: StandardMaterial3D = null

@export var kind: int = KIND_DRAWER
## Contenido: lista de "id:cantidad" (por ejemplo "pistol_ammo:6").
@export var contents: PackedStringArray = PackedStringArray()
## Ya registrado en esta partida (lo recuerda el estado del mundo). Solo entonces aparece
## abierto; uno que sale vacío desde el principio (por el reparto o la dificultad) aparece
## cerrado y al abrirlo avisa de que no hay nada.
@export var searched: bool = false

## Giro (radianes) de lo que se ve: el frente mira hacia aquí (lo fija el piso: hacia el centro
## de la sala). No gira la colisión.
var facing: float = 0.0

var _remaining: Array[ItemStack] = []
## Parte que se mueve al abrir (tapa, cajón o puerta) y su nodo de giro o desplazamiento.
var _moving: Node3D = null
var _visual: Node3D = null
var _opened: bool = false


func _ready() -> void:
	super._ready()
	prompt_key = "prompt_search"
	for entry: String in contents:
		var stack := _parse_entry(entry)
		if stack != null:
			_remaining.append(stack)
	_build()
	DrawDistance.mark(self, DrawDistance.SMALL)
	if _remaining.is_empty() and searched:
		# Registrado en una visita anterior: aparece abierto y vacío.
		enabled = false
		_open_visual(false)


func is_empty() -> bool:
	return _remaining.is_empty()


## Si ya se abrió (para las pruebas y las capturas).
func is_open() -> bool:
	return _opened


## Lo que le queda dentro, como "id:cantidad" (para recordarlo al cambiar de piso).
func remaining_entries() -> PackedStringArray:
	var result := PackedStringArray()
	for stack: ItemStack in _remaining:
		result.append("%s:%d" % [stack.id(), stack.count])
	return result


func interact(player: Player) -> void:
	if not enabled:
		return
	if _remaining.is_empty():
		# Vacío desde el principio: se abre, avisa y queda registrado.
		enabled = false
		searched = true
		_open_visual(true)
		EventBus.user_message.emit("msg_container_empty")
		used.emit(player)
		return
	var state := GameState.player
	var kept: Array[ItemStack] = []
	var obtained: Array[ItemStack] = []
	for stack: ItemStack in _remaining:
		var before := stack.count
		if stack.item.category == ItemData.CATEGORY_KEY:
			state.keys.add(stack.id())
			EventBus.key_items_changed.emit()
			EventBus.user_message.emit("msg_key_item")
			EventBus.item_obtained.emit(stack.id(), before)
			obtained.append(stack)
			continue
		var fits := state.inventory.add_stack(stack)
		# add_stack deja en la casilla lo que no cupo: lo que falta es lo que entró.
		var taken := before - (0 if fits else stack.count)
		if taken > 0:
			EventBus.item_obtained.emit(stack.id(), taken)
			obtained.append(stack)
		if not fits:
			kept.append(stack)
	_remaining = kept
	_open_visual(true)
	_reveal(obtained)
	AudioDirector.play("pickup")
	if not _remaining.is_empty():
		EventBus.user_message.emit("msg_inventory_full")
	else:
		enabled = false
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
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var moving := SurfaceTool.new()
	moving.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Solo lo que se ve gira hacia el centro de la sala; la colisión queda como en los datos (un
	# contenedor no cuadrado girado cerraba pasos justos de la navegación).
	_visual = Node3D.new()
	_visual.rotation.y = facing
	add_child(_visual)
	_moving = Node3D.new()
	_moving.name = "Moving"
	_visual.add_child(_moving)
	match index:
		KIND_REGISTER:
			_build_register(body, moving, size)
		KIND_LOCKER:
			_build_locker(body, moving, size)
		_:
			_build_chest(body, moving, size)
	_visual.add_child(_mesh_from(body))
	_moving.add_child(_mesh_from(moving))
	_add_collision(size)


## Arcón: caja con refuerzos metálicos y tapa con bisagra atrás (se levanta al abrir).
func _build_chest(body: SurfaceTool, lid: SurfaceTool, size: Vector3) -> void:
	var color := COLORS[KIND_DRAWER]
	var lid_height := 0.06
	var box_height := size.y - lid_height
	_box(body, Vector3(0, box_height * 0.5, 0), Vector3(size.x, box_height, size.z), color)
	# Interior oscuro: asoma 4 mm sobre el borde de la caja (queda dentro de la tapa cerrada y se
	# ve al levantarla). Justo bajo el borde coincidía con la cara de arriba y parpadeaba.
	_box(
		body,
		Vector3(0, box_height + 0.001, 0),
		Vector3(size.x - 0.06, 0.006, size.z - 0.06),
		INSIDE_COLOR
	)
	for x: float in [-size.x * 0.5 + 0.03, size.x * 0.5 - 0.03]:
		_box(
			body,
			Vector3(x, box_height * 0.5, -size.z * 0.5 - 0.006),
			Vector3(0.05, box_height, 0.012),
			METAL_COLOR
		)
	# La tapa gira sobre el canto de atrás.
	_moving.position = Vector3(0, box_height, size.z * 0.5)
	_box(
		lid, Vector3(0, lid_height * 0.5, -size.z * 0.5), Vector3(size.x, lid_height, size.z), color
	)
	_box(
		lid, Vector3(0, lid_height * 0.5, -size.z - 0.012), Vector3(0.12, 0.04, 0.025), METAL_COLOR
	)


## Caja registradora: base, pantalla, teclado y un cajón del dinero que sale hacia delante.
func _build_register(body: SurfaceTool, drawer: SurfaceTool, size: Vector3) -> void:
	var color := COLORS[KIND_REGISTER]
	var drawer_height := 0.08
	_box(
		body,
		Vector3(0, drawer_height + (size.y - drawer_height) * 0.5, 0),
		Vector3(size.x, size.y - drawer_height, size.z),
		color
	)
	_box(body, Vector3(0, 0.004, 0), Vector3(size.x, 0.008, size.z), color.darkened(0.3))
	# Hueco oscuro del cajón (se ve cuando sale): 4 mm más alto y más bajo que el cajón para que
	# sus caras no coincidan.
	_box(
		body,
		Vector3(0, drawer_height * 0.5, 0.02),
		Vector3(size.x - 0.04, drawer_height - 0.004, size.z - 0.04),
		INSIDE_COLOR
	)
	_box(
		body,
		Vector3(0, size.y + 0.02, size.z * 0.15),
		Vector3(size.x * 0.8, 0.04, size.z * 0.5),
		color.darkened(0.25)
	)
	_box(
		body,
		Vector3(0, size.y + 0.13, size.z * 0.3),
		Vector3(size.x * 0.5, 0.16, 0.03),
		Color(0.1, 0.25, 0.2)
	)
	_box(
		drawer,
		Vector3(0, drawer_height * 0.5, 0),
		Vector3(size.x - 0.05, drawer_height - 0.012, size.z - 0.05),
		color.lightened(0.1)
	)
	_box(
		drawer,
		Vector3(0, drawer_height * 0.5, -size.z * 0.5 + 0.01),
		Vector3(0.1, 0.02, 0.02),
		METAL_COLOR
	)


## Casillero: armario alto con rejillas y una puerta con bisagra a la izquierda.
func _build_locker(body: SurfaceTool, door: SurfaceTool, size: Vector3) -> void:
	var color := COLORS[KIND_LOCKER]
	_box(body, Vector3(0, size.y * 0.5, 0.01), Vector3(size.x, size.y, size.z - 0.02), color)
	# Fondo oscuro del interior, 4 mm por delante de la cara del armario para no coincidir con ella
	# (se ve con la puerta abierta).
	_box(
		body,
		Vector3(0, size.y * 0.5, -size.z * 0.5 + 0.014),
		Vector3(size.x - 0.04, size.y - 0.04, 0.004),
		INSIDE_COLOR
	)
	var door_width := size.x - 0.01
	_moving.position = Vector3(-size.x * 0.5 + 0.005, 0, -size.z * 0.5 + 0.01)
	_box(
		door,
		Vector3(door_width * 0.5, size.y * 0.5, -0.012),
		Vector3(door_width, size.y - 0.02, 0.024),
		color.lightened(0.08)
	)
	for row: int in 4:
		_box(
			door,
			Vector3(door_width * 0.5, size.y - 0.18 - row * 0.05, -0.026),
			Vector3(door_width * 0.6, 0.015, 0.006),
			INSIDE_COLOR
		)
	_box(
		door,
		Vector3(door_width - 0.06, size.y * 0.52, -0.034),
		Vector3(0.025, 0.14, 0.02),
		METAL_COLOR
	)


func _box(tool: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var painted := ArrayMesh.new()
	painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	tool.append_from(painted, 0, Transform3D(Basis.IDENTITY, center))


func _mesh_from(tool: SurfaceTool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = _shared_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.8
	return _material


func _add_collision(size: Vector3) -> void:
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


## Abre la parte móvil (con animación o directamente si ya venía registrado).
func _open_visual(animated: bool) -> void:
	if _opened:
		return
	_opened = true
	var property := "rotation:x"
	var target: Variant = 1.9
	match clampi(kind, 0, SIZES.size() - 1):
		KIND_REGISTER:
			property = "position:z"
			target = _moving.position.z - 0.24
		KIND_LOCKER:
			property = "rotation:y"
			target = 1.75
	if not animated or not is_inside_tree():
		_moving.set_indexed(NodePath(property), target)
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_moving, property, target, OPEN_SECONDS)


## Los objetos que se sacaron asoman con su modelo y suben un momento antes de desaparecer.
## Con «Reducir movimiento» aparecen quietos y se desvanecen.
func _reveal(stacks: Array[ItemStack]) -> void:
	if stacks.is_empty() or not is_inside_tree():
		return
	var size := SIZES[clampi(kind, 0, SIZES.size() - 1)]
	var top := minf(size.y, 1.2) + 0.1
	var still := Settings.get_bool("reduce_motion")
	var count := mini(stacks.size(), MAX_REVEALED)
	for index: int in count:
		var stack := stacks[index]
		var model := ItemModels.instance(stack.id(), stack.durability.state(), true)
		if model == null:
			continue
		var spread := (float(index) - float(count - 1) * 0.5) * 0.22
		model.position = Vector3(spread, top, -size.z * 0.3)
		model.scale = Vector3.ONE * Pickup.scale_for(stack.item.category)
		_visual.add_child(model)
		var tween := model.create_tween()
		if not still:
			tween.tween_property(model, "position:y", top + REVEAL_RISE, REVEAL_SECONDS * 0.4)
			tween.parallel().tween_property(model, "rotation:y", PI, REVEAL_SECONDS * 0.4)
		tween.tween_interval(REVEAL_SECONDS * 0.4)
		tween.tween_property(model, "scale", Vector3.ONE * 0.01, REVEAL_SECONDS * 0.2)
		tween.tween_callback(model.queue_free)

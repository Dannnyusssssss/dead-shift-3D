class_name Gate
extends Interactable
## Reja que bloquea el paso hasta abrirla. Si pide una llave, solo se abre con ese objeto clave;
## si es un atajo, solo desde un lado. Al abrirse pone su marca en el estado del mundo, así sigue
## abierta en una partida continuada. Se arma desde un GateSpec del piso.

const BAR_COLOR: Color = Color(0.32, 0.33, 0.36)
const BAR_SPACING: float = 0.25
const OPEN_TIME: float = 0.8

var spec: GateSpec = null
var is_open: bool = false

var _solid: StaticBody3D = null
var _bars: Node3D = null


func _ready() -> void:
	super._ready()
	_build()
	if not spec.flag.is_empty() and GameState.world.has_flag(spec.flag):
		_set_open(false)


func get_prompt_key() -> String:
	if is_open or not enabled:
		return ""
	var viewer := get_tree().get_first_node_in_group("player") as Node3D
	if viewer != null and not _reachable_from(viewer.global_position):
		return "prompt_gate_other_side"
	if not spec.required_item.is_empty() and not GameState.player.keys.has(spec.required_item):
		return "prompt_gate_locked"
	return "prompt_open_gate"


func interact(player: Player) -> void:
	if is_open:
		return
	if not _reachable_from(player.global_position):
		EventBus.user_message.emit("msg_locked_other_side")
		return
	if not spec.required_item.is_empty() and not GameState.player.keys.has(spec.required_item):
		EventBus.user_message.emit("msg_need_key")
		return
	GameState.world.set_flag(spec.flag)
	NoiseSystem.emit_noise(global_position, Rules.NOISE_MEDIUM)
	EventBus.sound_cue.emit("cue_gate_open", global_position)
	_set_open(true)
	used.emit(player)


## Verdadero si la reja se puede abrir desde ese punto del mundo (atajos de un solo lado).
func _reachable_from(point: Vector3) -> bool:
	if spec.open_side == GateSpec.SIDE_BOTH:
		return true
	var local_z := to_local(point).z
	return local_z * float(spec.open_side) > 0.0


func _set_open(animated: bool) -> void:
	is_open = true
	enabled = false
	_solid.collision_layer = 0
	var raised := Vector3(0.0, spec.size.y - 0.15, 0.0)
	if animated:
		var tween := create_tween()
		tween.tween_property(_bars, "position", raised, OPEN_TIME)
	else:
		_bars.position = raised


func _build() -> void:
	var size := spec.size
	_bars = Node3D.new()
	add_child(_bars)
	var material := StandardMaterial3D.new()
	material.albedo_color = BAR_COLOR
	material.metallic = 0.6
	var count := maxi(int(size.x / BAR_SPACING), 2)
	for index: int in count + 1:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.05, size.y, 0.05)
		mesh.material = material
		bar.mesh = mesh
		bar.position = Vector3(
			-size.x * 0.5 + size.x * float(index) / float(count), size.y * 0.5, 0.0
		)
		_bars.add_child(bar)
	for height: float in [0.15, size.y - 0.15]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(size.x, 0.08, 0.08)
		rail_mesh.material = material
		rail.mesh = rail_mesh
		rail.position = Vector3(0.0, height, 0.0)
		_bars.add_child(rail)
	# Zona de interacción algo más gruesa que la reja, para apuntarla con facilidad.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, maxf(size.z, 0.15) + 0.6)
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	_solid = StaticBody3D.new()
	_solid.collision_layer = Rules.LAYER_DOOR
	_solid.collision_mask = 0
	var solid_shape := CollisionShape3D.new()
	var solid_box := BoxShape3D.new()
	solid_box.size = Vector3(size.x, size.y, maxf(size.z, 0.15))
	solid_shape.shape = solid_box
	solid_shape.position.y = size.y * 0.5
	_solid.add_child(solid_shape)
	add_child(_solid)

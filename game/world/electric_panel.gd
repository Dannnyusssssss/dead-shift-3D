class_name ElectricPanel
extends StaticBody3D
## Tablero eléctrico de pared. Mientras tiene corriente, el jefe que choca contra él queda
## aturdido mucho tiempo y el tablero se apaga para siempre. La corriente se indica con una
## luz fija y un rótulo (sin parpadeo); al apagarse, la luz se atenúa de forma suave.

signal shorted

var size: Vector3 = Vector3(1.2, 1.6, 0.3)
var live: bool = true

var _material: StandardMaterial3D = null
var _label: Label3D = null


func _ready() -> void:
	collision_layer = Rules.LAYER_WORLD
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5 + 0.4
	add_child(shape)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.25, 0.27, 0.3)
	_material.emission_enabled = true
	_material.emission = Color(0.9, 0.8, 0.2)
	_material.emission_energy_multiplier = 0.8
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = size.y * 0.5 + 0.4
	add_child(instance)
	_label = Label3D.new()
	_label.text = tr("prop_panel_live")
	_label.font_size = 40
	_label.outline_size = 8
	# Pegado a la parte de arriba de la cara del cuadro (antes flotaba por encima de la caja) y
	# solo por delante, para que no se lea en espejo desde detrás.
	_label.pixel_size = 0.0035
	_label.double_sided = false
	_label.position = Vector3(0.0, 0.4 + size.y - 0.2, size.z * 0.5 + 0.006)
	add_child(_label)


## Lo apaga tras el choque del jefe (solo una vez).
func short_out() -> void:
	if not live:
		return
	set_dead()
	NoiseSystem.emit_noise(global_position, Rules.NOISE_HIGH)
	EventBus.sound_cue.emit("cue_panel_short", global_position)
	shorted.emit()


## Queda sin corriente (también al volver a un piso donde ya se usó).
func set_dead() -> void:
	live = false
	_label.text = tr("prop_panel_dead")
	var tween := create_tween()
	tween.tween_property(_material, "emission_energy_multiplier", 0.0, 0.6)

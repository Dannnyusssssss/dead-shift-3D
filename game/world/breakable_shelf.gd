class_name BreakableShelf
extends StaticBody3D
## Estantería sólida que el jefe destroza al embestirla. Al romperse hace ruido, deja de
## bloquear y queda marcada en el estado del mundo.

signal broken

const COLOR: Color = Color(0.42, 0.36, 0.3)

var size: Vector3 = Vector3(3.0, 2.2, 0.8)
var is_broken: bool = false

var _visual: Node3D = null


func _ready() -> void:
	collision_layer = Rules.LAYER_WORLD
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	for level: int in 4:
		var board := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size.x, 0.06, size.z)
		mesh.material = material
		board.mesh = mesh
		board.position.y = 0.1 + float(level) * (size.y - 0.2) / 3.0
		_visual.add_child(board)
	for x: float in [-size.x * 0.5 + 0.04, size.x * 0.5 - 0.04]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.08, size.y, size.z)
		post_mesh.material = material
		post.mesh = post_mesh
		post.position = Vector3(x, size.y * 0.5, 0.0)
		_visual.add_child(post)


## Rompe la estantería (solo una vez).
func break_apart() -> void:
	if is_broken:
		return
	is_broken = true
	collision_layer = 0
	NoiseSystem.emit_noise(global_position, Rules.NOISE_HIGH)
	EventBus.sound_cue.emit("cue_shelf_break", global_position)
	EventBus.debris.emit(global_position + Vector3.UP * 1.0)
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", 1.3, 0.35)
	tween.parallel().tween_property(_visual, "position:y", -0.6, 0.35)
	broken.emit()


## Aparece ya rota (en una visita posterior al piso).
func set_broken_silently() -> void:
	is_broken = true
	collision_layer = 0
	_visual.rotation.z = 1.3
	_visual.position.y = -0.6

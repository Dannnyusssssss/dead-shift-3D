class_name ToxicCloud
extends Node3D
## Nube tóxica del jefe: aparece en un punto, avisa creciendo durante un momento y después
## daña al jugador mientras esté dentro, hasta disiparse. Obliga a moverse. No contagia.
## Se ve como una esfera verde semitransparente que cambia de forma suave (sin destellos).

var radius: float = 3.0
var warning: float = 1.0
var duration: float = 6.0
var dps: float = 6.0

var _time: float = 0.0
var _mesh: MeshInstance3D = null
var _material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("toxic_cloud")
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.45, 0.75, 0.25, 0.0)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 1.2
	sphere.material = _material
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.position.y = radius * 0.3
	_mesh.scale = Vector3.ONE * 0.2
	add_child(_mesh)
	EventBus.sound_cue.emit("cue_toxic_cloud", global_position)


## Verdadero si ya hace daño (pasó el aviso y no se disipó).
func is_active() -> bool:
	return _time >= warning and _time < warning + duration


## Verdadero si el punto está dentro de la nube (en el plano).
func contains(point: Vector3) -> bool:
	var flat := Vector2(point.x - global_position.x, point.z - global_position.z)
	return flat.length() <= radius


func _physics_process(delta: float) -> void:
	_time += delta
	var growth := clampf(_time / maxf(warning, 0.01), 0.0, 1.0)
	_mesh.scale = Vector3.ONE * lerpf(0.2, 1.0, growth)
	var fade := 1.0
	if _time > warning + duration - 1.0:
		fade = clampf(warning + duration - _time, 0.0, 1.0)
	_material.albedo_color.a = 0.35 * growth * fade
	if is_active():
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null and not player.is_dead() and contains(player.global_position):
			player.receive_toxic_damage(dps * delta)
	if _time >= warning + duration:
		queue_free()

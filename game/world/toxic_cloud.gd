class_name ToxicCloud
extends Node3D
## Nube tóxica del jefe, en fases que se ven y dan tiempo a apartarse (se entiende sin sonido):
##   1. Marca (lead_time): un círculo en el suelo con el borde bien visible donde va a caer,
##      mientras el jefe hace el gesto de lanzar.
##   2. Vuelo (flight_time): un bote verde brillante hace un arco desde la mano del jefe hasta la
##      marca, que sigue en el suelo.
##   3. Aviso (warning): la nube crece sobre la marca; todavía no hace daño.
##   4. Daño (duration): daña al jugador mientras esté dentro del círculo, hasta disiparse.
## El borde late despacio (menos de un latido por segundo) y con «Reducir destellos» queda fijo.
## No contagia.

## Latidos por segundo del borde de la marca (muy por debajo de 3) y altura del arco del bote.
const BORDER_PULSE_RATE: float = 0.8
const ARC_HEIGHT: float = 2.5
const BORDER_COLOR: Color = Color(0.85, 1.0, 0.3)
const CLOUD_COLOR: Color = Color(0.45, 0.75, 0.25)

var radius: float = 3.0
var warning: float = 1.0
var duration: float = 6.0
var dps: float = 6.0
## Segundos que solo se ve la marca (el gesto del jefe) y que tarda el bote en llegar.
var lead_time: float = 0.0
var flight_time: float = 0.0
## Punto (global) desde el que sale el bote.
var launch_origin: Vector3 = Vector3.ZERO

var _time: float = 0.0
var _mesh: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _border: MeshInstance3D = null
var _border_material: StandardMaterial3D = null
var _disc_material: StandardMaterial3D = null
var _canister: MeshInstance3D = null


func _ready() -> void:
	add_to_group("toxic_cloud")
	_build_marker()
	_build_canister()
	_material = _transparent(CLOUD_COLOR, 0.0)
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 1.2
	sphere.material = _material
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.position.y = radius * 0.3
	_mesh.scale = Vector3.ONE * 0.2
	_mesh.visible = false
	add_child(_mesh)
	EventBus.sound_cue.emit("cue_toxic_cloud", global_position)


## Segundos desde que el bote cayó (negativo mientras se marca o vuela).
func landed_time() -> float:
	return _time - lead_time - flight_time


## Verdadero si ya hace daño (pasó el aviso y no se disipó).
func is_active() -> bool:
	var since := landed_time()
	return since >= warning and since < warning + duration


## Verdadero si el bote ya está en el aire (para las pruebas).
func is_flying() -> bool:
	return _time >= lead_time and landed_time() < 0.0


## Verdadero si el punto está dentro de la nube (en el plano).
func contains(point: Vector3) -> bool:
	var flat := Vector2(point.x - global_position.x, point.z - global_position.z)
	return flat.length() <= radius


## Posición del bote en el arco (t de 0 a 1), en coordenadas globales.
func arc_point(t: float) -> Vector3:
	var target := global_position + Vector3.UP * 0.2
	var point := launch_origin.lerp(target, t)
	point.y += ARC_HEIGHT * 4.0 * t * (1.0 - t)
	return point


func _physics_process(delta: float) -> void:
	_time += delta
	var since := landed_time()
	_update_marker(since)
	if _canister != null:
		_canister.visible = is_flying()
		if _canister.visible and flight_time > 0.0:
			_canister.global_position = arc_point((_time - lead_time) / flight_time)
	_mesh.visible = since >= 0.0
	if since >= 0.0:
		var growth := clampf(since / maxf(warning, 0.01), 0.0, 1.0)
		_mesh.scale = Vector3.ONE * lerpf(0.2, 1.0, growth)
		_material.albedo_color.a = 0.35 * growth * _fade(since)
	if is_active():
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null and not player.is_dead() and contains(player.global_position):
			player.receive_toxic_damage(dps * delta)
	if since >= warning + duration:
		queue_free()


## Se desvanece durante su último segundo.
func _fade(since: float) -> float:
	if since > warning + duration - 1.0:
		return clampf(warning + duration - since, 0.0, 1.0)
	return 1.0


## Círculo en el suelo: disco tenue y borde claro que late despacio (fijo con «Reducir
## destellos»). Se ve desde que el jefe empieza el gesto hasta que la nube se disipa.
func _update_marker(since: float) -> void:
	var pulse := 1.0
	if not Settings.get_bool("reduce_flashes"):
		pulse = 0.75 + 0.25 * sin(_time * TAU * BORDER_PULSE_RATE)
	var fade := _fade(since) if since >= 0.0 else 1.0
	_border_material.albedo_color.a = 0.9 * pulse * fade
	_disc_material.albedo_color.a = 0.18 * fade


func _build_marker() -> void:
	_disc_material = _transparent(BORDER_COLOR, 0.18)
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = radius
	disc_mesh.bottom_radius = radius
	disc_mesh.height = 0.01
	disc_mesh.radial_segments = 32
	disc_mesh.material = _disc_material
	var disc := MeshInstance3D.new()
	disc.mesh = disc_mesh
	disc.position.y = 0.03
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	_border_material = _transparent(BORDER_COLOR, 0.9)
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.12
	ring.outer_radius = radius
	ring.rings = 48
	ring.ring_segments = 6
	ring.material = _border_material
	_border = MeshInstance3D.new()
	_border.mesh = ring
	_border.position.y = 0.05
	_border.scale = Vector3(1.0, 0.4, 1.0)
	_border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_border)


func _build_canister() -> void:
	if flight_time <= 0.0:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = BORDER_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body := CylinderMesh.new()
	body.top_radius = 0.14
	body.bottom_radius = 0.14
	body.height = 0.42
	body.material = material
	_canister = MeshInstance3D.new()
	_canister.mesh = body
	_canister.rotation.x = 0.6
	_canister.visible = false
	_canister.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_canister)


func _transparent(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

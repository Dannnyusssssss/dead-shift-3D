class_name PlayerThrow
extends Node3D
## Lanzar con puntería: la tecla de lanzar (o «Lanzar» en la mochila) deja el objeto en la mano
## y dibuja la trayectoria hasta donde caerá. Atacar o volver a pulsar lanzar lo lanza; apuntar
## (clic derecho) lo cancela. Va como hijo del nodo Player (lo crea el jugador).

## Puntos de la trayectoria dibujada y paso de tiempo entre ellos.
const ARC_POINTS: int = 26
const ARC_STEP: float = 0.06
const ARC_COLOR: Color = Color(1.0, 0.92, 0.55)

## Material de la bolsa listo para lanzar ("" = ninguno).
var ready_item: String = ""

var _player: Player = null
var _threw_frame: int = -1
var _dots: MultiMeshInstance3D = null
var _marker: MeshInstance3D = null
var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_player = get_parent() as Player
	_ray.collision_mask = Rules.LAYER_WORLD
	_build_arc()
	EventBus.player_died.connect(cancel)


## Verdadero mientras hay un objeto listo o se acaba de lanzar en este fotograma (el combate
## no debe disparar con la misma pulsación).
func is_aiming() -> bool:
	return not ready_item.is_empty() or _threw_frame == Engine.get_physics_frames()


## Deja listo para lanzar un material de la bolsa. Devuelve falso si no se puede lanzar.
func prepare(item_id: String) -> bool:
	if GameState.player == null or GameState.player.inventory.bag.count(item_id) <= 0:
		return false
	ready_item = item_id
	_player.arms.hold_for_throw(ready_item)
	_set_arc_visible(true)
	return true


func cancel() -> void:
	if ready_item.is_empty():
		return
	ready_item = ""
	# Si las manos pasan a otra cosa (curarse, combinar), esa acción ya puso lo suyo en ellas.
	if not _player.hands_busy:
		_player.arms.release_hands()
	_set_arc_visible(false)


func _physics_process(_delta: float) -> void:
	if ready_item.is_empty():
		if _can_act() and InputRouter.just_pressed("throw_next"):
			# Cambia lo que se lanza con la tecla rápida (lo muestra el HUD).
			GameState.player.cycle_quick_throw()
			EventBus.inventory_changed.emit()
		if _can_act() and InputRouter.just_pressed("throw") and not _player.combat.is_busy():
			var item_id := GameState.player.quick_throw_item()
			if item_id.is_empty():
				EventBus.user_message.emit("msg_nothing_to_throw")
			else:
				prepare(item_id)
		return
	if not _can_act() or GameState.player.inventory.bag.count(ready_item) <= 0:
		cancel()
		return
	if InputRouter.just_pressed("aim"):
		cancel()
		return
	if InputRouter.just_pressed("throw") or InputRouter.just_pressed("attack"):
		var item_id := ready_item
		cancel()
		if _player.throw_material(item_id):
			_threw_frame = Engine.get_physics_frames()
		return
	_update_arc()


func _can_act() -> bool:
	return _player.controls_enabled and not _player.hands_busy and not _player.is_dead()


## Simula el vuelo (misma física que el objeto lanzado) y coloca los puntos y la marca de caída.
func _update_arc() -> void:
	var position_now := _player.aim_origin() + _player.aim_direction() * 0.4
	var velocity := _player.aim_direction() * Rules.THROW_SPEED + Vector3.UP * Rules.THROW_LIFT
	var space := get_world_3d().direct_space_state
	var shown := 0
	var landed := false
	for index: int in ARC_POINTS:
		var next := position_now + velocity * ARC_STEP
		velocity.y -= ThrownItem.GRAVITY * ARC_STEP
		_ray.from = position_now
		_ray.to = next
		var hit := space.intersect_ray(_ray)
		if not hit.is_empty():
			var point: Vector3 = hit["position"]
			var normal: Vector3 = hit["normal"]
			_marker.global_position = point + normal * 0.02
			_marker.visible = true
			landed = true
			break
		_dots.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, next))
		shown = index + 1
		position_now = next
	_dots.multimesh.visible_instance_count = shown
	if not landed:
		_marker.visible = false


func _build_arc() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = ARC_COLOR
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 6
	dot.rings = 3
	dot.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = dot
	multimesh.instance_count = ARC_POINTS
	multimesh.visible_instance_count = 0
	_dots = MultiMeshInstance3D.new()
	_dots.multimesh = multimesh
	_dots.top_level = true
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dots)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.3
	ring.material = material
	_marker = MeshInstance3D.new()
	_marker.mesh = ring
	_marker.top_level = true
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_set_arc_visible(false)


func _set_arc_visible(shown: bool) -> void:
	_dots.visible = shown
	_marker.visible = shown
	if not shown:
		_dots.multimesh.visible_instance_count = 0

extends Node
@warning_ignore_start("unsafe_call_argument")
## Bot de recorrido: juega la planta baja con semilla fija, sin ventana, a través de las
## acciones del InputMap (moverse, mirar, disparar, recargar, golpear). Recoge el chaleco y la
## munición de la sala de seguridad, pasa por la ferretería y llega a la escalera.
## Demuestra que el piso es completable; no que sea divertido.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")
## Tiempo máximo de juego antes de darlo por fallido.
const TIME_LIMIT: float = 420.0
const ENGAGE_RANGE: float = 16.0
const MELEE_RANGE: float = 1.3
const INTERACT_RANGE: float = 1.6
const REPATH_TIME: float = 0.5
const CHEST_HEIGHT: float = 1.1
## Objetivos en orden: punto y si hay que usar lo que esté ahí.
const ROUTE: Array = [
	[Vector3(-6.0, 0.0, -2.0), true],
	[Vector3(-0.7, 0.0, -2.8), true],
	[Vector3(11.0, 0.0, -1.5), false],
	[Vector3(8.0, 0.0, -8.0), true],
	[Vector3(11.0, 0.0, -5.5), true],
	[Vector3(11.0, 0.0, -1.5), false],
	[Vector3(40.5, 0.0, 0.0), false],
]

var _game: Game = null
var _player: Player = null
var _route_index: int = 0
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _repath_timer: float = 0.0
var _fire_toggle: bool = false
var _stuck_timer: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _unstick_timer: float = 0.0
var _kills: int = 0
var _done: bool = false
## Acciones que el bot quiere pulsadas en este fotograma (se aplican al final, sin soltar y
## volver a pulsar en el mismo fotograma, que el motor no cuenta como pulsación nueva).
var _wanted: Dictionary = {}


func _ready() -> void:
	_game = GAME_SCRIPT.new()
	add_child(_game)
	_player = _game.level.player
	EventBus.goal_reached.connect(_on_goal)
	EventBus.player_died.connect(_on_died)
	EventBus.enemy_died.connect(func(_o: Vector3, _d: Array[ItemStack]) -> void: _kills += 1)
	print("[bot] inicio: piso %s" % _game.level.floor_data.id)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _game.elapsed > TIME_LIMIT:
		_finish(false, "tiempo agotado en el objetivo %d" % _route_index)
		return
	_wanted.clear()
	var enemy := _visible_enemy()
	if enemy != null:
		_fight(enemy)
	else:
		_follow_route(delta)
	_apply_actions()


func _fight(enemy: Enemy) -> void:
	var target := enemy.global_position + Vector3.UP * CHEST_HEIGHT
	_aim_at(target)
	var state := GameState.player
	var stack := state.equipped()
	var distance := _player.global_position.distance_to(enemy.global_position)
	if stack != null and stack.item.weapon.kind == WeaponData.KIND_RANGED:
		if stack.ammo_loaded > 0:
			_tap("attack")
			return
		if state.inventory.count_of(stack.item.weapon.ammo_item_id) > 0:
			_tap("reload")
			return
		if not _equip_melee():
			_retreat(enemy)
		return
	if stack == null:
		_retreat(enemy)
		return
	if distance > MELEE_RANGE:
		_hold("move_forward")
	else:
		_hold("attack")


func _follow_route(delta: float) -> void:
	if _route_index >= ROUTE.size():
		return
	var step: Array = ROUTE[_route_index]
	var goal: Vector3 = step[0]
	var use: bool = step[1]
	var flat_distance := Vector2(goal.x, goal.z).distance_to(
		Vector2(_player.global_position.x, _player.global_position.z)
	)
	if flat_distance < (INTERACT_RANGE if use else 1.0):
		if use:
			_use_nearby(goal)
		_route_index += 1
		_path = PackedVector3Array()
		return
	_repath_timer -= delta
	if _path.is_empty() or _repath_timer <= 0.0:
		_repath_timer = REPATH_TIME
		var map := _player.get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map, _player.global_position, goal, true)
		_path_index = 0
	while _path_index < _path.size() - 1:
		var point := _path[_path_index]
		if (
			Vector2(point.x, point.z).distance_to(
				Vector2(_player.global_position.x, _player.global_position.z)
			)
			> 0.5
		):
			break
		_path_index += 1
	var next := goal if _path.is_empty() else _path[_path_index]
	_aim_at(Vector3(next.x, _player.global_position.y + Rules.PLAYER_EYE_HEIGHT, next.z))
	_hold("move_forward")
	_check_stuck(delta)


func _check_stuck(delta: float) -> void:
	if _unstick_timer > 0.0:
		_unstick_timer -= delta
		_hold("move_right")
		return
	if _player.global_position.distance_to(_last_position) < 0.02:
		_stuck_timer += delta
		if _stuck_timer > 2.0:
			_stuck_timer = 0.0
			_unstick_timer = 0.5
			_path = PackedVector3Array()
	else:
		_stuck_timer = 0.0
	_last_position = _player.global_position


func _use_nearby(point: Vector3) -> void:
	var best: Interactable = null
	var best_distance := 2.0
	for node: Node in _game.level.get_children():
		var target := node as Interactable
		if target == null or not target.enabled:
			continue
		var distance := target.global_position.distance_to(point)
		if distance < best_distance:
			best = target
			best_distance = distance
	if best != null:
		print("[bot] usa %s" % best.get_prompt_key())
		best.interact(_player)


func _visible_enemy() -> Enemy:
	var best: Enemy = null
	var best_distance := ENGAGE_RANGE
	var space := _player.get_world_3d().direct_space_state
	var eye := _player.aim_origin()
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var target := enemy.global_position + Vector3.UP * CHEST_HEIGHT
		var distance := eye.distance_to(target)
		if distance > best_distance:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, target, Rules.LAYER_WORLD)
		if not space.intersect_ray(query).is_empty():
			continue
		best = enemy
		best_distance = distance
	return best


func _equip_melee() -> bool:
	var state := GameState.player
	for index: int in state.inventory.capacity():
		var stack := state.inventory.get_slot(index)
		if stack != null and stack.is_weapon():
			if stack.item.weapon.kind == WeaponData.KIND_MELEE and state.select_slot(index):
				EventBus.weapon_changed.emit()
				return true
	return false


func _retreat(enemy: Enemy) -> void:
	_aim_at(enemy.global_position + Vector3.UP * CHEST_HEIGHT)
	_hold("move_back")


## Gira la mirada hacia un punto a través de InputRouter (como lo haría el ratón).
func _aim_at(point: Vector3) -> void:
	var eye := _player.aim_origin()
	var direction := point - eye
	var flat := Vector2(direction.x, direction.z)
	if flat.length() < 0.01:
		return
	var desired_yaw := atan2(-direction.x, -direction.z)
	var desired_pitch := atan2(direction.y, flat.length())
	var yaw_delta := wrapf(_player.rotation.y - desired_yaw, -PI, PI)
	var pitch_delta := _player.head.rotation.x - desired_pitch
	if Settings.get_bool("invert_y"):
		pitch_delta = -pitch_delta
	InputRouter.add_look_radians(Vector2(yaw_delta, pitch_delta))


## Mantiene pulsada una acción este fotograma.
func _hold(action: String) -> void:
	_wanted[action] = true


## Pulsación corta: alterna pulsada y suelta en fotogramas seguidos.
func _tap(action: String) -> void:
	_fire_toggle = not _fire_toggle
	if _fire_toggle:
		_wanted[action] = true


func _apply_actions() -> void:
	for action: String in ["move_forward", "move_back", "move_right", "attack", "reload"]:
		if _wanted.has(action):
			if not Input.is_action_pressed(action):
				Input.action_press(action)
		elif Input.is_action_pressed(action):
			Input.action_release(action)


func _release_all() -> void:
	_wanted.clear()
	_apply_actions()


func _on_goal() -> void:
	_finish(true, "llegó a la escalera")


func _on_died() -> void:
	_finish(false, "murió en el objetivo %d" % _route_index)


func _finish(success: bool, reason: String) -> void:
	if _done:
		return
	_done = true
	_release_all()
	var state := GameState.player
	print(
		(
			"[bot] %s: %s | tiempo %.1f s | salud %d | enemigos muertos %d | armas rotas %d"
			% [
				"COMPLETADO" if success else "FALLO",
				reason,
				_game.elapsed,
				ceili(state.health),
				_kills,
				state.weapons_broken,
			]
		)
	)
	get_tree().quit(0 if success else 1)

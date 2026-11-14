extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Acechador en escena mínima con navegación: no ataca de frente si tiene ruta para rodear al
## jugador (golpea desde un flanco o la espalda) y se retira si el jugador lo mira de frente.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://game/actors/enemies/enemy.tscn")
const STALKER: EnemyData = preload("res://game/data/enemies/stalker.tres")
const ATTACK_CONE: float = 70.0

var _world: Node3D
var _player: Player
var _hit_angles: Array[float] = []
var _stalker: Enemy


func before_each() -> void:
	GameState.start_new_run()
	InputRouter.touch_mode = false
	_hit_angles.clear()
	_world = Node3D.new()
	add_child_autofree(_world)
	var region := NavigationRegion3D.new()
	_world.add_child(region)
	var ground := StaticBody3D.new()
	ground.collision_layer = Rules.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(shape)
	region.add_child(ground)
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Rules.LAYER_WORLD
	region.navigation_mesh = mesh
	region.bake_navigation_mesh(false)
	_player = PLAYER_SCENE.instantiate()
	_world.add_child(_player)
	EventBus.player_damaged.connect(_on_player_damaged)


func after_each() -> void:
	EventBus.player_damaged.disconnect(_on_player_damaged)


func _on_player_damaged(_amount: float) -> void:
	if _stalker == null:
		return
	var to_stalker := _stalker.global_position - _player.global_position
	to_stalker.y = 0.0
	var forward := _player.aim_direction()
	forward.y = 0.0
	_hit_angles.append(rad_to_deg(forward.angle_to(to_stalker)))


func _spawn(at: Vector3) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.data = STALKER
	enemy.position = at
	_world.add_child(enemy)
	return enemy


func test_stalker_flanks_instead_of_attacking_from_the_front() -> void:
	# El jugador no se mueve y mira hacia -Z; el acechador aparece delante.
	_stalker = _spawn(Vector3(0.0, 0.0, -9.0))
	for _step: int in 90:
		await wait_physics_frames(10)
		if not _hit_angles.is_empty():
			break
	assert_false(_hit_angles.is_empty(), "terminó atacando")
	if not _hit_angles.is_empty():
		assert_gte(
			_hit_angles[0], ATTACK_CONE - 5.0, "el primer golpe llega por el flanco o la espalda"
		)


func test_stalker_retreats_when_watched() -> void:
	_stalker = _spawn(Vector3(0.0, 0.0, -9.0))
	var behavior_retreated := false
	var closest := 100.0
	# El jugador gira para mirarlo siempre de frente durante 8 segundos.
	for _frame: int in 480:
		var to_stalker := _stalker.global_position - _player.global_position
		_player.rotation.y = atan2(-to_stalker.x, -to_stalker.z)
		await wait_physics_frames(1)
		closest = minf(closest, Vector2(to_stalker.x, to_stalker.z).length())
		if _stalker.state == Enemy.STATE_CHASE and _stalker.sees_player:
			var gap := Vector2(to_stalker.x, to_stalker.z).length()
			if gap > 2.0 and _hit_angles.is_empty() and closest < 9.0:
				behavior_retreated = behavior_retreated or gap > closest + 1.0
	assert_true(_hit_angles.is_empty(), "mirado de frente no ataca")
	assert_true(behavior_retreated, "se alejó al ser mirado")

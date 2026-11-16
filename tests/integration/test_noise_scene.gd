extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Ruido en escena mínima: un objeto lanzado atrae a un oyente y no a un caminante, el oyente
## investiga y vuelve a su sitio, agacharse no lo alerta, una pared amortigua el ruido y un
## objeto que no es frágil queda en el suelo para recogerlo.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://game/actors/enemies/enemy.tscn")
const WALKER: EnemyData = preload("res://game/data/enemies/walker.tres")
const LISTENER: EnemyData = preload("res://game/data/enemies/listener.tres")
const THROWN_SCRIPT: GDScript = preload("res://game/world/thrown_item.gd")
const SPAWNER_SCRIPT: GDScript = preload("res://game/world/loot_spawner.gd")

var _world: Node3D
var _player: Player


func before_each() -> void:
	GameState.start_new_run()
	InputRouter.touch_mode = false
	_world = Node3D.new()
	add_child_autofree(_world)
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(80.0, 1.0, 80.0))
	_world.add_child(SPAWNER_SCRIPT.new())
	_player = PLAYER_SCENE.instantiate()
	_world.add_child(_player)


func _add_box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Rules.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	_world.add_child(body)


func _spawn(data: EnemyData, at: Vector3) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.data = data
	enemy.position = at
	_world.add_child(enemy)
	return enemy


func _drop_bottle(at: Vector3) -> void:
	var thrown: ThrownItem = THROWN_SCRIPT.new()
	var bottle := ItemStack.new(GameState.items.get_item("bottle"))
	var exclude: Array[RID] = []
	thrown.setup(bottle, Vector3.DOWN, exclude)
	_world.add_child(thrown)
	thrown.global_position = at + Vector3.UP * 0.6


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_thrown_object_attracts_listener_not_walker() -> void:
	var listener := _spawn(LISTENER, Vector3(8.0, 0.0, 12.0))
	var walker := _spawn(WALKER, Vector3(-8.0, 0.0, 14.0))
	await wait_physics_frames(5)
	var walker_start := walker.global_position
	watch_signals(EventBus)
	var landing := Vector3(0.0, 0.0, 12.0)
	_drop_bottle(landing)
	await wait_physics_frames(30)
	assert_signal_emitted(EventBus, "noise_emitted", "la botella hizo ruido al romperse")
	assert_eq(listener.state, Enemy.STATE_INVESTIGATE, "el oyente reacciona")
	assert_eq(walker.state, Enemy.STATE_IDLE, "el caminante no oye")
	for _step: int in 60:
		await wait_physics_frames(10)
		if _flat_distance(listener.global_position, landing) <= Enemy.ARRIVE_DISTANCE + 0.1:
			break
	assert_lt(_flat_distance(listener.global_position, landing), Enemy.ARRIVE_DISTANCE + 0.2)
	assert_lt(_flat_distance(walker.global_position, walker_start), 0.3, "no se movió")


func test_listener_returns_home_after_investigating() -> void:
	var home := Vector3(6.0, 0.0, 12.0)
	var listener := _spawn(LISTENER, home)
	await wait_physics_frames(5)
	NoiseSystem.emit_noise(Vector3(0.0, 0.0, 12.0), Rules.NOISE_HIGH)
	await wait_physics_frames(5)
	assert_eq(listener.state, Enemy.STATE_INVESTIGATE)
	for _step: int in 120:
		await wait_physics_frames(10)
		if listener.state == Enemy.STATE_IDLE:
			break
	assert_eq(listener.state, Enemy.STATE_IDLE, "terminó de investigar")
	assert_lt(_flat_distance(listener.global_position, home), Enemy.ARRIVE_DISTANCE + 0.2)


func test_crouching_is_silent_but_walking_is_heard() -> void:
	var listener := _spawn(LISTENER, Vector3(0.0, 0.0, 9.0))
	await wait_physics_frames(5)
	var step_spot := Vector3(0.0, 0.0, 6.0)
	NoiseSystem.emit_noise(step_spot, Rules.NOISE_CROUCH, true)
	await wait_physics_frames(3)
	assert_eq(listener.state, Enemy.STATE_IDLE, "agachado no se oye")
	NoiseSystem.emit_noise(step_spot, Rules.NOISE_WALK, true)
	await wait_physics_frames(3)
	assert_eq(listener.state, Enemy.STATE_INVESTIGATE, "caminando cerca sí")


func test_wall_muffles_the_noise() -> void:
	var listener := _spawn(LISTENER, Vector3(0.0, 0.0, 18.0))
	_add_box(Vector3(0.0, 1.5, 14.0), Vector3(20.0, 3.0, 0.4))
	await wait_physics_frames(5)
	# Nivel medio a 10 m: el oyente lo oiría (radio 13), pero la pared lo reduce a la mitad.
	NoiseSystem.emit_noise(Vector3(0.0, 0.0, 8.0), Rules.NOISE_MEDIUM)
	await wait_physics_frames(3)
	assert_eq(listener.state, Enemy.STATE_IDLE, "la pared amortigua")
	NoiseSystem.emit_noise(Vector3(0.0, 0.0, 8.0), Rules.NOISE_VERY_HIGH)
	await wait_physics_frames(3)
	assert_eq(listener.state, Enemy.STATE_INVESTIGATE, "un disparo sí atraviesa")


func test_thrown_sturdy_object_lands_as_pickup() -> void:
	GameState.player.inventory.add_item(GameState.items.get_item("rag"), 2)
	await wait_physics_frames(2)
	assert_true(_player.throw_material("rag"))
	assert_eq(GameState.player.inventory.count_of("rag"), 1, "gasta una unidad")
	for _step: int in 30:
		await wait_physics_frames(5)
		if not get_tree().get_nodes_in_group("pickup").is_empty():
			break
	var pickups := get_tree().get_nodes_in_group("pickup")
	assert_eq(pickups.size(), 1, "quedó en el suelo")
	if pickups.size() == 1:
		var pickup: Pickup = pickups[0]
		assert_eq(pickup.item_id, "rag")
		assert_gt(_flat_distance(pickup.global_position, _player.global_position), 2.0)


## La botella ruidosa llama a todos los enemigos cercanos de su piso, también a un caminante
## (que no oye el resto de ruidos); los que están lejos o en otro piso no se mueven.
func test_noise_bottle_pulls_every_nearby_enemy() -> void:
	_player.position = Vector3(30.0, 0.0, 30.0)
	var near := _spawn(WALKER, Vector3(8.0, 0.0, 0.0))
	var far := _spawn(WALKER, Vector3(-30.0, 0.0, 0.0))
	var lure := Lure.new()
	lure.time_left = 3.0
	_world.add_child(lure)
	await wait_physics_frames(3)
	assert_eq(near.state, Enemy.STATE_INVESTIGATE, "el cercano va hacia el señuelo")
	assert_ne(far.state, Enemy.STATE_INVESTIGATE, "el lejano no")
	var start := near.global_position.distance_to(lure.global_position)
	await wait_seconds(1.5)
	assert_lt(near.global_position.distance_to(lure.global_position), start - 0.5, "se acerca")
	EventBus.lure_pulled.emit(Vector3(8.0, 5.0, 0.0), 14.0)
	assert_eq(far.state, Enemy.STATE_IDLE, "un señuelo de otro piso no lo mueve")

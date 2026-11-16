extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Jugador en escena mínima, movido solo por acciones del InputMap (como lo harían el
## teclado o los controles táctiles): avanzar, correr, agacharse, mirar e interactuar.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")

var _world: Node3D
var _player: Player


class CountingInteractable:
	extends Interactable
	var uses: int = 0

	func interact(_player: Player) -> void:
		uses += 1


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(shape)
	_world.add_child(ground)
	_player = PLAYER_SCENE.instantiate()
	_world.add_child(_player)
	InputRouter.touch_mode = false


func after_each() -> void:
	for action: String in ["move_forward", "move_right", "sprint", "crouch", "interact"]:
		Input.action_release(action)


func _walk(action: String, frames: int) -> Vector3:
	await wait_physics_frames(5)
	var start := _player.global_position
	Input.action_press(action)
	await wait_physics_frames(frames)
	Input.action_release(action)
	return _player.global_position - start


func test_moves_forward_with_action() -> void:
	var moved: Vector3 = await _walk("move_forward", 30)
	assert_lt(moved.z, -0.5, "adelante es -Z")
	assert_almost_eq(moved.x, 0.0, 0.05)


func test_strafes_right() -> void:
	var moved: Vector3 = await _walk("move_right", 30)
	assert_gt(moved.x, 0.5)


func test_sprint_is_faster_than_walk() -> void:
	var walked: Vector3 = await _walk("move_forward", 30)
	Input.action_press("sprint")
	var sprinted: Vector3 = await _walk("move_forward", 30)
	assert_gt(sprinted.length(), walked.length() * 1.3)
	Input.action_release("sprint")
	await wait_physics_frames(3)
	assert_eq(_player.movement_noise(), -1, "quieto no hace ruido")


func test_crouch_is_slower_and_quiet() -> void:
	var walked: Vector3 = await _walk("move_forward", 30)
	Input.action_press("crouch")
	await wait_physics_frames(2)
	Input.action_release("crouch")
	assert_true(_player.crouching)
	Input.action_press("move_forward")
	await wait_physics_frames(20)
	assert_eq(_player.movement_noise(), Rules.NOISE_CROUCH)
	Input.action_release("move_forward")
	var crouched: Vector3 = await _walk("move_forward", 30)
	assert_lt(crouched.length(), walked.length() * 0.7)
	assert_lt(_player.head.position.y, Rules.PLAYER_EYE_HEIGHT - 0.2)


func test_touch_look_turns_player() -> void:
	await wait_physics_frames(2)
	var yaw := _player.rotation.y
	InputRouter.add_touch_look(Vector2(100.0, 0.0))
	await wait_physics_frames(2)
	assert_ne(_player.rotation.y, yaw)
	InputRouter.touch_mode = false


func test_disabled_controls_block_movement() -> void:
	_player.controls_enabled = false
	var moved: Vector3 = await _walk("move_forward", 20)
	assert_almost_eq(moved.length(), 0.0, 0.01)


func test_interacts_with_target_in_front() -> void:
	var target := CountingInteractable.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 0.2)
	shape.shape = box
	target.add_child(shape)
	target.position = Vector3(0.0, Rules.PLAYER_EYE_HEIGHT, -1.5)
	_world.add_child(target)
	await wait_physics_frames(5)
	Input.action_press("interact")
	await wait_physics_frames(2)
	Input.action_release("interact")
	assert_eq(target.uses, 1)


## Al morir la cámara cae y se ladea; con «Reducir movimiento» no se mueve (solo fundido).
func test_death_fall_moves_camera_unless_reduced_motion() -> void:
	Settings.set_value("reduce_motion", true)
	assert_eq(_player.play_death_fall(), 0.0, "sin caída con «Reducir movimiento»")
	Settings.set_value("reduce_motion", false)
	var start_y := _player.camera.position.y
	var seconds := _player.play_death_fall()
	assert_gt(seconds, 0.0)
	await wait_seconds(seconds + 0.2)
	assert_lt(_player.camera.position.y, start_y - 1.0, "la cámara bajó casi al suelo")
	assert_gt(absf(_player.camera.rotation.z), 0.8, "la cámara se ladeó")

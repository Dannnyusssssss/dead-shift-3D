extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Cristales de escaparate en escena mínima: un disparo, un golpe o un objeto lanzado los rompe,
## hace ruido, deja trozos y el hueco abierto, y siguen rotos al reconstruir la sala desde el
## estado guardado.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")
const PANE_SIZE: Vector3 = Vector3(2.0, 1.7, 0.04)

var _world: Node3D
var _player: Player


func before_each() -> void:
	GameState.start_new_run()
	InputRouter.touch_mode = false
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


func after_each() -> void:
	Input.action_release("attack")


## Un panel delante del jugador (que mira hacia -z) a la distancia dada.
func _panes(distance: float) -> GlassPanes:
	var panes := GlassPanes.new()
	panes.floor_id = "test_floor"
	panes.room_id = "shop"
	panes.add_pane(Vector3(0.0, 1.75, -distance), PANE_SIZE)
	_world.add_child(panes)
	panes.build()
	return panes


func _bodies(panes: GlassPanes) -> int:
	return panes.find_children("*", "GlassPane", false, false).size()


func _press_attack() -> void:
	Input.action_press("attack")
	await wait_physics_frames(2)
	Input.action_release("attack")


func test_a_shot_breaks_the_pane_with_noise() -> void:
	var panes := _panes(4.0)
	await wait_physics_frames(5)
	watch_signals(panes)
	watch_signals(EventBus)
	await _press_attack()
	await wait_physics_frames(3)
	assert_true(panes.is_broken(0), "la bala rompe el cristal")
	assert_signal_emitted(panes, "pane_broken")
	assert_signal_emitted_with_parameters(
		EventBus, "sound_cue", ["cue_glass_break", panes.to_global(Vector3(0.0, 1.75, -4.0))]
	)
	assert_true(GameState.world.is_taken("test_floor", GlassShards.key("shop", 0)))
	assert_eq(_bodies(panes), 0, "el hueco queda abierto")


func test_a_melee_hit_breaks_the_pane() -> void:
	var pipe := ItemStack.new(GameState.items.get_item("pipe"))
	GameState.player.inventory.add_stack(pipe)
	GameState.player.select_slot(GameState.player.inventory.find_slot("pipe"))
	var panes := _panes(1.2)
	await wait_physics_frames(5)
	await _press_attack()
	await wait_physics_frames(40)
	assert_true(panes.is_broken(0), "el golpe rompe el cristal")
	assert_eq(NoiseSystem.last_level, Rules.NOISE_GLASS_BREAK, "y hace ruido")


func test_a_thrown_object_breaks_the_pane() -> void:
	var panes := _panes(5.0)
	await wait_physics_frames(3)
	var thrown := ThrownItem.new()
	var rag := ItemStack.new(GameState.items.get_item("rag"))
	thrown.setup(rag, Vector3(0.0, 0.0, -12.0), [_player.get_rid()])
	_world.add_child(thrown)
	thrown.global_position = Vector3(0.0, 1.75, -1.0)
	await wait_physics_frames(30)
	assert_true(panes.is_broken(0), "el trapo lanzado rompe el cristal")


func test_broken_pane_stays_broken_after_saving() -> void:
	var panes := _panes(3.0)
	assert_true(panes.break_pane(0))
	assert_false(panes.break_pane(0), "no se rompe dos veces")
	var restored := WorldState.new()
	restored.load_data(JSON.parse_string(JSON.stringify(GameState.world.to_data())))
	GameState.world = restored
	var again := _panes(3.0)
	assert_true(again.is_broken(0), "sigue roto al reconstruir la sala")
	assert_eq(_bodies(again), 0)
	var meshes := again.find_children("*", "MeshInstance3D", false, false)
	var with_mesh := 0
	for node: Node in meshes:
		if (node as MeshInstance3D).mesh != null:
			with_mesh += 1
	assert_eq(with_mesh, 1, "solo la malla de los trozos")

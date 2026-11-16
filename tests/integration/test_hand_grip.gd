extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Manos y agarre: cada arma se sostiene con su puño (alrededor del mango o de la empuñadura) y
## ningún dedo invade el mango; la mano derecha se abre sin arma; el chaleco del policía tiene
## forma de chaleco.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")
const ARMS: String = "res://assets/generated/arms/"
## Radio libre que tiene que dejar el puño alrededor del eje del mango (los mangos miden 1,6 a
## 2 cm de radio; se admite rozar).
const CLEAR_RADIUS: float = 0.013


func _vertices(path: String) -> PackedVector3Array:
	var node := ItemModels.instance_from_path(path)
	assert_not_null(node, path)
	if node == null:
		return PackedVector3Array()
	var arrays := node.mesh.surface_get_arrays(0)
	node.free()
	return arrays[Mesh.ARRAY_VERTEX]


## El puño de cuerpo a cuerpo deja libre el eje del mango (a lo largo de -Z, debajo de la
## muñeca) en toda la longitud del puño.
func test_melee_fist_leaves_the_handle_free() -> void:
	var axis_y := PlayerArms.GRIP_POINT.y
	for side: String in ["right", "left"]:
		var inside := 0
		for vertex: Vector3 in _vertices(ARMS + "hand_grip_%s.glb" % side):
			if vertex.z > -0.11 and vertex.z < -0.015:
				if Vector2(vertex.x, vertex.y - axis_y).length() < CLEAR_RADIUS:
					inside += 1
		assert_eq(inside, 0, "dedos dentro del mango: " + side)


## El puño de arma de fuego deja libre la empuñadura vertical de la pistola.
func test_pistol_fist_leaves_the_grip_free() -> void:
	var axis := PlayerArms.GRIP_POINT + Vector3(0.0, -0.045, 0.01)
	for side: String in ["right", "left"]:
		var inside := 0
		for vertex: Vector3 in _vertices(ARMS + "hand_pistol_%s.glb" % side):
			if vertex.y > axis.y - 0.05 and vertex.y < axis.y + 0.03:
				if Vector2(vertex.x - axis.x, vertex.z - axis.z).length() < CLEAR_RADIUS:
					inside += 1
		assert_eq(inside, 0, "dedos dentro de la empuñadura: " + side)


func test_right_hand_shape_follows_what_it_holds() -> void:
	GameState.start_new_run()
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	await wait_physics_frames(2)
	var arms: PlayerArms = null
	for node: Node in player.find_children("*", "Node3D", true, false):
		if node is PlayerArms:
			arms = node
	arms.show_weapon(null)
	assert_eq(arms.hand_shape("right"), "open", "sin arma, mano abierta")
	arms.show_weapon(ItemStack.new(GameState.items.get_item("pistol")))
	assert_eq(arms.hand_shape("right"), "pistol")
	arms.show_weapon(ItemStack.new(GameState.items.get_item("bat")))
	assert_eq(arms.hand_shape("right"), "grip")
	assert_eq(arms.hand_shape("left"), "open")
	arms.show_weapon(ItemStack.new(GameState.items.get_item("extinguisher")))
	var holder: Node3D = arms.call("_holder", "right")
	var model: Node3D = null
	for child: Node in holder.get_children():
		if child is MeshInstance3D and not child.is_queued_for_deletion():
			model = child
	assert_not_null(model)
	assert_eq(model.position, PlayerArms.GRIP_OFFSETS["extinguisher"], "se coge por la maneta")


func test_police_vest_is_shaped() -> void:
	assert_true(ResourceLoader.exists(ItemModels.FOLDER + "vest_worn.glb"))
	var police := GameState.items.get_item("vest")
	assert_not_null(police)
	var worn := _vertices(ItemModels.FOLDER + "vest_worn.glb")
	var flat := _vertices(ItemModels.FOLDER + "vest.glb")
	# Con forma: muchas más piezas que la caja de antes (24 vértices por caja).
	assert_gt(worn.size(), 24 * 10)
	assert_gt(flat.size(), 24 * 8)

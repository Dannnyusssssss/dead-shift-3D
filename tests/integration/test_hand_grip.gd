extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Manos y agarre: cada arma se sostiene con su puño (alrededor del mango o de la empuñadura) y
## ningún dedo invade el mango; la mano derecha se abre sin arma; la izquierda no se queda
## abierta delante; el chaleco del policía tiene forma de chaleco.

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


## Vértices a menos de CLEAR_RADIUS del eje (punto y dirección) en el tramo dado del eje.
func _inside(
	vertices: PackedVector3Array, point: Vector3, axis: Vector3, from: float, to: float
) -> int:
	var count := 0
	var direction := axis.normalized()
	for vertex: Vector3 in vertices:
		var along := (vertex - point).dot(direction)
		if along < from or along > to:
			continue
		if (vertex - point - direction * along).length() < CLEAR_RADIUS:
			count += 1
	return count


## El puño de cuerpo a cuerpo deja libre el eje del mango (el -Z de su colocación) en todo el
## ancho del puño.
func test_melee_fist_leaves_the_handle_free() -> void:
	var frame: Transform3D = PlayerArms.HOLD_FRAMES["melee"]
	for side: String in ["right", "left"]:
		var point := frame.origin
		var axis := -frame.basis.z
		if side == "left":
			point.x = -point.x
			axis.x = -axis.x
		var vertices := _vertices(ARMS + "hand_grip_%s.glb" % side)
		assert_gt(vertices.size(), 300, "mano modelada: " + side)
		assert_eq(_inside(vertices, point, axis, -0.06, 0.06), 0, "dedos dentro del mango: " + side)


## El puño de arma de fuego deja libre la empuñadura de la pistola (inclinada 14 grados).
func test_pistol_fist_leaves_the_grip_free() -> void:
	var frame: Transform3D = PlayerArms.HOLD_FRAMES["pistol"]
	var point := frame * Vector3(0.0, -0.045, 0.01)
	var axis := frame.basis * Vector3(0.0, cos(deg_to_rad(14.0)), sin(deg_to_rad(14.0)))
	for side: String in ["right", "left"]:
		var side_point := point
		var side_axis := axis
		if side == "left":
			side_point.x = -side_point.x
			side_axis.x = -side_axis.x
		var vertices := _vertices(ARMS + "hand_pistol_%s.glb" % side)
		assert_eq(
			_inside(vertices, side_point, side_axis, -0.05, 0.03),
			0,
			"dedos dentro de la empuñadura: " + side
		)


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
	assert_eq(arms.hand_shape("left"), "grip", "la izquierda nunca queda abierta")
	assert_eq(arms.left_shown(), 0.0, "en reposo la izquierda está fuera de la vista")
	arms.show_weapon(ItemStack.new(GameState.items.get_item("extinguisher")))
	var holder: Node3D = arms.call("_holder", "right")
	var model: Node3D = null
	for child: Node in holder.get_children():
		if child is MeshInstance3D and not child.is_queued_for_deletion():
			model = child
	assert_not_null(model)
	var offset: Vector3 = PlayerArms.GRIP_OFFSETS["extinguisher"]
	var frame: Transform3D = PlayerArms.HOLD_FRAMES["melee"]
	var expected := frame * Transform3D(Basis(), offset)
	assert_true(model.transform.is_equal_approx(expected), "se coge por la maneta")


func test_police_vest_is_shaped() -> void:
	assert_true(ResourceLoader.exists(ItemModels.FOLDER + "vest_worn.glb"))
	var police := GameState.items.get_item("vest")
	assert_not_null(police)
	var worn := _vertices(ItemModels.FOLDER + "vest_worn.glb")
	var flat := _vertices(ItemModels.FOLDER + "vest.glb")
	# Con forma: muchas más piezas que la caja de antes (24 vértices por caja).
	assert_gt(worn.size(), 24 * 10)
	assert_gt(flat.size(), 24 * 8)

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Constructor del kit: las caras coincidentes (mismo plano, mismo sentido y solapadas) se
## separan para que no parpadeen al mover la cámara. La pieza pequeña se retrasa, una fila de
## piezas iguales encadenadas queda escalonada y las colisiones no cambian.

const RECESS := Kit.Builder.COPLANAR_RECESS


func _box(builder: Kit.Builder, index: int) -> Array:
	var boxes: Array[Array] = builder.get("_boxes")
	return boxes[index]


func test_small_piece_flush_with_big_one_is_recessed() -> void:
	var builder := Kit.Builder.new()
	var mat := Kit.gray(0.5)
	# Pasamanos largo y poste metido en él, con la cara de delante (z = 0) en el mismo plano.
	builder.add_box(Vector3(0.0, 1.0, -0.035), Vector3(2.0, 0.07, 0.07), mat)
	builder.add_box(Vector3(0.0, 0.5, -0.03), Vector3(0.06, 1.1, 0.06), mat)
	builder.resolve_coplanar()
	var rail: Array = _box(builder, 0)
	var post: Array = _box(builder, 1)
	var rail_front: float = (rail[0] as Transform3D).origin.z + (rail[1] as Vector3).z * 0.5
	var post_front: float = (post[0] as Transform3D).origin.z + (post[1] as Vector3).z * 0.5
	assert_almost_eq(rail_front, 0.0, 0.0001, "la pieza grande no se mueve")
	assert_almost_eq(post_front, -RECESS, 0.0001, "la pequeña se retrasa")


func test_chain_of_equal_pieces_is_staggered() -> void:
	var builder := Kit.Builder.new()
	var mat := Kit.gray(0.5)
	# Tres lamas iguales que se solapan en fila, con la cara de arriba en el mismo plano.
	for index: int in 3:
		builder.add_box(Vector3(0.3 * index, 0.0, 0.0), Vector3(0.5, 0.2, 0.5), mat)
	builder.resolve_coplanar()
	var tops: Array[float] = []
	for index: int in 3:
		var box: Array = _box(builder, index)
		tops.append((box[0] as Transform3D).origin.y + (box[1] as Vector3).y * 0.5)
	assert_almost_eq(tops[0], 0.1, 0.0001)
	assert_almost_eq(tops[1], 0.1 - RECESS, 0.0001)
	assert_almost_eq(tops[2], 0.1 - 2.0 * RECESS, 0.0001, "cada una un paso más")


func test_faces_that_only_touch_or_face_away_are_left_alone() -> void:
	var builder := Kit.Builder.new()
	var mat := Kit.gray(0.5)
	# Dos tramos de pared seguidos (se tocan por el canto) y una placa pegada por detrás.
	builder.add_box(Vector3(0.0, 1.0, 0.0), Vector3(2.0, 2.0, 0.2), mat)
	builder.add_box(Vector3(2.0, 1.0, 0.0), Vector3(2.0, 2.0, 0.2), mat)
	builder.add_box(Vector3(0.0, 1.0, 0.15), Vector3(0.5, 0.5, 0.1), mat)
	builder.resolve_coplanar()
	assert_eq(_box(builder, 0)[1], Vector3(2.0, 2.0, 0.2))
	assert_eq(_box(builder, 1)[1], Vector3(2.0, 2.0, 0.2))
	assert_eq(_box(builder, 2)[1], Vector3(0.5, 0.5, 0.1))


func test_collisions_keep_the_original_size() -> void:
	var builder := Kit.Builder.new()
	var mat := Kit.gray(0.5)
	builder.add_box(Vector3(0.0, 1.0, -0.035), Vector3(2.0, 0.07, 0.07), mat)
	builder.add_box(Vector3(0.0, 0.5, -0.03), Vector3(0.06, 1.1, 0.06), mat)
	var body := builder.build("Test")
	add_child_autofree(body)
	var sizes: Array[Vector3] = []
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			sizes.append(((child as CollisionShape3D).shape as BoxShape3D).size)
	assert_true(sizes.has(Vector3(0.06, 1.1, 0.06)), "el poste choca con su tamaño real")

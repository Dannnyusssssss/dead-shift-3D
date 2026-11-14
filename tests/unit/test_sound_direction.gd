extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Dirección de los subtítulos respecto a quien escucha (mira hacia -Z).


func test_four_directions() -> void:
	var at_origin := Transform3D.IDENTITY
	assert_eq(SoundDirection.key_for(at_origin, Vector3(0, 0, -5)), SoundDirection.FRONT)
	assert_eq(SoundDirection.key_for(at_origin, Vector3(0, 0, 5)), SoundDirection.BACK)
	assert_eq(SoundDirection.key_for(at_origin, Vector3(-5, 0, 0)), SoundDirection.LEFT)
	assert_eq(SoundDirection.key_for(at_origin, Vector3(5, 0, 0)), SoundDirection.RIGHT)


func test_rotation_of_listener_is_used() -> void:
	# Girado 90 grados a la izquierda: lo que está en -X queda delante.
	var turned := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	assert_eq(SoundDirection.key_for(turned, Vector3(-5, 0, 0)), SoundDirection.FRONT)
	assert_eq(SoundDirection.key_for(turned, Vector3(0, 0, -5)), SoundDirection.RIGHT)


func test_height_does_not_matter_and_same_point_is_front() -> void:
	assert_eq(SoundDirection.key_for_local(Vector3(0, 10, 0)), SoundDirection.FRONT)
	assert_eq(SoundDirection.key_for_local(Vector3(0, -3, -2)), SoundDirection.FRONT)

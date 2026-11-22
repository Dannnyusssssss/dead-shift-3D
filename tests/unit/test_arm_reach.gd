extends GutTest
## Alcance de dos huesos: la muñeca llega al punto pedido, el codo sale hacia el lado indicado y
## un punto fuera de alcance estira el brazo hacia él sin romperse.

const UPPER: float = 0.28
const FORE: float = 0.26
const SHOULDER: Vector3 = Vector3(0.2, -0.24, 0.12)


func test_wrist_reaches_points_within_range() -> void:
	var targets: Array[Vector3] = [
		Vector3(0.1, -0.2, -0.3),
		Vector3(0.0, -0.15, -0.36),
		Vector3(0.25, -0.35, -0.2),
		Vector3(-0.05, -0.1, -0.25),
	]
	for target: Vector3 in targets:
		var reach := ArmReach.solve(SHOULDER, target, Vector3(0.6, -1.0, 0.4), UPPER, FORE)
		var wrist := ArmReach.wrist_of(
			SHOULDER, reach["shoulder"] as Vector3, reach["elbow"] as float, UPPER, FORE
		)
		assert_lt(wrist.distance_to(target), 0.01, "llega a %s" % target)
		assert_between(reach["elbow"] as float, 0.0, PI, "el codo dobla hacia su lado")


func test_elbow_points_towards_the_pole() -> void:
	var target := Vector3(0.05, -0.2, -0.3)
	var down := ArmReach.solve(SHOULDER, target, Vector3.DOWN, UPPER, FORE)
	var up := ArmReach.solve(SHOULDER, target, Vector3.UP, UPPER, FORE)
	assert_lt((down["elbow_point"] as Vector3).y, (up["elbow_point"] as Vector3).y)


func test_out_of_range_stretches_towards_the_point() -> void:
	var target := SHOULDER + Vector3(0.0, 0.0, -2.0)
	var reach := ArmReach.solve(SHOULDER, target, Vector3.DOWN, UPPER, FORE)
	var wrist := ArmReach.wrist_of(
		SHOULDER, reach["shoulder"] as Vector3, reach["elbow"] as float, UPPER, FORE
	)
	assert_almost_eq(wrist.distance_to(SHOULDER), UPPER + FORE, 0.01, "estirado del todo")
	assert_lt((wrist - SHOULDER).normalized().distance_to(Vector3.FORWARD), 0.01, "hacia el punto")


func test_aim_turns_the_hand_axes() -> void:
	var basis := ArmReach.aim(Vector3(0.0, 0.79, -0.61), Vector3.RIGHT, Vector3.LEFT, Vector3.UP)
	assert_lt((basis * Vector3(0.0, 0.79, -0.61).normalized()).distance_to(Vector3.LEFT), 0.001)
	assert_almost_eq(basis.determinant(), 1.0, 0.001, "giro sin espejo")

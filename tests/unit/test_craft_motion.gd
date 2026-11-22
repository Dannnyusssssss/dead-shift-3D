extends GutTest
## Movimiento de las manos al combinar: las dos manos se juntan en el punto de trabajo, al
## alcance de los brazos; al envolver la derecha da vueltas, con clavos golpea de arriba abajo y
## al ensamblar se acerca y se retira.

const REACH: float = 0.28 + 0.26
const SHOULDERS: Dictionary = {
	"right": Vector3(0.2, -0.24, 0.12),
	"left": Vector3(-0.2, -0.24, 0.12),
}
const KINDS: Array[String] = [CraftMotion.WRAP, CraftMotion.JOIN, CraftMotion.ASSEMBLE]


func test_hands_stay_together_and_within_reach() -> void:
	for kind: String in KINDS:
		for step: int in 21:
			var pose := CraftMotion.pose(kind, step / 20.0)
			for side: String in ["right", "left"]:
				var point: Vector3 = (pose[side] as Dictionary)["point"]
				assert_lt(point.distance_to(CraftMotion.WORK), 0.25, "%s %s junto" % [kind, side])
				assert_lt(
					point.distance_to(SHOULDERS[side] as Vector3),
					REACH,
					"%s %s alcanza" % [kind, side]
				)
			var right: Vector3 = (pose["right"] as Dictionary)["point"]
			var left: Vector3 = (pose["left"] as Dictionary)["point"]
			assert_gt(right.x, left.x, "%s: la derecha a la derecha" % kind)


func test_wrap_circles_around_the_held_item() -> void:
	var heights: Array[float] = []
	for step: int in 8:
		var hands := CraftMotion.pose(CraftMotion.WRAP, step / 8.0)
		var point: Vector3 = (hands["right"] as Dictionary)["point"]
		heights.append(point.y)
	var spread: float = (heights.max() as float) - (heights.min() as float)
	assert_gt(spread, CraftMotion.WRAP_RADIUS * 1.5, "da vueltas")


func test_join_lifts_and_strikes_twice() -> void:
	var strikes := 0
	var was_up := false
	for step: int in 200:
		var lift := CraftMotion.join_lift(step / 200.0)
		if lift > CraftMotion.JOIN_LIFT * 0.8:
			was_up = true
		elif lift <= 0.0 and was_up:
			strikes += 1
			was_up = false
	assert_eq(strikes, 2, "dos golpes por ciclo")


func test_assemble_comes_close_then_backs_off() -> void:
	assert_almost_eq(CraftMotion.assemble_reach(0.0), CraftMotion.ASSEMBLE_FAR, 0.001)
	assert_almost_eq(CraftMotion.assemble_reach(0.55), CraftMotion.ASSEMBLE_NEAR, 0.001)
	assert_almost_eq(CraftMotion.assemble_reach(1.0), CraftMotion.ASSEMBLE_FAR, 0.001)
	assert_ne(CraftMotion.assemble_twist(0.47), 0.0, "gira al encajar")


## Con «Reducir movimiento» las manos se juntan igual pero se mueven mucho menos.
func test_reduced_motion_shrinks_the_movement() -> void:
	for kind: String in KINDS:
		var full := _spread(kind, 1.0)
		var reduced := _spread(kind, CraftMotion.REDUCED)
		assert_lt(reduced, full * 0.5, "%s: mucho menos movimiento" % kind)
		var pose := CraftMotion.pose(kind, 0.0, CraftMotion.REDUCED)
		var point: Vector3 = (pose["right"] as Dictionary)["point"]
		assert_lt(point.distance_to(CraftMotion.WORK), 0.25, "%s: la mano sigue junto" % kind)


## Recorrido de la mano derecha en un ciclo (distancia máxima entre dos momentos).
func _spread(kind: String, amount: float) -> float:
	var points: Array[Vector3] = []
	for step: int in 40:
		points.append((CraftMotion.pose(kind, step / 40.0, amount)["right"] as Dictionary)["point"])
	var widest := 0.0
	for a: Vector3 in points:
		for b: Vector3 in points:
			widest = maxf(widest, a.distance_to(b))
	return widest

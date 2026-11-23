extends GutTest
## Distancia de dibujo por calidad: más corta en Baja, sin límite en Alta, y las piezas grandes
## siempre se ven desde más lejos que las pequeñas.


func test_lower_quality_draws_less_far() -> void:
	for kind: StringName in [DrawDistance.SMALL, DrawDistance.LARGE]:
		var low := DrawDistance.range_for(kind, SettingsSchema.QUALITY_LOW)
		var medium := DrawDistance.range_for(kind, SettingsSchema.QUALITY_MEDIUM)
		assert_gt(low, 0.0)
		assert_gt(medium, low)
		assert_eq(
			DrawDistance.range_for(kind, SettingsSchema.QUALITY_HIGH), 0.0, "Alta: sin límite"
		)


func test_large_pieces_reach_further() -> void:
	for quality: int in [SettingsSchema.QUALITY_LOW, SettingsSchema.QUALITY_MEDIUM]:
		assert_gt(
			DrawDistance.range_for(DrawDistance.LARGE, quality),
			DrawDistance.range_for(DrawDistance.SMALL, quality)
		)


func test_out_of_range_quality_is_clamped() -> void:
	assert_eq(DrawDistance.range_for(DrawDistance.SMALL, -3), Rules.DRAW_DISTANCE_SMALL[0])
	assert_eq(DrawDistance.range_for(DrawDistance.SMALL, 99), Rules.DRAW_DISTANCE_SMALL[2])

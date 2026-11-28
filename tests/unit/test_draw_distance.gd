extends GutTest
## Distancia de dibujo por calidad: más corta cuanto más baja, sin límite en Alta, y las piezas
## grandes siempre se ven desde más lejos que las pequeñas. Las luces de sala se apagan antes
## cuanto más baja es la calidad y nunca en Alta.


func test_lower_quality_draws_less_far() -> void:
	for kind: StringName in [DrawDistance.SMALL, DrawDistance.LARGE]:
		var minimum := DrawDistance.range_for(kind, SettingsSchema.QUALITY_MINIMUM)
		var low := DrawDistance.range_for(kind, SettingsSchema.QUALITY_LOW)
		var medium := DrawDistance.range_for(kind, SettingsSchema.QUALITY_MEDIUM)
		assert_gt(minimum, 0.0)
		assert_gt(low, minimum)
		assert_gt(medium, low)
		assert_eq(
			DrawDistance.range_for(kind, SettingsSchema.QUALITY_HIGH), 0.0, "Alta: sin límite"
		)


func test_large_pieces_reach_further() -> void:
	var limited: Array[int] = [
		SettingsSchema.QUALITY_MINIMUM, SettingsSchema.QUALITY_LOW, SettingsSchema.QUALITY_MEDIUM
	]
	for quality: int in limited:
		assert_gt(
			DrawDistance.range_for(DrawDistance.LARGE, quality),
			DrawDistance.range_for(DrawDistance.SMALL, quality)
		)


func test_out_of_range_quality_is_clamped() -> void:
	assert_eq(DrawDistance.range_for(DrawDistance.SMALL, -3), Rules.DRAW_DISTANCE_SMALL[0])
	assert_eq(
		DrawDistance.range_for(DrawDistance.SMALL, 99),
		Rules.DRAW_DISTANCE_SMALL[Rules.DRAW_DISTANCE_SMALL.size() - 1]
	)


func test_room_lights_fade_sooner_at_lower_quality() -> void:
	var minimum := DrawDistance.light_fade_for(SettingsSchema.QUALITY_MINIMUM)
	var low := DrawDistance.light_fade_for(SettingsSchema.QUALITY_LOW)
	var medium := DrawDistance.light_fade_for(SettingsSchema.QUALITY_MEDIUM)
	assert_gt(minimum, 0.0)
	assert_gt(low, minimum)
	assert_gt(medium, low)
	assert_eq(DrawDistance.light_fade_for(SettingsSchema.QUALITY_HIGH), 0.0, "Alta: nunca")


func test_every_quality_table_covers_every_level() -> void:
	var levels := SettingsSchema.QUALITY_HIGH + 1
	assert_eq(Rules.QUALITY_RENDER_SCALE.size(), levels)
	assert_eq(Rules.QUALITY_MAX_CANVAS_PIXELS.size(), levels)
	assert_eq(Rules.SOFTWARE_RENDER_SCALE.size(), levels)
	assert_eq(Rules.QUALITY_MSAA.size(), levels)
	assert_eq(Rules.QUALITY_VIEW_DISTANCE.size(), levels)
	assert_eq(Rules.QUALITY_DEPTH_FOG.size(), levels)
	assert_eq(Rules.LIGHT_FADE_DISTANCE.size(), levels)
	assert_eq(Rules.DRAW_DISTANCE_SMALL.size(), levels)
	assert_eq(Rules.DRAW_DISTANCE_LARGE.size(), levels)
	assert_eq(GoreBudget.MAX_PARTICLES.size(), levels)
	assert_eq(GoreBudget.MAX_STAINS.size(), levels)
	for quality: int in levels:
		var view: float = Rules.QUALITY_VIEW_DISTANCE[quality]
		assert_gt(view, Rules.DRAW_DISTANCE_LARGE[quality], "lo grande se ve antes del corte")


## La escena se dibuja siempre al 100 % (ampliarla costaba más que dibujarla entera) salvo Mínima
## con dibujo por software; lo que baja con la calidad es el tope de píxeles del lienzo.
func test_scene_is_full_size_and_canvas_cap_drops_with_quality() -> void:
	for quality: int in SettingsSchema.QUALITY_HIGH + 1:
		assert_eq(
			Settings.render_scale_for(quality, false), 1.0, "con gráfica, al 100 %%: %d" % quality
		)
	var minimum_soft := Settings.render_scale_for(SettingsSchema.QUALITY_MINIMUM, true)
	var low_soft := Settings.render_scale_for(SettingsSchema.QUALITY_LOW, true)
	assert_lt(minimum_soft, low_soft, "por software, más baja la calidad, menos escena")
	assert_lt(low_soft, 1.0)
	assert_eq(Settings.render_scale_for(SettingsSchema.QUALITY_HIGH, true), 1.0)
	var caps := Rules.QUALITY_MAX_CANVAS_PIXELS
	assert_gt(caps[SettingsSchema.QUALITY_MINIMUM], 0)
	assert_gt(caps[SettingsSchema.QUALITY_LOW], caps[SettingsSchema.QUALITY_MINIMUM])
	assert_gt(caps[SettingsSchema.QUALITY_MEDIUM], caps[SettingsSchema.QUALITY_LOW])
	assert_eq(caps[SettingsSchema.QUALITY_HIGH], 0, "Alta: sin tope")

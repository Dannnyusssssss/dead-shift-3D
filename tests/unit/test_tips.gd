extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Consejos de primera vez: cada uno una sola vez por partida, solo los conocidos, y todos con
## texto.


func test_each_tip_only_once_per_run() -> void:
	var world := WorldState.new()
	assert_true(Tips.take(world, Tips.DAMAGE))
	assert_false(Tips.take(world, Tips.DAMAGE), "ya salió")
	assert_true(Tips.take(world, Tips.MAP), "los demás siguen pendientes")
	assert_false(Tips.take(WorldState.new(), "made_up"), "solo los conocidos")
	assert_false(Tips.take(null, Tips.BAG), "sin mundo no hace nada")


func test_seen_tips_travel_with_the_save() -> void:
	var world := WorldState.new()
	Tips.take(world, Tips.DARK)
	var copy := WorldState.new()
	copy.load_data(world.to_data())
	assert_false(Tips.take(copy, Tips.DARK))


func test_every_tip_has_text_and_fits_the_save_flags() -> void:
	for tip_id: String in Tips.ALL:
		var key := Tips.text_key(tip_id)
		assert_ne(tr(key), key, "texto de " + key)
		assert_true(Validation.is_valid_id(Tips.PREFIX + tip_id))
	assert_lte(Tips.ALL.size() + 16, SaveSchema.MAX_FLAGS, "caben con las demás marcas")

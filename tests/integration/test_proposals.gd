extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Añadidos del Hito 3: la porra que siempre se lleva (no se rompe ni se suelta), el segundo
## Neutrax que se prepara con un vial y una jeringa, el culatazo de la escopeta vacía, la tecla
## para cambiar lo que se lanza y el aviso de los últimos 30 segundos antes de convertirse.


func after_each() -> void:
	GameState.start_new_run()


func test_baton_is_always_carried_and_never_breaks() -> void:
	GameState.start_new_run()
	var state := GameState.player
	var slot := state.inventory.find_slot(PlayerState.BOUND_WEAPON)
	assert_gte(slot, 0, "la porra va en la mochila desde el principio")
	var baton := state.inventory.get_slot(slot)
	assert_true(baton.item.bound, "no se suelta")
	assert_true(baton.durability.is_unbreakable(), "no se rompe")
	assert_lt(baton.item.weapon.damage, GameState.items.get_item("bat").weapon.damage, "débil")
	assert_eq(state.equipped().id(), PlayerState.STARTING_WEAPON, "se empieza con la pistola")
	for _hit: int in 200:
		WeaponUse.melee_hit(baton)
	assert_false(baton.durability.is_broken())


## Una partida guardada antes de la porra la recibe al cargarse.
func test_old_save_gets_the_baton() -> void:
	var data := {"health": 80.0, "inventory": [{"id": "pistol", "count": 1}]}
	var state := SaveGame.restore_player(data, GameState.items)
	assert_gte(state.inventory.find_slot(PlayerState.BOUND_WEAPON), 0)


func test_second_neutrax_is_crafted_from_vial_and_syringe() -> void:
	var recipe: RecipeData = null
	for candidate: RecipeData in GameState.CATALOG.recipes:
		if candidate.result_id == "neutrax":
			recipe = candidate
	assert_not_null(recipe, "receta del Neutrax")
	assert_eq([recipe.input_a, recipe.input_b], ["antiviral_vial", "syringe"])
	# Los dos ingredientes están en el edificio antes del jefe (pisos 0 a 2), con cualquier
	# semilla (el reparto no los saca de su piso).
	for seed_value: int in 60:
		var plan := LootPlan.build(GameState.CATALOG.floors, seed_value, true, GameState.items)
		var found: Array[String] = []
		for floor_data: FloorData in GameState.CATALOG.floors:
			for room: RoomData in floor_data.rooms:
				for spot: LootSpot in plan.loot_for(floor_data.id, room):
					if spot.item_id in ["antiviral_vial", "syringe"]:
						assert_lte(floor_data.level_index, 2, spot.item_id)
						found.append(spot.item_id)
		found.sort()
		assert_eq(found, ["antiviral_vial", "syringe"] as Array[String], "semilla %d" % seed_value)


func test_empty_shotgun_strikes_with_the_butt() -> void:
	GameState.start_new_run()
	var inventory := GameState.player.inventory
	var shotgun := ItemStack.new(GameState.items.get_item("shotgun"))
	shotgun.ammo_loaded = 0
	assert_true(WeaponUse.uses_butt(shotgun, inventory), "vacía y sin cartuchos: culatazo")
	inventory.add_item(GameState.items.get_item("shotgun_shells"), 2)
	assert_false(WeaponUse.uses_butt(shotgun, inventory), "con cartuchos se recarga")
	var pistol := ItemStack.new(GameState.items.get_item("pistol"))
	pistol.ammo_loaded = 0
	inventory.remove_count("pistol_ammo", 99)
	assert_false(WeaponUse.uses_butt(pistol, inventory), "solo la escopeta")
	assert_eq(WeaponUse.BUTT_DAMAGE, GameState.items.get_item("baton").weapon.damage)


func test_quick_throw_can_be_cycled() -> void:
	GameState.start_new_run()
	var state := GameState.player
	state.inventory.add_item(GameState.items.get_item("rag"), 2)
	state.inventory.add_item(GameState.items.get_item("bottle"), 1)
	var first := state.quick_throw_item()
	assert_false(first.is_empty())
	var second := state.cycle_quick_throw()
	assert_ne(second, first, "cambia a otro material")
	assert_eq(state.quick_throw_item(), second, "la tecla rápida lanza el elegido")
	assert_eq(state.cycle_quick_throw(), first, "da la vuelta")
	assert_true(InputMap.has_action("throw_next"))


func test_conversion_warning_in_the_last_30_seconds() -> void:
	GameState.start_new_run()
	var warning := ConversionWarning.new()
	add_child_autofree(warning)
	await wait_frames(2)
	assert_false(warning.is_warning(), "sano: sin aviso")
	var infection := GameState.player.infection
	assert_true(infection.try_infect(1.0, RandomNumberGenerator.new()))
	await wait_frames(2)
	assert_false(warning.is_warning(), "con tiempo de sobra: sin aviso")
	infection.time_left = 25.0
	await wait_frames(2)
	assert_true(warning.is_warning(), "en los últimos 30 s")
	assert_lt(ConversionWarning.PULSE_RATE, 3.0, "menos de 3 latidos por segundo")
	infection.infected = false
	await wait_frames(2)
	assert_false(warning.is_warning(), "curado: se quita")

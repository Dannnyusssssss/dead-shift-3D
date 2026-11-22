extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Estado del jugador: equipo inicial, daño con chaleco, cambio de arma, armas rotas y chaleco.

const Fixtures = preload("res://tests/helpers/fixtures.gd")

var _items: ItemCatalog


func before_each() -> void:
	var pistol := Fixtures.pistol(8)
	var ammo := Fixtures.stackable("ammo", 60)
	_items = (
		ItemCatalog
		. new(
			[
				pistol,
				ammo,
				Fixtures.melee("pipe", 2.0, 1.0),
				Fixtures.vest(),
				Fixtures.consumable("bandage", ItemData.EFFECT_HEAL, 30.0),
				Fixtures.consumable("antibiotics", ItemData.EFFECT_DELAY_INFECTION),
				Fixtures.consumable("neutrax", ItemData.EFFECT_CURE_INFECTION),
				Fixtures.material("rock", 5),
				_lure(),
			]
		)
	)


func test_starting_kit_has_loaded_pistol_and_little_ammo() -> void:
	var state := PlayerState.new(_items)
	state.give_starting_kit()
	assert_eq(state.equipped().id(), "pistol")
	assert_eq(state.equipped().ammo_loaded, 8)
	assert_eq(state.inventory.count_of("ammo"), PlayerState.STARTING_RESERVE_AMMO)


func test_damage_with_vest_and_death() -> void:
	var state := PlayerState.new(_items)
	state.vest = ItemStack.new(_items.get_item("vest"))
	assert_eq(state.take_damage(20.0), 10.0)
	state.vest = null
	state.take_damage(1000.0)
	assert_true(state.is_dead())
	assert_eq(state.health, 0.0)
	assert_eq(state.take_damage(5.0), 0.0, "muerto no recibe más")


func test_cycle_and_select_weapons() -> void:
	var state := PlayerState.new(_items, 4)
	state.give_starting_kit()
	state.inventory.add_stack(ItemStack.new(_items.get_item("pipe")))
	var pipe_slot := state.inventory.find_slot("pipe")
	assert_true(state.cycle_weapon(1))
	assert_eq(state.equipped_slot, pipe_slot)
	assert_true(state.cycle_weapon(-1))
	assert_eq(state.equipped().id(), "pistol")
	assert_false(state.select_slot(state.inventory.find_slot("ammo")), "la munición no se equipa")


func test_broken_weapon_is_removed_and_counted() -> void:
	var state := PlayerState.new(_items, 4)
	state.give_starting_kit()
	state.inventory.add_stack(ItemStack.new(_items.get_item("pipe")))
	state.select_slot(state.inventory.find_slot("pipe"))
	var pipe := state.equipped()
	WeaponUse.melee_hit(pipe)
	assert_eq(WeaponUse.melee_hit(pipe), WeaponUse.HIT_BROKE)
	assert_eq(state.handle_broken_weapons(), 1)
	assert_eq(state.weapons_broken, 1)
	assert_eq(state.equipped().id(), "pistol", "vuelve a la pistola")


func test_swap_vest_returns_old_one() -> void:
	var state := PlayerState.new(_items)
	var first := ItemStack.new(_items.get_item("vest"), 1, 0.3)
	var second := ItemStack.new(_items.get_item("vest"), 1, 0.9)
	assert_null(state.swap_vest(first))
	assert_eq(state.swap_vest(second), first)
	assert_eq(state.vest, second)
	var pipe := ItemStack.new(_items.get_item("pipe"))
	assert_eq(state.swap_vest(pipe), pipe, "solo acepta chalecos")
	assert_eq(state.vest, second)


func test_take_one_splits_a_stack() -> void:
	var state := PlayerState.new(_items)
	state.inventory.add_item(_items.get_item("ammo"), 3)
	var slot := state.inventory.find_slot("ammo")
	var one := state.take_one(slot)
	assert_eq(one.count, 1)
	assert_eq(state.inventory.count_of("ammo"), 2)
	assert_null(state.take_one(7), "casilla vacía")


func test_take_last_unit_empties_slot() -> void:
	var state := PlayerState.new(_items)
	state.inventory.add_item(_items.get_item("ammo"), 1)
	var slot := state.inventory.find_slot("ammo")
	assert_not_null(state.take_one(slot))
	assert_null(state.inventory.get_slot(slot))


func test_throwing_equipped_weapon_equips_another() -> void:
	var state := PlayerState.new(_items)
	state.give_starting_kit()
	state.inventory.add_stack(ItemStack.new(_items.get_item("pipe")))
	var pistol_slot := state.equipped_slot
	var thrown := state.take_one(pistol_slot)
	assert_eq(thrown.id(), "pistol")
	assert_eq(state.equipped().id(), "pipe")


func test_quick_throw_uses_bag_materials_lures_last() -> void:
	var state := PlayerState.new(_items)
	state.inventory.add_stack(ItemStack.new(_items.get_item("pipe")))
	assert_eq(state.quick_throw_item(), "", "las armas no se lanzan con la acción rápida")
	state.inventory.add_item(_items.get_item("lure"), 1)
	assert_eq(state.quick_throw_item(), "lure", "el señuelo si no hay otra cosa")
	state.inventory.add_item(_items.get_item("rock"), 2)
	assert_eq(state.quick_throw_item(), "rock", "primero lo que no es señuelo")


func test_take_material_from_bag() -> void:
	var state := PlayerState.new(_items)
	state.inventory.add_item(_items.get_item("rock"), 2)
	var one := state.take_material("rock")
	assert_eq(one.count, 1)
	assert_eq(state.inventory.bag.count("rock"), 1)
	assert_not_null(state.take_material("rock"))
	assert_null(state.take_material("rock"), "ya no queda")
	assert_null(state.take_material("nada"))


static func _lure() -> ItemData:
	var data := Fixtures.material("lure", 3)
	data.lure_time = 6.0
	return data


func _with(item_id: String, amount: int = 1) -> PlayerState:
	var state := PlayerState.new(_items)
	state.inventory.add_item(_items.get_item(item_id), amount)
	return state


func test_bites_fill_exposure_and_infect_when_full() -> void:
	var state := PlayerState.new(_items)
	for bite: int in 3:
		state.take_bite(5.0, 0.25)
		assert_false(state.infection.infected, "golpe %d de 4: aún no" % (bite + 1))
	assert_almost_eq(state.infection.exposure, 0.75, 0.0001)
	state.take_bite(5.0, 0.25)
	assert_true(state.infection.infected, "el cuarto golpe de caminante infecta")
	var clean := PlayerState.new(_items)
	clean.take_bite(10.0, 0.0)
	assert_eq(clean.infection.exposure, 0.0, "un golpe sin exposición no suma")


func test_bandage_heals_up_to_max_and_is_consumed() -> void:
	var state := _with("bandage", 2)
	var slot := state.inventory.find_slot("bandage")
	assert_eq(state.check_use(slot), PlayerState.USE_FULL_HEALTH)
	state.take_damage(10.0)
	assert_eq(state.use_item(slot), PlayerState.USE_OK)
	assert_eq(state.health, Rules.PLAYER_MAX_HEALTH, "no pasa del máximo")
	assert_eq(state.inventory.count_of("bandage"), 1)


func test_antibiotics_and_neutrax_need_infection() -> void:
	var state := _with("antibiotics")
	state.inventory.add_item(_items.get_item("neutrax"), 1)
	var antibiotics := state.inventory.find_slot("antibiotics")
	var neutrax := state.inventory.find_slot("neutrax")
	assert_eq(state.use_item(antibiotics), PlayerState.USE_NOT_INFECTED)
	assert_eq(state.use_item(neutrax), PlayerState.USE_NOT_INFECTED)
	assert_eq(state.inventory.count_of("neutrax"), 1, "no se gasta")
	state.infection.add_exposure(1.0)
	assert_eq(state.use_item(antibiotics), PlayerState.USE_COUNTDOWN_FULL, "cuenta completa")
	state.infection.tick(100.0)
	assert_eq(state.use_item(antibiotics), PlayerState.USE_OK)
	assert_almost_eq(state.infection.time_left, Rules.INFECTION_TIME - 10.0, 0.001, "+90 s")
	assert_eq(state.use_item(neutrax), PlayerState.USE_OK)
	assert_false(state.infection.infected)


func test_non_consumables_cannot_be_used() -> void:
	var state := _with("ammo", 3)
	assert_eq(state.check_use(state.inventory.find_slot("ammo")), PlayerState.USE_NOT_USABLE)
	assert_eq(state.check_use(7), PlayerState.USE_NOT_USABLE)


func test_infection_reaching_zero_kills_by_conversion() -> void:
	var state := PlayerState.new(_items)
	state.infection.add_exposure(1.0)
	assert_false(state.tick_infection(Rules.INFECTION_TIME - 1.0))
	assert_true(state.tick_infection(2.0))
	assert_true(state.is_dead())
	assert_eq(state.death_cause, PlayerState.CAUSE_INFECTION)


func test_death_by_damage_records_cause() -> void:
	var state := PlayerState.new(_items)
	state.take_damage(1000.0)
	assert_eq(state.death_cause, PlayerState.CAUSE_DAMAGE)


func test_key_items_are_kept_once() -> void:
	var state := PlayerState.new(_items)
	assert_true(state.keys.add("phone_antenna"))
	assert_false(state.keys.add("phone_antenna"), "sin repetir")
	assert_false(state.keys.add(""))
	assert_true(state.keys.has("phone_antenna"))
	assert_eq(state.inventory.used_slots(), 0, "no ocupa casilla")

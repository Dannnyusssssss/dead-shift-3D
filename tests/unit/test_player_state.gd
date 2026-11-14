extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Estado del jugador: equipo inicial, daño con chaleco, cambio de arma, armas rotas y chaleco.

const Fixtures = preload("res://tests/helpers/fixtures.gd")

var _items: ItemCatalog


func before_each() -> void:
	var pistol := Fixtures.pistol(8)
	var ammo := Fixtures.material("ammo", 60)
	_items = ItemCatalog.new([pistol, ammo, Fixtures.melee("pipe", 2.0, 1.0), Fixtures.vest()])


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

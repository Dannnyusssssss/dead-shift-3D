extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Curación rápida: venda si falta salud; con infección, antibióticos mientras sumen tiempo y
## Neutrax en último lugar.

const Fixtures = preload("res://tests/helpers/fixtures.gd")

var _items: ItemCatalog


func before_each() -> void:
	_items = (
		ItemCatalog
		. new(
			[
				Fixtures.consumable("bandage", ItemData.EFFECT_HEAL, 30.0),
				Fixtures.consumable("antibiotics", ItemData.EFFECT_DELAY_INFECTION),
				Fixtures.consumable("neutrax", ItemData.EFFECT_CURE_INFECTION),
			]
		)
	)


func _state(ids: Array[String]) -> PlayerState:
	var state := PlayerState.new(_items)
	state.inventory = Inventory.new()
	for item_id: String in ids:
		state.inventory.add_item(_items.get_item(item_id), 1)
	return state


func test_nothing_needed_when_healthy() -> void:
	var state := _state(["bandage", "neutrax"])
	assert_eq(QuickHeal.choose(state), -1)
	assert_eq(QuickHeal.reason(state), QuickHeal.NOTHING_NEEDED)


func test_bandage_first_when_hurt() -> void:
	var state := _state(["neutrax", "bandage"])
	state.take_damage(20.0)
	state.infection.add_exposure(1.0)
	assert_eq(QuickHeal.choose(state), state.inventory.find_slot("bandage"))


func test_infection_prefers_antibiotics_while_they_add_time() -> void:
	var state := _state(["neutrax", "antibiotics"])
	state.infection.add_exposure(1.0)
	assert_eq(QuickHeal.choose(state), state.inventory.find_slot("neutrax"), "cuenta llena")
	state.infection.tick(120.0)
	assert_eq(QuickHeal.choose(state), state.inventory.find_slot("antibiotics"))


func test_reports_missing_cure() -> void:
	var state := _state([])
	state.take_damage(20.0)
	assert_eq(QuickHeal.choose(state), -1)
	assert_eq(QuickHeal.reason(state), QuickHeal.NOTHING_TO_USE)

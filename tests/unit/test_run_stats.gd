extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Estadísticas y nota final: puntos por tiempo (solo en el rescate), daño, armas rotas,
## objetos creados y balas sobrantes; letras y comparación de marcas.

const Fixtures = preload("res://tests/helpers/fixtures.gd")


func _stats(outcome: int = RunStats.OUTCOME_RESCUED) -> RunStats:
	var stats := RunStats.new()
	stats.outcome = outcome
	return stats


func test_perfect_rescue_gets_top_grade() -> void:
	var stats := _stats()
	stats.seconds = 900.0
	stats.items_crafted = 5
	stats.ammo_left = 40
	assert_eq(stats.score(), 100)
	assert_eq(stats.grade(), "S")


func test_slow_hurt_rescue_gets_low_grade() -> void:
	var stats := _stats()
	stats.seconds = 4000.0
	stats.damage_taken = 500.0
	stats.weapons_broken = 6
	assert_eq(stats.score(), 0)
	assert_eq(stats.grade(), "D")


func test_time_only_counts_when_rescued() -> void:
	var rescued := _stats()
	rescued.seconds = 900.0
	var lost := _stats(RunStats.OUTCOME_LOST)
	lost.seconds = 900.0
	assert_eq(rescued.score() - lost.score(), 30)


func test_each_factor_moves_the_score() -> void:
	var base := _stats()
	base.seconds = 2400.0
	var reference := base.score()
	var hurt := _stats()
	hurt.seconds = 2400.0
	hurt.damage_taken = 200.0
	assert_lt(hurt.score(), reference, "daño")
	var broke := _stats()
	broke.seconds = 2400.0
	broke.weapons_broken = 2
	assert_lt(broke.score(), reference, "armas rotas")
	var crafty := _stats()
	crafty.seconds = 2400.0
	crafty.items_crafted = 2
	assert_gt(crafty.score(), reference, "objetos creados")
	var saver := _stats()
	saver.seconds = 2400.0
	saver.ammo_left = 10
	assert_gt(saver.score(), reference, "balas sobrantes")


func test_bonuses_are_capped() -> void:
	var stats := _stats(RunStats.OUTCOME_LOST)
	stats.items_crafted = 100
	stats.ammo_left = 1000
	assert_eq(stats.score(), 25 + 10 + 15 + 20)


func test_grade_rank_orders_letters() -> void:
	assert_lt(RunStats.grade_rank("S"), RunStats.grade_rank("A"))
	assert_lt(RunStats.grade_rank("C"), RunStats.grade_rank("D"))
	assert_eq(RunStats.grade_rank("Z"), RunStats.GRADES.size(), "letra desconocida al final")


func test_from_state_collects_player_numbers() -> void:
	var pistol := Fixtures.pistol(8)
	var ammo := Fixtures.stackable("ammo", 60)
	ammo.category = ItemData.CATEGORY_AMMO
	var state := PlayerState.new(ItemCatalog.new([pistol, ammo]))
	state.give_starting_kit()
	state.take_damage(15.0)
	state.weapons_broken = 1
	state.items_crafted = 2
	state.kills = 9
	var stats := RunStats.from_state(state, RunStats.OUTCOME_DEAD, 123.0)
	assert_eq(stats.outcome, RunStats.OUTCOME_DEAD)
	assert_eq(stats.seconds, 123.0)
	assert_eq(stats.damage_taken, 15.0)
	assert_eq(stats.ammo_left, 8 + PlayerState.STARTING_RESERVE_AMMO, "cargadas y de reserva")
	assert_eq(stats.kills, 9)

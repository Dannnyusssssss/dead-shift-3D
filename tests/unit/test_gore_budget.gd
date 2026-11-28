extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Topes de los efectos de impacto y «Reducir sangre»: nunca se pasa del tope por calidad, las
## manchas se reciclan de la más vieja a la más nueva y con la opción no hay sangre.


func test_caps_grow_with_quality() -> void:
	var minimum := GoreBudget.new(SettingsSchema.QUALITY_MINIMUM)
	var low := GoreBudget.new(SettingsSchema.QUALITY_LOW)
	var high := GoreBudget.new(SettingsSchema.QUALITY_HIGH)
	assert_lt(minimum.max_particles(), low.max_particles())
	assert_lt(low.max_particles(), high.max_particles())
	assert_lt(low.max_stains(), high.max_stains())
	assert_eq(
		GoreBudget.new(9).quality, SettingsSchema.QUALITY_HIGH, "la calidad se limita al rango"
	)


func test_particles_never_exceed_the_cap() -> void:
	var budget := GoreBudget.new(0)
	var total := 0
	for i: int in 20:
		total += budget.reserve_particles(GoreBudget.BURST_DEATH)
	assert_eq(total, budget.max_particles())
	assert_eq(budget.reserve_particles(5), 0)
	budget.release_particle()
	assert_eq(budget.reserve_particles(5), 1)
	assert_eq(budget.reserve_particles(-3), 0)


func test_stain_slots_wrap_around() -> void:
	var budget := GoreBudget.new(0)
	var first := budget.next_stain_slot()
	for i: int in budget.max_stains() - 1:
		budget.next_stain_slot()
	assert_eq(budget.next_stain_slot(), first, "tras el tope se recicla la mancha más vieja")


func test_reduce_gore_changes_blood_for_dust() -> void:
	var normal := GoreBudget.new(1, false)
	var reduced := GoreBudget.new(1, true)
	assert_eq(normal.flesh_kind(), GoreBudget.KIND_BLOOD)
	assert_true(normal.leaves_stain())
	assert_eq(reduced.flesh_kind(), GoreBudget.KIND_DUST)
	assert_false(reduced.leaves_stain())


## Los efectos responden a las señales y respetan la opción (sin mancha con «Reducir sangre»).
func test_impact_effects_follow_the_signals() -> void:
	var effects := ImpactEffects.new()
	add_child_autofree(effects)
	effects.budget.reduce_gore = true
	EventBus.enemy_hit.emit(Vector3(0, 1, 0), Vector3.FORWARD, true)
	assert_gt(effects.budget.live_particles(), 0)
	var stains := effects.get("_stains") as MultiMeshInstance3D
	assert_false(stains.visible, "con «Reducir sangre» no hay manchas")
	for i: int in 60:
		effects._process(0.05)
	assert_eq(effects.budget.live_particles(), 0, "las partículas terminan")
	EventBus.debris.emit(Vector3.ZERO)
	assert_gt(effects.budget.live_particles(), 0)

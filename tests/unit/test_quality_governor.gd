extends GutTest
## Calidad automática: no decide durante el margen inicial, baja solo si la media sostenida de
## fotogramas por segundo queda por debajo del mínimo, un tirón suelto no decide solo y después
## de bajar vuelve a esperar el margen.

const STEP_SLOW: float = 1.0 / 20.0
const STEP_FAST: float = 1.0 / 60.0


func _run(governor: QualityGovernor, step: float, seconds: float) -> int:
	var drops := 0
	var elapsed := 0.0
	while elapsed < seconds:
		if governor.tick(step):
			drops += 1
		elapsed += step
	return drops


func test_fast_game_never_lowers_quality() -> void:
	var governor := QualityGovernor.new()
	assert_eq(_run(governor, STEP_FAST, 120.0), 0)


func test_slow_game_lowers_once_per_window_after_the_grace() -> void:
	var governor := QualityGovernor.new()
	assert_eq(_run(governor, STEP_SLOW, QualityGovernor.GRACE), 0, "durante el margen, nada")
	var to_first := QualityGovernor.WINDOW + 0.5
	assert_eq(_run(governor, STEP_SLOW, to_first), 1, "baja tras una ventana lenta")
	assert_eq(_run(governor, STEP_SLOW, QualityGovernor.GRACE * 0.9), 0, "y vuelve a esperar")


func test_single_long_hitch_does_not_decide_alone() -> void:
	var governor := QualityGovernor.new()
	_run(governor, STEP_FAST, QualityGovernor.GRACE + 1.0)
	assert_false(governor.tick(3.0), "un fotograma de 3 s cuenta como mucho MAX_DELTA")
	assert_eq(_run(governor, STEP_FAST, QualityGovernor.WINDOW), 0)


func test_reset_restarts_the_grace() -> void:
	var governor := QualityGovernor.new()
	_run(governor, STEP_SLOW, QualityGovernor.GRACE + QualityGovernor.WINDOW * 0.9)
	governor.reset()
	assert_eq(_run(governor, STEP_SLOW, QualityGovernor.GRACE), 0)

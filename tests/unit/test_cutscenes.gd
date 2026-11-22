extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Intro, escena final y créditos: se pueden saltar, avisan al terminar (la escena final, cuando
## tocan las estadísticas, en pleno vuelo) y los créditos llevan el inventario de licencias y el
## aviso del motor.


func test_intro_can_be_skipped_once() -> void:
	var intro := Intro.new()
	watch_signals(intro)
	add_child_autofree(intro)
	await wait_frames(2)
	intro.skip()
	intro.skip()
	assert_signal_emit_count(intro, "finished", 1, "avisa una sola vez")


func test_intro_skips_with_escape() -> void:
	var intro := Intro.new()
	watch_signals(intro)
	add_child_autofree(intro)
	await wait_frames(2)
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	intro._unhandled_input(key)
	assert_signal_emitted(intro, "finished")


func test_outro_without_level_ends_at_once() -> void:
	var outro := Outro.new()
	watch_signals(outro)
	add_child_autofree(outro)
	await wait_frames(1)
	assert_signal_emitted(outro, "results_time", "sin cámara no hay escena")


func test_outro_with_level_can_be_skipped() -> void:
	var level := Node3D.new()
	add_child_autofree(level)
	var outro := Outro.new()
	outro.setup(level, Vector3.ZERO, Vector3(2.0, 0.0, 1.0), RunStats.OUTCOME_RESCUED)
	watch_signals(outro)
	add_child_autofree(outro)
	await wait_frames(2)
	assert_signal_not_emitted(outro, "results_time")
	outro.skip()
	outro.skip()
	assert_signal_emit_count(outro, "results_time", 1, "una sola vez")
	var camera: Camera3D = outro.get("_camera")
	assert_true(is_instance_valid(camera), "la cámara de la escena sigue al saltar")
	assert_true(camera.current, "no vuelve la cámara del jugador")


func test_credits_list_licenses_and_engine_notice() -> void:
	var text := CreditsView.credits_text()
	assert_string_contains(text, "CC0")
	assert_string_contains(text, tr("credits_ambientcg"))
	assert_string_contains(text, tr("credits_quaternius"))
	assert_string_contains(text, tr("credits_kenney"))
	assert_string_contains(text, Engine.get_license_text().left(40))
	var view := CreditsView.new()
	add_child_autofree(view)
	watch_signals(view)
	view.open()
	assert_true(view.visible)
	view.close()
	assert_false(view.visible)
	assert_signal_emitted(view, "closed")


## Cada desenlace recorre sus etapas: el rescate aterriza, sube el guardia y se aleja; la caída
## además cae; el rescate perdido solo ve irse al helicóptero. Las estadísticas salen una vez y
## durante el vuelo (en la etapa «away», o «lost»), no al final; la cámara de la escena se queda.
func test_outro_stages_follow_the_outcome() -> void:
	var expected := {
		RunStats.OUTCOME_RESCUED: ["land", "board", "away"],
		RunStats.OUTCOME_CRASHED: ["land", "board", "away", "fall"],
		RunStats.OUTCOME_LOST: ["lost"],
	}
	for outcome: int in expected:
		var level := Node3D.new()
		add_child_autofree(level)
		var outro := Outro.new()
		outro.setup(level, Vector3.ZERO, Vector3(2.0, 0.0, 1.0), outcome)
		watch_signals(outro)
		add_child(outro)
		var seen: Array[String] = []
		var stage_at_results := ""
		for _step: int in 900:
			if not is_instance_valid(outro) or outro.get("_done"):
				break
			var stage: String = outro.stage
			if not stage.is_empty() and not seen.has(stage):
				seen.append(stage)
			if outro.results_shown and stage_at_results.is_empty():
				stage_at_results = stage
			await wait_frames(1)
		assert_eq(seen, expected[outcome] as Array[String], "desenlace %d" % outcome)
		assert_signal_emit_count(outro, "results_time", 1, "estadísticas una vez")
		var during := "lost" if outcome == RunStats.OUTCOME_LOST else "away"
		assert_eq(stage_at_results, during, "estadísticas en pleno vuelo (%d)" % outcome)
		var camera: Camera3D = outro.get("_camera")
		assert_true(camera.current, "la cámara de la escena se queda (%d)" % outcome)
		outro.queue_free()


## Subir al helicóptero sano es el rescate; infectado y sin curar, la caída.
func test_boarding_outcome_depends_on_the_infection() -> void:
	var infection := Infection.new()
	assert_eq(RunStats.boarding_outcome(infection), RunStats.OUTCOME_RESCUED)
	assert_true(infection.add_exposure(1.0))
	assert_eq(RunStats.boarding_outcome(infection), RunStats.OUTCOME_CRASHED)
	assert_eq(RunStats.boarding_outcome(null), RunStats.OUTCOME_RESCUED)

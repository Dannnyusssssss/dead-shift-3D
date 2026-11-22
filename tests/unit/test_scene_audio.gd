extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Sonido de la intro y del ambiente, y despertar del guardia al empezar: la intro tiene sonido
## en cada momento y ya no construye el cuarto aparte del guardia; el ambiente de cada piso y sus
## sonidos sueltos existen; el despertar bloquea los controles, esconde los brazos y al terminar
## (o saltarlo) deja la cámara en su sitio.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")


func test_every_intro_sound_exists() -> void:
	assert_false(Intro.SOUNDS.is_empty())
	for sound_id: String in Intro.SOUNDS:
		assert_true(AudioDirector.has_sound(sound_id), "falta el sonido %s" % sound_id)


func test_intro_has_no_separate_guard_room() -> void:
	var intro := Intro.new()
	add_child_autofree(intro)
	await wait_frames(1)
	assert_eq(intro.find_children("GuardRoom", "", true, false).size(), 0)
	assert_eq(intro.find_children("GuardChair", "", true, false).size(), 0)
	intro.skip()


func test_floor_ambience_and_its_events_exist() -> void:
	for floor_id: String in AudioDirector.FLOOR_AMBIENCE:
		var bed: String = AudioDirector.FLOOR_AMBIENCE[floor_id]
		assert_true(AudioDirector.has_sound(bed), "falta el fondo %s" % bed)
		var events: Array = AudioDirector.AMBIENT_EVENTS.get(bed, [])
		assert_false(events.is_empty(), "el piso %s tiene sonidos sueltos" % floor_id)
		for event: String in events:
			assert_true(AudioDirector.has_sound(event), "falta el sonido suelto %s" % event)


func test_ambience_can_be_silenced_and_changed() -> void:
	AudioDirector.set_ambience("amb_rooftop", false)
	AudioDirector.set_ambience("")
	AudioDirector.set_ambience("amb_ground")
	assert_true(AudioDirector.has_sound("amb_ground"))
	AudioDirector.set_ambience("")


func test_wake_up_blocks_controls_until_finished() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	await wait_frames(1)
	var seconds := player.play_wake_up()
	assert_gt(seconds, 1.5, "dura lo bastante para verse")
	assert_lt(seconds, 4.0, "y es corto")
	assert_true(player.is_waking())
	assert_false(player.controls_enabled, "no se mueve mientras despierta")
	assert_false(player.arms.visible, "los brazos no atraviesan la mesa")
	assert_lt(player.camera.position.y, -0.3, "empieza con la cabeza caída")
	player.finish_wake_up()
	assert_false(player.is_waking())
	assert_true(player.controls_enabled)
	assert_true(player.arms.visible)
	assert_eq(player.camera.position, Vector3.ZERO)
	assert_eq(player.camera.rotation, Vector3.ZERO)


func test_wake_up_ends_by_itself() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	await wait_frames(1)
	var seconds := player.play_wake_up()
	await wait_seconds(seconds + 0.3)
	assert_false(player.is_waking(), "termina solo")
	assert_eq(player.camera.position, Vector3.ZERO)

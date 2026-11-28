extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Sonidos: la lista generada está completa, cada aviso, enemigo y piso tiene su sonido, y
## ningún archivo pasa del pico acordado (sin sonidos que revienten de golpe).

const SOUND_LIST := "res://assets/audio/sounds.json"
## Pico máximo de los WAV (-3 dB, el de tools/blender/audio.py) con un margen de redondeo.
const MAX_PEAK := 0.71


func _listing() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOUND_LIST))
	return parsed if parsed is Dictionary else {}


func test_every_listed_sound_exists() -> void:
	var listing := _listing()
	assert_gt(listing.size(), 50)
	for key: Variant in listing:
		var path: String = "res://assets/audio/" + String(listing[key])
		assert_true(ResourceLoader.exists(path), path)


func test_cues_enemies_and_floors_have_sounds() -> void:
	for cue: String in AudioDirector.CUE_SOUNDS:
		assert_true(AudioDirector.has_sound(AudioDirector.CUE_SOUNDS[cue]), cue)
	for enemy: EnemyData in GameState.CATALOG.enemies:
		var voice := "voice_" + ("boss" if enemy.model_id == "technician" else enemy.model_id)
		assert_true(AudioDirector.has_sound(voice), voice)
	for floor_data: FloorData in GameState.CATALOG.floors:
		assert_true(AudioDirector.FLOOR_AMBIENCE.has(floor_data.id), floor_data.id)
		assert_true(AudioDirector.has_sound(AudioDirector.FLOOR_AMBIENCE[floor_data.id]))
	for sound_id: String in [
		"gun_pistol",
		"gun_shotgun",
		"reload_click",
		"swing",
		"pickup",
		"step_concrete",
		"step_wood",
		"step_metal",
		"hit_flesh",
		"hit_wood",
		"hit_metal",
		"knife_slice",
		"geiger_loop",
		"helicopter_loop",
		"music_tension",
		"music_boss",
		"music_rescue"
	]:
		assert_true(AudioDirector.has_sound(sound_id), sound_id)


func test_loops_repeat() -> void:
	for sound_id: String in ["amb_ground", "music_tension", "geiger_loop", "helicopter_loop"]:
		var wav := AudioDirector.loop_stream(sound_id) as AudioStreamWAV
		assert_not_null(wav, sound_id)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, sound_id)


## Lee cada WAV (16 bits, mono) y comprueba el pico: así ningún sonido sale mucho más fuerte.
func test_no_sound_exceeds_the_peak() -> void:
	var listing := _listing()
	for key: Variant in listing:
		var bytes := FileAccess.get_file_as_bytes("res://assets/audio/" + String(listing[key]))
		var peak := 0
		var i := 44
		while i + 1 < bytes.size():
			var value := bytes.decode_s16(i)
			peak = maxi(peak, absi(value))
			i += 2
		assert_lte(float(peak) / 32767.0, MAX_PEAK, String(key))


## Los canales vienen del archivo de canales del proyecto (no se crean al arrancar, porque en la
## web esos canales no llegan a la salida) y todos acaban en «Master».
func test_buses_come_from_layout_file() -> void:
	var layout_path := String(ProjectSettings.get_setting("audio/buses/default_bus_layout"))
	var layout := load(layout_path) as AudioBusLayout
	assert_not_null(layout, layout_path)
	for bus_name: String in ["Music", "SFX", "Ambience"]:
		var index := AudioServer.get_bus_index(bus_name)
		assert_gte(index, 0, bus_name)
		assert_eq(String(AudioServer.get_bus_send(index)), "Master", bus_name)
	var source := FileAccess.get_file_as_string("res://game/systems/audio_director.gd")
	assert_false(source.contains("add_bus("), "los canales no se crean por código")


## Con el juego en pausa se detiene lo que suena y se reanuda al volver; un sonido de la
## interfaz pedido durante la pausa sí suena.
func test_pause_stops_playing_sounds_and_resume_restores_them() -> void:
	var music: AudioStreamPlayer = AudioDirector._music
	var effect: AudioStreamPlayer3D = AudioDirector._players_3d[0]
	var stream := AudioStreamGenerator.new()
	music.stream = stream
	effect.stream = stream
	music.play()
	effect.play()
	# El sonido 3D arranca en el siguiente paso de física.
	await wait_physics_frames(2)
	assert_true(effect.playing)
	EventBus.paused_changed.emit(true)
	assert_true(music.stream_paused, "la música se detiene")
	assert_true(effect.stream_paused, "los efectos se detienen")
	var ui_player: AudioStreamPlayer = AudioDirector._players_2d[AudioDirector._next_2d]
	ui_player.stream_paused = true
	AudioDirector._paused_2d.append(ui_player)
	var was_silent: bool = AudioDirector._silent
	AudioDirector._silent = false
	AudioDirector.play("pickup")
	AudioDirector._silent = was_silent
	assert_false(ui_player.stream_paused, "un sonido nuevo durante la pausa suena")
	EventBus.paused_changed.emit(false)
	assert_false(music.stream_paused, "la música vuelve")
	assert_false(effect.stream_paused, "los efectos vuelven")
	assert_eq(AudioDirector._paused_2d.size(), 0)
	assert_eq(AudioDirector._paused_3d.size(), 0)
	music.stop()
	effect.stop()
	ui_player.stop()
	music.stream = null
	effect.stream = null

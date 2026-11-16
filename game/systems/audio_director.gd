extends Node
## Director de audio: aplica los volúmenes de los ajustes a los canales (buses) y reproduce
## los sonidos de assets/audio (tools/blender/audio.py). Los sonidos con variantes (paso_0,
## paso_1…) se alternan. Hay un grupo de reproductores con posición (3D) y otro sin posición,
## que se reutilizan: nunca se crean nodos al reproducir. El ambiente cambia con el piso y la
## música con la situación (tensión, jefe, espera del rescate), con fundidos.
## Los avisos importantes siguen teniendo subtítulo (el juego se completa sin sonido).
## Los canales Music, SFX y Ambience están definidos en res://default_bus_layout.tres y no se
## crean por código: en la web, los canales añadidos al arrancar no llegan a la cadena de
## reproducción del navegador y todo sonaba en silencio.

## Canal -> clave del ajuste de volumen.
const BUSES: Dictionary = {
	"Master": "volume_master",
	"Music": "volume_music",
	"SFX": "volume_sfx",
	"Ambience": "volume_ambience",
}
const SOUND_LIST: String = "res://assets/audio/sounds.json"
const AUDIO_FOLDER: String = "res://assets/audio/"
const POOL_3D: int = 14
const POOL_2D: int = 8
## Distancia a la que un sonido con posición deja de oírse.
const MAX_DISTANCE: float = 28.0
const FADE_SECONDS: float = 1.5
## Volumen base (dB) de cada grupo, para que convivan sin que uno tape a los demás.
const GROUP_DB: Dictionary = {
	"steps": -14.0,
	"combat": -4.0,
	"world": -6.0,
	"enemies": -6.0,
	"items": -10.0,
	"ui": -12.0,
	"ambience": -12.0,
	"music": -15.0,
}
## Aviso (con subtítulo) -> sonido.
const CUE_SOUNDS: Dictionary = {
	"cue_glass_break": "hit_glass",
	"cue_object_fall": "hit_soft",
	"cue_shelf_break": "hit_plank",
	"cue_gate_open": "door_open",
	"cue_panel_short": "zap",
	"cue_power_down": "power_down",
	"cue_power_up": "power_up",
	"cue_listener_alert": "voice_listener",
	"cue_growl": "voice_walker",
	"cue_horde": "voice_walker",
	"cue_boss_roar": "voice_boss",
	"cue_boss_charge": "voice_boss",
	"cue_boss_stunned": "zap",
	"cue_boss_suit_breaks": "hit_metal",
	"cue_boss_down": "voice_boss",
	"cue_lure": "hit_glass",
	"cue_toxic_cloud": "voice_stalker",
}
## Piso -> bucle de ambiente.
const FLOOR_AMBIENCE: Dictionary = {
	"ground_floor": "amb_ground",
	"level_1": "amb_level_1",
	"level_2": "amb_level_2",
	"rooftop": "amb_rooftop",
}
## Superficie del suelo -> sonido de paso.
const STEP_SOUNDS: Dictionary = {
	"wood_floor": "step_wood",
	"diamond_plate": "step_metal",
	"corrugated": "step_metal",
}

var _paths: Dictionary = {}
var _variants: Dictionary = {}
var _turn: Dictionary = {}
var _streams: Dictionary = {}
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _next_3d: int = 0
var _next_2d: int = 0
var _ambience: AudioStreamPlayer = null
var _music: AudioStreamPlayer = null
var _geiger: AudioStreamPlayer = null
var _ambience_id: String = ""
var _music_id: String = ""
var _boss_level: int = 0
var _ray: PhysicsRayQueryParameters3D = null
## Sin ventana (bot, tests) no se reproduce nada: el controlador de audio ficticio no suelta las
## reproducciones y quedarían recursos vivos al salir.
var _silent: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			push_error("falta el canal de audio %s en default_bus_layout.tres" % bus_name)
	apply_volumes()
	_load_list()
	for i: int in POOL_3D:
		var player := AudioStreamPlayer3D.new()
		player.bus = "SFX"
		player.max_distance = MAX_DISTANCE
		player.unit_size = 4.0
		add_child(player)
		_players_3d.append(player)
	for i: int in POOL_2D:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players_2d.append(player)
	_ambience = _loop_player("Ambience")
	_music = _loop_player("Music")
	_geiger = _loop_player("SFX")
	_ray = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, Rules.LAYER_WORLD)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.sound_cue.connect(_on_sound_cue)
	EventBus.enemy_hit.connect(_on_enemy_hit)
	EventBus.surface_hit.connect(_on_surface_hit)
	EventBus.debris.connect(func(origin: Vector3) -> void: play_at("hit_plank", origin))
	EventBus.floor_changed.connect(_on_floor_changed)
	EventBus.boss_proximity.connect(_on_boss_proximity)
	EventBus.rescue_changed.connect(_refresh_music)
	EventBus.crafting_changed.connect(func(_active: bool) -> void: play("bag"))


## Aplica los volúmenes (0 a 1, lineal) de los ajustes a cada canal; 0 silencia el canal.
func apply_volumes() -> void:
	for bus_name: String in BUSES:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			continue
		var setting: String = BUSES[bus_name]
		var level := clampf(Settings.get_float(setting), 0.0, 1.0)
		AudioServer.set_bus_mute(index, level <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))


## Si existe un sonido (o un grupo de variantes) con ese id.
func has_sound(sound_id: String) -> bool:
	return _paths.has(sound_id) or _variants.has(sound_id)


## Si el audio está desactivado (juego sin ventana).
func is_silent() -> bool:
	return _silent


## Sonido sin posición (interfaz, el propio jugador). Devuelve false si no existe.
func play(sound_id: String, volume_db: float = 0.0) -> bool:
	var stream := _stream_for(sound_id)
	if stream == null:
		return false
	if _silent:
		return true
	var player := _players_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _players_2d.size()
	player.stream = stream
	player.volume_db = _group_db(sound_id) + volume_db
	player.play()
	return true


## Sonido en un punto del mundo (se oye más o menos según la distancia y la dirección).
func play_at(sound_id: String, origin: Vector3, volume_db: float = 0.0) -> bool:
	var stream := _stream_for(sound_id)
	if stream == null:
		return false
	if _silent:
		return true
	var player := _players_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _players_3d.size()
	player.stream = stream
	player.volume_db = _group_db(sound_id) + volume_db
	player.global_position = origin
	player.play()
	return true


## Paso del jugador: el sonido depende de la superficie que pisa.
func footstep(body: Node3D, loud: bool) -> void:
	play(_step_sound_under(body), 4.0 if loud else 0.0)


## Sonido de golpe según el arma cuerpo a cuerpo (madera, metal, cuchillo).
func melee_impact(weapon_id: String, origin: Vector3) -> void:
	var sound := "hit_metal"
	if weapon_id.begins_with("bat"):
		sound = "hit_wood"
	elif weapon_id == "knife":
		sound = "knife_slice"
	elif weapon_id == "extinguisher":
		sound = "hit_metal"
	play_at(sound, origin)


## Voz de un enemigo según su modelo (caminante, oyente, policía, acechador, El Técnico).
func enemy_voice(model_id: String, origin: Vector3) -> void:
	var voice := "voice_" + ("boss" if model_id == "technician" else model_id)
	play_at(voice, origin, -2.0)


func _step_sound_under(body: Node3D) -> String:
	if body == null or not body.is_inside_tree():
		return "step_concrete"
	_ray.from = body.global_position + Vector3.UP * 0.3
	_ray.to = body.global_position + Vector3.DOWN * 0.6
	var hit := body.get_world_3d().direct_space_state.intersect_ray(_ray)
	var collider := hit.get("collider") as Node
	if collider == null:
		return "step_concrete"
	var section := collider.get_parent() as FloorSection
	if section == null or section.floor_data == null:
		return "step_concrete"
	for room: RoomData in section.floor_data.rooms:
		if room.id == collider.name:
			return STEP_SOUNDS.get(room.floor_surface, "step_concrete")
	return "step_concrete"


func _on_sound_cue(cue_key: String, origin: Vector3) -> void:
	var sound: String = CUE_SOUNDS.get(cue_key, "")
	if not sound.is_empty():
		play_at(sound, origin)


func _on_enemy_hit(point: Vector3, _direction: Vector3, _is_bullet: bool) -> void:
	play_at("hit_flesh", point, -3.0)


func _on_surface_hit(point: Vector3, _normal: Vector3) -> void:
	play_at("hit_soft", point, -6.0)


func _on_floor_changed(floor_id: String) -> void:
	var ambience: String = FLOOR_AMBIENCE.get(floor_id, "amb_ground")
	if ambience != _ambience_id:
		_ambience_id = ambience
		_crossfade(_ambience, ambience)
	_refresh_music()


## El crepitar del contador Geiger sube al acercarse el jefe (0 = no se oye).
func _on_boss_proximity(level: int) -> void:
	_boss_level = level
	if _silent:
		return
	if level <= 0:
		_geiger.stop()
	else:
		if not _geiger.playing:
			_geiger.stream = loop_stream("geiger_loop")
			_geiger.play()
		_geiger.volume_db = _group_db("geiger_loop") - 12.0 + 4.0 * float(level)
	_refresh_music()


## Música según la situación: el jefe cerca, la espera del rescate o la tensión de fondo.
func _refresh_music() -> void:
	var wanted := "music_tension"
	if _boss_level >= 2:
		wanted = "music_boss"
	elif GameState.rescue != null and GameState.rescue.state == RescueClock.STATE_WAITING:
		wanted = "music_rescue"
	if wanted != _music_id:
		_music_id = wanted
		_crossfade(_music, wanted)


func _crossfade(player: AudioStreamPlayer, sound_id: String) -> void:
	var stream := loop_stream(sound_id)
	if stream == null or _silent:
		return
	var target := _group_db(sound_id)
	var tween := create_tween()
	if player.playing:
		tween.tween_property(player, "volume_db", -40.0, FADE_SECONDS * 0.5)
	tween.tween_callback(
		func() -> void:
			player.stream = stream
			player.volume_db = -40.0
			player.play()
	)
	tween.tween_property(player, "volume_db", target, FADE_SECONDS)


func _loop_player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player


## Lista de sonidos: id -> ruta; los ids terminados en _N se agrupan como variantes del id base.
func _load_list() -> void:
	var text := FileAccess.get_file_as_string(SOUND_LIST)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var listing: Dictionary = parsed
	var keys := listing.keys()
	keys.sort()
	for key: Variant in keys:
		var sound_id: String = key
		var relative: String = listing[key]
		_paths[sound_id] = AUDIO_FOLDER + relative
		var cut := sound_id.rfind("_")
		if cut > 0 and sound_id.substr(cut + 1).is_valid_int():
			var base := sound_id.substr(0, cut)
			if not _variants.has(base):
				_variants[base] = []
			(_variants[base] as Array).append(sound_id)


func _stream_for(sound_id: String) -> AudioStream:
	var chosen := sound_id
	if _variants.has(sound_id):
		var options: Array = _variants[sound_id]
		var turn: int = _turn.get(sound_id, 0)
		var pick: String = options[turn % options.size()]
		chosen = pick
		_turn[sound_id] = turn + 1
	if not _paths.has(chosen):
		return null
	if not _streams.has(chosen):
		var path: String = _paths[chosen]
		_streams[chosen] = load(path)
	return _streams[chosen]


## Bucle: la misma muestra con repetición hacia delante de principio a fin.
func loop_stream(sound_id: String) -> AudioStream:
	var stream := _stream_for(sound_id)
	var wav := stream as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	return stream


func _group_db(sound_id: String) -> float:
	var path: String = _paths.get(sound_id, "")
	if path.is_empty() and _variants.has(sound_id):
		path = _paths.get((_variants[sound_id] as Array)[0], "")
	var group := path.trim_prefix(AUDIO_FOLDER).get_slice("/", 0)
	return GROUP_DB.get(group, -8.0)


func _on_settings_changed(key: String) -> void:
	if key.begins_with("volume_"):
		apply_volumes()


## Al cerrar se sueltan los sonidos cargados (si no, quedan recursos vivos al salir).
func _exit_tree() -> void:
	for player: AudioStreamPlayer3D in _players_3d:
		player.stop()
		player.stream = null
	for player: AudioStreamPlayer in [_ambience, _music, _geiger] + _players_2d:
		player.stop()
		player.stream = null
	_streams.clear()

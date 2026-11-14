extends Node
## Director de audio: crea los canales (buses) del juego bajo «Master» y aplica el volumen de
## cada uno desde los ajustes. Todavía no hay sonidos (llegan en el Hito 3): los avisos de
## sonido se muestran con subtítulos e indicadores, así que el juego se completa sin audio.

## Canal -> clave del ajuste de volumen.
const BUSES: Dictionary = {
	"Master": "volume_master",
	"Music": "volume_music",
	"SFX": "volume_sfx",
	"Ambience": "volume_ambience",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	apply_volumes()
	EventBus.settings_changed.connect(_on_settings_changed)


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


func _on_settings_changed(key: String) -> void:
	if key.begins_with("volume_"):
		apply_volumes()

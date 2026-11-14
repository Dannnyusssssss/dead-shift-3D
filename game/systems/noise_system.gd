extends Node
## Sistema de ruido: recibe los ruidos del juego y los publica como eventos. Los enemigos que
## oyen (sensibilidad mayor que 0) se suscriben a noise_emitted; el indicador de ruido de la
## interfaz escucha player_noise.

## Último ruido emitido (para las pruebas).
var last_level: int = -1
var last_origin: Vector3 = Vector3.ZERO


## Emite un ruido. Los niveles inválidos o silenciosos no se publican. from_player indica que
## lo hizo el jugador (pasos, disparos, golpes, combinar).
func emit_noise(origin: Vector3, level: int, from_player: bool = false) -> void:
	if NoiseModel.radius_for(level) <= 0.0:
		return
	last_level = level
	last_origin = origin
	EventBus.noise_emitted.emit(origin, level)
	if from_player:
		EventBus.player_noise.emit(level)

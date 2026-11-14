extends Node
## Sistema de ruido: recibe los ruidos del juego y los publica como eventos. En la planta
## baja ningún enemigo los usa todavía; los oyentes del nivel 1 se suscribirán aquí.

## Último ruido emitido (para el indicador visual y las pruebas).
var last_level: int = -1
var last_origin: Vector3 = Vector3.ZERO


## Emite un ruido. Los niveles inválidos o silenciosos no se publican.
func emit_noise(origin: Vector3, level: int) -> void:
	if NoiseModel.radius_for(level) <= 0.0:
		return
	last_level = level
	last_origin = origin
	EventBus.noise_emitted.emit(origin, level)

class_name RescueClock
extends RefCounted
## Reloj del rescate. El jugador llama al helicóptero cuando quiere (con el teléfono armado):
## empieza la cuenta de llegada; al llegar espera en la azotea un tiempo limitado y se va. Si el
## jugador está en el helipuerto mientras espera, sube (rescate). Si se va sin él, el rescate se
## pierde. El tiempo se inyecta con tick(): no lee ningún reloj del sistema.

const STATE_IDLE: int = 0
const STATE_INBOUND: int = 1
const STATE_WAITING: int = 2
const STATE_DEPARTED: int = 3
const STATE_BOARDED: int = 4

## Lo que pasó en un tick.
const EVENT_NONE: int = 0
const EVENT_ARRIVED: int = 1
const EVENT_DEPARTED: int = 2
const EVENT_BOARDED: int = 3

var state: int = STATE_IDLE
## Segundos que quedan de la etapa actual (llegada o espera).
var time_left: float = 0.0

var _arrival_time: float = Rules.HELICOPTER_ARRIVAL_TIME
var _wait_time: float = Rules.HELICOPTER_WAIT_TIME


func _init(
	arrival_time: float = Rules.HELICOPTER_ARRIVAL_TIME,
	wait_time: float = Rules.HELICOPTER_WAIT_TIME
) -> void:
	_arrival_time = maxf(arrival_time, 0.0)
	_wait_time = maxf(wait_time, 0.0)


## Llama al helicóptero. Solo se puede una vez. Devuelve verdadero si se hizo la llamada.
func call_helicopter() -> bool:
	if state != STATE_IDLE:
		return false
	state = STATE_INBOUND
	time_left = _arrival_time
	return true


## Avanza el reloj. on_helipad indica si el jugador está en el helipuerto de la azotea.
func tick(delta: float, on_helipad: bool) -> int:
	var step := maxf(delta, 0.0)
	match state:
		STATE_INBOUND:
			time_left = maxf(time_left - step, 0.0)
			if time_left <= 0.0:
				state = STATE_WAITING
				time_left = _wait_time
				return EVENT_ARRIVED
		STATE_WAITING:
			if on_helipad:
				state = STATE_BOARDED
				time_left = 0.0
				return EVENT_BOARDED
			time_left = maxf(time_left - step, 0.0)
			if time_left <= 0.0:
				state = STATE_DEPARTED
				return EVENT_DEPARTED
	return EVENT_NONE


func is_called() -> bool:
	return state != STATE_IDLE


func is_finished() -> bool:
	return state == STATE_DEPARTED or state == STATE_BOARDED


## Datos para el guardado.
func to_data() -> Dictionary:
	return {"state": state, "time_left": time_left}


## Restaura desde datos ya validados. Un estado intermedio inválido vuelve a «sin llamar».
func load_data(state_value: int, seconds: float) -> void:
	if state_value < STATE_IDLE or state_value > STATE_BOARDED:
		state = STATE_IDLE
		time_left = 0.0
		return
	state = state_value
	var limit := _arrival_time if state == STATE_INBOUND else _wait_time
	time_left = clampf(seconds, 0.0, limit) if state <= STATE_WAITING else 0.0

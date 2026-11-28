class_name QualityGovernor
extends RefCounted
## Decide cuándo bajar sola la calidad gráfica: si durante WINDOW segundos de juego la media de
## fotogramas por segundo queda por debajo de MIN_FPS. Tras empezar, cambiar de piso, cambiar
## la calidad o quitar la pausa espera GRACE segundos, para que las cargas no cuenten. Un
## fotograma suelto muy largo cuenta como mucho MAX_DELTA (un tirón no decide solo). Nunca sube.

const WINDOW: float = 8.0
const GRACE: float = 6.0
const MIN_FPS: float = 35.0
const MAX_DELTA: float = 0.25

var _grace: float = GRACE
var _time: float = 0.0
var _frames: int = 0


## Vuelve a esperar el margen y empieza una medición nueva.
func reset() -> void:
	_grace = GRACE
	_time = 0.0
	_frames = 0


## Suma un fotograma de «delta» segundos. Devuelve verdadero si hay que bajar un nivel; en ese
## caso vuelve a empezar con el margen.
func tick(delta: float) -> bool:
	if _grace > 0.0:
		_grace -= delta
		return false
	_time += clampf(delta, 0.0, MAX_DELTA)
	_frames += 1
	if _time < WINDOW:
		return false
	var fps := float(_frames) / _time
	_time = 0.0
	_frames = 0
	if fps < MIN_FPS:
		reset()
		return true
	return false

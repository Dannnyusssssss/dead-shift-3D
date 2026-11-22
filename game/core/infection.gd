class_name Infection
extends RefCounted
## Infección por mordida, sin azar: cada golpe que hace daño llena la exposición (0 a 1, se ve
## en la interfaz); al llenarse empieza una cuenta regresiva que, al llegar a cero, convierte al
## guardia. Sin golpes, la exposición baja sola despacio. Los antibióticos suman tiempo a la
## cuenta; Neutrax la cura y deja la exposición a cero.

## Margen para dar por llena la exposición (sumas de decimales).
const FULL_EPSILON: float = 0.0001

var infected: bool = false
## Segundos que quedan antes de la conversión.
var time_left: float = 0.0
## Exposición acumulada (0 a 1) mientras no hay infección.
var exposure: float = 0.0
## Segundos desde el último golpe (la exposición no baja justo después de uno).
var _since_hit: float = 0.0


## Suma la exposición de un golpe. Devuelve verdadero si contagia ahora (no si ya lo estaba).
func add_exposure(amount: float) -> bool:
	if infected or amount <= 0.0:
		return false
	exposure = minf(exposure + amount, 1.0)
	_since_hit = 0.0
	if exposure < 1.0 - FULL_EPSILON:
		return false
	exposure = 0.0
	infected = true
	time_left = Rules.INFECTION_TIME
	return true


## Golpes de esta exposición que faltan para infectarse (al menos 1; 0 si ya hay infección).
func hits_left(amount: float) -> int:
	if infected:
		return 0
	if amount <= 0.0:
		return -1
	return maxi(ceili((1.0 - exposure - FULL_EPSILON) / amount), 1)


## Avanza la cuenta (o baja la exposición si no hay infección). Devuelve verdadero en el
## momento en que la cuenta llega a cero (conversión).
func tick(delta: float) -> bool:
	var step := maxf(delta, 0.0)
	if not infected:
		_since_hit += step
		if _since_hit > Rules.EXPOSURE_DECAY_DELAY:
			exposure = maxf(exposure - Rules.EXPOSURE_DECAY_PER_SECOND * step, 0.0)
		return false
	if time_left <= 0.0:
		return false
	time_left = maxf(time_left - step, 0.0)
	return time_left <= 0.0


func is_converted() -> bool:
	return infected and time_left <= 0.0


## Antibióticos: suman tiempo a la cuenta sin pasar de la cuenta inicial. Devuelve los segundos
## ganados (0 si no hay infección o la cuenta ya está completa).
func add_time(seconds: float) -> float:
	if not infected or is_converted():
		return 0.0
	var before := time_left
	time_left = minf(time_left + maxf(seconds, 0.0), Rules.INFECTION_TIME)
	return time_left - before


## Verdadero si unos antibióticos ahora sumarían algo.
func can_add_time() -> bool:
	return infected and not is_converted() and time_left < Rules.INFECTION_TIME - 0.5


## Neutrax: cura la infección. Solo sirve si hay infección.
func cure() -> bool:
	if not infected or is_converted():
		return false
	infected = false
	time_left = 0.0
	exposure = 0.0
	return true

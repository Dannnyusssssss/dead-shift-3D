class_name Infection
extends RefCounted
## Infección por mordida: una cuenta regresiva que, al llegar a cero, convierte al guardia.
## Los antibióticos suman tiempo a la cuenta; Neutrax la cura. El azar se inyecta.

var infected: bool = false
## Segundos que quedan antes de la conversión.
var time_left: float = 0.0


## Tira el azar de una mordida. Devuelve verdadero si contagia ahora (no si ya lo estaba).
func try_infect(chance: float, rng: RandomNumberGenerator) -> bool:
	if infected or chance <= 0.0:
		return false
	if rng.randf() >= clampf(chance, 0.0, 1.0):
		return false
	infected = true
	time_left = Rules.INFECTION_TIME
	return true


## Avanza la cuenta. Devuelve verdadero en el momento en que llega a cero (conversión).
func tick(delta: float) -> bool:
	if not infected or time_left <= 0.0:
		return false
	time_left = maxf(time_left - maxf(delta, 0.0), 0.0)
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
	return true

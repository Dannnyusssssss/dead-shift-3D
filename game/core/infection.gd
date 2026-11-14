class_name Infection
extends RefCounted
## Infección por mordida: una cuenta regresiva que, al llegar a cero, convierte al guardia.
## Los antibióticos frenan la cuenta un tiempo; Neutrax la cura. El azar se inyecta.

var infected: bool = false
## Segundos que quedan antes de la conversión (a ritmo normal).
var time_left: float = 0.0
## Segundos que quedan del efecto de los antibióticos.
var slowed_left: float = 0.0


## Tira el azar de una mordida. Devuelve verdadero si contagia ahora (no si ya lo estaba).
func try_infect(chance: float, rng: RandomNumberGenerator) -> bool:
	if infected or chance <= 0.0:
		return false
	if rng.randf() >= clampf(chance, 0.0, 1.0):
		return false
	infected = true
	time_left = Rules.INFECTION_TIME
	slowed_left = 0.0
	return true


## Ritmo actual de la cuenta (1 normal, menor con antibióticos).
func rate() -> float:
	return Rules.ANTIBIOTIC_RATE if slowed_left > 0.0 else 1.0


func is_slowed() -> bool:
	return infected and slowed_left > 0.0


## Avanza la cuenta. Devuelve verdadero en el momento en que llega a cero (conversión).
func tick(delta: float) -> bool:
	if not infected or time_left <= 0.0:
		return false
	var step := maxf(delta, 0.0)
	time_left = maxf(time_left - step * rate(), 0.0)
	slowed_left = maxf(slowed_left - step, 0.0)
	return time_left <= 0.0


func is_converted() -> bool:
	return infected and time_left <= 0.0


## Antibióticos: frenan la cuenta durante un tiempo. Solo sirven si hay infección.
func slow() -> bool:
	if not infected or is_converted():
		return false
	slowed_left = Rules.ANTIBIOTIC_DURATION
	return true


## Neutrax: cura la infección. Solo sirve si hay infección.
func cure() -> bool:
	if not infected or is_converted():
		return false
	infected = false
	time_left = 0.0
	slowed_left = 0.0
	return true

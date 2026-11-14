class_name RunStats
extends RefCounted
## Desenlaces y estadísticas de la partida, con la nota final (letra) calculada a partir del
## tiempo, el daño recibido, las armas rotas, los objetos creados y las balas que sobran.
## Lógica pura: Game le pasa los números al terminar.

const OUTCOME_RESCUED: int = 0
const OUTCOME_LOST: int = 1
const OUTCOME_DEAD: int = 2
const OUTCOME_CONVERTED: int = 3

## Letras de la nota, de mejor a peor, y puntos mínimos de cada una.
const GRADES: Array[String] = ["S", "A", "B", "C", "D"]
const GRADE_THRESHOLDS: Array[int] = [85, 70, 55, 40, 0]
## Tiempos de referencia (segundos): con el primero o menos, todos los puntos de tiempo.
const TIME_BEST: float = 1200.0
const TIME_WORST: float = 3600.0
## Daño recibido con el que ya no quedan puntos de daño.
const DAMAGE_WORST: float = 400.0

var outcome: int = OUTCOME_DEAD
var seconds: float = 0.0
var damage_taken: float = 0.0
var weapons_broken: int = 0
var items_crafted: int = 0
var ammo_left: int = 0
var kills: int = 0


## Puntos de 0 a 100. Solo el rescate da nota completa; los demás desenlaces no puntúan tiempo.
func score() -> int:
	var points := 0.0
	if outcome == OUTCOME_RESCUED:
		var span := TIME_WORST - TIME_BEST
		points += 30.0 * clampf((TIME_WORST - seconds) / span, 0.0, 1.0)
	points += 25.0 * clampf(1.0 - damage_taken / DAMAGE_WORST, 0.0, 1.0)
	points += maxf(10.0 - 2.0 * float(weapons_broken), 0.0)
	points += minf(3.0 * float(items_crafted), 15.0)
	points += minf(float(ammo_left) * 0.5, 20.0)
	return clampi(roundi(points), 0, 100)


## Letra de la nota.
func grade() -> String:
	var points := score()
	for index: int in GRADES.size():
		if points >= GRADE_THRESHOLDS[index]:
			return GRADES[index]
	return GRADES[GRADES.size() - 1]


## Índice de la letra (0 = la mejor) para comparar marcas.
static func grade_rank(letter: String) -> int:
	var index := GRADES.find(letter)
	return index if index >= 0 else GRADES.size()


## Reúne los números de la partida en curso.
static func from_state(state: PlayerState, run_outcome: int, elapsed: float) -> RunStats:
	var stats := RunStats.new()
	stats.outcome = run_outcome
	stats.seconds = maxf(elapsed, 0.0)
	stats.damage_taken = state.damage_taken
	stats.weapons_broken = state.weapons_broken
	stats.items_crafted = state.items_crafted
	stats.ammo_left = state.ammo_left()
	stats.kills = state.kills
	return stats

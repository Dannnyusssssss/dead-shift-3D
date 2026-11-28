class_name GoreBudget
extends RefCounted
## Topes de los efectos de impacto por calidad y qué efecto toca. Sin nodos: ImpactEffects lo
## usa para no pasarse nunca del tope (las manchas más viejas se reciclan) y para cambiar la
## sangre por polvo con «Reducir sangre».

const KIND_BLOOD: int = 0
const KIND_DUST: int = 1
const KIND_SPARKS: int = 2
const KIND_DEBRIS: int = 3

## Partículas vivas a la vez y manchas en el suelo y las paredes, por calidad (Mínima, Baja,
## Media, Alta).
const MAX_PARTICLES: Array[int] = [12, 24, 48, 96]
const MAX_STAINS: Array[int] = [8, 16, 40, 80]
## Partículas por impacto (bala, golpe, muerte, escombros) antes del tope.
const BURST_BULLET: int = 6
const BURST_MELEE: int = 9
const BURST_DEATH: int = 14
const BURST_DEBRIS: int = 10

var quality: int = 2
var reduce_gore: bool = false
var _next_stain: int = 0
var _live_particles: int = 0


func _init(quality_level: int = 2, gore_reduced: bool = false) -> void:
	quality = clampi(quality_level, 0, MAX_STAINS.size() - 1)
	reduce_gore = gore_reduced


func max_particles() -> int:
	return MAX_PARTICLES[quality]


func max_stains() -> int:
	return MAX_STAINS[quality]


## Efecto de un golpe a un enemigo: sangre, o polvo con «Reducir sangre».
func flesh_kind() -> int:
	return KIND_DUST if reduce_gore else KIND_BLOOD


## Si un golpe a un enemigo deja mancha (con «Reducir sangre», nunca).
func leaves_stain() -> bool:
	return not reduce_gore


## Cuántas partículas se pueden lanzar ahora de las que se piden (sin pasar del tope).
func reserve_particles(wanted: int) -> int:
	var granted := clampi(max_particles() - _live_particles, 0, maxi(wanted, 0))
	_live_particles += granted
	return granted


## Una partícula terminó su vida.
func release_particle() -> void:
	_live_particles = maxi(_live_particles - 1, 0)


func live_particles() -> int:
	return _live_particles


## Hueco para una mancha nueva: va dando la vuelta, así la más vieja es la que se recicla.
func next_stain_slot() -> int:
	var slot := _next_stain
	_next_stain = (_next_stain + 1) % max_stains()
	return slot

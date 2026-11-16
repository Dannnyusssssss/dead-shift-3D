class_name Objectives
extends RefCounted
## Objetivo actual de la partida a partir del estado (sin escenas): qué falta para el rescate,
## en orden. Devuelve una clave de texto y sus valores para el cuaderno y el HUD.


## Objetivo principal: {"key": String, "args": Array}. Mientras el jugador no sabe que tiene que
## armar un teléfono (no leyó la nota del técnico ni encontró ninguna pieza), el objetivo es
## general: buscar la forma de salir.
static func current(
	state: PlayerState, rescue: RescueClock, roof_open: bool, knows_phone: bool = true
) -> Dictionary:
	match rescue.state:
		RescueClock.STATE_DEPARTED:
			return _make("objective_lost")
		RescueClock.STATE_WAITING:
			return _make("objective_waiting", [clock(rescue.time_left)])
		RescueClock.STATE_INBOUND:
			return _make("objective_inbound", [clock(rescue.time_left)])
	var keys := state.keys
	if keys.phone_assembled:
		if not roof_open and not keys.has("roof_key"):
			return _make("objective_roof_key")
		return _make("objective_call")
	if keys.can_assemble_phone():
		return _make("objective_assemble")
	if not knows_phone:
		return _make("objective_explore")
	return _make("objective_find_parts", [keys.phone_parts_count(), Rules.PHONE_PARTS.size()])


## Aviso secundario (infección), o {} si no hay.
static func warning(state: PlayerState) -> Dictionary:
	if state.infection.infected and not state.infection.is_converted():
		return _make("objective_infected")
	return {}


## Segundos como m:ss.
static func clock(seconds: float) -> String:
	var whole := maxi(ceili(seconds), 0)
	return "%d:%02d" % [whole / 60, whole % 60]


static func _make(key: String, args: Array = []) -> Dictionary:
	return {"key": key, "args": args}

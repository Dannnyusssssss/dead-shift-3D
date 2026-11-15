class_name QuickHeal
extends RefCounted
## Curación rápida (sin abrir la mochila): elige qué cura usar según lo que hace falta.
## Primero vendas si falta salud; si hay infección, antibióticos mientras sumen tiempo y, en
## último lugar, Neutrax (hay muy pocas dosis).

## Motivos para no curarse.
const NOTHING_NEEDED: String = "nothing_needed"
const NOTHING_TO_USE: String = "nothing_to_use"


## Casilla a usar, o -1 si no hay ninguna útil ahora.
static func choose(state: PlayerState) -> int:
	if state.health < Rules.PLAYER_MAX_HEALTH:
		var bandage := _slot_with_effect(state, ItemData.EFFECT_HEAL)
		if bandage >= 0:
			return bandage
	if state.infection.infected:
		if state.infection.can_add_time():
			var antibiotics := _slot_with_effect(state, ItemData.EFFECT_DELAY_INFECTION)
			if antibiotics >= 0:
				return antibiotics
		return _slot_with_effect(state, ItemData.EFFECT_CURE_INFECTION)
	return -1


## Por qué no hay nada que usar: no hace falta curarse o falta la cura.
static func reason(state: PlayerState) -> String:
	var hurt := state.health < Rules.PLAYER_MAX_HEALTH
	if not hurt and not state.infection.infected:
		return NOTHING_NEEDED
	return NOTHING_TO_USE


static func _slot_with_effect(state: PlayerState, effect: int) -> int:
	for index: int in state.inventory.capacity():
		var stack := state.inventory.get_slot(index)
		if stack != null and stack.item.use_effect == effect:
			return index
	return -1

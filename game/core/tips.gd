class_name Tips
extends RefCounted
## Consejos de primera vez: cada uno sale una sola vez por partida (queda anotado como marca del
## mundo «tip_<id>», que viaja con el guardado). Lógica pura; qué evento dispara cada consejo lo
## decide la interfaz (TipBanner).

const PREFIX: String = "tip_"
const DAMAGE: String = "damage"
const BAG: String = "bag"
const THROW: String = "throw"
const WEAR: String = "wear"
const INFECTION: String = "infection"
const MAP: String = "map"
const DARK: String = "dark"
const PHONE: String = "phone"
const EXPOSURE: String = "exposure"
const ALL: Array[String] = [DAMAGE, EXPOSURE, BAG, THROW, WEAR, INFECTION, MAP, DARK, PHONE]


## Verdadero (y lo anota) si el consejo todavía no salió en esta partida.
static func take(world: WorldState, tip_id: String) -> bool:
	if world == null or not ALL.has(tip_id) or world.has_flag(PREFIX + tip_id):
		return false
	world.set_flag(PREFIX + tip_id)
	return true


## Clave del texto del consejo.
static func text_key(tip_id: String) -> String:
	return PREFIX + tip_id

class_name SaveSchema
extends RefCounted
## Límites del guardado de partida (versión 1). Lo que exceda se ajusta o se descarta
## en boundary/validation.gd.

const MAX_FLOOR: int = 3
const MAX_INFECTION_SECONDS: float = 3600.0
const MAX_RESCUE_SECONDS: float = 7200.0
const MAX_INVENTORY_ENTRIES: int = 64
const MAX_SLOT_INDEX: int = 63
const MAX_STACK_COUNT: int = 999
const MAX_LOADED_AMMO: int = 999
const MAX_PHONE_PIECES: int = 8
const MAX_SHORTCUTS: int = 16
const MAX_KILLED: int = 256
const MAX_STAT_TIME: float = 360000.0
const MAX_STAT_DAMAGE: float = 1000000.0
const MAX_STAT_COUNT: int = 99999

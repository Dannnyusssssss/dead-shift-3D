class_name SaveSchema
extends RefCounted
## Límites del guardado de partida (versión 2). Lo que exceda se ajusta o se descarta en
## boundary/save_validation.gd.

## Pisos en el orden del guardado de la versión 1 (que los guardaba por número).
const V1_FLOORS: Array[String] = ["ground_floor", "level_1", "level_2", "rooftop"]

const MAX_KEY_ITEMS: int = 16
const MAX_FLAGS: int = 32
const MAX_KILLED: int = 256
const MAX_CONTAINERS: int = 128
const MAX_CONTAINER_ENTRIES: int = 16
const MAX_DROPS: int = 64
## Coordenada máxima (en metros) de un objeto en el suelo.
const MAX_COORDINATE: float = 500.0
const MAX_STAT_TIME: float = 360000.0
const MAX_STAT_DAMAGE: float = 1000000.0
const MAX_STAT_COUNT: int = 99999

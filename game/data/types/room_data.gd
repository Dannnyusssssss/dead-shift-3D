class_name RoomData
extends Resource
## Una sala de un piso: rectángulo en el plano, puertas, escaparate y botín.
## El pasillo central, las tiendas y la sala de seguridad son salas.

## Lados (bits) para open_sides.
const OPEN_NORTH: int = 1
const OPEN_SOUTH: int = 2
const OPEN_WEST: int = 4
const OPEN_EAST: int = 8

@export var id: String = ""
@export var name_key: String = ""
## Esquina (x, z) y tamaño (ancho en x, fondo en z), en metros.
@export var rect: Rect2 = Rect2(0.0, 0.0, 8.0, 8.0)
@export var height: float = 4.7
@export var floor_color: Color = Color(0.45, 0.45, 0.45)
@export var wall_color: Color = Color(0.6, 0.6, 0.6)
## Superficies con textura (ids de Surfaces.IDS); vacío = la de por defecto de Surfaces.
@export var floor_surface: String = ""
@export var wall_surface: String = ""
@export var ceiling_surface: String = ""
@export var doors: Array[DoorSpec] = []
## Lado con escaparate de cristal (-1 = ninguno).
@export var storefront_side: int = -1
@export var loot: Array[LootSpot] = []
## Zona segura (sala de seguridad).
@export var safe_zone: bool = false
## Luz del techo (energía; 0 = sin luz) y cuántas luces se reparten a lo largo de la sala.
@export var light_energy: float = 1.0
@export var light_count: int = 1
## Exterior (azotea): sin techo; las paredes son un pretil bajo.
@export var outdoor: bool = false
## Lados sin pared (bits OPEN_*): el pasillo central lo cierran las fachadas de las tiendas.
@export var open_sides: int = 0
## Falso para salas que se apoyan en el suelo de otra (la caseta de la azotea).
@export var has_floor: bool = true
## Persiana metálica sobre la puerta principal (0 = subida, 1 = bajada hasta el suelo).
@export var shutter: float = 0.0


## Tienda cerrada: tiene persiana (a medias o bajada). No se puede entrar: bajo la persiana hay
## una puerta cerrada y detrás del escaparate un fondo; no lleva botín ni enemigos dentro.
func is_closed() -> bool:
	return shutter > 0.0

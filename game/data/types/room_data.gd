class_name RoomData
extends Resource
## Una sala de un piso: rectángulo en el plano, puertas, escaparate y botín.
## El pasillo, las tiendas y la sala de seguridad son salas.

@export var id: String = ""
@export var name_key: String = ""
## Esquina (x, z) y tamaño (ancho en x, fondo en z), en metros.
@export var rect: Rect2 = Rect2(0.0, 0.0, 8.0, 8.0)
@export var height: float = 3.5
@export var floor_color: Color = Color(0.45, 0.45, 0.45)
@export var wall_color: Color = Color(0.6, 0.6, 0.6)
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

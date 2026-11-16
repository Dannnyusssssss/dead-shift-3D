class_name Surfaces
extends RefCounted
## Superficies con textura del edificio: capa de la textura por capas
## (assets/generated/textures/surfaces_albedo.png, generada por tools/blender/surfaces.py) y
## metros que ocupa cada repetición. El orden coincide con surfaces.json (lo comprueba un test).

const IDS: Array[String] = [
	"plaster",
	"concrete_light",
	"concrete_dark",
	"tiles_marble",
	"tiles_checker",
	"wood_floor",
	"ceiling_tiles",
	"corrugated",
	"diamond_plate",
	"rust",
	"asphalt",
]
## Metros de suelo o pared que cubre una repetición de cada capa (mismo orden que IDS).
const TILE_METERS: Array[float] = [2.5, 3.0, 3.0, 2.4, 2.4, 2.0, 2.4, 1.5, 1.2, 2.0, 4.0]
## Capa reservada para «sin textura»: solo el color del vértice (decorado, piezas grises).
const PLAIN: int = 15
## Capa emisiva: brilla con el color del vértice (paneles de luz, carteles de emergencia).
const EMISSIVE: int = 14
## Número máximo de capas que entiende el shader (la capa se codifica en el alfa en dieciseisavos).
const MAX_LAYERS: int = 16

## Superficies por defecto cuando una sala no indica la suya.
const DEFAULT_FLOOR: String = "concrete_dark"
const DEFAULT_WALL: String = "plaster"
const DEFAULT_CEILING: String = "ceiling_tiles"
const DEFAULT_OUTDOOR_FLOOR: String = "asphalt"


## Capa de una superficie, o PLAIN si el id no existe.
static func layer_of(id: String) -> int:
	var index := IDS.find(id)
	return index if index >= 0 else PLAIN


## Tamaños de repetición para el shader (16 valores; las capas sin textura usan 1).
static func tile_table() -> PackedFloat32Array:
	var table := PackedFloat32Array()
	table.resize(MAX_LAYERS)
	table.fill(1.0)
	for i: int in TILE_METERS.size():
		table[i] = TILE_METERS[i]
	return table


## Color de vértice para una superficie con textura a partir del color de la sala: casi blanco
## (la textura da el aspecto), con el matiz de la sala y su claridad, sin pasar de 1.
static func texture_tint(room_color: Color) -> Color:
	var luminance := maxf(room_color.get_luminance(), 0.01)
	var brightness := clampf(luminance / 0.55, 0.55, 1.0)
	var hue := Color(
		minf(room_color.r / luminance, 1.0),
		minf(room_color.g / luminance, 1.0),
		minf(room_color.b / luminance, 1.0)
	)
	var tinted := Color.WHITE.lerp(hue, 0.3)
	return Color(tinted.r * brightness, tinted.g * brightness, tinted.b * brightness)

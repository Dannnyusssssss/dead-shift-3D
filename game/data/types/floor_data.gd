class_name FloorData
extends Resource
## Un piso del centro comercial: salas (pasillo, tiendas, zona segura), huecos en el forjado
## (atrio, escaleras), escaleras que suben, enemigos, rejas, accesorios y descansillos con
## nombre. Las coordenadas son del piso: el edificio lo coloca a la altura de su índice.

@export var id: String = ""
@export var name_key: String = ""
## Orden en el edificio (0 = planta baja); fija la altura del piso.
@export var level_index: int = 0
@export var rooms: Array[RoomData] = []
## Huecos del suelo de este piso (x, z, ancho, fondo): sin forjado ni techo del piso de abajo.
@export var holes: Array[Rect2] = []
@export var ramps: Array[RampSpec] = []
@export var enemies: Array[EnemySpawn] = []
@export var player_spawn: Vector3 = Vector3.ZERO
## Giro inicial del jugador en grados.
@export var player_yaw_deg: float = 0.0
@export var exits: Array[FloorExit] = []
@export var gates: Array[GateSpec] = []
@export var props: Array[PropSpec] = []
## Helipuerto (solo la azotea): centro y radio donde el jugador sube al helicóptero.
@export var has_helipad: bool = false
@export var helipad_position: Vector3 = Vector3.ZERO
@export var helipad_radius: float = 3.0
## Puntos por donde llegan las oleadas (solo la azotea).
@export var wave_spawn_points: PackedVector3Array = PackedVector3Array()
@export var ambient_color: Color = Color(0.25, 0.27, 0.32)
@export var ambient_energy: float = 0.6


## Altura del suelo del piso en el edificio.
func elevation() -> float:
	return float(level_index) * Rules.FLOOR_HEIGHT


## Salida con ese identificador, o null.
func find_exit(exit_id: String) -> FloorExit:
	for floor_exit: FloorExit in exits:
		if floor_exit.id == exit_id:
			return floor_exit
	return null


## Descansillo más cercano a un punto (en coordenadas del piso), o null si no hay.
func nearest_exit(point: Vector3) -> FloorExit:
	var best: FloorExit = null
	var best_distance := INF
	var flat := Vector2(point.x, point.z)
	for floor_exit: FloorExit in exits:
		var distance := flat.distance_to(Vector2(floor_exit.arrival.x, floor_exit.arrival.z))
		if distance < best_distance:
			best_distance = distance
			best = floor_exit
	return best

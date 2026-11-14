class_name FloorData
extends Resource
## Un piso del centro comercial: salas (pasillo, tiendas, zona segura), enemigos, rejas,
## salidas a otros pisos y punto de inicio de una partida nueva. El nivel se construye a partir
## de estos datos con el kit modular.

@export var id: String = ""
@export var name_key: String = ""
@export var rooms: Array[RoomData] = []
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
## Puntos por donde llegan las oleadas si se pierde el rescate (solo la azotea).
@export var wave_spawn_points: PackedVector3Array = PackedVector3Array()
@export var ambient_color: Color = Color(0.25, 0.27, 0.32)
@export var ambient_energy: float = 0.6


## Salida con ese identificador, o null.
func find_exit(exit_id: String) -> FloorExit:
	for floor_exit: FloorExit in exits:
		if floor_exit.id == exit_id:
			return floor_exit
	return null

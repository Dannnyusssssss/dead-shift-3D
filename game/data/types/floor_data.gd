class_name FloorData
extends Resource
## Un piso del centro comercial: salas (pasillo, tiendas, zona segura), enemigos, punto de
## inicio y meta. El nivel se construye a partir de estos datos con el kit modular.

@export var id: String = ""
@export var name_key: String = ""
@export var rooms: Array[RoomData] = []
@export var enemies: Array[EnemySpawn] = []
@export var player_spawn: Vector3 = Vector3.ZERO
## Giro inicial del jugador en grados.
@export var player_yaw_deg: float = 0.0
## Meta del piso (salida a la escalera).
@export var goal: Vector3 = Vector3.ZERO
@export var goal_size: Vector3 = Vector3(2.0, 2.5, 2.0)
@export var ambient_color: Color = Color(0.25, 0.27, 0.32)
@export var ambient_energy: float = 0.6

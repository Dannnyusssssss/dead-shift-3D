class_name FloorExit
extends Resource
## Salida de un piso a otro (escalera, escalera de servicio). Al entrar en su zona el juego
## carga el piso de destino y coloca al jugador en el punto de llegada de la salida enlazada.

@export var id: String = ""
## Centro de la zona (a ras de suelo) y su tamaño.
@export var position: Vector3 = Vector3.ZERO
@export var size: Vector3 = Vector3(2.0, 2.5, 2.0)
## Piso de destino y salida de ese piso donde aparece el jugador.
@export var target_floor: String = ""
@export var target_exit: String = ""
## Dónde queda el jugador al llegar por esta salida (fuera de su zona) y hacia dónde mira.
@export var arrival: Vector3 = Vector3.ZERO
@export var arrival_yaw_deg: float = 0.0
## Rótulo sobre la salida.
@export var label_key: String = ""
## Marca del mundo que debe estar puesta para usarla ("" = siempre abierta) y aviso si no.
@export var requires_flag: String = ""
@export var locked_message_key: String = ""

class_name FloorExit
extends Resource
## Descansillo con nombre de un piso (pie o cabeza de una escalera). Sirve de punto de
## reaparición al continuar una partida guardada tras cambiar de piso, y de rótulo en el mapa.

@export var id: String = ""
## Dónde se dibuja en el mapa (a ras de suelo, en coordenadas del piso).
@export var position: Vector3 = Vector3.ZERO
## Dónde queda el jugador al reaparecer aquí y hacia dónde mira (grados).
@export var arrival: Vector3 = Vector3.ZERO
@export var arrival_yaw_deg: float = 0.0
## Rótulo en el mapa.
@export var label_key: String = ""

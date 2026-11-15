class_name RampSpec
extends Resource
## Escalera o escalera mecánica parada que sube desde el suelo de un piso. El jugador y los
## enemigos la recorren caminando: la colisión es una rampa lisa y los peldaños son solo visuales.

const KIND_STAIRS: int = 0
const KIND_ESCALATOR: int = 1

@export var kind: int = KIND_STAIRS
## Centro del borde de abajo (en coordenadas del piso; y > 0 si nace en un descansillo).
@export var start: Vector3 = Vector3.ZERO
## Hacia dónde sube, en grados (0 = +X, 90 = +Z, 180 = -X, 270 = -Z).
@export var direction_deg: float = 0.0
## Recorrido horizontal, subida y ancho, en metros.
@export var run: float = 8.0
@export var rise: float = 5.0
@export var width: float = 1.8
## Carriles separados por un pasamanos central (escaleras mecánicas dobles).
@export var lanes: int = 1
## Rellena el hueco de debajo hasta el suelo del piso (escaleras que nacen en planta).
@export var fill_below: bool = true


## Vector unitario horizontal hacia donde sube.
func forward() -> Vector3:
	var angle := deg_to_rad(direction_deg)
	return Vector3(cos(angle), 0.0, sin(angle)).snapped(Vector3(0.0001, 0.0001, 0.0001))

class_name SoundDirection
extends RefCounted
## Dirección de un sonido respecto a quien lo oye, como clave de texto para los subtítulos
## («a la izquierda», «detrás»…). Solo cuenta el plano horizontal.

const FRONT: String = "dir_front"
const BACK: String = "dir_back"
const LEFT: String = "dir_left"
const RIGHT: String = "dir_right"
## Grados a cada lado del frente (y de la espalda) que cuentan como delante (o detrás).
const FRONT_HALF_ANGLE: float = 40.0


## Clave de la dirección de origin visto desde un oyente con esa transformación
## (mira hacia -Z, como las cámaras de Godot).
static func key_for(listener: Transform3D, origin: Vector3) -> String:
	var local := listener.affine_inverse() * origin
	return key_for_local(local)


## Clave de la dirección de un punto ya en coordenadas locales del oyente.
static func key_for_local(local: Vector3) -> String:
	if Vector2(local.x, local.z).length() < 0.01:
		return FRONT
	var angle := rad_to_deg(atan2(local.x, -local.z))
	if absf(angle) <= FRONT_HALF_ANGLE:
		return FRONT
	if absf(angle) >= 180.0 - FRONT_HALF_ANGLE:
		return BACK
	return RIGHT if angle > 0.0 else LEFT

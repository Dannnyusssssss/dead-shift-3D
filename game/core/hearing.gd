class_name Hearing
extends RefCounted
## Lo que recuerda haber oído un enemigo: el ruido que más le importa ahora mismo.
## Un ruido nuevo solo reemplaza al actual si se percibe al menos igual de fuerte; el recuerdo
## se debilita con el tiempo, así que un ruido más débil pero reciente termina ganando.
## Lógica pura: el enemigo le pasa su posición y cuántas paredes hay en medio.

## Sensibilidad (multiplica el radio de los ruidos). 0 = no reacciona al ruido.
var sensitivity: float = 0.0
var has_target: bool = false
## Punto del ruido que investiga.
var target: Vector3 = Vector3.ZERO
## Intensidad recordada del ruido actual (se debilita con el tiempo).
var strength: float = 0.0


func _init(hearing_sensitivity: float) -> void:
	sensitivity = maxf(hearing_sensitivity, 0.0)


func is_deaf() -> bool:
	return sensitivity <= 0.0


## Procesa un ruido. Devuelve verdadero si pasa a ser el ruido que investiga.
func hear(listener: Vector3, origin: Vector3, level: int, walls: int = 0) -> bool:
	if is_deaf() or not NoiseModel.can_hear(listener, origin, level, sensitivity, walls):
		return false
	var perceived := NoiseModel.loudness(listener, origin, level, sensitivity, walls)
	if has_target and perceived < strength:
		return false
	has_target = true
	target = origin
	strength = perceived
	return true


## Debilita el recuerdo del ruido actual.
func tick(delta: float) -> void:
	if has_target:
		strength = maxf(strength - Rules.NOISE_FORGET_RATE * maxf(delta, 0.0), 0.0)


## Olvida el ruido (terminó de investigar o vio al jugador).
func clear() -> void:
	has_target = false
	strength = 0.0

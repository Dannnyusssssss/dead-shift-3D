class_name ArmReach
extends RefCounted
## Alcance de un brazo de dos huesos (hombro, codo y muñeca), sin nodos: dado dónde tiene que
## quedar la muñeca, devuelve el giro del hombro y la flexión del codo que la llevan ahí.
##
## Convención de los brazos en primera persona (PlayerArms): el brazo y el antebrazo apuntan a
## -Z de su hueso; el codo dobla sobre su X y con ángulo positivo el antebrazo sube hacia la +Y
## del brazo. El giro del hombro se da en ángulos de Euler en el orden por defecto de Godot.

## Margen para no estirar del todo ni plegar del todo el brazo (el codo no salta).
const REACH_MARGIN: float = 0.002


## Giro del hombro (Euler) y flexión del codo para llevar la muñeca a «target». «pole» es hacia
## dónde apunta el codo (por ejemplo, abajo y afuera). Si el punto queda fuera del alcance, el
## brazo se estira hacia él lo más posible.
static func solve(
	shoulder: Vector3, target: Vector3, pole: Vector3, upper: float, fore: float
) -> Dictionary:
	var to_target := target - shoulder
	var direction := to_target.normalized() if to_target.length() > 0.0001 else Vector3.FORWARD
	var reach := clampf(
		to_target.length(), absf(upper - fore) + REACH_MARGIN, upper + fore - REACH_MARGIN
	)
	# Ángulo en el codo (interior) y en el hombro, por la ley de los cosenos.
	var cos_elbow := clampf(
		(upper * upper + fore * fore - reach * reach) / (2.0 * upper * fore), -1.0, 1.0
	)
	var cos_shoulder := clampf(
		(upper * upper + reach * reach - fore * fore) / (2.0 * upper * reach), -1.0, 1.0
	)
	var bend := PI - acos(cos_elbow)
	var shoulder_angle := acos(cos_shoulder)
	# El codo sale hacia el lado del «pole», en el plano que forma con la dirección al punto.
	var side := pole - direction * pole.dot(direction)
	if side.length() < 0.0001:
		side = Vector3.DOWN - direction * Vector3.DOWN.dot(direction)
	side = side.normalized()
	var upper_dir := direction * cos(shoulder_angle) + side * sin(shoulder_angle)
	var elbow := shoulder + upper_dir * upper
	var wrist := shoulder + direction * reach
	var fore_dir := (wrist - elbow).normalized()
	# Base del hombro: su -Z por el brazo y su +Y hacia donde sube el antebrazo.
	var z := -upper_dir
	var y := fore_dir - upper_dir * fore_dir.dot(upper_dir)
	if y.length() < 0.0001:
		y = side.cross(upper_dir)
	y = y.normalized()
	var x := y.cross(z).normalized()
	var basis := Basis(x, y, z).orthonormalized()
	return {
		"shoulder": basis.get_euler(),
		"basis": basis,
		"elbow": bend,
		"elbow_point": elbow,
		"wrist_point": wrist,
	}


## Dónde queda la muñeca con un giro de hombro y una flexión de codo (la cuenta al revés, para
## comprobar).
static func wrist_of(
	shoulder: Vector3, rotation: Vector3, bend: float, upper: float, fore: float
) -> Vector3:
	var shoulder_basis := Basis.from_euler(rotation)
	var elbow := shoulder + shoulder_basis * Vector3(0.0, 0.0, -upper)
	var elbow_basis := shoulder_basis * Basis(Vector3.RIGHT, bend)
	return elbow + elbow_basis * Vector3(0.0, 0.0, -fore)


## Base que gira los ejes locales «local_axis» y «local_side» de la mano hasta «axis» y «side»
## (orientación de la muñeca con el objeto apuntando a donde se pide).
static func aim(local_axis: Vector3, local_side: Vector3, axis: Vector3, side: Vector3) -> Basis:
	return _frame(axis, side) * _frame(local_axis, local_side).inverse()


static func _frame(axis: Vector3, side: Vector3) -> Basis:
	var a := axis.normalized()
	var s := (side - a * side.dot(a)).normalized()
	return Basis(s, a, s.cross(a))

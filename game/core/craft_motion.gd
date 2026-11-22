class_name CraftMotion
extends RefCounted
## Movimiento de las manos al combinar, sin nodos: dónde va cada puño, hacia dónde apunta el
## objeto que sostiene y hacia dónde mira su dorso, en coordenadas de la cámara (x a la derecha,
## y arriba, -z delante) y en el instante t del ciclo (0 a 1, en bucle). Las dos manos se juntan
## abajo y al centro, delante de la cámara, para que se vea qué se hace:
##   - wrap (cinta o trapos): la izquierda sujeta y la derecha da dos vueltas alrededor.
##   - join (clavos): la izquierda sujeta y la derecha sube y golpea dos veces.
##   - assemble (lo demás): la derecha acerca su pieza, la encaja girándola y se retira.

const WRAP: String = "craft_wrap"
const JOIN: String = "craft_join"
const ASSEMBLE: String = "craft_assemble"
## Punto de trabajo: donde se juntan los objetos.
const WORK: Vector3 = Vector3(0.0, -0.09, -0.27)
## Puño izquierdo (sujeta) y derecho en reposo respecto al punto de trabajo.
const LEFT_OFFSET: Vector3 = Vector3(-0.08, -0.01, 0.0)
const RIGHT_OFFSET: Vector3 = Vector3(0.09, 0.0, 0.0)
## Objetos: el de la izquierda apunta hacia el centro y a la derecha; el de la derecha, al revés.
const LEFT_AXIS: Vector3 = Vector3(1.0, 0.2, -0.35)
const RIGHT_AXIS: Vector3 = Vector3(-1.0, 0.3, -0.35)
const LEFT_SIDE: Vector3 = Vector3(-0.5, 0.85, 0.0)
const RIGHT_SIDE: Vector3 = Vector3(0.5, 0.85, 0.0)
## Envolver: radio de las vueltas y vueltas por ciclo.
const WRAP_RADIUS: float = 0.065
const WRAP_TURNS: float = 2.0
## Clavos: golpes por ciclo, altura a la que sube la mano y hundimiento de la izquierda al golpe.
const JOIN_HITS: float = 2.0
const JOIN_LIFT: float = 0.09
const JOIN_DIP: float = 0.01
## Ensamblar: distancia de la que parte la pieza y giro al encajarla (radianes).
const ASSEMBLE_FAR: float = 0.17
const ASSEMBLE_NEAR: float = 0.06
const ASSEMBLE_TWIST: float = 0.5

## Amplitud del movimiento con «Reducir movimiento» (las manos se juntan igual, pero las vueltas,
## los golpes y el encaje son mucho más cortos).
const REDUCED: float = 0.35


## Pose de las dos manos: {"left"/"right": {"point", "axis", "side"}}. «amount» escala la
## amplitud del movimiento (1 normal, REDUCED con «Reducir movimiento»).
static func pose(kind: String, t: float, amount: float = 1.0) -> Dictionary:
	var time := fposmod(t, 1.0)
	var left := _hand(WORK + LEFT_OFFSET, LEFT_AXIS, LEFT_SIDE)
	var right := _hand(WORK + RIGHT_OFFSET, RIGHT_AXIS, RIGHT_SIDE)
	match kind:
		WRAP:
			var angle := TAU * WRAP_TURNS * time
			var around := Vector3(0.0, cos(angle), sin(angle)) * WRAP_RADIUS * amount
			right = _hand(WORK + Vector3(0.02, 0.0, 0.0) + around, RIGHT_AXIS, RIGHT_SIDE)
		JOIN:
			var lift := join_lift(time) * amount
			right = _hand(
				WORK + Vector3(0.04, 0.02 + lift, -0.01), Vector3(-0.4, -1.0, -0.2), RIGHT_SIDE
			)
			var dip := (
				JOIN_DIP * amount * (1.0 - clampf(lift / (JOIN_LIFT * amount * 0.25), 0.0, 1.0))
			)
			left = _hand(WORK + LEFT_OFFSET + Vector3(0.0, -dip, 0.0), LEFT_AXIS, LEFT_SIDE)
		_:
			var reach := lerpf(ASSEMBLE_NEAR, assemble_reach(time), amount)
			var twist := assemble_twist(time) * amount
			var axis := RIGHT_AXIS.normalized()
			right = _hand(
				WORK + Vector3(reach, 0.0, 0.0), RIGHT_AXIS, RIGHT_SIDE.rotated(axis, twist)
			)
	return {"left": left, "right": right}


## Altura de la mano que golpea (0 = sobre la pieza): sube despacio y baja de golpe.
static func join_lift(time: float) -> float:
	var phase := fposmod(time * JOIN_HITS, 1.0)
	if phase < 0.6:
		return JOIN_LIFT * smoothstep(0.0, 0.6, phase)
	if phase < 0.72:
		return JOIN_LIFT * (1.0 - (phase - 0.6) / 0.12)
	return 0.0


## Distancia de la pieza derecha al punto de trabajo: se acerca, encaja y se retira.
static func assemble_reach(time: float) -> float:
	if time < 0.4:
		return lerpf(ASSEMBLE_FAR, ASSEMBLE_NEAR, smoothstep(0.0, 0.4, time))
	if time < 0.7:
		return ASSEMBLE_NEAR
	return lerpf(ASSEMBLE_NEAR, ASSEMBLE_FAR, smoothstep(0.7, 1.0, time))


## Giro de la pieza mientras encaja (ida y vuelta).
static func assemble_twist(time: float) -> float:
	if time < 0.4 or time > 0.7:
		return 0.0
	return ASSEMBLE_TWIST * sin((time - 0.4) / 0.3 * TAU)


static func _hand(point: Vector3, axis: Vector3, side: Vector3) -> Dictionary:
	return {"point": point, "axis": axis.normalized(), "side": side.normalized()}

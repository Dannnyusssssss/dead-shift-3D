class_name ArmAnimations
extends RefCounted
## Animaciones de los brazos en primera persona como datos: fotogramas clave con la pose de
## cada brazo y un muestreador puro (sin nodos; lo aplica PlayerArms).
##
## Una pose de un brazo son 10 números: desplazamiento del hombro sobre su sitio (x, y, z, en
## metros), giro del hombro (x, y, z, radianes), flexión del codo (radianes, positivo = sube el
## antebrazo) y giro de la muñeca (x, y, z). Una pose completa son 20: brazo derecho y después
## el izquierdo. El tiempo de los fotogramas va de 0 a 1 (la duración real la da quien la usa).

const ARM_VALUES: int = 10
const POSE_VALUES: int = 20
# Índices dentro de un brazo, para escribir las poses con nombre.
const OX := 0
const OY := 1
const OZ := 2
const SX := 3
const SY := 4
const SZ := 5
const ELBOW := 6
const WX := 7
const WY := 8
const WZ := 9

## Reposo: el derecho sostiene el arma delante; el izquierdo, más bajo y a un lado.
const REST_RIGHT: Array[float] = [0.0, 0.0, 0.0, -0.55, 0.2, 0.0, 0.95, -0.4, 0.0, 0.0]
const REST_LEFT: Array[float] = [0.0, -0.06, 0.04, -0.8, 0.25, 0.0, 1.0, -0.25, 0.0, 0.0]

## Duración de referencia (segundos) de las animaciones en bucle y de las que no la reciben.
const LOOP_SECONDS: Dictionary = {"idle": 3.2, "walk": 0.9}
const SHOOT_SECONDS: float = 0.22
const SHOTGUN_SHOOT_SECONDS: float = 0.6
const THROW_SECONDS: float = 0.5
## Materiales que trabajan sobre la otra pieza al combinar (van en la mano derecha, la que se
## mueve; la izquierda sujeta la pieza quieta).
const CRAFT_TOOLS: Array[String] = ["tape", "rag", "nails"]

static var _table: Dictionary = {}


## Nombres de todas las animaciones.
static func names() -> Array:
	return _keys().keys()


static func is_loop(anim: String) -> bool:
	return LOOP_SECONDS.has(anim) or anim.begins_with("craft_")


## Pose de reposo completa.
static func rest() -> PackedFloat32Array:
	var out := PackedFloat32Array(REST_RIGHT)
	out.append_array(PackedFloat32Array(REST_LEFT))
	return out


## Pose de una animación en el instante t (0 a 1; en bucle se da la vuelta, si no se limita).
## Entre fotogramas se suaviza (entrada y salida lentas). Una animación desconocida da el reposo.
static func sample(anim: String, t: float) -> PackedFloat32Array:
	var keys: Array = _keys().get(anim, [])
	if keys.is_empty():
		return rest()
	var time := fposmod(t, 1.0) if is_loop(anim) else clampf(t, 0.0, 1.0)
	for i: int in range(1, keys.size()):
		var next: Array = keys[i]
		var next_time: float = next[0]
		if time <= next_time:
			var prev: Array = keys[i - 1]
			var prev_time: float = prev[0]
			var prev_pose: PackedFloat32Array = prev[1]
			var next_pose: PackedFloat32Array = next[1]
			var span := maxf(next_time - prev_time, 0.0001)
			var k := smoothstep(0.0, 1.0, (time - prev_time) / span)
			return _mix(prev_pose, next_pose, k)
	var last: Array = keys[keys.size() - 1]
	var last_pose: PackedFloat32Array = last[1]
	return PackedFloat32Array(last_pose)


## Mezcla lineal de dos poses (para pasar de una animación a otra sin saltos).
static func blend(a: PackedFloat32Array, b: PackedFloat32Array, k: float) -> PackedFloat32Array:
	return _mix(a, b, clampf(k, 0.0, 1.0))


## Acerca una pose al reposo (amount 0 = reposo, 1 = la pose tal cual): «Reducir movimiento».
static func damp(pose: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	return _mix(rest(), pose, clampf(amount, 0.0, 1.0))


## Golpe según el arma: cuchillo apuñala, extintor empuja, las de fuego golpean con la culata,
## el resto barre (bate, tubo).
static func attack_for(weapon_id: String) -> String:
	match weapon_id:
		"knife":
			return "stab"
		"extinguisher":
			return "push"
		"pistol", "shotgun":
			return "bash"
		_:
			return "swing"


## Acciones en las que la mano izquierda trabaja (empujar el extintor, bombear o recargar,
## curarse y combinar). En las demás y en reposo la izquierda baja fuera de la vista: con un arma
## de una mano no se queda flotando delante.
static func uses_left_hand(anim: String) -> bool:
	return (
		anim in ["push", "shoot_shotgun", "reload_pistol", "reload_shotgun"]
		or anim.begins_with("heal_")
		or anim.begins_with("craft_")
	)


static func shoot_for(weapon_id: String) -> String:
	return "shoot_shotgun" if weapon_id == "shotgun" else "shoot_pistol"


static func reload_for(weapon_id: String) -> String:
	return "reload_shotgun" if weapon_id == "shotgun" else "reload_pistol"


## Curarse: venda y venda improvisada se enrollan, el Neutrax se inyecta, el resto se toma.
static func heal_for(item_id: String) -> String:
	match item_id:
		"bandage", "improvised_bandage":
			return "heal_wrap"
		"neutrax":
			return "heal_inject"
		_:
			return "heal_pill"


## Qué sostiene cada mano al combinar: [izquierda, derecha]. El material (cinta, trapos o clavos)
## va en la derecha, que da las vueltas o golpea; la pieza grande, quieta en la izquierda.
static func craft_hands(first_id: String, second_id: String) -> Array[String]:
	if CRAFT_TOOLS.has(first_id) and not CRAFT_TOOLS.has(second_id):
		return [second_id, first_id]
	return [first_id, second_id]


## Combinar: con cinta o trapos se envuelve, con clavos se une a golpes, lo demás se ensambla.
static func craft_for(first_id: String, second_id: String) -> String:
	var ids := [first_id, second_id]
	if ids.has("tape") or ids.has("rag"):
		return "craft_wrap"
	if ids.has("nails"):
		return "craft_join"
	return "craft_assemble"


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(POSE_VALUES)
	for i: int in POSE_VALUES:
		out[i] = lerpf(a[i], b[i], k)
	return out


## Pose a partir del reposo con cambios: diccionarios {índice: valor} para cada brazo.
static func _pose(right: Dictionary, left: Dictionary = {}) -> PackedFloat32Array:
	var out := rest()
	for index: int in right:
		out[index] = right[index]
	for index: int in left:
		out[ARM_VALUES + index] = left[index]
	return out


static func _keys() -> Dictionary:
	if not _table.is_empty():
		return _table
	var r := rest()
	_table = {
		# Respiración: el arma sube y baja muy poco.
		"idle":
		[
			[0.0, r],
			[0.5, _pose({OY: 0.008, SX: -0.53}, {OY: -0.052})],
			[1.0, r],
		],
		# Paso: vaivén lateral y vertical al ritmo de la marcha.
		"walk":
		[
			[0.0, r],
			[0.25, _pose({OX: 0.012, OY: -0.012, SZ: -0.04}, {OX: 0.01, OY: -0.07})],
			[0.5, r],
			[0.75, _pose({OX: -0.012, OY: -0.012, SZ: 0.04}, {OX: -0.01, OY: -0.07})],
			[1.0, r],
		],
		# Bate o tubo: lleva el arma atrás y arriba, barre de derecha a izquierda y vuelve.
		"swing":
		[
			[0.0, r],
			[0.3, _pose({OX: 0.04, OY: 0.06, OZ: 0.05, SX: -0.1, SY: -0.5, SZ: 0.6, ELBOW: 1.4})],
			[
				0.55,
				_pose({OX: -0.12, OY: -0.02, OZ: -0.08, SX: -0.55, SY: 1.0, SZ: -0.7, ELBOW: 0.4})
			],
			[1.0, r],
		],
		# Cuchillo: recoge el brazo y apuñala hacia delante.
		"stab":
		[
			[0.0, r],
			[0.3, _pose({OZ: 0.0, SX: -0.45, ELBOW: 1.25, WX: -0.2})],
			[0.5, _pose({OZ: -0.1, SX: -0.75, SY: 0.1, ELBOW: 0.25, WX: -0.6})],
			[1.0, r],
		],
		# Extintor: las dos manos empujan el cilindro hacia delante.
		"push":
		[
			[0.0, r],
			[0.3, _pose({OZ: 0.05, ELBOW: 1.3}, {OX: 0.08, OY: 0.04, SY: 0.4, ELBOW: 1.3})],
			[
				0.5,
				_pose({OZ: -0.12, ELBOW: 0.3}, {OX: 0.08, OY: 0.04, OZ: -0.12, SY: 0.4, ELBOW: 0.3})
			],
			[1.0, r],
		],
		# Golpe con la culata (pistola o escopeta sin disparar).
		"bash":
		[
			[0.0, r],
			[0.35, _pose({OX: 0.03, SY: -0.3, SZ: 0.3, ELBOW: 1.3, WZ: 0.5})],
			[0.55, _pose({OX: -0.08, OZ: -0.06, SY: 0.6, SZ: -0.3, ELBOW: 0.6, WZ: -0.3})],
			[1.0, r],
		],
		# Pistola: retroceso corto hacia arriba y atrás.
		"shoot_pistol":
		[
			[0.0, r],
			[0.2, _pose({OZ: 0.05, SX: -0.4, WX: -0.05})],
			[1.0, r],
		],
		# Escopeta: retroceso fuerte y la mano izquierda bombea la corredera.
		"shoot_shotgun":
		[
			[0.0, r],
			[0.12, _pose({OZ: 0.09, SX: -0.3, WX: 0.05}, {OZ: 0.06})],
			[0.45, _pose({OZ: 0.02}, {OX: 0.12, OY: 0.06, OZ: 0.06, SY: 0.5, ELBOW: 1.2})],
			[0.7, _pose({}, {OX: 0.12, OY: 0.06, OZ: -0.04, SY: 0.5, ELBOW: 0.9})],
			[1.0, r],
		],
		# Pistola: la baja y gira, la izquierda saca el cargador y mete otro.
		"reload_pistol":
		[
			[0.0, r],
			[0.2, _pose({OY: -0.05, SX: -0.75, WZ: 0.6}, {OX: 0.05, OY: -0.04})],
			[
				0.45,
				_pose({OY: -0.05, SX: -0.75, WZ: 0.6}, {OX: 0.12, OY: -0.06, SY: 0.5, ELBOW: 0.9})
			],
			[
				0.7,
				_pose({OY: -0.05, SX: -0.75, WZ: 0.6}, {OX: 0.13, OY: -0.03, SY: 0.55, ELBOW: 1.2})
			],
			[1.0, r],
		],
		# Escopeta: inclinada, la izquierda mete cartuchos uno a uno.
		"reload_shotgun":
		[
			[0.0, r],
			[0.15, _pose({OY: -0.04, SX: -0.7, WZ: -0.5}, {OX: 0.1, OY: -0.06, SY: 0.5})],
			[
				0.35,
				_pose({OY: -0.04, SX: -0.7, WZ: -0.5}, {OX: 0.13, OY: -0.02, SY: 0.6, ELBOW: 1.2})
			],
			[0.55, _pose({OY: -0.04, SX: -0.7, WZ: -0.5}, {OX: 0.1, OY: -0.06, SY: 0.5})],
			[
				0.8,
				_pose({OY: -0.04, SX: -0.7, WZ: -0.5}, {OX: 0.13, OY: -0.02, SY: 0.6, ELBOW: 1.2})
			],
			[1.0, r],
		],
		# Venda: el antebrazo izquierdo delante y la derecha da vueltas alrededor.
		"heal_wrap":
		[
			[0.0, r],
			[
				0.2,
				_pose(
					{OX: -0.05, OY: -0.05, SY: 0.6, ELBOW: 0.9},
					{OX: 0.1, OY: 0.0, SY: 0.6, ELBOW: 1.05}
				)
			],
			[
				0.45,
				_pose(
					{OX: -0.08, OY: -0.09, SY: 0.7, ELBOW: 1.05, WZ: 1.0},
					{OX: 0.1, OY: 0.0, SY: 0.6, ELBOW: 1.05}
				)
			],
			[
				0.7,
				_pose(
					{OX: -0.05, OY: -0.02, SY: 0.6, ELBOW: 1.0, WZ: -0.5},
					{OX: 0.1, OY: 0.0, SY: 0.6, ELBOW: 1.05}
				)
			],
			[1.0, r],
		],
		# Pastilla o frasco: la izquierda se lleva la cura a la boca.
		"heal_pill":
		[
			[0.0, r],
			[
				0.35,
				_pose(
					{OY: -0.08, SX: -0.8},
					{OX: 0.12, OY: 0.12, OZ: 0.12, SX: 0.1, SY: 0.6, ELBOW: 1.7}
				)
			],
			[
				0.65,
				_pose(
					{OY: -0.08, SX: -0.8},
					{OX: 0.12, OY: 0.12, OZ: 0.12, SX: 0.1, SY: 0.6, ELBOW: 1.7}
				)
			],
			[1.0, r],
		],
		# Neutrax: la izquierda clava el autoinyector hacia abajo.
		"heal_inject":
		[
			[0.0, r],
			[
				0.3,
				_pose(
					{OY: -0.06, SX: -0.8},
					{OX: 0.08, OY: 0.06, SX: -0.3, SY: 0.4, ELBOW: 1.6, WX: 0.6}
				)
			],
			[
				0.5,
				_pose(
					{OY: -0.06, SX: -0.8},
					{OX: 0.08, OY: -0.08, SX: -1.0, SY: 0.4, ELBOW: 0.6, WX: 1.2}
				)
			],
			[1.0, r],
		],
		# Lanzar: el brazo derecho atrás y arriba, y lanza por encima del hombro.
		"throw":
		[
			[0.0, r],
			[0.35, _pose({OY: 0.08, OZ: 0.12, SX: 0.6, SZ: 0.3, ELBOW: 1.8, WX: 0.4})],
			[0.6, _pose({OY: 0.02, OZ: -0.1, SX: -0.9, ELBOW: 0.3, WX: -0.6})],
			[1.0, r],
		],
		# Envolver (cinta o trapos): una mano sujeta y la otra da vueltas.
		"craft_wrap":
		[
			[
				0.0,
				_pose(
					{OX: -0.06, OY: -0.06, SY: 0.5, ELBOW: 1.1},
					{OX: 0.08, OY: -0.02, SY: 0.6, ELBOW: 1.2}
				)
			],
			[
				0.5,
				_pose(
					{OX: -0.09, OY: -0.1, SY: 0.6, ELBOW: 1.3, WZ: 1.2},
					{OX: 0.08, OY: -0.02, SY: 0.6, ELBOW: 1.2}
				)
			],
			[
				1.0,
				_pose(
					{OX: -0.06, OY: -0.06, SY: 0.5, ELBOW: 1.1},
					{OX: 0.08, OY: -0.02, SY: 0.6, ELBOW: 1.2}
				)
			],
		],
		# Unir con clavos: la izquierda sujeta y la derecha golpea de arriba abajo.
		"craft_join":
		[
			[
				0.0,
				_pose(
					{OX: -0.04, OY: 0.02, SX: -0.35, SY: 0.4, ELBOW: 1.15},
					{OX: 0.08, OY: -0.05, SY: 0.6, ELBOW: 1.1}
				)
			],
			[
				0.5,
				_pose(
					{OX: -0.04, OY: -0.06, SX: -0.8, SY: 0.4, ELBOW: 0.9},
					{OX: 0.08, OY: -0.05, SY: 0.6, ELBOW: 1.1}
				)
			],
			[
				1.0,
				_pose(
					{OX: -0.04, OY: 0.02, SX: -0.35, SY: 0.4, ELBOW: 1.15},
					{OX: 0.08, OY: -0.05, SY: 0.6, ELBOW: 1.1}
				)
			],
		],
		# Ensamblar: las dos manos se acercan, encajan y se separan un poco.
		"craft_assemble":
		[
			[
				0.0,
				_pose(
					{OX: -0.05, OY: -0.04, SY: 0.45, ELBOW: 1.2},
					{OX: 0.05, OY: -0.02, SY: 0.45, ELBOW: 1.2}
				)
			],
			[
				0.5,
				_pose(
					{OX: -0.08, OY: -0.05, SY: 0.6, ELBOW: 1.25, WY: 0.4},
					{OX: 0.08, OY: -0.03, SY: 0.6, ELBOW: 1.25, WY: -0.4}
				)
			],
			[
				1.0,
				_pose(
					{OX: -0.05, OY: -0.04, SY: 0.45, ELBOW: 1.2},
					{OX: 0.05, OY: -0.02, SY: 0.45, ELBOW: 1.2}
				)
			],
		],
	}
	return _table

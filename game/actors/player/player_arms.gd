class_name PlayerArms
extends Node3D
## Brazos del guardia en primera persona. Cada brazo es un esqueleto de tres huesos (hombro,
## codo y muñeca) con las piezas de tools/blender/arms.py; las poses salen de ArmAnimations
## (datos) y aquí solo se aplican: reposo y paso en bucle debajo, y encima la acción en curso
## (golpe según el arma, disparo, recarga, curarse, lanzar, combinar). Las armas y objetos son
## los modelos de ItemModels (el arma, en su estado de desgaste). Con «Reducir movimiento» el
## reposo y el paso casi no se mueven.

const ARMS_FOLDER: String = "res://assets/generated/arms/"
## Sitio de cada hombro respecto a la cámara (fuera de la vista; los brazos entran por abajo).
const RIGHT_SHOULDER: Vector3 = Vector3(0.2, -0.24, 0.12)
const LEFT_SHOULDER: Vector3 = Vector3(-0.2, -0.24, 0.12)
## Largo de los huesos (como los modelos) y punto de agarre en la mano.
const UPPER_LENGTH: float = 0.28
const FOREARM_LENGTH: float = 0.26
## Colocación de cada arma en la mano, en coordenadas de la muñeca: su eje de agarre va por el
## hueco del puño y su punto de agarre al centro. La calcula tools/blender/arms.py a partir del
## hueco con el que se construye cada guante (la imprime al exportar). Las de cuerpo a cuerpo y
## los objetos apuntan a -Z desde su origen y salen por el lado del pulgar; pistola y escopeta,
## por su empuñadura.
const HOLD_FRAMES: Dictionary = {
	"melee":
	Transform3D(
		Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.6112, 0.7915), Vector3(0.0, -0.7915, 0.6112)),
		Vector3(-0.034, 0.0, -0.07)
	),
	"pistol":
	Transform3D(
		Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.9946, -0.1037), Vector3(0.0, 0.1037, 0.9946)),
		Vector3(-0.036, 0.0649, -0.0943)
	),
	"shotgun":
	Transform3D(
		Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.9901, 0.14), Vector3(0.0, -0.14, 0.9901)),
		Vector3(-0.036, 0.0759, -0.0991)
	),
}
## Armas de fuego: se sujetan con el puño de empuñadura vertical (índice en el gatillo).
const FIREARMS: Array[String] = ["pistol", "shotgun"]
## Desplazamiento del modelo dentro de su colocación: el extintor se coge por la maneta de
## arriba (el cuerpo cuelga por debajo del puño).
const GRIP_OFFSETS: Dictionary = {
	"extinguisher": Vector3(0.0, -0.1, 0.38),
}
## Tiempo para pasar de una pose a otra al empezar o terminar una acción.
const BLEND_SECONDS: float = 0.12
## Calibración del montaje del brazo derecho según la forma de la mano: desplazamiento del
## hombro, giro fijo que se suma al hombro (x, y, z), al codo y a la muñeca (x). Con el puño de
## verdad el mango sale hacia arriba por el lado del pulgar, así que con un arma de cuerpo a
## cuerpo el hombro sube, el antebrazo va casi horizontal y la muñeca apenas se dobla (unos 40
## grados con la caída del puño): el arma queda hacia delante y arriba. Con las de fuego el arma
## queda donde estaba antes y la muñeca se dobla poco. Calculado con el reposo de ArmAnimations.
const RIGHT_CALIBRATION: Dictionary = {
	"grip":
	{
		"offset": Vector3(-0.007, 0.211, 0.057),
		"shoulder": Vector3(0.113, -0.039, 0.016),
		"elbow": -0.455,
		"wrist": 0.23,
	},
	"pistol":
	{
		"offset": Vector3(0.067, -0.127, 0.025),
		"shoulder": Vector3(0.35, 0.0, 0.0),
		"elbow": 0.0,
		"wrist": -0.25,
	},
	"open":
	{
		"offset": Vector3.ZERO,
		"shoulder": Vector3(0.35, 0.0, 0.0),
		"elbow": 0.0,
		"wrist": -0.35,
	},
}
const LEFT_SHOULDER_BIAS: float = 0.4
const LEFT_WRIST_BIAS: float = -0.25
## Amplitud del reposo y el paso con «Reducir movimiento».
const REDUCED_MOTION: float = 0.2
## Mano izquierda fuera de la vista cuando no trabaja: cuánto baja y se retrasa el hombro, y
## cuánto tarda en entrar o salir (segundos).
## Reflejo en X: la mano izquierda sostiene los objetos como la derecha, al otro lado.
const MIRROR: Transform3D = Transform3D(
	Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3.BACK), Vector3.ZERO
)
const LEFT_AWAY: Vector3 = Vector3(-0.05, -0.5, 0.2)
const LEFT_SHOW_SECONDS: float = 0.15

var _bones: Dictionary = {}
var _weapon_holder: Node3D = null
## Lo que sostiene cada mano al combinar, curarse o lanzar (el arma se guarda mientras tanto).
var _left_hold: Node3D = null
var _right_hold: Node3D = null
var _weapon_id: String = ""
var _base_time: float = 0.0
var _action: String = ""
var _action_time: float = 0.0
var _action_seconds: float = 1.0
## Pose desde la que se mezcla al cambiar de acción, y cuánto falta para terminar la mezcla.
var _from_pose: PackedFloat32Array = ArmAnimations.rest()
var _blend_left: float = 0.0
var _current: PackedFloat32Array = ArmAnimations.rest()
## 1 con la mano izquierda a la vista, 0 fuera de ella (entra y sale poco a poco).
var _left_shown: float = 0.0


func _ready() -> void:
	position = Vector3.ZERO
	_bones["right"] = _make_arm("right", RIGHT_SHOULDER)
	_bones["left"] = _make_arm("left", LEFT_SHOULDER)
	_weapon_holder = _holder("right")
	_right_hold = Node3D.new()
	_holder("right").add_child(_right_hold)
	_left_hold = _holder("left")
	_set_grip("left", "grip")
	_refresh_right_hand()
	_apply(_current)


func _process(delta: float) -> void:
	var speed := 0.0
	var body := owner as CharacterBody3D
	if body != null:
		speed = Vector2(body.velocity.x, body.velocity.z).length()
	var walking := speed > 0.5
	var base_name := "walk" if walking else "idle"
	var loop_seconds: float = ArmAnimations.LOOP_SECONDS[base_name]
	_base_time += delta / loop_seconds * (clampf(speed / 4.0, 0.8, 1.6) if walking else 1.0)
	var target := ArmAnimations.sample(base_name, _base_time)
	if Settings.get_bool("reduce_motion"):
		target = ArmAnimations.damp(target, REDUCED_MOTION)
	if not _action.is_empty():
		_action_time += delta / _action_seconds
		if _action_time >= 1.0 and not ArmAnimations.is_loop(_action):
			_end_action()
		else:
			target = ArmAnimations.sample(_action, _action_time)
	if _blend_left > 0.0:
		_blend_left = maxf(_blend_left - delta, 0.0)
		target = ArmAnimations.blend(target, _from_pose, _blend_left / BLEND_SECONDS)
	_current = target
	var wanted := 1.0 if ArmAnimations.uses_left_hand(_action) else 0.0
	_left_shown = move_toward(_left_shown, wanted, delta / LEFT_SHOW_SECONDS)
	_apply(_current)


## Muestra en la mano el arma dada (o ninguna) con su estado de desgaste.
func show_weapon(stack: ItemStack) -> void:
	for child: Node in _weapon_holder.get_children():
		if child != _right_hold:
			child.queue_free()
	_weapon_id = "" if stack == null else stack.id()
	if stack == null:
		_refresh_right_hand()
		return
	var model := ItemModels.instance(stack.id(), stack.durability.state())
	if model == null:
		model = _fallback_box()
	var offset: Vector3 = GRIP_OFFSETS.get(_weapon_id, Vector3.ZERO)
	model.transform = hold_frame(_weapon_id) * Transform3D(Basis(), offset)
	_weapon_holder.add_child(model)
	_refresh_right_hand()


## Golpe cuerpo a cuerpo según el arma (barrer, apuñalar, empujar o culatazo).
func play_attack(duration: float) -> void:
	_play(ArmAnimations.attack_for(_weapon_id), duration)


func play_shoot() -> void:
	var anim := ArmAnimations.shoot_for(_weapon_id)
	var seconds := (
		ArmAnimations.SHOTGUN_SHOOT_SECONDS
		if anim == "shoot_shotgun"
		else ArmAnimations.SHOOT_SECONDS
	)
	_play(anim, seconds)


func play_reload(duration: float) -> void:
	_play(ArmAnimations.reload_for(_weapon_id), duration)


## Lanzar por encima del hombro el objeto que tiene en la mano derecha.
func play_throw() -> void:
	_play("throw", ArmAnimations.THROW_SECONDS)


## Combinar: cada mano sostiene uno de los objetos y repiten el gesto que toca (envolver, unir o
## ensamblar) hasta que termina.
func start_craft(first_id: String, second_id: String) -> void:
	_hold(_left_hold, first_id)
	_hold(_right_hold, second_id)
	_play(ArmAnimations.craft_for(first_id, second_id), 1.1)


func stop_craft() -> void:
	if not _action.begins_with("craft_"):
		return
	_end_action()
	_release_hands()


## Curarse: la mano izquierda sostiene la cura y hacen el gesto de ese tipo de cura.
func start_heal(item_id: String) -> void:
	_hold(_left_hold, item_id)
	_play(ArmAnimations.heal_for(item_id), 1.6)


func stop_heal() -> void:
	if _action.begins_with("heal_"):
		_end_action()
	_release_hands()


## Pone el objeto que se va a lanzar en la mano derecha (el arma se guarda).
func hold_for_throw(item_id: String) -> void:
	_hold(_right_hold, item_id)


## Vacía las manos y vuelve a mostrar el arma.
func release_hands() -> void:
	_release_hands()


## Acción en curso ("" si solo está en reposo o caminando). Para pruebas y depuración.
func current_action() -> String:
	return _action


## Pone los brazos en un instante de una animación (vista previa y pruebas).
func preview(anim: String, t: float) -> void:
	_action = ""
	_blend_left = 0.0
	_current = ArmAnimations.sample(anim, t)
	_apply(_current)


func _play(anim: String, seconds: float) -> void:
	_from_pose = _current
	_blend_left = BLEND_SECONDS
	_action = anim
	_action_time = 0.0
	_action_seconds = maxf(seconds, 0.05)


func _end_action() -> void:
	_from_pose = _current
	_blend_left = BLEND_SECONDS
	_action = ""
	_action_time = 0.0


## Pone en una mano el modelo de un objeto, cierra esa mano y esconde el arma.
func _hold(holder: Node3D, item_id: String) -> void:
	for child: Node in holder.get_children():
		child.queue_free()
	for child: Node in _weapon_holder.get_children():
		if child != _right_hold and child is Node3D:
			(child as Node3D).visible = false
	var model := ItemModels.instance(item_id)
	if model == null:
		model = _fallback_box()
	holder.add_child(model)
	var frame: Transform3D = HOLD_FRAMES["melee"]
	model.transform = frame if holder != _left_hold else MIRROR * frame * MIRROR
	if holder == _left_hold:
		_set_grip("left", "grip")
	else:
		_set_grip("right", "grip")


func _release_hands() -> void:
	for holder: Node3D in [_left_hold, _right_hold]:
		for child: Node in holder.get_children():
			child.queue_free()
	for child: Node in _weapon_holder.get_children():
		if child is Node3D:
			(child as Node3D).visible = true
	_set_grip("left", "grip")
	_refresh_right_hand()


## Si la mano izquierda está a la vista (para las pruebas): 0 fuera, 1 del todo.
func left_shown() -> float:
	return _left_shown


## Colocación de un arma en la mano derecha (las de fuego por su empuñadura, el resto como un
## mango).
static func hold_frame(weapon_id: String) -> Transform3D:
	if HOLD_FRAMES.has(weapon_id):
		return HOLD_FRAMES[weapon_id]
	return HOLD_FRAMES["melee"]


## Aplica una pose de 20 valores (brazo derecho y después el izquierdo) a los huesos.
func _apply(pose: PackedFloat32Array) -> void:
	for side: String in ["right", "left"]:
		var base := 0 if side == "right" else ArmAnimations.ARM_VALUES
		var bones: Dictionary = _bones[side]
		var shoulder: Node3D = bones["shoulder"]
		var rest_spot: Vector3 = bones["spot"]
		shoulder.position = rest_spot + Vector3(pose[base], pose[base + 1], pose[base + 2])
		if side == "left":
			shoulder.position += LEFT_AWAY * (1.0 - _left_shown)
			shoulder.visible = _left_shown > 0.001
		# El brazo izquierdo es el reflejo del derecho: los giros laterales cambian de signo.
		var mirror := 1.0 if side == "right" else -1.0
		var shoulder_bias := Vector3(LEFT_SHOULDER_BIAS, 0.0, 0.0)
		var elbow_bias := 0.0
		var wrist_bias := LEFT_WRIST_BIAS
		if side == "right":
			var calibration: Dictionary = RIGHT_CALIBRATION[hand_shape("right")]
			shoulder.position += calibration["offset"]
			shoulder_bias = calibration["shoulder"]
			elbow_bias = calibration["elbow"]
			wrist_bias = calibration["wrist"]
		shoulder.rotation = Vector3(
			pose[base + 3] + shoulder_bias.x,
			pose[base + 4] * mirror + shoulder_bias.y,
			pose[base + 5] * mirror + shoulder_bias.z
		)
		(bones["elbow"] as Node3D).rotation = Vector3(pose[base + 6] + elbow_bias, 0.0, 0.0)
		(bones["wrist"] as Node3D).rotation = Vector3(
			pose[base + 7] + wrist_bias, pose[base + 8] * mirror, pose[base + 9] * mirror
		)


func _make_arm(side: String, spot: Vector3) -> Dictionary:
	var shoulder := Node3D.new()
	shoulder.name = side.capitalize() + "Shoulder"
	shoulder.position = spot
	add_child(shoulder)
	_attach(shoulder, ARMS_FOLDER + "upper_arm.glb")
	var elbow := Node3D.new()
	elbow.position = Vector3(0.0, 0.0, -UPPER_LENGTH)
	shoulder.add_child(elbow)
	_attach(elbow, ARMS_FOLDER + "forearm_%s.glb" % side)
	var wrist := Node3D.new()
	wrist.position = Vector3(0.0, 0.0, -FOREARM_LENGTH)
	elbow.add_child(wrist)
	var grip := _attach(wrist, ARMS_FOLDER + "hand_grip_%s.glb" % side)
	var pistol := _attach(wrist, ARMS_FOLDER + "hand_pistol_%s.glb" % side)
	var open := _attach(wrist, ARMS_FOLDER + "hand_open_%s.glb" % side)
	var holder := Node3D.new()
	wrist.add_child(holder)
	return {
		"shoulder": shoulder,
		"spot": spot,
		"elbow": elbow,
		"wrist": wrist,
		"grip": grip,
		"pistol": pistol,
		"open": open,
		"holder": holder,
	}


func _attach(parent: Node3D, path: String) -> Node3D:
	var node := ItemModels.instance_from_path(path)
	if node == null:
		return Node3D.new()
	parent.add_child(node)
	return node


func _holder(side: String) -> Node3D:
	return (_bones[side] as Dictionary)["holder"]


## Forma de la mano: "grip" (puño alrededor de un mango), "pistol" (empuñadura vertical) u
## "open" (abierta). Solo se ve una de las tres.
func _set_grip(side: String, shape: String) -> void:
	var bones: Dictionary = _bones[side]
	for name: String in ["grip", "pistol", "open"]:
		(bones[name] as Node3D).visible = name == shape


## Si la mano que se muestra ahora tiene esa forma (para las pruebas).
func hand_shape(side: String) -> String:
	var bones: Dictionary = _bones[side]
	for name: String in ["grip", "pistol", "open"]:
		if (bones[name] as Node3D).visible:
			return name
	return ""


## La mano derecha según el arma: abierta sin arma, empuñadura con las de fuego y puño con el
## resto.
func _refresh_right_hand() -> void:
	if _weapon_id.is_empty():
		_set_grip("right", "open")
	elif FIREARMS.has(_weapon_id):
		_set_grip("right", "pistol")
	else:
		_set_grip("right", "grip")


## Caja gris de respaldo si un objeto no tuviera modelo.
func _fallback_box() -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.25)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(0.0, 0.0, -0.1)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

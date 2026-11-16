class_name EnemyModel
extends Node3D
## Aspecto de un enemigo: el modelo de tools/blender/enemies.py (cuerpo con esqueleto y color
## de vértice) y sus animaciones según lo que hace (quieto, andar, correr, atacar, aturdido,
## golpe recibido y muerte). Su material propio deja que Enemy tiña el cuerpo (destello suave al
## recibir un golpe, traje roto del jefe). Las piezas que deben seguir el cuerpo (chaleco,
## tanque) se cuelgan de un hueso.

const FOLDER: String = "res://assets/generated/enemies/"
## Velocidad (m/s) a la que la animación de andar se ve a ritmo normal, y a partir de la que
## se usa la de correr.
const WALK_ANIM_SPEED: float = 1.2
const RUN_FROM_SPEED: float = 2.6
const BLEND: float = 0.18

var material: StandardMaterial3D = null

var _player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
## Una animación de una sola vez en curso (ataque, golpe, aturdido, muerte): no la corta el
## bucle de andar hasta que termina.
var _one_shot: String = ""
var _dead: bool = false
var _lean: LeanModifier = null


## Crea el aspecto del enemigo, o null si no hay modelo para ese id.
static func create(model_id: String) -> EnemyModel:
	if model_id.is_empty():
		return null
	return create_from(FOLDER + model_id + ".glb")


## Crea el aspecto desde cualquier modelo con esqueleto (personas de la intro), o null.
static func create_from(path: String) -> EnemyModel:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	var model := EnemyModel.new()
	var root := scene.instantiate()
	# Los modelos (glTF) miran hacia +Z: la punta del pie va por delante del tobillo en +Z. El
	# enemigo mira hacia -Z (look_at), así que el modelo se gira media vuelta; sin el giro los
	# enemigos avanzaban de espaldas.
	(root as Node3D).rotation.y = PI
	model.add_child(root)
	model._setup(root)
	return model


func _setup(root: Node) -> void:
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.roughness = 0.85
	for mesh: MeshInstance3D in _find_meshes(root):
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_player = _find_type(root, "AnimationPlayer") as AnimationPlayer
	_skeleton = _find_type(root, "Skeleton3D") as Skeleton3D
	if _player != null:
		_player.animation_finished.connect(_on_finished)
		for anim_name: String in ["idle", "walk", "run"]:
			if _player.has_animation(anim_name):
				_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_play("idle")


## Elige la animación según el estado del enemigo y su velocidad horizontal.
func update(state: int, speed: float) -> void:
	if _player == null or _dead:
		return
	if state == Enemy.STATE_ATTACK:
		_once("attack")
		return
	if state == Enemy.STATE_STUNNED:
		_once("stun")
		return
	if not _one_shot.is_empty():
		return
	if speed > RUN_FROM_SPEED and _player.has_animation("run"):
		_play("run", speed / 4.0)
	elif speed > 0.2:
		_play("walk", clampf(speed / WALK_ANIM_SPEED, 0.6, 2.0))
	else:
		_play("idle")


## Golpe recibido (en la cabeza si el golpe fue alto).
func play_hit(high: bool) -> void:
	if _player == null or _dead or _one_shot == "attack":
		return
	_one_shot = ""
	_once("hit_head" if high else "hit")


## Reproduce una animación por nombre (escenas): en bucle o una vez, a la velocidad dada.
func play_named(anim_name: String, looped: bool = true, speed: float = 1.0) -> void:
	if _player == null or not _player.has_animation(anim_name):
		return
	_player.get_animation(anim_name).loop_mode = (
		Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	)
	_one_shot = "" if looped else anim_name
	_player.play(anim_name, BLEND)
	_player.speed_scale = speed


## Congela la animación en un instante (segundos): para empezar una escena en una pose.
func hold_pose(anim_name: String, at_seconds: float) -> void:
	if _player == null or not _player.has_animation(anim_name):
		return
	_player.play(anim_name)
	_player.seek(at_seconds, true)
	_player.pause()


func play_death() -> void:
	if _player == null:
		return
	_dead = true
	_one_shot = "death"
	_player.play("death", BLEND)


## Inclina el torso y la cabeza hacia delante (0 erguido, 1 caído sobre una mesa), encima de
## la animación. Sin esqueleto no hace nada.
func set_lean(amount: float) -> void:
	if _skeleton == null:
		return
	if _lean == null:
		_lean = LeanModifier.new()
		_skeleton.add_child(_lean)
	_lean.amount = clampf(amount, 0.0, 1.0)


## Inclinación actual (0 a 1).
func lean() -> float:
	return 0.0 if _lean == null else _lean.amount


## Animación que se está viendo ("" sin animaciones).
func current_animation() -> String:
	return "" if _player == null else _player.current_animation


## Cuelga un nodo de un hueso para que siga la animación, colocado en el punto dado en el
## espacio del enemigo (x a la derecha, y arriba, z hacia su espalda). Debe estar ya en el
## árbol. Sin esqueleto, queda en ese punto sin moverse.
func attach_to_bone(node: Node3D, bone: String, spot: Vector3) -> void:
	var index := -1 if _skeleton == null else _skeleton.find_bone(bone)
	if index < 0:
		node.position = spot
		add_child(node)
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	_skeleton.add_child(attachment)
	attachment.add_child(node)
	var target := global_transform * Transform3D(Basis.IDENTITY, spot)
	var bone_rest := _skeleton.global_transform * _skeleton.get_bone_global_rest(index)
	node.transform = bone_rest.affine_inverse() * target


func _once(anim_name: String) -> void:
	if _one_shot == anim_name or not _player.has_animation(anim_name):
		return
	_one_shot = anim_name
	_player.play(anim_name, BLEND)


func _play(anim_name: String, speed: float = 1.0) -> void:
	if not _player.has_animation(anim_name):
		return
	if _player.current_animation != anim_name:
		_player.play(anim_name, BLEND)
	_player.speed_scale = speed


func _on_finished(anim_name: StringName) -> void:
	if String(anim_name) == _one_shot and not _dead:
		_one_shot = ""
		_player.speed_scale = 1.0


static func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child: Node in node.get_children():
		found.append_array(_find_meshes(child))
	return found


static func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child: Node in node.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null

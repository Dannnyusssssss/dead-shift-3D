class_name Enemy
extends CharacterBody3D
## Máquina de estados común a todos los enemigos: quieto, persiguiendo, atacando, aturdido,
## muerto y, para los que oyen, investigando un ruido y volviendo a su sitio. Lo propio de
## cada tipo vive en su .tres (valores) y en su comportamiento (a dónde ir), registrado en
## EnemyBehaviors. La salud y el chaleco usan la lógica de core.

## Murió (para recordarlo al cambiar de piso).
signal died

const STATE_IDLE: int = 0
const STATE_CHASE: int = 1
const STATE_ATTACK: int = 2
const STATE_STUNNED: int = 3
const STATE_DEAD: int = 4
const STATE_INVESTIGATE: int = 5
const STATE_RETURN: int = 6

const GRAVITY: float = 9.8
## Cada cuánto se comprueba si ve al jugador y se recalcula la ruta (no en cada frame).
const THINK_INTERVAL: float = 0.25
## Segundos sin ver al jugador antes de rendirse.
const LOSE_SIGHT_TIME: float = 6.0
## Parte del ataque antes de que el golpe llegue (permite esquivarlo).
const ATTACK_WINDUP: float = 0.45
const STUN_TIME: float = 1.2
## Tambaleo al recibir un golpe que no lo mata: retrocede un poco y no ataca un instante.
const STAGGER_BULLET: float = 0.18
const STAGGER_MELEE: float = 0.35
const STAGGER_PUSH: float = 2.2
const HEAD_HEIGHT: float = 1.45
const VEST_BOTTOM: float = 0.85
## Segundos que mira alrededor al llegar al punto del ruido.
const INVESTIGATE_LOOK_TIME: float = 3.0
## Giro (radianes por segundo) mientras mira alrededor.
const LOOK_AROUND_SPEED: float = 1.6
## Distancia horizontal a la que se considera que llegó a un punto.
const ARRIVE_DISTANCE: float = 1.2

@export var data: EnemyData = null
## -1 = el azar decide si lleva chaleco; 0 = sin chaleco; 1 = con chaleco.
@export var vest_override: int = -1
## Semilla del azar de este enemigo (botín y chaleco), para poder reproducirlo.
@export var rng_seed: int = 1

var state: int = STATE_IDLE
var health: EnemyHealth = null
var hearing: Hearing = null
## Verdadero si en el último análisis veía al jugador.
var sees_player: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _behavior: EnemyBehavior = null
var _player: Player = null
var _think_timer: float = 0.0
var _unseen_time: float = 0.0
var _attack_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _stun_timer: float = 0.0
var _stagger_timer: float = 0.0
var _stagger_push: Vector3 = Vector3.ZERO
var _sight_query: PhysicsRayQueryParameters3D = null
var _body_material: StandardMaterial3D = null
var _vest_mesh: MeshInstance3D = null
var _home: Vector3 = Vector3.ZERO
var _look_timer: float = 0.0
var _arrived: bool = false
var _noise_query: PhysicsRayQueryParameters3D = null
var _chase_target: Vector3 = Vector3.ZERO

@onready var _agent: NavigationAgent3D = $Agent
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("enemy")
	floor_constant_speed = true
	floor_snap_length = 0.4
	_rng.seed = rng_seed
	health = EnemyHealth.new(data, _rng, _vest_max(), vest_override)
	_behavior = EnemyBehaviors.create(data.behavior)
	_sight_query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, Rules.LAYER_WORLD)
	_noise_query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, Rules.LAYER_WORLD)
	hearing = Hearing.new(data.hearing)
	_home = global_position
	if not hearing.is_deaf():
		EventBus.noise_emitted.connect(_on_noise)
	_build_visual()
	_think_timer = _rng.randf() * THINK_INTERVAL


func _physics_process(delta: float) -> void:
	if state == STATE_DEAD:
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	hearing.tick(delta)
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		velocity.x = _stagger_push.x
		velocity.z = _stagger_push.z
		_stagger_push = _stagger_push.move_toward(Vector3.ZERO, STAGGER_PUSH * delta * 4.0)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = THINK_INTERVAL
		_think()
	match state:
		STATE_CHASE:
			_chase(delta)
		STATE_ATTACK:
			_attack(delta)
		STATE_STUNNED:
			_stun_timer -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			if _stun_timer <= 0.0:
				state = STATE_CHASE
		STATE_INVESTIGATE:
			_investigate(delta)
		STATE_RETURN:
			_return_home()
		_:
			velocity.x = 0.0
			velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()


## Recibe un impacto en un punto del mundo. La altura del impacto decide la zona
## (cabeza, chaleco o cuerpo). Devuelve el daño aplicado.
func take_hit(damage: float, hit_point: Vector3, is_bullet: bool, stuns: bool = false) -> float:
	if state == STATE_DEAD:
		return 0.0
	var applied := health.take_hit(damage, _zone_at(hit_point), is_bullet)
	_refresh_vest_visual()
	_flash_hit()
	if health.is_dead():
		_die()
	else:
		if stuns:
			state = STATE_STUNNED
			_stun_timer = STUN_TIME
		elif state != STATE_CHASE and state != STATE_ATTACK:
			_start_chase()
		_stagger(hit_point, is_bullet)
	return applied


## Retrocede un poco desde el punto del golpe e inclina el cuerpo un instante.
func _stagger(hit_point: Vector3, is_bullet: bool) -> void:
	var away := global_position - hit_point
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -global_basis.z
	_stagger_timer = STAGGER_BULLET if is_bullet else STAGGER_MELEE
	_stagger_push = away * STAGGER_PUSH * (0.5 if is_bullet else 1.0)
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:x", -0.22, 0.07)
	tween.tween_property(_visual, "rotation:x", 0.0, 0.2)


func is_dead() -> bool:
	return state == STATE_DEAD


func _think() -> void:
	_player = _find_player()
	if _player == null or _player.is_dead():
		if state == STATE_CHASE or state == STATE_ATTACK:
			state = STATE_IDLE
		return
	var sees := _can_see_player() or data.relentless
	sees_player = sees
	if sees:
		_unseen_time = 0.0
		if state == STATE_IDLE or state == STATE_INVESTIGATE or state == STATE_RETURN:
			_start_chase()
	elif state == STATE_CHASE:
		_unseen_time += THINK_INTERVAL
		if _unseen_time > LOSE_SIGHT_TIME:
			_lose_player()
	if state == STATE_CHASE:
		_chase_target = _behavior.target_position(self, _player)
		_agent.target_position = _chase_target


## Empieza a perseguir al jugador (y lo anuncia con un subtítulo).
func _start_chase() -> void:
	state = STATE_CHASE
	_unseen_time = 0.0
	hearing.clear()
	EventBus.sound_cue.emit("cue_growl", global_position)


## Perdió al jugador: si oye, va a investigar donde lo vio por última vez; si no, se queda.
func _lose_player() -> void:
	if hearing.is_deaf() or _player == null:
		state = STATE_IDLE
		return
	hearing.clear()
	hearing.hear(global_position, _player.global_position, Rules.NOISE_VERY_HIGH)
	_begin_investigation()


## Reacciona a un ruido del juego (solo los enemigos que oyen están suscritos).
func _on_noise(origin: Vector3, level: int) -> void:
	if state == STATE_DEAD or state == STATE_CHASE or state == STATE_ATTACK:
		return
	if state == STATE_STUNNED:
		return
	var ear := global_position + Vector3.UP * HEAD_HEIGHT
	if not hearing.hear(ear, origin, level, _walls_between(ear, origin)):
		return
	if state != STATE_INVESTIGATE:
		EventBus.sound_cue.emit("cue_listener_alert", global_position)
	_begin_investigation()


func _begin_investigation() -> void:
	state = STATE_INVESTIGATE
	_arrived = false
	_agent.target_position = hearing.target


## Va al punto del ruido, mira alrededor un rato y vuelve a su sitio.
func _investigate(delta: float) -> void:
	if not _arrived:
		if _move_to(hearing.target, data.move_speed):
			_arrived = true
			_look_timer = INVESTIGATE_LOOK_TIME
		return
	velocity.x = 0.0
	velocity.z = 0.0
	rotate_y(LOOK_AROUND_SPEED * delta)
	_look_timer -= delta
	if _look_timer <= 0.0:
		hearing.clear()
		state = STATE_RETURN
		_agent.target_position = _home


func _return_home() -> void:
	if _move_to(_home, data.move_speed * 0.7):
		state = STATE_IDLE


## Camina hacia un punto por la navegación. Devuelve verdadero al llegar.
func _move_to(point: Vector3, speed: float) -> bool:
	var flat := Vector2(point.x - global_position.x, point.z - global_position.z)
	if flat.length() <= ARRIVE_DISTANCE:
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	if _agent.target_position.distance_to(point) > 0.5:
		_agent.target_position = point
	var next := _agent.get_next_path_position()
	if _agent.is_navigation_finished() or next.distance_to(global_position) < 0.05:
		next = point
	_walk_toward(next, speed)
	return false


## Paredes entre dos puntos para atenuar un ruido: 0 si hay línea directa, 1 si no.
func _walls_between(from: Vector3, to: Vector3) -> int:
	_noise_query.from = from
	_noise_query.to = to + Vector3.UP * 0.5
	var hit := get_world_3d().direct_space_state.intersect_ray(_noise_query)
	return 0 if hit.is_empty() else 1


## Verdadero si la navegación encuentra ruta hasta su objetivo actual.
func has_route() -> bool:
	return _agent.is_target_reachable()


func _chase(delta: float) -> void:
	if _player == null:
		state = STATE_IDLE
		return
	_behavior.update(self, _player, delta)
	var in_range := global_position.distance_to(_player.global_position) <= data.attack_range
	if in_range and _behavior.can_attack(self, _player):
		if _attack_cooldown <= 0.0:
			state = STATE_ATTACK
			_attack_timer = ATTACK_WINDUP
		velocity.x = 0.0
		velocity.z = 0.0
		_face(_player.global_position)
		return
	var next := _agent.get_next_path_position()
	if _agent.is_navigation_finished() or next.distance_to(global_position) < 0.05:
		# Sin ruta (o ya en ella): va en línea recta al punto que pide su comportamiento.
		next = _chase_target
	_walk_toward(next, data.move_speed)


func _walk_toward(point: Vector3, speed: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_face(global_position + direction)


func _attack(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	if (
		_player != null
		and global_position.distance_to(_player.global_position) <= data.attack_range + 0.3
	):
		_player.receive_damage(data.attack_damage, data.infect_chance)
	_attack_cooldown = data.attack_interval
	state = STATE_CHASE


func _die() -> void:
	state = STATE_DEAD
	collision_layer = 0
	collision_mask = Rules.LAYER_WORLD
	velocity = Vector3.ZERO
	var drops := LootRoller.roll(health, GameState.items, _rng)
	EventBus.enemy_died.emit(global_position, drops)
	died.emit()
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:x", -PI * 0.5, 0.5)
	tween.parallel().tween_property(_visual, "position:y", 0.25, 0.5)


func _zone_at(point: Vector3) -> int:
	var height := point.y - global_position.y
	if height >= HEAD_HEIGHT:
		return Rules.ZONE_HEAD
	if height >= VEST_BOTTOM and health.has_vest:
		return Rules.ZONE_VEST
	return Rules.ZONE_BODY


func _can_see_player() -> bool:
	var eye := global_position + Vector3.UP * HEAD_HEIGHT
	var target := _player.global_position + Vector3.UP * Rules.PLAYER_EYE_HEIGHT * 0.8
	if eye.distance_to(target) > data.sight_range:
		return false
	_sight_query.from = eye
	_sight_query.to = target
	var hit := get_world_3d().direct_space_state.intersect_ray(_sight_query)
	return hit.is_empty()


func _find_player() -> Player:
	var node := get_tree().get_first_node_in_group("player")
	if node is Player:
		return node
	return null


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.01:
		look_at(flat, Vector3.UP)


func _vest_max() -> float:
	var vest_item := GameState.items.get_item(data.vest_item_id)
	return vest_item.max_durability() if vest_item != null else 100.0


func _build_visual() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = data.body_color
	_visual.scale = Vector3.ONE * data.body_scale
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.6
	capsule.material = _body_material
	body.mesh = capsule
	body.position.y = 0.8
	_visual.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.3, 0.3, 0.3)
	head_mesh.material = _body_material
	head.mesh = head_mesh
	head.position.y = 1.65
	_visual.add_child(head)
	if health.has_vest:
		_vest_mesh = MeshInstance3D.new()
		var vest_mesh := BoxMesh.new()
		vest_mesh.size = Vector3(0.7, 0.6, 0.72)
		var vest_material := StandardMaterial3D.new()
		vest_material.albedo_color = Color(0.12, 0.12, 0.12)
		vest_mesh.material = vest_material
		_vest_mesh.mesh = vest_mesh
		_vest_mesh.position.y = 1.15
		_visual.add_child(_vest_mesh)


func _refresh_vest_visual() -> void:
	if _vest_mesh == null:
		return
	_vest_mesh.visible = not health.vest_durability.is_broken()
	_vest_mesh.scale = Vector3.ONE * lerpf(0.9, 1.0, health.vest_durability.fraction())


func _flash_hit() -> void:
	# Cambio suave de color al recibir un golpe (sin destellos de pantalla).
	var tween := create_tween()
	var base := _body_material.albedo_color
	tween.tween_property(_body_material, "albedo_color", base.lightened(0.35), 0.06)
	tween.tween_property(_body_material, "albedo_color", base, 0.2)

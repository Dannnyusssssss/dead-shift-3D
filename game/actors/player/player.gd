class_name Player
extends CharacterBody3D
## Jugador en primera persona: movimiento, mirada, agacharse, balanceo de cámara e
## interacción por rayo. El combate y el inventario son nodos hijos con su propio script.
## Solo lee controles a través de InputRouter.

const GRAVITY: float = 9.8
const HEAD_BOB_SPEED: float = 10.0
const HEAD_BOB_HEIGHT: float = 0.035
const CROUCH_LERP: float = 10.0
## Cada cuánto suena un paso (emite ruido) al moverse.
const STEP_INTERVAL: float = 0.45
const THROWN_SCRIPT: GDScript = preload("res://game/world/thrown_item.gd")

## Falso mientras algo bloquea los controles (combinar, inventario abierto, muerte):
## el jugador no se mueve ni ataca. Asignarlo pone o quita el bloqueo «manual».
var controls_enabled: bool:
	get:
		return _blocks.is_empty()
	set(value):
		set_blocked("manual", not value)
## Verdadero mientras combina o se cura: las manos están ocupadas (no ataca, no recoge, no
## lanza ni cambia de arma), pero puede mirar y caminar despacio.
var hands_busy: bool:
	get:
		return crafting.active or healing.active
var crouching: bool = false
var sprinting: bool = false
## Lanzar con puntería (se crea al empezar; no está en la escena).
var throw: PlayerThrow = null
## Linterna del hombro (se crea al empezar; no está en la escena).
var flashlight: PlayerFlashlight = null

var _pitch: float = 0.0
var _bob_time: float = 0.0
var _eye_height: float = Rules.PLAYER_EYE_HEIGHT
var _prompt_key: String = ""
var _step_timer: float = 0.0
var _throw_cooldown: float = 0.0
## Motivos activos que bloquean los controles.
var _blocks: Dictionary = {}
## Retroceso y sacudida de la cámara (se suman a la mirada y vuelven solos a cero).
var _kick: float = 0.0
var _shake: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var arms: PlayerArms = $Head/Camera/Arms
@onready var interact_ray: RayCast3D = $Head/Camera/InteractRay
@onready var aim_ray: RayCast3D = $Head/Camera/AimRay
@onready var combat: PlayerCombat = $Combat
@onready var crafting: PlayerCrafting = $Crafting
@onready var healing: PlayerHealing = $Healing


func _ready() -> void:
	add_to_group("player")
	throw = PlayerThrow.new()
	throw.name = "Throw"
	add_child(throw)
	flashlight = PlayerFlashlight.new()
	flashlight.name = "FlashlightControl"
	add_child(flashlight)
	# Escaleras: misma velocidad en pendiente y pegado al suelo al bajar.
	floor_constant_speed = true
	floor_snap_length = 0.4
	if GameState.player == null:
		GameState.start_new_run()
	interact_ray.target_position = Vector3(0.0, 0.0, -Rules.PLAYER_INTERACT_RANGE)
	_apply_fov()
	EventBus.settings_changed.connect(_on_settings_changed)


func _physics_process(delta: float) -> void:
	_settle_camera(delta)
	_apply_look()
	_update_movement(delta)
	_update_head(delta)
	_update_steps(delta)
	_update_interaction()
	_update_throw(delta)
	_update_infection(delta)


## Empujón de la cámara hacia arriba (retroceso). No hace nada con «Reducir movimiento».
func kick_camera(amount: float) -> void:
	if Settings.get_bool("reduce_motion"):
		return
	_kick = minf(_kick + amount, 0.12)


## Recupera el retroceso y la sacudida poco a poco.
func _settle_camera(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, delta * 0.35)
	_shake = move_toward(_shake, 0.0, delta * 0.12)


## Pone o quita un motivo de bloqueo de los controles.
func set_blocked(reason: String, blocked: bool) -> void:
	if blocked:
		_blocks[reason] = true
	else:
		_blocks.erase(reason)


## Deja una casilla en el suelo, delante del jugador.
func drop_stack(stack: ItemStack) -> void:
	var spot := global_position - global_basis.z * 0.8 + Vector3.UP * 0.2
	EventBus.item_dropped.emit(spot, stack)


## Lanza una unidad de un material de la bolsa hacia donde mira. Devuelve falso si no se pudo.
func throw_material(item_id: String) -> bool:
	if _throw_cooldown > 0.0 or is_dead() or GameState.player == null:
		return false
	var stack := GameState.player.take_material(item_id)
	if stack == null:
		return false
	_throw_cooldown = Rules.THROW_COOLDOWN
	var thrown: ThrownItem = THROWN_SCRIPT.new()
	var start_velocity := aim_direction() * Rules.THROW_SPEED + Vector3.UP * Rules.THROW_LIFT
	var exclude: Array[RID] = [get_rid()]
	thrown.setup(stack, start_velocity, exclude)
	get_parent().add_child(thrown)
	thrown.global_position = aim_origin() + aim_direction() * 0.4
	arms.play_attack(Rules.THROW_COOLDOWN)
	EventBus.inventory_changed.emit()
	EventBus.weapon_changed.emit()
	return true


func is_dead() -> bool:
	return GameState.player != null and GameState.player.is_dead()


## Recibe un golpe: pasa por el chaleco (lógica de core) y avisa a la interfaz. Si viene de
## un enemigo que contagia, infect_chance es la probabilidad de infectar (azar de la partida).
func receive_damage(amount: float, infect_chance: float = 0.0) -> void:
	var state := GameState.player
	if state == null or state.is_dead():
		return
	var was_infected := state.infection.infected
	var lost := state.take_bite(amount, infect_chance, GameState.rng)
	EventBus.player_damaged.emit(lost)
	if lost > 0.0 and not Settings.get_bool("reduce_motion"):
		_shake = minf(_shake + lost * 0.0012, 0.03)
	EventBus.player_health_changed.emit(state.health)
	EventBus.vest_changed.emit()
	if state.infection.infected and not was_infected:
		EventBus.infection_changed.emit()
		EventBus.user_message.emit("msg_infected")
	if state.is_dead():
		_die()


## Daño del gas tóxico: no pasa por el chaleco ni contagia.
func receive_toxic_damage(amount: float) -> void:
	var state := GameState.player
	if state == null or state.is_dead():
		return
	var lost := state.take_raw_damage(amount)
	EventBus.player_damaged.emit(lost)
	EventBus.player_health_changed.emit(state.health)
	if state.is_dead():
		_die()


func _die() -> void:
	set_blocked("dead", true)
	EventBus.player_died.emit()


## Nivel de ruido que hace ahora al moverse (Rules.NOISE_*), o -1 si está quieto.
func movement_noise() -> int:
	var horizontal := Vector2(velocity.x, velocity.z)
	if horizontal.length() < 0.2 or not is_on_floor():
		return -1
	if crouching:
		return Rules.NOISE_CROUCH
	if sprinting:
		return Rules.NOISE_SPRINT
	return Rules.NOISE_WALK


## Punto y dirección del centro de la mirada (para disparar y golpear).
func aim_origin() -> Vector3:
	return camera.global_position


func aim_direction() -> Vector3:
	return -camera.global_basis.z


func _apply_look() -> void:
	var look := InputRouter.consume_look()
	if not controls_enabled:
		return
	rotate_y(-look.x)
	var limit := deg_to_rad(Rules.LOOK_PITCH_LIMIT_DEG)
	_pitch = clampf(_pitch - look.y, -limit, limit)
	head.rotation.x = _pitch + _kick
	head.rotation.z = sin(Time.get_ticks_msec() * 0.07) * _shake


func _update_movement(delta: float) -> void:
	var input := InputRouter.move_vector() if controls_enabled else Vector2.ZERO
	if controls_enabled and InputRouter.just_pressed("crouch"):
		crouching = not crouching
	var wants_sprint := InputRouter.is_pressed("sprint")
	if InputRouter.touch_mode:
		# En táctil, empujar la palanca hasta el borde equivale a correr.
		wants_sprint = input.length() > 0.95
	sprinting = wants_sprint and not crouching and input.y > 0.3 and not hands_busy
	var speed := Rules.PLAYER_WALK_SPEED
	if hands_busy:
		speed = minf(Rules.PLAYER_BUSY_SPEED, Rules.PLAYER_CROUCH_SPEED if crouching else INF)
	elif crouching:
		speed = Rules.PLAYER_CROUCH_SPEED
	elif sprinting:
		speed = Rules.PLAYER_SPRINT_SPEED
	var direction := global_basis * Vector3(input.x, 0.0, -input.y)
	direction.y = 0.0
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()


func _update_head(delta: float) -> void:
	var target := Rules.PLAYER_CROUCH_EYE_HEIGHT if crouching else Rules.PLAYER_EYE_HEIGHT
	_eye_height = lerpf(_eye_height, target, clampf(CROUCH_LERP * delta, 0.0, 1.0))
	var bob := 0.0
	var bob_allowed := Settings.get_bool("head_bob") and not Settings.get_bool("reduce_motion")
	if bob_allowed and movement_noise() >= 0:
		_bob_time += delta * HEAD_BOB_SPEED * (1.4 if sprinting else 1.0)
		bob = sin(_bob_time) * HEAD_BOB_HEIGHT
	head.position.y = _eye_height + bob


func _update_steps(delta: float) -> void:
	var level := movement_noise()
	if level < 0:
		_step_timer = 0.0
		return
	_step_timer -= delta * (1.4 if sprinting else 1.0)
	if _step_timer <= 0.0:
		_step_timer = STEP_INTERVAL
		NoiseSystem.emit_noise(global_position, level, true)


func _update_interaction() -> void:
	var target := _interaction_target()
	var key := target.get_prompt_key() if target != null else ""
	if key != _prompt_key:
		_prompt_key = key
		var detail := target.get_prompt_detail() if target != null and not key.is_empty() else ""
		EventBus.interaction_prompt.emit(key, detail)
	if target != null and not key.is_empty() and controls_enabled and not hands_busy:
		if InputRouter.just_pressed("interact"):
			target.interact(self)


func _update_throw(delta: float) -> void:
	_throw_cooldown = maxf(_throw_cooldown - delta, 0.0)


func _update_infection(delta: float) -> void:
	var state := GameState.player
	if state != null and state.tick_infection(delta):
		EventBus.player_health_changed.emit(state.health)
		_die()


func _interaction_target() -> Interactable:
	if not interact_ray.is_colliding():
		return null
	var collider := interact_ray.get_collider()
	if collider is Interactable:
		return collider
	return null


func _apply_fov() -> void:
	camera.fov = Settings.get_float("fov")


func _on_settings_changed(key: String) -> void:
	if key == "fov":
		_apply_fov()

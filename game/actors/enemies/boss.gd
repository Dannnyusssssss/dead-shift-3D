class_name Boss
extends Enemy
## El Técnico, jefe del Nivel 2. Hereda de Enemy para que el combate y la interfaz lo traten
## como a cualquier enemigo, pero tiene su propia secuencia: perseguir, golpe cercano, embestida
## anunciada (rompe estanterías; contra un tablero con corriente queda aturdido mucho tiempo),
## nube tóxica y segunda fase al romperse el traje. Las reglas están en core (BossModel).
## Se anuncia de forma gradual con un indicador de radiación y subtítulos.

const B_IDLE: int = 0
const B_CHASE: int = 1
const B_SWIPE: int = 2
const B_CHARGE_WINDUP: int = 3
const B_CHARGING: int = 4
const B_STUNNED: int = 5
const B_RETURN: int = 6
const B_DEAD: int = 7

## Distancia a la que empieza el combate si ve al jugador, y a la que deja de perseguirlo.
const ENGAGE_DISTANCE: float = 16.0
const LEASH_DISTANCE: float = 30.0
## Distancias del indicador de radiación (niveles 3, 2 y 1).
const PROXIMITY_STEPS: Array[float] = [8.0, 16.0, 26.0]
## Ángulo (grados desde su frente) a partir del cual un golpe llega al tanque de la espalda.
const TANK_ANGLE: float = 110.0
const CHARGE_HIT_DISTANCE: float = 1.6

var model: BossModel = null
var boss_state: int = B_IDLE
## Dirección fija de la embestida en curso.
var charge_direction: Vector3 = Vector3.ZERO

var _boss_timer: float = 0.0
var _proximity: int = -1
var _announced: bool = false
var _charge_hit_player: bool = false
var _tank_mesh: MeshInstance3D = null


func _ready() -> void:
	super._ready()
	model = BossModel.new(data.boss, GameState.difficulty.boss_health_multiplier())
	add_to_group("boss")


func _physics_process(delta: float) -> void:
	if boss_state == B_DEAD:
		return
	# Sus tiempos solo corren en combate (quieto no prepara ataques).
	if boss_state != B_IDLE and boss_state != B_RETURN:
		model.tick(delta)
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = THINK_INTERVAL
		_boss_think()
	if model.phase_changed:
		model.phase_changed = false
		_on_phase_two()
	if model.is_stunned() and boss_state != B_STUNNED:
		boss_state = B_STUNNED
	match boss_state:
		B_CHASE:
			_boss_chase()
		B_SWIPE:
			_boss_swipe(delta)
		B_CHARGE_WINDUP:
			_boss_windup(delta)
		B_CHARGING:
			_boss_charging(delta)
		B_STUNNED:
			velocity.x = 0.0
			velocity.z = 0.0
			if not model.is_stunned():
				boss_state = B_CHASE
		B_RETURN:
			if _move_to(_home, model.speed()):
				boss_state = B_IDLE
		_:
			velocity.x = 0.0
			velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if boss_state == B_CHARGING:
		_check_charge_collisions()


## Recibe un impacto. Llega al tanque si el golpe viene desde atrás; si está aturdido, todo
## golpe cuenta como tanque. El extintor lo aturde (con inmunidad posterior).
func take_hit(damage: float, _hit_point: Vector3, _is_bullet: bool, stuns: bool = false) -> float:
	if boss_state == B_DEAD:
		return 0.0
	var applied := model.take_hit(damage, _hit_from_behind())
	if stuns and model.stun_by_extinguisher():
		EventBus.sound_cue.emit("cue_boss_stunned", global_position)
	_flash_hit()
	if boss_state == B_IDLE:
		_engage()
	EventBus.boss_changed.emit()
	if model.is_dead():
		_boss_die()
	return applied


func is_dead() -> bool:
	return boss_state == B_DEAD


func _boss_think() -> void:
	_player = _find_player()
	if _player == null or _player.is_dead():
		_emit_proximity(0)
		return
	var distance := global_position.distance_to(_player.global_position)
	sees_player = _can_see_player()
	_emit_proximity(_proximity_level(distance))
	if boss_state == B_IDLE and sees_player and distance <= ENGAGE_DISTANCE:
		_engage()
	elif boss_state == B_CHASE and distance > LEASH_DISTANCE:
		boss_state = B_RETURN
	elif boss_state == B_RETURN and sees_player and distance <= ENGAGE_DISTANCE:
		_engage()
	if boss_state == B_CHASE:
		_agent.target_position = _player.global_position
		if model.can_cloud():
			_spawn_cloud()


func _engage() -> void:
	boss_state = B_CHASE
	model.begin_fight()
	if not _announced:
		_announced = true
		EventBus.sound_cue.emit("cue_boss_roar", global_position)
	EventBus.boss_changed.emit()


func _boss_chase() -> void:
	if _player == null:
		return
	var distance := global_position.distance_to(_player.global_position)
	if model.can_swipe(distance):
		model.start_swipe()
		boss_state = B_SWIPE
		_boss_timer = data.boss.swipe_windup
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if sees_player and model.can_charge(distance):
		model.start_charge()
		boss_state = B_CHARGE_WINDUP
		_boss_timer = data.boss.charge_windup
		EventBus.sound_cue.emit("cue_boss_charge", global_position)
		return
	var next := _agent.get_next_path_position()
	if _agent.is_navigation_finished() or next.distance_to(global_position) < 0.05:
		next = _player.global_position
	_walk_toward(next, model.speed())


func _boss_swipe(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _player != null:
		_face(_player.global_position)
	_boss_timer -= delta
	if _boss_timer > 0.0:
		return
	if _player != null:
		var distance := global_position.distance_to(_player.global_position)
		if distance <= data.boss.swipe_range + 0.3:
			_player.receive_damage(data.boss.swipe_damage)
	boss_state = B_CHASE


## Preparación visible de la embestida: se queda quieto mirando al jugador; al final fija la
## dirección (el jugador puede apartarse).
func _boss_windup(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _player != null:
		_face(_player.global_position)
	_boss_timer -= delta
	if _boss_timer > 0.0:
		return
	if _player == null:
		_player = _find_player()
	var target := _player.global_position if _player != null else global_position
	charge_direction = Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	charge_direction = (
		charge_direction.normalized() if charge_direction.length() > 0.01 else -global_basis.z
	)
	boss_state = B_CHARGING
	_boss_timer = data.boss.charge_duration
	_charge_hit_player = false


func _boss_charging(delta: float) -> void:
	velocity.x = charge_direction.x * data.boss.charge_speed
	velocity.z = charge_direction.z * data.boss.charge_speed
	_boss_timer -= delta
	if _player != null and not _charge_hit_player:
		if global_position.distance_to(_player.global_position) <= CHARGE_HIT_DISTANCE:
			_charge_hit_player = true
			_player.receive_damage(data.boss.charge_damage)
	if _boss_timer <= 0.0:
		boss_state = B_CHASE


## Choques de la embestida: rompe estanterías, se aturde contra un tablero con corriente
## (y lo apaga) y un momento contra una pared.
func _check_charge_collisions() -> void:
	for index: int in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider()
		if collider is BreakableShelf:
			(collider as BreakableShelf).break_apart()
			continue
		if collider is ElectricPanel and (collider as ElectricPanel).live:
			(collider as ElectricPanel).short_out()
			model.stun(data.boss.panel_stun)
			EventBus.sound_cue.emit("cue_boss_stunned", global_position)
			boss_state = B_STUNNED
			return
		if collider is Player:
			continue
		if collision.get_normal().dot(charge_direction) < -0.5:
			model.stun(data.boss.wall_stun)
			boss_state = B_STUNNED
			return


func _spawn_cloud() -> void:
	if _player == null:
		return
	model.start_cloud()
	var cloud := ToxicCloud.new()
	cloud.radius = data.boss.cloud_radius
	cloud.warning = data.boss.cloud_warning
	cloud.duration = data.boss.cloud_duration
	cloud.dps = model.cloud_dps()
	get_parent().add_child(cloud)
	cloud.global_position = Vector3(_player.global_position.x, 0.0, _player.global_position.z)


func _on_phase_two() -> void:
	EventBus.sound_cue.emit("cue_boss_suit_breaks", global_position)
	_body_material.albedo_color = data.body_color.darkened(0.35)
	if _tank_mesh != null:
		var material := _tank_mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = 1.2
	EventBus.boss_changed.emit()


func _hit_from_behind() -> bool:
	var player := _find_player()
	if player == null:
		return false
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() < 0.01:
		return false
	var forward := -global_basis.z
	forward.y = 0.0
	return rad_to_deg(forward.angle_to(to_player)) >= TANK_ANGLE


func _proximity_level(distance: float) -> int:
	for index: int in PROXIMITY_STEPS.size():
		if distance <= PROXIMITY_STEPS[index]:
			return 3 - index
	return 0


func _emit_proximity(level: int) -> void:
	if level == _proximity:
		return
	if level > 0 and _proximity <= 0:
		EventBus.sound_cue.emit("cue_geiger", global_position)
	_proximity = level
	EventBus.boss_proximity.emit(level)


func _boss_die() -> void:
	boss_state = B_DEAD
	state = STATE_DEAD
	collision_layer = 0
	collision_mask = Rules.LAYER_WORLD
	velocity = Vector3.ZERO
	var drops: Array[ItemStack] = []
	var key := GameState.items.get_item(data.boss.drop_key_item)
	if key != null:
		drops.append(ItemStack.new(key))
	GameState.world.set_flag("boss_defeated")
	_emit_proximity(0)
	EventBus.enemy_died.emit(global_position, drops)
	EventBus.boss_changed.emit()
	EventBus.sound_cue.emit("cue_boss_down", global_position)
	died.emit()
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:x", -PI * 0.5, 0.8)
	tween.parallel().tween_property(_visual, "position:y", 0.35, 0.8)


func _build_visual() -> void:
	super._build_visual()
	# Tanque a la espalda (+Z local, porque el frente mira a -Z): el punto débil.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.75, 0.2)
	material.emission_enabled = true
	material.emission = Color(0.6, 0.9, 0.2)
	material.emission_energy_multiplier = 0.4
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 0.8
	mesh.material = material
	_tank_mesh = MeshInstance3D.new()
	_tank_mesh.mesh = mesh
	_tank_mesh.position = Vector3(0.0, 1.25, 0.38)
	_visual.add_child(_tank_mesh)

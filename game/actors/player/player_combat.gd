class_name PlayerCombat
extends Node
## Combate del jugador: disparar, recargar, golpear cuerpo a cuerpo, cambiar de arma y apuntar.
## Las reglas (munición, desgaste, rotura) son de core; aquí se aplican a la escena.
## Va como hijo del nodo Player.

## Grados que se cierra el campo de visión al apuntar con un arma de fuego.
## Empujón de cámara (radianes) al disparar y al acertar un golpe (sin «Reducir movimiento»).
const RECOIL_KICK: float = 0.035
const MELEE_KICK: float = 0.02
const AIM_FOV_OFFSET: float = 15.0
const AIM_LERP: float = 12.0
## Momento del golpe dentro de la animación (fracción del intervalo de ataque).
const MELEE_HIT_MOMENT: float = 0.35
## Ángulo del arco del golpe cuerpo a cuerpo (grados a cada lado del centro).
const MELEE_ARC_DEGREES: float = 25.0
## Duración del destello del disparo (uno por disparo; el intervalo limita a 3 por segundo).
const MUZZLE_TIME: float = 0.06
const MUZZLE_ENERGY: float = 1.6
const CHEST_HEIGHT: float = 1.15

var _player: Player = null
var _cooldown: float = 0.0
var _reload_timer: float = 0.0
var _reload_stack: ItemStack = null
var _melee_timer: float = -1.0
var _melee_stack: ItemStack = null
var _muzzle_timer: float = 0.0
var _muzzle: OmniLight3D = null
var _ray: PhysicsRayQueryParameters3D = null


func _ready() -> void:
	_player = get_parent() as Player
	_ray = PhysicsRayQueryParameters3D.create(
		Vector3.ZERO, Vector3.ZERO, Rules.LAYER_WORLD | Rules.LAYER_ENEMY
	)
	_ray.exclude = [_player.get_rid()]
	_muzzle = OmniLight3D.new()
	_muzzle.light_energy = 0.0
	_muzzle.omni_range = 4.0
	_muzzle.light_color = Color(1.0, 0.85, 0.6)
	_muzzle.position = Vector3(0.2, -0.1, -0.6)
	# Los hijos están listos antes que el padre: la cámara se toma por su ruta.
	_player.get_node(^"Head/Camera").add_child(_muzzle)
	EventBus.weapon_changed.connect(_refresh_weapon_visual)
	_refresh_weapon_visual.call_deferred()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_update_aim(delta)
	if not _player.controls_enabled or _player.is_dead() or _player.hands_busy:
		return
	if _player.throw != null and _player.throw.is_aiming():
		return
	_handle_switch()
	_handle_reload_input()
	_handle_attack()


## Verdadero mientras recarga o está en medio de un golpe.
func is_busy() -> bool:
	return _reload_timer > 0.0 or _melee_timer >= 0.0


func _state() -> PlayerState:
	return GameState.player


func _tick_timers(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _muzzle_timer > 0.0:
		_muzzle_timer -= delta
		if _muzzle_timer <= 0.0:
			_muzzle.light_energy = 0.0
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
	if _melee_timer >= 0.0:
		_melee_timer -= delta
		if _melee_timer < 0.0:
			_resolve_melee()


func _handle_switch() -> void:
	if is_busy():
		return
	var changed := false
	if InputRouter.just_pressed("weapon_next"):
		changed = _state().cycle_weapon(1)
	elif InputRouter.just_pressed("weapon_prev"):
		changed = _state().cycle_weapon(-1)
	else:
		for number: int in 3:
			if InputRouter.just_pressed("weapon_slot_%d" % (number + 1)):
				changed = _select_nth_weapon(number)
	if changed:
		EventBus.weapon_changed.emit()


## Equipa la enésima arma del inventario (teclas 1, 2 y 3).
func _select_nth_weapon(number: int) -> bool:
	var seen := 0
	for index: int in _state().inventory.capacity():
		var stack := _state().inventory.get_slot(index)
		if stack != null and stack.is_weapon():
			if seen == number:
				return _state().select_slot(index)
			seen += 1
	return false


func _handle_reload_input() -> void:
	if InputRouter.just_pressed("reload"):
		_start_reload()


func _start_reload() -> void:
	var stack := _state().equipped()
	if stack == null or is_busy() or not WeaponUse.can_reload(stack, _state().inventory):
		return
	_reload_stack = stack
	_reload_timer = stack.item.weapon.reload_time
	_player.arms.play_reload(_reload_timer)


func _finish_reload() -> void:
	if _reload_stack != null and _reload_stack == _state().equipped():
		WeaponUse.reload_from(_reload_stack, _state().inventory)
		EventBus.inventory_changed.emit()
		EventBus.weapon_changed.emit()
	_reload_stack = null


func _handle_attack() -> void:
	var stack := _state().equipped()
	if stack == null or _cooldown > 0.0 or is_busy():
		return
	var weapon := stack.item.weapon
	if weapon.kind == WeaponData.KIND_RANGED:
		if InputRouter.just_pressed("attack"):
			if WeaponUse.can_fire(stack):
				_shoot(stack)
			else:
				_start_reload()
	elif InputRouter.is_pressed("attack"):
		_swing(stack)


func _shoot(stack: ItemStack) -> void:
	var weapon := stack.item.weapon
	WeaponUse.fire(stack)
	_cooldown = weapon.attack_interval
	_player.arms.play_shoot()
	if not Settings.get_bool("reduce_flashes"):
		_muzzle.light_energy = MUZZLE_ENERGY
		_muzzle_timer = MUZZLE_TIME
	NoiseSystem.emit_noise(_player.global_position, weapon.noise_level, true)
	var origin := _player.aim_origin()
	var direction := _assisted_direction(origin, _player.aim_direction(), weapon.attack_range)
	var hit := _cast(origin, origin + direction * weapon.attack_range)
	if not hit.is_empty():
		var collider: Variant = hit.get("collider")
		var point: Vector3 = hit.get("position", Vector3.ZERO)
		if collider is Enemy:
			var enemy: Enemy = collider
			enemy.take_hit(weapon.damage, point, true)
			EventBus.hit_confirmed.emit(enemy.is_dead())
	_player.kick_camera(RECOIL_KICK)
	EventBus.weapon_changed.emit()


func _swing(stack: ItemStack) -> void:
	var weapon := stack.item.weapon
	_cooldown = weapon.attack_interval
	_melee_stack = stack
	_melee_timer = weapon.attack_interval * MELEE_HIT_MOMENT
	_player.arms.play_attack(weapon.attack_interval)


## El golpe llega: busca un enemigo en el arco frontal, lo daña y desgasta el arma.
func _resolve_melee() -> void:
	var stack := _melee_stack
	_melee_stack = null
	if stack == null or stack != _state().equipped():
		return
	var weapon := stack.item.weapon
	var target := _melee_target(weapon.attack_range)
	if target == null:
		return
	var point := target.global_position + Vector3.UP * CHEST_HEIGHT
	target.take_hit(weapon.damage, point, false, weapon.stuns)
	EventBus.hit_confirmed.emit(target.is_dead())
	_player.kick_camera(MELEE_KICK)
	NoiseSystem.emit_noise(_player.global_position, weapon.noise_level, true)
	if WeaponUse.melee_hit(stack) == WeaponUse.HIT_BROKE:
		EventBus.weapon_broken.emit(stack.id())
		_state().handle_broken_weapons()
		EventBus.inventory_changed.emit()
	EventBus.weapon_changed.emit()


func _melee_target(reach: float) -> Enemy:
	var origin := _player.aim_origin()
	var forward := _player.aim_direction()
	var best: Enemy = null
	var best_distance := reach + 0.6
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var to_enemy := enemy.global_position + Vector3.UP * CHEST_HEIGHT - origin
		var distance := to_enemy.length()
		if distance > best_distance:
			continue
		if rad_to_deg(forward.angle_to(to_enemy)) > MELEE_ARC_DEGREES:
			continue
		var hit := _cast(origin, origin + to_enemy)
		if not hit.is_empty() and hit.get("collider") != enemy:
			continue
		best = enemy
		best_distance = distance
	return best


## Ayuda de puntería suave, solo con controles táctiles y si está activada: corrige el disparo
## hacia el enemigo visible más cercano al centro, dentro de un ángulo pequeño.
func _assisted_direction(origin: Vector3, direction: Vector3, reach: float) -> Vector3:
	if not InputRouter.touch_mode or not Settings.get_bool("aim_assist"):
		return direction
	var best := direction
	var best_angle := deg_to_rad(Rules.AIM_ASSIST_DEGREES)
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var to_enemy := enemy.global_position + Vector3.UP * CHEST_HEIGHT - origin
		if to_enemy.length() > reach:
			continue
		var angle := direction.angle_to(to_enemy)
		if angle < best_angle:
			best_angle = angle
			best = to_enemy.normalized()
	return best


func _cast(from: Vector3, to: Vector3) -> Dictionary:
	_ray.from = from
	_ray.to = to
	return _player.get_world_3d().direct_space_state.intersect_ray(_ray)


func _update_aim(delta: float) -> void:
	var base := Settings.get_float("fov")
	var target := base
	var stack := _state().equipped() if _state() != null else null
	var aiming := _player.controls_enabled and InputRouter.is_pressed("aim")
	if aiming and stack != null and stack.item.weapon.kind == WeaponData.KIND_RANGED:
		target = base - AIM_FOV_OFFSET
	_player.camera.fov = lerpf(_player.camera.fov, target, clampf(AIM_LERP * delta, 0.0, 1.0))


func _refresh_weapon_visual() -> void:
	if _state() != null:
		_player.arms.show_weapon(_state().equipped())

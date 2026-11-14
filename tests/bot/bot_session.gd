extends Node
@warning_ignore_start("unsafe_call_argument")
## Bot de recorrido: juega con semilla fija, sin ventana, a través de las acciones del InputMap
## (moverse, mirar, disparar, recargar, golpear). Sigue una ruta por piso: en la planta baja
## recoge el chaleco, curas y armas; en el Nivel 1 las piezas del teléfono, curas, la llave y
## el puesto de seguridad (escopeta); en el Nivel 2 la zona segura, la última pieza, vence al
## jefe y abre la puerta de la azotea. Demuestra que los pisos son completables; no que sean
## divertidos.
##
## Escenarios (argumento tras «--»): «full» (por defecto: la partida desde el principio hasta
## el rescate; arma el teléfono, llama al llegar a la azotea y espera en el helipuerto),
## «boss_shotgun» y «boss_melee» (empiezan en el Nivel 2 frente al almacén, sin los demás
## enemigos, con o sin escopeta, y terminan en la puerta de la azotea), «lost» (en la azotea con
## el helicóptero ya ido: oleadas hasta el final de rescate perdido) y «death» (en el Nivel 2
## casi sin salud ni armas: el final de muerte).

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")
## Tiempo máximo de juego antes de darlo por fallido.
const TIME_LIMIT: float = 600.0
const BOT_SEED: int = 20261114
const ENGAGE_RANGE: float = 16.0
const MELEE_RANGE: float = 1.3
const INTERACT_RANGE: float = 1.6
const REPATH_TIME: float = 0.5
const CHEST_HEIGHT: float = 1.1
## Altura a la que apunta con armas de fuego (la cabeza, como haría un jugador).
const HEAD_AIM_HEIGHT: float = 1.62
## Altura del tanque del jefe.
const TANK_HEIGHT: float = 1.3
## Sin arma útil solo retrocede si el enemigo está así de cerca; si no, sigue su ruta.
const RETREAT_RANGE: float = 7.0
## Distancia a la que el bot se desvía a recoger objetos útiles del suelo (botín de policías).
const LOOT_RANGE: float = 7.0
## Distancia delante de un tablero con corriente donde espera la embestida del jefe.
const PANEL_BAIT_DISTANCE: float = 2.6
## Objetivos en orden por piso: punto y si hay que usar lo que esté ahí.
const ROUTES: Dictionary = {
	"ground_floor":
	[
		[Vector3(-6.0, 0.0, -2.0), true],
		[Vector3(-6.8, 0.0, 2.6), true],
		[Vector3(-0.7, 0.0, -2.8), true],
		[Vector3(11.0, 0.0, -1.5), false],
		[Vector3(8.0, 0.0, -8.0), true],
		[Vector3(11.0, 0.0, -5.5), true],
		[Vector3(11.0, 0.0, -1.5), false],
		[Vector3(19.0, 0.0, 1.5), false],
		[Vector3(17.0, 0.0, 8.0), true],
		[Vector3(21.0, 0.0, 5.5), true],
		[Vector3(23.3, 0.0, 9.0), true],
		[Vector3(19.0, 0.0, 1.5), false],
		[Vector3(27.0, 0.0, -1.5), false],
		[Vector3(26.0, 0.0, -7.0), true],
		[Vector3(27.0, 0.0, -1.5), false],
		[Vector3(40.5, 0.0, 0.0), false],
	],
	"level_1":
	[
		[Vector3(27.0, 0.0, -1.5), false],
		[Vector3(27.0, 0.0, -5.5), true],
		[Vector3(30.2, 0.0, -9.4), true],
		[Vector3(27.0, 0.0, -1.5), false],
		[Vector3(19.0, 0.0, 1.5), false],
		[Vector3(19.0, 0.0, 7.5), true],
		[Vector3(15.2, 0.0, 9.6), true],
		[Vector3(23.2, 0.0, 9.6), true],
		[Vector3(19.0, 0.0, 1.5), false],
		[Vector3(11.0, 0.0, -1.5), false],
		[Vector3(15.3, 0.0, -9.8), true],
		[Vector3(11.0, 0.0, -1.5), false],
		[Vector3(32.0, 0.0, 1.5), false],
		[Vector3(32.0, 0.0, 3.6), true],
		[Vector3(32.0, 0.0, 8.0), true],
		[Vector3(29.2, 0.0, 9.6), true],
		[Vector3(35.2, 0.0, 9.6), true],
		[Vector3(30.0, 0.0, 6.0), true],
		[Vector3(32.0, 0.0, 1.5), false],
		[Vector3(-5.5, 0.0, 0.0), false],
	],
	"level_2":
	[
		[Vector3(11.0, 0.0, -1.5), false],
		[Vector3(15.2, 0.0, -9.8), true],
		[Vector3(7.2, 0.0, -9.8), true],
		[Vector3(11.0, 0.0, -1.5), false],
		[Vector3(27.0, 0.0, -1.5), false],
		[Vector3(27.0, 0.0, -5.5), true],
		[Vector3(30.2, 0.0, -9.4), true],
		[Vector3(27.0, 0.0, -1.5), false],
		[Vector3(31.0, 0.0, 2.4), true],
		[Vector3(19.0, 0.0, 1.5), false],
		[Vector3(19.0, 0.0, 5.0), false],
		[Vector3(32.0, 0.0, 9.0), false],
		[Vector3(34.6, 0.0, 9.0), true],
		[Vector3(38.0, 0.0, 9.0), false],
	],
}
## Ruta del escenario del jefe: entra al almacén y, vencido, sube a la azotea.
const BOSS_ROUTE: Array = [
	[Vector3(19.0, 0.0, 1.5), false],
	[Vector3(19.0, 0.0, 5.0), false],
	[Vector3(32.0, 0.0, 9.0), false],
	[Vector3(34.6, 0.0, 9.0), true],
	[Vector3(38.0, 0.0, 9.0), false],
]
## En los escenarios del jefe, pedir el cambio a este piso da el recorrido por completado.
const FINISH_FLOOR: String = "rooftop"
## Desenlace esperado de cada escenario que termina la partida.
const EXPECTED: Dictionary = {
	"full": RunStats.OUTCOME_RESCUED,
	"lost": RunStats.OUTCOME_LOST,
	"death": RunStats.OUTCOME_DEAD,
}
## En la azotea: ir al helipuerto y esperar.
const ROOFTOP_ROUTE: Array = [[Vector3(28.0, 0.0, 4.0), false]]

var scenario: String = "full"

var _game: Game = null
var _player: Player = null
var _route: Array = []
var _route_index: int = 0
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _path_goal: Vector3 = Vector3.INF
var _repath_timer: float = 0.0
var _fire_toggle: bool = false
var _stuck_timer: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _unstick_timer: float = 0.0
var _kills: int = 0
var _strafe_side: float = 1.0
## Objetos del suelo que no pudo recoger (para no insistir).
var _ignored: Array[int] = []
## Objeto que está intentando recoger y cuánto tiempo lleva (si no llega, lo descarta un rato:
## puede estar tras una reja cerrada).
var _loot_target: Pickup = null
var _loot_time: float = 0.0
var _done: bool = false
## Acciones que el bot quiere pulsadas en este fotograma (se aplican al final, sin soltar y
## volver a pulsar en el mismo fotograma, que el motor no cuenta como pulsación nueva).
var _wanted: Dictionary = {}
## Punto al que mirar este fotograma (se aplica una sola vez al final: el último pedido gana).
var _aim_point: Vector3 = Vector3.ZERO
var _has_aim: bool = false


func _ready() -> void:
	var run_seed := BOT_SEED
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.trim_prefix("--scenario=")
		elif arg.begins_with("--seed=") and arg.trim_prefix("--seed=").is_valid_int():
			run_seed = clampi(arg.trim_prefix("--seed=").to_int(), 0, Validation.SEED_MAX)
	# Semilla fija: el azar de la partida (mordidas) es el mismo en cada ejecución.
	GameState.forced_seed = run_seed
	_game = GAME_SCRIPT.new()
	add_child(_game)
	_player = _game.level.player
	_route = ROUTES.get(_game.level.floor_data.id, [])
	EventBus.goal_reached.connect(_on_goal)
	EventBus.floor_changed.connect(_on_floor_changed)
	EventBus.floor_change_requested.connect(_on_floor_change_requested)
	EventBus.player_died.connect(_on_died)
	EventBus.run_finished.connect(_on_run_finished)
	EventBus.enemy_died.connect(func(_o: Vector3, _d: Array[ItemStack]) -> void: _kills += 1)
	print(
		(
			"[bot] inicio: escenario %s, semilla %d, piso %s"
			% [scenario, run_seed, _game.level.floor_data.id]
		)
	)
	if scenario.begins_with("boss"):
		_prepare_boss_scenario.call_deferred()
	elif scenario == "lost":
		_prepare_lost_scenario.call_deferred()
	elif scenario == "death":
		_prepare_death_scenario.call_deferred()


## Escenario del jefe: equipo fijo, el resto del Nivel 2 vacío y directo al almacén.
func _prepare_boss_scenario() -> void:
	var level_2 := GameState.CATALOG.find_floor("level_2")
	for index: int in level_2.enemies.size():
		if level_2.enemies[index].enemy.boss == null:
			GameState.world.mark_killed("level_2", "enemy_%d" % index)
	var state := GameState.player
	state.inventory = Inventory.new()
	var items := GameState.items
	var pistol := ItemStack.new(items.get_item("pistol"))
	pistol.ammo_loaded = 8
	state.inventory.add_stack(pistol)
	state.inventory.add_item(items.get_item("pistol_ammo"), 8)
	state.inventory.add_stack(ItemStack.new(items.get_item("bat")))
	state.inventory.add_item(items.get_item("bandage"), 3)
	if scenario == "boss_shotgun":
		var shotgun := ItemStack.new(items.get_item("shotgun"))
		shotgun.ammo_loaded = 2
		state.inventory.add_stack(shotgun)
		state.inventory.add_item(items.get_item("shotgun_shells"), 6)
	else:
		state.inventory.add_stack(ItemStack.new(items.get_item("extinguisher")))
	state.vest = ItemStack.new(items.get_item("vest"), 1, 0.8)
	state.equipped_slot = 0
	_game.change_floor("level_2", "stairs_down")


## Rescate perdido: en la azotea con el helicóptero ya ido y equipo de combate.
func _prepare_lost_scenario() -> void:
	_give_fight_kit(false)
	GameState.rescue.call_helicopter()
	GameState.rescue.load_data(RescueClock.STATE_DEPARTED, 0.0)
	_game.change_floor("rooftop", "stairs_down")


## Muerte: en el Nivel 2, casi sin salud y sin armas.
func _prepare_death_scenario() -> void:
	GameState.player.inventory = Inventory.new()
	GameState.player.equipped_slot = -1
	GameState.player.health = 5.0
	_game.change_floor("level_2", "stairs_down")


func _give_fight_kit(with_shotgun: bool) -> void:
	var state := GameState.player
	state.inventory = Inventory.new()
	var items := GameState.items
	var pistol := ItemStack.new(items.get_item("pistol"))
	pistol.ammo_loaded = 8
	state.inventory.add_stack(pistol)
	state.inventory.add_item(items.get_item("pistol_ammo"), 30)
	state.inventory.add_stack(ItemStack.new(items.get_item("bat")))
	state.inventory.add_stack(ItemStack.new(items.get_item("bat_nails")))
	state.inventory.add_item(items.get_item("bandage"), 3)
	if with_shotgun:
		var shotgun := ItemStack.new(items.get_item("shotgun"))
		shotgun.ammo_loaded = 2
		state.inventory.add_stack(shotgun)
		state.inventory.add_item(items.get_item("shotgun_shells"), 6)
	else:
		state.inventory.add_stack(ItemStack.new(items.get_item("extinguisher")))
	state.vest = ItemStack.new(items.get_item("vest"), 1, 0.8)
	state.equipped_slot = 0


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _game.elapsed > TIME_LIMIT:
		_finish(false, "tiempo agotado en el objetivo %d" % _route_index)
		return
	_wanted.clear()
	_has_aim = false
	if _game.changing_floor or _player.healing.active or _game.finished:
		_apply_actions()
		return
	_handle_phone()
	var boss := _active_boss()
	var enemy := _visible_enemy()
	if boss != null:
		_fight_boss(boss, delta)
	elif enemy != null:
		_fight(enemy, delta)
	elif _try_heal():
		pass
	else:
		var loot := _nearby_loot()
		if loot != null:
			_collect(loot, delta)
		else:
			_follow_route(delta)
	_apply_actions()


## Arma el teléfono en cuanto tiene las tres piezas y llama al llegar a la azotea.
func _handle_phone() -> void:
	var keys := GameState.player.keys
	if keys.can_assemble_phone() and keys.assemble_phone():
		print("[bot] arma el teléfono")
	var on_roof := _game.level.floor_data.has_helipad
	if keys.phone_assembled and on_roof and GameState.rescue.call_helicopter():
		print("[bot] llama al helicóptero")


# --- Jefe -----------------------------------------------------------------------------------


## El jefe si está vivo y en combate.
func _active_boss() -> Boss:
	var boss := get_tree().get_first_node_in_group("boss") as Boss
	if boss == null or boss.is_dead() or not boss.is_inside_tree():
		return null
	if boss.boss_state == Boss.B_IDLE or boss.boss_state == Boss.B_RETURN:
		return null
	return boss


## Táctica contra el jefe: esquivar la embestida de lado, salir de las nubes, esperarlo delante
## de un tablero con corriente y castigar el tanque cuando está aturdido.
func _fight_boss(boss: Boss, delta: float) -> void:
	var distance := _flat(boss.global_position).distance_to(_flat(_player.global_position))
	var cloud := _cloud_here()
	var hurt := GameState.player.health < Rules.PLAYER_MAX_HEALTH * 0.45 and distance > 7.0
	if boss.boss_state == Boss.B_CHARGING:
		_dodge_charge(boss)
	elif boss.model.is_stunned():
		_punish(boss, distance, delta)
	elif cloud != null:
		_leave_cloud(cloud, delta)
	elif boss.boss_state == Boss.B_CHARGE_WINDUP:
		_aim_at(boss.global_position + Vector3.UP * CHEST_HEIGHT)
	elif hurt and _try_heal():
		pass
	elif _best_panel(boss) != null:
		var bait := _panel_bait_point(_best_panel(boss))
		if _flat(bait).distance_to(_flat(_player.global_position)) > 0.8:
			_walk_to(bait, delta)
		else:
			_aim_at(boss.global_position + Vector3.UP * CHEST_HEIGHT)
	elif not _try_extinguisher(boss, distance, delta):
		# Sin tableros ni extintor: mantiene la distancia para provocar embestidas contra las
		# paredes.
		_aim_at(boss.global_position + Vector3.UP * CHEST_HEIGHT)
		if distance < 5.0:
			_hold("move_back")


## Sale de la nube alejándose de su centro.
func _leave_cloud(cloud: ToxicCloud, delta: float) -> void:
	var away := _player.global_position - cloud.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	_walk_to(cloud.global_position + away * (cloud.radius + 1.5), delta)


func _dodge_charge(boss: Boss) -> void:
	var side := boss.charge_direction.cross(Vector3.UP).normalized()
	var offset := _player.global_position - boss.global_position
	# Se aparta hacia el lado en que ya está de la línea de la embestida.
	var sign_side := 1.0 if offset.dot(side) >= 0.0 else -1.0
	var target := _player.global_position + side * sign_side * 3.0
	_aim_at(boss.global_position + Vector3.UP * CHEST_HEIGHT)
	var right := _player.global_basis.x
	right.y = 0.0
	var wanted := (target - _player.global_position).normalized()
	_hold("move_right" if right.dot(wanted) >= 0.0 else "move_left")


## Aturdido: todo golpe cuenta como tanque. Escopeta o pistola si tiene; si no, bate de cerca.
func _punish(boss: Boss, distance: float, delta: float) -> void:
	var state := GameState.player
	var shotgun := _slot_with("shotgun")
	var melee := _best_melee_slot()
	var pistol := _slot_with("pistol")
	var pistol_ready := pistol >= 0 and _ammo_for(state.inventory.get_slot(pistol)) > 0
	var choice := -1
	if shotgun >= 0 and _ammo_for(state.inventory.get_slot(shotgun)) > 0:
		choice = shotgun
	elif melee >= 0 and (distance <= 3.0 or not pistol_ready):
		choice = melee
	else:
		choice = pistol
	if choice >= 0 and choice != state.equipped_slot and not _player.combat.is_busy():
		if state.select_slot(choice):
			EventBus.weapon_changed.emit()
	var stack := state.equipped()
	if stack == null:
		return
	if stack.item.weapon.kind == WeaponData.KIND_RANGED:
		_aim_at(boss.global_position + Vector3.UP * TANK_HEIGHT)
		if stack.ammo_loaded > 0:
			_tap("attack")
		elif _ammo_for(stack) > 0:
			_tap("reload")
		return
	_aim_at(boss.global_position + Vector3.UP * CHEST_HEIGHT)
	if distance > 1.6:
		_walk_to(boss.global_position, delta)
	else:
		_hold("attack")


func _try_extinguisher(boss: Boss, distance: float, delta: float) -> bool:
	var slot := _slot_with("extinguisher")
	if slot < 0 or boss.model.data == null:
		return false
	var state := GameState.player
	if slot != state.equipped_slot and not _player.combat.is_busy():
		if state.select_slot(slot):
			EventBus.weapon_changed.emit()
	_aim_at(boss.global_position + Vector3.UP * CHEST_HEIGHT)
	if distance > 1.5:
		_walk_to(boss.global_position, delta)
	else:
		_hold("attack")
	return true


func _best_panel(boss: Boss) -> ElectricPanel:
	var best: ElectricPanel = null
	var best_distance := INF
	for node: Node in _game.level.navigation.get_children():
		var panel := node as ElectricPanel
		if panel == null or not panel.live:
			continue
		var distance := _flat(panel.global_position).distance_to(_flat(boss.global_position))
		# El tablero debe quedar lejos del jefe para que tenga recorrido de embestida.
		if distance > boss.data.boss.charge_min_distance + 1.0 and distance < best_distance:
			best = panel
			best_distance = distance
	return best


func _panel_bait_point(panel: ElectricPanel) -> Vector3:
	# El tablero mira hacia +Z local: el punto queda delante de él, dentro del almacén.
	var normal := panel.global_basis.z
	normal.y = 0.0
	return panel.global_position + normal.normalized() * PANEL_BAIT_DISTANCE


func _cloud_here() -> ToxicCloud:
	for node: Node in get_tree().get_nodes_in_group("toxic_cloud"):
		var cloud := node as ToxicCloud
		if cloud != null and cloud.contains(_player.global_position):
			return cloud
	return null


func _in_cloud() -> bool:
	return _cloud_here() != null


func _slot_with(item_id: String) -> int:
	return GameState.player.inventory.find_slot(item_id)


func _best_melee_slot() -> int:
	var state := GameState.player
	var best := -1
	var best_damage := 0.0
	for index: int in state.inventory.capacity():
		var stack := state.inventory.get_slot(index)
		if stack == null or not stack.is_weapon() or stack.durability.is_broken():
			continue
		var weapon := stack.item.weapon
		if (
			weapon.kind == WeaponData.KIND_MELEE
			and not weapon.stuns
			and weapon.damage > best_damage
		):
			best = index
			best_damage = weapon.damage
	return best


func _ammo_for(stack: ItemStack) -> int:
	if stack == null or stack.item.weapon == null:
		return 0
	return stack.ammo_loaded + GameState.player.inventory.count_of(stack.item.weapon.ammo_item_id)


# --- Enemigos normales ----------------------------------------------------------------------


func _fight(enemy: Enemy, delta: float) -> void:
	_choose_weapon(enemy)
	var state := GameState.player
	var stack := state.equipped()
	var distance := _player.global_position.distance_to(enemy.global_position)
	var ranged := stack != null and stack.item.weapon.kind == WeaponData.KIND_RANGED
	var height := HEAD_AIM_HEIGHT if ranged else CHEST_HEIGHT
	_aim_at(enemy.global_position + Vector3.UP * height)
	if not _has_usable_weapon() and distance > RETREAT_RANGE:
		_follow_route(delta)
		return
	if stack != null and ranged:
		if stack.ammo_loaded > 0:
			_tap("attack")
			return
		if state.inventory.count_of(stack.item.weapon.ammo_item_id) > 0:
			_tap("reload")
			return
		if not _equip_melee():
			_retreat(enemy)
		return
	if stack == null:
		_retreat(enemy)
		return
	if distance > MELEE_RANGE * 2.0:
		# Lejos: se acerca por la navegación (puede haber un escaparate en medio).
		_walk_to(enemy.global_position, delta)
	elif distance > MELEE_RANGE:
		_hold("move_forward")
	else:
		_hold("attack")


## Arma de fuego contra los resistentes (policías) y los rápidos que rodean (acechador), cuerpo
## a cuerpo contra el resto, para no gastar balas ni atraer a todo el piso con disparos.
## La escopeta se reserva para el jefe.
func _choose_weapon(enemy: Enemy) -> void:
	if _player.combat.is_busy():
		return
	var state := GameState.player
	var tough := enemy.data.max_health >= 150.0 or enemy.data.behavior == "stalker"
	var best := -1
	var best_score := -1.0
	for index: int in state.inventory.capacity():
		var stack := state.inventory.get_slot(index)
		if stack == null or not stack.is_weapon() or stack.durability.is_broken():
			continue
		var weapon := stack.item.weapon
		if stack.id() == "shotgun" or weapon.stuns:
			continue
		var score := weapon.damage
		if weapon.kind == WeaponData.KIND_RANGED:
			if _ammo_for(stack) <= 0:
				continue
			score += 1000.0 if tough else -1000.0
		if score > best_score:
			best = index
			best_score = score
	if best >= 0 and best != state.equipped_slot and state.select_slot(best):
		EventBus.weapon_changed.emit()


## Tiene un arma cuerpo a cuerpo sana o un arma de fuego con munición.
func _has_usable_weapon() -> bool:
	var state := GameState.player
	for index: int in state.inventory.capacity():
		var stack := state.inventory.get_slot(index)
		if stack == null or not stack.is_weapon() or stack.durability.is_broken():
			continue
		if stack.item.weapon.kind == WeaponData.KIND_MELEE or _ammo_for(stack) > 0:
			return true
	return false


func _equip_melee() -> bool:
	var slot := _best_melee_slot()
	if slot >= 0 and GameState.player.select_slot(slot):
		EventBus.weapon_changed.emit()
		return true
	return false


func _retreat(enemy: Enemy) -> void:
	_aim_at(enemy.global_position + Vector3.UP * CHEST_HEIGHT)
	_hold("move_back")


func _visible_enemy() -> Enemy:
	var best: Enemy = null
	var best_distance := ENGAGE_RANGE
	var space := _player.get_world_3d().direct_space_state
	var eye := _player.aim_origin()
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or enemy is Boss:
			continue
		var target := enemy.global_position + Vector3.UP * CHEST_HEIGHT
		var distance := eye.distance_to(target)
		if distance > best_distance:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, target, Rules.LAYER_WORLD)
		if not space.intersect_ray(query).is_empty():
			continue
		best = enemy
		best_distance = distance
	return best


# --- Curas y objetos ------------------------------------------------------------------------


## Usa una cura si hace falta y no hay enemigos a la vista: Neutrax o antibióticos si está
## infectado, vendas si la salud baja. Devuelve verdadero si empezó a curarse.
func _try_heal() -> bool:
	var state := GameState.player
	var wanted: Array[String] = []
	if state.infection.infected:
		wanted.append("neutrax")
		if not state.infection.is_slowed():
			wanted.append("antibiotics")
	if state.health < Rules.PLAYER_MAX_HEALTH * 0.6:
		wanted.append("bandage")
	for item_id: String in wanted:
		var slot := state.inventory.find_slot(item_id)
		if slot >= 0 and _player.healing.start(slot) == PlayerState.USE_OK:
			print("[bot] usa %s (salud %d)" % [item_id, ceili(state.health)])
			return true
	return false


## Objeto útil cercano en el suelo (munición, curas, objetos clave y armas si faltan).
func _nearby_loot() -> Pickup:
	var best: Pickup = null
	var best_distance := LOOT_RANGE
	for node: Node in get_tree().get_nodes_in_group("pickup"):
		var pickup := node as Pickup
		if pickup == null or not pickup.enabled or pickup.stack == null:
			continue
		if (
			_ignored.has(pickup.get_instance_id())
			or not pickup.is_inside_tree()
			or not _wants(pickup.stack)
		):
			continue
		var distance := _flat(pickup.global_position).distance_to(_flat(_player.global_position))
		if distance < best_distance:
			best = pickup
			best_distance = distance
	return best


func _wants(stack: ItemStack) -> bool:
	var category := stack.item.category
	if category == ItemData.CATEGORY_WEAPON:
		return _weapon_count() < 4
	return (
		category == ItemData.CATEGORY_AMMO
		or category == ItemData.CATEGORY_CONSUMABLE
		or category == ItemData.CATEGORY_KEY
	)


func _weapon_count() -> int:
	var count := 0
	for index: int in GameState.player.inventory.capacity():
		var stack := GameState.player.inventory.get_slot(index)
		if stack != null and stack.is_weapon():
			count += 1
	return count


func _collect(pickup: Pickup, delta: float) -> void:
	if pickup != _loot_target:
		_loot_target = pickup
		_loot_time = 0.0
	_loot_time += delta
	if _loot_time > 6.0:
		_ignored.append(pickup.get_instance_id())
		_loot_target = null
		_forget_ignored_later(pickup.get_instance_id())
		return
	if _flat(pickup.global_position).distance_to(_flat(_player.global_position)) < 1.4:
		_make_room()
		pickup.interact(_player)
		if pickup.enabled:
			_ignored.append(pickup.get_instance_id())
		else:
			print("[bot] recoge %s" % pickup.item_id)
		_path = PackedVector3Array()
		return
	_walk_to(pickup.global_position, delta)


## Vuelve a considerar un objeto descartado pasado un rato (la reja ya puede estar abierta).
func _forget_ignored_later(pickup_id: int) -> void:
	await get_tree().create_timer(30.0, true, true).timeout
	_ignored.erase(pickup_id)


# --- Movimiento -----------------------------------------------------------------------------


func _follow_route(delta: float) -> void:
	if _route_index >= _route.size():
		return
	var step: Array = _route[_route_index]
	var goal: Vector3 = step[0]
	var use: bool = step[1]
	var flat_distance := _flat(goal).distance_to(_flat(_player.global_position))
	if flat_distance < (INTERACT_RANGE if use else 1.0):
		if use:
			_use_nearby(goal)
		_route_index += 1
		_path = PackedVector3Array()
		return
	_walk_to(goal, delta)


## Camina hacia un punto siguiendo la navegación del piso.
func _walk_to(goal: Vector3, delta: float) -> void:
	_repath_timer -= delta
	if _path.is_empty() or _repath_timer <= 0.0 or _path_goal.distance_to(goal) > 0.5:
		_repath_timer = REPATH_TIME
		_path_goal = goal
		var map := _player.get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map, _player.global_position, goal, true)
		_path_index = 0
	while _path_index < _path.size() - 1:
		var point := _path[_path_index]
		if _flat(point).distance_to(_flat(_player.global_position)) > 0.5:
			break
		_path_index += 1
	var next := goal if _path.is_empty() else _path[_path_index]
	_aim_at(Vector3(next.x, _player.global_position.y + Rules.PLAYER_EYE_HEIGHT, next.z))
	_hold("move_forward")
	_check_stuck(delta)


func _check_stuck(delta: float) -> void:
	if _unstick_timer > 0.0:
		_unstick_timer -= delta
		_hold("move_right")
		return
	if _player.global_position.distance_to(_last_position) < 0.02:
		_stuck_timer += delta
		if _stuck_timer > 2.0:
			_stuck_timer = 0.0
			_unstick_timer = 0.5
			_path = PackedVector3Array()
	else:
		_stuck_timer = 0.0
	_last_position = _player.global_position


func _use_nearby(point: Vector3) -> void:
	var best: Interactable = null
	var best_distance := 2.0
	for node: Node in _game.level.get_children():
		var target := node as Interactable
		if target == null or not target.enabled:
			continue
		var distance := target.global_position.distance_to(point)
		if distance < best_distance:
			best = target
			best_distance = distance
	if best != null:
		_make_room()
		print("[bot] usa %s" % best.get_prompt_key())
		best.interact(_player)


## Suelta materiales (el bot no combina) si quedan menos de dos casillas libres, para que
## quepan las curas y la munición, como haría un jugador.
func _make_room() -> void:
	var inventory := GameState.player.inventory
	for index: int in inventory.capacity():
		if inventory.capacity() - inventory.used_slots() >= 2:
			return
		var stack := inventory.get_slot(index)
		if stack != null and stack.item.category == ItemData.CATEGORY_MATERIAL:
			_player.drop_stack(inventory.take_slot(index))
			EventBus.inventory_changed.emit()


## Pide mirar hacia un punto este fotograma.
func _aim_at(point: Vector3) -> void:
	_aim_point = point
	_has_aim = true


## Gira la mirada hacia el punto pedido a través de InputRouter (como lo haría el ratón).
func _apply_aim() -> void:
	if not _has_aim:
		return
	var eye := _player.aim_origin()
	var direction := _aim_point - eye
	var flat := Vector2(direction.x, direction.z)
	if flat.length() < 0.01:
		return
	var desired_yaw := atan2(-direction.x, -direction.z)
	var desired_pitch := atan2(direction.y, flat.length())
	var yaw_delta := wrapf(_player.rotation.y - desired_yaw, -PI, PI)
	var pitch_delta := _player.head.rotation.x - desired_pitch
	if Settings.get_bool("invert_y"):
		pitch_delta = -pitch_delta
	InputRouter.add_look_radians(Vector2(yaw_delta, pitch_delta))


func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


## Mantiene pulsada una acción este fotograma.
func _hold(action: String) -> void:
	_wanted[action] = true


## Pulsación corta: alterna pulsada y suelta en fotogramas seguidos.
func _tap(action: String) -> void:
	_fire_toggle = not _fire_toggle
	if _fire_toggle:
		_wanted[action] = true


func _apply_actions() -> void:
	_apply_aim()
	for action: String in [
		"move_forward", "move_back", "move_right", "move_left", "attack", "reload"
	]:
		if _wanted.has(action):
			if not Input.is_action_pressed(action):
				Input.action_press(action)
		elif Input.is_action_pressed(action):
			Input.action_release(action)


func _release_all() -> void:
	_wanted.clear()
	_apply_actions()


# --- Fin ------------------------------------------------------------------------------------


func _on_goal() -> void:
	_finish(true, "llegó a la meta")


func _on_floor_changed(floor_id: String) -> void:
	_player = _game.level.player
	if scenario.begins_with("boss"):
		_route = BOSS_ROUTE
	elif floor_id == "rooftop":
		_route = ROOFTOP_ROUTE
	else:
		_route = ROUTES.get(floor_id, [])
	_route_index = 0
	_path = PackedVector3Array()
	print("[bot] piso %s (salud %d)" % [floor_id, ceili(GameState.player.health)])


func _on_floor_change_requested(floor_id: String, _exit_id: String) -> void:
	if scenario.begins_with("boss") and floor_id == FINISH_FLOOR:
		var parts := GameState.player.keys.items.size()
		_finish(true, "llegó a la puerta de la azotea con %d objetos clave" % parts)


func _on_died() -> void:
	if not EXPECTED.has(scenario):
		_finish(false, "murió en el objetivo %d" % _route_index)


## La partida terminó: correcto si el desenlace es el esperado en el escenario.
func _on_run_finished(outcome: int) -> void:
	var names := ["rescate", "rescate perdido", "muerte", "conversión"]
	var text: String = names[outcome] if outcome >= 0 and outcome < names.size() else "?"
	if EXPECTED.has(scenario):
		var expected: int = EXPECTED[scenario]
		_finish(outcome == expected, "desenlace: %s" % text)
	else:
		_finish(false, "desenlace inesperado: %s" % text)


func _finish(success: bool, reason: String) -> void:
	if _done:
		return
	_done = true
	_release_all()
	var state := GameState.player
	var boss := get_tree().get_first_node_in_group("boss") as Boss
	var boss_text := ""
	if boss != null and boss.model != null:
		boss_text = " | jefe fase %d vida %d" % [boss.model.phase, ceili(boss.model.health)]
	print(
		(
			"[bot] %s: %s | tiempo %.1f s | salud %d | enemigos muertos %d | armas rotas %d%s"
			% [
				"COMPLETADO" if success else "FALLO",
				reason,
				_game.elapsed,
				ceili(state.health),
				_kills,
				state.weapons_broken,
				boss_text,
			]
		)
	)
	get_tree().quit(0 if success else 1)

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Combate en escena mínima: el caminante alcanza al jugador y le hace daño, el policía
## muerto deja botín, el disparo daña al enemigo y un golpe puede romper el arma.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://game/actors/enemies/enemy.tscn")
const WALKER: EnemyData = preload("res://game/data/enemies/walker.tres")
const POLICE: EnemyData = preload("res://game/data/enemies/police_zombie.tres")

var _world: Node3D
var _player: Player


func before_each() -> void:
	GameState.start_new_run()
	InputRouter.touch_mode = false
	_world = Node3D.new()
	add_child_autofree(_world)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(shape)
	_world.add_child(ground)
	_player = PLAYER_SCENE.instantiate()
	_world.add_child(_player)


func after_each() -> void:
	Input.action_release("attack")


func _spawn(data: EnemyData, at: Vector3, vest: int = -1) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.data = data
	enemy.vest_override = vest
	enemy.position = at
	_world.add_child(enemy)
	return enemy


func _press_attack() -> void:
	Input.action_press("attack")
	await wait_physics_frames(2)
	Input.action_release("attack")


func test_walker_reaches_player_and_damages() -> void:
	_spawn(WALKER, Vector3(0.0, 0.0, -6.0))
	var start_health := GameState.player.health
	for _step: int in 80:
		await wait_physics_frames(10)
		if GameState.player.health < start_health:
			break
	assert_lt(GameState.player.health, start_health, "el caminante llegó y golpeó")


func test_police_death_drops_loot() -> void:
	var police := _spawn(POLICE, Vector3(10.0, 0.0, 10.0), 1)
	await wait_physics_frames(2)
	watch_signals(EventBus)
	while not police.is_dead():
		police.take_hit(40.0, police.global_position + Vector3.UP * 0.5, true)
	assert_signal_emitted(EventBus, "enemy_died")
	var params: Array = get_signal_parameters(EventBus, "enemy_died")
	var drops: Array = params[1]
	assert_eq(drops.size(), 2, "balas y chaleco")
	var ammo: ItemStack = drops[0]
	assert_eq(ammo.id(), "pistol_ammo")
	assert_between(ammo.count, POLICE.ammo_min, POLICE.ammo_max)
	var vest: ItemStack = drops[1]
	assert_eq(vest.id(), "vest")
	assert_eq(vest.durability.fraction(), 1.0, "disparos fuera del chaleco no lo dañan")


func test_pistol_shot_damages_enemy_in_front() -> void:
	var walker := _spawn(WALKER, Vector3(0.0, 0.0, -5.0))
	await wait_physics_frames(5)
	var loaded := GameState.player.equipped().ammo_loaded
	await _press_attack()
	await wait_physics_frames(2)
	assert_lt(walker.health.health, WALKER.max_health, "la bala acertó")
	assert_eq(GameState.player.equipped().ammo_loaded, loaded - 1)
	assert_eq(NoiseSystem.last_level, Rules.NOISE_VERY_HIGH, "el disparo hace mucho ruido")


func test_reload_action_refills_magazine() -> void:
	var gun := GameState.player.equipped()
	gun.ammo_loaded = 0
	await wait_physics_frames(2)
	Input.action_press("reload")
	await wait_physics_frames(2)
	Input.action_release("reload")
	await wait_physics_frames(int(gun.item.weapon.reload_time * 60.0) + 20)
	assert_eq(gun.ammo_loaded, PlayerState.STARTING_RESERVE_AMMO, "carga la reserva")
	assert_eq(GameState.player.inventory.count_of("pistol_ammo"), 0)


func test_empty_trigger_starts_reload() -> void:
	var gun := GameState.player.equipped()
	gun.ammo_loaded = 0
	await wait_physics_frames(2)
	await _press_attack()
	await wait_physics_frames(int(gun.item.weapon.reload_time * 60.0) + 20)
	assert_gt(gun.ammo_loaded, 0, "apretar el gatillo vacío recarga")


func test_melee_hit_can_break_weapon() -> void:
	var pipe := ItemStack.new(GameState.items.get_item("pipe"), 1, 0.05)
	GameState.player.inventory.add_stack(pipe)
	GameState.player.select_slot(GameState.player.inventory.find_slot("pipe"))
	var walker := _spawn(WALKER, Vector3(0.0, 0.0, -1.4))
	await wait_physics_frames(5)
	watch_signals(EventBus)
	await _press_attack()
	await wait_physics_frames(40)
	assert_lt(walker.health.health, WALKER.max_health, "el golpe llegó")
	assert_signal_emitted(EventBus, "weapon_broken")
	assert_eq(GameState.player.weapons_broken, 1)
	assert_eq(GameState.player.inventory.count_of("pipe"), 0, "el arma rota desaparece")
	assert_eq(GameState.player.equipped().id(), "pistol", "vuelve a otra arma")

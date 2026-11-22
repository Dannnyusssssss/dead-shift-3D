extends GutTest
@warning_ignore_start("unsafe_call_argument")
## El jefe en escena mínima: la embestida contra un tablero con corriente lo aturde y apaga el
## tablero, rompe estanterías, los golpes por la espalda llegan al tanque, la nube tóxica daña
## sin pasar por el chaleco y al morir suelta la llave de la azotea.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")
const BOSS_SCENE: PackedScene = preload("res://game/actors/enemies/boss.tscn")
const TECHNICIAN: EnemyData = preload("res://game/data/enemies/technician.tres")

var _world: Node3D
var _player: Player


func before_each() -> void:
	GameState.start_new_run()
	InputRouter.touch_mode = false
	_world = Node3D.new()
	add_child_autofree(_world)
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0))
	_world.add_child(LootSpawner.new())
	_player = PLAYER_SCENE.instantiate()
	_world.add_child(_player)


func _add_box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Rules.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	_world.add_child(body)


func _spawn_boss(at: Vector3) -> Boss:
	var boss: Boss = BOSS_SCENE.instantiate()
	boss.data = TECHNICIAN
	boss.position = at
	_world.add_child(boss)
	return boss


func _wait_until(condition: Callable, frames: int) -> void:
	for _step: int in frames / 5:
		await wait_physics_frames(5)
		if condition.call():
			return


func test_charge_into_live_panel_stuns_and_shorts_it() -> void:
	# El jugador está delante de un tablero; el jefe embiste y el jugador se aparta.
	var panel := ElectricPanel.new()
	panel.position = Vector3(0.0, 0.0, 2.0)
	_world.add_child(panel)
	var boss := _spawn_boss(Vector3(0.0, 0.0, -9.0))
	_player.position = Vector3(0.0, 0.0, 0.8)
	await wait_physics_frames(2)
	boss.model.start_charge()
	boss.boss_state = Boss.B_CHARGE_WINDUP
	await _wait_until(func() -> bool: return boss.boss_state == Boss.B_CHARGING, 200)
	_player.global_position = Vector3(4.0, 0.0, 0.8)
	await _wait_until(func() -> bool: return boss.model.is_stunned(), 200)
	assert_true(boss.model.is_stunned(), "aturdido por el tablero")
	assert_false(panel.live, "el tablero se apagó")
	assert_gte(boss.model.stun_left, TECHNICIAN.boss.panel_stun - 0.5)


func test_charge_breaks_shelves() -> void:
	var shelf := BreakableShelf.new()
	shelf.position = Vector3(0.0, 0.0, -2.0)
	_world.add_child(shelf)
	var boss := _spawn_boss(Vector3(0.0, 0.0, -10.0))
	_player.position = Vector3(0.0, 0.0, 1.0)
	await wait_physics_frames(2)
	boss.model.start_charge()
	boss.boss_state = Boss.B_CHARGE_WINDUP
	await _wait_until(func() -> bool: return shelf.is_broken, 240)
	assert_true(shelf.is_broken)


func test_hits_from_behind_reach_the_tank() -> void:
	var boss := _spawn_boss(Vector3(0.0, 0.0, -5.0))
	await wait_physics_frames(2)
	# Si el jefe mira hacia -Z, el jugador (en el origen, más hacia +Z) queda a su espalda.
	boss.look_at(Vector3(0.0, 0.0, -20.0), Vector3.UP)
	var behind := boss.take_hit(20.0, boss.global_position, true)
	assert_eq(behind, 20.0 * TECHNICIAN.boss.tank_multiplier, "por la espalda: tanque")
	boss.look_at(Vector3(0.0, 0.0, 20.0), Vector3.UP)
	var front := boss.take_hit(20.0, boss.global_position, true)
	assert_eq(front, 20.0 * TECHNICIAN.boss.phase_one_front_multiplier, "de frente: traje")


func test_toxic_cloud_hurts_without_using_the_vest() -> void:
	GameState.player.vest = ItemStack.new(GameState.items.get_item("vest"))
	var vest_before := GameState.player.vest.durability.fraction()
	var cloud := ToxicCloud.new()
	cloud.warning = 0.1
	cloud.duration = 1.0
	cloud.dps = 10.0
	_world.add_child(cloud)
	cloud.global_position = _player.global_position
	await wait_physics_frames(50)
	assert_lt(GameState.player.health, Rules.PLAYER_MAX_HEALTH, "el gas daña")
	assert_eq(GameState.player.vest.durability.fraction(), vest_before, "el chaleco no lo frena")
	assert_false(GameState.player.infection.infected, "el gas no contagia")


func test_death_drops_roof_key_and_sets_flag() -> void:
	var boss := _spawn_boss(Vector3(0.0, 0.0, -6.0))
	await wait_physics_frames(2)
	watch_signals(EventBus)
	while not boss.is_dead():
		boss.model.stun(1.0)
		boss.take_hit(200.0, boss.global_position, true)
	assert_true(GameState.world.has_flag("boss_defeated"))
	assert_signal_emitted(EventBus, "enemy_died")
	var drops: Array = get_signal_parameters(EventBus, "enemy_died")[1]
	assert_eq(drops.size(), 1)
	var key: ItemStack = drops[0]
	assert_eq(key.id(), "roof_key")


## La nube se lanza con aviso: el jefe se para y hace el gesto, el punto queda marcado en el
## suelo donde estaba el jugador (a su misma altura), el bote vuela después y la nube no hace
## daño hasta pasar el gesto, el vuelo y su propio aviso. Si el jugador se aparta, no le daña.
func test_toxic_cloud_is_telegraphed_and_avoidable() -> void:
	var boss := _spawn_boss(Vector3(0.0, 0.0, -6.0))
	_player.position = Vector3(0.0, 0.0, 0.0)
	await wait_physics_frames(2)
	boss.call("_engage")
	boss.set("_player", _player)
	boss.call("_begin_throw")
	assert_eq(boss.boss_state, Boss.B_THROW, "gesto de lanzar")
	var clouds := get_tree().get_nodes_in_group("toxic_cloud")
	assert_eq(clouds.size(), 1)
	var cloud := clouds[0] as ToxicCloud
	assert_almost_eq(cloud.global_position.y, boss.global_position.y, 0.01, "en su piso")
	assert_true(cloud.contains(Vector3.ZERO), "marca donde estaba el jugador")
	assert_false(cloud.is_active())
	assert_false(cloud.is_flying(), "durante el gesto solo se ve la marca")
	var start := boss.global_position
	_player.position = Vector3(8.0, 0.0, 0.0)
	var health := GameState.player.health
	await wait_seconds(Boss.THROW_WINDUP - 0.15)
	var moved := Vector2(boss.global_position.x - start.x, boss.global_position.z - start.z)
	assert_lt(moved.length(), 0.05, "quieto durante el gesto")
	await wait_seconds(0.25)
	assert_true(cloud.is_flying(), "el bote vuela tras el gesto")
	await wait_seconds(Boss.THROW_FLIGHT)
	assert_false(cloud.is_flying())
	assert_false(cloud.is_active(), "al caer todavía avisa")
	await wait_seconds(cloud.warning + 0.5)
	assert_true(cloud.is_active())
	assert_eq(GameState.player.health, health, "el jugador se apartó a tiempo")
	var lead := Boss.THROW_WINDUP + Boss.THROW_FLIGHT + TECHNICIAN.boss.cloud_warning
	assert_gte(lead, 2.5, "tiempo de sobra para apartarse")


## La nube solo daña en su piso: el jugador justo encima (otro piso) no recibe daño aunque esté
## dentro del círculo en el plano.
func test_toxic_cloud_does_not_reach_another_floor() -> void:
	_add_box(Vector3(0.0, Rules.FLOOR_HEIGHT - 0.5, 0.0), Vector3(6.0, 1.0, 6.0))
	_player.position = Vector3(0.0, Rules.FLOOR_HEIGHT, 0.0)
	await wait_physics_frames(3)
	var cloud := ToxicCloud.new()
	cloud.warning = 0.1
	cloud.duration = 1.0
	cloud.dps = 10.0
	_world.add_child(cloud)
	cloud.global_position = Vector3.ZERO
	assert_false(cloud.contains(_player.global_position), "otro piso: fuera")
	assert_false(cloud.contains(Vector3(0.0, -Rules.FLOOR_HEIGHT, 0.0)), "piso de abajo: fuera")
	assert_true(cloud.contains(Vector3(0.5, 0.3, 0.0)), "mismo piso: dentro")
	await wait_physics_frames(50)
	assert_eq(GameState.player.health, Rules.PLAYER_MAX_HEALTH, "sin daño desde otro piso")


## El jefe no lanza la nube si el jugador está en otro piso (encima, al otro lado del atrio).
func test_boss_does_not_throw_to_another_floor() -> void:
	_add_box(Vector3(0.0, Rules.FLOOR_HEIGHT - 0.5, 0.0), Vector3(6.0, 1.0, 6.0))
	_player.position = Vector3(0.0, Rules.FLOOR_HEIGHT, 0.0)
	var boss := _spawn_boss(Vector3(0.0, 0.0, -6.0))
	await wait_physics_frames(3)
	boss.call("_engage")
	boss.set("_player", _player)
	assert_false(boss.can_throw_at(_player.global_position))
	boss.call("_begin_throw")
	assert_ne(boss.boss_state, Boss.B_THROW, "no lanza a otro piso")
	assert_eq(get_tree().get_nodes_in_group("toxic_cloud").size(), 0)


## Aturdido contra una pared (2,5 s) o un tablero (5 s): cae una sola vez, se queda en el suelo
## y se levanta una sola vez al final (antes repetía caer y levantarse en bucle).
func test_long_stun_falls_and_rises_once() -> void:
	for seconds: float in [TECHNICIAN.boss.wall_stun, TECHNICIAN.boss.panel_stun]:
		var boss := _spawn_boss(Vector3(0.0, 0.0, -6.0))
		await wait_physics_frames(3)
		boss.call("_engage")
		var view := boss.get("_model") as EnemyModel
		boss.model.stun(seconds)
		var phases: Array[int] = []
		while boss.model.is_stunned():
			await wait_physics_frames(1)
			var phase := view.stun_phase()
			if phase != EnemyModel.STUN_NONE and (phases.is_empty() or phases[-1] != phase):
				phases.append(phase)
		await wait_physics_frames(2)
		assert_eq(
			phases,
			[EnemyModel.STUN_DOWN, EnemyModel.STUN_RISE] as Array[int],
			"cae y se levanta una vez (%.1f s)" % seconds
		)
		assert_eq(view.stun_phase(), EnemyModel.STUN_NONE, "vuelve a moverse")
		boss.queue_free()
		await wait_physics_frames(1)


## El tanque (punto débil) va a la espalda: detrás del pecho, del lado por el que los golpes
## llegan al tanque, a la altura del torso y sin llegar a la cabeza.
func test_tank_hangs_on_the_back() -> void:
	var boss := _spawn_boss(Vector3(0.0, 0.0, -6.0))
	await wait_physics_frames(10)
	var tank := boss.get("_tank_mesh") as Node3D
	var local := boss.to_local(tank.global_position)
	var view := boss.get("_model") as EnemyModel
	var skeleton := view.get("_skeleton") as Skeleton3D
	var spine := boss.to_local(
		(
			skeleton.global_transform
			* skeleton.get_bone_global_pose(skeleton.find_bone("spine_03")).origin
		)
	)
	assert_gt(local.z, spine.z + 0.2, "detrás de la columna (+Z es la espalda)")
	assert_almost_eq(local.x, spine.x, 0.2, "centrado en la espalda (sigue el balanceo del torso)")
	assert_almost_eq(local.y, spine.y, 0.35, "a la altura del torso")
	var head := boss.to_local(
		skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
	)
	# El tanque va tumbado sobre la espalda a lo largo de la columna: no llega a la cabeza (la
	# distancia del eje del tanque a la cabeza supera su radio con margen).
	var half := (tank as MeshInstance3D).mesh.get_aabb().size.y * 0.5
	var radius := (tank as MeshInstance3D).mesh.get_aabb().size.x * 0.5
	var axis := boss.global_transform.basis.inverse() * tank.global_transform.basis.y.normalized()
	var closest := Geometry3D.get_closest_point_to_segment(
		head, local - axis * half, local + axis * half
	)
	assert_gt(head.distance_to(closest), radius + 0.1, "no toca la cabeza")


## Si muere en el aire (bajando una escalera, en plena embestida), el cuerpo cae al suelo en vez
## de quedarse flotando rígido en la pose de muerte.
func test_dead_body_falls_to_the_floor() -> void:
	var boss := _spawn_boss(Vector3(0.0, 3.0, -6.0))
	await wait_physics_frames(2)
	while not boss.is_dead():
		boss.model.stun(1.0)
		boss.take_hit(400.0, boss.global_position, true)
	await wait_physics_frames(90)
	assert_almost_eq(boss.global_position.y, 0.0, 0.1, "en el suelo")

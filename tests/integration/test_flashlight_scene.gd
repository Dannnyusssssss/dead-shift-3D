extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Linterna del jugador y apagón del jefe en escena: la acción enciende y apaga la luz de forma
## gradual; al empezar la pelea el piso del jefe baja sus luces sin parpadeos hasta la de
## emergencia y la recupera al vencerlo.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")
const GAME_SCRIPT: GDScript = preload("res://game/game.gd")


func after_each() -> void:
	Input.action_release("flashlight")
	GameState.forced_seed = -1
	InputRouter.gameplay_active = false
	InputRouter.menu_open = false


func _tap_flashlight() -> void:
	Input.action_press("flashlight")
	await wait_physics_frames(2)
	Input.action_release("flashlight")


func test_action_fades_the_light_in_and_out() -> void:
	GameState.start_new_run()
	var world := Node3D.new()
	add_child_autofree(world)
	var player: Player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	var light := player.flashlight.light
	# Apagada, la luz sigue en escena con un brillo que no se ve (los sombreadores se preparan al
	# dibujar cada objeto y encenderla luego no congela el juego).
	await wait_physics_frames(3)
	assert_true(light.visible, "en escena aunque esté apagada")
	assert_lte(light.light_energy, PlayerFlashlight.IDLE_ENERGY + 0.0001, "sin brillo visible")
	await _tap_flashlight()
	assert_true(GameState.player.flashlight.on)
	assert_lt(light.light_energy, PlayerFlashlight.ENERGY, "no se enciende de golpe")
	await wait_seconds(0.6)
	assert_almost_eq(light.light_energy, PlayerFlashlight.ENERGY, 0.01, "llega a su brillo")
	await _tap_flashlight()
	assert_false(GameState.player.flashlight.on)
	assert_gt(light.light_energy, 0.0, "tampoco se apaga de golpe")
	await wait_seconds(0.6)
	assert_true(light.visible, "sigue en escena")
	assert_lte(light.light_energy, PlayerFlashlight.IDLE_ENERGY + 0.0001, "vuelve al brillo mínimo")


func test_boss_blackout_fades_and_returns() -> void:
	GameState.forced_seed = 7
	var game: Game = GAME_SCRIPT.new()
	add_child_autofree(game)
	await wait_physics_frames(3)
	var boss := get_tree().get_first_node_in_group("boss") as Boss
	var section := game.level.section_at(boss.global_position)
	var lights := section.find_children("*", "OmniLight3D", false, false)
	var light := lights[0] as OmniLight3D
	var full := light.light_energy
	boss.call("_engage")
	assert_false(section.powered, "el jefe corta la energía")
	var previous := light.light_energy
	var steps := 0
	while light.light_energy > full * Rules.BLACKOUT_LIGHT_FACTOR + 0.001 and steps < 400:
		await wait_physics_frames(1)
		assert_true(light.light_energy <= previous + 0.0001, "solo baja: sin parpadeos")
		previous = light.light_energy
		steps += 1
	assert_almost_eq(light.light_energy, full * Rules.BLACKOUT_LIGHT_FACTOR, 0.01)
	assert_gt(steps, 60, "tarda en bajar (gradual)")
	# Oscuridad total: las luces del piso a cero y los paneles del techo casi apagados (solo en el
	# piso del jefe; los demás pisos conservan su material encendido).
	assert_eq(Rules.BLACKOUT_LIGHT_FACTOR, 0.0)
	var material: ShaderMaterial = section.get("_surface_material")
	assert_not_null(material, "el piso tiene su propia copia del material")
	await wait_seconds(0.3)
	var glow: float = material.get_shader_parameter("emission_scale")
	assert_almost_eq(glow, Rules.BLACKOUT_EMISSION_FACTOR, 0.01)
	for other: FloorSection in game.level.sections:
		if other == section or other.get("_surface_material") == null:
			continue
		var other_material: ShaderMaterial = other.get("_surface_material")
		assert_ne(other_material, material, "cada piso con su material")
		var other_glow: float = other_material.get_shader_parameter("emission_scale")
		assert_almost_eq(other_glow, 1.0, 0.001, other.name)
	# Dos fases: el primer golpe enorme rompe el traje y el segundo lo vence.
	boss.take_hit(100000.0, boss.global_position, true)
	await wait_physics_frames(2)
	boss.take_hit(100000.0, boss.global_position, true)
	assert_true(boss.is_dead())
	assert_true(section.powered, "vuelve la luz al vencerlo")
	await wait_seconds(Rules.BLACKOUT_FADE + 0.2)
	assert_almost_eq(light.light_energy, full, 0.01)

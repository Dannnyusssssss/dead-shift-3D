extends Node
@warning_ignore_start("unsafe_call_argument")
## Recorre puntos fijos de todos los pisos en calidad Baja y Media: guarda una captura de
## cada uno y mide FPS, tiempo de frame, llamadas de dibujo y primitivas. Sirve para detectar
## errores visibles (pantalla negra, piezas que faltan) y medir en esta máquina; no para dar
## por buena la estética. Restaura la calidad que tenía el jugador al terminar.
## Con la variable de entorno DEADSHIFT_CAPTURE_ONLY=enemigos solo hace las capturas de los
## enemigos en movimiento, con =angulos solo las de un mismo sitio desde ángulos casi iguales y
## con =objetos solo el catálogo de objetos y los contenedores, con =tiendas solo las tiendas
## cerradas, con =decorado solo el decorado, con =luz las tiendas iluminadas y el apagón del
## jefe, con =brazos cada arma en la mano, con =jefe el lanzamiento de la nube, con =intro la
## intro, con =final las escenas finales, con =despertar el despertar del guardia al empezar,
## con =parpadeo los mismos sitios girando poco a poco en
## las tres calidades, con =camaras el visor de cámaras y con =linterna el coste de la linterna
## y el fotograma más largo al encenderla (para revisar una parte sin recorrer todo).

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")
## Nombre, posición en el edificio, giro y cabeceo (grados) de cada punto.
const POINTS: Array = [
	["01_pb_seguridad", Vector3(-30.0, 0.0, -4.0), -70.0, 0.0],
	["02_pb_pasillo_oeste", Vector3(-22.0, 0.0, 0.5), -90.0, 5.0],
	["03_pb_atrio", Vector3(-9.0, 0.0, -4.6), -115.0, 12.0],
	["04_pb_escalera_mecanica", Vector3(5.0, 0.0, 3.5), -105.0, 8.0],
	["05_pb_galerias", Vector3(-3.0, 0.0, -7.5), 0.0, 0.0],
	["06_n1_atrio_desde_arriba", Vector3(0.0, 5.0, 4.4), 0.0, -32.0],
	["07_n1_pasillo_este", Vector3(20.5, 5.0, 0.0), 90.0, 0.0],
	["08_n1_escalera_servicio", Vector3(-24.8, 5.0, 4.0), 90.0, -10.0],
	["09_n2_patio_comidas", Vector3(-12.0, 10.0, -4.5), 0.0, 0.0],
	["10_n2_almacen", Vector3(12.0, 10.0, 7.5), 180.0, 0.0],
	["11_n2_atrio", Vector3(0.0, 10.0, -4.3), 180.0, -38.0],
	["12_azotea", Vector3(-10.0, 15.0, 7.0), -60.0, 0.0],
	["13_n1_nota_tecnico", Vector3(7.5, 5.0, -13.8), 0.0, -28.0],
	["14_pb_ascensor", Vector3(19.5, 0.0, 3.5), -90.0, 0.0],
	["15_n1_ropa", Vector3(-17.0, 5.0, -6.6), 0.0, -8.0],
	["16_n1_electronica", Vector3(8.0, 5.0, -6.8), 10.0, -8.0],
	["17_n1_farmacia", Vector3(-18.0, 5.0, 6.8), 180.0, -8.0],
	["18_n2_patio_comidas_mostradores", Vector3(-13.0, 10.0, -8.5), 0.0, -5.0],
	["19_n1_oficinas", Vector3(24.6, 5.0, 0.0), -90.0, -10.0],
	["20_pb_deposito", Vector3(24.6, 0.0, 0.0), -90.0, -10.0],
]
const QUALITIES: Array[int] = [SettingsSchema.QUALITY_LOW, SettingsSchema.QUALITY_MEDIUM]
const SETTLE_FRAMES: int = 30
const MEASURE_FRAMES: int = 120

var _game: Game = null
var _out_dir: String = ""
var _report: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var base := OS.get_environment("TEMP")
	if base.is_empty():
		base = OS.get_user_data_dir()
	_out_dir = base.path_join("deadshift3d-capturas").path_join("godot")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# La intro va antes de la partida: se captura sola, sin el edificio debajo.
	if OS.get_environment("DEADSHIFT_CAPTURE_ONLY") != "intro":
		_game = GAME_SCRIPT.new()
		# El despertar del guardia solo ocurre en una partida nueva justo tras la intro.
		_game.wake_up_on_start = OS.get_environment("DEADSHIFT_CAPTURE_ONLY") == "despertar"
		add_child(_game)
	_run.call_deferred()


func _run() -> void:
	var only := OS.get_environment("DEADSHIFT_CAPTURE_ONLY")
	var parts: Array[String] = [
		"enemigos",
		"angulos",
		"objetos",
		"tiendas",
		"decorado",
		"luz",
		"brazos",
		"jefe",
		"parpadeo",
		"camaras",
		"intro",
		"final",
		"despertar",
		"linterna",
	]
	if only in parts:
		if only == "final":
			await _capture_outros()
		elif only == "despertar":
			await _capture_wake_up()
		elif only == "intro":
			await _capture_intro()
		elif only == "jefe":
			await _capture_boss_throw()
		elif only == "linterna":
			await _measure_flashlight()
		elif only == "brazos":
			await _capture_arms()
		elif only == "luz":
			await _capture_spots(
				[
					["15_n1_ropa_luz", Vector3(-17.0, 5.0, -6.6), 0.0, -8.0],
					["16_n1_electronica_luz", Vector3(8.0, 5.0, -6.8), 10.0, -8.0],
					["12_azotea_luz", Vector3(-10.0, 15.0, 7.0), -60.0, 0.0],
				]
			)
			GameState.player.flashlight.on = true
			await _capture_spots(
				[["16_n1_electronica_linterna", Vector3(8.0, 5.0, -6.8), 10.0, -20.0]]
			)
			GameState.player.flashlight.on = false
			await _capture_blackout()
		elif only == "camaras":
			await _capture_cameras()
		elif only == "parpadeo":
			await _capture_flicker()
		elif only == "decorado":
			await _capture_decor()
		elif only == "tiendas":
			await _capture_closed_stores()
		elif only == "enemigos":
			await _capture_enemies_moving()
		elif only == "angulos":
			await _capture_angles()
		else:
			await _capture_catalog()
		print("[captura] %s en %s" % [only, _out_dir])
		get_tree().quit(0)
		return
	var original_quality := Settings.get_int("quality")
	_report.append("punto | calidad | FPS | frame ms | draw calls | primitivas")
	for quality: int in QUALITIES:
		Settings.set_value("quality", quality)
		for point: Array in POINTS:
			var label: String = point[0]
			var position: Vector3 = point[1]
			var yaw: float = point[2]
			var pitch: float = point[3]
			var player := _game.level.player
			player.set_blocked("capture", true)
			for node: Node in get_tree().get_nodes_in_group("enemy"):
				node.set_physics_process(false)
			player.global_position = position
			player.rotation.y = deg_to_rad(yaw)
			player.head.rotation.x = deg_to_rad(pitch)
			for _frame: int in SETTLE_FRAMES:
				await get_tree().process_frame
			await _measure(label, quality)
	Settings.set_value("quality", original_quality)
	await _capture_broken_glass()
	await _capture_impacts()
	await _capture_cameras()
	await _capture_blackout()
	await _capture_interface()
	await _capture_enemies_moving()
	await _capture_angles()
	await _capture_catalog()
	await _capture_closed_stores()
	await _capture_decor()
	await _capture_arms()
	await _capture_boss_throw()
	await _capture_intro()
	await _capture_outros()
	var report_path := _out_dir.path_join("medicion.txt")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_report) + "\n")
		file.close()
	print("[captura] %d imágenes y medición en %s" % [POINTS.size() * QUALITIES.size(), _out_dir])
	for line: String in _report:
		print("[captura] " + line)
	get_tree().quit(0)


func _measure(label: String, quality: int) -> void:
	var draws := 0.0
	var primitives := 0.0
	var started := Time.get_ticks_usec()
	for _frame: int in MEASURE_FRAMES:
		await get_tree().process_frame
		draws = maxf(draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives = maxf(
			primitives, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		)
	var seconds := float(Time.get_ticks_usec() - started) / 1000000.0
	var fps := float(MEASURE_FRAMES) / maxf(seconds, 0.0001)
	var image := get_viewport().get_texture().get_image()
	var name := "%s_q%d.png" % [label, quality]
	image.save_png(_out_dir.path_join(name))
	_report.append(
		"%s | %d | %.0f | %.1f | %d | %d" % [label, quality, fps, 1000.0 / fps, draws, primitives]
	)


## Tiendas cerradas vistas desde el pasillo: persiana, puerta cerrada y escaparate con fondo.
func _capture_closed_stores() -> void:
	await _capture_spots(
		[
			["38_cerrada_jugueteria", Vector3(-2.0, 0.0, 1.5), 180.0, 0.0],
			["38_cerrada_boutique", Vector3(-7.0, 5.0, 4.6), 180.0, 0.0],
			["38_cerrada_joyeria", Vector3(19.0, 5.0, -1.5), 0.0, 0.0],
		]
	)


## Decorado: ascensor con cabina, baños, cafetería, monitores de cámaras y desorden.
func _capture_decor() -> void:
	await _capture_spots(
		[
			["39_ascensor", Vector3(18.5, 0.0, 3.5), -90.0, 4.0],
			["40_banos_pb", Vector3(-21.0, 0.0, 7.4), 180.0, -8.0],
			["41_banos_n1", Vector3(-25.2, 5.0, -2.0), 90.0, -8.0],
			["42_cafeteria", Vector3(8.0, 0.0, 7.4), 180.0, -10.0],
			["43_monitores", Vector3(-28.0, 0.0, -2.5), 0.0, -5.0],
			["44_desorden_pasillo", Vector3(-12.0, 0.0, 4.5), -100.0, -20.0],
		]
	)


## Cada arma en la mano, en primera persona y vista de lado (cámara aparte junto al brazo), para
## ver si el puño la sujeta o la atraviesa.
func _capture_arms() -> void:
	var player := _game.level.player
	player.set_blocked("capture", true)
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		node.set_physics_process(false)
	player.global_position = Vector3(-21.0, 0.0, 0.5)
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	var state := GameState.player
	var side := Camera3D.new()
	side.fov = 40.0
	player.head.add_child(side)
	side.position = Vector3(0.75, -0.25, -0.35)
	side.rotation.y = deg_to_rad(90.0)
	var ids := Array(GameState.items.ids())
	ids.sort()
	for item_id: String in ids:
		var item := GameState.items.get_item(item_id)
		if item.category != ItemData.CATEGORY_WEAPON:
			continue
		# Se deja sitio en la mochila: el arma anterior se quita (salvo la pistola inicial).
		for slot: int in state.inventory.capacity():
			var held := state.inventory.get_slot(slot)
			if (
				held != null
				and held.item.category == ItemData.CATEGORY_WEAPON
				and held.id() != "pistol"
			):
				state.inventory.take_slot(slot)
		if state.inventory.find_slot(item_id) < 0:
			state.inventory.add_stack(ItemStack.new(item))
		state.select_slot(state.inventory.find_slot(item_id))
		EventBus.weapon_changed.emit()
		for _frame: int in SETTLE_FRAMES:
			await get_tree().process_frame
		_save_image("45_brazos_%s" % item_id)
		side.make_current()
		for _frame: int in 4:
			await get_tree().process_frame
		_save_image("46_brazos_lado_%s" % item_id)
		player.camera.make_current()
	side.queue_free()


## Lanzamiento de la nube del jefe en sus fases: marca en el suelo, bote en el aire y nube
## activa (con la linterna encendida, porque el combate es a oscuras).
func _capture_boss_throw() -> void:
	var boss := get_tree().get_first_node_in_group("boss") as Boss
	if boss == null:
		return
	var player := _game.level.player
	player.set_blocked("capture", true)
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		if node != boss:
			node.set_physics_process(false)
	# En el centro del almacén del Nivel 2: el jefe a un lado, el jugador al otro y la marca en
	# medio (a más de un radio del jugador).
	var section := _game.level.find_section("level_2")
	var room := section.find_room("warehouse")
	var center := (
		section.global_position + Vector3(room.rect.get_center().x, 0.0, room.rect.get_center().y)
	)
	boss.global_position = center + Vector3(-5.0, 0.0, 0.0)
	var spot := center + Vector3(5.0, 0.0, 0.0)
	player.global_position = spot
	player.rotation.y = deg_to_rad(90.0)
	player.head.rotation.x = deg_to_rad(-22.0)
	GameState.player.flashlight.on = true
	boss.call("_engage")
	for _frame: int in 30:
		await get_tree().process_frame
	boss.set("_player", player)
	player.global_position = center
	boss.call("_begin_throw")
	player.global_position = spot
	for frame: int in 200:
		await get_tree().physics_frame
		if frame == 25:
			_save_image("47_jefe_marca")
		elif frame == 70:
			_save_image("47_jefe_bote")
		elif frame == 190:
			_save_image("47_jefe_nube")
	await _capture_boss_views(boss, center)
	GameState.player.flashlight.on = false
	await _measure_flashlight()


## El jefe de frente y de espaldas (el tanque va a la espalda), corriendo, y tumbado durante un
## aturdido largo (cae una vez y se queda en el suelo).
func _capture_boss_views(boss: Boss, center: Vector3) -> void:
	var player := _game.level.player
	for cloud: Node in get_tree().get_nodes_in_group("toxic_cloud"):
		cloud.queue_free()
	boss.set_physics_process(false)
	boss.global_position = center
	for view: Array in [["48_jefe_frente", -1.0], ["48_jefe_espalda", 1.0]]:
		boss.look_at(center + Vector3(0.0, 0.0, -1.0), Vector3.UP)
		var side: float = view[1]
		# Delante del jefe es -Z: de frente el jugador mira hacia +Z (giro de media vuelta).
		player.global_position = center + Vector3(0.0, 0.0, 3.2 * side)
		player.rotation.y = PI if side < 0.0 else 0.0
		player.head.rotation.x = deg_to_rad(-8.0)
		for _frame: int in 20:
			await get_tree().process_frame
		_save_image(view[0])
	# Corriendo, de espaldas y de lado: el tanque tiene que ir pegado a lo largo de la espalda.
	(boss.get("_model") as EnemyModel).play_named("run")
	for view: Array in [
		["48_jefe_corriendo_espalda", Vector3(0.0, 0.0, 3.2), 0.0],
		["48_jefe_corriendo_lado", Vector3(3.2, 0.0, 0.0), 90.0]
	]:
		player.global_position = center + (view[1] as Vector3)
		player.rotation.y = deg_to_rad(view[2] as float)
		player.head.rotation.x = deg_to_rad(-8.0)
		for _frame: int in 17:
			await get_tree().process_frame
		_save_image(view[0])
	boss.set_physics_process(true)
	boss.model.stun(5.0)
	for _frame: int in 120:
		await get_tree().physics_frame
	_save_image("48_jefe_aturdido_suelo")


## Coste de la linterna en dos sitios (tienda de electrónica y pasillo largo del Nivel 1), en
## calidad Media y Alta (con sombras): llamadas de dibujo y tiempo de frame apagada y encendida.
func _measure_flashlight() -> void:
	var player := _game.level.player
	var original := Settings.get_int("quality")
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		node.set_physics_process(false)
	var spots: Array = [
		["electronica", Vector3(8.0, 5.0, -6.8), 10.0],
		["pasillo", Vector3(20.5, 5.0, 0.0), 90.0],
	]
	for quality: int in [SettingsSchema.QUALITY_MEDIUM, SettingsSchema.QUALITY_HIGH]:
		Settings.set_value("quality", quality)
		for spot: Array in spots:
			player.global_position = spot[1]
			player.rotation.y = deg_to_rad(spot[2])
			player.head.rotation.x = deg_to_rad(-8.0)
			for state: bool in [false, true]:
				GameState.player.flashlight.on = state
				# Fotograma más largo justo al encender (un parón saldría aquí).
				var worst := 0.0
				for _frame: int in SETTLE_FRAMES:
					var before := Time.get_ticks_usec()
					await get_tree().process_frame
					worst = maxf(worst, float(Time.get_ticks_usec() - before) / 1000.0)
				if state:
					print(
						(
							"[captura] linterna %s q%d: peor fotograma al encender %.1f ms"
							% [spot[0], quality, worst]
						)
					)
				var label: String = "49_linterna_%s_%s" % [spot[0], "si" if state else "no"]
				await _measure(label, quality)
	GameState.player.flashlight.on = false
	Settings.set_value("quality", original)
	for line: String in _report.slice(-8):
		print("[captura] " + line)


## La intro en sus momentos clave (segundos desde el principio).
func _capture_intro() -> void:
	var intro := Intro.new()
	add_child(intro)
	var moments: Array = [
		[2.5, "48_intro_central"],
		[7.0, "48_intro_alarma"],
		[11.5, "48_intro_caida"],
		[13.5, "48_intro_caidos"],
		[16.5, "48_intro_viaje"],
		[22.5, "48_intro_dos_horas"],
	]
	var elapsed := 0.0
	for moment: Array in moments:
		var at: float = moment[0]
		await get_tree().create_timer(at - elapsed).timeout
		elapsed = at
		if not is_instance_valid(intro):
			break
		_save_image(moment[1])
	if is_instance_valid(intro):
		intro.queue_free()
	if _game != null:
		_game.level.player.camera.make_current()


## Despertar del guardia en la sala de seguridad al empezar (primera persona), por momentos.
func _capture_wake_up() -> void:
	var moments: Array = [
		[0.4, "50_despertar_cabeza"],
		[1.2, "50_despertar_incorpora"],
		[2.0, "50_despertar_sentado"],
		[2.6, "50_despertar_levanta"],
		[3.6, "50_despertar_de_pie"],
	]
	var elapsed := 0.0
	for moment: Array in moments:
		var at: float = moment[0]
		await get_tree().create_timer(at - elapsed).timeout
		elapsed = at
		_save_image(moment[1])


## Escenas finales (rescate, caída y rescate perdido) en sus momentos clave, en la azotea, con
## la pantalla final encima en pleno vuelo (como en la partida).
func _capture_outros() -> void:
	var pad := _game.level.helipad_point()
	var end_screen := _game.get("_end_screen") as EndScreen
	var outcomes: Dictionary = {
		RunStats.OUTCOME_RESCUED: "rescate",
		RunStats.OUTCOME_CRASHED: "caida",
		RunStats.OUTCOME_LOST: "perdido",
	}
	for outcome: int in outcomes:
		var outro := Outro.new()
		outro.setup(_game.level, pad, pad + Vector3(2.5, 0.0, 1.5), outcome)
		outro.results_time.connect(
			func() -> void:
				var stats := RunStats.from_state(GameState.player, outcome, 600.0)
				end_screen.show_result(stats, false, GameState.difficulty, true)
		)
		add_child(outro)
		var name: String = outcomes[outcome]
		var moments: Array = [
			[1.8, "aterriza"], [3.6, "sube"], [6.5, "se_va"], [9.5, "final"], [14.0, "despues"]
		]
		var elapsed := 0.0
		for moment: Array in moments:
			var at: float = moment[0]
			await get_tree().create_timer(at - elapsed).timeout
			elapsed = at
			_save_image("49_final_%s_%s" % [name, moment[1]])
		end_screen.visible = false
		outro.queue_free()
		await get_tree().process_frame
	_game.level.player.camera.make_current()


## Captura una lista de puntos [nombre, posición, giro, cabeceo] con los enemigos quietos.
func _capture_spots(spots: Array) -> void:
	var player := _game.level.player
	player.set_blocked("capture", true)
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		node.set_physics_process(false)
	for spot: Array in spots:
		player.global_position = spot[1]
		player.rotation.y = deg_to_rad(spot[2])
		player.head.rotation.x = deg_to_rad(spot[3])
		for _frame: int in SETTLE_FRAMES:
			await get_tree().process_frame
		_save_image(spot[0])


## Todos los objetos del catálogo en el suelo del pasillo oeste de la planta baja, de cinco en
## cinco y vistos de cerca (con su nombre flotando), y los tres contenedores cerrados y abiertos.
func _capture_catalog() -> void:
	var player := _game.level.player
	player.set_blocked("capture", true)
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		node.set_physics_process(false)
	var base := Vector3(-21.0, 0.0, -0.5)
	player.global_position = base + Vector3(0.0, 0.0, 2.6)
	player.rotation.y = 0.0
	player.head.rotation.x = deg_to_rad(-26.0)
	var ids := Array(GameState.items.ids())
	ids.sort()
	for batch: int in range(0, ids.size(), 5):
		var placed: Array[Node] = []
		for index: int in mini(5, ids.size() - batch):
			var pickup := Pickup.new()
			pickup.item_id = ids[batch + index]
			_game.level.add_child(pickup)
			pickup.global_position = base + Vector3(-1.8 + 0.9 * index, 0.0, 0.0)
			placed.append(pickup)
		for _frame: int in SETTLE_FRAMES:
			await get_tree().process_frame
		_save_image("36_objetos_%02d" % (batch / 5))
		for node: Node in placed:
			node.queue_free()
	var boxes: Array[LootContainer] = []
	for kind: int in 3:
		var box := LootContainer.new()
		box.kind = kind
		box.contents = PackedStringArray(["neutrax:1", "batteries:1"])
		box.facing = PI
		_game.level.add_child(box)
		box.global_position = base + Vector3(-1.4 + kind * 1.4, 0.0, -0.4)
		boxes.append(box)
	for _frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	_save_image("37_contenedores_cerrados")
	for box: LootContainer in boxes:
		box.interact(player)
	for _frame: int in 24:
		await get_tree().process_frame
	_save_image("37_contenedores_abiertos")
	for box: LootContainer in boxes:
		box.queue_free()


## Rayas y parpadeos: los mismos sitios girando de 2 en 2 grados, en las tres calidades y con la
## linterna encendida (en Alta proyecta sombra). De una imagen a la siguiente no deben aparecer
## rayas ni zonas que se apaguen de golpe.
func _capture_flicker() -> void:
	var spots: Array = [
		["41_quiosco_techo", Vector3(-16.0, 0.0, -3.0), 180.0, 25.0],
		["42_n2_comidas", Vector3(-12.0, 10.0, -4.5), 0.0, -30.0],
		["43_pb_pasillo_pared", Vector3(-22.0, 0.0, 0.5), -60.0, 0.0],
	]
	var original_quality := Settings.get_int("quality")
	var player := _game.level.player
	player.set_blocked("capture", true)
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		node.set_physics_process(false)
	GameState.player.flashlight.on = true
	for quality: int in [
		SettingsSchema.QUALITY_LOW, SettingsSchema.QUALITY_MEDIUM, SettingsSchema.QUALITY_HIGH
	]:
		Settings.set_value("quality", quality)
		for spot: Array in spots:
			for step: int in 5:
				var offset := -4.0 + 2.0 * float(step)
				player.global_position = spot[1]
				player.rotation.y = deg_to_rad(float(spot[2]) + offset)
				player.head.rotation.x = deg_to_rad(spot[3])
				for _frame: int in SETTLE_FRAMES:
					await get_tree().process_frame
				_save_image("%s_q%d_%+d" % [spot[0], quality, int(offset)])
	GameState.player.flashlight.on = false
	Settings.set_value("quality", original_quality)


## Mismo sitio desde tres ángulos casi iguales (giro de 3 grados): las paredes, marcos,
## barandillas y rótulos no deben cambiar de una a otra.
func _capture_angles() -> void:
	var spots: Array = [
		["31_quiosco", Vector3(-16.0, 0.0, -3.8), 180.0, 10.0],
		["32_escalera_ascensor", Vector3(19.5, 0.0, 3.5), -90.0, 0.0],
		["33_jardinera", Vector3(-6.0, 0.0, 4.5), 180.0, -10.0],
		["34_atrio_desde_n1", Vector3(0.0, 5.0, 4.4), 0.0, -32.0],
		["35_escalera_mecanica", Vector3(9.5, 0.0, -4.0), -70.0, 4.0],
	]
	var player := _game.level.player
	player.set_blocked("capture", true)
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		node.set_physics_process(false)
	for spot: Array in spots:
		for offset: float in [-3.0, 0.0, 3.0]:
			player.global_position = spot[1]
			player.rotation.y = deg_to_rad(float(spot[2]) + offset)
			player.head.rotation.x = deg_to_rad(spot[3])
			for _frame: int in SETTLE_FRAMES:
				await get_tree().process_frame
			_save_image("%s_%+d" % [spot[0], int(offset)])


## Un enemigo de cada tipo persiguiendo al jugador por el pasillo este del Nivel 1, en dos
## momentos (tiene que verse de frente, la cara, no de espaldas) y después muerto en el suelo.
func _capture_enemies_moving() -> void:
	var player := _game.level.player
	player.set_blocked("capture", true)
	var seen: Dictionary = {}
	for floor_id: String in ["ground_floor", "level_1", "level_2"]:
		for enemy: Enemy in _game.level.enemies_on_floor(floor_id):
			if enemy is Boss or seen.has(enemy.data.model_id):
				continue
			seen[enemy.data.model_id] = true
			for node: Node in get_tree().get_nodes_in_group("enemy"):
				node.set_physics_process(false)
			player.global_position = Vector3(23.5, 5.0, -1.0)
			player.rotation.y = deg_to_rad(90.0)
			player.head.rotation.x = deg_to_rad(-4.0)
			var home := enemy.global_position
			enemy.global_position = Vector3(20.5, 5.0, -1.0)
			enemy.set_physics_process(true)
			enemy.call("_start_chase")
			for frame: int in 24:
				await get_tree().physics_frame
				if frame == 6:
					_save_image("30_enemigo_%s_a" % enemy.data.model_id)
			_save_image("30_enemigo_%s_b" % enemy.data.model_id)
			# Muerto en el suelo, mirando hacia abajo: sin grietas entre las partes del cuerpo.
			enemy.call("_die")
			player.head.rotation.x = deg_to_rad(-45.0)
			for _frame: int in 120:
				await get_tree().physics_frame
			_save_image("30_enemigo_%s_c_muerto" % enemy.data.model_id)
			player.head.rotation.x = deg_to_rad(-4.0)
			enemy.set_physics_process(false)
			enemy.global_position = home


## Golpes y una muerte delante del jugador en el pasillo este del Nivel 1: salpicaduras,
## manchas, marcas de bala y escombros (y lo mismo con «Reducir sangre»).
func _capture_impacts() -> void:
	var player := _game.level.player
	player.global_position = Vector3(19.0, 5.0, -1.0)
	player.rotation.y = deg_to_rad(-80.0)
	player.head.rotation.x = deg_to_rad(-22.0)
	var gore := Settings.get_bool("reduce_gore")
	for reduced: bool in [false, true]:
		Settings.set_value("reduce_gore", reduced)
		var target := Vector3(21.8, 5.0, -1.6)
		for index: int in 4:
			EventBus.enemy_hit.emit(
				target + Vector3(0, 1.2, 0.2 * index), Vector3.RIGHT, index % 2 == 0
			)
		EventBus.enemy_died.emit(target + Vector3(0, 0, 0.8), [] as Array[ItemStack])
		EventBus.surface_hit.emit(Vector3(21.0, 6.6, -5.85), Vector3.BACK)
		EventBus.surface_hit.emit(Vector3(21.4, 6.3, -5.85), Vector3.BACK)
		EventBus.debris.emit(target + Vector3(0, 1.0, -1.0))
		for _frame: int in 6:
			await get_tree().process_frame
		_save_image("25_impactos" + ("_sin_sangre" if reduced else ""))
		for _frame: int in SETTLE_FRAMES:
			await get_tree().process_frame
		_save_image("26_manchas" + ("_sin_sangre" if reduced else ""))
	Settings.set_value("reduce_gore", gore)


## Escaparate de electrónica del Nivel 1 roto, visto desde el pasillo (trozos y hueco).
func _capture_broken_glass() -> void:
	for node: Node in _game.level.find_children(
		"glass_electronics_store", "GlassPanes", true, false
	):
		var panes := node as GlassPanes
		for index: int in panes.pane_count():
			panes.break_pane(index)
	var player := _game.level.player
	player.global_position = Vector3(11.6, 5.0, -3.6)
	player.rotation.y = 0.0
	player.head.rotation.x = deg_to_rad(-30.0)
	for _frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	_save_image("21_n1_escaparate_roto")


## Visor de cámaras desde la sala de seguridad: una captura y una medición por cámara (FPS con
## el monitor abierto, que renderiza la escena dos veces).
func _capture_cameras() -> void:
	var player := _game.level.player
	player.set_blocked("capture", false)
	player.global_position = Vector3(-28.0, 0.0, -3.5)
	await get_tree().process_frame
	var view := _game.find_children("*", "CameraView", true, false)[0] as CameraView
	EventBus.cameras_requested.emit()
	var count := CameraSpots.from_floors(GameState.CATALOG.floors).size()
	for index: int in count:
		for _frame: int in SETTLE_FRAMES:
			await get_tree().process_frame
		await _measure("24_camara_%d" % (index + 1), Settings.get_int("quality"))
		view.cycle(1)
	view.close()
	player.set_blocked("capture", true)


## Apagón del jefe en el almacén del Nivel 2: a oscuras con las luces de emergencia y luego con
## la linterna encendida.
func _capture_blackout() -> void:
	var boss := get_tree().get_first_node_in_group("boss") as Boss
	if boss == null:
		return
	boss.call("_engage")
	boss.set_physics_process(false)
	var player := _game.level.player
	player.global_position = Vector3(5.0, 10.0, 7.2)
	player.rotation.y = deg_to_rad(200.0)
	player.head.rotation.x = deg_to_rad(-5.0)
	for _frame: int in int((Rules.BLACKOUT_FADE + 0.5) * 60.0):
		await get_tree().process_frame
	_save_image("22_n2_apagon")
	GameState.player.flashlight.on = true
	for _frame: int in 40:
		await get_tree().process_frame
	_save_image("23_n2_apagon_linterna")
	GameState.player.flashlight.on = false


## Capturas de la interfaz con objetos de ejemplo: mochila, combinar, cuaderno, mapa (abierto
## desde el plano de la mochila, en el Nivel 1), nota del técnico y curación.
func _capture_interface() -> void:
	var state := GameState.player
	var items := GameState.items
	state.inventory.add_stack(ItemStack.new(items.get_item("bat"), 1, 0.7))
	state.inventory.add_item(items.get_item("nails"), 4)
	state.inventory.add_item(items.get_item("bandage"), 2)
	state.inventory.add_item(items.get_item("rag"), 1)
	state.inventory.add_item(items.get_item("bottle"), 2)
	state.keys.add("phone_antenna")
	state.keys.add("security_key")
	state.keys.add("mall_map")
	GameState.world.set_flag(Discovery.NOTE_FLAG)
	EventBus.inventory_changed.emit()
	state.take_damage(45.0)
	var panel := _game.find_children("*", "InventoryPanel", true, false)[0] as InventoryPanel
	var player := _game.level.player
	player.set_blocked("capture", false)
	for tab: int in [
		InventoryPanel.TAB_BAG, InventoryPanel.TAB_COMBINE, InventoryPanel.TAB_NOTEBOOK
	]:
		panel.open(tab)
		if tab == InventoryPanel.TAB_BAG:
			panel.call("_on_tile_pressed", 0)
		for _frame: int in 10:
			await get_tree().process_frame
		_save_image("ui_%d_mochila" % tab)
		panel.close()
	player.global_position = Vector3(8.0, 5.0, -10.0)
	await get_tree().process_frame
	panel.open()
	await get_tree().process_frame
	(panel.find_child("MapButton", true, false) as TapButton).pressed.emit()
	for _frame: int in 10:
		await get_tree().process_frame
	_save_image("ui_4_mapa")
	(_game.find_children("*", "MapView", true, false)[0] as MapView).close()
	EventBus.note_opened.emit("technician")
	for _frame: int in 10:
		await get_tree().process_frame
	_save_image("ui_5_nota")
	(_game.find_children("*", "NoteView", true, false)[0] as NoteView).close()
	var slot := state.inventory.find_slot("bandage")
	player.healing.start(slot)
	for _frame: int in 40:
		await get_tree().process_frame
	_save_image("ui_6_curacion")
	player.healing.cancel()
	# Teléfono armado: botón de llamar y su confirmación, con todos los objetos clave.
	for part: String in Rules.PHONE_PARTS:
		state.keys.add(part)
	state.keys.add("roof_key")
	state.keys.assemble_phone()
	panel.open(InventoryPanel.TAB_BAG)
	for _frame: int in 10:
		await get_tree().process_frame
	_save_image("ui_7_llamar")
	panel.call("_on_call")
	for _frame: int in 10:
		await get_tree().process_frame
	_save_image("ui_8_llamar_confirmar")
	panel.close()


func _save_image(label: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out_dir.path_join(label + ".png"))

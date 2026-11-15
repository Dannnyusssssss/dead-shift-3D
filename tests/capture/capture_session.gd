extends Node
@warning_ignore_start("unsafe_call_argument")
## Recorre puntos fijos de todos los pisos en calidad Baja y Media: guarda una captura de
## cada uno y mide FPS, tiempo de frame, llamadas de dibujo y primitivas. Sirve para detectar
## errores visibles (pantalla negra, piezas que faltan) y medir en esta máquina; no para dar
## por buena la estética. Restaura la calidad que tenía el jugador al terminar.

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
	_game = GAME_SCRIPT.new()
	add_child(_game)
	_run.call_deferred()


func _run() -> void:
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
	await _capture_interface()
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


## Capturas de la interfaz con objetos de ejemplo: mochila, combinar, cuaderno y curación.
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
	var slot := state.inventory.find_slot("bandage")
	player.healing.start(slot)
	for _frame: int in 40:
		await get_tree().process_frame
	_save_image("ui_3_curacion")


func _save_image(label: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out_dir.path_join(label + ".png"))

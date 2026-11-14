extends Node
@warning_ignore_start("unsafe_call_argument")
## Recorre puntos fijos de todos los pisos en calidad Baja y Media: guarda una captura de
## cada uno y mide FPS, tiempo de frame, llamadas de dibujo y primitivas. Sirve para detectar
## errores visibles (pantalla negra, piezas que faltan) y medir en esta máquina; no para dar
## por buena la estética. Restaura la calidad que tenía el jugador al terminar.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")
## Nombre, piso (y salida por la que se llega), posición y giro (grados) de cada punto.
const POINTS: Array = [
	["1_sala_seguridad", "ground_floor", "stairs_up", Vector3(-6.5, 0.0, 2.5), -60.0],
	["2_pasillo_oeste", "ground_floor", "stairs_up", Vector3(1.5, 0.0, 0.0), -90.0],
	["3_ferreteria", "ground_floor", "stairs_up", Vector3(11.0, 0.0, -4.0), 0.0],
	["4_deportes", "ground_floor", "stairs_up", Vector3(19.0, 0.0, 4.0), 180.0],
	["5_pasillo_este", "ground_floor", "stairs_up", Vector3(39.0, 0.0, 0.0), 90.0],
	["6_nivel1_pasillo", "level_1", "stairs_down", Vector3(36.0, 0.0, 0.0), 90.0],
	["7_nivel1_farmacia", "level_1", "stairs_down", Vector3(19.0, 0.0, 9.0), 0.0],
	["8_nivel2_almacen", "level_2", "stairs_down", Vector3(19.0, 0.0, 4.5), 180.0],
	["9_nivel2_personal", "level_2", "stairs_down", Vector3(11.0, 0.0, -5.0), 0.0],
	["10_azotea", "rooftop", "stairs_down", Vector3(32.5, 0.0, 9.0), 90.0],
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
			var floor_id: String = point[1]
			var exit_id: String = point[2]
			var position: Vector3 = point[3]
			var yaw: float = point[4]
			if _game.level.floor_data.id != floor_id:
				_game.change_floor(floor_id, exit_id)
				while _game.changing_floor:
					await get_tree().process_frame
			var player := _game.level.player
			player.set_blocked("capture", true)
			for node: Node in get_tree().get_nodes_in_group("enemy"):
				node.set_physics_process(false)
			player.global_position = position
			player.rotation.y = deg_to_rad(yaw)
			for _frame: int in SETTLE_FRAMES:
				await get_tree().process_frame
			await _measure(label, quality)
	Settings.set_value("quality", original_quality)
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

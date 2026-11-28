extends Node
@warning_ignore_start("unsafe_call_argument")
## Mide cuánto cuesta calcular cada fotograma en sitios fijos con los enemigos activos (el
## jugador quieto e invencible) y cuánto baja al apagar cada parte: enemigos, objetos del
## suelo, interfaz, edificio, jugador y audio. Sirve para saber dónde se va el tiempo; las
## cifras son de esta máquina sin dibujar (en el navegador la lógica es varias veces más lenta).

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")
## Nombre, posición, giro (grados) y si se lanzan oleadas.
const SCENARIOS: Array = [
	["pb_pasillo_oeste", Vector3(-22.0, 0.0, 0.5), -90.0, false],
	["n1_pasillo_este", Vector3(20.5, 5.0, 0.0), 90.0, false],
	["azotea_oleadas", Vector3(-10.0, 15.0, 7.0), -60.0, true],
]
const SETTLE_FRAMES: int = 120
const MEASURE_FRAMES: int = 300
const PARTS: Array[String] = ["enemigos", "objetos", "interfaz", "edificio", "jugador", "audio"]

var _game: Game = null
var _report: PackedStringArray = PackedStringArray()
var _invincible: bool = true


func _ready() -> void:
	_game = GAME_SCRIPT.new()
	add_child(_game)
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	if _invincible and GameState.player != null:
		GameState.player.health = Rules.PLAYER_MAX_HEALTH
		GameState.player.infection.exposure = 0.0


func _run() -> void:
	for _frame: int in 60:
		await get_tree().process_frame
	_report.append(
		"escenario | parte apagada | frame medio ms | p95 ms | max ms | proceso ms | física ms"
	)
	for scenario: Array in SCENARIOS:
		await _place(scenario)
		_report.append(_counts(str(scenario[0])))
		await _measure(str(scenario[0]), "ninguna")
		for part: String in PARTS:
			var restore := _switch_off(part)
			for _frame: int in 30:
				await get_tree().process_frame
			await _measure(str(scenario[0]), part)
			restore.call()
			for _frame: int in 30:
				await get_tree().process_frame
	for line: String in _report:
		print("[banco] " + line)
	get_tree().quit(0)


func _place(scenario: Array) -> void:
	var player := _game.level.player
	player.set_blocked("banco", true)
	player.global_position = scenario[1]
	player.rotation.y = deg_to_rad(scenario[2])
	if scenario[3]:
		_game.level.place_player_at_exit("rooftop", "stairs_down")
		for _frame: int in 10:
			await get_tree().process_frame
		_game.call("_make_spawner", "BancoOleadas")
		player.global_position = scenario[1]
	for _frame: int in SETTLE_FRAMES:
		await get_tree().process_frame


func _counts(label: String) -> String:
	var enemies := _game.level.active_enemies().size()
	var awake := 0
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		if node.can_process():
			awake += 1
	var pickups := 0
	for node: Node in get_tree().get_nodes_in_group("pickup"):
		if node.can_process():
			pickups += 1
	return (
		"%s: nodos %d, enemigos activos %d (procesando %d), objetos procesando %d,"
		+ (
			" cuerpos físicos activos %d, pares de colisión %d"
			% [
				label,
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				enemies,
				awake,
				pickups,
				Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
				Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
			]
		)
	)


func _measure(label: String, part: String) -> void:
	var frames: Array[float] = []
	var process_ms := 0.0
	var physics_ms := 0.0
	var last := Time.get_ticks_usec()
	for _frame: int in MEASURE_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var total := 0.0
	for value: float in frames:
		total += value
	frames.sort()
	(
		_report
		. append(
			(
				"%s | %s | %.2f | %.2f | %.2f | %.2f | %.2f"
				% [
					label,
					part,
					total / frames.size(),
					frames[int(frames.size() * 0.95)],
					frames[frames.size() - 1],
					process_ms / MEASURE_FRAMES,
					physics_ms / MEASURE_FRAMES,
				]
			)
		)
	)


## Apaga una parte y devuelve cómo volver a encenderla.
func _switch_off(part: String) -> Callable:
	var nodes: Array[Node] = []
	match part:
		"enemigos":
			nodes.append_array(get_tree().get_nodes_in_group("enemy"))
		"objetos":
			nodes.append_array(get_tree().get_nodes_in_group("pickup"))
		"interfaz":
			nodes.append(_game.get("_hud"))
		"edificio":
			nodes.append(_game.level)
		"jugador":
			nodes.append(_game.level.player)
		"audio":
			nodes.append(AudioDirector)
	var previous: Array[int] = []
	for node: Node in nodes:
		previous.append(node.process_mode)
		if part == "edificio":
			node.set_process(false)
		else:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	return func() -> void:
		for index: int in nodes.size():
			var node := nodes[index]
			if not is_instance_valid(node):
				continue
			if part == "edificio":
				node.set_process(true)
			else:
				node.process_mode = previous[index] as Node.ProcessMode

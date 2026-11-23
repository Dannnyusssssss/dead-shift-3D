class_name BotSoak
extends RefCounted
## Escenario «soak» del bot: en la azotea, oleadas del rescate perdido que vuelven a empezar
## (con un generador nuevo) cada vez que se acaban; el jugador es invencible y los enemigos
## cercanos caen cada poco, así se crean y se quitan enemigos sin parar durante 30 minutos.
## Compara la memoria y los nodos con una referencia tomada al principio: si crecen más de la
## cuenta, algo no se está liberando.

const PASSED: String = "sin fugas"
const DURATION: float = 1800.0
## Referencia cuando ya está todo cargado; cada cuánto se informa y se derriban enemigos.
const BASELINE_AT: float = 120.0
const REPORT_EVERY: float = 300.0
const CULL_EVERY: float = 20.0
const CULL_RANGE: float = 30.0
const MAX_MEMORY_GROWTH: float = 0.1
const MAX_NODE_GROWTH: float = 0.1

var culled: int = 0
var rounds: int = 0

var _memory: float = 0.0
var _nodes: float = 0.0
var _next_report: float = BASELINE_AT
var _next_cull: float = CULL_EVERY
var _spawner: WaveSpawner = null


## En la azotea (las oleadas empiezan en el primer paso, ya con el piso cambiado).
func prepare(game: Game) -> void:
	game.level.place_player_at_exit("rooftop", "stairs_down")


## Un paso del escenario. Al terminar llama a «finish(éxito, motivo)» y devuelve verdadero.
func tick(game: Game, finish: Callable) -> bool:
	var state := GameState.player
	state.health = Rules.PLAYER_MAX_HEALTH
	state.infection.exposure = 0.0
	if state.infection.infected:
		state.infection.cure()
	if _spawner == null and game.level.floor_data.has_helipad:
		_restart_waves(game)
	if game.elapsed >= _next_cull:
		_next_cull += CULL_EVERY
		_cull(game)
	if game.elapsed < _next_report:
		return false
	_next_report += REPORT_EVERY
	var memory := float(OS.get_static_memory_usage())
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	if _memory <= 0.0:
		_memory = memory
		_nodes = nodes
	print(
		(
			"[bot] soak %.0f s: memoria %.1f MB, nodos %d, enemigos %d, derribados %d, rondas %d"
			% [
				game.elapsed,
				memory / 1048576.0,
				nodes,
				game.level.active_enemies().size(),
				culled,
				rounds,
			]
		)
	)
	if game.elapsed < DURATION:
		return false
	var memory_growth := memory / _memory - 1.0
	var node_growth := nodes / maxf(_nodes, 1.0) - 1.0
	var ok := memory_growth <= MAX_MEMORY_GROWTH and node_growth <= MAX_NODE_GROWTH
	finish.call(
		ok,
		(
			"%s: 30 min, %d enemigos derribados, memoria %+.1f %%, nodos %+.1f %%"
			% [PASSED if ok else "posible fuga", culled, memory_growth * 100.0, node_growth * 100.0]
		)
	)
	return true


## Un generador nuevo con las oleadas del rescate perdido; al acabarse, se quita y se repite.
func _restart_waves(game: Game) -> void:
	if _spawner != null:
		_spawner.queue_free()
	rounds += 1
	_spawner = game.call("_make_spawner", "SoakWaves%d" % rounds) as WaveSpawner
	_spawner.waves_cleared.connect(_restart_waves.bind(game), CONNECT_DEFERRED)


func _cull(game: Game) -> void:
	var origin := game.level.player.global_position
	for enemy: Enemy in game.level.active_enemies():
		if enemy is Boss or enemy.is_dead():
			continue
		if enemy.global_position.distance_to(origin) <= CULL_RANGE:
			enemy.take_hit(10000.0, enemy.global_position + Vector3.UP, true)
			culled += 1

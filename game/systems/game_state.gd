extends Node
## Estado de la partida en curso: catálogo de datos, estado del jugador, dificultad, semilla del
## azar de la partida y pausa.

const CATALOG: GameCatalog = preload("res://game/data/catalog.tres")

## Señal del mundo de las partidas que reparten el botín con su semilla.
const LOOT_SHUFFLE_FLAG: String = "loot_shuffle"

var items: ItemCatalog = null
var player: PlayerState = null
var world: WorldState = null
var rescue: RescueClock = null
## Dificultad de la partida en curso.
var difficulty: Difficulty = Difficulty.new()
## Dificultad con la que empieza la próxima partida nueva (la elige el menú; «Jugar de nuevo»
## repite la última).
var next_difficulty: String = Difficulty.EASY
var paused: bool = false
## Semilla de la partida en curso y azar de las reglas que dependen de ella (mordidas).
var run_seed: int = 0
## Reparto del botín de esta partida (null antes de empezar: los datos tal cual).
var loot_plan: LootPlan = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Si es 0 o más, la próxima partida usa esta semilla (bot y pruebas); si no, la de la URL o
## una al azar.
var forced_seed: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	items = CATALOG.item_catalog()
	EventBus.pause_requested.connect(set_paused.bind(true))
	EventBus.inventory_changed.connect(mark_discoveries)


## Botín efectivo de una sala en esta partida.
func loot_for(floor_id: String, room: RoomData) -> Array[LootSpot]:
	return room.loot if loot_plan == null else loot_plan.loot_for(floor_id, room)


## Empieza una partida nueva con el equipo inicial.
func start_new_run() -> void:
	run_seed = _pick_seed()
	rng.seed = run_seed
	difficulty = Difficulty.new(CATALOG.find_difficulty(next_difficulty))
	player = PlayerState.new(items)
	world = WorldState.new()
	rescue = RescueClock.new(Rules.HELICOPTER_ARRIVAL_TIME, difficulty.helicopter_wait_time())
	world.current_floor = CATALOG.start_floor
	# Las partidas nuevas reparten el botín con su semilla (las guardadas antes, no).
	world.set_flag(LOOT_SHUFFLE_FLAG)
	loot_plan = LootPlan.build(CATALOG.floors, run_seed, true, items)
	player.give_starting_kit()
	mark_discoveries()
	set_paused(false)


## Retoma una partida guardada (datos ya validados por boundary/save_validation.gd).
func load_run(data: Dictionary) -> void:
	run_seed = data.get("seed", 0)
	rng.seed = run_seed
	var difficulty_id: String = data.get("difficulty", Difficulty.EASY)
	difficulty = Difficulty.new(CATALOG.find_difficulty(difficulty_id))
	next_difficulty = difficulty.id()
	player = SaveGame.restore_player(data, items)
	world = SaveGame.restore_world(data)
	rescue = SaveGame.restore_rescue(data, difficulty.helicopter_wait_time())
	loot_plan = LootPlan.build(CATALOG.floors, run_seed, world.has_flag(LOOT_SHUFFLE_FLAG), items)
	mark_discoveries()
	set_paused(false)


## Anota como descubiertos los ingredientes de combinaciones que el jugador tiene ahora.
func mark_discoveries() -> void:
	if player != null and world != null:
		Discovery.mark_seen(world, player.inventory, CATALOG.recipes)


func _pick_seed() -> int:
	if forced_seed >= 0:
		return forced_seed
	if Config.url_seed >= 0:
		return Config.url_seed
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	return generator.randi_range(0, Validation.SEED_MAX)


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	get_tree().paused = value
	InputRouter.gameplay_active = not value
	if value:
		InputRouter.release_capture()
	EventBus.paused_changed.emit(value)

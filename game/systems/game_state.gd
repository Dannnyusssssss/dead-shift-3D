extends Node
## Estado de la partida en curso: catálogo de datos, estado del jugador y pausa.

const CATALOG: GameCatalog = preload("res://game/data/catalog.tres")

var items: ItemCatalog = null
var player: PlayerState = null
var paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	items = CATALOG.item_catalog()
	EventBus.pause_requested.connect(set_paused.bind(true))


## Empieza una partida nueva con el equipo inicial.
func start_new_run() -> void:
	player = PlayerState.new(items)
	player.give_starting_kit()
	set_paused(false)


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	get_tree().paused = value
	InputRouter.gameplay_active = not value
	if value:
		InputRouter.release_capture()
	EventBus.paused_changed.emit(value)

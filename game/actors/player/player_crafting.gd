class_name PlayerCrafting
extends Node
## Combinar objetos en juego: toma unos segundos, hace ruido y deja al jugador indefenso
## (sin moverse ni atacar) mientras las manos hacen la animación genérica.
## Las reglas de recetas son de core (Crafting). Va como hijo del nodo Player.

const ERROR_BUSY: String = "busy"
## Cada cuánto vuelve a sonar el ruido de combinar mientras dura.
const NOISE_INTERVAL: float = 1.0

var active: bool = false

var _player: Player = null
var _crafting: Crafting = null
var _timer: float = 0.0
var _duration: float = 0.0
var _noise_timer: float = 0.0
var _slot_a: int = -1
var _slot_b: int = -1


func _ready() -> void:
	_player = get_parent() as Player
	_crafting = Crafting.new(GameState.CATALOG.recipes, GameState.items)
	EventBus.player_died.connect(cancel)


## Comprueba si dos casillas se pueden combinar ahora. Devuelve un código o "".
func check(slot_a: int, slot_b: int) -> String:
	if active:
		return ERROR_BUSY
	return _crafting.check(GameState.player.inventory, slot_a, slot_b)


## Empieza a combinar. Devuelve un código de error o "" si empezó.
func start(slot_a: int, slot_b: int) -> String:
	var problem := check(slot_a, slot_b)
	if problem != Crafting.ERROR_NONE:
		return problem
	var inventory := GameState.player.inventory
	var recipe := _crafting.find_recipe(inventory.get_slot(slot_a), inventory.get_slot(slot_b))
	active = true
	_slot_a = slot_a
	_slot_b = slot_b
	_duration = recipe.craft_time
	_timer = _duration
	_noise_timer = 0.0
	_player.set_blocked("crafting", true)
	_player.arms.start_craft()
	EventBus.crafting_changed.emit(true)
	return Crafting.ERROR_NONE


## Fracción completada de la combinación en curso (0 a 1).
func progress() -> float:
	if not active or _duration <= 0.0:
		return 0.0
	return 1.0 - _timer / _duration


func cancel() -> void:
	if not active:
		return
	_end()


func _physics_process(delta: float) -> void:
	if not active:
		return
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = NOISE_INTERVAL
		NoiseSystem.emit_noise(_player.global_position, Rules.NOISE_CRAFT)
	_timer -= delta
	if _timer <= 0.0:
		_finish()


func _finish() -> void:
	var result := _crafting.craft(GameState.player.inventory, _slot_a, _slot_b)
	if result == Crafting.ERROR_NONE:
		GameState.player.items_crafted += 1
		EventBus.user_message.emit("msg_crafted")
	else:
		EventBus.user_message.emit("msg_cannot_combine")
	_end()
	EventBus.inventory_changed.emit()
	EventBus.weapon_changed.emit()


func _end() -> void:
	active = false
	_player.set_blocked("crafting", false)
	_player.arms.stop_craft()
	EventBus.crafting_changed.emit(false)

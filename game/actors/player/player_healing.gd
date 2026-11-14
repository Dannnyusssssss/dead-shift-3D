class_name PlayerHealing
extends Node
## Usar curas (vendas, antibióticos, Neutrax): tarda unos segundos, se ve en primera persona y
## deja al jugador expuesto (sin moverse ni atacar). Las reglas del efecto son de core
## (PlayerState.use_item). Va como hijo del nodo Player.

const ERROR_BUSY: String = "busy"

var active: bool = false

var _player: Player = null
var _timer: float = 0.0
var _duration: float = 0.0
var _slot: int = -1
var _item_id: String = ""


func _ready() -> void:
	_player = get_parent() as Player
	EventBus.player_died.connect(cancel)


## Empieza a usar la casilla. Devuelve "" si empezó, o el motivo del rechazo.
func start(index: int) -> String:
	if active or _player.crafting.active:
		return ERROR_BUSY
	var state := GameState.player
	var problem := state.check_use(index)
	if problem != PlayerState.USE_OK:
		return problem
	var item := state.inventory.get_slot(index).item
	active = true
	_slot = index
	_item_id = item.id
	_duration = maxf(item.use_time, 0.1)
	_timer = _duration
	_player.set_blocked("healing", true)
	_player.arms.start_heal()
	return PlayerState.USE_OK


## Fracción completada (0 a 1).
func progress() -> float:
	if not active or _duration <= 0.0:
		return 0.0
	return 1.0 - _timer / _duration


func cancel() -> void:
	if active:
		_end()


func _physics_process(delta: float) -> void:
	if not active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_finish()


func _finish() -> void:
	var state := GameState.player
	var stack := state.inventory.get_slot(_slot)
	var effect := stack.item.use_effect if stack != null else ItemData.EFFECT_NONE
	# La casilla debe seguir teniendo el mismo objeto que se empezó a usar.
	if stack != null and stack.id() == _item_id and state.use_item(_slot) == PlayerState.USE_OK:
		EventBus.user_message.emit(_message_for(effect))
		EventBus.player_health_changed.emit(state.health)
		EventBus.infection_changed.emit()
	_end()
	EventBus.inventory_changed.emit()


func _message_for(effect: int) -> String:
	match effect:
		ItemData.EFFECT_SLOW_INFECTION:
			return "msg_infection_slowed"
		ItemData.EFFECT_CURE_INFECTION:
			return "msg_infection_cured"
	return "msg_healed"


func _end() -> void:
	active = false
	_player.set_blocked("healing", false)
	_player.arms.stop_heal()

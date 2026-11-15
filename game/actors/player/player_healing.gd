class_name PlayerHealing
extends Node
## Usar curas (vendas, antibióticos, Neutrax): tarda unos segundos y la cura se ve en la mano.
## Mientras dura se puede mirar y caminar despacio, pero no atacar. Las reglas del efecto son
## de core (PlayerState.use_item). Va como hijo del nodo Player.

const ERROR_BUSY: String = "busy"

var active: bool = false

var _player: Player = null
var _timer: float = 0.0
var _duration: float = 0.0
var _slot: int = -1
var _item_id: String = ""
var _item: ItemData = null


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
	_item = item
	_duration = maxf(item.use_time, 0.1)
	_timer = _duration
	_player.arms.start_heal(item.id)
	return PlayerState.USE_OK


## Clave del aviso que explica por qué no se pudo usar una cura.
static func problem_message(problem: String) -> String:
	match problem:
		PlayerState.USE_FULL_HEALTH:
			return "msg_full_health"
		PlayerState.USE_NOT_INFECTED:
			return "msg_not_infected"
		PlayerState.USE_COUNTDOWN_FULL:
			return "msg_countdown_full"
	return "msg_cannot_use"


## Objeto que se está usando (null si no hay cura en curso).
func current_item() -> ItemData:
	return _item if active else null


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
		_handle_quick_heal()
		return
	_timer -= delta
	if _timer <= 0.0:
		_finish()


## Tecla o botón de curarse: usa la cura que hace falta sin abrir la mochila.
func _handle_quick_heal() -> void:
	if not InputRouter.just_pressed("heal"):
		return
	if not _player.controls_enabled or _player.hands_busy or _player.is_dead():
		return
	var state := GameState.player
	var slot := QuickHeal.choose(state)
	if slot < 0:
		var key := "msg_full_health"
		if QuickHeal.reason(state) == QuickHeal.NOTHING_TO_USE:
			key = "msg_no_cure"
		EventBus.user_message.emit(key)
		return
	var problem := start(slot)
	if problem != PlayerState.USE_OK:
		EventBus.user_message.emit(problem_message(problem))


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
		ItemData.EFFECT_DELAY_INFECTION:
			return "msg_infection_delayed"
		ItemData.EFFECT_CURE_INFECTION:
			return "msg_infection_cured"
	return "msg_healed"


func _end() -> void:
	active = false
	_player.arms.stop_heal()

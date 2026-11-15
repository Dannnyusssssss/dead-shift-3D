class_name PlayerCrafting
extends Node
## Combinar objetos en juego: toma unos segundos y hace ruido. Mientras dura, las manos
## sostienen los dos objetos (el arma se guarda): se puede mirar y caminar despacio, no atacar.
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
var _recipe: RecipeData = null
var _slot: int = -1
## Lo que se está combinando: los dos objetos y el resultado ("" si es una reparación).
var _description: Array[String] = []


func _ready() -> void:
	_player = get_parent() as Player
	_crafting = Crafting.new(GameState.CATALOG.recipes, GameState.items)
	EventBus.player_died.connect(cancel)


## Comprueba si la receta se puede hacer ahora con la casilla dada (-1 si no usa casilla).
## Devuelve un código o "".
func check(recipe: RecipeData, slot: int) -> String:
	if active:
		return ERROR_BUSY
	return _crafting.check(GameState.player.inventory, recipe, slot)


## Empieza a combinar. Devuelve un código de error o "" si empezó.
func start(recipe: RecipeData, slot: int) -> String:
	var problem := check(recipe, slot)
	if problem != Crafting.ERROR_NONE:
		return problem
	var inventory := GameState.player.inventory
	active = true
	_recipe = recipe
	_slot = slot
	_duration = recipe.craft_time
	_timer = _duration
	_noise_timer = 0.0
	var first := recipe.input_a
	var second := recipe.input_b
	if recipe.is_repair():
		second = inventory.get_slot(slot).id()
	_description = [first, second, "" if recipe.is_repair() else recipe.result_id]
	_player.arms.start_craft(first, second)
	EventBus.crafting_changed.emit(true)
	return Crafting.ERROR_NONE


## Objetos de la combinación en curso: [primero, segundo, resultado] (resultado "" si repara).
func description() -> Array[String]:
	return _description if active else []


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
		NoiseSystem.emit_noise(_player.global_position, Rules.NOISE_CRAFT, true)
	_timer -= delta
	if _timer <= 0.0:
		_finish()


func _finish() -> void:
	var state := GameState.player
	var was_equipped := _slot >= 0 and _slot == state.equipped_slot
	var result := _crafting.craft(state.inventory, _recipe, _slot)
	if result == Crafting.ERROR_NONE and was_equipped and state.equipped() == null:
		# Se combinó el arma en la mano: se equipa lo que salió (o la siguiente arma).
		var made := state.inventory.find_slot(_recipe.result_id)
		if made < 0 or not state.select_slot(made):
			state.cycle_weapon(1)
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
	_player.arms.stop_craft()
	EventBus.crafting_changed.emit(false)

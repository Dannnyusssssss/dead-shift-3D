class_name SaveGame
extends RefCounted
## Traduce la partida en curso a un diccionario de guardado (solo tipos JSON) y lo contrario,
## a partir de datos ya validados por boundary/save_validation.gd. Lógica pura.


## Reúne todo lo que se guarda. spawn_kind/spawn_id dicen dónde reaparecer al continuar.
static func capture(
	state: PlayerState,
	world: WorldState,
	rescue: RescueClock,
	floor_id: String,
	spawn_kind: String,
	spawn_id: String,
	seed_value: int,
	elapsed: float,
	difficulty_id: String = Difficulty.EASY
) -> Dictionary:
	var vest: Dictionary = {}
	if state.vest != null:
		vest = {"id": state.vest.id(), "durability": state.vest.durability.fraction()}
	var keys: Array[String] = []
	for item_id: String in state.keys.items:
		keys.append(item_id)
	return {
		"floor": floor_id,
		"spawn_kind": spawn_kind,
		"spawn_id": spawn_id,
		"health": state.health,
		"infection":
		{
			"infected": state.infection.infected,
			"time_left": state.infection.time_left,
			"exposure": state.infection.exposure,
		},
		"inventory": state.inventory.to_data(),
		"bag": state.inventory.bag.to_data(),
		"flashlight": state.flashlight.to_data(),
		"vest": vest,
		"equipped": state.equipped_slot,
		"keys": keys,
		"phone_assembled": state.keys.phone_assembled,
		"rescue": rescue.to_data(),
		"world": world.to_data(),
		"seed": seed_value,
		"difficulty": difficulty_id,
		"stats":
		{
			"time": elapsed,
			"damage_taken": state.damage_taken,
			"weapons_broken": state.weapons_broken,
			"crafted": state.items_crafted,
			"kills": state.kills,
		},
	}


## Reconstruye el jugador desde datos validados.
static func restore_player(data: Dictionary, items: ItemCatalog) -> PlayerState:
	var state := PlayerState.new(items)
	state.health = data.get("health", Rules.PLAYER_MAX_HEALTH)
	var infection: Dictionary = data.get("infection", {})
	state.infection.infected = infection.get("infected", false)
	state.infection.time_left = infection.get("time_left", 0.0)
	state.infection.exposure = infection.get("exposure", 0.0)
	var bag: Dictionary = data.get("bag", {})
	state.inventory.bag.load_data(bag, items)
	var flashlight: Dictionary = data.get("flashlight", {})
	state.flashlight.load_data(flashlight)
	var entries: Array[Dictionary] = []
	var raw_inventory: Array = data.get("inventory", [])
	for entry: Variant in raw_inventory:
		if entry is Dictionary:
			entries.append(entry)
	state.inventory.load_data(entries, items)
	# El arma equipada se fija antes de reponer la porra: si una partida antigua la guardó en una
	# casilla normal y la llevaba en la mano, sigue en la mano al pasar a su posición fija.
	state.equipped_slot = data.get("equipped", -1)
	state.ensure_bound_items()
	var vest: Dictionary = data.get("vest", {})
	var vest_id: String = vest.get("id", "")
	var vest_fraction: float = vest.get("durability", 1.0)
	var vest_item := items.get_item(vest_id)
	if vest_item != null and vest_item.vest != null:
		state.vest = ItemStack.new(vest_item, 1, vest_fraction)
	if state.equipped() == null:
		state.equipped_slot = -1
		state.cycle_weapon(1)
	var keys: Array = data.get("keys", [])
	for item_id: Variant in keys:
		if item_id is String:
			var key_id: String = item_id
			state.keys.add(key_id)
	state.keys.phone_assembled = data.get("phone_assembled", false)
	var stats: Dictionary = data.get("stats", {})
	state.damage_taken = stats.get("damage_taken", 0.0)
	state.weapons_broken = stats.get("weapons_broken", 0)
	state.items_crafted = stats.get("crafted", 0)
	state.kills = stats.get("kills", 0)
	return state


static func restore_world(data: Dictionary) -> WorldState:
	var world := WorldState.new()
	var world_data: Dictionary = data.get("world", {})
	world.load_data(world_data)
	world.current_floor = data.get("floor", "")
	return world


## Reloj del rescate con la espera del helicóptero de la dificultad de la partida.
static func restore_rescue(
	data: Dictionary, wait_time: float = Rules.HELICOPTER_WAIT_TIME
) -> RescueClock:
	var clock := RescueClock.new(Rules.HELICOPTER_ARRIVAL_TIME, wait_time)
	var rescue: Dictionary = data.get("rescue", {})
	var state_value: int = rescue.get("state", RescueClock.STATE_IDLE)
	var seconds: float = rescue.get("time_left", 0.0)
	clock.load_data(state_value, seconds)
	return clock

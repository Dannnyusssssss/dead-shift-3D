class_name TipBanner
extends Label
## Consejos de primera vez (opción «Consejos» en Accesibilidad): escucha lo que pasa en la
## partida y, la primera vez que ocurre algo (primer daño, primer material en la bolsa, algo que
## lanzar, arma gastada, infección, el plano, el apagón, el teléfono armado), muestra un consejo
## corto unos segundos abajo y al centro. Si llegan varios a la vez, salen uno detrás de otro.

const SHOW_TIME: float = 7.0
const THROWABLES: Array[String] = ["bottle", "noise_bottle"]

var _queue: Array[String] = []
var _timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 8)
	EventBus.player_damaged.connect(func(_amount: float) -> void: offer(Tips.DAMAGE))
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.weapon_changed.connect(_on_inventory_changed)
	EventBus.infection_changed.connect(_on_infection_changed)
	EventBus.key_items_changed.connect(_on_key_items_changed)
	EventBus.blackout_changed.connect(_on_blackout_changed)


## Pide mostrar un consejo: solo si la opción está activa y no salió antes en esta partida.
func offer(tip_id: String) -> void:
	if not Settings.get_bool("tips") or GameState.world == null:
		return
	if Tips.take(GameState.world, tip_id):
		_queue.append(tip_id)
		if _timer <= 0.0:
			_next()


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		text = ""
		_next()


func _next() -> void:
	if _queue.is_empty():
		return
	var tip_id: String = _queue.pop_front()
	text = "%s %s" % [tr("tip_prefix"), tr(Tips.text_key(tip_id))]
	_timer = SHOW_TIME


func _on_inventory_changed() -> void:
	var state := GameState.player
	if state == null:
		return
	var bag := state.inventory.bag
	if not bag.is_empty():
		offer(Tips.BAG)
	for item_id: String in THROWABLES:
		if bag.count(item_id) > 0:
			offer(Tips.THROW)
	var stack := state.equipped()
	if stack != null and not stack.durability.is_unbreakable() and stack.durability.state() >= 1:
		offer(Tips.WEAR)


func _on_infection_changed() -> void:
	if GameState.player != null and GameState.player.infection.infected:
		offer(Tips.INFECTION)


func _on_key_items_changed() -> void:
	var keys := GameState.player.keys if GameState.player != null else null
	if keys == null:
		return
	if keys.has(MapMarkers.MAP_ITEM):
		offer(Tips.MAP)
	if keys.phone_assembled:
		offer(Tips.PHONE)


func _on_blackout_changed(active: bool, _origin: Vector3) -> void:
	if active:
		offer(Tips.DARK)

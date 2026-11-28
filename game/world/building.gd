class_name Building
extends Node3D
## El centro comercial entero: todos los pisos apilados a su altura en una sola escena, con una
## navegación común (los enemigos también suben escaleras), el jugador, los enemigos y los
## objetos sueltos. Sabe en qué piso está el jugador por su altura; al cambiar de piso avisa y
## deja activos solo ese piso y los contiguos (enemigos y geometría), para el rendimiento.

## Cada cuánto se revisa el piso del jugador y qué enemigos siguen activos.
const TRACK_INTERVAL: float = 0.25
## Exposición del tono de película y ganancia de la luz ambiente de cada piso (ajustados al ver
## las capturas con las texturas del Hito 3; los valores de cada piso son relativos entre sí).
const EXPOSURE: float = 1.15
const AMBIENT_GAIN: float = 1.3
const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://game/actors/enemies/enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://game/actors/enemies/boss.tscn")

## Color del fondo y de la niebla suave (Media y Alta), y su densidad.
const BACKGROUND_COLOR: Color = Color(0.02, 0.02, 0.03)
const FOG_COLOR: Color = Color(0.05, 0.05, 0.07)
const FOG_DENSITY: float = 0.02
## Inicio y cierre de la niebla de profundidad (fracción de la distancia de visión).
const DEPTH_FOG_BEGIN: float = 0.35
const DEPTH_FOG_END: float = 0.95

## Piso y descansillo o zona segura donde aparece el jugador ("" = inicio de partida nueva).
var start_floor: String = ""
var arrival_exit: String = ""
var arrival_safe_room: String = ""

var player: Player = null
var navigation: NavigationRegion3D = null
## Piso actual del jugador.
var floor_data: FloorData = null
var current_index: int = 0
var sections: Array[FloorSection] = []

var _actors: Node3D = null
var _spawner: LootSpawner = null
var _viewed_index: int = -1
var _environment: Environment = null
var _track_timer: float = 0.0


func _ready() -> void:
	_build_environment()
	# Sangre, polvo, chispas, marcas de bala y escombros (tres llamadas de dibujo en total).
	var effects := ImpactEffects.new()
	effects.name = "ImpactEffects"
	add_child(effects)
	EventBus.blackout_changed.connect(_on_blackout_changed)
	navigation = NavigationRegion3D.new()
	navigation.name = "Navigation"
	add_child(navigation)
	var floors := GameState.CATALOG.floors.duplicate()
	floors.sort_custom(
		func(a: FloorData, b: FloorData) -> bool: return a.level_index < b.level_index
	)
	for index: int in floors.size():
		var section := FloorSection.new()
		section.floor_data = floors[index]
		if index + 1 < floors.size():
			var above: FloorData = floors[index + 1]
			section.holes_above = above.holes
		navigation.add_child(section)
		sections.append(section)
	_bake_navigation()
	_actors = Node3D.new()
	_actors.name = "Actors"
	add_child(_actors)
	_spawner = LootSpawner.new()
	_spawner.name = "LootSpawner"
	add_child(_spawner)
	for section: FloorSection in sections:
		_restore_drops(section.floor_data)
		for index: int in section.floor_data.enemies.size():
			_spawn_enemy(section.floor_data, index)
	_place_player()
	current_index = floor_index_at(player.global_position.y)
	floor_data = sections[current_index].floor_data
	GameState.world.current_floor = floor_data.id
	_refresh_active()


func _physics_process(delta: float) -> void:
	_track_timer -= delta
	if _track_timer > 0.0 or player == null:
		return
	_track_timer = TRACK_INTERVAL
	var index := floor_index_at(player.global_position.y)
	if index != current_index:
		current_index = index
		floor_data = sections[index].floor_data
		GameState.world.current_floor = floor_data.id
		_environment.ambient_light_color = floor_data.ambient_color
		_environment.ambient_light_energy = _ambient_energy(sections[index])
		EventBus.floor_changed.emit(floor_data.id)
	_refresh_active()


## Índice del piso al que pertenece una altura (el suelo que tiene debajo, con margen para que
## la mitad de abajo de una escalera siga contando como el piso de abajo).
func floor_index_at(height: float) -> int:
	var index := floori((height + Rules.FLOOR_SWITCH_MARGIN) / Rules.FLOOR_HEIGHT)
	return clampi(index, 0, sections.size() - 1)


## Luz ambiente de un piso: la suya, o una fracción si está en apagón.
func _ambient_energy(section: FloorSection) -> float:
	var energy := section.floor_data.ambient_energy * AMBIENT_GAIN
	return energy * Rules.BLACKOUT_AMBIENT_FACTOR if not section.powered else energy


## Apagón del jefe: baja o devuelve la luz del piso del jefe y, si el jugador está en él, la luz
## ambiente, siempre de forma gradual.
func _on_blackout_changed(active: bool, origin: Vector3) -> void:
	var section := section_at(origin)
	section.set_power(not active)
	EventBus.sound_cue.emit("cue_power_down" if active else "cue_power_up", origin)
	if section == sections[current_index]:
		var tween := create_tween()
		tween.tween_property(
			_environment, "ambient_light_energy", _ambient_energy(section), Rules.BLACKOUT_FADE
		)


func section_at(point: Vector3) -> FloorSection:
	return sections[floor_index_at(point.y)]


func find_section(floor_id: String) -> FloorSection:
	for section: FloorSection in sections:
		if section.floor_data.id == floor_id:
			return section
	return null


## Pasa un punto del mundo a coordenadas de su piso.
func to_floor_local(point: Vector3) -> Vector3:
	return point - Vector3.UP * section_at(point).floor_data.elevation()


## Sala que es zona segura y contiene el punto del mundo, o null.
func safe_room_at(point: Vector3) -> RoomData:
	return section_at(point).safe_room_at(to_floor_local(point))


## Verdadero si el punto del mundo está en el helipuerto.
## Centro del helipuerto en el mundo (el piso que lo tenga; si ninguno, el origen).
func helipad_point() -> Vector3:
	for section: FloorSection in sections:
		if section.floor_data.has_helipad:
			return section.floor_data.helipad_position + Vector3.UP * section.floor_data.elevation()
	return Vector3.ZERO


func on_helipad(point: Vector3) -> bool:
	return section_at(point).on_helipad(to_floor_local(point))


## Descansillo del piso actual más cercano al jugador ("" si el piso no tiene).
func nearest_exit_id() -> String:
	var nearest := floor_data.nearest_exit(to_floor_local(player.global_position))
	return nearest.id if nearest != null else ""


## Enemigos activos ahora (piso del jugador y contiguos).
func active_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node: Node in _actors.get_children():
		var enemy := node as Enemy
		if enemy != null and enemy.process_mode != Node.PROCESS_MODE_DISABLED:
			result.append(enemy)
	return result


## Enemigos vivos cuyo cuerpo está ahora en ese piso.
func enemies_on_floor(floor_id: String) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var section := find_section(floor_id)
	if section == null:
		return result
	var index := sections.find(section)
	for node: Node in _actors.get_children():
		var enemy := node as Enemy
		if enemy != null and not enemy.is_dead():
			if floor_index_at(enemy.global_position.y) == index:
				result.append(enemy)
	return result


## Coloca al jugador en un descansillo de un piso (pruebas y recorrido automático).
func place_player_at_exit(floor_id: String, exit_id: String) -> bool:
	var section := find_section(floor_id)
	var landing := section.floor_data.find_exit(exit_id) if section != null else null
	if landing == null:
		return false
	player.global_position = landing.arrival + Vector3.UP * section.floor_data.elevation()
	player.rotation.y = deg_to_rad(landing.arrival_yaw_deg)
	player.velocity = Vector3.ZERO
	return true


## Añade un enemigo creado fuera del edificio (oleadas) al nodo de actores.
func add_actor(node: Node3D) -> void:
	_actors.add_child(node)


## Guarda en el estado del mundo los objetos que quedan en el suelo, por piso.
func store_world_state() -> void:
	var entries: Dictionary = {}
	for section: FloorSection in sections:
		entries[section.floor_data.id] = [] as Array[Dictionary]
	for child: Node in _spawner.get_children():
		var pickup := child as Pickup
		if pickup == null or pickup.stack == null or not pickup.enabled:
			continue
		if pickup.spot_key.is_empty():
			var floor_id := section_at(pickup.global_position).floor_data.id
			var list: Array[Dictionary] = entries[floor_id]
			list.append(pickup.to_drop_entry())
	for floor_id: String in entries:
		var list: Array[Dictionary] = entries[floor_id]
		GameState.world.set_drops(floor_id, list)


func _place_player() -> void:
	player = PLAYER_SCENE.instantiate()
	var section := find_section(start_floor)
	if section == null:
		section = find_section(GameState.CATALOG.start_floor)
	var data := section.floor_data
	var lift := Vector3.UP * data.elevation()
	var arrival := data.find_exit(arrival_exit) if not arrival_exit.is_empty() else null
	var safe_room := (
		section.find_room(arrival_safe_room) if not arrival_safe_room.is_empty() else null
	)
	if arrival != null:
		player.position = arrival.arrival + lift
		player.rotation.y = deg_to_rad(arrival.arrival_yaw_deg)
	elif safe_room != null and safe_room.safe_zone:
		var center := safe_room.rect.get_center()
		player.position = Vector3(center.x, 0.0, center.y) + lift
	else:
		player.position = data.player_spawn + lift
		player.rotation.y = deg_to_rad(data.player_yaw_deg)
	add_child(player)


## Deja activos y visibles solo el piso del jugador y los contiguos.
## Piso que se está mirando por las cámaras (-1 si ninguno): se ve aunque esté lejos.
func set_viewed_floor(index: int) -> void:
	_viewed_index = index
	_refresh_active()


func _refresh_active() -> void:
	for index: int in sections.size():
		var near := absi(index - current_index) <= Rules.ACTIVE_FLOOR_RANGE
		sections[index].visible = near or index == _viewed_index
	for node: Node in _actors.get_children():
		var enemy := node as Enemy
		if enemy == null:
			continue
		var enemy_floor := floor_index_at(enemy.global_position.y)
		var near := absi(enemy_floor - current_index) <= Rules.ACTIVE_FLOOR_RANGE
		# En el piso que se mira por las cámaras se ven, pero quietos si está lejos.
		enemy.visible = near or enemy_floor == _viewed_index
		enemy.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED


func _spawn_enemy(data: FloorData, index: int) -> void:
	var world := GameState.world
	var floor_id := data.id
	var key := "enemy_%d" % index
	if world.is_killed(floor_id, key):
		return
	var spawn: EnemySpawn = data.enemies[index]
	var scene := BOSS_SCENE if spawn.enemy.boss != null else ENEMY_SCENE
	var enemy: Enemy = scene.instantiate()
	enemy.data = spawn.enemy
	enemy.vest_override = spawn.vest_override
	enemy.rng_seed = spawn.rng_seed
	enemy.position = spawn.position + Vector3.UP * data.elevation()
	enemy.died.connect(func() -> void: world.mark_killed(floor_id, key))
	_actors.add_child(enemy)


## Vuelve a poner los objetos que quedaron en el suelo de un piso en una visita anterior.
func _restore_drops(data: FloorData) -> void:
	for entry: Dictionary in GameState.world.drops(data.id):
		var item_id: String = entry.get("id", "")
		var item := GameState.items.get_item(item_id)
		if item == null:
			continue
		var count: int = entry.get("count", 1)
		var fraction_left: float = entry.get("durability", 1.0)
		var stack := ItemStack.new(item, count, fraction_left)
		if item.weapon != null:
			var ammo: int = entry.get("ammo", 0)
			stack.ammo_loaded = clampi(ammo, 0, item.weapon.magazine_size)
		var x: float = entry.get("x", 0.0)
		var z: float = entry.get("z", 0.0)
		_spawner.spawn(Vector3(x, data.elevation(), z), stack, false)


func _build_environment() -> void:
	var first: FloorData = GameState.CATALOG.find_floor(GameState.CATALOG.start_floor)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = first.ambient_color
	environment.ambient_light_energy = first.ambient_energy
	environment.fog_enabled = true
	# Tono de película: las zonas claras no se queman y las oscuras conservan detalle.
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = EXPOSURE
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	_environment = environment
	_apply_quality_look()
	EventBus.settings_changed.connect(_on_settings_changed)


func _on_settings_changed(key: String) -> void:
	if key == "quality":
		_apply_quality_look()
		DrawDistance.refresh(get_tree())


## Niebla y halo según la calidad. En Mínima y Baja la niebla es de profundidad y llega al
## color del fondo justo antes de la distancia de visión, así el corte de lo lejano no se ve.
## En Media y Alta, la niebla suave de siempre y el halo de los paneles y carteles que brillan.
func _apply_quality_look() -> void:
	var quality := clampi(Settings.get_int("quality"), 0, Rules.QUALITY_DEPTH_FOG.size() - 1)
	if Rules.QUALITY_DEPTH_FOG[quality]:
		var view := Rules.QUALITY_VIEW_DISTANCE[quality]
		_environment.fog_mode = Environment.FOG_MODE_DEPTH
		_environment.fog_light_color = BACKGROUND_COLOR
		_environment.fog_density = 1.0
		_environment.fog_depth_begin = view * DEPTH_FOG_BEGIN
		_environment.fog_depth_end = view * DEPTH_FOG_END
	else:
		_environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		_environment.fog_light_color = FOG_COLOR
		_environment.fog_density = FOG_DENSITY
	_environment.glow_enabled = quality >= SettingsSchema.QUALITY_MEDIUM


func _bake_navigation() -> void:
	var mesh := NavigationMesh.new()
	# Valores múltiplos del tamaño de celda, para que el horneado no pierda precisión.
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 40.0
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Rules.LAYER_WORLD
	navigation.navigation_mesh = mesh
	# Horneado síncrono: en web no hay hilos. Se hace una vez al empezar la partida.
	navigation.bake_navigation_mesh(false)

class_name FloorLevel
extends Node3D
## Construye un piso a partir de su FloorData: salas con el kit modular, botín, luces,
## navegación horneada al cargar, rejas, enemigos, jugador y salidas a otros pisos.
## Respeta el estado del mundo: lo muerto sigue muerto, lo recogido no vuelve y lo registrado
## sigue vacío; los objetos que quedaron en el suelo reaparecen donde estaban.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://game/actors/enemies/enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://game/actors/enemies/boss.tscn")

@export var floor_data: FloorData = null
## Salida por la que llega el jugador ("" = punto de inicio de una partida nueva).
@export var arrival_exit: String = ""
## Zona segura donde reaparece al continuar una partida guardada ("" = no).
@export var arrival_safe_room: String = ""

var player: Player = null
var navigation: NavigationRegion3D = null

var _spawner: LootSpawner = null
var _environment: Environment = null


func _ready() -> void:
	_build_environment()
	navigation = NavigationRegion3D.new()
	navigation.name = "Navigation"
	add_child(navigation)
	for room: RoomData in floor_data.rooms:
		_build_room(room)
	for index: int in floor_data.props.size():
		_build_prop(floor_data.props[index], "prop_%d" % index)
	_bake_navigation()
	GameState.world.current_floor = floor_data.id
	_spawner = LootSpawner.new()
	_spawner.name = "LootSpawner"
	add_child(_spawner)
	for room: RoomData in floor_data.rooms:
		_place_loot(room)
	_restore_drops()
	for gate_spec: GateSpec in floor_data.gates:
		var gate := Gate.new()
		gate.spec = gate_spec
		gate.position = gate_spec.position
		gate.rotation.y = deg_to_rad(gate_spec.rotation_deg)
		add_child(gate)
	for index: int in floor_data.enemies.size():
		_spawn_enemy(floor_data.enemies[index], "enemy_%d" % index)
	if floor_data.has_helipad:
		var helicopter := Helicopter.new()
		helicopter.position = floor_data.helipad_position
		add_child(helicopter)
	for floor_exit: FloorExit in floor_data.exits:
		var zone := FloorExitZone.new()
		zone.spec = floor_exit
		zone.position = floor_exit.position
		add_child(zone)
	player = PLAYER_SCENE.instantiate()
	var arrival := floor_data.find_exit(arrival_exit) if not arrival_exit.is_empty() else null
	var safe_room := _find_room(arrival_safe_room)
	if arrival != null:
		player.position = arrival.arrival
		player.rotation.y = deg_to_rad(arrival.arrival_yaw_deg)
	elif safe_room != null and safe_room.safe_zone:
		var center := safe_room.rect.get_center()
		player.position = Vector3(center.x, 0.0, center.y)
	else:
		player.position = floor_data.player_spawn
		player.rotation.y = deg_to_rad(floor_data.player_yaw_deg)
	add_child(player)


## Guarda en el estado del mundo los objetos que quedan en el suelo (antes de dejar el piso).
func store_world_state() -> void:
	var entries: Array[Dictionary] = []
	for child: Node in _spawner.get_children():
		var pickup := child as Pickup
		if pickup == null or pickup.stack == null or not pickup.enabled:
			continue
		if pickup.spot_key.is_empty():
			entries.append(pickup.to_drop_entry())
	GameState.world.set_drops(floor_data.id, entries)


func _find_room(room_id: String) -> RoomData:
	if room_id.is_empty():
		return null
	for room: RoomData in floor_data.rooms:
		if room.id == room_id:
			return room
	return null


## Sala que es zona segura y contiene el punto, o null.
func safe_room_at(point: Vector3) -> RoomData:
	for room: RoomData in floor_data.rooms:
		if room.safe_zone and room.rect.has_point(Vector2(point.x, point.z)):
			return room
	return null


## Verdadero si el punto está en el helipuerto del piso.
func on_helipad(point: Vector3) -> bool:
	if not floor_data.has_helipad:
		return false
	var flat := Vector2(point.x, point.z)
	var pad := Vector2(floor_data.helipad_position.x, floor_data.helipad_position.z)
	return flat.distance_to(pad) <= floor_data.helipad_radius


## Salas que son zona segura.
func safe_rooms() -> Array[RoomData]:
	var result: Array[RoomData] = []
	for room: RoomData in floor_data.rooms:
		if room.safe_zone:
			result.append(room)
	return result


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.03)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = floor_data.ambient_color
	environment.ambient_light_energy = floor_data.ambient_energy
	environment.fog_enabled = Rules.QUALITY_FOG[Settings.get_int("quality")]
	environment.fog_light_color = Color(0.05, 0.05, 0.07)
	environment.fog_density = 0.02
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	_environment = environment
	EventBus.settings_changed.connect(_on_settings_changed)


func _on_settings_changed(key: String) -> void:
	if key == "quality":
		_environment.fog_enabled = Rules.QUALITY_FOG[Settings.get_int("quality")]


func _build_room(room: RoomData) -> void:
	var rect := room.rect
	var builder := Kit.Builder.new()
	var floor_mat := Kit.material(room.floor_color)
	var wall_mat := Kit.material(room.wall_color)
	var ceiling_mat := Kit.material(room.wall_color.darkened(0.5))
	var center := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	builder.add_box(center + Vector3.DOWN * 0.1, Vector3(rect.size.x, 0.2, rect.size.y), floor_mat)
	if not room.outdoor:
		builder.add_box(
			center + Vector3.UP * (room.height + 0.1),
			Vector3(rect.size.x, 0.2, rect.size.y),
			ceiling_mat,
			false
		)
	var half := Kit.WALL_THICKNESS * 0.5
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	var z1 := rect.end.y
	var sides: Array[Array] = [
		[DoorSpec.SIDE_NORTH, Vector3(x0, 0.0, z0 + half), Vector3(x1, 0.0, z0 + half)],
		[DoorSpec.SIDE_SOUTH, Vector3(x0, 0.0, z1 - half), Vector3(x1, 0.0, z1 - half)],
		[DoorSpec.SIDE_WEST, Vector3(x0 + half, 0.0, z0), Vector3(x0 + half, 0.0, z1)],
		[DoorSpec.SIDE_EAST, Vector3(x1 - half, 0.0, z0), Vector3(x1 - half, 0.0, z1)],
	]
	for side: Array in sides:
		var side_id: int = side[0]
		var start: Vector3 = side[1]
		var end: Vector3 = side[2]
		var openings := _openings(room, side_id, start.distance_to(end))
		Kit.add_wall(builder, start, end, room.height, openings, wall_mat)
	var body := builder.build(room.id)
	navigation.add_child(body)
	_add_lights(room, center)
	_add_sign(room)


## Luces del techo repartidas a lo largo del lado más largo de la sala, sin sombras.
func _add_lights(room: RoomData, center: Vector3) -> void:
	if room.light_energy <= 0.0:
		return
	var rect := room.rect
	var count := maxi(room.light_count, 1)
	var long_x := rect.size.x >= rect.size.y
	var span := rect.size.x if long_x else rect.size.y
	for index: int in count:
		var light := OmniLight3D.new()
		var along := (float(index) + 0.5) / float(count) * span - span * 0.5
		var offset := Vector3(along, 0.0, 0.0) if long_x else Vector3(0.0, 0.0, along)
		light.position = center + offset + Vector3.UP * (room.height - 0.4)
		light.omni_range = maxf(span / float(count), minf(rect.size.x, rect.size.y)) * 0.9
		light.light_energy = room.light_energy
		light.light_color = Color(0.85, 0.9, 1.0)
		light.shadow_enabled = false
		add_child(light)


## Rótulo con el nombre de la tienda sobre su puerta (texto por clave).
func _add_sign(room: RoomData) -> void:
	if room.name_key.is_empty() or room.doors.is_empty():
		return
	var door: DoorSpec = room.doors[0]
	var rect := room.rect
	var spot := Vector3.ZERO
	# El rótulo se separa de la pared hacia fuera de la sala para no atravesarla.
	match door.side:
		DoorSpec.SIDE_NORTH:
			spot = Vector3(rect.position.x + door.offset, 0.0, rect.position.y - 1.3)
		DoorSpec.SIDE_SOUTH:
			spot = Vector3(rect.position.x + door.offset, 0.0, rect.end.y + 1.3)
		DoorSpec.SIDE_WEST:
			spot = Vector3(rect.position.x - 1.3, 0.0, rect.position.y + door.offset)
		_:
			spot = Vector3(rect.end.x + 1.3, 0.0, rect.position.y + door.offset)
	var label := Label3D.new()
	label.text = tr(room.name_key)
	label.font_size = 56
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = spot + Vector3.UP * (Kit.DOOR_HEIGHT + 0.5)
	add_child(label)


## Aberturas de una pared: puertas (hasta el suelo) y, si es el escaparate, ventanas de cristal
## en el resto de la pared.
func _openings(room: RoomData, side: int, length: float) -> Array[Array]:
	var result: Array[Array] = []
	var doors: Array[Vector2] = []
	for door: DoorSpec in room.doors:
		if door.side == side:
			var from := door.offset - door.width * 0.5
			var to := door.offset + door.width * 0.5
			result.append([from, to, 0.0, Kit.DOOR_HEIGHT, false])
			doors.append(Vector2(from, to))
	if room.storefront_side == side:
		var margin := 0.6
		var cursor := margin
		doors.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		for door_span: Vector2 in doors:
			if door_span.x - 0.3 > cursor:
				result.append([cursor, door_span.x - 0.3, Kit.WINDOW_SILL, Kit.WINDOW_TOP, true])
			cursor = door_span.y + 0.3
		if length - margin > cursor:
			result.append([cursor, length - margin, Kit.WINDOW_SILL, Kit.WINDOW_TOP, true])
	return result


func _bake_navigation() -> void:
	var mesh := NavigationMesh.new()
	# Valores múltiplos del tamaño de celda, para que el horneado no pierda precisión.
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Rules.LAYER_WORLD
	navigation.navigation_mesh = mesh
	# Horneado síncrono: en web no hay hilos y el piso es pequeño.
	navigation.bake_navigation_mesh(false)


func _place_loot(room: RoomData) -> void:
	var world := GameState.world
	var floor_id := floor_data.id
	var origin := Vector3(room.rect.position.x, 0.0, room.rect.position.y)
	for index: int in room.loot.size():
		var spot: LootSpot = room.loot[index]
		var key := "%s_%d" % [room.id, index]
		var node: Interactable = null
		if spot.kind == LootSpot.KIND_PICKUP:
			if world.is_taken(floor_id, key):
				continue
			var pickup := Pickup.new()
			pickup.item_id = spot.item_id
			pickup.count = spot.count
			pickup.durability_fraction = spot.durability
			pickup.spot_key = key
			pickup.used.connect(func(_by: Player) -> void: world.mark_taken(floor_id, key))
			node = pickup
		else:
			var container := LootContainer.new()
			container.kind = spot.kind
			container.contents = spot.contents
			if world.has_container(floor_id, key):
				container.contents = world.container_contents(floor_id, key)
			container.used.connect(
				func(_by: Player) -> void:
					world.set_container(floor_id, key, container.remaining_entries())
			)
			node = container
		node.position = origin + spot.position
		node.rotation.y = deg_to_rad(spot.rotation_deg)
		add_child(node)


func _spawn_enemy(spawn: EnemySpawn, key: String) -> void:
	var world := GameState.world
	var floor_id := floor_data.id
	if world.is_killed(floor_id, key):
		return
	var scene := BOSS_SCENE if spawn.enemy.boss != null else ENEMY_SCENE
	var enemy: Enemy = scene.instantiate()
	enemy.data = spawn.enemy
	enemy.vest_override = spawn.vest_override
	enemy.rng_seed = spawn.rng_seed
	enemy.position = spawn.position
	enemy.died.connect(func() -> void: world.mark_killed(floor_id, key))
	add_child(enemy)


## Estantería o tablero eléctrico. Se horneará en la navegación (es sólido); si ya se rompió o
## se apagó en una visita anterior, aparece así.
func _build_prop(spec: PropSpec, key: String) -> void:
	var world := GameState.world
	var floor_id := floor_data.id
	var used := world.is_taken(floor_id, key)
	if spec.kind == PropSpec.KIND_MONITOR:
		var monitor := SecurityMonitor.new()
		monitor.position = spec.position
		monitor.rotation.y = deg_to_rad(spec.rotation_deg)
		add_child(monitor)
		return
	if spec.kind == PropSpec.KIND_PANEL:
		var panel := ElectricPanel.new()
		panel.size = spec.size
		panel.position = spec.position
		panel.rotation.y = deg_to_rad(spec.rotation_deg)
		navigation.add_child(panel)
		if used:
			panel.set_dead()
		panel.shorted.connect(func() -> void: world.mark_taken(floor_id, key))
		return
	var shelf := BreakableShelf.new()
	shelf.size = spec.size
	shelf.position = spec.position
	shelf.rotation.y = deg_to_rad(spec.rotation_deg)
	navigation.add_child(shelf)
	if used:
		shelf.set_broken_silently()
	shelf.broken.connect(func() -> void: world.mark_taken(floor_id, key))


## Vuelve a poner los objetos que quedaron en el suelo en una visita anterior.
func _restore_drops() -> void:
	for entry: Dictionary in GameState.world.drops(floor_data.id):
		var item_id: String = entry.get("id", "")
		var data := GameState.items.get_item(item_id)
		if data == null:
			continue
		var count: int = entry.get("count", 1)
		var fraction_left: float = entry.get("durability", 1.0)
		var stack := ItemStack.new(data, count, fraction_left)
		if data.weapon != null:
			var ammo: int = entry.get("ammo", 0)
			stack.ammo_loaded = clampi(ammo, 0, data.weapon.magazine_size)
		var x: float = entry.get("x", 0.0)
		var z: float = entry.get("z", 0.0)
		_spawner.spawn(Vector3(x, 0.0, z), stack)

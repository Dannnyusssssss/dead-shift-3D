class_name FloorLevel
extends Node3D
## Construye un piso a partir de su FloorData: salas con el kit modular, botín, luces,
## navegación horneada al cargar, enemigos, jugador y meta (salida a la escalera).

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://game/actors/enemies/enemy.tscn")

@export var floor_data: FloorData = null

var player: Player = null
var navigation: NavigationRegion3D = null


func _ready() -> void:
	_build_environment()
	navigation = NavigationRegion3D.new()
	navigation.name = "Navigation"
	add_child(navigation)
	for room: RoomData in floor_data.rooms:
		_build_room(room)
	_bake_navigation()
	var spawner := LootSpawner.new()
	spawner.name = "LootSpawner"
	add_child(spawner)
	for room: RoomData in floor_data.rooms:
		_place_loot(room)
	for spawn: EnemySpawn in floor_data.enemies:
		_spawn_enemy(spawn)
	_build_goal()
	player = PLAYER_SCENE.instantiate()
	player.position = floor_data.player_spawn
	player.rotation.y = deg_to_rad(floor_data.player_yaw_deg)
	add_child(player)


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
	EventBus.settings_changed.connect(
		func(key: String) -> void:
			if key == "quality":
				environment.fog_enabled = Rules.QUALITY_FOG[Settings.get_int("quality")]
	)


func _build_room(room: RoomData) -> void:
	var rect := room.rect
	var builder := Kit.Builder.new()
	var floor_mat := Kit.material(room.floor_color)
	var wall_mat := Kit.material(room.wall_color)
	var ceiling_mat := Kit.material(room.wall_color.darkened(0.5))
	var center := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	builder.add_box(center + Vector3.DOWN * 0.1, Vector3(rect.size.x, 0.2, rect.size.y), floor_mat)
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
	var origin := Vector3(room.rect.position.x, 0.0, room.rect.position.y)
	for spot: LootSpot in room.loot:
		var node: Interactable = null
		if spot.kind == LootSpot.KIND_PICKUP:
			var pickup := Pickup.new()
			pickup.item_id = spot.item_id
			pickup.count = spot.count
			pickup.durability_fraction = spot.durability
			node = pickup
		else:
			var container := LootContainer.new()
			container.kind = spot.kind
			container.contents = spot.contents
			node = container
		node.position = origin + spot.position
		node.rotation.y = deg_to_rad(spot.rotation_deg)
		add_child(node)


func _spawn_enemy(spawn: EnemySpawn) -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.data = spawn.enemy
	enemy.vest_override = spawn.vest_override
	enemy.rng_seed = spawn.rng_seed
	enemy.position = spawn.position
	add_child(enemy)


func _build_goal() -> void:
	var goal := Area3D.new()
	goal.name = "Goal"
	goal.collision_layer = 0
	goal.collision_mask = Rules.LAYER_PLAYER
	goal.position = floor_data.goal
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = floor_data.goal_size
	shape.shape = box
	shape.position.y = floor_data.goal_size.y * 0.5
	goal.add_child(shape)
	var sign := Label3D.new()
	sign.text = tr("goal_stairs")
	sign.font_size = 96
	sign.modulate = Color(0.55, 1.0, 0.6)
	sign.outline_size = 16
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0.0, floor_data.goal_size.y + 0.4, 0.0)
	goal.add_child(sign)
	goal.body_entered.connect(_on_goal_body_entered)
	add_child(goal)


func _on_goal_body_entered(body: Node3D) -> void:
	if body is Player and not (body as Player).is_dead():
		EventBus.goal_reached.emit()

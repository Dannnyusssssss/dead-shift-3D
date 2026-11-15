class_name FloorSection
extends Node3D
## Un piso dentro del edificio, construido desde su FloorData: salas con el kit modular
## (forjado con huecos, techo, paredes, escaparates y decorado fundido por sala), escaleras,
## barandillas, rótulos, accesorios con función, botín, rejas y helipuerto. Va colocado a la
## altura de su piso; todo lo de dentro usa las coordenadas del piso.
## Respeta el estado del mundo: lo recogido no vuelve, lo registrado sigue vacío y lo roto
## sigue roto. Los enemigos los crea el edificio (pueden cambiar de piso).

## Color de las luces de las salas y de las de emergencia durante un apagón.
const LIGHT_COLOR: Color = Color(0.85, 0.9, 1.0)
const EMERGENCY_COLOR: Color = Color(1.0, 0.62, 0.42)

var floor_data: FloorData = null
## Huecos del piso de arriba: allí las salas de este piso no llevan techo.
var holes_above: Array[Rect2] = []
## Falso durante el apagón del jefe.
var powered: bool = true

var _lights: Array[OmniLight3D] = []
var _light_energy: Array[float] = []
var _power_tween: Tween = null


func _ready() -> void:
	name = floor_data.id
	position.y = floor_data.elevation()
	var builders: Dictionary = {}
	for room: RoomData in floor_data.rooms:
		builders[room.id] = Kit.Builder.new()
	var loose := Kit.Builder.new()
	for index: int in floor_data.props.size():
		_build_prop(floor_data.props[index], "prop_%d" % index, builders, loose)
	for ramp: RampSpec in floor_data.ramps:
		var target := _builder_at(ramp.start, builders, loose)
		var step_mat := Kit.gray(0.5 if ramp.kind == RampSpec.KIND_STAIRS else 0.32)
		Kit.add_ramp(target, ramp, step_mat, Kit.gray(0.42))
	for room: RoomData in floor_data.rooms:
		var room_builder: Kit.Builder = builders[room.id]
		_build_room(room, room_builder)
	if not loose.is_empty():
		add_child(loose.build("extras"))
	# Botín ajustado a la dificultad; se recorren todas las salas en orden, también lo ya
	# recogido, para que lo quitado sea siempre lo mismo.
	var loot := GameState.difficulty.floor_loot()
	for room: RoomData in floor_data.rooms:
		_place_loot(room, loot)
	for gate_spec: GateSpec in floor_data.gates:
		var gate := Gate.new()
		gate.spec = gate_spec
		gate.position = gate_spec.position
		gate.rotation.y = deg_to_rad(gate_spec.rotation_deg)
		add_child(gate)
	if floor_data.has_helipad:
		var helicopter := Helicopter.new()
		helicopter.position = floor_data.helipad_position
		add_child(helicopter)


## Sala que es zona segura y contiene el punto (en coordenadas del piso), o null.
func safe_room_at(local_point: Vector3) -> RoomData:
	for room: RoomData in floor_data.rooms:
		if room.safe_zone and room.rect.has_point(Vector2(local_point.x, local_point.z)):
			return room
	return null


func find_room(room_id: String) -> RoomData:
	for room: RoomData in floor_data.rooms:
		if room.id == room_id:
			return room
	return null


## Verdadero si el punto (en coordenadas del piso) está en el helipuerto.
func on_helipad(local_point: Vector3) -> bool:
	if not floor_data.has_helipad:
		return false
	var flat := Vector2(local_point.x, local_point.z)
	var pad := Vector2(floor_data.helipad_position.x, floor_data.helipad_position.z)
	return flat.distance_to(pad) <= floor_data.helipad_radius


## Constructor de la sala que contiene el punto (o el de piezas sueltas si ninguna).
func _builder_at(point: Vector3, builders: Dictionary, loose: Kit.Builder) -> Kit.Builder:
	for room: RoomData in floor_data.rooms:
		if room.rect.has_point(Vector2(point.x, point.z)):
			var found: Kit.Builder = builders[room.id]
			return found
	return loose


func _build_room(room: RoomData, builder: Kit.Builder) -> void:
	var rect := room.rect
	var floor_mat := Kit.material(room.floor_color)
	var wall_mat := Kit.material(room.wall_color)
	var ceiling_mat := Kit.material(room.wall_color.darkened(0.45))
	if room.has_floor:
		Kit.add_slab(builder, rect, floor_data.holes, 0.0, floor_mat)
	if not room.outdoor:
		var ceiling_holes: Array[Rect2] = []
		ceiling_holes.append_array(holes_above)
		Kit.add_slab(
			builder, rect, ceiling_holes, room.height + Kit.SLAB_THICKNESS, ceiling_mat, false
		)
	# Cristales del escaparate: se pueden romper y se recuerdan rotos.
	var panes := GlassPanes.new()
	panes.name = "glass_" + room.id
	panes.floor_id = floor_data.id
	panes.room_id = room.id
	var half := Kit.WALL_THICKNESS * 0.5
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	var z1 := rect.end.y
	var north := Vector3(0.0, 0.0, z0 + half)
	var south := Vector3(0.0, 0.0, z1 - half)
	var west := Vector3(x0 + half, 0.0, 0.0)
	var east := Vector3(x1 - half, 0.0, 0.0)
	var sides: Array[Array] = [
		[
			DoorSpec.SIDE_NORTH,
			RoomData.OPEN_NORTH,
			north + Vector3.RIGHT * x0,
			north + Vector3.RIGHT * x1
		],
		[
			DoorSpec.SIDE_SOUTH,
			RoomData.OPEN_SOUTH,
			south + Vector3.RIGHT * x0,
			south + Vector3.RIGHT * x1
		],
		[
			DoorSpec.SIDE_WEST,
			RoomData.OPEN_WEST,
			west + Vector3.BACK * z0,
			west + Vector3.BACK * z1
		],
		[
			DoorSpec.SIDE_EAST,
			RoomData.OPEN_EAST,
			east + Vector3.BACK * z0,
			east + Vector3.BACK * z1
		],
	]
	for side: Array in sides:
		var side_id: int = side[0]
		var open_bit: int = side[1]
		if room.open_sides & open_bit:
			continue
		var start: Vector3 = side[2]
		var end: Vector3 = side[3]
		var openings := _openings(room, side_id, start.distance_to(end))
		Kit.add_wall(builder, start, end, room.height, openings, wall_mat, panes)
	if panes.pane_count() > 0:
		add_child(panes)
		panes.build()
	else:
		# Sala sin escaparate: el grupo no entra en el árbol y hay que liberarlo a mano.
		panes.free()
	_add_shutter(room, builder)
	add_child(builder.build(room.id))
	_add_lights(room)
	_add_sign(room)


## Persiana metálica sobre la puerta principal: bajada del todo cierra el paso.
func _add_shutter(room: RoomData, builder: Kit.Builder) -> void:
	if room.shutter <= 0.0 or room.doors.is_empty():
		return
	var door: DoorSpec = room.doors[0]
	var drop := Kit.DOOR_HEIGHT * clampf(room.shutter, 0.0, 1.0)
	var center := _door_center(room, door) + Vector3.UP * (Kit.DOOR_HEIGHT - drop * 0.5)
	var size := Vector3(door.width, drop, 0.08)
	if door.side == DoorSpec.SIDE_WEST or door.side == DoorSpec.SIDE_EAST:
		size = Vector3(0.08, drop, door.width)
	builder.add_box(center, size, Kit.gray(0.3), room.shutter >= 0.99)


## Centro de una puerta a ras de suelo, en el plano de su pared.
func _door_center(room: RoomData, door: DoorSpec) -> Vector3:
	var rect := room.rect
	var half := Kit.WALL_THICKNESS * 0.5
	match door.side:
		DoorSpec.SIDE_NORTH:
			return Vector3(rect.position.x + door.offset, 0.0, rect.position.y + half)
		DoorSpec.SIDE_SOUTH:
			return Vector3(rect.position.x + door.offset, 0.0, rect.end.y - half)
		DoorSpec.SIDE_WEST:
			return Vector3(rect.position.x + half, 0.0, rect.position.y + door.offset)
		_:
			return Vector3(rect.end.x - half, 0.0, rect.position.y + door.offset)


## Luces del techo repartidas a lo largo del lado más largo de la sala, sin sombras.
## Corta o devuelve la energía del piso: cada luz baja hasta la de emergencia (tenue y
## anaranjada) o vuelve a la suya, en BLACKOUT_FADE segundos y sin parpadeos.
func set_power(on: bool) -> void:
	if on == powered:
		return
	powered = on
	if _power_tween != null:
		_power_tween.kill()
	if _lights.is_empty():
		return
	_power_tween = create_tween().set_parallel()
	for index: int in _lights.size():
		var light := _lights[index]
		var energy := _light_energy[index] * (1.0 if on else Rules.BLACKOUT_LIGHT_FACTOR)
		var color := LIGHT_COLOR if on else EMERGENCY_COLOR
		_power_tween.tween_property(light, "light_energy", energy, Rules.BLACKOUT_FADE)
		_power_tween.tween_property(light, "light_color", color, Rules.BLACKOUT_FADE)


func _add_lights(room: RoomData) -> void:
	if room.light_energy <= 0.0:
		return
	var rect := room.rect
	var center := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	var count := maxi(room.light_count, 1)
	var long_x := rect.size.x >= rect.size.y
	var span := rect.size.x if long_x else rect.size.y
	var height := room.height - 0.4 if not room.outdoor else 4.0
	for index: int in count:
		var light := OmniLight3D.new()
		var along := (float(index) + 0.5) / float(count) * span - span * 0.5
		var offset := Vector3(along, 0.0, 0.0) if long_x else Vector3(0.0, 0.0, along)
		light.position = center + offset + Vector3.UP * height
		light.omni_range = maxf(span / float(count), minf(rect.size.x, rect.size.y)) * 0.95
		light.light_energy = room.light_energy
		light.light_color = LIGHT_COLOR
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)
		_light_energy.append(room.light_energy)


## Rótulo con el nombre de la tienda sobre su puerta principal, pegado a la fachada.
func _add_sign(room: RoomData) -> void:
	if room.name_key.is_empty() or room.doors.is_empty():
		return
	var door: DoorSpec = room.doors[0]
	var spot := _door_center(room, door)
	var outward := Vector3.ZERO
	match door.side:
		DoorSpec.SIDE_NORTH:
			outward = Vector3.FORWARD
		DoorSpec.SIDE_SOUTH:
			outward = Vector3.BACK
		DoorSpec.SIDE_WEST:
			outward = Vector3.LEFT
		_:
			outward = Vector3.RIGHT
	var label := Label3D.new()
	label.text = tr(room.name_key)
	label.font_size = 64
	label.outline_size = 12
	label.pixel_size = 0.006
	label.position = spot + outward * 0.14 + Vector3.UP * (Kit.WINDOW_TOP + 0.55)
	label.rotation.y = atan2(outward.x, outward.z)
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


func _place_loot(room: RoomData, loot: Difficulty.FloorLoot) -> void:
	var world := GameState.world
	var floor_id := floor_data.id
	var origin := Vector3(room.rect.position.x, 0.0, room.rect.position.y)
	for index: int in room.loot.size():
		var spot: LootSpot = room.loot[index]
		var key := "%s_%d" % [room.id, index]
		var node: Interactable = null
		if spot.kind == LootSpot.KIND_PICKUP:
			var item := GameState.items.get_item(spot.item_id)
			var count := spot.count
			if item != null:
				count = loot.adjust(item.id, item.category, spot.count)
			if count <= 0 or world.is_taken(floor_id, key):
				continue
			var pickup := Pickup.new()
			pickup.item_id = spot.item_id
			pickup.count = count
			pickup.durability_fraction = spot.durability
			pickup.spot_key = key
			pickup.used.connect(func(_by: Player) -> void: world.mark_taken(floor_id, key))
			node = pickup
		else:
			var container := LootContainer.new()
			container.kind = spot.kind
			container.contents = loot.adjust_contents(spot.contents, GameState.items)
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


## Accesorios de decorado (bloque, cristal, barandilla, rótulo). Devuelve falso si el accesorio
## tiene función y necesita su propio nodo.
func _build_decor(spec: PropSpec, builders: Dictionary, loose: Kit.Builder) -> bool:
	var basis := Basis(Vector3.UP, deg_to_rad(spec.rotation_deg))
	var center := spec.position + Vector3.UP * (spec.size.y * 0.5)
	match spec.kind:
		PropSpec.KIND_BLOCK:
			# Todos los bloques de una sala comparten una superficie (gris en los vértices).
			_builder_at(spec.position, builders, loose).add_colored_box(
				Transform3D(basis, center), spec.size, Kit.gray_color(spec.shade)
			)
		PropSpec.KIND_GLASS:
			_builder_at(spec.position, builders, loose).add_oriented_box(
				Transform3D(basis, center), spec.size, Kit.glass_material()
			)
		PropSpec.KIND_RAIL:
			Kit.add_rail(
				_builder_at(spec.position, builders, loose),
				spec.position,
				spec.rotation_deg,
				spec.size.x
			)
		PropSpec.KIND_CAMERA:
			# Carcasa de la cámara (decorado sin colisión; la imagen la da el monitor).
			_builder_at(spec.position, builders, loose).add_colored_box(
				Transform3D(basis, spec.position),
				Vector3(0.22, 0.16, 0.34),
				Color(0.12, 0.12, 0.13),
				false
			)
		PropSpec.KIND_SIGN:
			var label := Label3D.new()
			label.text = tr(spec.text_key)
			label.font_size = 64
			label.outline_size = 12
			label.pixel_size = clampf(spec.size.y, 0.002, 0.03)
			label.position = spec.position
			label.rotation.y = deg_to_rad(spec.rotation_deg)
			add_child(label)
		_:
			return false
	return true


## Accesorios: los de decorado se funden con la malla de su sala; los que tienen función son
## nodos propios. Si una estantería ya se rompió o un tablero ya se apagó, aparecen así.
func _build_prop(spec: PropSpec, key: String, builders: Dictionary, loose: Kit.Builder) -> void:
	if _build_decor(spec, builders, loose):
		return
	var world := GameState.world
	var floor_id := floor_data.id
	var used := world.is_taken(floor_id, key)
	if spec.kind == PropSpec.KIND_NOTE:
		var note := TechNote.new()
		note.note_id = spec.text_key
		note.position = spec.position
		note.rotation.y = deg_to_rad(spec.rotation_deg)
		add_child(note)
		return
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
		add_child(panel)
		if used:
			panel.set_dead()
		panel.shorted.connect(func() -> void: world.mark_taken(floor_id, key))
		return
	var shelf := BreakableShelf.new()
	shelf.size = spec.size
	shelf.position = spec.position
	shelf.rotation.y = deg_to_rad(spec.rotation_deg)
	add_child(shelf)
	if used:
		shelf.set_broken_silently()
	shelf.broken.connect(func() -> void: world.mark_taken(floor_id, key))

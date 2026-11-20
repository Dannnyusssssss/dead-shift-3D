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
## Paneles de luz del techo, carteles de salida y una de cada cuántas luces está rota.
const LIGHT_PANEL_COLOR: Color = Color(0.92, 0.95, 1.0)
const EXIT_SIGN_COLOR: Color = Color(0.2, 0.85, 0.35)
## Distancia de cada luz al techo (bajo su panel) y altura de las farolas de la azotea.
const LIGHT_DROP: float = 1.1
const OUTDOOR_LAMP_HEIGHT: float = 3.6
const OUTDOOR_LAMP_INSET: float = 0.8
const BROKEN_LIGHT_ONE_IN: int = 4
## Capa visual de lo que se mueve entre pisos (jugador, enemigos, objetos lanzados, efectos):
## la iluminan las luces de cualquier piso. Lo fijo de cada piso va en su propia capa
## (DYNAMIC_LAYER << (índice del piso + 1)) y sus luces solo alumbran esa capa y la dinámica.
## Así una malla nunca suma las luces de los pisos de arriba y de abajo: el render solo aplica
## 8 luces por malla y, al pasar de ese tope, cuáles se pintaban dependía de la cámara (paredes,
## marcos y barandillas cambiaban entre dos encuadres casi iguales).
const DYNAMIC_LAYER: int = 1
## Fondo del escaparate de una tienda cerrada: distancia desde la pared del escaparate.
const CLOSED_DISPLAY_DEPTH: float = 1.3
## Placas de los rótulos de las tiendas: ancho y colores (oscuros para que el texto se lea).
const SIGN_PLATE_WIDTH: float = 3.2
const SIGN_COLORS: Array[Color] = [
	Color(0.32, 0.08, 0.08),
	Color(0.08, 0.16, 0.3),
	Color(0.1, 0.24, 0.16),
	Color(0.26, 0.18, 0.06),
	Color(0.2, 0.1, 0.24),
	Color(0.12, 0.12, 0.14),
]

var floor_data: FloorData = null
## Huecos del piso de arriba: allí las salas de este piso no llevan techo.
var holes_above: Array[Rect2] = []
## Falso durante el apagón del jefe.
var powered: bool = true

var _lights: Array[OmniLight3D] = []
## Círculos del suelo donde no cae desorden (puertas, botín, salidas, muebles).
var _clutter_blocked: Array[Vector4] = []
var _light_energy: Array[float] = []
var _power_tween: Tween = null
## Copia del material de superficies solo para este piso: el apagón baja su brillo (paneles y
## carteles) sin tocar los demás pisos.
var _surface_material: ShaderMaterial = null


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
		# Escalera de servicio de hormigón; escalera mecánica de chapa estriada.
		var stairs := ramp.kind == RampSpec.KIND_STAIRS
		var step_mat := Kit.surface(
			"concrete_light" if stairs else "diamond_plate", Kit.gray_color(0.85 if stairs else 0.7)
		)
		Kit.add_ramp(target, ramp, step_mat, Kit.surface("concrete_light", Kit.gray_color(0.75)))
	_clutter_blocked = RoomDressing.blocked_points(floor_data)
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
	_apply_visual_layer(self)


## Las superficies con el material compartido del edificio pasan a usar la copia de este piso.
func _use_floor_material(instance: MeshInstance3D) -> void:
	if instance.mesh == null:
		return
	var shared := Kit.surface_material()
	for surface: int in instance.mesh.get_surface_count():
		if instance.mesh.surface_get_material(surface) != shared:
			continue
		if _surface_material == null:
			_surface_material = shared.duplicate() as ShaderMaterial
			_surface_material.set_shader_parameter("emission_scale", 1.0)
		instance.set_surface_override_material(surface, _surface_material)


## Capa visual propia de este piso.
func visual_layer() -> int:
	return DYNAMIC_LAYER << (floor_data.level_index + 1)


## Pone todo lo fijo del piso en su capa y hace que sus luces solo alumbren esa capa y la de lo
## que se mueve.
func _apply_visual_layer(node: Node) -> void:
	var own := visual_layer()
	if node is Light3D:
		(node as Light3D).light_cull_mask = own | DYNAMIC_LAYER
	elif node is VisualInstance3D:
		(node as VisualInstance3D).layers = own
		if node is MeshInstance3D:
			_use_floor_material(node as MeshInstance3D)
	for child: Node in node.get_children():
		_apply_visual_layer(child)


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


## Sala que contiene el punto (en coordenadas del piso), o null.
func _room_at(point: Vector3) -> RoomData:
	for room: RoomData in floor_data.rooms:
		if room.rect.has_point(Vector2(point.x, point.z)):
			return room
	return null


## Constructor de la sala que contiene el punto (o el de piezas sueltas si ninguna).
func _builder_at(point: Vector3, builders: Dictionary, loose: Kit.Builder) -> Kit.Builder:
	for room: RoomData in floor_data.rooms:
		if room.rect.has_point(Vector2(point.x, point.z)):
			var found: Kit.Builder = builders[room.id]
			return found
	return loose


func _build_room(room: RoomData, builder: Kit.Builder) -> void:
	var rect := room.rect
	var floor_mat := Kit.surface(_floor_surface(room), Surfaces.texture_tint(room.floor_color))
	var wall_mat := Kit.surface(
		_pick(room.wall_surface, Surfaces.DEFAULT_WALL), Surfaces.texture_tint(room.wall_color)
	)
	var ceiling_mat := Kit.surface(
		_pick(room.ceiling_surface, Surfaces.DEFAULT_CEILING),
		Surfaces.texture_tint(room.wall_color.darkened(0.3))
	)
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
	_add_closed_backdrop(room, builder, wall_mat)
	RoomDressing.dress_closed_display(room, builder, CLOSED_DISPLAY_DEPTH)
	if room.id == "restrooms":
		RoomDressing.furnish_restroom(room, builder)
	RoomDressing.scatter_clutter(floor_data, room, builder, _clutter_blocked)
	_add_sign(room, builder)
	_add_lights(room, builder)
	_add_exit_signs(room, builder)
	add_child(builder.build(room.id))


## Superficie del suelo de una sala: la suya, o asfalto al aire libre y hormigón dentro.
static func _floor_surface(room: RoomData) -> String:
	if room.outdoor:
		return _pick(room.floor_surface, Surfaces.DEFAULT_OUTDOOR_FLOOR)
	return _pick(room.floor_surface, Surfaces.DEFAULT_FLOOR)


static func _pick(value: String, fallback: String) -> String:
	return value if not value.is_empty() else fallback


## Persiana metálica sobre la puerta principal de una tienda cerrada (sólida, a medias o hasta
## el suelo).
func _add_shutter(room: RoomData, builder: Kit.Builder) -> void:
	if room.shutter <= 0.0 or room.doors.is_empty():
		return
	var door: DoorSpec = room.doors[0]
	var drop := Kit.DOOR_HEIGHT * clampf(room.shutter, 0.0, 1.0)
	var center := _door_center(room, door) + Vector3.UP * (Kit.DOOR_HEIGHT - drop * 0.5)
	var size := Vector3(door.width, drop, 0.08)
	if door.side == DoorSpec.SIDE_WEST or door.side == DoorSpec.SIDE_EAST:
		size = Vector3(0.08, drop, door.width)
	# Una tienda con persiana está cerrada: la persiana siempre es sólida.
	builder.add_box(center, size, Kit.surface("corrugated", Kit.gray_color(0.75)), true)
	if room.shutter < 0.99:
		# Persiana a medias: debajo, la puerta de cristal oscuro cerrada (no se pasa).
		var gap := Kit.DOOR_HEIGHT - drop
		var door_size := Vector3(door.width, gap, 0.06)
		if door.side == DoorSpec.SIDE_WEST or door.side == DoorSpec.SIDE_EAST:
			door_size = Vector3(0.06, gap, door.width)
		builder.add_box(
			_door_center(room, door) + Vector3.UP * (gap * 0.5), door_size, Kit.gray(0.06), true
		)
		# Tirador con cadena: se entiende que está cerrada sin depender del color.
		var bar := Vector3(minf(door.width * 0.5, 0.8), 0.05, 0.1)
		if door.side == DoorSpec.SIDE_WEST or door.side == DoorSpec.SIDE_EAST:
			bar = Vector3(0.1, 0.05, minf(door.width * 0.5, 0.8))
		builder.add_box(
			_door_center(room, door) + Vector3.UP * minf(1.05, gap - 0.1),
			bar,
			Kit.gray(0.65),
			false
		)


## Tienda cerrada: fondo sólido a poca distancia detrás del escaparate. Así el escaparate se ve
## como un escaparate (con lo que se exponga delante) y nunca deja ver una sala vacía.
func _add_closed_backdrop(
	room: RoomData, builder: Kit.Builder, wall_mat: StandardMaterial3D
) -> void:
	if not room.is_closed() or room.storefront_side < 0:
		return
	var rect := room.rect
	var inset := Kit.WALL_THICKNESS + CLOSED_DISPLAY_DEPTH
	var center := Vector3.ZERO
	var size := Vector3.ZERO
	match room.storefront_side:
		DoorSpec.SIDE_NORTH, DoorSpec.SIDE_SOUTH:
			var z := (
				rect.position.y + inset
				if room.storefront_side == DoorSpec.SIDE_NORTH
				else rect.end.y - inset
			)
			center = Vector3(rect.get_center().x, room.height * 0.5, z)
			size = Vector3(rect.size.x - Kit.WALL_THICKNESS * 2.0, room.height, 0.1)
		_:
			var x := (
				rect.position.x + inset
				if room.storefront_side == DoorSpec.SIDE_WEST
				else rect.end.x - inset
			)
			center = Vector3(x, room.height * 0.5, rect.get_center().y)
			size = Vector3(0.1, room.height, rect.size.y - Kit.WALL_THICKNESS * 2.0)
	builder.add_box(center, size, wall_mat, true)


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
	if _surface_material != null:
		_power_tween.tween_property(
			_surface_material,
			"shader_parameter/emission_scale",
			1.0 if on else Rules.BLACKOUT_EMISSION_FACTOR,
			Rules.BLACKOUT_FADE
		)
	for index: int in _lights.size():
		var light := _lights[index]
		var energy := _light_energy[index] * (1.0 if on else Rules.BLACKOUT_LIGHT_FACTOR)
		var color := LIGHT_COLOR if on else EMERGENCY_COLOR
		_power_tween.tween_property(light, "light_energy", energy, Rules.BLACKOUT_FADE)
		_power_tween.tween_property(light, "light_color", color, Rules.BLACKOUT_FADE)


## Luces del techo de una sala: un panel que brilla por cada luz y su luz real. Algunas están
## rotas (panel apagado y sin luz) para que haya zonas oscuras: siempre las mismas, nunca en
## zonas seguras ni en salas de una sola luz, y nunca todas las de una sala. Sin parpadeos.
func _add_lights(room: RoomData, builder: Kit.Builder) -> void:
	if room.light_energy <= 0.0:
		return
	var rect := room.rect
	var center := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	var count := maxi(room.light_count, 1)
	var long_x := rect.size.x >= rect.size.y
	var span := rect.size.x if long_x else rect.size.y
	# La luz cuelga algo por debajo del panel: a 0,4 m del techo dejaba un disco brillante y de
	# borde marcado en el techo.
	var height := room.height - LIGHT_DROP if not room.outdoor else OUTDOOR_LAMP_HEIGHT
	for index: int in count:
		var along := (float(index) + 0.5) / float(count) * span - span * 0.5
		var offset := Vector3(along, 0.0, 0.0) if long_x else Vector3(0.0, 0.0, along)
		if room.outdoor:
			# Al aire libre las farolas van junto al pretil, lejos del helipuerto y de los equipos.
			var edge := rect.size.y if long_x else rect.size.x
			offset += (
				Vector3(0.0, 0.0, -edge * 0.5 + OUTDOOR_LAMP_INSET)
				if long_x
				else Vector3(-edge * 0.5 + OUTDOOR_LAMP_INSET, 0.0, 0.0)
			)
		var broken := is_light_broken(room, index)
		if not room.outdoor:
			var panel := Transform3D(
				Basis.IDENTITY, center + offset + Vector3.UP * (room.height - 0.03)
			)
			var panel_mat := Kit.gray(0.22) if broken else Kit.emissive(LIGHT_PANEL_COLOR)
			builder.add_box(panel.origin, Vector3(1.2, 0.04, 0.5), panel_mat, false)
		elif not broken:
			# Al aire libre: farola (poste y cabeza) para que la luz tenga su fuente.
			var pole := center + offset
			builder.add_box(
				pole + Vector3.UP * (OUTDOOR_LAMP_HEIGHT * 0.5),
				Vector3(0.12, OUTDOOR_LAMP_HEIGHT, 0.12),
				Kit.gray(0.3)
			)
			builder.add_box(
				pole + Vector3.UP * (OUTDOOR_LAMP_HEIGHT + 0.08),
				Vector3(0.6, 0.12, 0.3),
				Kit.emissive(LIGHT_PANEL_COLOR),
				false
			)
		if broken:
			continue
		var light := OmniLight3D.new()
		light.position = center + offset + Vector3.UP * height
		light.omni_range = maxf(span / float(count), minf(rect.size.x, rect.size.y)) * 0.95
		light.light_energy = room.light_energy
		light.light_color = LIGHT_COLOR
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)
		_light_energy.append(room.light_energy)


## Si la luz index de la sala está rota (siempre la misma para la misma sala).
static func is_light_broken(room: RoomData, index: int) -> bool:
	var count := maxi(room.light_count, 1)
	if count < 2 or room.safe_zone or room.outdoor:
		return false
	# Con todas rotas quedaría a oscuras: la primera siempre funciona en ese caso.
	var all_broken := true
	for other: int in count:
		if absi(("%s:%d" % [room.id, other]).hash()) % BROKEN_LIGHT_ONE_IN != 0:
			all_broken = false
	if all_broken and index == 0:
		return false
	return absi(("%s:%d" % [room.id, index]).hash()) % BROKEN_LIGHT_ONE_IN == 0


## Carteles de salida de emergencia (verdes, siempre encendidos) sobre las puertas de las salas
## de servicio, por fuera.
func _add_exit_signs(room: RoomData, builder: Kit.Builder) -> void:
	# Los baños llevan su propio rótulo (figuras), no el de salida de emergencia.
	if (
		room.storefront_side >= 0
		or room.outdoor
		or room.name_key.is_empty()
		or room.id == "restrooms"
	):
		return
	for door: DoorSpec in room.doors:
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
		var spot := (
			_door_center(room, door) + outward * 0.13 + Vector3.UP * (Kit.DOOR_HEIGHT + 0.22)
		)
		var size := Vector3(0.42, 0.16, 0.05)
		if door.side == DoorSpec.SIDE_WEST or door.side == DoorSpec.SIDE_EAST:
			size = Vector3(0.05, 0.16, 0.42)
		builder.add_box(spot, size, Kit.emissive(EXIT_SIGN_COLOR), false)


## Rótulo sobre la puerta principal, pegado a la fachada. Las tiendas con marca (clave de texto
## brand_<id de la sala>, nombres inventados) llevan una placa de color con la marca grande y la
## categoría debajo; las demás salas, solo su nombre. La placa se funde con la malla de la sala.
func _add_sign(room: RoomData, builder: Kit.Builder) -> void:
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
	var yaw := atan2(outward.x, outward.z)
	# Por encima de la puerta, sin pasar del alto de la sala (en una caseta baja quedaba sobre el
	# borde de la pared, flotando).
	var center := spot + Vector3.UP * minf(Kit.WINDOW_TOP + 0.55, room.height - 0.45)
	var brand_key := "brand_" + room.id
	var brand := tr(brand_key)
	if brand == brand_key:
		var label := _sign_label(tr(room.name_key), 0.006, Color.WHITE)
		label.position = center + outward * 0.14
		label.rotation.y = yaw
		add_child(label)
		return
	var plate := Transform3D(Basis(Vector3.UP, yaw), center + outward * 0.14)
	builder.add_colored_box(
		plate, Vector3(SIGN_PLATE_WIDTH, 0.72, 0.06), _sign_color(room.id), false
	)
	var title := _sign_label(brand, 0.0075, Color(0.96, 0.93, 0.86))
	title.position = center + outward * 0.18 + Vector3.UP * 0.09
	title.rotation.y = yaw
	add_child(title)
	var category := _sign_label(tr(room.name_key), 0.0032, Color(0.78, 0.78, 0.76))
	category.position = center + outward * 0.18 + Vector3.UP * -0.21
	category.rotation.y = yaw
	add_child(category)


func _sign_label(text: String, pixel: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.outline_size = 12
	label.pixel_size = pixel
	label.modulate = color
	# Solo por delante: por detrás se leía en espejo (a través de cristales o desde las cámaras).
	label.double_sided = false
	return label


## Color de la placa de una tienda: siempre el mismo para la misma sala (paleta apagada).
static func _sign_color(room_id: String) -> Color:
	return SIGN_COLORS[absi(room_id.hash()) % SIGN_COLORS.size()]


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
	var spots := GameState.loot_for(floor_id, room)
	for index: int in spots.size():
		var spot: LootSpot = spots[index]
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
		if node is LootContainer and is_zero_approx(spot.rotation_deg):
			(node as LootContainer).facing = facing_room_center(room, node.position)
		add_child(node)


## Giro (en radianes, en pasos de 90 grados) para que el frente (-Z) de algo colocado en point
## mire hacia el centro de la sala: así una puerta o un cajón no se abren contra la pared.
static func facing_room_center(room: RoomData, point: Vector3) -> float:
	var center := room.rect.get_center()
	var toward := Vector2(center.x - point.x, center.y - point.z)
	if toward.length() < 0.01:
		return 0.0
	if absf(toward.x) > absf(toward.y):
		return -PI * 0.5 if toward.x > 0.0 else PI * 0.5
	return 0.0 if toward.y < 0.0 else PI


## Accesorios de decorado (bloque, cristal, barandilla, rótulo). Devuelve falso si el accesorio
## tiene función y necesita su propio nodo.
func _build_decor(spec: PropSpec, builders: Dictionary, loose: Kit.Builder) -> bool:
	var basis := Basis(Vector3.UP, deg_to_rad(spec.rotation_deg))
	var center := spec.position + Vector3.UP * (spec.size.y * 0.5)
	match spec.kind:
		PropSpec.KIND_BLOCK:
			var block_builder := _builder_at(spec.position, builders, loose)
			if spec.collision_only:
				# La forma la pone un modelo; el bloque solo conserva la colisión.
				block_builder.add_collision(Transform3D(basis, center), spec.size)
			else:
				# Todos los bloques de una sala comparten una superficie (gris en los vértices).
				block_builder.add_colored_box(
					Transform3D(basis, center), spec.size, Kit.gray_color(spec.shade)
				)
		PropSpec.KIND_MODEL:
			var placed := _builder_at(spec.position, builders, loose).add_model(
				Transform3D(basis, spec.position), spec.text_key
			)
			if not placed:
				push_warning("Modelo de decorado inexistente: " + spec.text_key)
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
			# Solo por delante: un rótulo que se lee por los dos lados lleva dos copias en los datos.
			label.double_sided = false
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
		var monitor_room := _room_at(spec.position)
		if monitor_room != null and is_zero_approx(spec.rotation_deg):
			# Las pantallas miran hacia dentro de la sala, no a la pared.
			monitor.rotation.y = facing_room_center(monitor_room, spec.position)
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

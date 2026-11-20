class_name RoomDressing
extends RefCounted
## Mobiliario que se coloca por código según el tipo de sala, fundido con la malla de la sala
## (no añade llamadas de dibujo): los baños (cubículos, lavabos con espejo, secamanos,
## urinarios y rótulo), los escaparates de las tiendas cerradas (artículos según la tienda) y el
## desorden del ataque por el suelo (papeles, ropa, cajas volcadas, sillas caídas, escombros).
## El desorden no tiene colisión y nunca cae en puertas, escaleras, huecos, salidas, botín ni
## muebles. Todo es determinista: la misma sala sale siempre igual.

## Escaparate de cada tienda cerrada (por la clave de su nombre).
const DISPLAYS: Dictionary = {
	"room_books": "display_books",
	"room_toys": "display_toys",
	"room_optics": "display_optics",
	"room_jewelry": "display_jewelry",
	"room_boutique": "display_boutique",
	"room_cinema": "display_cinema",
}
const DISPLAY_WIDTH: float = 3.0
## Alto de la tarima propia de los modelos de escaparate.
const DISPLAY_BASE_HEIGHT: float = 0.25
## Zócalo de azulejo de los baños: alto y separación de la cara de la pared.
const TILE_BAND_HEIGHT: float = 1.4
const TILE_BAND_GAP: float = 0.006
## Grosor del zócalo de azulejo.
const TILE_BAND_THICKNESS: float = 0.01
const CLUTTER_MODELS: Array[String] = [
	"clutter_papers",
	"clutter_clothes",
	"clutter_box",
	"clutter_chair",
	"clutter_bags",
	"clutter_debris",
	"clutter_papers",
]
## Salas sin desorden (las cerradas y los baños también se excluyen).
const TIDY_ROOMS: Array[String] = ["service_stairs", "roof_stairs", "stair_hut", "roof"]
## Huecos que el desorden deja libres (metros).
const CLUTTER_WALL_GAP: float = 0.5
const CLUTTER_DOOR_GAP: float = 1.8
const CLUTTER_LOOT_GAP: float = 1.3
const CLUTTER_PROP_GAP: float = 0.5
const CLUTTER_EXIT_GAP: float = 2.2
const CLUTTER_RAMP_GAP: float = 1.0
const CLUTTER_SPACING: float = 1.6
## Metros cuadrados de suelo por pieza de desorden y tope por sala.
const CLUTTER_AREA_EACH: float = 16.0
const CLUTTER_MAX: int = 7


## Marco de una sala visto desde una de sus paredes: u a lo largo de la pared (desde la esquina)
## y v hacia dentro de la sala.
class Frame:
	extends RefCounted
	var origin: Vector3 = Vector3.ZERO
	var along: Vector3 = Vector3.RIGHT
	var inward: Vector3 = Vector3.BACK
	var length: float = 0.0
	var depth: float = 0.0

	static func of(room: RoomData, side: int) -> Frame:
		var frame := Frame.new()
		var rect := room.rect
		match side:
			DoorSpec.SIDE_NORTH:
				frame.origin = Vector3(rect.position.x, 0.0, rect.position.y)
				frame.inward = Vector3.BACK
			DoorSpec.SIDE_SOUTH:
				frame.origin = Vector3(rect.position.x, 0.0, rect.end.y)
				frame.inward = Vector3.FORWARD
			DoorSpec.SIDE_WEST:
				frame.origin = Vector3(rect.position.x, 0.0, rect.position.y)
				frame.along = Vector3.BACK
				frame.inward = Vector3.RIGHT
			_:
				frame.origin = Vector3(rect.end.x, 0.0, rect.position.y)
				frame.along = Vector3.BACK
				frame.inward = Vector3.LEFT
		var horizontal := side == DoorSpec.SIDE_NORTH or side == DoorSpec.SIDE_SOUTH
		frame.length = rect.size.x if horizontal else rect.size.y
		frame.depth = rect.size.y if horizontal else rect.size.x
		return frame

	func point(u: float, v: float) -> Vector3:
		return origin + along * u + inward * v


## Giro (radianes) para que el frente de un modelo (-Z) mire hacia direction.
static func yaw_facing(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## Coloca un modelo (y su colisión si collision no es cero) en el constructor de la sala.
static func place(
	builder: Kit.Builder, model_id: String, at: Vector3, yaw: float, collision: Vector3
) -> void:
	var basis := Basis(Vector3.UP, yaw)
	builder.add_model(Transform3D(basis, at), model_id)
	if collision != Vector3.ZERO:
		builder.add_collision(Transform3D(basis, at + Vector3.UP * (collision.y * 0.5)), collision)


## Baño: cubículos contra la pared del fondo, lavabos con espejo y secamanos en una pared lateral
## y urinarios en la otra; el rótulo con las figuras va fuera, junto a la puerta.
static func furnish_restroom(room: RoomData, builder: Kit.Builder) -> void:
	if room.doors.is_empty():
		return
	var door: DoorSpec = room.doors[0]
	var front := Frame.of(room, door.side)
	var wall := Kit.WALL_THICKNESS
	var toward_door := -front.inward
	# Zócalo de azulejo (1,4 m) en las tres paredes sin puerta, pegado a la cara de la pared.
	var tiles := Kit.surface("tiles_checker", Color(0.92, 0.92, 0.9))
	var inner := front.depth - wall - TILE_BAND_GAP
	builder.add_oriented_box(
		Transform3D(
			Basis(Vector3.UP, yaw_facing(toward_door)),
			front.point(front.length * 0.5, inner) + Vector3.UP * (TILE_BAND_HEIGHT * 0.5)
		),
		Vector3(front.length - wall * 2.0, TILE_BAND_HEIGHT, TILE_BAND_THICKNESS),
		tiles,
		false
	)
	for u: float in [wall + TILE_BAND_GAP, front.length - wall - TILE_BAND_GAP]:
		builder.add_oriented_box(
			Transform3D(
				Basis(Vector3.UP, yaw_facing(front.along)),
				front.point(u, front.depth * 0.5) + Vector3.UP * (TILE_BAND_HEIGHT * 0.5)
			),
			Vector3(front.depth - wall * 2.0, TILE_BAND_HEIGHT, TILE_BAND_THICKNESS),
			tiles,
			false
		)
	# Cubículos en fila contra la pared del fondo, mirando hacia la puerta.
	var stalls := clampi(int((front.length - 0.6) / 1.05), 1, 3)
	for index: int in stalls:
		var at := front.point(wall + 0.55 + index * 1.05, front.depth - wall - 0.75)
		place(builder, "toilet_stall", at, yaw_facing(toward_door), Vector3(1.0, 2.0, 1.5))
	# Lavabos en la pared lateral izquierda (u = 0) a media sala, mirando hacia dentro, apoyados en
	# la cara del zócalo (dentro de él, sus caras de atrás coincidían con las del azulejo).
	var tiled := wall + TILE_BAND_GAP + TILE_BAND_THICKNESS * 0.5
	var sinks_at := front.point(tiled + 0.28, front.depth * 0.45)
	place(builder, "sink_counter", sinks_at, yaw_facing(front.along), Vector3(2.0, 0.9, 0.55))
	place(
		builder,
		"hand_dryer",
		front.point(tiled + 0.11, front.depth * 0.45 - 1.5),
		yaw_facing(front.along),
		Vector3.ZERO
	)
	# Urinarios en la pared lateral derecha.
	for index: int in 2:
		var at := front.point(front.length - wall - 0.15, front.depth * 0.4 + index * 0.8)
		place(builder, "urinal", at, yaw_facing(-front.along), Vector3(0.4, 1.1, 0.3))
	# Rótulo de baño fuera, en la pared, al lado de la puerta.
	var beside := door.offset + door.width * 0.5 + 0.45
	if beside > front.length - 0.4:
		beside = door.offset - door.width * 0.5 - 0.45
	var sign_at := front.point(beside, -0.02) + Vector3.UP * 1.7
	place(builder, "restroom_sign", sign_at, yaw_facing(-front.inward), Vector3.ZERO)


## Tienda cerrada: artículos de su tipo entre el cristal del escaparate y el fondo.
static func dress_closed_display(room: RoomData, builder: Kit.Builder, depth: float) -> void:
	if not room.is_closed() or room.storefront_side < 0:
		return
	var model_id: String = DISPLAYS.get(room.name_key, "")
	if model_id.is_empty():
		return
	var front := Frame.of(room, room.storefront_side)
	var count := maxi(int((front.length - 0.4) / DISPLAY_WIDTH), 1)
	var start := (front.length - count * DISPLAY_WIDTH) * 0.5 + DISPLAY_WIDTH * 0.5
	var v := Kit.WALL_THICKNESS + depth * 0.5
	# La tarima del modelo (0,25 m) se sube hasta el alféizar del cristal, sobre un pedestal
	# sólido: si no, lo expuesto quedaría tapado por la pared bajo el cristal.
	var lift := Kit.WINDOW_SILL - DISPLAY_BASE_HEIGHT
	for index: int in count:
		var at := front.point(start + index * DISPLAY_WIDTH, v)
		var yaw := yaw_facing(-front.inward)
		builder.add_oriented_box(
			Transform3D(Basis(Vector3.UP, yaw), at + Vector3.UP * (lift * 0.5)),
			Vector3(DISPLAY_WIDTH, lift, depth - 0.2),
			Kit.gray(0.2),
			true
		)
		# El frente del escaparate mira al pasillo (hacia el cristal).
		place(builder, model_id, at + Vector3.UP * lift, yaw, Vector3.ZERO)


## Si una sala lleva desorden por el suelo.
static func wants_clutter(room: RoomData) -> bool:
	return not (
		room.is_closed()
		or room.safe_zone
		or room.outdoor
		or room.id == "restrooms"
		or TIDY_ROOMS.has(room.id)
	)


## Puntos donde no puede caer desorden en un piso: puertas, botín, salidas y muebles.
static func blocked_points(floor_data: FloorData) -> Array[Vector4]:
	# x, z, radio, (sin uso): círculos prohibidos.
	var result: Array[Vector4] = []
	for room: RoomData in floor_data.rooms:
		for door: DoorSpec in room.doors:
			var frame := Frame.of(room, door.side)
			var center := frame.point(door.offset, 0.0)
			result.append(Vector4(center.x, center.z, CLUTTER_DOOR_GAP + door.width * 0.5, 0.0))
		var origin := Vector3(room.rect.position.x, 0.0, room.rect.position.y)
		for spot: LootSpot in room.loot:
			var at := origin + spot.position
			result.append(Vector4(at.x, at.z, CLUTTER_LOOT_GAP, 0.0))
	for floor_exit: FloorExit in floor_data.exits:
		result.append(Vector4(floor_exit.position.x, floor_exit.position.z, CLUTTER_EXIT_GAP, 0.0))
		result.append(Vector4(floor_exit.arrival.x, floor_exit.arrival.z, CLUTTER_EXIT_GAP, 0.0))
	for spec: PropSpec in floor_data.props:
		if spec.kind == PropSpec.KIND_SIGN or spec.kind == PropSpec.KIND_CAMERA:
			continue
		var radius := maxf(spec.size.x, spec.size.z) * 0.5 + CLUTTER_PROP_GAP
		result.append(Vector4(spec.position.x, spec.position.z, radius, 0.0))
	for gate: GateSpec in floor_data.gates:
		result.append(Vector4(gate.position.x, gate.position.z, CLUTTER_DOOR_GAP + 1.0, 0.0))
	return result


## Desorden del ataque por el suelo de una sala (sin colisión). Devuelve dónde cayó cada pieza.
static func scatter_clutter(
	floor_data: FloorData, room: RoomData, builder: Kit.Builder, blocked: Array[Vector4]
) -> Array[Vector2]:
	var placed: Array[Vector2] = []
	if not wants_clutter(room):
		return placed
	var rect := room.rect.grow(-CLUTTER_WALL_GAP)
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return placed
	var wanted := clampi(int(room.rect.get_area() / CLUTTER_AREA_EACH), 1, CLUTTER_MAX)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(("%s/%s" % [floor_data.id, room.id]).hash())
	for attempt: int in wanted * 12:
		if placed.size() >= wanted:
			break
		var spot := Vector2(
			rng.randf_range(rect.position.x, rect.end.x),
			rng.randf_range(rect.position.y, rect.end.y)
		)
		var model_id: String = CLUTTER_MODELS[rng.randi_range(0, CLUTTER_MODELS.size() - 1)]
		var yaw := rng.randf_range(0.0, TAU)
		if not clutter_spot_free(floor_data, spot, blocked, placed):
			continue
		placed.append(spot)
		place(builder, model_id, Vector3(spot.x, 0.0, spot.y), yaw, Vector3.ZERO)
	return placed


## Si en ese punto del suelo puede ir una pieza de desorden.
static func clutter_spot_free(
	floor_data: FloorData, spot: Vector2, blocked: Array[Vector4], placed: Array[Vector2]
) -> bool:
	for hole: Rect2 in floor_data.holes:
		if hole.grow(0.8).has_point(spot):
			return false
	for ramp: RampSpec in floor_data.ramps:
		if _near_ramp(ramp, spot):
			return false
	for circle: Vector4 in blocked:
		if spot.distance_to(Vector2(circle.x, circle.y)) < circle.z:
			return false
	for other: Vector2 in placed:
		if spot.distance_to(other) < CLUTTER_SPACING:
			return false
	return true


static func _near_ramp(ramp: RampSpec, spot: Vector2) -> bool:
	var start := Vector2(ramp.start.x, ramp.start.z)
	var forward3 := ramp.forward()
	var forward := Vector2(forward3.x, forward3.z).normalized()
	var side := Vector2(-forward.y, forward.x)
	var offset := spot - start
	var along := offset.dot(forward)
	var across := absf(offset.dot(side))
	var half_width := ramp.width * float(maxi(ramp.lanes, 1)) * 0.5 + CLUTTER_RAMP_GAP
	return (
		along > -CLUTTER_RAMP_GAP - 1.0
		and along < ramp.run + CLUTTER_RAMP_GAP + 1.0
		and (across < half_width)
	)

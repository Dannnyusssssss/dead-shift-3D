class_name MapView
extends Control
## Mapa del piso actual (si el jugador tiene el plano de la sala de seguridad): salas con su
## nombre, zonas seguras, salidas y la posición del jugador. Marca con un número la sala donde
## están las piezas del teléfono y las llaves que faltan, con una lista escrita al lado (este
## piso, zonas seguras y lo que hay en otros pisos). Se abre con la acción «map», el botón
## táctil o tocando el plano en la mochila; se cierra igual o con «Cerrar». Mientras está
## abierto el jugador queda quieto.

const MAP_ITEM: String = MapMarkers.MAP_ITEM
const MARGIN: float = 60.0
## Ancho de la lista escrita a la derecha.
const LIST_WIDTH: float = 360.0
const MARKER_RADIUS: float = 13.0
const MARKER_COLOR: Color = Color(1.0, 0.75, 0.25)

var _player: Player = null
var _canvas: Control = null
var _title: Label = null
var _legend: Label = null
var _list: Label = null
## Marcas del piso actual: [{"number", "room_id"}], calculadas al abrir.
var _markers: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.position = Vector2(24.0, 16.0)
	add_child(_title)
	_legend = Label.new()
	_legend.add_theme_font_size_override("font_size", 18)
	_legend.text = tr("map_legend")
	_legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_legend.offset_left = 24.0
	_legend.offset_top = -44.0
	_legend.offset_right = 900.0
	add_child(_legend)
	var list_panel := PanelContainer.new()
	list_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	list_panel.offset_left = -LIST_WIDTH - 24.0
	list_panel.offset_top = 92.0
	list_panel.offset_right = -24.0
	list_panel.offset_bottom = -60.0
	add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)
	_list = Label.new()
	_list.add_theme_font_size_override("font_size", 18)
	_list.autowrap_mode = TextServer.AUTOWRAP_WORD
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var close_button := TapButton.new()
	close_button.text = tr("inventory_close")
	close_button.custom_minimum_size = Vector2(160.0, 60.0)
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -190.0
	close_button.offset_top = 16.0
	close_button.offset_right = -24.0
	close_button.offset_bottom = 76.0
	close_button.pressed.connect(close)
	add_child(close_button)


func bind_player(player: Player) -> void:
	_player = player


func is_open() -> bool:
	return visible


## Abre el mapa si el jugador tiene el plano; si no, avisa.
func open() -> void:
	if _player == null or _player.is_dead() or not _player.controls_enabled:
		return
	if not GameState.player.keys.has(MAP_ITEM):
		EventBus.user_message.emit("msg_no_map")
		return
	visible = true
	_player.set_blocked("map", true)
	InputRouter.menu_open = true
	InputRouter.release_capture()
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	if _player != null:
		_player.set_blocked("map", false)
	InputRouter.menu_open = false


func _process(_delta: float) -> void:
	if _player == null or GameState.paused:
		return
	if InputRouter.just_pressed("map"):
		if visible:
			close()
		elif InputRouter.gameplay_active:
			open()
	elif visible and InputRouter.just_pressed("pause"):
		close()
	if visible:
		_canvas.queue_redraw()


func _refresh() -> void:
	var floor_data := _floor()
	_title.text = tr("map_title") + " — " + (tr(floor_data.name_key) if floor_data != null else "")
	_markers.clear()
	_list.text = list_text(floor_data, _markers) if floor_data != null else ""
	_canvas.queue_redraw()


## Texto de la lista lateral. Rellena «markers» con el número de cada cosa de este piso.
func list_text(floor_data: FloorData, markers: Array[Dictionary]) -> String:
	var here: Array[String] = []
	var elsewhere: Array[String] = []
	for entry: Dictionary in MapMarkers.missing(GameState.CATALOG.floors, GameState.player.keys):
		var item_id: String = entry["item_id"]
		var floor_key: String = entry["floor_key"]
		var item_name := InventoryRows.item_name(item_id)
		var room_key: String = entry["room_key"]
		var room_name := tr(room_key) if not room_key.is_empty() else tr("map_hall")
		var carrier_key: String = entry["carrier_key"]
		if not carrier_key.is_empty():
			room_name = tr("map_carried_by") % [tr(carrier_key), room_name]
		if entry["floor_id"] == floor_data.id:
			markers.append({"number": markers.size() + 1, "room_id": entry["room_id"]})
			here.append("%d. %s — %s" % [markers.size(), item_name, room_name])
		else:
			elsewhere.append("· %s — %s, %s" % [item_name, room_name, tr(floor_key)])
	var lines: Array[String] = [tr("map_list_here")]
	lines.append_array(here if not here.is_empty() else [tr("map_list_nothing")])
	lines.append("")
	lines.append(tr("map_list_safe"))
	var safe := MapMarkers.safe_rooms(floor_data)
	if safe.is_empty():
		lines.append(tr("map_list_nothing"))
	for room: RoomData in safe:
		lines.append("· " + tr(room.name_key))
	if not elsewhere.is_empty():
		lines.append("")
		lines.append(tr("map_list_other_floors"))
		lines.append_array(elsewhere)
	return "\n".join(lines)


func _floor() -> FloorData:
	var level := _player.get_parent() as Building if _player != null else null
	return level.floor_data if level != null else null


## Rectángulo del piso en metros (x, z) que abarcan todas las salas.
func _bounds(floor_data: FloorData) -> Rect2:
	var bounds := Rect2()
	var first := true
	for room: RoomData in floor_data.rooms:
		bounds = room.rect if first else bounds.merge(room.rect)
		first = false
	return bounds


func _draw_map() -> void:
	var floor_data := _floor()
	if floor_data == null:
		return
	var bounds := _bounds(floor_data)
	var area := Rect2(
		Vector2(MARGIN, MARGIN + 30.0),
		size - Vector2(MARGIN * 2.0 + LIST_WIDTH, MARGIN * 2.0 + 60.0)
	)
	var scale_factor := minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	var offset := area.position + (area.size - bounds.size * scale_factor) * 0.5
	var to_screen := func(point: Vector2) -> Vector2:
		return offset + (point - bounds.position) * scale_factor
	var font := get_theme_default_font()
	for room: RoomData in floor_data.rooms:
		var top_left: Vector2 = to_screen.call(room.rect.position)
		var rect := Rect2(top_left, room.rect.size * scale_factor)
		var fill := Color(0.2, 0.22, 0.25)
		if room.safe_zone:
			fill = Color(0.15, 0.32, 0.18)
		_canvas.draw_rect(rect, fill)
		_canvas.draw_rect(rect, Color(0.85, 0.85, 0.85), false, 2.0)
		var label := tr(room.name_key) if not room.name_key.is_empty() else ""
		if room.safe_zone:
			label += " (" + tr("map_safe") + ")"
		if not label.is_empty():
			_canvas.draw_string(
				font,
				rect.position + Vector2(6.0, 22.0),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				rect.size.x - 8.0,
				16
			)
	for hole: Rect2 in floor_data.holes:
		var hole_corner: Vector2 = to_screen.call(hole.position)
		var hole_rect := Rect2(hole_corner, hole.size * scale_factor)
		_canvas.draw_rect(hole_rect, Color(0.05, 0.05, 0.07))
	for floor_exit: FloorExit in floor_data.exits:
		var spot: Vector2 = to_screen.call(Vector2(floor_exit.position.x, floor_exit.position.z))
		_canvas.draw_rect(
			Rect2(spot - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), Color(0.55, 1.0, 0.6)
		)
		_canvas.draw_string(
			font,
			spot + Vector2(10.0, 6.0),
			tr(floor_exit.label_key),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14
		)
	_draw_markers(floor_data, to_screen, font)
	if _player != null:
		var at: Vector2 = to_screen.call(
			Vector2(_player.global_position.x, _player.global_position.z)
		)
		var forward := Vector2(-sin(_player.rotation.y), -cos(_player.rotation.y))
		var side := Vector2(-forward.y, forward.x)
		var tip := at + forward * 14.0
		var points := PackedVector2Array(
			[tip, at - forward * 8.0 + side * 8.0, at - forward * 8.0 - side * 8.0]
		)
		_canvas.draw_colored_polygon(points, Color(1.0, 0.85, 0.2))
		_canvas.draw_string(
			font, at + Vector2(12.0, -10.0), tr("map_you"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16
		)


## Círculo numerado en el centro de la sala de cada cosa importante de este piso (si hay
## varias en la misma sala, una al lado de otra).
func _draw_markers(floor_data: FloorData, to_screen: Callable, font: Font) -> void:
	var per_room: Dictionary = {}
	for marker: Dictionary in _markers:
		var room_id: String = marker["room_id"]
		var room := _room(floor_data, room_id)
		if room == null:
			continue
		var order: int = per_room.get(room.id, 0)
		per_room[room.id] = order + 1
		var center: Vector2 = to_screen.call(room.rect.get_center())
		center.x += (MARKER_RADIUS * 2.0 + 4.0) * order
		_canvas.draw_circle(center, MARKER_RADIUS, MARKER_COLOR)
		_canvas.draw_circle(center, MARKER_RADIUS, Color.BLACK, false, 2.0)
		_canvas.draw_string(
			font,
			center + Vector2(-MARKER_RADIUS, 6.0),
			str(marker["number"]),
			HORIZONTAL_ALIGNMENT_CENTER,
			MARKER_RADIUS * 2.0,
			18,
			Color.BLACK
		)


func _room(floor_data: FloorData, room_id: String) -> RoomData:
	for room: RoomData in floor_data.rooms:
		if room.id == room_id:
			return room
	return null

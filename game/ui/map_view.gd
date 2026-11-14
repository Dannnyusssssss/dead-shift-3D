class_name MapView
extends Control
## Mapa del piso actual (si el jugador tiene el plano de la sala de seguridad): salas con su
## nombre, zonas seguras, salidas, la posición del jugador y las zonas probables de piezas del
## teléfono que faltan (la sala, no el punto exacto). Se abre con la acción «map» o el botón
## táctil y se cierra igual o con «Cerrar». Mientras está abierto el jugador queda quieto.

const MAP_ITEM: String = "mall_map"
const MARGIN: float = 60.0

var _player: Player = null
var _canvas: Control = null
var _title: Label = null
var _legend: Label = null


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
	_canvas.queue_redraw()


func _floor() -> FloorData:
	var level := _player.get_parent() as FloorLevel if _player != null else null
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
		Vector2(MARGIN, MARGIN + 30.0), size - Vector2(MARGIN * 2.0, MARGIN * 2.0 + 60.0)
	)
	var scale_factor := minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	var offset := area.position + (area.size - bounds.size * scale_factor) * 0.5
	var to_screen := func(point: Vector2) -> Vector2:
		return offset + (point - bounds.position) * scale_factor
	var font := get_theme_default_font()
	var probable := _probable_rooms(floor_data)
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
		if probable.has(room.id):
			label += "  ?" + tr("map_probable")
		if not label.is_empty():
			_canvas.draw_string(
				font,
				rect.position + Vector2(6.0, 22.0),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				rect.size.x - 8.0,
				16
			)
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


## Salas que contienen piezas del teléfono que el jugador todavía no tiene (zona probable).
func _probable_rooms(floor_data: FloorData) -> Dictionary:
	var result: Dictionary = {}
	var state := GameState.player
	for room: RoomData in floor_data.rooms:
		for spot: LootSpot in room.loot:
			var ids: Array[String] = []
			if spot.kind == LootSpot.KIND_PICKUP:
				ids.append(spot.item_id)
			for entry: String in spot.contents:
				ids.append(entry.split(":")[0])
			for item_id: String in ids:
				if Rules.PHONE_PARTS.has(item_id) and not state.keys.has(item_id):
					result[room.id] = true
	return result

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Teléfono, helicóptero, cámaras y mapa con la partida completa: armar el teléfono con las tres
## piezas, llamar (una sola vez), llegada y partida sin el jugador, aviso de las cámaras en la
## zona segura, informe de los monitores y mapa solo con el plano.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")

var _game: Game


func before_each() -> void:
	GameState.forced_seed = 7
	_game = GAME_SCRIPT.new()
	add_child_autofree(_game)
	await wait_physics_frames(3)


func after_each() -> void:
	GameState.forced_seed = -1
	InputRouter.gameplay_active = false
	InputRouter.menu_open = false
	InputRouter.release_capture()


func test_phone_needs_all_parts_and_call_happens_once() -> void:
	var state := GameState.player
	state.keys.add("phone_antenna")
	state.keys.add("phone_battery")
	assert_false(state.keys.can_assemble_phone(), "faltan piezas")
	assert_false(state.keys.assemble_phone())
	state.keys.add("phone_board")
	assert_true(state.keys.assemble_phone())
	assert_false(state.keys.assemble_phone(), "ya armado")
	assert_true(GameState.rescue.call_helicopter())
	assert_false(GameState.rescue.call_helicopter(), "una sola llamada")


func test_helicopter_arrives_and_leaves_without_player() -> void:
	watch_signals(EventBus)
	GameState.rescue.call_helicopter()
	GameState.rescue.time_left = 0.05
	await wait_frames(10)
	assert_eq(GameState.rescue.state, RescueClock.STATE_WAITING, "llegó")
	GameState.rescue.time_left = 0.05
	await wait_frames(10)
	assert_eq(GameState.rescue.state, RescueClock.STATE_DEPARTED, "se fue sin el jugador")
	assert_signal_emitted(EventBus, "rescue_lost")


func test_rescue_clock_stops_while_paused() -> void:
	GameState.rescue.call_helicopter()
	var before := GameState.rescue.time_left
	GameState.set_paused(true)
	await wait_frames(20)
	assert_eq(GameState.rescue.time_left, before, "la pausa detiene el reloj")
	GameState.set_paused(false)


func test_cameras_warn_when_an_enemy_nears_the_safe_room() -> void:
	watch_signals(EventBus)
	var player := _game.level.player
	player.global_position = Vector3(-28.0, 0.0, -2.0)
	var enemy: Enemy = _game.level.enemies_on_floor("ground_floor")[0]
	enemy.global_position = Vector3(-21.0, 0.0, -2.0)
	await wait_frames(45)
	assert_signal_emitted_with_parameters(EventBus, "camera_alert", [true])


func test_monitors_report_enemies_per_floor() -> void:
	var report := SecurityMonitor.report()
	for floor_data: FloorData in GameState.CATALOG.floors:
		assert_string_contains(report, tr(floor_data.name_key))
	assert_string_contains(report, tr("cameras_boss"))


func test_map_needs_the_plan() -> void:
	var map: MapView = null
	for node: Node in _game.get_node("UI").get_children():
		if node is MapView:
			map = node
	map.open()
	assert_false(map.is_open(), "sin plano no se abre")
	GameState.player.keys.add("mall_map")
	map.open()
	assert_true(map.is_open())
	assert_false(_game.level.player.controls_enabled, "con el mapa abierto queda quieto")
	map.close()
	assert_true(_game.level.player.controls_enabled)


func _ui_node(type_name: String) -> Node:
	var found := _game.get_node("UI").find_children("*", type_name, false, false)
	return found[0] if not found.is_empty() else null


func test_plan_in_backpack_closes_it_and_opens_the_map() -> void:
	GameState.player.keys.add("mall_map")
	var panel := _ui_node("InventoryPanel") as InventoryPanel
	var map := _ui_node("MapView") as MapView
	InputRouter.gameplay_active = true
	panel.open()
	await wait_frames(2)
	var button := panel.find_child("MapButton", true, false) as TapButton
	assert_not_null(button, "el plano es un botón entre los objetos clave")
	button.pressed.emit()
	assert_false(panel.is_open(), "la mochila se cierra")
	assert_true(map.is_open(), "y se abre el mapa")
	assert_true(InputRouter.menu_open, "con el cursor libre para el mapa")
	assert_false(_game.level.player.controls_enabled)
	map.close()
	assert_true(_game.level.player.controls_enabled)


## Con el teléfono armado, «Llamar al helicóptero» queda siempre a la vista (en el panel de
## detalle, no al final de la columna de objetos clave) y las piezas ya no salen sueltas.
func test_call_button_fits_on_screen() -> void:
	var state := GameState.player
	for part: String in Rules.PHONE_PARTS:
		state.keys.add(part)
	for key_id: String in ["mall_map", "security_key", "roof_key"]:
		state.keys.add(key_id)
	assert_true(state.keys.assemble_phone())
	for item_id: String in ["nails", "rag", "tape", "bottle", "batteries"]:
		state.inventory.add_item(GameState.items.get_item(item_id), 1)
	var panel := _ui_node("InventoryPanel") as InventoryPanel
	InputRouter.gameplay_active = true
	panel.open()
	await wait_frames(3)
	var button := panel.find_child("CallButton", true, false) as TapButton
	assert_true(button.is_visible_in_tree())
	# Va en el panel de detalle, fuera de la columna que se desplaza: siempre a la vista.
	var parent := button.get_parent()
	while parent != panel:
		assert_false(parent is ScrollContainer, "el botón no queda dentro de lo que se desplaza")
		parent = parent.get_parent()
	var row := panel.get("_keys_row") as Control
	assert_eq(row.get_child_count(), 4, "plano, dos llaves y el teléfono")
	panel.close()


func test_map_numbers_what_is_missing_on_this_floor() -> void:
	GameState.player.keys.add("mall_map")
	var map := _ui_node("MapView") as MapView
	var markers: Array[Dictionary] = []
	var level_1: FloorData = GameState.CATALOG.floors[1]
	var text := map.list_text(level_1, markers)
	assert_string_contains(text, "1. " + tr("item_phone_antenna"))
	assert_string_contains(text, "2. " + tr("item_phone_battery"))
	assert_string_contains(text, "3. " + tr("item_security_key"))
	assert_string_contains(text, tr("enemy_technician"), "la llave de la azotea la lleva el jefe")
	assert_string_contains(text, tr("item_phone_board"), "lo de otros pisos también")
	assert_string_contains(text, tr("map_list_other_floors"))
	assert_eq(markers.size(), 3, "antena, batería y llave de seguridad en el Nivel 1")


func test_technician_note_opens_and_teaches_the_phone() -> void:
	var note: TechNote = null
	for node: Node in _game.level.find_children("*", "TechNote", true, false):
		note = node
	assert_not_null(note, "la nota está en el edificio")
	var view := _ui_node("NoteView") as NoteView
	assert_false(Discovery.knows_phone(GameState.world, GameState.player.keys))
	GameState.player.keys.add("phone_antenna")
	note.interact(_game.level.player)
	assert_true(GameState.world.has_flag(Discovery.NOTE_FLAG))
	assert_true(view.is_open())
	var body := NoteView.body_text("technician")
	assert_string_contains(body, "[x] " + tr("item_phone_antenna"), "la que ya tiene")
	assert_string_contains(body, "[ ] " + tr("item_phone_board"))
	assert_string_contains(body, _board_room(), "dice dónde la dejó")
	assert_false(_game.level.player.controls_enabled)
	view.close()
	assert_true(_game.level.player.controls_enabled)


func test_notebook_shows_only_what_was_discovered() -> void:
	var notebook := Notebook.new()
	add_child_autofree(notebook)
	notebook.refresh()
	var text := _labels(notebook)
	assert_string_contains(text, tr("notebook_phone_unknown"))
	assert_string_contains(text, tr("notebook_recipes_none"))
	GameState.world.set_flag(Discovery.NOTE_FLAG)
	GameState.player.inventory.add_item(GameState.items.get_item("rag"), 1)
	EventBus.inventory_changed.emit()
	notebook.refresh()
	await wait_frames(1)
	text = _labels(notebook)
	assert_string_contains(text, tr("notebook_phone_intro"))
	assert_string_contains(text, _board_room(), "la nota dice dónde buscar")
	assert_string_contains(text, tr("item_improvised_bandage"), "receta con el trapo")
	assert_false(text.contains(tr("item_bat_nails")), "la del bate todavía no")


func _labels(root: Node) -> String:
	var text := ""
	for node: Node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if not label.is_queued_for_deletion():
			text += label.text + "\n"
	return text


func test_the_building_has_breakable_storefronts() -> void:
	var groups := _game.level.find_children("*", "GlassPanes", true, false)
	assert_gt(groups.size(), 10, "un grupo de cristales por escaparate")


func test_monitors_show_real_cameras_and_stop_rendering_when_closed() -> void:
	var view := _ui_node("CameraView") as CameraView
	var monitor: SecurityMonitor = null
	for node: Node in _game.level.find_children("*", "SecurityMonitor", true, false):
		monitor = node
	assert_not_null(monitor, "monitores en la sala de seguridad")
	assert_false(view.is_rendering(), "cerrado no renderiza")
	monitor.interact(_game.level.player)
	assert_true(view.is_open())
	assert_true(view.is_rendering(), "abierto renderiza la cámara")
	assert_false(_game.level.player.controls_enabled)
	var first := view.current_name_key()
	view.cycle(1)
	assert_ne(view.current_name_key(), first, "cambia de cámara")
	var top := _game.level.sections[2]
	while not view.current_name_key().begins_with("cam_level2"):
		view.cycle(1)
	assert_true(top.visible, "el piso de la cámara se ve aunque el jugador esté lejos")
	view.close()
	assert_false(view.is_rendering(), "al cerrar deja de renderizar")
	assert_false(top.visible, "y el piso lejano vuelve a ocultarse")
	assert_true(_game.level.player.controls_enabled)


func test_first_damage_shows_a_tip_once_and_the_option_turns_it_off() -> void:
	var banner: TipBanner = _game.find_children("*", "TipBanner", true, false)[0]
	Settings.set_value("tips", false)
	banner.offer(Tips.DAMAGE)
	assert_eq(banner.text, "", "con la opción apagada no sale")
	assert_false(GameState.world.has_flag(Tips.PREFIX + Tips.DAMAGE), "ni se gasta")
	Settings.set_value("tips", true)
	EventBus.player_damaged.emit(5.0)
	assert_string_contains(banner.text, tr("tip_damage"))
	banner.text = ""
	EventBus.player_damaged.emit(5.0)
	assert_eq(banner.text, "", "una sola vez por partida")


func test_pause_shows_the_run_summary() -> void:
	var pause: PauseMenu = _game.find_children("*", "PauseMenu", true, false)[0]
	GameState.player.keys.add("phone_antenna")
	GameState.set_paused(true)
	await wait_frames(1)
	var text := ""
	for node: Node in pause.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	GameState.set_paused(false)
	assert_string_contains(text, tr("end_kills"))
	assert_string_contains(text, "%s 1/3" % tr("end_phone_parts"))
	assert_false(text.contains(tr("end_grade")), "sin nota a mitad de partida")


## Sala donde el reparto de esta partida dejó la placa del teléfono (cambia con la semilla).
func _board_room() -> String:
	var wanted: Array[String] = ["phone_board"]
	var places := MapMarkers.locations(GameState.CATALOG.floors, wanted, GameState.loot_plan)
	assert_eq(places.size(), 1, "la placa está en algún piso")
	return tr(String(places[0]["room_key"])) if not places.is_empty() else ""


## La pestaña Combinar no ofrece armar el teléfono hasta leer la nota del técnico, aunque estén
## todas las piezas; al leerla, la opción aparece.
func test_combine_tab_offers_the_phone_only_after_the_note() -> void:
	var lists := _game.get_node("UI").find_children("*", "CombineList", true, false)
	assert_false(lists.is_empty(), "la pestaña Combinar existe")
	var list := lists[0] as CombineList
	for part: String in Rules.PHONE_PARTS:
		GameState.player.keys.add(part)
	var before := list.available_count()
	GameState.world.set_flag(Discovery.NOTE_FLAG)
	assert_eq(list.available_count(), before + 1, "con la nota aparece armar el teléfono")

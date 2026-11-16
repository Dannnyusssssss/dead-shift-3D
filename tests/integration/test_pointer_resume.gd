extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Puntero: si se juega con ratón y el puntero no está capturado (el navegador no dejó
## recuperarlo), el clic que lo recupera no dispara ni apunta.


func after_each() -> void:
	InputRouter.gameplay_active = false
	_click(false)


func _click(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)


func test_resume_click_does_not_attack() -> void:
	InputRouter.gameplay_active = true
	InputRouter.touch_mode = false
	InputRouter.menu_open = false
	InputRouter.release_capture()
	assert_true(InputRouter.needs_click(), "sin puntero capturado se pide un clic")
	_click(true)
	await wait_process_frames(1)
	assert_false(InputRouter.just_pressed("attack"), "ese clic no dispara")
	assert_false(InputRouter.is_pressed("attack"))
	_click(false)
	await wait_process_frames(2)
	assert_false(InputRouter.is_pressed("attack"))


func test_menu_open_does_not_ask_for_a_click() -> void:
	InputRouter.gameplay_active = true
	InputRouter.touch_mode = false
	InputRouter.menu_open = true
	assert_false(InputRouter.needs_click(), "con un menú abierto el cursor se ve a propósito")
	InputRouter.menu_open = false


## Cerrar la nota con E (la misma tecla que la abre) la cierra y pide el puntero en ese gesto,
## sin pedir otro clic; la pulsación que la abre no la cierra.
func test_closing_the_note_with_interact_recaptures_the_pointer() -> void:
	GameState.start_new_run()
	var scene: PackedScene = load("res://game/actors/player/player.tscn")
	var player: Player = scene.instantiate()
	add_child_autofree(player)
	var note := NoteView.new()
	add_child_autofree(note)
	note.bind_player(player)
	await wait_process_frames(1)
	InputRouter.gameplay_active = true
	InputRouter.touch_mode = false
	note.open("technician")
	Input.action_press("interact")
	await wait_process_frames(1)
	Input.action_release("interact")
	await wait_process_frames(1)
	assert_true(note.is_open(), "la pulsación que la abre no la cierra")
	var before := InputRouter.capture_requests
	Input.action_press("interact")
	await wait_process_frames(2)
	Input.action_release("interact")
	assert_false(note.is_open(), "E la cierra")
	assert_false(InputRouter.menu_open)
	assert_gt(InputRouter.capture_requests, before, "pide el puntero al cerrar")

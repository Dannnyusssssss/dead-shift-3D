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

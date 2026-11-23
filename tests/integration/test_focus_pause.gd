extends GutTest
## Pestaña o ventana en segundo plano: la partida se pausa sola; fuera de la partida (menús)
## no pasa nada.


func after_each() -> void:
	GameState.set_paused(false)
	InputRouter.gameplay_active = false
	InputRouter.release_capture()


func test_losing_focus_pauses_the_run() -> void:
	InputRouter.gameplay_active = true
	InputRouter.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(GameState.paused, "se pausa al pasar a segundo plano")
	assert_false(InputRouter.gameplay_active)


func test_losing_focus_in_menus_does_nothing() -> void:
	InputRouter.gameplay_active = false
	InputRouter.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(GameState.paused)

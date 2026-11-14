extends SceneTree
## Ejecutor del bot de recorrido (sin ventana):
##   godot --headless --fixed-fps 60 -s res://tests/bot/run_bot.gd
## Carga la sesión del bot después del primer fotograma, cuando los autoloads ya existen.

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var session_script: GDScript = load("res://tests/bot/bot_session.gd")
		var session: Node = session_script.new()
		root.add_child(session)
	return false

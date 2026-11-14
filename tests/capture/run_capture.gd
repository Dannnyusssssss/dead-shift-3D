extends SceneTree
## Capturas por script de 5 puntos fijos y medición de rendimiento (con ventana):
##   godot --path . -s res://tests/capture/run_capture.gd
## Guarda las imágenes y las cifras fuera del repositorio (carpeta temporal del sistema).
## Carga la sesión después del primer fotograma, cuando los autoloads ya existen.

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var session_script: GDScript = load("res://tests/capture/capture_session.gd")
		var session: Node = session_script.new()
		root.add_child(session)
	return false

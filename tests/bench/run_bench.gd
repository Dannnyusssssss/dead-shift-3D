extends SceneTree
## Banco de rendimiento de la lógica (sin ventana, sin dibujar):
##   godot --headless --fixed-fps 60 --path . -s res://tests/bench/run_bench.gd
## Con --fixed-fps cada fotograma avanza 1/60 s y hace un paso de física, así el tiempo real
## de cada fotograma es lo que cuesta calcularlo. Imprime una tabla por escenario y cuánto
## baja el coste al apagar cada parte del juego. No es una prueba que pase o falle.

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var session_script: GDScript = load("res://tests/bench/bench_session.gd")
		if session_script == null or not session_script.can_instantiate():
			print("[banco] FALLO: la sesión del banco no compila")
			quit(1)
			return false
		var session: Node = session_script.new()
		root.add_child(session)
	return false

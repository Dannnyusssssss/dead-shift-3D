extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Todos los scripts y escenas del juego compilan y cargan (con el tipado estricto activo).
## Evita que un script que ninguna prueba usa llegue roto al export.


func _collect(path: String, extensions: PackedStringArray, found: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(path.path_join(sub), extensions, found)
	for file: String in dir.get_files():
		if file.get_extension() in extensions:
			found.append(path.path_join(file))


func test_every_script_compiles() -> void:
	var scripts := PackedStringArray()
	_collect("res://game", PackedStringArray(["gd"]), scripts)
	assert_gt(scripts.size(), 10)
	for path: String in scripts:
		var script: Script = load(path)
		assert_not_null(script, path)
		if script != null:
			assert_true(script.can_instantiate(), "compila: " + path)


func test_every_scene_loads() -> void:
	var scenes := PackedStringArray()
	_collect("res://game", PackedStringArray(["tscn"]), scenes)
	for path: String in scenes:
		var scene: PackedScene = load(path)
		assert_not_null(scene, path)
		if scene != null:
			assert_true(scene.can_instantiate(), "carga: " + path)

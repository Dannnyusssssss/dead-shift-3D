extends GutTest
## Los datos van en una carpeta propia del juego (en web, user:// es común a todos los juegos del
## mismo dominio hechos con el motor) y lo guardado con las rutas antiguas se mueve a la nueva.

## Los ajustes y la mejor nota de quien ejecuta las pruebas se conservan (se guardan antes y
## se restauran).
var _backup: Dictionary = {}


func before_each() -> void:
	_backup.clear()
	for path: String in [SaveStore.SETTINGS_PATH, SaveStore.BEST_PATH]:
		if FileAccess.file_exists(path):
			_backup[path] = FileAccess.get_file_as_string(path)


func after_each() -> void:
	SaveStore.delete_game()
	for path: String in SaveStore.LEGACY_PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for path: String in _backup:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(_backup[path] as String)
		file.close()


func test_files_live_in_the_game_folder() -> void:
	for path: String in [SaveStore.SETTINGS_PATH, SaveStore.GAME_PATH, SaveStore.BEST_PATH]:
		assert_true(path.begins_with(SaveStore.DATA_DIR + "/"), path)
	assert_true(SaveStore.save_game({"probe": true}))
	assert_true(FileAccess.file_exists(SaveStore.GAME_PATH))


func test_legacy_files_move_to_the_game_folder() -> void:
	SaveStore.delete_game()
	var legacy := FileAccess.open("user://save_1.json", FileAccess.WRITE)
	legacy.store_string("antiguo")
	legacy.close()
	SaveStore.call("_move_legacy_files")
	assert_false(FileAccess.file_exists("user://save_1.json"), "la ruta antigua queda libre")
	assert_eq(FileAccess.get_file_as_string(SaveStore.GAME_PATH), "antiguo", "se conserva")


func test_delete_all_also_clears_legacy_files() -> void:
	var legacy := FileAccess.open("user://best.json", FileAccess.WRITE)
	legacy.store_string("x")
	legacy.close()
	SaveStore.delete_all()
	assert_false(FileAccess.file_exists("user://best.json"))

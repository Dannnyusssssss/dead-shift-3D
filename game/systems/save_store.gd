extends Node
## Único módulo de acceso a datos guardados. Hoy escribe en user:// (en web, el almacenamiento
## del navegador para este origen); nada sale del dispositivo. Todo lo leído pasa por
## boundary/validation.gd antes de usarse.

const SETTINGS_PATH: String = "user://settings.json"
const GAME_PATH: String = "user://save_1.json"
const BEST_PATH: String = "user://best.json"
## Versión del formato de la mejor marca (2: una nota por dificultad).
const BEST_VERSION: int = 2

## Evita repetir el aviso de almacenamiento no disponible.
var _storage_warned: bool = false


## Verdadero si ya existen ajustes guardados (para saber si es el primer arranque).
func has_settings() -> bool:
	return FileAccess.file_exists(SETTINGS_PATH)


## Lee y valida los ajustes; si faltan o están dañados devuelve los valores por defecto.
func load_settings() -> Dictionary:
	return Validation.parse_settings(_read_text(SETTINGS_PATH))


## Guarda los ajustes. Devuelve falso si el navegador no permite guardar.
func save_settings(values: Dictionary) -> bool:
	return _write_text(SETTINGS_PATH, SaveCodec.encode(values, SettingsSchema.VERSION))


## Verdadero si hay una partida guardada.
func has_game() -> bool:
	return FileAccess.file_exists(GAME_PATH)


## Lee y valida la partida con el contexto del catálogo (GameCatalog.save_context()).
func load_game(context: Dictionary) -> DataResult:
	var text := _read_text(GAME_PATH)
	var result := SaveValidation.parse(text, context)
	if not result.ok and not text.is_empty():
		ErrorLog.report("save_rejected", result.error)
	return result


## Guarda la partida. Devuelve falso si el navegador no permite guardar.
func save_game(data: Dictionary) -> bool:
	return _write_text(GAME_PATH, SaveCodec.encode(data))


## Borra solo la partida guardada (al empezar una nueva no se borra hasta guardar).
func delete_game() -> void:
	if FileAccess.file_exists(GAME_PATH):
		DirAccess.remove_absolute(GAME_PATH)


## Mejores notas guardadas en este dispositivo, por dificultad ({} si no hay o están dañadas).
func load_best_all() -> Dictionary:
	var ids := GameState.CATALOG.difficulty_ids()
	return Validation.parse_best(_read_text(BEST_PATH), ids, BEST_VERSION)


## Mejor nota de una dificultad ("" si no hay).
func load_best(difficulty_id: String) -> String:
	var grade: String = load_best_all().get(difficulty_id, "")
	return grade


## Guarda la nota de una dificultad si mejora la anterior. Devuelve verdadero si fue récord.
func save_best(grade: String, difficulty_id: String) -> bool:
	if not RunStats.GRADES.has(grade):
		return false
	if not GameState.CATALOG.difficulty_ids().has(difficulty_id):
		return false
	var grades := load_best_all()
	var previous: String = grades.get(difficulty_id, "")
	if not previous.is_empty() and RunStats.grade_rank(previous) <= RunStats.grade_rank(grade):
		return false
	grades[difficulty_id] = grade
	return _write_text(BEST_PATH, SaveCodec.encode({"grades": grades}, BEST_VERSION))


## Borra todos los datos guardados en este navegador (ajustes, partida y mejor marca).
func delete_all() -> void:
	for path: String in [SETTINGS_PATH, GAME_PATH, BEST_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Lee un archivo como texto con tope de tamaño; ante cualquier problema devuelve "".
func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		ErrorLog.report("read_failed", path)
		return ""
	if file.get_length() > SaveCodec.MAX_BYTES:
		ErrorLog.report("file_too_large", path)
		return ""
	return file.get_as_text()


## Escribe texto en un archivo; si falla (modo privado, cuota llena) avisa una sola vez.
func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_warn_storage(path)
		return false
	file.store_string(text)
	file.close()
	return true


func _warn_storage(path: String) -> void:
	if _storage_warned:
		ErrorLog.report("write_failed", path)
		return
	_storage_warned = true
	ErrorLog.report_to_user("write_failed", "msg_storage_unavailable", path)

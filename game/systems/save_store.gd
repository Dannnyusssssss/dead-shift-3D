extends Node
## Único módulo de acceso a datos guardados. Hoy escribe en user:// (en web, el almacenamiento
## del navegador para este origen); nada sale del dispositivo. Todo lo leído pasa por
## boundary/validation.gd antes de usarse.

const SETTINGS_PATH: String = "user://settings.json"
const GAME_PATH: String = "user://save_1.json"
const BEST_PATH: String = "user://best.json"

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
	return _write_text(SETTINGS_PATH, SaveCodec.encode(values))


## Verdadero si hay una partida guardada.
func has_game() -> bool:
	return FileAccess.file_exists(GAME_PATH)


## Lee y valida la partida. known_items son los identificadores de objetos válidos.
func load_game(known_items: PackedStringArray) -> DataResult:
	var text := _read_text(GAME_PATH)
	var result := Validation.parse_save(text, known_items)
	if not result.ok and not text.is_empty():
		ErrorLog.report("save_rejected", result.error)
	return result


## Guarda la partida. Devuelve falso si el navegador no permite guardar.
func save_game(data: Dictionary) -> bool:
	return _write_text(GAME_PATH, SaveCodec.encode(data))


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

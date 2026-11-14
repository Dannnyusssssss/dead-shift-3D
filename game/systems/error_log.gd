extends Node
## Manejo central de errores: guarda el detalle en un registro interno y,
## si el jugador debe enterarse, emite solo una clave de mensaje genérico.

const MAX_ENTRIES: int = 64

var _entries: Array[String] = []


## Anota un error con un código estable y un detalle técnico (nunca se muestra al jugador).
func report(code: String, detail: String = "") -> void:
	var line := code if detail.is_empty() else "%s: %s" % [code, detail]
	_entries.append(line)
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	if OS.is_debug_build():
		print("[registro] ", line)


## Anota el error y avisa a la interfaz con una clave de texto genérica.
func report_to_user(code: String, text_key: String, detail: String = "") -> void:
	report(code, detail)
	EventBus.user_message.emit(text_key)


## Copia de las entradas del registro interno (para el overlay de depuración y las pruebas).
func entries() -> Array[String]:
	return _entries.duplicate()

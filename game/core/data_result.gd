class_name DataResult
extends RefCounted
## Resultado de una operación que puede fallar: datos válidos o un código de error estable.
## El código es para el registro interno; al jugador solo se le muestra un mensaje genérico.

var ok: bool = false
var data: Dictionary = {}
var error: String = ""


static func success(value: Dictionary) -> DataResult:
	var result := DataResult.new()
	result.ok = true
	result.data = value
	return result


static func failure(code: String) -> DataResult:
	var result := DataResult.new()
	result.ok = false
	result.error = code
	return result

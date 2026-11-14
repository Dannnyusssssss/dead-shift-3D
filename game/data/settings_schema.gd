class_name SettingsSchema
extends RefCounted
## Esquema de los ajustes: tipo, valor por defecto y rango de cada campo.
## Lo usan Settings (valores iniciales) y boundary/validation.gd (lectura de datos guardados).

const QUALITY_LOW: int = 0
const QUALITY_MEDIUM: int = 1
const QUALITY_HIGH: int = 2

## Campos numéricos: [mínimo, máximo, por defecto].
const FLOATS: Dictionary = {
	"mouse_sensitivity": [0.1, 5.0, 1.0],
	"touch_sensitivity": [0.1, 5.0, 1.0],
	"fov": [60.0, 100.0, 75.0],
	"volume_master": [0.0, 1.0, 0.8],
	"touch_button_scale": [0.75, 1.5, 1.0],
	"touch_opacity": [0.3, 1.0, 0.7],
}

## Campos enteros: [mínimo, máximo, por defecto].
const INTS: Dictionary = {
	"quality": [QUALITY_LOW, QUALITY_HIGH, QUALITY_MEDIUM],
}

## Campos booleanos: valor por defecto.
const BOOLS: Dictionary = {
	"reduce_motion": false,
	"reduce_gore": false,
	"head_bob": true,
	"invert_y": false,
	"aim_assist": true,
	"subtitles": true,
	"show_performance": false,
}


## Devuelve un diccionario con todos los ajustes en su valor por defecto.
static func defaults() -> Dictionary:
	var result: Dictionary = {}
	for key: String in FLOATS:
		var spec: Array = FLOATS[key]
		result[key] = spec[2]
	for key: String in INTS:
		var spec: Array = INTS[key]
		result[key] = spec[2]
	for key: String in BOOLS:
		result[key] = BOOLS[key]
	return result

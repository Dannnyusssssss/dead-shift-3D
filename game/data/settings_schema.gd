class_name SettingsSchema
extends RefCounted
## Esquema de los ajustes: tipo, valor por defecto y rango de cada campo, y las teclas que se
## pueden reasignar. Lo usan Settings (valores iniciales) y boundary/validation.gd (lectura de
## datos guardados).

## Versión del formato de los ajustes (independiente de la de la partida).
const VERSION: int = 1

const QUALITY_LOW: int = 0
const QUALITY_MEDIUM: int = 1
const QUALITY_HIGH: int = 2

## Campos numéricos: [mínimo, máximo, por defecto].
const FLOATS: Dictionary = {
	"mouse_sensitivity": [0.1, 5.0, 1.0],
	"touch_sensitivity": [0.1, 5.0, 1.0],
	"fov": [60.0, 100.0, 75.0],
	"volume_master": [0.0, 1.0, 0.8],
	"volume_music": [0.0, 1.0, 0.8],
	"volume_sfx": [0.0, 1.0, 0.8],
	"volume_ambience": [0.0, 1.0, 0.8],
	"touch_button_scale": [0.75, 1.5, 1.0],
	"touch_opacity": [0.3, 1.0, 0.7],
	"ui_scale": [0.8, 1.5, 1.0],
}

## Campos enteros: [mínimo, máximo, por defecto].
const INTS: Dictionary = {
	"quality": [QUALITY_LOW, QUALITY_HIGH, QUALITY_MEDIUM],
}

## Campos booleanos: valor por defecto.
const BOOLS: Dictionary = {
	"reduce_motion": false,
	"reduce_flashes": false,
	"reduce_gore": false,
	"head_bob": true,
	"invert_y": false,
	"aim_assist": true,
	"subtitles": true,
	"tips": true,
	"show_performance": false,
}

## Teclas de fábrica de cada acción reasignable (la primera es la principal). Deben coincidir
## con el InputMap de project.godot (lo comprueba un test).
const DEFAULT_BINDINGS: Dictionary = {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"reload": [KEY_R],
	"interact": [KEY_E],
	"throw": [KEY_G],
	"throw_next": [KEY_V],
	"inventory": [KEY_TAB, KEY_I],
	"map": [KEY_M],
	"notebook": [KEY_N],
	"heal": [KEY_H],
	"flashlight": [KEY_F],
	"weapon_next": [KEY_Q],
}
## Orden en que se muestran y se resuelven los conflictos.
const REBINDABLE: Array[String] = [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"sprint",
	"crouch",
	"reload",
	"interact",
	"throw",
	"throw_next",
	"inventory",
	"map",
	"notebook",
	"heal",
	"flashlight",
	"weapon_next",
]
## Teclas reservadas que nunca se asignan: pausa (P y Esc, fijas), las de cambio rápido de
## arma (1, 2, 3, fijas) y las del navegador (F1 a F12, Intro).
const RESERVED_KEYS: Array[int] = [KEY_P, KEY_ESCAPE, KEY_1, KEY_2, KEY_3, KEY_ENTER]


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
	result["bindings"] = {}
	return result


## Verdadero si la tecla (código físico) se puede asignar: letras, números del 4 al 9 y el 0,
## espacio, modificadores, tabulador, flechas y signos comunes. Nunca las reservadas.
static func is_allowed_key(keycode: int) -> bool:
	if RESERVED_KEYS.has(keycode):
		return false
	if keycode >= KEY_A and keycode <= KEY_Z:
		return true
	if keycode >= KEY_0 and keycode <= KEY_9:
		return true
	return (
		[
			KEY_SPACE,
			KEY_SHIFT,
			KEY_CTRL,
			KEY_ALT,
			KEY_TAB,
			KEY_CAPSLOCK,
			KEY_LEFT,
			KEY_RIGHT,
			KEY_UP,
			KEY_DOWN,
			KEY_COMMA,
			KEY_PERIOD,
			KEY_SEMICOLON,
			KEY_SLASH,
			KEY_MINUS,
			KEY_EQUAL,
			KEY_BRACKETLEFT,
			KEY_BRACKETRIGHT,
			KEY_APOSTROPHE,
		]
		. has(keycode)
	)

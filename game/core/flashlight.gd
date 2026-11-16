class_name Flashlight
extends RefCounted
## Linterna del guardia: encendida o apagada, con una carga en segundos de luz que se gasta
## mientras está encendida. Al agotarse se cambian las pilas solas si hay en la bolsa; si no,
## queda una luz mínima de emergencia (nunca a ciegas). Calcula el brillo al que debe ir la luz;
## el nodo lo alcanza poco a poco (sin parpadeos). Lógica pura.

## Material de la bolsa que recarga la linterna.
const BATTERY_ITEM: String = "batteries"
## Brillo con la carga agotada (luz de emergencia) y por debajo de la carga baja.
const EMERGENCY_LEVEL: float = 0.2
const LOW_LEVEL: float = 0.55
## Segundos de carga por debajo de los cuales la luz empieza a bajar.
const LOW_CHARGE: float = 20.0
## Aviso de carga baja: bajadas suaves del haz por segundo (muy por debajo de 3 destellos por
## segundo) y cuánto baja en cada una.
const LOW_FLICKER_RATE: float = 0.6
const LOW_FLICKER_DEPTH: float = 0.35

var on: bool = false
var charge: float = Rules.FLASHLIGHT_SECONDS


## Enciende o apaga. Devuelve el estado nuevo.
func toggle() -> bool:
	on = not on
	return on


## Gasta carga si está encendida. Si se agota y la bolsa tiene pilas, gasta una y recarga.
## Devuelve verdadero si cambió las pilas en este paso.
func tick(delta: float, bag: MaterialBag) -> bool:
	if not on or delta <= 0.0:
		return false
	charge = maxf(charge - delta, 0.0)
	if charge > 0.0 or bag == null:
		return false
	if bag.remove(BATTERY_ITEM, 1) == 1:
		charge = Rules.FLASHLIGHT_SECONDS
		return true
	return false


func is_empty() -> bool:
	return charge <= 0.0


## Brillo objetivo de 0 a 1: apagada 0; sin carga, luz de emergencia; con poca carga baja poco a
## poco hasta LOW_LEVEL; si no, 1.
func level() -> float:
	if not on:
		return 0.0
	if charge <= 0.0:
		return EMERGENCY_LEVEL
	if charge >= LOW_CHARGE:
		return 1.0
	return lerpf(LOW_LEVEL, 1.0, charge / LOW_CHARGE)


## Si queda poca carga (y la linterna sigue dando luz normal): hay que avisar.
func is_low() -> bool:
	return on and charge > 0.0 and charge < LOW_CHARGE


## Multiplicador del brillo para avisar de la carga baja: una bajada suave cada
## 1 / LOW_FLICKER_RATE segundos. Con reduce_flashes no hay bajadas (solo la atenuación de
## level()). Fuera de la carga baja, 1.
func flicker(time: float, reduce_flashes: bool) -> float:
	if reduce_flashes or not is_low():
		return 1.0
	var wave := maxf(sin(time * TAU * LOW_FLICKER_RATE), 0.0)
	return 1.0 - LOW_FLICKER_DEPTH * pow(wave, 8.0)


## Fracción de carga (0 a 1) para la interfaz.
func fraction() -> float:
	return clampf(charge / Rules.FLASHLIGHT_SECONDS, 0.0, 1.0)


func to_data() -> Dictionary:
	return {"on": on, "charge": charge}


## Restaura desde datos ya validados por boundary/save_validation.gd.
func load_data(data: Dictionary) -> void:
	var stored_on: bool = data.get("on", false)
	var stored_charge: float = data.get("charge", Rules.FLASHLIGHT_SECONDS)
	on = stored_on
	charge = clampf(stored_charge, 0.0, Rules.FLASHLIGHT_SECONDS)

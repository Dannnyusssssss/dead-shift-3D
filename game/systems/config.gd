extends Node
## Configuración pública del juego: plataforma, capacidades del dispositivo y parámetros de URL.
## No hay secretos ni claves en este proyecto; si algún día existieran, no vivirían aquí.
## Las diferencias entre PC y celular se deciden aquí y en Settings, no repartidas por el código.

## Verdadero si el juego corre en el navegador.
var is_web: bool = false
## Verdadero si el dispositivo tiene pantalla táctil.
var is_touch: bool = false
## Semilla recibida por la URL ("?seed=N"), o -1 si no hay una válida.
var url_seed: int = -1


func _ready() -> void:
	is_web = OS.has_feature("web")
	is_touch = DisplayServer.is_touchscreen_available()
	if is_web:
		url_seed = Validation.parse_seed(_read_url_query())


## Calidad inicial según el dispositivo: Baja en táctil, Media en PC.
func default_quality() -> int:
	if is_touch:
		return SettingsSchema.QUALITY_LOW
	return SettingsSchema.QUALITY_MEDIUM


## Lee la cadena de consulta de la URL sin evaluar código: solo una propiedad del objeto location.
func _read_url_query() -> String:
	var location: JavaScriptObject = JavaScriptBridge.get_interface("location")
	if location == null:
		return ""
	var search: Variant = location.get("search")
	if search is String:
		return search
	return ""

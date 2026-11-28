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


## Calidad inicial según el dispositivo: Mínima si el navegador dibuja sin la tarjeta gráfica,
## Baja en táctil y Media en PC.
func default_quality() -> int:
	if is_software_render():
		return SettingsSchema.QUALITY_MINIMUM
	if is_touch:
		return SettingsSchema.QUALITY_LOW
	return SettingsSchema.QUALITY_MEDIUM


## Márgenes de la zona segura (izquierda, arriba, derecha, abajo) como fracción del ancho o alto
## de la pantalla. En el navegador los escribe la página (boot.js) y se validan; fuera, ninguno.
func safe_insets() -> PackedFloat32Array:
	if not is_web:
		return PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	return Validation.parse_safe_insets(_read_safe_area())


## Área de la interfaz libre de muescas según la página, dentro de un rectángulo de tamaño «size».
func safe_rect(size: Vector2) -> Rect2:
	var insets := safe_insets()
	var left := size.x * insets[0]
	var top := size.y * insets[1]
	return Rect2(
		left, top, size.x * (1.0 - insets[0] - insets[2]), size.y * (1.0 - insets[1] - insets[3])
	)


## Verdadero si el navegador dibuja por software (sin la tarjeta gráfica). Lo decide la página
## (boot.js) y deja solo un «1» o un «0»; el juego no conoce el nombre de la gráfica.
func is_software_render() -> bool:
	if not is_web:
		return false
	return Validation.parse_flag(_read_body_data("softwareRender"))


func _read_safe_area() -> String:
	return _read_body_data("safeArea")


## Lee un atributo data- del cuerpo del documento sin evaluar código: solo propiedades.
func _read_body_data(key: String) -> String:
	var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
	if document == null:
		return ""
	var body: Variant = document.get("body")
	if not body is JavaScriptObject:
		return ""
	var dataset: Variant = (body as JavaScriptObject).get("dataset")
	if not dataset is JavaScriptObject:
		return ""
	var value: Variant = (dataset as JavaScriptObject).get(key)
	return value if value is String else ""


## Lee la cadena de consulta de la URL sin evaluar código: solo una propiedad del objeto location.
func _read_url_query() -> String:
	var location: JavaScriptObject = JavaScriptBridge.get_interface("location")
	if location == null:
		return ""
	var search: Variant = location.get("search")
	if search is String:
		return search
	return ""

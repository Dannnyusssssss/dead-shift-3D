class_name PickupFeed
extends VBoxContainer
## Avisos de lo que se acaba de recoger (del suelo o de un contenedor): el icono del objeto y su
## nombre con la cantidad, uno por línea. Cada aviso dura unos segundos y se desvanece sin
## parpadear; si llegan muchos, se quitan los más viejos. Se entiende sin sonido y sin color.

## Segundos que se ve cada aviso, lo que tarda en desvanecerse y cuántos caben a la vez.
const SHOW_SECONDS: float = 3.5
const FADE_SECONDS: float = 0.6
const MAX_ENTRIES: int = 3
const ICON_SIZE: float = 40.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 6)
	EventBus.item_obtained.connect(add_entry)


## Añade el aviso de un objeto recogido (count > 1 muestra «x3»).
func add_entry(item_id: String, count: int) -> void:
	var item := GameState.items.get_item(item_id) if GameState.items != null else null
	if item == null:
		return
	while get_child_count() >= MAX_ENTRIES:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var icon := ItemIcon.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.item_id = item_id
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.text = "+ %s%s" % [tr(item.name_key), " x%d" % count if count > 1 else ""]
	row.add_child(label)
	add_child(row)
	var tween := row.create_tween()
	tween.tween_interval(SHOW_SECONDS)
	tween.tween_property(row, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(row.queue_free)


## Texto de los avisos que se ven ahora (para las pruebas).
func entries() -> PackedStringArray:
	var result := PackedStringArray()
	for row: Node in get_children():
		for child: Node in row.get_children():
			if child is Label:
				result.append((child as Label).text)
	return result

class_name HitMarker
extends Control
## Marcador de impacto junto a la mira: cuatro trazos en diagonal que aparecen un instante al
## acertar a un enemigo (más grandes si lo mató). No es un destello de pantalla: es pequeño y
## se desvanece.

const SHOW_TIME: float = 0.16
const COLOR_HIT: Color = Color(1.0, 1.0, 1.0)
const COLOR_KILL: Color = Color(1.0, 0.55, 0.45)

var _timer: float = 0.0
var _killed: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.hit_confirmed.connect(_on_hit)


func _on_hit(killed: bool) -> void:
	_timer = SHOW_TIME
	_killed = killed
	queue_redraw()


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	queue_redraw()


func _draw() -> void:
	if _timer <= 0.0:
		return
	var center := size * 0.5
	var inner := 7.0 if not _killed else 9.0
	var outer := 15.0 if not _killed else 20.0
	var color := COLOR_KILL if _killed else COLOR_HIT
	color.a = clampf(_timer / SHOW_TIME, 0.0, 1.0)
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var direction := corner.normalized()
		draw_line(center + direction * inner, center + direction * outer, color, 2.5, true)

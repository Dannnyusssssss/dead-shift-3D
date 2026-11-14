class_name NoiseIndicator
extends Label
## Indicador del ruido que hace el jugador, en tres niveles (bajo, medio, alto) con forma
## y texto: «Ruido: ))) Alto». No depende del color ni del sonido. El nivel se mantiene un
## momento tras cada ruido y luego baja de a uno.

const ICONS: Array[String] = ["·", ")", "))", ")))"]
const LEVEL_KEYS: Array[String] = ["noise_silent", "noise_low", "noise_medium", "noise_high"]
## Segundos que se mantiene el nivel tras un ruido, y cada cuánto baja un nivel después.
const HOLD_TIME: float = 1.0
const DECAY_STEP: float = 0.5

## Nivel mostrado (0 a 3).
var shown_level: int = 0

var _timer: float = 0.0
var _crouched: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 8)
	EventBus.player_noise.connect(_on_player_noise)
	_refresh()


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var crouched := player != null and player.crouching
	if crouched != _crouched:
		_crouched = crouched
		_refresh()
	if shown_level == 0:
		return
	_timer -= delta
	if _timer <= 0.0:
		shown_level -= 1
		_timer = DECAY_STEP
		_refresh()


func _on_player_noise(level: int) -> void:
	var display := clampi(level, 0, ICONS.size() - 1)
	if display >= shown_level:
		shown_level = display
		_timer = HOLD_TIME
		_refresh()


func _refresh() -> void:
	text = "%s %s %s" % [tr("hud_noise"), ICONS[shown_level], tr(LEVEL_KEYS[shown_level])]
	if _crouched:
		text += "   " + tr("hud_crouched")

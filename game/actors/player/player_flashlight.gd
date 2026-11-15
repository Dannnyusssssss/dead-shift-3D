class_name PlayerFlashlight
extends Node
## Linterna montada en el hombro derecho: alumbra hacia donde se mira y no ocupa las manos, así
## que se usa a la vez que se dispara o se golpea. La acción «flashlight» (F o el botón táctil)
## la enciende o la apaga. El estado y la carga viven en GameState.player.flashlight; aquí solo
## se gasta con el tiempo y el brillo de la luz se acerca poco a poco al que toca (encender,
## apagar o quedarse sin carga nunca es un parpadeo). Sombras solo en calidad Alta.

## Posición respecto a la cabeza: hombro derecho, un poco por debajo de los ojos.
const MOUNT: Vector3 = Vector3(0.22, -0.32, 0.05)
const ENERGY: float = 2.4
const RANGE: float = 20.0
const ANGLE_DEG: float = 30.0
## Brillo (en fracción de ENERGY) que gana o pierde por segundo: de apagada a encendida en 0,4 s.
const FADE_PER_SECOND: float = 2.5

var light: SpotLight3D = null

var _player: Player = null


func _ready() -> void:
	_player = get_parent() as Player
	light = SpotLight3D.new()
	light.name = "Flashlight"
	light.position = MOUNT
	light.spot_range = RANGE
	light.spot_angle = ANGLE_DEG
	light.spot_attenuation = 0.8
	light.light_color = Color(1.0, 0.95, 0.85)
	light.light_energy = 0.0
	light.visible = false
	_player.head.add_child(light)
	_apply_quality()
	EventBus.settings_changed.connect(_on_settings_changed)


func _physics_process(delta: float) -> void:
	var state := GameState.player
	if state == null:
		return
	var torch := state.flashlight
	if _player.controls_enabled and not _player.is_dead():
		if InputRouter.just_pressed("flashlight"):
			torch.toggle()
	if torch.tick(delta, state.inventory.bag):
		EventBus.user_message.emit("msg_batteries_swapped")
		EventBus.inventory_changed.emit()
	var target := 0.0 if _player.is_dead() else torch.level() * ENERGY
	light.light_energy = move_toward(light.light_energy, target, FADE_PER_SECOND * ENERGY * delta)
	light.visible = light.light_energy > 0.001


func _apply_quality() -> void:
	light.shadow_enabled = Settings.get_int("quality") == SettingsSchema.QUALITY_HIGH


func _on_settings_changed(key: String) -> void:
	if key == "quality":
		_apply_quality()

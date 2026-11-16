class_name SecurityMonitor
extends Interactable
## Monitores de las cámaras de la sala de seguridad: cuatro pantallas apagadas hasta que se
## usan por primera vez. Al usarlos se encienden y se abre el visor de cámaras
## (imagen real de cada una) con el informe de cuántos enemigos hay en cada piso (según el
## estado del mundo). Mientras el jugador está en una zona segura, las cámaras avisan además si
## algo se mueve cerca (lo hace Game).

const SIZE: Vector3 = Vector3(1.4, 0.9, 0.5)
## Altura del mostrador sobre el que van los monitores.
const DESK_HEIGHT: float = 0.95
const BANK_MODEL: String = "res://assets/generated/props/monitor_bank.glb"
## Pantallas del soporte (centro x, y sobre la base) y su tamaño.
const SCREENS: Array[Vector2] = [
	Vector2(-0.36, 0.48), Vector2(0.36, 0.48), Vector2(-0.36, 0.94), Vector2(0.36, 0.94)
]
const SCREEN_SIZE: Vector2 = Vector2(0.62, 0.36)
const OFF_COLOR: Color = Color(0.02, 0.025, 0.03)
const ON_GLOW: Color = Color(0.3, 0.45, 0.55)

## Encendido tras usarlo por primera vez (apagado al llegar: pantalla negra).
var powered_on: bool = false
var _screen_material: StandardMaterial3D = null


func _ready() -> void:
	super._ready()
	prompt_key = "prompt_cameras"
	var bank := ItemModels.instance_from_path(BANK_MODEL)
	if bank != null:
		bank.position.y = DESK_HEIGHT
		add_child(bank)
	_screen_material = StandardMaterial3D.new()
	_screen_material.albedo_color = OFF_COLOR
	_screen_material.roughness = 0.15
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	for spot: Vector2 in SCREENS:
		var screen := MeshInstance3D.new()
		screen.mesh = quad
		screen.material_override = _screen_material
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Delante de la cara frontal de cada monitor (que mira hacia -Z).
		screen.position = Vector3(spot.x, DESK_HEIGHT + spot.y, 0.012)
		screen.rotation.y = PI
		add_child(screen)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE + Vector3(0.3, 0.6, 0.6)
	shape.shape = box
	shape.position.y = 1.0 + SIZE.y * 0.5
	add_child(shape)


func interact(player: Player) -> void:
	_power_on()
	EventBus.cameras_requested.emit()
	used.emit(player)


## Enciende las pantallas (brillo suave y fijo, sin parpadeo).
func _power_on() -> void:
	if powered_on:
		return
	powered_on = true
	_screen_material.albedo_color = Color(0.05, 0.07, 0.08)
	_screen_material.emission_enabled = true
	_screen_material.emission = ON_GLOW
	_screen_material.emission_energy_multiplier = 0.7


## Texto con los enemigos que ven las cámaras en cada piso.
static func report() -> String:
	var lines: Array[String] = [TranslationServer.translate("cameras_title")]
	var world := GameState.world
	for floor_data: FloorData in GameState.CATALOG.floors:
		var alive := 0
		var boss_alive := false
		for index: int in floor_data.enemies.size():
			if world.is_killed(floor_data.id, "enemy_%d" % index):
				continue
			if floor_data.enemies[index].enemy.boss != null:
				boss_alive = true
			else:
				alive += 1
		var line := "%s: %d" % [TranslationServer.translate(floor_data.name_key), alive]
		if boss_alive:
			line += " + " + TranslationServer.translate("cameras_boss")
		lines.append(line)
	return "\n".join(lines)

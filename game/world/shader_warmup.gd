class_name ShaderWarmup
extends Node
## Antes de jugar, tapado por una pantalla negra, mira un instante cada piso desde su centro en
## cuatro direcciones y sin límite de distancia de dibujo. Así el navegador prepara los
## materiales al principio y no a mitad de partida (los tirones al llegar por primera vez a una
## sala). El edificio queda quieto mientras tanto. Con dibujo por software no se hace: allí
## preparar un material es rápido y cada fotograma cuesta mucho.

## Giros (grados) desde el centro de cada piso y cabeceo de la cámara.
const YAWS: Array[float] = [0.0, 90.0, 180.0, 270.0]
const PITCH: float = -12.0
const EYE_HEIGHT: float = 1.7
const FOV: float = 100.0
const FAR: float = 200.0

## Solo para el banco de rendimiento: saltarse la preparación y medir la diferencia.
static var skip_for_bench: bool = false


## Si hay que preparar los materiales en este equipo.
static func wanted() -> bool:
	if skip_for_bench:
		return false
	return DisplayServer.get_name() != "headless" and not Config.is_software_render()


## Centro de un piso a la altura de los ojos (media de los centros de sus salas).
static func floor_center(floor_data: FloorData) -> Vector3:
	var sum := Vector2.ZERO
	for room: RoomData in floor_data.rooms:
		sum += room.rect.get_center()
	var count := maxi(floor_data.rooms.size(), 1)
	return Vector3(sum.x / count, floor_data.elevation() + EYE_HEIGHT, sum.y / count)


## Recorre los pisos y deja todo como estaba. Se espera con «await».
func run(building: Building) -> void:
	var cover := CanvasLayer.new()
	cover.layer = 128
	add_child(cover)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(black)
	var label := Label.new()
	label.text = tr("loading_graphics")
	label.add_theme_font_size_override("font_size", 24)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	cover.add_child(label)
	var previous_mode := building.process_mode
	building.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	camera.fov = FOV
	camera.far = FAR
	building.add_child(camera)
	camera.make_current()
	DrawDistance.apply_unlimited(get_tree())
	var shown: Array[bool] = []
	for section: FloorSection in building.sections:
		shown.append(section.visible)
		section.visible = false
	# Un fotograma con la pantalla negra antes de empezar a mirar.
	await get_tree().process_frame
	for section: FloorSection in building.sections:
		section.visible = true
		camera.global_position = floor_center(section.floor_data)
		for yaw: float in YAWS:
			camera.rotation_degrees = Vector3(PITCH, yaw, 0.0)
			await get_tree().process_frame
		section.visible = false
	for index: int in building.sections.size():
		building.sections[index].visible = shown[index]
	DrawDistance.refresh(get_tree())
	if building.player != null:
		building.player.camera.make_current()
	camera.queue_free()
	building.process_mode = previous_mode
	cover.queue_free()

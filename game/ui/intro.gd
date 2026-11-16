class_name Intro
extends Node
## Escena de la intro antes de una partida nueva: la sala de control de la central con sus
## trabajadores, el fallo y la alarma, el aire que se vuelve verde y los trabajadores que se
## desploman, el viaje de la nube por la carretera desde la central hasta el centro comercial,
## «Dos horas después» y el guardia, dormido sobre la consola del cuarto de vigilancia, que
## despierta y se levanta.
## Todo se cuenta también con texto (se entiende sin sonido). Se salta con el botón «Saltar»,
## Esc, Espacio, Intro, clic o toque. Con «Reducir movimiento» la cámara no se mueve: cada plano
## es una imagen fija y se pasa de uno a otro fundiendo a negro. La luz de alarma late despacio
## (menos de un destello por segundo) y sin parpadeos.

signal finished

const PEOPLE: String = "res://assets/generated/people/"
const VEHICLES: String = "res://assets/generated/vehicles/"
## Separación entre el decorado de la central y el del centro comercial (dos sitios distintos).
const MALL_OFFSET: Vector3 = Vector3(0.0, 0.0, 60.0)
const FADE: float = 0.5
## Punto de partida del plano de viaje (sobre la central, mirando hacia el centro comercial).
const TRAVEL_START: Vector3 = Vector3(-4.0, 15.0, -32.0)
## Sitio del guardia dormido en el cuarto de vigilancia (respecto a MALL_OFFSET): sentado ante la
## consola, que queda delante (-Z).
const GUARD_SPOT: Vector3 = Vector3(-1.2, 0.0, -1.55)
## Latido de la luz de alarma (por segundo): muy por debajo del límite de 3 destellos.
const ALARM_RATE: float = 0.5

var _world: Node3D = null
var _camera: Camera3D = null
var _environment: Environment = null
var _alarm: OmniLight3D = null
var _workers: Array[EnemyModel] = []
var _guard: EnemyModel = null
var _guard_chair: Node3D = null
var _caption: Label = null
var _title: Label = null
var _black: ColorRect = null
var _done: bool = false
var _time: float = 0.0
var _alarm_on: bool = false


func _ready() -> void:
	_build_world()
	_build_overlay()
	_run()


func _process(delta: float) -> void:
	_time += delta
	if _alarm_on and _alarm != null:
		# Latido suave (seno), nunca un parpadeo.
		_alarm.light_energy = 1.2 + 1.0 * sin(_time * TAU * ALARM_RATE)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			skip()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		skip()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip()


## Termina la intro ya (botón «Saltar» o una tecla).
func skip() -> void:
	if _done:
		return
	_done = true
	finished.emit()


## Planos de la intro, uno detrás de otro (cámara desde, hasta, a dónde mira, segundos, texto).
func _run() -> void:
	var still := Settings.get_bool("reduce_motion")
	await _shot(
		Vector3(-5, 2.4, 6), Vector3(-2, 2.0, 4.5), Vector3(0, 1.0, -1), 5.0, "intro_1", still
	)
	if _done:
		return
	_alarm_on = true
	for worker: EnemyModel in _workers:
		worker.play_named("flinch", false)
	await _shot(
		Vector3(3, 1.7, 3), Vector3(2, 1.8, 2.2), Vector3(-1, 1.2, -2), 4.0, "intro_2", still
	)
	if _done:
		return
	var tween := create_tween()
	tween.tween_property(_environment, "fog_density", 0.25, 3.5)
	tween.parallel().tween_property(_environment, "fog_light_color", Color(0.25, 0.45, 0.12), 3.5)
	_collapse_workers()
	await _shot(
		Vector3(0, 2.0, 4.6), Vector3(0, 2.8, 4.4), Vector3(0, 0.4, 0), 4.5, "intro_3", still
	)
	if _done:
		return
	# Viaje: la nube avanza sobre la carretera desde la central hasta el centro comercial.
	_environment.fog_density = 0.012
	_environment.fog_light_color = Color(0.12, 0.2, 0.08)
	await _shot(
		TRAVEL_START,
		MALL_OFFSET + Vector3(0, 9, -6),
		MALL_OFFSET + Vector3(0, 3, 6),
		5.0,
		"intro_travel",
		still
	)
	if _done:
		return
	_environment.fog_density = 0.03
	_environment.fog_light_color = Color(0.05, 0.05, 0.07)
	var room := MALL_OFFSET
	await _shot(
		room + Vector3(1.5, 3.5, 3.0),
		room + Vector3(0.6, 1.6, 0.6),
		room + GUARD_SPOT + Vector3(0, 0.9, 0),
		3.5,
		"intro_4",
		still
	)
	if _done:
		return
	await _title_card("intro_5", 2.5)
	if _done:
		return
	_wake_guard()
	await _shot(
		room + Vector3(0.9, 1.4, 0.4),
		room + Vector3(0.7, 1.5, 0.1),
		room + GUARD_SPOT + Vector3(0, 1.1, 0),
		5.0,
		"intro_6",
		still
	)
	skip()


## Los trabajadores se desploman uno detrás de otro con el gas (caída animada, de pie y con
## sitio detrás para no atravesar nada).
func _collapse_workers() -> void:
	for index: int in _workers.size():
		var worker := _workers[index]
		get_tree().create_timer(0.5 + index * 0.8).timeout.connect(
			func() -> void:
				if not _done:
					worker.play_named("collapse", false)
		)


## El guardia, dormido sobre la consola, se endereza despacio y se levanta de la silla.
func _wake_guard() -> void:
	if _guard == null:
		return
	var tween := create_tween()
	tween.tween_method(_guard.set_lean, 1.0, 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: _guard.play_named("stand_up", false))
	# La silla se aparta hacia atrás mientras se levanta (no queda metido en ella).
	if _guard_chair != null:
		tween.parallel().tween_property(
			_guard_chair, "position:z", _guard_chair.position.z + 0.55, 0.6
		)


func _shot(
	from: Vector3, to: Vector3, look: Vector3, seconds: float, caption: String, still: bool
) -> void:
	_caption.text = tr(caption)
	var start := to if still else from
	_camera.global_position = start
	_camera.look_at(look, Vector3.UP)
	await _fade(0.0)
	if not still:
		var tween := create_tween()
		(
			tween
			. tween_method(
				func(t: float) -> void:
					_camera.global_position = from.lerp(to, t)
					_camera.look_at(look, Vector3.UP),
				0.0,
				1.0,
				seconds
			)
			. set_trans(Tween.TRANS_SINE)
		)
	await get_tree().create_timer(maxf(seconds - FADE, 0.1)).timeout
	if not _done:
		await _fade(1.0)


func _title_card(text_key: String, seconds: float) -> void:
	_caption.text = ""
	_title.text = tr(text_key)
	_title.visible = true
	await get_tree().create_timer(seconds).timeout
	_title.visible = false


func _fade(alpha: float) -> void:
	if _done:
		return
	var tween := create_tween()
	tween.tween_property(_black, "color:a", alpha, FADE)
	await tween.finished


func _build_world() -> void:
	_world = Node3D.new()
	add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.01, 0.01, 0.02)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.35, 0.37, 0.42)
	_environment.ambient_light_energy = 0.6
	_environment.fog_enabled = true
	_environment.fog_density = 0.03
	_environment.fog_light_color = Color(0.05, 0.05, 0.07)
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = _environment
	_world.add_child(world_env)
	_camera = Camera3D.new()
	_camera.fov = 60.0
	_world.add_child(_camera)
	_camera.make_current()
	_build_control_room()
	_build_guard_room()
	_build_travel()


## Sala de control: suelo, paredes, panel mural, tres consolas y tres trabajadores.
func _build_control_room() -> void:
	var builder := Kit.Builder.new()
	var floor_mat := Kit.surface("concrete_light", Color(0.8, 0.8, 0.8))
	var wall_mat := Kit.surface("plaster", Color(0.85, 0.87, 0.9))
	builder.add_box(Vector3(0, -0.05, 0), Vector3(12, 0.1, 10), floor_mat)
	builder.add_box(Vector3(0, 2, -4), Vector3(12, 4, 0.2), wall_mat)
	builder.add_box(Vector3(-6, 2, 0), Vector3(0.2, 4, 10), wall_mat)
	builder.add_box(Vector3(6, 2, 0), Vector3(0.2, 4, 10), wall_mat)
	builder.add_box(
		Vector3(0, 4.05, 0), Vector3(12, 0.1, 10), Kit.surface("ceiling_tiles", Color.WHITE)
	)
	# Una silla vacía apartada junto a la pared.
	builder.add_box(Vector3(-5.2, 0.22, 2.5), Vector3(0.5, 0.44, 0.5), Kit.gray(0.18))
	builder.add_box(Vector3(-5.2, 0.75, 2.8), Vector3(0.5, 0.6, 0.06), Kit.gray(0.18))
	_world.add_child(builder.build("ControlRoom"))
	_place(VEHICLES + "control_wall.glb", Vector3(0, 0.4, -3.85), 0.0)
	for x: float in [-3.0, 0.0, 3.0]:
		_place(VEHICLES + "control_console.glb", Vector3(x, 0, -1.5), 0.0)
	# De pie ante las consolas, separados: al desplomarse caen hacia la zona libre de detrás.
	var poses := [
		["worker", Vector3(-3, 0, -0.3), "idle"],
		["worker_f", Vector3(1.5, 0, 1.7), "talk"],
		["worker", Vector3(3.3, 0, -0.3), "idle"]
	]
	for pose: Array in poses:
		var model_name: String = pose[0]
		var anim_name: String = pose[2]
		var person := EnemyModel.create_from(PEOPLE + model_name + ".glb")
		if person == null:
			continue
		_world.add_child(person)
		person.position = pose[1]
		person.rotation.y = 0.0
		person.play_named(anim_name)
		_workers.append(person)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.6, 0)
	light.omni_range = 12.0
	light.light_energy = 1.4
	_world.add_child(light)
	_alarm = OmniLight3D.new()
	_alarm.position = Vector3(0, 3.4, -3)
	_alarm.omni_range = 14.0
	_alarm.light_color = Color(1.0, 0.15, 0.1)
	_alarm.light_energy = 0.0
	_world.add_child(_alarm)


## Cuarto de vigilancia del centro comercial: el guardia dormido sobre la consola y los monitores.
func _build_guard_room() -> void:
	var at := MALL_OFFSET
	var builder := Kit.Builder.new()
	builder.add_box(
		at + Vector3(0, -0.05, 0),
		Vector3(6, 0.1, 6),
		Kit.surface("concrete_dark", Color(0.8, 0.8, 0.8))
	)
	builder.add_box(
		at + Vector3(0, 1.5, -3),
		Vector3(6, 3, 0.2),
		Kit.surface("concrete_light", Color(0.7, 0.72, 0.75))
	)
	builder.add_box(
		at + Vector3(-3, 1.5, 0),
		Vector3(0.2, 3, 6),
		Kit.surface("concrete_light", Color(0.7, 0.72, 0.75))
	)
	_world.add_child(builder.build("GuardRoom"))
	_place(VEHICLES + "control_console.glb", at + Vector3(-1.2, 0, -2.4), 0.0)
	# Silla delante de la consola y el guardia dormido en ella, caído sobre la mesa.
	var chair := Kit.Builder.new()
	chair.add_box(at + GUARD_SPOT + Vector3(0, 0.22, 0.12), Vector3(0.5, 0.44, 0.5), Kit.gray(0.18))
	chair.add_box(at + GUARD_SPOT + Vector3(0, 0.75, 0.38), Vector3(0.5, 0.6, 0.06), Kit.gray(0.18))
	_guard_chair = chair.build("GuardChair")
	_world.add_child(_guard_chair)
	_guard = EnemyModel.create_from(PEOPLE + "guard.glb")
	if _guard != null:
		_world.add_child(_guard)
		_guard.position = at + GUARD_SPOT
		_guard.play_named("sit")
		_guard.set_lean(1.0)
	var screen := OmniLight3D.new()
	screen.position = at + Vector3(-1.2, 1.2, -1.8)
	screen.light_color = Color(0.5, 0.7, 1.0)
	screen.light_energy = 1.0
	screen.omni_range = 5.0
	_world.add_child(screen)


## Exterior para el plano de viaje: llanura, la carretera de la central al centro comercial,
## dos torres de refrigeración de la central (con el escape verde) y la fachada del centro
## comercial con algunas ventanas encendidas. Queda fuera de las salas de dentro.
func _build_travel() -> void:
	var builder := Kit.Builder.new()
	builder.add_box(
		Vector3(0, -0.2, 30), Vector3(120, 0.1, 130), Kit.surface("asphalt", Color(0.5, 0.52, 0.5))
	)
	builder.add_box(Vector3(0, -0.13, 30), Vector3(7, 0.04, 120), Kit.gray(0.12))
	for index: int in 12:
		builder.add_box(
			Vector3(0, -0.1, -10 + index * 10.0), Vector3(0.25, 0.02, 3.0), Kit.gray(0.8), false
		)
	# Fachada del centro comercial (detrás del cuarto de vigilancia).
	var mall := MALL_OFFSET + Vector3(0, 4, 14)
	builder.add_box(mall, Vector3(30, 8, 14), Kit.surface("concrete_light", Color(0.6, 0.62, 0.66)))
	for column: int in 6:
		builder.add_box(
			MALL_OFFSET + Vector3(-12.5 + column * 5.0, 5.5, 6.95),
			Vector3(2.2, 1.2, 0.1),
			Kit.emissive(Color(0.9, 0.85, 0.6)),
			false
		)
	_world.add_child(builder.build("Travel"))
	# Luna tenue para el exterior (sin sombras; dentro apenas se nota).
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	moon.light_color = Color(0.6, 0.7, 0.9)
	moon.light_energy = 0.35
	moon.shadow_enabled = false
	_world.add_child(moon)
	var tower_material := StandardMaterial3D.new()
	tower_material.albedo_color = Color(0.55, 0.56, 0.55)
	for x: float in [-26.0, -16.0]:
		var tower := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 4.0
		mesh.bottom_radius = 6.0
		mesh.height = 16.0
		mesh.material = tower_material
		tower.mesh = mesh
		tower.position = Vector3(x, 8.0, -14.0)
		_world.add_child(tower)


func _place(path: String, spot: Vector3, yaw: float) -> void:
	var node := ItemModels.instance_from_path(path)
	if node == null:
		return
	node.position = spot
	node.rotation.y = yaw
	_world.add_child(node)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -140
	_caption.offset_bottom = -60
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(_caption)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 52)
	_title.visible = false
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(_title)
	var skip_button := TapButton.new()
	skip_button.text = tr("intro_skip")
	skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_button.offset_left = -200
	skip_button.offset_top = 24
	skip_button.offset_right = -24
	skip_button.custom_minimum_size = Vector2(160, 56)
	skip_button.pressed.connect(skip)
	layer.add_child(skip_button)

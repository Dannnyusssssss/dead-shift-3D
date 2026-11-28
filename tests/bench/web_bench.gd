extends Node
@warning_ignore_start("unsafe_call_argument")
## Banco de rendimiento del dibujo, para el export «Web banco» (nunca el publicado). Recorre
## sitios fijos y mide el tiempo real de cada fotograma con varias variantes: calidad Media y
## Baja, y sobre Baja media resolución, sin luces de sala, luz por vértice, sin brillo
## especular, sin filtrado anisotrópico, sin enemigos y con la linterna. También anota el
## fotograma más largo al llegar a cada sitio (ahí se notan los tirones de compilar
## materiales). Escribe cada línea en la consola con el prefijo [banco-web] y termina con
## «[banco-web] fin». Lo lee tools/web_bench.py.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")
const SURFACES_SHADER: String = "res://game/world/surfaces.gdshader"
## Nombre, posición, giro y cabeceo (grados), y si se prueban todas las variantes.
const SPOTS: Array = [
	["pb_pasillo_oeste", Vector3(-22.0, 0.0, 0.5), -90.0, 5.0, true],
	["pb_atrio", Vector3(-9.0, 0.0, -4.6), -115.0, 12.0, true],
	["n1_pasillo_este", Vector3(20.5, 5.0, 0.0), 90.0, 0.0, true],
	["n2_patio_comidas", Vector3(-12.0, 10.0, -4.5), 0.0, 0.0, false],
	["azotea", Vector3(-10.0, 15.0, 7.0), -60.0, 0.0, false],
]
const BASE_VARIANTS: Array[String] = ["minima", "baja", "media", "alta"]
## Nombre de cada calidad en las variantes.
const QUALITY_NAMES: Array[String] = ["minima", "baja", "media", "alta"]
## Si se prueban también las variantes de diagnóstico en los sitios marcados.
const WITH_EXTRAS: bool = false
## Variantes: calidad (media o baja) y modificadores separados por «+».
const EXTRA_VARIANTS: Array[String] = [
	"baja+sin_3d",
	"baja+sin_proceso_enemigos",
	"baja+sin_proceso_objetos",
	"baja+sin_proceso_jugador",
	"baja+sin_proceso_edificio",
	"baja+sin_enemigos",
	"baja+sin_luces",
	"baja+lejos25",
	"baja+mitad_luces",
	"baja+sin_cristal",
]
const SETTLE_FRAMES: int = 20
## Fotogramas de espera mientras la página guarda una captura.
const CAPTURE_FRAMES: int = 60
const MEASURE_FRAMES: int = 40

var _game: Game = null
var _surface_materials: Array[ShaderMaterial] = []
var _original_shader: Shader = null
var _saved_ranges: Dictionary = {}
var _saved_modes: Dictionary = {}


func _ready() -> void:
	# Con «?sin_preparar» en la dirección se mide sin la preparación de materiales.
	var location: JavaScriptObject = JavaScriptBridge.get_interface("location")
	var query: Variant = location.get("search") if location != null else ""
	ShaderWarmup.skip_for_bench = query is String and str(query).contains("sin_preparar")
	_game = GAME_SCRIPT.new()
	add_child(_game)
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	if GameState.player != null:
		GameState.player.health = Rules.PLAYER_MAX_HEALTH
		GameState.player.infection.exposure = 0.0


func _run() -> void:
	for _frame: int in 30:
		await get_tree().process_frame
	while _game.warming_up:
		await get_tree().process_frame
	_find_surface_materials()
	_log(
		(
			"motor %s, ventana %s, adaptador «%s» de «%s»"
			% [
				Engine.get_version_info().string,
				get_viewport().get_visible_rect().size,
				RenderingServer.get_video_adapter_name(),
				RenderingServer.get_video_adapter_vendor(),
			]
		)
	)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_log(
		(
			"sitio | variante | ms medio | p90 ms | max ms | max al llegar ms | draw calls"
			+ " | dibujo CPU ms | preparación ms | GPU ms"
		)
	)
	for spot: Array in SPOTS:
		var arrival := await _place(spot)
		var variants: Array[String] = []
		variants.append_array(BASE_VARIANTS)
		if spot[4] and WITH_EXTRAS:
			variants.append_array(EXTRA_VARIANTS)
		for variant: String in variants:
			_apply(variant)
			for _frame: int in SETTLE_FRAMES:
				await get_tree().process_frame
			await _measure(str(spot[0]), variant, arrival)
			arrival = 0.0
			if spot == SPOTS[0]:
				# Pide una captura de la página (la hace tools/web_bench.py) y le da tiempo.
				_log("captura %s_%s" % [spot[0], variant.replace("+", "_")])
				for _frame: int in CAPTURE_FRAMES:
					await get_tree().process_frame
			_reset()
	_log("fin")


func _log(text: String) -> void:
	print("[banco-web] " + text)


func _place(spot: Array) -> float:
	# La calidad se pone antes de moverse: cambiarla recrea los búferes de dibujo y eso no es
	# un tirón de llegar a un sitio nuevo.
	Settings.set_value("quality", SettingsSchema.QUALITY_MEDIUM)
	for _frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var player := _game.level.player
	player.set_blocked("banco", true)
	player.global_position = spot[1]
	player.rotation.y = deg_to_rad(spot[2])
	player.head.rotation.x = deg_to_rad(spot[3])
	var worst := 0.0
	var last := Time.get_ticks_usec()
	for _frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
	return worst


func _measure(label: String, variant: String, arrival: float) -> void:
	var frames: Array[float] = []
	var draws := 0.0
	var render_cpu := 0.0
	var setup_cpu := 0.0
	var gpu := 0.0
	var rid := get_viewport().get_viewport_rid()
	var last := Time.get_ticks_usec()
	for _frame: int in MEASURE_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		draws = maxf(draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		setup_cpu += RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var total := 0.0
	for value: float in frames:
		total += value
	frames.sort()
	_log(
		(
			"%s | %s | %.1f | %.1f | %.1f | %.1f | %d | %.1f | %.1f | %.1f"
			% [
				label,
				variant,
				total / frames.size(),
				frames[int(frames.size() * 0.9)],
				frames[frames.size() - 1],
				arrival,
				draws,
				render_cpu / MEASURE_FRAMES,
				setup_cpu / MEASURE_FRAMES,
				gpu / MEASURE_FRAMES,
			]
		)
	)


func _find_surface_materials() -> void:
	for node: Node in _game.level.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var candidates: Array[Material] = [mesh_instance.material_override]
		if mesh_instance.mesh != null:
			for index: int in mesh_instance.mesh.get_surface_count():
				candidates.append(mesh_instance.mesh.surface_get_material(index))
		for material: Material in candidates:
			var shader_material := material as ShaderMaterial
			if shader_material == null or shader_material.shader == null:
				continue
			if shader_material.shader.resource_path != SURFACES_SHADER:
				continue
			if not _surface_materials.has(shader_material):
				_surface_materials.append(shader_material)
				_original_shader = shader_material.shader


func _shader_variant(old: String, new: String) -> Shader:
	var shader := Shader.new()
	shader.code = _original_shader.code.replace(old, new)
	return shader


func _set_surface_shader(shader: Shader) -> void:
	for material: ShaderMaterial in _surface_materials:
		material.shader = shader


func _room_lights() -> Array[Node]:
	return _game.level.find_children("*", "OmniLight3D", true, false)


func _apply(variant: String) -> void:
	var parts := variant.split("+")
	Settings.set_value("quality", maxi(QUALITY_NAMES.find(parts[0]), 0))
	var environment: Environment = _game.level.get("_environment")
	var lights := _room_lights()
	for part: String in parts.slice(1):
		match part:
			"escala50":
				get_viewport().scaling_3d_scale = 0.5
			"escala100":
				get_viewport().scaling_3d_scale = 1.0
			"sin_luces":
				for light: Node in lights:
					(light as Light3D).visible = false
			"mitad_luces":
				for index: int in lights.size():
					if index % 2 == 1:
						(lights[index] as Light3D).visible = false
			"luces_cortas":
				for light: Node in lights:
					var omni := light as OmniLight3D
					_saved_ranges[omni] = omni.omni_range
					omni.omni_range *= 0.6
			"fade12":
				for light: Node in lights:
					var faded := light as Light3D
					faded.distance_fade_enabled = true
					faded.distance_fade_begin = 12.0
					faded.distance_fade_length = 4.0
			"sin_glow":
				environment.glow_enabled = false
			"sin_niebla":
				environment.fog_enabled = false
			"tonemap_lineal":
				environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			"sin_interfaz":
				(_game.get("_hud") as CanvasItem).visible = false
			"sin_3d":
				get_viewport().disable_3d = true
			"sin_proceso_enemigos":
				_disable_group("enemy")
			"sin_proceso_objetos":
				_disable_group("pickup")
			"sin_proceso_jugador":
				_disable(_game.level.player)
			"sin_proceso_edificio":
				_game.level.set_process(false)
			"lejos25":
				get_viewport().get_camera_3d().far = 25.0
			"sin_cristal":
				for mesh: MeshInstance3D in _glass_meshes():
					mesh.visible = false
			"sin_enemigos":
				for enemy: Node in get_tree().get_nodes_in_group("enemy"):
					(enemy as Node3D).visible = false
			"linterna":
				GameState.player.flashlight.on = true


func _disable_group(group: String) -> void:
	for node: Node in get_tree().get_nodes_in_group(group):
		_disable(node)


func _disable(node: Node) -> void:
	_saved_modes[node] = node.process_mode
	node.process_mode = Node.PROCESS_MODE_DISABLED


func _glass_meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var glass := Kit.glass_material()
	for node: Node in _game.level.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.material_override == glass:
			result.append(mesh_instance)
			continue
		if mesh_instance.mesh == null:
			continue
		for index: int in mesh_instance.mesh.get_surface_count():
			if mesh_instance.mesh.surface_get_material(index) == glass:
				result.append(mesh_instance)
				break
	return result


func _reset() -> void:
	Settings.apply_quality()
	get_viewport().disable_3d = false
	for node: Node in _saved_modes:
		if is_instance_valid(node):
			node.process_mode = _saved_modes[node] as Node.ProcessMode
	_saved_modes.clear()
	_game.level.set_process(true)
	var environment: Environment = _game.level.get("_environment")
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_game.level.call("_apply_quality_look")
	for light: Node in _room_lights():
		var reset_light := light as Light3D
		reset_light.visible = true
		reset_light.distance_fade_enabled = false
	for omni: OmniLight3D in _saved_ranges:
		omni.omni_range = _saved_ranges[omni]
	_saved_ranges.clear()
	(_game.get("_hud") as CanvasItem).visible = true
	for mesh: MeshInstance3D in _glass_meshes():
		mesh.visible = true
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		(enemy as Node3D).visible = true
	GameState.player.flashlight.on = false

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Luces del edificio dentro de los límites del render: todas caben en el tope de luces por
## cuadro (si no, desde el atrio unas u otras desaparecían según la cámara), lo fijo de cada piso
## va en su capa y las luces de un piso no alumbran la geometría de otro.

const GAME_SCRIPT: GDScript = preload("res://game/game.gd")

var _game: Game


func before_each() -> void:
	GameState.forced_seed = 5
	_game = GAME_SCRIPT.new()
	add_child_autofree(_game)
	await wait_physics_frames(3)


func after_each() -> void:
	GameState.forced_seed = -1
	InputRouter.gameplay_active = false
	InputRouter.release_capture()


func test_all_lights_fit_the_per_frame_limit() -> void:
	var limit: int = ProjectSettings.get_setting("rendering/limits/opengl/max_renderable_lights")
	var lights := _game.level.find_children("*", "OmniLight3D", true, false)
	assert_gt(lights.size(), 0)
	assert_lte(lights.size(), limit, "luces del edificio frente al tope por cuadro")


func test_floor_geometry_and_lights_use_the_floor_layer() -> void:
	for section: FloorSection in _game.level.sections:
		var own := section.visual_layer()
		assert_eq(own & FloorSection.DYNAMIC_LAYER, 0, "la capa del piso no es la dinámica")
		for node: Node in section.find_children("*", "VisualInstance3D", true, false):
			if node is Light3D:
				var light := node as Light3D
				assert_eq(light.light_cull_mask, own | FloorSection.DYNAMIC_LAYER, light.name)
			else:
				assert_eq((node as VisualInstance3D).layers, own, String(node.get_path()))
	var layers: Array[int] = []
	for section: FloorSection in _game.level.sections:
		assert_false(layers.has(section.visual_layer()), "cada piso tiene su capa")
		layers.append(section.visual_layer())

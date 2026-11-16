extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Superficies con textura: la tabla del juego coincide con la textura generada y las pinturas
## del kit se codifican y se leen bien.

const LAYERS_JSON := "res://assets/generated/textures/surfaces.json"
const LAYERS_TEXTURE := "res://assets/generated/textures/surfaces_albedo.png"


## El orden de Surfaces.IDS es el de las capas que escribió tools/blender/surfaces.py: si no,
## cada superficie mostraría la textura de otra.
func test_ids_match_generated_layers() -> void:
	var text := FileAccess.get_file_as_string(LAYERS_JSON)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "surfaces.json no es un objeto")
	var layers: Array = (parsed as Dictionary).get("layers", [])
	assert_eq(layers.size(), Surfaces.IDS.size())
	for i: int in layers.size():
		assert_eq(String(layers[i]), Surfaces.IDS[i])


## La textura importada tiene una capa por superficie y caben en el alfa del vértice.
func test_texture_has_one_layer_per_surface() -> void:
	var texture: TextureLayered = load(LAYERS_TEXTURE)
	assert_not_null(texture)
	assert_eq(texture.get_layers(), Surfaces.IDS.size())
	assert_lt(Surfaces.IDS.size(), Surfaces.PLAIN, "la capa PLAIN debe quedar libre")
	assert_eq(Surfaces.TILE_METERS.size(), Surfaces.IDS.size())


func test_layer_of_known_and_unknown() -> void:
	assert_eq(Surfaces.layer_of("plaster"), 0)
	assert_eq(Surfaces.layer_of("asphalt"), Surfaces.IDS.size() - 1)
	assert_eq(Surfaces.layer_of(""), Surfaces.PLAIN)
	assert_eq(Surfaces.layer_of("no_existe"), Surfaces.PLAIN)


func test_tile_table_has_sixteen_positive_values() -> void:
	var table := Surfaces.tile_table()
	assert_eq(table.size(), Surfaces.MAX_LAYERS)
	for value: float in table:
		assert_gt(value, 0.0)


## La capa vuelve a salir igual tras guardarse en 8 bits (como la lee el shader: floor(a * 16)).
func test_paint_code_layer_survives_8_bit_storage() -> void:
	for layer: int in Surfaces.MAX_LAYERS:
		var code := Kit.paint_code(Color(0.5, 0.5, 0.5), layer)
		var stored := roundf(code.a * 255.0) / 255.0
		assert_eq(int(floorf(stored * 16.0)), layer)


## El tono de una superficie con textura nunca pasa de 1 (no cabría en el color del vértice).
func test_texture_tint_stays_in_range() -> void:
	for color: Color in [Color(0.9, 0.2, 0.1), Color(0.05, 0.05, 0.05), Color.WHITE]:
		var tint := Surfaces.texture_tint(color)
		for channel: float in [tint.r, tint.g, tint.b]:
			assert_between(channel, 0.0, 1.0)


func test_kit_surface_is_a_paint_and_glass_is_not() -> void:
	var mat := Kit.surface("tiles_marble", Color.WHITE)
	assert_true(Kit.is_paint(mat))
	assert_eq(int(floorf(Kit.paint_of(mat).a * 16.0)), Surfaces.layer_of("tiles_marble"))
	assert_true(Kit.is_paint(Kit.gray(0.5)))
	assert_false(Kit.is_paint(Kit.glass_material()))


## Las superficies que indican los pisos existen (un id mal escrito saldría sin textura).
func test_floor_rooms_use_known_surfaces() -> void:
	for floor_data: FloorData in GameState.CATALOG.floors:
		for room: RoomData in floor_data.rooms:
			for id: String in [room.floor_surface, room.wall_surface, room.ceiling_surface]:
				if id.is_empty():
					continue
				assert_true(Surfaces.IDS.has(id), "%s/%s: %s" % [floor_data.id, room.id, id])


## Todas las piezas pintadas de una sala van en una sola superficie (una llamada de dibujo).
func test_builder_merges_painted_boxes_into_one_surface() -> void:
	var builder := Kit.Builder.new()
	builder.add_box(Vector3.ZERO, Vector3.ONE, Kit.surface("plaster", Color.WHITE))
	builder.add_box(Vector3(2, 0, 0), Vector3.ONE, Kit.surface("wood_floor", Color.WHITE))
	builder.add_box(Vector3(4, 0, 0), Vector3.ONE, Kit.gray(0.4))
	builder.add_colored_box(Transform3D(Basis.IDENTITY, Vector3(6, 0, 0)), Vector3.ONE, Color.RED)
	var body := builder.build("test")
	var meshes := 0
	for child: Node in body.get_children():
		if child is MeshInstance3D:
			meshes += 1
			assert_eq((child as MeshInstance3D).mesh.get_surface_count(), 1)
	assert_eq(meshes, 1)
	body.free()


## Luz por vértice: una pared es más oscura al pie que arriba; un suelo no se oscurece.
func test_tall_pieces_darken_at_the_foot() -> void:
	var builder := Kit.Builder.new()
	builder.add_box(Vector3(0, 1.5, 0), Vector3(1, 3, 0.2), Kit.surface("plaster", Color.WHITE))
	var body := builder.build("wall")
	var mesh: Mesh = (body.get_child(0) as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var low := 1.0
	var high := 0.0
	for i: int in vertices.size():
		if vertices[i].y < 0.1:
			low = minf(low, colors[i].r)
		else:
			high = maxf(high, colors[i].r)
	assert_lt(low, high)
	body.free()


## Cada modelo que piden los pisos existe y se puede preparar (si faltara, se vería el hueco).
func test_floor_models_exist() -> void:
	var count := 0
	for floor_data: FloorData in GameState.CATALOG.floors:
		for prop: PropSpec in floor_data.props:
			if prop.kind != PropSpec.KIND_MODEL:
				continue
			count += 1
			var mesh := Kit.model_mesh(prop.text_key)
			assert_not_null(mesh, "%s: falta el modelo %s" % [floor_data.id, prop.text_key])
			if mesh != null:
				assert_gt(mesh.get_surface_count(), 0)
	assert_gt(count, 0, "los pisos deberían usar modelos")


## Un modelo preparado lleva la capa sin textura en el alfa y su color de vértice.
func test_model_mesh_is_plain_painted() -> void:
	var mesh := Kit.model_mesh("bench")
	assert_not_null(mesh)
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_gt(colors.size(), 0)
	for c: Color in colors:
		assert_eq(int(floorf(c.a * 16.0)), Surfaces.PLAIN)
	assert_null(Kit.model_mesh("no_existe"))


## Los bloques que solo dan colisión siempre van con su modelo en el mismo piso.
func test_collision_only_blocks_come_with_models() -> void:
	for floor_data: FloorData in GameState.CATALOG.floors:
		var hidden := 0
		var models := 0
		for prop: PropSpec in floor_data.props:
			if prop.collision_only:
				hidden += 1
			if prop.kind == PropSpec.KIND_MODEL:
				models += 1
		if hidden > 0:
			assert_gt(models, 0, floor_data.id)


## Cada tienda con escaparate tiene marca inventada (rótulo con placa) y la traducción la lee.
func test_storefront_rooms_have_brands() -> void:
	for floor_data: FloorData in GameState.CATALOG.floors:
		for room: RoomData in floor_data.rooms:
			if room.storefront_side < 0 or room.id == "security_post":
				continue
			var key := "brand_" + room.id
			assert_ne(tr(key), key, "%s/%s sin marca" % [floor_data.id, room.id])


## Los rótulos del patio de comidas llevan marca y tipo de comida en dos líneas.
func test_food_signs_have_two_lines() -> void:
	for key: String in ["sign_food_pizza", "sign_food_grill", "sign_food_juice"]:
		assert_eq(tr(key).split("\n").size(), 2, key)


## Luces rotas: siempre las mismas, nunca todas las de una sala, nunca en zonas seguras ni al
## aire libre; y hay alguna (zonas oscuras).
func test_broken_lights_rules() -> void:
	var broken := 0
	for floor_data: FloorData in GameState.CATALOG.floors:
		for room: RoomData in floor_data.rooms:
			var count := maxi(room.light_count, 1)
			var lit := 0
			for index: int in count:
				var off := FloorSection.is_light_broken(room, index)
				assert_eq(off, FloorSection.is_light_broken(room, index))
				if off:
					broken += 1
					assert_false(room.safe_zone, room.id)
					assert_false(room.outdoor, room.id)
				else:
					lit += 1
			assert_gt(lit, 0, "%s/%s a oscuras" % [floor_data.id, room.id])
	assert_gt(broken, 0, "debería haber alguna luz rota")


func test_emissive_paint_uses_its_layer() -> void:
	var mat := Kit.emissive(Color(0.2, 0.85, 0.35))
	assert_true(Kit.is_paint(mat))
	assert_eq(int(floorf(Kit.paint_of(mat).a * 16.0)), Surfaces.EMISSIVE)
	assert_lt(Surfaces.IDS.size(), Surfaces.EMISSIVE, "la capa emisiva debe quedar libre")

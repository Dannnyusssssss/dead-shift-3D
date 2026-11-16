extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Modelos de armas y objetos: todos los objetos del catálogo tienen el suyo y las armas
## muestran el desgaste con la forma (no solo con el color).


## Ningún objeto del juego se queda sin modelo (se vería la caja de respaldo).
func test_every_catalog_item_has_a_model() -> void:
	for item: ItemData in GameState.CATALOG.items:
		assert_not_null(ItemModels.mesh(item.id, 0), "sin modelo: " + item.id)


## Cada arma que se desgasta tiene sus tres versiones y cada estado añade piezas (rayas,
## grietas, cinta). Las irrompibles (la porra) tienen un solo modelo.
func test_weapons_have_three_wear_states_with_more_detail() -> void:
	for item: ItemData in GameState.CATALOG.items:
		if item.category != ItemData.CATEGORY_WEAPON:
			continue
		var single := not ResourceLoader.exists(ItemModels.FOLDER + item.id + "_w0.glb")
		if single and item.weapon.max_durability <= 0.0:
			assert_true(ResourceLoader.exists(ItemModels.FOLDER + item.id + ".glb"), item.id)
			continue
		var previous := 0
		for state: int in ItemModels.WEAR_STATES:
			var path := ItemModels.path_for(item.id, state)
			assert_true(path.ends_with("_w%d.glb" % state), path)
			var mesh := ItemModels.mesh(item.id, state)
			assert_not_null(mesh)
			var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			assert_gt(
				vertices.size(), previous, "%s: el estado %d no añade detalle" % [item.id, state]
			)
			previous = vertices.size()


## El estado roto usa la versión crítica (no hay modelo aparte) y uno desconocido no falla.
func test_out_of_range_states_and_unknown_items() -> void:
	assert_eq(ItemModels.path_for("bat", 3), ItemModels.path_for("bat", 2))
	assert_eq(ItemModels.path_for("bat", -1), ItemModels.path_for("bat", 0))
	assert_null(ItemModels.mesh("no_existe"))
	assert_null(ItemModels.instance("no_existe"))


func test_instance_uses_vertex_colors() -> void:
	var node := ItemModels.instance("knife", 0)
	assert_not_null(node)
	var mat := node.material_override as StandardMaterial3D
	assert_true(mat.vertex_color_use_as_albedo)
	node.free()
	var glowing := ItemModels.instance("bandage", 0, true)
	assert_true((glowing.material_override as StandardMaterial3D).emission_enabled)
	glowing.free()


## Helicóptero y piezas de la intro existen (el helicóptero los usa al esperar en la azotea).
func test_vehicle_models_exist() -> void:
	for name: String in [
		"helicopter_body",
		"helicopter_rotor",
		"helicopter_tail_rotor",
		"control_console",
		"control_wall"
	]:
		var node := ItemModels.instance_from_path("res://assets/generated/vehicles/%s.glb" % name)
		assert_not_null(node, name)
		if node != null:
			node.free()

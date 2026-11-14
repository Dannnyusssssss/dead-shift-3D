extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Estado del mundo entre pisos: enemigos muertos, objetos recogidos, contenedores registrados,
## objetos en el suelo y marcas, separados por piso.


func test_killed_and_taken_are_per_floor() -> void:
	var world := WorldState.new()
	world.mark_killed("ground_floor", "enemy_0")
	world.mark_taken("ground_floor", "room_1")
	assert_true(world.is_killed("ground_floor", "enemy_0"))
	assert_false(world.is_killed("level_1", "enemy_0"), "otro piso")
	assert_true(world.is_taken("ground_floor", "room_1"))
	assert_false(world.is_taken("ground_floor", "room_2"))


func test_container_remembers_what_is_left() -> void:
	var world := WorldState.new()
	assert_false(world.has_container("level_1", "shop_0"))
	world.set_container("level_1", "shop_0", PackedStringArray(["tape:1"]))
	assert_true(world.has_container("level_1", "shop_0"))
	assert_eq(world.container_contents("level_1", "shop_0"), PackedStringArray(["tape:1"]))
	world.set_container("level_1", "shop_0", PackedStringArray())
	assert_true(world.container_contents("level_1", "shop_0").is_empty(), "registrado entero")


func test_drops_are_copied_not_shared() -> void:
	var world := WorldState.new()
	var entries: Array[Dictionary] = [{"id": "rag", "count": 1, "x": 1.0, "z": 2.0}]
	world.set_drops("ground_floor", entries)
	entries[0]["count"] = 99
	assert_eq(world.drops("ground_floor")[0]["count"], 1)
	assert_true(world.drops("level_1").is_empty())


func test_flags_are_global() -> void:
	var world := WorldState.new()
	world.set_flag("shortcut_l1")
	world.set_flag("")
	assert_true(world.has_flag("shortcut_l1"))
	assert_false(world.has_flag(""))
	assert_eq(world.flags.size(), 1)

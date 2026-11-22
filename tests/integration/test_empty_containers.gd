extends GutTest
## Contenedores vacíos desde el principio: en Difícil el reparto por semilla puede dejar en un
## contenedor solo la venda que la dificultad quita, y antes aparecía abierto como si el
## jugador ya lo hubiera registrado (el armario del inicio «ya abierto» en una partida nueva).
## Ahora aparece cerrado y al abrirlo avisa de que está vacío; solo lo que el jugador registró
## (lo recuerda el estado del mundo) aparece abierto.

const SEEDS: int = 60


## La causa: con Difícil hay semillas en las que algún contenedor de la planta baja se queda sin
## nada; con Fácil, ninguna.
func test_hard_difficulty_can_empty_a_container() -> void:
	assert_gt(_empty_containers("hard"), 0, "en Difícil algún contenedor sale vacío")
	assert_eq(_empty_containers("easy"), 0, "en Fácil ningún contenedor sale vacío")


func test_empty_container_starts_closed_and_opens_once() -> void:
	var box := LootContainer.new()
	add_child_autofree(box)
	assert_false(box.is_open(), "vacío desde el principio: cerrado")
	assert_true(box.enabled, "se puede abrir")
	watch_signals(box)
	box.interact(null)
	assert_true(box.is_open(), "al abrirlo se abre")
	assert_false(box.enabled, "y ya no se vuelve a abrir")
	assert_signal_emitted(box, "used", "queda registrado en el estado del mundo")


func test_searched_empty_container_starts_open() -> void:
	var box := LootContainer.new()
	box.searched = true
	add_child_autofree(box)
	assert_true(box.is_open(), "ya registrado en esta partida: abierto")
	assert_false(box.enabled)


## Contenedores de la planta baja que salen vacíos, sumando todas las semillas.
func _empty_containers(difficulty_id: String) -> int:
	var catalog := GameState.CATALOG
	var difficulty := Difficulty.new(catalog.find_difficulty(difficulty_id))
	var ground: FloorData = null
	for floor_data: FloorData in catalog.floors:
		if floor_data.id == catalog.start_floor:
			ground = floor_data
	var empty := 0
	for seed_value: int in range(1, SEEDS + 1):
		var plan := LootPlan.build(catalog.floors, seed_value, true, GameState.items)
		var loot := difficulty.floor_loot()
		for room: RoomData in ground.rooms:
			for spot: LootSpot in plan.loot_for(ground.id, room):
				if spot.kind == LootSpot.KIND_PICKUP:
					# Como el piso: los objetos sueltos también gastan lo que se quita.
					var item := GameState.items.get_item(spot.item_id)
					if item != null:
						loot.adjust(item.id, item.category, spot.count)
					continue
				if loot.adjust_contents(spot.contents, GameState.items).is_empty():
					empty += 1
	return empty

extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Reparto del botín con semilla: con cualquier semilla la partida se puede completar (nada
## clave detrás de una puerta con llave), no se pierde ni aparece nada, las armas y chalecos no
## se mueven y la misma semilla da siempre el mismo reparto.

const SEEDS: int = 500


## Objetos de un piso como «id» -> cantidad total (sueltos y dentro de contenedores).
func _totals(floor_data: FloorData, plan: LootPlan) -> Dictionary:
	var totals: Dictionary = {}
	for room: RoomData in floor_data.rooms:
		var spots := room.loot if plan == null else plan.loot_for(floor_data.id, room)
		for spot: LootSpot in spots:
			if spot.kind == LootSpot.KIND_PICKUP:
				totals[spot.item_id] = int(totals.get(spot.item_id, 0)) + spot.count
			for entry: String in spot.contents:
				var parts := entry.split(":")
				var amount := parts[1].to_int() if parts.size() > 1 else 1
				totals[parts[0]] = int(totals.get(parts[0], 0)) + amount
	return totals


## Propiedad sobre 500 semillas: completable y sin perder ni inventar objetos.
func test_every_seed_gives_a_completable_layout() -> void:
	var floors := GameState.CATALOG.floors
	var reference: Dictionary = {}
	for floor_data: FloorData in floors:
		reference[floor_data.id] = _totals(floor_data, null)
	var problems := 0
	for seed_value: int in SEEDS:
		var plan := LootPlan.build(floors, seed_value * 7919 + 13, true, GameState.items)
		for floor_data: FloorData in floors:
			if _totals(floor_data, plan) != reference[floor_data.id]:
				problems += 1
			var locked := LootPlan.locked_rooms(floor_data)
			for room: RoomData in floor_data.rooms:
				var spots := plan.loot_for(floor_data.id, room)
				for index: int in spots.size():
					if locked.has(room.id) and LootPlan.holds_key_item(spots[index]):
						problems += 1
					# Armas y chalecos se quedan en su punto.
					var original: LootSpot = room.loot[index]
					if original.kind == LootSpot.KIND_PICKUP:
						var item := GameState.items.get_item(original.item_id)
						if (
							item != null
							and item.category in [ItemData.CATEGORY_WEAPON, ItemData.CATEGORY_VEST]
						):
							if spots[index].item_id != original.item_id:
								problems += 1
	assert_eq(problems, 0)


## Las piezas del teléfono y las llaves aparecen en el mapa con cualquier semilla.
func test_key_items_are_always_found() -> void:
	var wanted: Array[String] = ["phone_antenna", "phone_battery", "phone_board", "security_key"]
	for seed_value: int in 50:
		var plan := LootPlan.build(GameState.CATALOG.floors, seed_value, true, GameState.items)
		var found := MapMarkers.locations(GameState.CATALOG.floors, wanted, plan)
		assert_eq(found.size(), wanted.size(), "semilla %d" % seed_value)


func test_same_seed_same_layout_and_seeds_differ() -> void:
	var floors := GameState.CATALOG.floors
	var a := LootPlan.build(floors, 1234, true, GameState.items)
	var b := LootPlan.build(floors, 1234, true, GameState.items)
	var c := LootPlan.build(floors, 98765, true, GameState.items)
	var same := true
	var differs := false
	for floor_data: FloorData in floors:
		for room: RoomData in floor_data.rooms:
			var sa := a.loot_for(floor_data.id, room)
			var sb := b.loot_for(floor_data.id, room)
			var sc := c.loot_for(floor_data.id, room)
			for i: int in sa.size():
				if sa[i].item_id != sb[i].item_id or sa[i].contents != sb[i].contents:
					same = false
				if sa[i].item_id != sc[i].item_id or sa[i].contents != sc[i].contents:
					differs = true
	assert_true(same, "la misma semilla debe dar el mismo reparto")
	assert_true(differs, "semillas distintas deberían repartir distinto")


## Sin reparto (partidas guardadas antes) todo queda como en los datos, y los datos del
## catálogo nunca se tocan.
func test_without_shuffle_layout_matches_data() -> void:
	var floors := GameState.CATALOG.floors
	var plan := LootPlan.build(floors, 42, false, GameState.items)
	for floor_data: FloorData in floors:
		assert_eq(_totals(floor_data, plan), _totals(floor_data, null))
		for room: RoomData in floor_data.rooms:
			var spots := plan.loot_for(floor_data.id, room)
			for i: int in spots.size():
				assert_eq(spots[i].item_id, room.loot[i].item_id)
	var before := _totals(floors[1], null)
	LootPlan.build(floors, 7, true, GameState.items)
	assert_eq(_totals(floors[1], null), before, "el catálogo no cambia")


## Semillas extremas (la mayor que admite la URL, 0 y negativas) no rompen el reparto.
func test_extreme_seeds() -> void:
	for seed_value: int in [0, -1, Validation.SEED_MAX, -9223372036854775807, 9223372036854775807]:
		var plan := LootPlan.build(GameState.CATALOG.floors, seed_value, true, GameState.items)
		assert_not_null(plan)
		assert_true(plan.shuffled)


## La puerta con llave del Nivel 1 se reconoce (si no, la regla de completable no protegería).
func test_locked_rooms_are_detected() -> void:
	var level_1 := GameState.CATALOG.find_floor("level_1")
	assert_has(LootPlan.locked_rooms(level_1), "security_post")


## Propiedad sobre 500 semillas: siempre hay pilas para la linterna antes del apagón del jefe
## (en la planta baja o el Nivel 1, fuera de salas con llave) y el Neutrax colocado sigue en la
## farmacia.
func test_batteries_before_the_boss_and_neutrax_in_pharmacy() -> void:
	var floors := GameState.CATALOG.floors
	for seed_value: int in SEEDS:
		var plan := LootPlan.build(floors, seed_value, true, GameState.items)
		var batteries := 0
		for floor_data: FloorData in floors:
			var locked := LootPlan.locked_rooms(floor_data)
			for room: RoomData in floor_data.rooms:
				for spot: LootSpot in plan.loot_for(floor_data.id, room):
					var ids: Array[String] = [spot.item_id]
					for entry: String in spot.contents:
						ids.append(entry.get_slice(":", 0))
					if ids.has("neutrax"):
						assert_eq(room.id, "pharmacy", "semilla %d" % seed_value)
					var early := floor_data.level_index <= 1 and not locked.has(room.id)
					if early and ids.has("batteries"):
						batteries += 1
		assert_gt(batteries, 0, "pilas antes del jefe con la semilla %d" % seed_value)

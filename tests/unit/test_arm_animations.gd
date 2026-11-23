extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Animaciones de los brazos: datos coherentes (sin saltos al empezar y terminar), elección de
## la animación según el arma o el objeto, y montaje del esqueleto en PlayerArms.


func _same(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if absf(a[i] - b[i]) > 0.0001:
			return false
	return true


## Las acciones empiezan y terminan en el reposo (no hay salto al pasar de una a otra) y los
## bucles terminan como empiezan.
func test_animations_are_continuous() -> void:
	for anim: String in ArmAnimations.names():
		var first := ArmAnimations.sample(anim, 0.0)
		var last := ArmAnimations.sample(anim, 1.0)
		assert_eq(first.size(), ArmAnimations.POSE_VALUES, anim)
		assert_true(_same(first, last), "%s no termina como empieza" % anim)
		if not anim.begins_with("craft_"):
			assert_true(_same(first, ArmAnimations.rest()), "%s no empieza en reposo" % anim)


func test_sample_limits_and_unknown() -> void:
	assert_true(_same(ArmAnimations.sample("swing", -1.0), ArmAnimations.sample("swing", 0.0)))
	assert_true(_same(ArmAnimations.sample("swing", 5.0), ArmAnimations.sample("swing", 1.0)))
	# En bucle se da la vuelta: 1,25 es lo mismo que 0,25.
	assert_true(_same(ArmAnimations.sample("walk", 1.25), ArmAnimations.sample("walk", 0.25)))
	assert_true(_same(ArmAnimations.sample("no_existe", 0.5), ArmAnimations.rest()))


## La acción se nota: a mitad de un golpe el brazo derecho no está en reposo.
func test_actions_move_the_arm() -> void:
	for anim: String in ["swing", "stab", "push", "bash", "throw", "reload_pistol"]:
		assert_false(_same(ArmAnimations.sample(anim, 0.45), ArmAnimations.rest()), anim)


func test_blend_and_damp() -> void:
	var swing := ArmAnimations.sample("swing", 0.5)
	assert_true(_same(ArmAnimations.blend(swing, ArmAnimations.rest(), 0.0), swing))
	assert_true(_same(ArmAnimations.blend(swing, ArmAnimations.rest(), 1.0), ArmAnimations.rest()))
	assert_true(_same(ArmAnimations.damp(swing, 0.0), ArmAnimations.rest()))
	assert_true(_same(ArmAnimations.damp(swing, 1.0), swing))


func test_soften_keeps_actions_short_but_recognizable() -> void:
	var base := ArmAnimations.sample("idle", 0.0)
	var swing := ArmAnimations.sample("swing", 0.5)
	assert_true(_same(ArmAnimations.soften(swing, base, 1.0), swing), "sin reducir, tal cual")
	assert_true(_same(ArmAnimations.soften(swing, base, 0.0), base), "del todo, la pose base")
	var soft := ArmAnimations.soften(swing, base, 0.4)
	var full_reach := 0.0
	var soft_reach := 0.0
	for index: int in swing.size():
		full_reach += absf(swing[index] - base[index])
		soft_reach += absf(soft[index] - base[index])
	assert_gt(full_reach, 0.0)
	assert_almost_eq(soft_reach, full_reach * 0.4, 0.001, "recorre el 40 %")


## Cada arma del juego tiene golpe, y las de fuego su disparo y recarga; cada cura su gesto.
func test_choices_cover_the_catalog() -> void:
	var anims := ArmAnimations.names()
	for item: ItemData in GameState.CATALOG.items:
		if item.category == ItemData.CATEGORY_WEAPON:
			assert_has(anims, ArmAnimations.attack_for(item.id))
			assert_has(anims, ArmAnimations.shoot_for(item.id))
			assert_has(anims, ArmAnimations.reload_for(item.id))
		if item.category == ItemData.CATEGORY_CONSUMABLE:
			assert_has(anims, ArmAnimations.heal_for(item.id))
	assert_eq(ArmAnimations.attack_for("knife"), "stab")
	assert_eq(ArmAnimations.attack_for("bat"), "swing")
	assert_eq(ArmAnimations.attack_for("extinguisher"), "push")
	assert_eq(ArmAnimations.shoot_for("shotgun"), "shoot_shotgun")
	assert_eq(ArmAnimations.heal_for("neutrax"), "heal_inject")
	assert_eq(ArmAnimations.heal_for("bandage"), "heal_wrap")
	assert_eq(ArmAnimations.craft_for("bat", "nails"), "craft_join")
	assert_eq(ArmAnimations.craft_for("pipe", "rag"), "craft_wrap")
	assert_eq(ArmAnimations.craft_for("phone_board", "phone_battery"), "craft_assemble")
	assert_true(ArmAnimations.is_loop("craft_wrap"))
	assert_eq(
		ArmAnimations.craft_hands("tape", "pipe"),
		["pipe", "tape"] as Array[String],
		"la cinta a la derecha"
	)
	assert_eq(ArmAnimations.craft_hands("bat", "nails"), ["bat", "nails"] as Array[String])
	assert_eq(
		ArmAnimations.craft_hands("phone_board", "phone_battery"),
		["phone_board", "phone_battery"] as Array[String]
	)
	assert_false(ArmAnimations.is_loop("swing"))


## El esqueleto se monta, una acción se reproduce y termina sola, y combinar dura hasta que
## se para.
func test_player_arms_play_and_finish_actions() -> void:
	var arms := PlayerArms.new()
	add_child_autofree(arms)
	var data := GameState.CATALOG.item_catalog().get_item("bat")
	arms.show_weapon(ItemStack.new(data))
	arms.play_attack(0.5)
	assert_eq(arms.current_action(), "swing")
	for i: int in 40:
		arms._process(0.02)
	assert_eq(arms.current_action(), "", "el golpe debería haber terminado")
	arms.start_craft("bat", "nails")
	for i: int in 200:
		arms._process(0.02)
	assert_eq(arms.current_action(), "craft_join")
	arms.stop_craft()
	assert_eq(arms.current_action(), "")


## La pose de vista previa mueve de verdad los huesos (la muñeca derecha cambia de sitio).
func test_preview_moves_the_bones() -> void:
	var arms := PlayerArms.new()
	add_child_autofree(arms)
	var wrist: Node3D = arms.get("_bones")["right"]["wrist"]
	arms.preview("idle", 0.0)
	var rest_spot := wrist.global_position
	arms.preview("throw", 0.35)
	assert_gt(wrist.global_position.distance_to(rest_spot), 0.05)


## La mano izquierda solo sale en las acciones en las que trabaja; en reposo, al golpear o al
## disparar la pistola queda fuera de la vista.
func test_left_hand_only_in_actions_that_use_it() -> void:
	for anim: String in ["idle", "walk", "swing", "stab", "bash", "shoot_pistol", "throw", ""]:
		assert_false(ArmAnimations.uses_left_hand(anim), anim)
	for anim: String in ["push", "shoot_shotgun", "reload_pistol", "heal_wrap", "craft_join"]:
		assert_true(ArmAnimations.uses_left_hand(anim), anim)


## Al combinar, los dos objetos llegan de verdad al sitio que marca CraftMotion (las manos se
## juntan delante); al soltar, los brazos vuelven a su pose.
func test_crafting_brings_both_items_together() -> void:
	var arms := PlayerArms.new()
	add_child_autofree(arms)
	for kind: Array in [["tape", "pipe"], ["bat", "nails"], ["phone_board", "phone_battery"]]:
		arms.start_craft(kind[0] as String, kind[1] as String)
		for i: int in 30:
			arms._process(0.02)
		var pose := CraftMotion.pose(arms.current_action(), arms.get("_craft_time") as float)
		for side: String in ["right", "left"]:
			var hold: Node3D = (
				arms.get("_right_hold") if side == "right" else arms.get("_left_hold")
			)
			var item := hold.get_child(hold.get_child_count() - 1) as Node3D
			var wanted: Vector3 = (pose[side] as Dictionary)["point"]
			assert_lt(
				arms.to_local(item.global_position).distance_to(wanted),
				0.02,
				"%s: objeto %s en su sitio" % [arms.current_action(), side]
			)
		var gap := arms.wrist_position("right").distance_to(arms.wrist_position("left"))
		assert_lt(gap, 0.35, "las manos juntas delante")
		arms.stop_craft()
		for i: int in 30:
			arms._process(0.02)
		assert_eq(arms.get("_craft_weight"), 0.0, "vuelve a la pose normal")

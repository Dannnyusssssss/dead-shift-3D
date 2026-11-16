extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Modelos de los enemigos: cada tipo tiene el suyo, con las animaciones que usa EnemyModel, y
## el aspecto responde a lo que hace el enemigo.

const ANIMATIONS: Array[String] = [
	"idle", "walk", "run", "attack", "hit", "hit_head", "stun", "death"
]


func test_every_enemy_has_a_model_with_its_animations() -> void:
	for enemy: EnemyData in GameState.CATALOG.enemies:
		assert_ne(enemy.model_id, "", "sin modelo: " + enemy.id)
		var model := EnemyModel.create(enemy.model_id)
		assert_not_null(model, enemy.id)
		if model == null:
			continue
		add_child_autofree(model)
		var player := model.get("_player") as AnimationPlayer
		assert_not_null(player, enemy.id)
		for anim_name: String in ANIMATIONS:
			assert_true(player.has_animation(anim_name), "%s sin %s" % [enemy.id, anim_name])


func test_model_follows_the_enemy_state() -> void:
	var model := EnemyModel.create("walker")
	add_child_autofree(model)
	model.update(Enemy.STATE_IDLE, 0.0)
	assert_eq(model.current_animation(), "idle")
	model.update(Enemy.STATE_CHASE, 1.5)
	assert_eq(model.current_animation(), "walk")
	model.update(Enemy.STATE_CHASE, 4.0)
	assert_eq(model.current_animation(), "run")
	model.update(Enemy.STATE_ATTACK, 0.0)
	assert_eq(model.current_animation(), "attack")
	model.play_death()
	assert_eq(model.current_animation(), "death")
	# Muerto, ya no cambia aunque se le pida andar.
	model.update(Enemy.STATE_CHASE, 1.5)
	assert_eq(model.current_animation(), "death")


func test_unknown_model_falls_back() -> void:
	assert_null(EnemyModel.create(""))
	assert_null(EnemyModel.create("no_existe"))


## Las piezas colgadas de un hueso quedan donde se pidió (el chaleco sobre el pecho).
func test_attach_to_bone_places_the_piece() -> void:
	var model := EnemyModel.create("police")
	add_child_autofree(model)
	var piece := Node3D.new()
	model.attach_to_bone(piece, "spine_02", Vector3(0.0, 1.25, 0.0))
	var local := model.to_local(piece.global_position)
	assert_almost_eq(local.y, 1.25, 0.3)


## Todos los modelos con esqueleto (enemigos y personas de la intro) miran hacia -Z, como el
## enemigo cuando hace look_at: la punta del pie queda por delante (más negativa en z) que el
## tobillo y el pie izquierdo a la izquierda (x negativa). Antes avanzaban de espaldas.
func test_models_face_minus_z_like_look_at() -> void:
	var paths: Array[String] = []
	for enemy: EnemyData in GameState.CATALOG.enemies:
		paths.append(EnemyModel.FOLDER + enemy.model_id + ".glb")
	for person: String in ["guard", "worker", "worker_f"]:
		paths.append("res://assets/generated/people/%s.glb" % person)
	for path: String in paths:
		var model := EnemyModel.create_from(path)
		assert_not_null(model, path)
		if model == null:
			continue
		add_child_autofree(model)
		var skeleton := model.get("_skeleton") as Skeleton3D
		var to_model := model.global_transform.affine_inverse() * skeleton.global_transform
		var ankle := to_model * skeleton.get_bone_global_rest(skeleton.find_bone("foot_l")).origin
		var toe := (
			to_model * skeleton.get_bone_global_rest(skeleton.find_bone("ball_leaf_l")).origin
		)
		assert_lt(toe.z, ankle.z - 0.1, "la punta del pie mira a -Z: " + path)
		assert_lt(ankle.x, 0.0, "el pie izquierdo queda a la izquierda: " + path)

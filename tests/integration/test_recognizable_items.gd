extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Objetos reconocibles: los contenedores se abren de verdad y sacan lo de dentro con su modelo,
## cada objeto recogido se avisa con icono y nombre, y los objetos sueltos muestran su nombre de
## cerca.

const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")

var _world: Node3D
var _player: Player


func before_each() -> void:
	GameState.start_new_run()
	_world = Node3D.new()
	add_child_autofree(_world)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(shape)
	_world.add_child(ground)
	_player = PLAYER_SCENE.instantiate()
	_world.add_child(_player)


func _pickup(item_id: String, count: int = 1) -> Pickup:
	var pickup := Pickup.new()
	pickup.item_id = item_id
	pickup.count = count
	_world.add_child(pickup)
	return pickup


## Registrar un contenedor lo abre de verdad (tapa, cajón o puerta), saca los objetos con su
## modelo y avisa de cada uno con su id y su cantidad (para el HUD con icono y nombre).
func test_container_opens_reveals_and_reports_each_item() -> void:
	for kind: int in [
		LootContainer.KIND_DRAWER, LootContainer.KIND_REGISTER, LootContainer.KIND_LOCKER
	]:
		var box := LootContainer.new()
		box.kind = kind
		box.contents = PackedStringArray(["neutrax:1", "batteries:2"])
		_world.add_child(box)
		await wait_physics_frames(1)
		var moving := box.find_child("Moving", true, false) as Node3D
		var closed := moving.transform
		var reported: Array[String] = []
		var collect := func(item_id: String, count: int) -> void:
			reported.append("%s:%d" % [item_id, count])
		EventBus.item_obtained.connect(collect)
		box.interact(_player)
		EventBus.item_obtained.disconnect(collect)
		assert_true(box.is_open(), "abierto: tipo %d" % kind)
		assert_eq(reported, ["neutrax:1", "batteries:2"] as Array[String])
		var models := 0
		# Lo que se ve cuelga de un nodo propio (gira hacia la sala; la colisión no).
		for child: Node in moving.get_parent().get_children():
			if child is MeshInstance3D:
				models += 1
		assert_eq(models, 3, "cuerpo y dos objetos asomando: tipo %d" % kind)
		await wait_seconds(0.5)
		assert_false(moving.transform.is_equal_approx(closed), "la parte móvil se movió")
		GameState.player.inventory.remove_count("neutrax", 1)
		GameState.player.inventory.remove_count("batteries", 2)


## Un contenedor ya registrado en otra visita aparece abierto y vacío.
func test_searched_container_appears_open() -> void:
	var box := LootContainer.new()
	box.kind = LootContainer.KIND_LOCKER
	_world.add_child(box)
	await wait_physics_frames(1)
	assert_true(box.is_open())
	assert_eq(box.get_prompt_key(), "")


## Recoger del suelo avisa con id y cantidad, y el aviso del HUD muestra nombre y cantidad.
func test_pickup_reports_to_the_feed() -> void:
	var feed := PickupFeed.new()
	add_child_autofree(feed)
	var pickup := _pickup("nails", 3)
	await wait_physics_frames(1)
	pickup.interact(_player)
	var lines := feed.entries()
	assert_eq(lines.size(), 1)
	assert_true(lines[0].contains(tr("item_nails")) and lines[0].contains("x3"), lines[0])


## El nombre flotante del objeto solo se ve de cerca.
func test_pickup_name_shows_only_up_close() -> void:
	var pickup := _pickup("neutrax")
	pickup.position = Vector3(0.0, 0.0, -2.0)
	await wait_physics_frames(3)
	var label: Label3D = pickup.get("_name_label")
	assert_not_null(label)
	assert_true(label.visible, "a 2 m se lee el nombre")
	pickup.position = Vector3(0.0, 0.0, -12.0)
	await wait_physics_frames(2)
	assert_false(label.visible, "a 12 m no")

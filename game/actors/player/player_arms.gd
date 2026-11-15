class_name PlayerArms
extends Node3D
## Brazos provisionales en primera persona, hechos con cajas, y sus animaciones por código:
## golpear, disparar, recargar y combinar (genérica). El arma en la mano muestra su desgaste
## con grietas en tres pasos; la interfaz muestra además un icono (no solo color).

const REST_POSITION: Vector3 = Vector3(0.0, 0.0, 0.0)
const SKIN_COLOR: Color = Color(0.78, 0.62, 0.5)
const SLEEVE_COLOR: Color = Color(0.16, 0.2, 0.3)
const CRACK_COLOR: Color = Color(0.08, 0.06, 0.05)

## Forma provisional de cada arma: tamaño de la caja, color y desplazamiento en la mano.
const WEAPON_SHAPES: Dictionary = {
	"pistol": [Vector3(0.05, 0.1, 0.22), Color(0.15, 0.15, 0.17), Vector3(0.0, 0.03, -0.08)],
	"pipe": [Vector3(0.04, 0.04, 0.8), Color(0.55, 0.57, 0.6), Vector3(0.0, 0.0, -0.35)],
	"pipe_grip": [Vector3(0.05, 0.05, 0.8), Color(0.45, 0.4, 0.35), Vector3(0.0, 0.0, -0.35)],
	"pipe_nails": [Vector3(0.06, 0.06, 0.8), Color(0.5, 0.52, 0.55), Vector3(0.0, 0.0, -0.35)],
	"bat": [Vector3(0.07, 0.07, 0.85), Color(0.6, 0.42, 0.24), Vector3(0.0, 0.0, -0.38)],
	"bat_nails": [Vector3(0.09, 0.09, 0.85), Color(0.5, 0.36, 0.22), Vector3(0.0, 0.0, -0.38)],
	"knife": [Vector3(0.02, 0.04, 0.3), Color(0.8, 0.82, 0.85), Vector3(0.0, 0.0, -0.14)],
	"extinguisher": [Vector3(0.14, 0.14, 0.42), Color(0.75, 0.12, 0.1), Vector3(0.0, -0.05, -0.18)],
	"shotgun": [Vector3(0.06, 0.09, 0.7), Color(0.22, 0.18, 0.14), Vector3(0.0, 0.03, -0.3)],
}
## Forma de los objetos que no son armas cuando se sostienen al combinar o curarse.
const ITEM_SHAPES: Dictionary = {
	"nails": [Vector3(0.05, 0.03, 0.12), Color(0.6, 0.62, 0.66), Vector3(0.0, 0.0, -0.06)],
	"rag": [Vector3(0.14, 0.02, 0.12), Color(0.85, 0.84, 0.78), Vector3(0.0, 0.0, -0.06)],
	"tape": [Vector3(0.1, 0.1, 0.04), Color(0.55, 0.57, 0.6), Vector3(0.0, 0.02, -0.06)],
	"bottle": [Vector3(0.06, 0.06, 0.2), Color(0.3, 0.55, 0.32), Vector3(0.0, 0.0, -0.1)],
	"bandage": [Vector3(0.07, 0.07, 0.1), Color(0.92, 0.92, 0.88), Vector3(0.0, 0.0, -0.06)],
	"antibiotics": [Vector3(0.05, 0.08, 0.05), Color(0.9, 0.9, 0.85), Vector3(0.0, 0.02, -0.05)],
	"neutrax": [Vector3(0.03, 0.03, 0.11), Color(0.55, 0.75, 0.95), Vector3(0.0, 0.0, -0.06)],
	"improvised_bandage":
	[Vector3(0.09, 0.05, 0.1), Color(0.82, 0.8, 0.72), Vector3(0.0, 0.0, -0.06)],
	"noise_bottle": [Vector3(0.06, 0.06, 0.2), Color(0.42, 0.5, 0.36), Vector3(0.0, 0.0, -0.1)],
}

var _right: Node3D = null
var _left: Node3D = null
var _weapon_holder: Node3D = null
## Lo que sostiene cada mano al combinar o curarse (el arma se guarda mientras tanto).
var _left_hold: Node3D = null
var _right_hold: Node3D = null
var _tween: Tween = null
var _crafting: bool = false


func _ready() -> void:
	position = Vector3(0.0, -0.22, -0.35)
	_right = _make_arm(Vector3(0.22, 0.0, 0.0))
	_left = _make_arm(Vector3(-0.24, -0.02, 0.05))
	_weapon_holder = Node3D.new()
	_weapon_holder.position = Vector3(0.0, 0.05, -0.18)
	_right.add_child(_weapon_holder)
	_left_hold = Node3D.new()
	_left_hold.position = Vector3(0.0, 0.04, -0.16)
	_left.add_child(_left_hold)
	_right_hold = Node3D.new()
	_right_hold.position = Vector3(0.0, 0.04, -0.16)
	_right.add_child(_right_hold)


## Muestra en la mano el arma dada (o ninguna) con su estado de desgaste.
func show_weapon(stack: ItemStack) -> void:
	for child: Node in _weapon_holder.get_children():
		child.queue_free()
	if stack == null:
		return
	var shape: Array = WEAPON_SHAPES.get(
		stack.id(), [Vector3(0.05, 0.05, 0.4), Color.GRAY, Vector3.ZERO]
	)
	var size: Vector3 = shape[0]
	var color: Color = shape[1]
	var offset: Vector3 = shape[2]
	var state := stack.durability.state()
	# El desgaste oscurece y agrieta el arma; el icono del HUD lo dice también con forma.
	var worn := color.darkened(0.15 * state)
	var body := _box(size, worn)
	body.position = offset
	_weapon_holder.add_child(body)
	for index: int in mini(state, 2) * 2:
		var crack := _box(Vector3(size.x * 1.05, size.y * 1.05, 0.015), CRACK_COLOR)
		crack.position = offset + Vector3(0.0, 0.0, size.z * (0.3 - 0.15 * index))
		crack.rotation.z = 0.4 * index
		_weapon_holder.add_child(crack)


## Golpe cuerpo a cuerpo: el brazo derecho barre de derecha a izquierda.
func play_attack(duration: float) -> void:
	_start_tween()
	_tween.tween_property(_right, "rotation", Vector3(-0.3, 0.9, 0.4), duration * 0.35)
	_tween.tween_property(_right, "rotation", Vector3(0.2, -0.6, -0.3), duration * 0.25)
	_tween.tween_property(_right, "rotation", Vector3.ZERO, duration * 0.4)


## Disparo: retroceso corto del brazo derecho.
func play_shoot() -> void:
	_start_tween()
	_tween.tween_property(_right, "position:z", 0.08, 0.05)
	_tween.parallel().tween_property(_right, "rotation:x", 0.25, 0.05)
	_tween.tween_property(_right, "position:z", 0.0, 0.15)
	_tween.parallel().tween_property(_right, "rotation:x", 0.0, 0.15)


## Recarga: baja el arma, la mano izquierda se acerca y vuelve.
func play_reload(duration: float) -> void:
	_start_tween()
	_tween.tween_property(_right, "rotation:x", -0.7, duration * 0.25)
	_tween.parallel().tween_property(
		_left, "position", Vector3(-0.05, -0.1, -0.05), duration * 0.25
	)
	_tween.tween_interval(duration * 0.5)
	_tween.tween_property(_right, "rotation:x", 0.0, duration * 0.25)
	_tween.parallel().tween_property(
		_left, "position", Vector3(-0.24, -0.02, 0.05), duration * 0.25
	)


## Animación genérica de combinar: guarda el arma, cada mano sostiene uno de los objetos y las
## dos se juntan y «envuelven» en bucle.
func start_craft(first_id: String, second_id: String) -> void:
	_crafting = true
	_hold(_left_hold, first_id)
	_hold(_right_hold, second_id)
	_start_tween()
	_tween.set_loops()
	_tween.tween_property(_left, "position", Vector3(-0.06, -0.05, -0.1), 0.35)
	_tween.parallel().tween_property(_right, "position", Vector3(0.06, -0.05, -0.1), 0.35)
	_tween.tween_property(_left, "rotation:z", 0.5, 0.3)
	_tween.tween_property(_left, "rotation:z", -0.3, 0.3)


func stop_craft() -> void:
	if not _crafting:
		return
	_crafting = false
	_release_hands()
	_start_tween()
	_tween.tween_property(_left, "position", Vector3(-0.24, -0.02, 0.05), 0.25)
	_tween.parallel().tween_property(_right, "position", Vector3(0.22, 0.0, 0.0), 0.25)
	_tween.parallel().tween_property(_left, "rotation", Vector3.ZERO, 0.25)


## Animación genérica de curarse: guarda el arma, la mano izquierda sostiene la cura y la
## derecha la aplica.
func start_heal(item_id: String) -> void:
	_crafting = true
	_hold(_left_hold, item_id)
	_start_tween()
	_tween.tween_property(_right, "position", Vector3(0.04, -0.12, -0.08), 0.3)
	_tween.parallel().tween_property(_right, "rotation:x", -0.6, 0.3)
	_tween.tween_property(_left, "position", Vector3(-0.02, -0.08, -0.12), 0.3)
	_tween.tween_property(_left, "rotation:y", 0.8, 0.4)
	_tween.tween_property(_left, "rotation:y", -0.4, 0.4)


func stop_heal() -> void:
	_crafting = false
	_release_hands()
	_start_tween()
	_tween.tween_property(_left, "position", Vector3(-0.24, -0.02, 0.05), 0.25)
	_tween.parallel().tween_property(_right, "position", Vector3(0.22, 0.0, 0.0), 0.25)
	_tween.parallel().tween_property(_left, "rotation", Vector3.ZERO, 0.25)
	_tween.parallel().tween_property(_right, "rotation", Vector3.ZERO, 0.25)


## Pone en una mano la forma de un objeto y esconde el arma.
func _hold(holder: Node3D, item_id: String) -> void:
	for child: Node in holder.get_children():
		child.queue_free()
	_weapon_holder.visible = false
	var shape: Array = ITEM_SHAPES.get(item_id, WEAPON_SHAPES.get(item_id, []))
	if shape.is_empty():
		shape = [Vector3(0.06, 0.06, 0.1), Color.GRAY, Vector3(0.0, 0.0, -0.05)]
	var size: Vector3 = shape[0]
	var color: Color = shape[1]
	var offset: Vector3 = shape[2]
	var body := _box(size, color)
	body.position = offset
	holder.add_child(body)


## Pone el objeto que se va a lanzar en la mano derecha (el arma se guarda).
func hold_for_throw(item_id: String) -> void:
	_hold(_right_hold, item_id)


## Vacía las manos y vuelve a mostrar el arma.
func release_hands() -> void:
	_release_hands()


func _release_hands() -> void:
	for holder: Node3D in [_left_hold, _right_hold]:
		for child: Node in holder.get_children():
			child.queue_free()
	_weapon_holder.visible = true


func _start_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _make_arm(at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	var sleeve := _box(Vector3(0.09, 0.09, 0.32), SLEEVE_COLOR)
	sleeve.position = Vector3(0.0, 0.0, 0.08)
	pivot.add_child(sleeve)
	var hand := _box(Vector3(0.08, 0.06, 0.1), SKIN_COLOR)
	hand.position = Vector3(0.0, 0.0, -0.12)
	pivot.add_child(hand)
	return pivot


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

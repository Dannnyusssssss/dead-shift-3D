class_name FloorExitZone
extends Area3D
## Zona de salida a otro piso. Al entrar el jugador, pide el cambio de piso; si la salida
## necesita una marca del mundo que no está puesta (atajo cerrado desde el otro lado), avisa.

var spec: FloorExit = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = Rules.LAYER_PLAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = spec.size
	shape.shape = box
	shape.position.y = spec.size.y * 0.5
	add_child(shape)
	if not spec.label_key.is_empty():
		var sign := Label3D.new()
		sign.text = tr(spec.label_key)
		sign.font_size = 80
		sign.modulate = Color(0.55, 1.0, 0.6)
		sign.outline_size = 14
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.position = Vector3(0.0, spec.size.y + 0.4, 0.0)
		add_child(sign)
	body_entered.connect(_on_body_entered)


## Verdadero si ahora se puede usar.
func is_open() -> bool:
	return spec.requires_flag.is_empty() or GameState.world.has_flag(spec.requires_flag)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	# Solo cuenta el jugador de este piso: al cambiar de piso, el del piso anterior todavía
	# existe un instante.
	if player == null or player.is_dead() or player.get_parent() != get_parent():
		return
	if not is_open():
		EventBus.user_message.emit(spec.locked_message_key)
		return
	EventBus.floor_change_requested.emit(spec.target_floor, spec.target_exit)

class_name TechNote
extends Interactable
## Nota que se lee (la del técnico, en la tienda de electrónica): una hoja sobre un mostrador.
## Al leerla queda marcado en el mundo que el jugador sabe qué hace falta para el teléfono, y la
## interfaz la muestra. Se puede leer las veces que se quiera; no se recoge.

const PAPER_SIZE: Vector3 = Vector3(0.32, 0.01, 0.42)

## Identificador de la nota (elige su texto en la interfaz).
var note_id: String = ""


func _ready() -> void:
	super._ready()
	prompt_key = "prompt_read_note"
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.9, 0.84)
	# Un poco de brillo propio para que se distinga en las salas oscuras.
	material.emission_enabled = true
	material.emission = Color(0.9, 0.88, 0.8)
	material.emission_energy_multiplier = 0.25
	var mesh := BoxMesh.new()
	mesh.size = PAPER_SIZE
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = PAPER_SIZE.y * 0.5
	add_child(instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.5, 0.8)
	shape.shape = box
	add_child(shape)


func interact(player: Player) -> void:
	GameState.world.set_flag(Discovery.NOTE_FLAG)
	EventBus.note_opened.emit(note_id)
	used.emit(player)

class_name SecurityMonitor
extends Interactable
## Monitores de las cámaras de la sala de seguridad. Al usarlos se abre el visor de cámaras
## (imagen real de cada una) con el informe de cuántos enemigos hay en cada piso (según el
## estado del mundo). Mientras el jugador está en una zona segura, las cámaras avisan además si
## algo se mueve cerca (lo hace Game).

const SIZE: Vector3 = Vector3(1.4, 0.9, 0.5)


func _ready() -> void:
	super._ready()
	prompt_key = "prompt_cameras"
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.13, 0.15)
	material.emission_enabled = true
	material.emission = Color(0.35, 0.55, 0.75)
	material.emission_energy_multiplier = 0.6
	var mesh := BoxMesh.new()
	mesh.size = SIZE
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = 1.0 + SIZE.y * 0.5
	add_child(instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE + Vector3(0.3, 0.6, 0.6)
	shape.shape = box
	shape.position.y = 1.0 + SIZE.y * 0.5
	add_child(shape)


func interact(player: Player) -> void:
	EventBus.cameras_requested.emit()
	used.emit(player)


## Texto con los enemigos que ven las cámaras en cada piso.
static func report() -> String:
	var lines: Array[String] = [TranslationServer.translate("cameras_title")]
	var world := GameState.world
	for floor_data: FloorData in GameState.CATALOG.floors:
		var alive := 0
		var boss_alive := false
		for index: int in floor_data.enemies.size():
			if world.is_killed(floor_data.id, "enemy_%d" % index):
				continue
			if floor_data.enemies[index].enemy.boss != null:
				boss_alive = true
			else:
				alive += 1
		var line := "%s: %d" % [TranslationServer.translate(floor_data.name_key), alive]
		if boss_alive:
			line += " + " + TranslationServer.translate("cameras_boss")
		lines.append(line)
	return "\n".join(lines)

class_name GlassPanes
extends Node3D
## Cristales de los escaparates de una sala. Los paneles enteros se dibujan en una sola malla y
## los trozos de los rotos en otra (dos llamadas de dibujo por sala como mucho); cada panel entero
## tiene su cuerpo de colisión (GlassPane). Romper uno hace mucho ruido, deja trozos en el suelo
## y el hueco abierto, y queda anotado en el estado del mundo: al volver o al cargar la partida
## sigue roto. Los escaparates tienen antepecho, así que la navegación no cambia.

## Se rompió el panel con este índice.
signal pane_broken(index: int)

var floor_id: String = ""
var room_id: String = ""

## Paneles: [centro, tamaño] en coordenadas del padre.
var _panes: Array[Array] = []
var _broken: Dictionary = {}
var _bodies: Dictionary = {}
var _glass: MeshInstance3D = null
var _shards: MeshInstance3D = null


## Añade un panel (antes de build()).
func add_pane(center: Vector3, size: Vector3) -> void:
	_panes.append([center, size])


func pane_count() -> int:
	return _panes.size()


func is_broken(index: int) -> bool:
	return _broken.has(index)


## Crea mallas y colisiones; los paneles que el mundo tiene anotados como rotos salen rotos.
func build() -> void:
	_glass = MeshInstance3D.new()
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glass)
	_shards = MeshInstance3D.new()
	_shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shards)
	for index: int in _panes.size():
		if GameState.world.is_taken(floor_id, GlassShards.key(room_id, index)):
			_broken[index] = true
		else:
			_add_body(index)
	_rebuild()


## Rompe un panel entero: ruido alto, aviso sonoro, trozos y anotación en el mundo. Devuelve
## falso si ya estaba roto o no existe.
func break_pane(index: int) -> bool:
	if index < 0 or index >= _panes.size() or _broken.has(index):
		return false
	_broken[index] = true
	GameState.world.mark_taken(floor_id, GlassShards.key(room_id, index))
	var body: GlassPane = _bodies.get(index)
	if body != null:
		_bodies.erase(index)
		body.queue_free()
	_rebuild()
	var center: Vector3 = _panes[index][0]
	var point := to_global(center)
	NoiseSystem.emit_noise(point, Rules.NOISE_GLASS_BREAK)
	EventBus.sound_cue.emit("cue_glass_break", point)
	pane_broken.emit(index)
	return true


func _add_body(index: int) -> void:
	var body := GlassPane.new()
	body.group = self
	body.index = index
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _panes[index][1]
	shape.shape = box
	body.add_child(shape)
	body.position = _panes[index][0]
	add_child(body)
	_bodies[index] = body


## Rehace las dos mallas: cristal de los enteros y trozos de los rotos.
func _rebuild() -> void:
	var glass_tool := SurfaceTool.new()
	glass_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shard_tool := SurfaceTool.new()
	shard_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_glass := false
	var has_shards := false
	for index: int in _panes.size():
		var center: Vector3 = _panes[index][0]
		var size: Vector3 = _panes[index][1]
		if not _broken.has(index):
			glass_tool.append_from(_box(size), 0, Transform3D(Basis.IDENTITY, center))
			has_glass = true
			continue
		# Los trozos caen al suelo del piso (y = 0 en las coordenadas de la sección).
		var floor_center := Vector3(center.x, 0.0, center.z)
		for shard: Dictionary in GlassShards.layout(floor_center, size, hash(room_id) + index):
			var yaw: float = shard["yaw"]
			var spot: Vector3 = shard["position"]
			var shard_size: Vector3 = shard["size"]
			var xform := Transform3D(Basis(Vector3.UP, yaw), spot)
			shard_tool.append_from(_box(shard_size), 0, xform)
			has_shards = true
	_glass.mesh = _commit(glass_tool, Kit.glass_material()) if has_glass else null
	_shards.mesh = _commit(shard_tool, Kit.shard_material()) if has_shards else null


static func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


static func _commit(tool: SurfaceTool, mat: StandardMaterial3D) -> ArrayMesh:
	tool.set_material(mat)
	tool.generate_normals()
	return tool.commit()

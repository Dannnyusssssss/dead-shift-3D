class_name ItemModels
extends RefCounted
## Modelos de armas y objetos generados por tools/blender/items.py (color de vértice, origen en
## el punto de agarre, apuntando hacia -Z). Las armas tienen tres versiones por desgaste (bueno,
## dañado y crítico); el resto, una. Las mallas se cargan una vez y se comparten.

const FOLDER: String = "res://assets/generated/items/"
## Versiones de desgaste que tiene cada arma (0 = bueno, 1 = dañado, 2 = crítico).
const WEAR_STATES: int = 3

static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D = null
static var _glow_material: StandardMaterial3D = null


## Ruta del modelo de un objeto; las armas eligen la versión de su estado de desgaste.
static func path_for(item_id: String, wear_state: int) -> String:
	var weapon_path := FOLDER + "%s_w%d.glb" % [item_id, clampi(wear_state, 0, WEAR_STATES - 1)]
	if ResourceLoader.exists(weapon_path):
		return weapon_path
	return FOLDER + item_id + ".glb"


## Malla del objeto en ese estado de desgaste, o null si no hay modelo.
static func mesh(item_id: String, wear_state: int = 0) -> Mesh:
	var path := path_for(item_id, wear_state)
	if _meshes.has(path):
		return _meshes[path]
	var found: Mesh = null
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		var root := scene.instantiate()
		var source := Kit._first_mesh(root)
		if source != null:
			found = source.mesh
		root.free()
	_meshes[path] = found
	return found


## Instancia lista para colgar de una mano o del suelo; null si el objeto no tiene modelo.
## glow añade un brillo propio tenue (objetos sueltos: se ven en la oscuridad sin parpadear).
static func instance(item_id: String, wear_state: int = 0, glow: bool = false) -> MeshInstance3D:
	var found := mesh(item_id, wear_state)
	if found == null:
		return null
	var node := MeshInstance3D.new()
	node.mesh = found
	node.material_override = _glow() if glow else _plain()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Instancia de cualquier modelo generado con color de vértice (helicóptero, intro…), por ruta.
static func instance_from_path(path: String) -> MeshInstance3D:
	var found: Mesh = null
	if _meshes.has(path):
		found = _meshes[path]
	elif ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		var root := scene.instantiate()
		var source := Kit._first_mesh(root)
		if source != null:
			found = source.mesh
		root.free()
		_meshes[path] = found
	if found == null:
		return null
	var node := MeshInstance3D.new()
	node.mesh = found
	node.material_override = _plain()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _plain() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		# Los colores del modelo ya están en lineal (glTF).
		_material.vertex_color_is_srgb = false
		_material.roughness = 0.7
	return _material


static func _glow() -> StandardMaterial3D:
	if _glow_material == null:
		_glow_material = _plain().duplicate()
		_glow_material.emission_enabled = true
		_glow_material.emission = Color(0.1, 0.1, 0.09)
	return _glow_material

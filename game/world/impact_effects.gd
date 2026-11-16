class_name ImpactEffects
extends Node3D
## Efectos de impacto 16+: salpicaduras de sangre y manchas en el suelo al golpear o matar a un
## enemigo, chispas o polvo y marcas de bala en las paredes, y escombros al romperse un arma o
## una estantería. Con «Reducir sangre» los golpes a enemigos levantan polvo y no manchan.
## Todo va en tres MultiMesh (partículas, manchas de sangre, marcas): tres llamadas de dibujo
## en total, con topes por calidad (GoreBudget). Las partículas no brillan: nada destella.

## Vida de una partícula, gravedad y velocidad de salida.
const PARTICLE_LIFE: float = 0.7
const GRAVITY: float = 9.0
const SPEED: float = 2.6
const BLOOD_COLOR: Color = Color(0.32, 0.02, 0.02)
const DUST_COLOR: Color = Color(0.55, 0.53, 0.5)
const SPARK_COLOR: Color = Color(0.95, 0.75, 0.4)
const DEBRIS_COLOR: Color = Color(0.42, 0.38, 0.34)
const MARK_COLOR: Color = Color(0.06, 0.06, 0.06)
## Distancia hacia abajo en la que se busca el suelo para la mancha.
const FLOOR_PROBE: float = 3.0

var budget: GoreBudget = null

var _particles: MultiMeshInstance3D = null
var _stains: MultiMeshInstance3D = null
var _marks: MultiMeshInstance3D = null
var _next_mark: int = 0
## Estado de cada partícula: posición, velocidad, vida restante (<= 0 = libre).
var _positions: PackedVector3Array = PackedVector3Array()
var _velocities: PackedVector3Array = PackedVector3Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _counter: int = 0
var _ray: PhysicsRayQueryParameters3D = null


func _ready() -> void:
	budget = GoreBudget.new(Settings.get_int("quality"), Settings.get_bool("reduce_gore"))
	_ray = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, Rules.LAYER_WORLD)
	_particles = _make_multimesh(_particle_mesh(), GoreBudget.MAX_PARTICLES[2], false)
	_stains = _make_multimesh(_stain_mesh(), GoreBudget.MAX_STAINS[2], true)
	_marks = _make_multimesh(_mark_mesh(), GoreBudget.MAX_STAINS[2], true)
	_positions.resize(GoreBudget.MAX_PARTICLES[2])
	_velocities.resize(GoreBudget.MAX_PARTICLES[2])
	_life.resize(GoreBudget.MAX_PARTICLES[2])
	EventBus.enemy_hit.connect(_on_enemy_hit)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.surface_hit.connect(_on_surface_hit)
	EventBus.debris.connect(_on_debris)
	EventBus.settings_changed.connect(_on_settings_changed)


func _process(delta: float) -> void:
	var mm := _particles.multimesh
	var visible_count := 0
	for i: int in _life.size():
		if _life[i] <= 0.0:
			continue
		_life[i] -= delta
		if _life[i] <= 0.0:
			budget.release_particle()
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		_velocities[i] += Vector3.DOWN * GRAVITY * delta
		_positions[i] += _velocities[i] * delta
		var size := 0.05 * clampf(_life[i] / PARTICLE_LIFE, 0.3, 1.0)
		mm.set_instance_transform(
			i, Transform3D(Basis.from_scale(Vector3.ONE * size), _positions[i])
		)
		visible_count += 1
	_particles.visible = visible_count > 0


## Golpe a un enemigo: salpicadura (o polvo) en la dirección del golpe y mancha en el suelo.
func _on_enemy_hit(point: Vector3, direction: Vector3, is_bullet: bool) -> void:
	var burst := GoreBudget.BURST_BULLET if is_bullet else GoreBudget.BURST_MELEE
	_burst(point, direction, burst, budget.flesh_kind())
	if budget.leaves_stain():
		_stain_below(point, 0.35)


func _on_enemy_died(origin: Vector3, _drops: Array[ItemStack]) -> void:
	_burst(origin + Vector3.UP * 0.9, Vector3.UP, GoreBudget.BURST_DEATH, budget.flesh_kind())
	if budget.leaves_stain():
		_stain_below(origin + Vector3.UP * 0.5, 0.9)


## Bala contra una pared o el suelo: chispas o polvo y una marca pegada a la superficie.
func _on_surface_hit(point: Vector3, normal: Vector3) -> void:
	_burst(point + normal * 0.03, normal, GoreBudget.BURST_BULLET, GoreBudget.KIND_DUST)
	if not Settings.get_bool("reduce_flashes"):
		_burst(point + normal * 0.03, normal, 2, GoreBudget.KIND_SPARKS)
	_place_mark(point, normal)


func _on_debris(origin: Vector3) -> void:
	_burst(origin, Vector3.UP, GoreBudget.BURST_DEBRIS, GoreBudget.KIND_DEBRIS)


func _on_settings_changed(key: String) -> void:
	if key == "reduce_gore" or key == "quality":
		budget.reduce_gore = Settings.get_bool("reduce_gore")
		budget.quality = clampi(Settings.get_int("quality"), 0, GoreBudget.MAX_STAINS.size() - 1)
		if budget.reduce_gore:
			# Al activarlo, las manchas que ya había desaparecen.
			for i: int in _stains.multimesh.instance_count:
				_stains.multimesh.set_instance_transform(
					i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
				)


func _burst(origin: Vector3, direction: Vector3, wanted: int, kind: int) -> void:
	var count := budget.reserve_particles(wanted)
	if count == 0:
		return
	var color := _kind_color(kind)
	var forward := direction.normalized() if direction.length() > 0.01 else Vector3.UP
	var mm := _particles.multimesh
	var placed := 0
	for i: int in _life.size():
		if placed >= count:
			break
		if _life[i] > 0.0:
			continue
		_counter += 1
		# Dispersión fija (sin azar): la misma secuencia siempre.
		var spread := Vector3(
			sin(_counter * 12.9898), cos(_counter * 78.233) * 0.5 + 0.6, sin(_counter * 37.719)
		)
		_positions[i] = origin
		_velocities[i] = (
			(forward * 0.7 + spread * 0.6).normalized() * SPEED * (0.6 + 0.4 * absf(spread.x))
		)
		_life[i] = PARTICLE_LIFE * (0.7 + 0.3 * absf(spread.z))
		mm.set_instance_color(i, color)
		placed += 1
	# Lo que no cupo se devuelve al presupuesto.
	for i: int in count - placed:
		budget.release_particle()


func _stain_below(point: Vector3, radius: float) -> void:
	var hit := _cast(point, point + Vector3.DOWN * FLOOR_PROBE)
	if hit.is_empty():
		return
	var spot: Vector3 = hit.get("position", point)
	var slot := budget.next_stain_slot()
	_counter += 1
	var basis := Basis(Vector3.UP, fposmod(_counter * 2.39996, TAU)).scaled(
		Vector3(radius, 1.0, radius * (0.75 + 0.25 * absf(sin(_counter * 1.7))))
	)
	_stains.multimesh.set_instance_transform(slot, Transform3D(basis, spot + Vector3.UP * 0.012))
	_stains.visible = true


func _place_mark(point: Vector3, normal: Vector3) -> void:
	var slot := _next_mark
	_next_mark = (_next_mark + 1) % budget.max_stains()
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.y) > 0.9 else Vector3.UP).normalized()
	var basis := Basis(side, up, side.cross(up)).scaled(Vector3(0.07, 1.0, 0.07))
	_marks.multimesh.set_instance_transform(slot, Transform3D(basis, point + up * 0.006))
	_marks.visible = true


func _cast(from: Vector3, to: Vector3) -> Dictionary:
	_ray.from = from
	_ray.to = to
	return get_world_3d().direct_space_state.intersect_ray(_ray)


func _kind_color(kind: int) -> Color:
	match kind:
		GoreBudget.KIND_BLOOD:
			return BLOOD_COLOR
		GoreBudget.KIND_SPARKS:
			return SPARK_COLOR
		GoreBudget.KIND_DEBRIS:
			return DEBRIS_COLOR
		_:
			return DUST_COLOR


func _make_multimesh(mesh: Mesh, count: int, flat: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not flat
	mm.mesh = mesh
	mm.instance_count = count
	for i: int in count:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	# Los efectos se ven en todo el edificio: sin recorte por caja (las instancias se mueven).
	node.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 200, 400))
	add_child(node)
	return node


static func _particle_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.6
	mesh.material = material
	return mesh


## Mancha de sangre: plano con una forma irregular dibujada por código (siempre la misma).
static func _stain_mesh() -> Mesh:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = _splat_texture()
	material.albedo_color = Color(0.3, 0.02, 0.02, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.35
	mesh.material = material
	return mesh


static func _mark_mesh() -> Mesh:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = _splat_texture()
	material.albedo_color = Color(MARK_COLOR.r, MARK_COLOR.g, MARK_COLOR.b, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	return mesh


## Forma de salpicadura de 64 px: círculo con borde irregular y gotas (alfa), sin azar.
static func _splat_texture() -> ImageTexture:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y: int in size:
		for x: int in size:
			var offset := Vector2(x, y) - center
			var angle := offset.angle()
			var edge := size * (0.3 + 0.06 * sin(angle * 5.0) + 0.04 * sin(angle * 11.0 + 1.3))
			var alpha := clampf((edge - offset.length()) / 3.0, 0.0, 1.0)
			# Gotas sueltas alrededor.
			for drop: int in 6:
				var drop_angle := drop * 1.047 + 0.4
				var drop_center := center + Vector2.from_angle(drop_angle) * size * 0.4
				var drop_alpha := clampf(
					(size * 0.05 - Vector2(x, y).distance_to(drop_center)) / 2.0, 0.0, 1.0
				)
				alpha = maxf(alpha, drop_alpha)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)

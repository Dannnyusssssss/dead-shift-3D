class_name CameraSpots
extends RefCounted
## Cámaras de seguridad del edificio según los datos de los pisos (accesorios KIND_CAMERA), en
## orden de piso y de lista: dónde está cada lente, hacia dónde mira y su nombre. El monitor las
## recorre en círculo. Lógica pura.


## [{"floor_index", "floor_id", "position" (Vector3 del edificio), "yaw" (grados), "name_key"}].
static func from_floors(floors: Array[FloorData]) -> Array[Dictionary]:
	var ordered := floors.duplicate()
	ordered.sort_custom(
		func(a: FloorData, b: FloorData) -> bool: return a.level_index < b.level_index
	)
	var result: Array[Dictionary] = []
	for floor_index: int in ordered.size():
		var floor_data: FloorData = ordered[floor_index]
		for prop: PropSpec in floor_data.props:
			if prop.kind != PropSpec.KIND_CAMERA:
				continue
			var spot := {
				"floor_index": floor_index,
				"floor_id": floor_data.id,
				"position": prop.position + Vector3.UP * floor_data.elevation(),
				"yaw": prop.rotation_deg,
				"name_key": prop.text_key,
			}
			result.append(spot)
	return result


## Índice siguiente (step = 1) o anterior (step = -1), dando la vuelta. -1 si no hay cámaras.
static func step(index: int, count: int, direction: int) -> int:
	if count <= 0:
		return -1
	return posmod(index + direction, count)

class_name LeanModifier
extends SkeletonModifier3D
## Inclina hacia delante la columna, el cuello y la cabeza encima de la animación que esté
## sonando (se aplica después de ella). Sirve para el guardia dormido sobre el escritorio en la
## intro: sentado, con el torso y la cabeza caídos hacia la consola. amount va de 0 (erguido) a
## 1 (dormido).

## Hueso -> giro hacia delante (radianes) con amount = 1.
const BONES: Dictionary = {
	"spine_01": 0.2,
	"spine_02": 0.3,
	"spine_03": 0.3,
	"neck_01": 0.35,
	"Head": 0.25,
}
## Eje local de los huesos del esqueleto de UAL alrededor del que se dobla hacia delante.
const AXIS: Vector3 = Vector3.RIGHT

var amount: float = 0.0


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or amount <= 0.0:
		return
	for bone_name: String in BONES:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			continue
		var angle: float = BONES[bone_name]
		var pose := skeleton.get_bone_pose_rotation(index)
		skeleton.set_bone_pose_rotation(index, pose * Quaternion(AXIS, angle * amount))

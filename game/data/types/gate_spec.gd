class_name GateSpec
extends Resource
## Reja que bloquea el paso hasta abrirla. Puede pedir un objeto clave (una llave) y, al
## abrirse, pone una marca del mundo (para atajos que se abren desde un solo lado).

@export var id: String = ""
## Centro (a ras de suelo), tamaño y giro en grados.
@export var position: Vector3 = Vector3.ZERO
@export var size: Vector3 = Vector3(1.8, 2.4, 0.15)
@export var rotation_deg: float = 0.0
## Objeto clave necesario ("" = se abre sin llave).
@export var required_item: String = ""
## Marca del mundo que pone al abrirse; si ya está puesta, la reja empieza abierta.
@export var flag: String = ""

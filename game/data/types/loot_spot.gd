class_name LootSpot
extends Resource
## Un punto de botín dentro de una sala: un objeto suelto o un contenedor con contenido.

const KIND_PICKUP: int = -1

## -1 = objeto suelto; si no, tipo de contenedor (LootContainer.KIND_*).
@export var kind: int = KIND_PICKUP
## Posición relativa a la esquina de la sala.
@export var position: Vector3 = Vector3.ZERO
## Giro en grados sobre el eje vertical.
@export var rotation_deg: float = 0.0
## Objeto suelto: identificador, cantidad y desgaste inicial.
@export var item_id: String = ""
@export var count: int = 1
@export var durability: float = 1.0
## Contenedor: lista de "id:cantidad".
@export var contents: PackedStringArray = PackedStringArray()

class_name PropSpec
extends Resource
## Accesorio del piso con función en el juego: estantería que el jefe rompe al embestir,
## tablero eléctrico que lo aturde si choca contra él o monitores de las cámaras.

const KIND_SHELF: int = 0
const KIND_PANEL: int = 1
## Monitores de las cámaras de seguridad (se usan, no bloquean).
const KIND_MONITOR: int = 2

@export var kind: int = KIND_SHELF
## Centro (a ras de suelo), tamaño y giro en grados.
@export var position: Vector3 = Vector3.ZERO
@export var size: Vector3 = Vector3(3.0, 2.2, 0.8)
@export var rotation_deg: float = 0.0

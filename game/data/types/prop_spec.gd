class_name PropSpec
extends Resource
## Accesorio de un piso. Con función en el juego: estantería que el jefe rompe al embestir,
## tablero eléctrico que lo aturde, monitores de las cámaras o una nota que se lee. Decorado:
## bloque sólido (bancos, macetas, mostradores, máquinas…), cristal, rótulo de texto o tramo de
## barandilla.

const KIND_SHELF: int = 0
const KIND_PANEL: int = 1
## Monitores de las cámaras de seguridad (se usan, no bloquean).
const KIND_MONITOR: int = 2
## Bloque sólido de decorado (se funde con la malla de la sala que lo contiene).
const KIND_BLOCK: int = 3
## Rótulo de texto fijo (no gira hacia la cámara); size.x es el ancho aproximado.
const KIND_SIGN: int = 4
## Barandilla de cristal con pasamanos y frente de forjado, de largo size.x.
const KIND_RAIL: int = 5
## Cristal sólido (lucernario, mamparas).
const KIND_GLASS: int = 6
## Nota que se puede leer (text_key = identificador de la nota).
const KIND_NOTE: int = 7
## Cámara de seguridad: position = lente, rotation_deg = hacia dónde mira, text_key = nombre.
## Se ve en los monitores de la sala de seguridad.
const KIND_CAMERA: int = 8
## Modelo de decorado generado en Blender (text_key = nombre del modelo en
## assets/generated/props/); solo visual: su colisión son los bloques collision_only que lo
## acompañan. Se funde con la malla de la sala que lo contiene.
const KIND_MODEL: int = 9

@export var kind: int = KIND_SHELF
## Centro de la base (en coordenadas del piso; y > 0 para lo que no apoya en el suelo),
## tamaño y giro en grados.
@export var position: Vector3 = Vector3.ZERO
@export var size: Vector3 = Vector3(3.0, 2.2, 0.8)
@export var rotation_deg: float = 0.0
## Tono de gris del bloque (1 = blanco, 0 = negro).
@export var shade: float = 0.55
## Clave de texto del rótulo.
@export var text_key: String = ""
## Bloque solo de colisión (invisible): la forma la pone un modelo KIND_MODEL.
@export var collision_only: bool = false

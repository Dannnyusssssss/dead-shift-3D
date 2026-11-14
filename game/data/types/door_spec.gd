class_name DoorSpec
extends Resource
## Abertura de puerta en una pared de una sala.

const SIDE_NORTH: int = 0
const SIDE_SOUTH: int = 1
const SIDE_WEST: int = 2
const SIDE_EAST: int = 3

@export var side: int = SIDE_NORTH
## Distancia desde el inicio de la pared hasta el centro de la puerta.
@export var offset: float = 2.0
@export var width: float = 1.8

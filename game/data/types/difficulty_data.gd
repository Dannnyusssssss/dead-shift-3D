class_name DifficultyData
extends Resource
## Parámetros de una dificultad. Fácil deja todo como está (multiplicadores 1, nada quitado);
## Medio y Difícil endurecen enemigos, recursos, infección, jefe, rescate y oleadas. La lógica
## que los aplica vive en core/difficulty.gd.

@export var id: String = "easy"
## Clave de traducción del nombre y de la descripción corta.
@export var name_key: String = "difficulty_easy"
@export var description_key: String = "difficulty_easy_text"
## Multiplicadores de la vida y del daño de los enemigos normales.
@export var enemy_health_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
## Multiplicador de la munición encontrada (cajones, objetos sueltos y lo que sueltan los
## enemigos). Se redondea hacia abajo, con un mínimo de 1 por punto de botín.
@export var ammo_found_multiplier: float = 1.0
## Objeto escaso y cuántas unidades se quitan por piso (las primeras que aparecen en el orden
## de las salas del piso).
@export var scarce_item_id: String = "bandage"
@export var scarce_removed_per_floor: int = 0
## Multiplicador de la probabilidad de contagio de cada mordida (con tope en 1).
@export var infection_chance_multiplier: float = 1.0
## Multiplicador de la vida del jefe (ambas fases).
@export var boss_health_multiplier: float = 1.0
## Segundos que espera el helicóptero en la azotea.
@export var helicopter_wait_time: float = 75.0
## Multiplicador del tamaño de cada oleada de la azotea (al entero más cercano).
@export var wave_size_multiplier: float = 1.0
## Si se autoguarda al cambiar de piso (si no, solo en las zonas seguras).
@export var autosave_on_floor_change: bool = true

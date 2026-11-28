class_name Rules
extends RefCounted
## Constantes de reglas compartidas por la lógica. Los valores de cada arma, objeto,
## receta y enemigo viven en sus .tres; aquí solo lo que no pertenece a uno en concreto.

## Fracción de durabilidad bajo la cual un arma o chaleco se considera dañado.
const DURABILITY_DAMAGED: float = 0.6
## Fracción bajo la cual está a punto de romperse.
const DURABILITY_CRITICAL: float = 0.25

## Niveles de ruido.
const NOISE_SILENT: int = 0
const NOISE_LOW: int = 1
const NOISE_MEDIUM: int = 2
const NOISE_HIGH: int = 3
const NOISE_VERY_HIGH: int = 4
## Radio en metros a que se oye cada nivel de ruido (índice = nivel).
const NOISE_RADII: Array[float] = [0.0, 4.0, 10.0, 18.0, 30.0]

## Ruido de las acciones del jugador.
const NOISE_WALK: int = NOISE_LOW
const NOISE_SPRINT: int = NOISE_MEDIUM
const NOISE_CROUCH: int = NOISE_SILENT
const NOISE_CRAFT: int = NOISE_MEDIUM
## Ruido al caer un objeto lanzado (intacto) y al romperse uno frágil.
const NOISE_THROW_LAND: int = NOISE_MEDIUM
const NOISE_THROW_BREAK: int = NOISE_HIGH
## Ruido al romperse un cristal de escaparate.
const NOISE_GLASS_BREAK: int = NOISE_HIGH
## Cada pared entre el ruido y quien escucha multiplica el radio por este factor.
const NOISE_WALL_FACTOR: float = 0.5
## Metros de intensidad que pierde por segundo el recuerdo de un ruido.
const NOISE_FORGET_RATE: float = 1.5

## Lanzar objetos: velocidad hacia donde se mira, impulso hacia arriba y espera entre lanzamientos.
const THROW_SPEED: float = 11.0
const THROW_LIFT: float = 2.5
const THROW_COOLDOWN: float = 0.6

## Infección: segundos hasta la conversión.
const INFECTION_TIME: float = 240.0
## Exposición: segundos sin recibir golpes antes de que empiece a bajar y cuánto baja por
## segundo (un golpe de caminante, 0,25, se va en unos 25 s más).
const EXPOSURE_DECAY_DELAY: float = 8.0
const EXPOSURE_DECAY_PER_SECOND: float = 0.01
## Segundos que suman los antibióticos a la cuenta de la infección (sin pasar de la cuenta
## inicial: tomarlos pronto desperdicia parte).
const ANTIBIOTIC_BONUS: float = 90.0

## Teléfono y helicóptero: piezas necesarias, segundos de llegada tras la llamada y de espera en
## la azotea.
const PHONE_PARTS: Array[String] = ["phone_antenna", "phone_battery", "phone_board"]
## Segundos que tarda armar el teléfono (con las manos, como combinar: hace ruido y no se ataca).
const PHONE_ASSEMBLE_TIME: float = 4.0
const HELICOPTER_ARRIVAL_TIME: float = 150.0
const HELICOPTER_WAIT_TIME: float = 75.0

## Linterna: segundos de luz de una carga completa (pilas nuevas).
const FLASHLIGHT_SECONDS: float = 180.0
## Apagón del jefe: segundos que tarda la luz en bajar o volver (siempre suave, sin parpadeos),
## fracción de la luz de cada sala que queda (ninguna: oscuridad total, hace falta la linterna)
## y fracción de la luz ambiente.
const BLACKOUT_FADE: float = 2.5
const BLACKOUT_LIGHT_FACTOR: float = 0.0
const BLACKOUT_AMBIENT_FACTOR: float = 0.06
## Brillo de los paneles y carteles durante el apagón (los carteles de salida se intuyen).
const BLACKOUT_EMISSION_FACTOR: float = 0.12

## Resolución de la imagen de las cámaras de seguridad (baja: se renderiza aparte).
const CAMERA_RESOLUTION: Vector2i = Vector2i(426, 240)

## Zonas de impacto en un enemigo.
const ZONE_BODY: int = 0
const ZONE_VEST: int = 1
const ZONE_HEAD: int = 2
## Multiplicador de daño en la cabeza.
const HEAD_MULTIPLIER: float = 2.0

## Jugador.
const PLAYER_MAX_HEALTH: float = 100.0
const INVENTORY_SLOTS: int = 8
const PLAYER_WALK_SPEED: float = 3.5
const PLAYER_SPRINT_SPEED: float = 5.5
const PLAYER_CROUCH_SPEED: float = 1.8
## Velocidad mientras combina o se cura: puede caminar despacio y mirar, pero no atacar.
const PLAYER_BUSY_SPEED: float = 1.5
const PLAYER_EYE_HEIGHT: float = 1.6
const PLAYER_CROUCH_EYE_HEIGHT: float = 1.0
const PLAYER_INTERACT_RANGE: float = 2.5
## Radianes por píxel de ratón con sensibilidad 1, y por píxel de arrastre táctil.
const LOOK_MOUSE_RADIANS: float = 0.0025
const LOOK_TOUCH_RADIANS: float = 0.006
const LOOK_PITCH_LIMIT_DEG: float = 85.0
## Ayuda de puntería táctil: ángulo máximo (grados) en el que se corrige el disparo.
const AIM_ASSIST_DEGREES: float = 6.0
## Tamaño mínimo de los botones táctiles en píxeles CSS.
const TOUCH_MIN_TARGET_PX: float = 44.0

## Capas de física (bits).
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 4
const LAYER_INTERACTABLE: int = 8
## Rejas y puertas que se abren: bloquean al jugador y a los enemigos, pero no la navegación.
const LAYER_DOOR: int = 16

## Edificio: distancia vertical entre pisos y altura libre de las salas interiores (el resto es
## el forjado). Un punto pertenece al piso cuyo suelo tiene debajo, con margen para las escaleras.
const FLOOR_HEIGHT: float = 5.0
const ROOM_HEIGHT: float = 4.7
const FLOOR_SWITCH_MARGIN: float = 1.5
## Pisos por encima y por debajo del jugador cuyos enemigos y geometría siguen activos.
const ACTIVE_FLOOR_RANGE: int = 1

## Niveles de calidad (índice = SettingsSchema.QUALITY_*: Mínima, Baja, Media y Alta): escala
## de resolución interna 3D y antialiasing (Viewport.MSAA_*). La interfaz siempre se dibuja a
## resolución completa. Medido en el navegador: lo que más cuesta en un equipo sin gráfica
## dedicada son los píxeles iluminados por las luces de sala y las llamadas de dibujo.
const QUALITY_RENDER_SCALE: Array[float] = [0.5, 0.6, 0.8, 1.0]
const QUALITY_MSAA: Array[int] = [0, 0, 0, 1]
## Distancia de visión (m) por calidad: lo que queda más lejos no se dibuja. En Mínima y Baja
## una niebla de profundidad oscurece hasta el color de fondo antes del límite, para que el
## corte no se vea; en Media y Alta queda la niebla suave de siempre.
const QUALITY_VIEW_DISTANCE: Array[float] = [30.0, 45.0, 120.0, 120.0]
const QUALITY_DEPTH_FOG: Array[bool] = [true, true, false, false]
## Distancia (m) a la que se apagan con un fundido las luces de las salas (0 = nunca).
const LIGHT_FADE_DISTANCE: Array[float] = [10.0, 16.0, 28.0, 0.0]
## Distancia (m) a partir de la que no se dibujan las piezas de cada tamaño, por calidad
## (0 = sin límite). Pequeñas: objetos, cajas, monitores, estantes y rótulos pequeños; grandes:
## rejas, cristales y rótulos de tienda. Los enemigos y la estructura se dibujan siempre.
const DRAW_DISTANCE_SMALL: Array[float] = [12.0, 16.0, 24.0, 0.0]
const DRAW_DISTANCE_LARGE: Array[float] = [20.0, 28.0, 40.0, 0.0]

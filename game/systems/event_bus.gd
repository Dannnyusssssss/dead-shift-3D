extends Node
## Bus de señales del juego: los nodos se comunican por aquí, sin buscarse por rutas.
## Las señales se añaden en este único lugar.

## Un ajuste cambió de valor.
@warning_ignore("unused_signal")
signal settings_changed(key: String)
## Mensaje para el jugador, por clave de texto (avisos genéricos de error o de estado).
@warning_ignore("unused_signal")
signal user_message(text_key: String)
## El jugador o el sistema piden pausar (por ejemplo, al perder la captura del puntero).
@warning_ignore("unused_signal")
signal pause_requested
## La pausa cambió.
@warning_ignore("unused_signal")
signal paused_changed(paused: bool)
## Cambió entre controles táctiles y teclado/ratón.
@warning_ignore("unused_signal")
signal input_mode_changed(touch: bool)
## Texto de interacción del objeto apuntado ("" si no hay ninguno) y detalle (qué objeto es).
@warning_ignore("unused_signal")
signal interaction_prompt(text_key: String, detail: String)
## Un golpe o disparo del jugador acertó a un enemigo (para el marcador de impacto).
@warning_ignore("unused_signal")
signal hit_confirmed(killed: bool)

## Un enemigo recibió un golpe en ese punto; direction = hacia dónde salió despedido.
signal enemy_hit(point: Vector3, direction: Vector3, is_bullet: bool)

## Una bala dio en una pared o el suelo (punto y normal de la superficie).
signal surface_hit(point: Vector3, normal: Vector3)

## Algo se rompió en ese punto (arma, estantería): saltan escombros.
signal debris(origin: Vector3)
## Se hizo un ruido en un punto (nivel Rules.NOISE_*).
@warning_ignore("unused_signal")
signal noise_emitted(origin: Vector3, level: int)
## El jugador hizo un ruido (para el indicador de ruido de la interfaz).
@warning_ignore("unused_signal")
signal player_noise(level: int)
## Sonó algo importante en un punto (clave de texto del subtítulo). Lo usan los subtítulos con
## dirección y, desde el Hito 3, el audio.
@warning_ignore("unused_signal")
signal sound_cue(cue_key: String, origin: Vector3)
## Cambió el arma equipada o su estado (desgaste, munición).
@warning_ignore("unused_signal")
signal weapon_changed
## Un arma se rompió.
@warning_ignore("unused_signal")
signal weapon_broken(item_id: String)
## Cambió la salud del jugador.
@warning_ignore("unused_signal")
signal player_health_changed(health: float)
## El jugador recibió daño.
@warning_ignore("unused_signal")
signal player_damaged(amount: float)
## El jugador murió.
@warning_ignore("unused_signal")
signal player_died
## Un enemigo murió y deja este botín en ese punto.
@warning_ignore("unused_signal")
signal enemy_died(origin: Vector3, drops: Array[ItemStack])
## Cambió el estado de la infección (contagio, frenada o curada).
@warning_ignore("unused_signal")
signal infection_changed
## Cambió el chaleco equipado o su desgaste.
@warning_ignore("unused_signal")
signal vest_changed
## Cambió el inventario.
@warning_ignore("unused_signal")
signal inventory_changed
## Empezó o terminó una combinación.
@warning_ignore("unused_signal")
signal crafting_changed(active: bool)
## El jugador pasó a otro piso del edificio (al subir o bajar una escalera, o al empezar).
@warning_ignore("unused_signal")
signal floor_changed(floor_id: String)
## Cambiaron los objetos clave del jugador (llaves, piezas del teléfono).
@warning_ignore("unused_signal")
signal key_items_changed
## Cambió el estado del jefe (vida, fase, combate empezado o terminado).
@warning_ignore("unused_signal")
signal boss_changed
## Cercanía del jefe para el indicador de radiación (0 = lejos, 3 = muy cerca).
@warning_ignore("unused_signal")
signal boss_proximity(level: int)
## Cambió el estado del rescate (llamada, llegada, partida).
@warning_ignore("unused_signal")
signal rescue_changed
## El helicóptero se fue sin el jugador.
@warning_ignore("unused_signal")
signal rescue_lost
## Informe de las cámaras de seguridad (texto ya traducido).
## Se usaron los monitores de seguridad: la interfaz abre las cámaras.
@warning_ignore("unused_signal")
signal cameras_requested
## Las cámaras ven movimiento cerca de la zona segura donde está el jugador.
@warning_ignore("unused_signal")
signal camera_alert(active: bool)

## Se corta (activo) o vuelve la energía del piso que contiene el punto (apagón del jefe).
@warning_ignore("unused_signal")
signal blackout_changed(active: bool, origin: Vector3)

## Se leyó una nota del mundo (la nota del técnico): la interfaz la muestra.
@warning_ignore("unused_signal")
signal note_opened(note_id: String)
## Terminó la partida con un desenlace (RunStats.OUTCOME_*).
@warning_ignore("unused_signal")
signal run_finished(outcome: int)
## El jugador se rinde tras perder el rescate (desde la pausa).
@warning_ignore("unused_signal")
signal surrender_requested
## Un señuelo (botella ruidosa) llama a todos los enemigos cercanos de su piso, oigan o no.
@warning_ignore("unused_signal")
signal lure_pulled(origin: Vector3, radius: float)
## Se recogió un objeto (del suelo o de un contenedor), con su cantidad.
@warning_ignore("unused_signal")
signal item_obtained(item_id: String, count: int)
## El jugador pide volver al menú principal (desde la pausa).
@warning_ignore("unused_signal")
signal main_menu_requested
## El jugador pide guardar a mano (desde la pausa).
@warning_ignore("unused_signal")
signal save_requested
## Se guardó la partida (manual indica si lo pidió el jugador).
@warning_ignore("unused_signal")
signal game_saved(manual: bool)
## El jugador llegó a la meta del nivel.
@warning_ignore("unused_signal")
signal goal_reached
## El jugador soltó una casilla en un punto del mundo.
@warning_ignore("unused_signal")
signal item_dropped(origin: Vector3, stack: ItemStack)

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
## Texto de interacción del objeto apuntado ("" si no hay ninguno).
@warning_ignore("unused_signal")
signal interaction_prompt(text_key: String)
## Se hizo un ruido en un punto (nivel Rules.NOISE_*).
@warning_ignore("unused_signal")
signal noise_emitted(origin: Vector3, level: int)
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
## Cambió el chaleco equipado o su desgaste.
@warning_ignore("unused_signal")
signal vest_changed
## Cambió el inventario.
@warning_ignore("unused_signal")
signal inventory_changed
## Empezó o terminó una combinación.
@warning_ignore("unused_signal")
signal crafting_changed(active: bool)
## El jugador llegó a la meta del nivel.
@warning_ignore("unused_signal")
signal goal_reached
## El jugador soltó una casilla en un punto del mundo.
@warning_ignore("unused_signal")
signal item_dropped(origin: Vector3, stack: ItemStack)

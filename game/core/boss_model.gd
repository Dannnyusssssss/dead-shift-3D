class_name BossModel
extends RefCounted
## Reglas del jefe, El Técnico: dos fases de vida, daño reducido de frente mientras el traje
## está entero, tanque de la espalda como punto débil (y todo golpe cuenta como tanque mientras
## está aturdido), aturdimientos por extintor (con inmunidad posterior), tablero eléctrico o
## choque, y esperas de sus ataques. Lógica pura: la escena decide cuándo pedir cada cosa.

const PHASE_ONE: int = 1
const PHASE_TWO: int = 2

var data: BossData = null
var phase: int = PHASE_ONE
var health: float = 0.0
var stun_left: float = 0.0
## Verdadero durante el fotograma en que cambió de fase (la escena lo consulta y lo limpia).
var phase_changed: bool = false

var _extinguisher_immunity: float = 0.0
var _charge_cooldown: float = 0.0
var _cloud_cooldown: float = 0.0
var _swipe_cooldown: float = 0.0


func _init(boss_data: BossData) -> void:
	data = boss_data
	health = data.phase_one_health
	begin_fight()


## Al empezar (o retomar) el combate: la primera embestida y la primera nube no llegan enseguida.
func begin_fight() -> void:
	_charge_cooldown = maxf(_charge_cooldown, data.charge_cooldown * 0.4)
	_cloud_cooldown = maxf(_cloud_cooldown, data.cloud_cooldown_phase_one * 0.6)


func is_dead() -> bool:
	return phase == PHASE_TWO and health <= 0.0


func is_stunned() -> bool:
	return stun_left > 0.0


## Multiplicador del daño según dónde se golpea.
func damage_multiplier(on_tank: bool) -> float:
	if on_tank or is_stunned():
		return data.tank_multiplier
	if phase == PHASE_ONE:
		return data.phase_one_front_multiplier
	return data.phase_two_front_multiplier


## Aplica un golpe. Devuelve el daño aplicado. Al vaciar la primera fase pasa a la segunda
## (el sobrante se pierde) y queda aturdido un momento.
func take_hit(damage: float, on_tank: bool) -> float:
	if is_dead() or damage <= 0.0:
		return 0.0
	var applied := minf(damage * damage_multiplier(on_tank), health)
	health -= applied
	if health <= 0.0 and phase == PHASE_ONE:
		phase = PHASE_TWO
		health = data.phase_two_health
		phase_changed = true
		stun(data.phase_change_stun)
	return applied


## Aturde durante los segundos dados (si ya estaba aturdido, se queda con el mayor).
func stun(seconds: float) -> void:
	if is_dead():
		return
	stun_left = maxf(stun_left, seconds)


## Golpe de extintor: aturde salvo durante la inmunidad posterior. Devuelve si aturdió.
func stun_by_extinguisher() -> bool:
	if is_dead() or is_stunned() or _extinguisher_immunity > 0.0:
		return false
	stun(data.extinguisher_stun)
	return true


func tick(delta: float) -> void:
	var step := maxf(delta, 0.0)
	if stun_left > 0.0:
		stun_left = maxf(stun_left - step, 0.0)
		if stun_left <= 0.0:
			_extinguisher_immunity = data.extinguisher_immunity
		return
	_extinguisher_immunity = maxf(_extinguisher_immunity - step, 0.0)
	_charge_cooldown = maxf(_charge_cooldown - step, 0.0)
	_cloud_cooldown = maxf(_cloud_cooldown - step, 0.0)
	_swipe_cooldown = maxf(_swipe_cooldown - step, 0.0)


func speed() -> float:
	return data.phase_one_speed if phase == PHASE_ONE else data.phase_two_speed


func can_charge(distance: float) -> bool:
	return (
		not is_stunned()
		and _charge_cooldown <= 0.0
		and distance >= data.charge_min_distance
		and distance <= data.charge_max_distance
	)


func start_charge() -> void:
	_charge_cooldown = data.charge_cooldown


func can_swipe(distance: float) -> bool:
	return not is_stunned() and _swipe_cooldown <= 0.0 and distance <= data.swipe_range


func start_swipe() -> void:
	_swipe_cooldown = data.swipe_cooldown


func can_cloud() -> bool:
	return not is_stunned() and _cloud_cooldown <= 0.0


func start_cloud() -> void:
	_cloud_cooldown = (
		data.cloud_cooldown_phase_one if phase == PHASE_ONE else data.cloud_cooldown_phase_two
	)


func cloud_dps() -> float:
	return data.cloud_dps_phase_one if phase == PHASE_ONE else data.cloud_dps_phase_two


## Fracción de vida de la fase actual (para la barra de la interfaz).
func health_fraction() -> float:
	var full := data.phase_one_health if phase == PHASE_ONE else data.phase_two_health
	return clampf(health / maxf(full, 1.0), 0.0, 1.0)

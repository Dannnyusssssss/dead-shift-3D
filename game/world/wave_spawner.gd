class_name WaveSpawner
extends Node3D
## Oleadas del rescate perdido en la azotea: cada oleada trae más enemigos de comportamiento
## simple (persiguen directo), que aparecen por los bordes. Nunca hay más de un tope de enemigos
## vivos a la vez (menor en celular, por rendimiento). Al limpiar la última oleada, avisa.

signal waves_cleared

const ENEMY_SCENE: PackedScene = preload("res://game/actors/enemies/enemy.tscn")
const WAVE_ENEMY: EnemyData = preload("res://game/data/enemies/wave_walker.tres")
## Enemigos de cada oleada.
const WAVES: Array[int] = [4, 7, 10, 14, 18]
## Tope de enemigos vivos a la vez en PC y en celular.
const CAP_DESKTOP: int = 20
const CAP_TOUCH: int = 12
## Segundos entre apariciones y de respiro entre oleadas.
const SPAWN_INTERVAL: float = 0.8
const WAVE_PAUSE: float = 6.0

var spawn_points: Array[Vector3] = []
var wave: int = 0
var cap: int = CAP_DESKTOP

var _pending: int = 0
var _timer: float = 0.0
var _alive: Array[Enemy] = []
var _spawned_total: int = 0
var _finished: bool = false


func _ready() -> void:
	cap = CAP_TOUCH if Config.is_touch else CAP_DESKTOP
	_start_wave()


## Enemigos de las oleadas que siguen vivos.
func alive_count() -> int:
	_prune()
	return _alive.size()


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_prune()
	_timer -= delta
	if _pending > 0:
		if _timer <= 0.0 and _alive.size() < cap:
			_spawn_one()
			_timer = SPAWN_INTERVAL
		return
	if not _alive.is_empty():
		return
	if wave >= WAVES.size():
		_finished = true
		waves_cleared.emit()
		return
	if _timer <= -WAVE_PAUSE:
		_start_wave()


func _start_wave() -> void:
	_pending = WAVES[wave]
	wave += 1
	_timer = 0.0
	EventBus.user_message.emit("msg_wave_incoming")
	EventBus.sound_cue.emit("cue_horde", global_position)


func _spawn_one() -> void:
	if spawn_points.is_empty():
		_pending = 0
		return
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.data = WAVE_ENEMY
	enemy.rng_seed = 500 + _spawned_total
	enemy.position = spawn_points[_spawned_total % spawn_points.size()]
	get_parent().add_child(enemy)
	_alive.append(enemy)
	_spawned_total += 1
	_pending -= 1


func _prune() -> void:
	for index: int in range(_alive.size() - 1, -1, -1):
		var enemy := _alive[index]
		if not is_instance_valid(enemy) or enemy.is_dead():
			_alive.remove_at(index)

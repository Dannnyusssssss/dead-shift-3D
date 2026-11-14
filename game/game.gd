class_name Game
extends Node
## Partida en curso: carga el piso y monta la interfaz (HUD, táctil, inventario, pausa,
## fin y rendimiento). Termina al morir o al llegar a la escalera.

signal restart_requested

const GROUND_FLOOR: FloorData = preload("res://game/data/floors/ground_floor.tres")

var level: FloorLevel = null
var elapsed: float = 0.0
var finished: bool = false
var won: bool = false

var _end_screen: EndScreen = null


func _ready() -> void:
	GameState.start_new_run()
	level = FloorLevel.new()
	level.name = "Level"
	level.floor_data = GROUND_FLOOR
	add_child(level)
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var hud := Hud.new()
	ui.add_child(hud)
	hud.bind_player(level.player)
	ui.add_child(TouchControls.new())
	var inventory := InventoryPanel.new()
	ui.add_child(inventory)
	inventory.bind_player(level.player)
	ui.add_child(PauseMenu.new())
	_end_screen = EndScreen.new()
	ui.add_child(_end_screen)
	_end_screen.restart_requested.connect(func() -> void: restart_requested.emit())
	ui.add_child(PerfOverlay.new())
	EventBus.player_died.connect(_on_player_died)
	EventBus.goal_reached.connect(_on_goal_reached)
	InputRouter.gameplay_active = true


func _process(delta: float) -> void:
	if not finished and not GameState.paused:
		elapsed += delta


func _on_player_died() -> void:
	_finish(false)


func _on_goal_reached() -> void:
	_finish(true)


func _finish(victory: bool) -> void:
	if finished:
		return
	finished = true
	won = victory
	level.player.set_blocked("finished", true)
	_end_screen.show_result(victory, elapsed)

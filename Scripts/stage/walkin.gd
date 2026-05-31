extends Node2D

## Generic stage for "walk-in" (faceless) clients. It runs, in order, every
## minigame the scheduled day requires (SaveManager.get_day_steps) with no
## special dialogue, then records the day's result and returns to the level
## select. Special clients with their own story get a dedicated stage instead
## (e.g. Scenes/stage/day1.tscn for the Highschool Girl).
##
## The day score (Global.current_day_score) is shared across all of the day's
## minigames, so a bad first client can still sink the whole day — matching the
## GDD's per-day scoring.

var _steps: Array = []
var _step_index: int = 0
var _current_game: Node = null
var _finished: bool = false
var _week: int = 1
var _day: int = 1


func _ready() -> void:
	var cur := SaveManager.get_current()
	_week = cur.x
	_day = cur.y
	_steps = SaveManager.get_day_steps(_week, _day)
	Global.reset_day()
	Global.day_failed.connect(_on_day_failed)
	if _steps.is_empty():
		# Shouldn't happen (the day wouldn't have been launchable), but bail safely.
		_finish_day(false)
		return
	_run_step()


func _run_step() -> void:
	if _step_index >= _steps.size():
		_finish_day(true)
		return
	var step: Dictionary = _steps[_step_index]
	var scene_path: String = SaveManager.GAME_SCENES.get(step.get("game", ""), "")
	var packed := load(scene_path) as PackedScene if scene_path != "" else null
	if packed == null:
		_advance()
		return
	_current_game = packed.instantiate()
	_current_game.difficulty = step.get("difficulty", {})
	_current_game.puzzle_complete.connect(_on_game_complete)
	add_child(_current_game)


func _on_game_complete() -> void:
	if _current_game:
		_current_game.queue_free()
		_current_game = null
	_advance()


func _advance() -> void:
	_step_index += 1
	_run_step()


# Fired by Global.deduct_score when the shared day score hits zero.
func _on_day_failed() -> void:
	if _current_game:
		_current_game.queue_free()
		_current_game = null
	_finish_day(false)


func _finish_day(cleared: bool) -> void:
	if _finished:
		return
	_finished = true
	SaveManager.record_day_result(_week, _day, cleared, Global.current_day_score)
	get_tree().change_scene_to_file("res://Scenes/ui/levels.tscn")

extends Node2D

# Which minigame appears on this day, and how hard it is, are declared centrally
# in SaveManager.DAY_CONFIG (keyed by week/day). This stage just runs the
# dialogue and launches whatever the level data specifies, at that difficulty.

const TIMELINE_HG_WEEK1 := "highschooler_week1"
const TIMELINE_HG_WEEK1_POST := "highschooler_week1_post"

# This stage is Week 1, Day 1.
const WEEK := 1
const DAY := 1

var _current_puzzle: Node = null
var _pending_post_timeline := ""
var _finished := false


func _ready() -> void:
	Global.reset_day()
	# The day is driven by signals from the Dialogic timelines + the puzzle,
	# mirroring the proven flow in Scripts/gym.gd. The day only ends (and is
	# written to the save) once the full diagnosis -> puzzle -> post-dialogue
	# loop resolves, or on a failure.
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Global.day_failed.connect(_on_day_failed)
	Dialogic.start(TIMELINE_HG_WEEK1)


func _on_dialogic_signal(arg: Variant) -> void:
	match str(arg):
		"start_malware_puzzle":
			_pending_post_timeline = TIMELINE_HG_WEEK1_POST
			Dialogic.end_timeline()
			_open_minigame()
		"day_failed":
			Dialogic.end_timeline()
			_finish_day(false)
		"day_complete":
			Dialogic.end_timeline()
			Global.award_week1_payment()
			_finish_day(true)


# Launches the minigame declared for this day (SaveManager.DAY_CONFIG) and hands
# it the day's difficulty values.
func _open_minigame() -> void:
	if _current_puzzle != null:
		return
	var scene_path: String = SaveManager.GAME_SCENES.get(SaveManager.get_day_game(WEEK, DAY), "")
	if scene_path == "":
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	_current_puzzle = packed.instantiate()
	_current_puzzle.difficulty = SaveManager.get_day_difficulty(WEEK, DAY)
	_current_puzzle.puzzle_complete.connect(_on_puzzle_complete)
	add_child(_current_puzzle)


func _on_puzzle_complete() -> void:
	if _current_puzzle:
		_current_puzzle.queue_free()
		_current_puzzle = null
	if _pending_post_timeline.is_empty():
		_finish_day(true)
		return
	var to_start := _pending_post_timeline
	_pending_post_timeline = ""
	Dialogic.start(to_start)


# Fired by Global.deduct_score when the score hits zero (during the puzzle).
func _on_day_failed() -> void:
	if _current_puzzle:
		_current_puzzle.queue_free()
		_current_puzzle = null
	_pending_post_timeline = ""
	_finish_day(false)


# Records the day's result into the save and returns to the level select.
# This is the integration point between gameplay and the save system.
func _finish_day(cleared: bool) -> void:
	if _finished:
		return
	_finished = true
	SaveManager.record_day_result(WEEK, DAY, cleared, Global.current_day_score)
	get_tree().change_scene_to_file("res://Scenes/ui/levels.tscn")

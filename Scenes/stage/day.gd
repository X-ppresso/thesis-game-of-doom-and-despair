extends Node2D

## The single, data-driven stage that runs ANY scheduled day. It reads the day's
## ordered client list from SaveManager.DAY_CONFIG and plays each client in turn:
##
##   * SPECIAL client  -> stage its chibi(s), run its authored diagnosis timeline,
##                        then its puzzle sequence, then its authored post timeline.
##   * FACELESS client -> run the shared walkin diagnosis (its GDD template lines
##                        injected via Global.fc_*), then its puzzle, then the
##                        shared walkin outro.
##
## Both kinds funnel through the same four Dialogic signals, so the flow is uniform:
##   wrong_diagnosis  -> a bad guess (score already docked inside the timeline)
##   start_minigames  -> diagnosis correct: end dialogue, run the client's puzzles
##   client_complete  -> post dialogue done: advance to the next client
##   day_failed       -> ran out of score during diagnosis: fail the day
## A puzzle draining the score to zero fails the day via Global.day_failed instead.
##
## The day score (Global.current_day_score) is shared across every client of the
## day, so a bad early client can still sink it — matching the GDD's per-day scoring.

const CHAR_SCENES := {
	"hg1": "res://Scenes/Characters/hg1.tscn",
	"hg2": "res://Scenes/Characters/hg2.tscn",
	"lk": "res://Scenes/Characters/lk.tscn",
	"ow": "res://Scenes/Characters/ow.tscn",
}
# Where staged chibis stand (left of the MC at the counter). One vs two clients.
const CHAR_POS_SOLO := [Vector2(950, 408)]
const CHAR_POS_PAIR := [Vector2(866, 408), Vector2(1018, 408)]
const CHAR_SCALE := Vector2(5, 5)

const WALKIN_DIAG := "walkin_diagnose"
const WALKIN_POST := "walkin_post"

@onready var chars_container: Node2D = $Characters

var _week := 1
var _day := 1
var _clients: Array = []
var _ci := 0                 # current client index
var _puzzles: Array = []     # current client's [{scene, difficulty}]
var _pi := 0                 # current puzzle index
var _post_timeline := ""
var _current_puzzle: Node = null
var _finished := false


func _ready() -> void:
	var cur := SaveManager.get_current()
	_week = cur.x
	_day = cur.y
	_clients = SaveManager.get_day_clients(_week, _day)
	Global.reset_day()
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Global.day_failed.connect(_on_day_failed)
	if _clients.is_empty():
		_finish_day(false)
		return
	_start_client()


# ------------------------------------------------------------------ per client

func _start_client() -> void:
	if _ci >= _clients.size():
		_finish_day(true)
		return
	var c: Dictionary = _clients[_ci]
	_puzzles = SaveManager.client_puzzle_scenes(c)
	_pi = 0
	if SaveManager.is_special(c):
		_spawn_chars(c.get("chars", []))
		var sp: Dictionary = c.get("special", {})
		_post_timeline = str(sp.get("post", ""))
		Dialogic.start(str(sp.get("diag", "")))
	else:
		Global.set_faceless_clue(c.get("fc", {}))
		_post_timeline = WALKIN_POST
		Dialogic.start(WALKIN_DIAG)


func _on_dialogic_signal(arg: Variant) -> void:
	match str(arg):
		"wrong_diagnosis":
			pass   # score was docked inside the timeline; nothing to do here
		"start_minigames":
			Dialogic.end_timeline()
			_run_next_puzzle()
		"client_complete":
			Dialogic.end_timeline()
			_end_client()
		"day_failed":
			Dialogic.end_timeline()
			_finish_day(false)


# ---------------------------------------------------------------- puzzle chain

func _run_next_puzzle() -> void:
	if _pi >= _puzzles.size():
		# All of this client's puzzles are done -> play its outro dialogue.
		if _post_timeline != "":
			Dialogic.start(_post_timeline)
		else:
			_end_client()
		return
	var step: Dictionary = _puzzles[_pi]
	var packed := load(str(step.get("scene", ""))) as PackedScene
	if packed == null:
		_pi += 1
		_run_next_puzzle()
		return
	_current_puzzle = packed.instantiate()
	_current_puzzle.difficulty = step.get("difficulty", {})
	_current_puzzle.puzzle_complete.connect(_on_puzzle_complete)
	add_child(_current_puzzle)


func _on_puzzle_complete() -> void:
	if _current_puzzle:
		_current_puzzle.queue_free()
		_current_puzzle = null
	_pi += 1
	_run_next_puzzle()


func _end_client() -> void:
	_despawn_chars()
	_ci += 1
	_start_client()


# ------------------------------------------------------------- chibi staging

func _spawn_chars(keys: Array) -> void:
	var positions := CHAR_POS_PAIR if keys.size() >= 2 else CHAR_POS_SOLO
	for i in range(keys.size()):
		var path: String = CHAR_SCENES.get(str(keys[i]), "")
		if path == "":
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var node := packed.instantiate() as Node2D
		node.position = positions[i] if i < positions.size() else positions[positions.size() - 1]
		node.scale = CHAR_SCALE
		chars_container.add_child(node)


func _despawn_chars() -> void:
	for c in chars_container.get_children():
		c.queue_free()


# ------------------------------------------------------------------- failure

# Fired by Global.deduct_score when the shared day score hits zero (in a puzzle).
func _on_day_failed() -> void:
	if _current_puzzle:
		_current_puzzle.queue_free()
		_current_puzzle = null
	_finish_day(false)


func _finish_day(cleared: bool) -> void:
	if _finished:
		return
	_finished = true
	SaveManager.record_day_result(_week, _day, cleared, Global.current_day_score)
	get_tree().change_scene_to_file("res://Scenes/ui/levels.tscn")

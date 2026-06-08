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
## Chibi animation: the MC (baked into the scene) idles facing the door; a special
## client's chibi walks in from the left the first time they speak, then idles
## facing the MC. Whoever is speaking does a small talk-bob each line — driven by
## Dialogic.Text.about_to_show_text (its "character" is the .dch resource, whose
## file basename is the chibi key, e.g. HG.dch -> "HG").

const CHAR_SCENES := {
	"hg1": "res://Scenes/Characters/hg1.tscn",
	"hg2": "res://Scenes/Characters/hg2.tscn",
	"lk": "res://Scenes/Characters/lk.tscn",
	"ow": "res://Scenes/Characters/ow.tscn",
}
# Maps a chibi key to the dialogue character it represents (Dialogic .dch name).
const CHAR_TO_DCH := {"hg1": "HG", "hg2": "HG2", "lk": "LK", "ow": "OW"}
# Where staged chibis come to rest (left of the MC at the counter). One vs two.
const CHAR_POS_SOLO := [Vector2(950, 408)]
const CHAR_POS_PAIR := [Vector2(866, 408), Vector2(1018, 408)]
const CHAR_SCALE := Vector2(5, 5)
const CHIBI_ENTER_X := -140.0   # off-screen left, where a client starts before walking in
const WALKIN_TIME := 1.0
const BOB_PX := 2.5             # talk-bob height in the sprite's local space (x5 on screen)

const WALKIN_DIAG := "walkin_diagnose"
const WALKIN_POST := "walkin_post"

@onready var chars_container: Node2D = $Characters
@onready var mc_chibi: Node2D = $MC

var _week := 1
var _day := 1
var _clients: Array = []
var _ci := 0                 # current client index
var _puzzles: Array = []     # current client's [{scene, difficulty}]
var _pi := 0                 # current puzzle index
var _post_timeline := ""
var _current_puzzle: Node = null
var _finished := false

# Per-client chibi bookkeeping (rebuilt each client; MC persists).
var _chibis := {}            # dch name -> chibi root Node2D
var _entered := {}           # dch name -> bool (has walked in yet)
var _target_pos := {}        # chibi root -> resting Vector2
var _bob_base := {}          # AnimatedSprite2D -> resting offset
var _bob_tween := {}         # AnimatedSprite2D -> active bob Tween


func _ready() -> void:
	var cur := SaveManager.get_current()
	_week = cur.x
	_day = cur.y
	_clients = SaveManager.get_day_clients(_week, _day)
	Global.reset_day()
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.Text.about_to_show_text.connect(_on_about_to_show_text)
	Global.day_failed.connect(_on_day_failed)
	# The MC is always on the counter, facing the door (toward the client).
	_register_chibi("MC", mc_chibi)
	_face(mc_chibi, "idle_left")
	if _clients.is_empty():
		_finish_day(false)
		return
	_start_client()


# ------------------------------------------------------------------ per client

func _start_client() -> void:
	if _ci >= _clients.size():
		_finish_day(true)
		return
	# Reset per-client chibi state (the MC carries over).
	_chibis = {"MC": mc_chibi}
	_entered = {}
	_target_pos = {}
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
		var key := str(keys[i])
		var path: String = CHAR_SCENES.get(key, "")
		if path == "":
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var node := packed.instantiate() as Node2D
		node.scale = CHAR_SCALE
		var target: Vector2 = positions[i] if i < positions.size() else positions[positions.size() - 1]
		node.position = Vector2(CHIBI_ENTER_X, target.y)   # wait off-screen until they speak
		chars_container.add_child(node)
		var dch := str(CHAR_TO_DCH.get(key, key))
		_register_chibi(dch, node)
		_entered[dch] = false
		_target_pos[node] = target
		_face(node, "idle_right")


func _despawn_chars() -> void:
	for c in chars_container.get_children():
		c.queue_free()


# ----------------------------------------------------------- chibi animation

# Talk-bob the speaker each line, and walk a client in the first time they speak.
func _on_about_to_show_text(info: Dictionary) -> void:
	var character = info.get("character")
	if character == null or not (character is Resource):
		return
	var key := String(character.resource_path).get_file().get_basename()
	var root: Node2D = _chibis.get(key)
	if root == null or not is_instance_valid(root):
		return
	if key != "MC" and not bool(_entered.get(key, true)):
		_entered[key] = true
		_walk_in(root)
	else:
		_bob(root)


func _walk_in(root: Node2D) -> void:
	var target: Vector2 = _target_pos.get(root, root.position)
	_face(root, "walk_right")
	var tween := create_tween()
	tween.tween_property(root, "position:x", target.x, WALKIN_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_face.bind(root, "idle_right"))


func _bob(root: Node2D) -> void:
	var spr := _sprite(root)
	if spr == null or not _bob_base.has(spr):
		return
	var base: Vector2 = _bob_base[spr]
	if _bob_tween.has(spr) and is_instance_valid(_bob_tween[spr]):
		_bob_tween[spr].kill()
	spr.offset = base
	var tween := create_tween()
	tween.tween_property(spr, "offset:y", base.y - BOB_PX, 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(spr, "offset:y", base.y, 0.12).set_trans(Tween.TRANS_SINE)
	_bob_tween[spr] = tween


func _register_chibi(dch: String, root: Node2D) -> void:
	_chibis[dch] = root
	var spr := _sprite(root)
	if spr != null:
		_bob_base[spr] = spr.offset


func _face(root: Node2D, anim: String) -> void:
	if not is_instance_valid(root):
		return
	var spr := _sprite(root)
	if spr != null and spr.sprite_frames != null and spr.sprite_frames.has_animation(anim):
		spr.play(anim)


func _sprite(root: Node2D) -> AnimatedSprite2D:
	if not is_instance_valid(root):
		return null
	return root.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


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
	# Clearing the last day of the week opens the weekly score tally first.
	if cleared and _day == SaveManager.DAYS_PER_WEEK:
		Global.last_completed_week = _week
		get_tree().change_scene_to_file("res://Scenes/ui/score_tally.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/ui/levels.tscn")

extends Node

## PvZ-style progress save for "Troubleshooter".
##
## This is intentionally NOT a full game-state snapshot. Like the original
## Plants vs Zombies, we only persist *progress*: which days are cleared/failed,
## the score earned per day, the per-week payment total, and where the player
## should continue from.
##
## Autoloaded as "SaveManager" (see project.godot). Read it from anywhere with
## SaveManager.<method>().

const SAVE_PATH := "user://troubleshooter_save.json"
## Bump this whenever DAY_CONFIG changes shape; older saves are discarded so the
## new schedule's defaults apply (progress is throwaway during development).
const SAVE_VERSION := 2

const TOTAL_WEEKS := 2
const DAYS_PER_WEEK := 5

## Per-day completion status. Derived (not stored) — see get_day_status().
enum Status { LOCKED, AVAILABLE, CLEARED, FAILED }

# ---------------------------------------------------------------- schedule
#
# The whole week-by-week plan from the GDD lives here. This is the single source
# of truth for "what appears which day" that the level select reads. Each day:
#   title       : shown in the level select.
#   clients     : ordered list of who comes in that day. Each client is
#                 { npc, problems:[...], device, game?, difficulty? }.
#                 - npc/problems/device describe the encounter (for display + future).
#                 - game + difficulty are set only on clients whose minigame is
#                   actually built; that is what the stage launches.
#   scene       : the stage scene that runs this day. ONLY days with a scene are
#                 playable; everything else shows as "(soon)" and can't launch.
#
# Right now only the Highschool Girl's 1st encounter (Week 1, Tue) is built, so
# it is the only day with a `scene` and a client `game`. Key format "<week>_<day>"
# with day 1=Mon .. 5=Fri.
const DAY_CONFIG := {
	# ----- Week 1 -----
	"1_1": {
		"title": "Walk-in Client",
		"clients": [{"npc": "Random", "problems": ["bloat"], "device": "pc"}],
	},
	"1_2": {
		"title": "The Highschool Girl",
		"scene": "res://Scenes/stage/day1.tscn",
		"clients": [{
			"npc": "The Highschool Girl",
			"problems": ["malware"],
			"device": "phone",
			"game": "malware_phone",
			"difficulty": {
				"total_objects": 9,
				"bad_objects": 3,
				"good_click_penalty": 5,
				"scan_duration": 1.5,
				"scan_cooldown": 4.0,
			},
		}],
	},
	"1_3": {
		"title": "Walk-in Client",
		"clients": [{"npc": "Random", "problems": ["bloat"], "device": "phone"}],
	},
	"1_4": {
		"title": "The Little Kid",
		"clients": [{"npc": "Little Kid (1st)", "problems": ["system"], "device": "pc"}],
	},
	"1_5": {
		"title": "Walk-in Clients",
		"clients": [
			{"npc": "Random", "problems": ["malware"], "device": "pc"},
			{"npc": "Random", "problems": ["bloat"], "device": "phone"},
		],
	},
	# ----- Week 2 -----
	"2_1": {
		"title": "The Highschool Girls",
		"clients": [
			{"npc": "Highschooler (2nd)", "problems": ["system", "malware"], "device": "phone"},
			{"npc": "Random", "problems": ["system"]},
		],
	},
	"2_2": {
		"title": "Walk-in Clients",
		"clients": [
			{"npc": "Random", "problems": ["bloat"]},
			{"npc": "Random", "problems": ["malware"]},
			{"npc": "Random", "problems": ["bloat"]},
		],
	},
	"2_3": {
		"title": "The Little Kid",
		"clients": [{"npc": "Little Kid (2nd)", "problems": ["malware"], "device": "pc"}],
	},
	# GDD: Thursday of week 2 has no scheduled client.
	"2_4": {
		"title": "Rest Day",
		"clients": [],
	},
	"2_5": {
		"title": "Office Worker & Co.",
		"clients": [
			{"npc": "Random", "problems": []},
			{"npc": "Random", "problems": []},
			{"npc": "The Office Worker", "problems": []},
		],
	},
}

## Maps a minigame id (declared per client above) to the scene that plays it.
## "<game>" = laptop device, "<game>_phone" = same minigame in a phone frame.
const GAME_SCENES := {
	"malware": "res://Scenes/ui/laptop_malware.tscn",
	"malware_phone": "res://Scenes/ui/phone_malware.tscn",
	"bloat": "res://Scenes/ui/laptop_bloat.tscn",
	"bloat_phone": "res://Scenes/ui/phone_bloat.tscn",
}

## Maps a client's *problem* to the base minigame that fixes it. Problems not
## listed here (e.g. "system") have no minigame built yet.
const PROBLEM_GAMES := {
	"bloat": "bloat",
	"malware": "malware",
}

## Generic stage that auto-runs a walk-in day's minigame(s). Used for days made
## up entirely of faceless "Random" clients; special-NPC days get their own scene.
const WALKIN_SCENE := "res://Scenes/stage/walkin.tscn"
const WALKIN_NPC := "Random"

## Per-week money quota target (from the GDD).
const WEEK_QUOTAS := {
	1: 50000,
	2: 200000,
}

var data: Dictionary = {}

signal progress_changed()


func _ready() -> void:
	if has_save():
		load_game()
	else:
		# Keep a valid default in memory so the level select can render before
		# the player has actually started a game. No file is written yet, so
		# Continue stays disabled until New Game is pressed.
		data = _build_new_data()


# ----------------------------------------------------------- schedule helpers

static func _key(week: int, day: int) -> String:
	return "%d_%d" % [week, day]


func _day_config(week: int, day: int) -> Dictionary:
	return DAY_CONFIG.get(_key(week, day), {})


func get_day_title(week: int, day: int) -> String:
	return _day_config(week, day).get("title", "Day %d" % day)


## The stage scene that runs this day:
##  - an explicit "scene" (special-NPC days with their own dialogue), else
##  - the generic walk-in stage if the day is an all-faceless day whose every
##    problem has a built minigame, else
##  - "" (not playable yet -> shown as "soon").
func get_day_scene(week: int, day: int) -> String:
	var explicit: String = _day_config(week, day).get("scene", "")
	if explicit != "":
		return explicit
	if not get_day_steps(week, day).is_empty():
		return WALKIN_SCENE
	return ""


func get_day_clients(week: int, day: int) -> Array:
	return _day_config(week, day).get("clients", [])


## Resolves a (problem, device) pair to a minigame id, or "" if not built.
## device "phone" -> "<game>_phone", anything else -> "<game>".
func _problem_game(problem: String, device: String) -> String:
	var base: String = PROBLEM_GAMES.get(problem, "")
	if base == "":
		return ""
	return base + ("_phone" if device == "phone" else "")


## The minigame ids a single client requires, in order, or [] if any of its
## problems has no built minigame. An explicit "game" id wins (special clients).
func client_games(client: Dictionary) -> Array:
	var explicit: String = client.get("game", "")
	if explicit != "":
		return [explicit]
	var problems: Array = client.get("problems", [])
	if problems.is_empty():
		return []
	var device: String = client.get("device", "pc")
	var games: Array = []
	for p in problems:
		var g := _problem_game(str(p), device)
		if g == "":
			return []   # an unbuilt problem -> this client isn't playable yet
		games.append(g)
	return games


## The ordered list of {game, difficulty} steps that auto-running this day would
## play. Non-empty ONLY when every client is a faceless "Random" walk-in AND each
## of their problems maps to a built minigame. Special-NPC days return [] (they
## need their own dialogue stage), as do days with an unbuilt problem.
func get_day_steps(week: int, day: int) -> Array:
	var clients := get_day_clients(week, day)
	if clients.is_empty():
		return []
	var steps: Array = []
	for c in clients:
		if not (c is Dictionary) or c.get("npc", "") != WALKIN_NPC:
			return []   # a special NPC -> not an auto-run walk-in day
		var games := client_games(c)
		if games.is_empty():
			return []   # unbuilt problem -> day not auto-runnable
		for g in games:
			steps.append({"game": g, "difficulty": c.get("difficulty", {})})
	return steps


# --- single-minigame accessors, used by special stages (e.g. day_1.gd) -------

## The first client of this day with an explicit minigame id, or {}.
func _explicit_client(week: int, day: int) -> Dictionary:
	for c in get_day_clients(week, day):
		if c is Dictionary and c.get("game", "") != "":
			return c
	return {}


## The minigame id a special stage should launch (e.g. "malware_phone"), or "".
func get_day_game(week: int, day: int) -> String:
	return _explicit_client(week, day).get("game", "")


## The difficulty values for that minigame (see DAY_CONFIG), or {}.
func get_day_difficulty(week: int, day: int) -> Dictionary:
	return _explicit_client(week, day).get("difficulty", {})


## A day is "built" (playable) if it resolves to a stage scene.
func is_day_built(week: int, day: int) -> bool:
	return get_day_scene(week, day) != ""


# Built days in schedule order. Used so availability skips over not-yet-built
# days (otherwise the only playable day could be locked behind unbuilt ones).
func _first_built_day() -> Vector2i:
	for w in range(1, TOTAL_WEEKS + 1):
		for d in range(1, DAYS_PER_WEEK + 1):
			if is_day_built(w, d):
				return Vector2i(w, d)
	return Vector2i.ZERO


func _prev_built_day(week: int, day: int) -> Vector2i:
	var last := Vector2i.ZERO
	for w in range(1, TOTAL_WEEKS + 1):
		for d in range(1, DAYS_PER_WEEK + 1):
			if w == week and d == day:
				return last
			if is_day_built(w, d):
				last = Vector2i(w, d)
	return last


# ------------------------------------------------------------------- defaults

func _build_new_data() -> Dictionary:
	var weeks := {}
	for w in range(1, TOTAL_WEEKS + 1):
		var days := {}
		for d in range(1, DAYS_PER_WEEK + 1):
			# We only persist the *result* of each day; availability is derived.
			days[str(d)] = {"result": "", "score": 0}
		weeks[str(w)] = {"payment": 0, "days": days}
	var first := _first_built_day()
	return {
		"version": SAVE_VERSION,
		"current_week": first.x if first != Vector2i.ZERO else 1,
		"current_day": first.y if first != Vector2i.ZERO else 1,
		"weeks": weeks,
	}


# --------------------------------------------------------------- persistence

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func new_game() -> void:
	data = _build_new_data()
	save_game()
	progress_changed.emit()


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open save file for writing: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		data = _build_new_data()
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	# Discard saves that are corrupt or from an older schedule version.
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("weeks") \
			or int(parsed.get("version", 0)) != SAVE_VERSION:
		push_warning("SaveManager: save missing/old/corrupt, starting fresh.")
		data = _build_new_data()
		return false
	data = parsed
	return true


# ------------------------------------------------------------------- queries
# (JSON loads numbers back as floats, so every getter coerces with int().)

func _week_dict(week: int) -> Dictionary:
	var weeks: Dictionary = data.get("weeks", {})
	return weeks.get(str(week), {})


func _day_dict(week: int, day: int) -> Dictionary:
	var days: Dictionary = _week_dict(week).get("days", {})
	return days.get(str(day), {})


func _stored_result(week: int, day: int) -> String:
	return str(_day_dict(week, day).get("result", ""))


## Availability is DERIVED, not stored: an unbuilt day is LOCKED; a day with a
## stored result is CLEARED/FAILED; otherwise it is AVAILABLE once the previous
## built day is cleared (or it is the first built day), else LOCKED.
func get_day_status(week: int, day: int) -> int:
	if not is_day_built(week, day):
		return Status.LOCKED
	match _stored_result(week, day):
		"cleared":
			return Status.CLEARED
		"failed":
			return Status.FAILED
	var prev := _prev_built_day(week, day)
	if prev == Vector2i.ZERO:
		return Status.AVAILABLE
	if _stored_result(prev.x, prev.y) == "cleared":
		return Status.AVAILABLE
	return Status.LOCKED


func get_day_score(week: int, day: int) -> int:
	return int(_day_dict(week, day).get("score", 0))


func get_week_payment(week: int) -> int:
	return int(_week_dict(week).get("payment", 0))


func get_week_quota(week: int) -> int:
	return int(WEEK_QUOTAS.get(week, 0))


func is_day_playable(week: int, day: int) -> bool:
	return is_day_built(week, day) and get_day_status(week, day) != Status.LOCKED


func get_current() -> Vector2i:
	var first := _first_built_day()
	return Vector2i(
		int(data.get("current_week", first.x)),
		int(data.get("current_day", first.y)))


## The first built day the player still has to play (available or previously
## failed). Returns Vector2i.ZERO when everything built has been cleared.
func get_next_unplayed() -> Vector2i:
	for w in range(1, TOTAL_WEEKS + 1):
		for d in range(1, DAYS_PER_WEEK + 1):
			if not is_day_built(w, d):
				continue
			var s := get_day_status(w, d)
			if s == Status.AVAILABLE or s == Status.FAILED:
				return Vector2i(w, d)
	return Vector2i.ZERO


# ------------------------------------------------------------------- mutation

func set_current(week: int, day: int) -> void:
	data["current_week"] = week
	data["current_day"] = day
	save_game()


## Call this when a day finishes. Stores its result/score, recomputes the week
## payment, advances the continue pointer to the next unplayed day, and writes
## the save. (Unlocking is implicit — get_day_status derives it from results.)
func record_day_result(week: int, day: int, cleared: bool, score: int) -> void:
	if not is_day_built(week, day):
		return
	var day_dict := _day_dict(week, day)
	if day_dict.is_empty():
		return
	day_dict["result"] = "cleared" if cleared else "failed"
	if cleared:
		# Keep the best score across retries.
		day_dict["score"] = maxi(int(day_dict.get("score", 0)), score)
	_recompute_week_payment(week)
	var nxt := get_next_unplayed()
	if nxt != Vector2i.ZERO:
		data["current_week"] = nxt.x
		data["current_day"] = nxt.y
	save_game()
	progress_changed.emit()


func _recompute_week_payment(week: int) -> void:
	var total := 0
	for d in range(1, DAYS_PER_WEEK + 1):
		if _stored_result(week, d) == "cleared":
			total += get_day_score(week, d)
	var wd := _week_dict(week)
	if not wd.is_empty():
		wd["payment"] = total

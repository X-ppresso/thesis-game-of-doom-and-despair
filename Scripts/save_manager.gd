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
const SAVE_VERSION := 1

const TOTAL_WEEKS := 2
const DAYS_PER_WEEK := 5

## Per-day completion status. Stored as ints in the save file.
enum Status { LOCKED, AVAILABLE, CLEARED, FAILED }

## Central declaration of what each day is: its stage scene, title, which
## minigame appears, and that game's difficulty values. This is the single place
## the level select uses to decide "what game appears which day" and how hard it
## is. Days not listed here show as "coming soon" and can't be launched yet.
## Key format: "<week>_<day>".
##
## difficulty keys (all optional; missing ones use the game's own defaults):
##   total_objects, bad_objects, good_click_penalty, scan_duration, scan_cooldown
const DAY_CONFIG := {
	"1_1": {
		"title": "The Highschool Girl",
		"scene": "res://Scenes/stage/day1.tscn",
		"game": "malware",
		"difficulty": {
			"total_objects": 13,
			"bad_objects": 3,
			"good_click_penalty": 5,
			"scan_duration": 1.5,
			"scan_cooldown": 4.0,
		},
	},
}

## Maps a minigame id (declared per day above) to the scene that plays it.
const GAME_SCENES := {
	"malware": "res://Scenes/ui/laptop_malware.tscn",
}

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


# ------------------------------------------------------------------- defaults

static func _key(week: int, day: int) -> String:
	return "%d_%d" % [week, day]


func _build_new_data() -> Dictionary:
	var weeks := {}
	for w in range(1, TOTAL_WEEKS + 1):
		var days := {}
		for d in range(1, DAYS_PER_WEEK + 1):
			# The very first day is available from the start; everything else is locked.
			var status: int = Status.AVAILABLE if (w == 1 and d == 1) else Status.LOCKED
			days[str(d)] = {"status": status, "score": 0}
		weeks[str(w)] = {"payment": 0, "days": days}
	return {
		"version": SAVE_VERSION,
		"current_week": 1,
		"current_day": 1,
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
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("weeks"):
		push_warning("SaveManager: save file was corrupt, starting fresh.")
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


func get_day_status(week: int, day: int) -> int:
	return int(_day_dict(week, day).get("status", Status.LOCKED))


func get_day_score(week: int, day: int) -> int:
	return int(_day_dict(week, day).get("score", 0))


func get_week_payment(week: int) -> int:
	return int(_week_dict(week).get("payment", 0))


func get_week_quota(week: int) -> int:
	return int(WEEK_QUOTAS.get(week, 0))


func _day_config(week: int, day: int) -> Dictionary:
	return DAY_CONFIG.get(_key(week, day), {})


func get_day_title(week: int, day: int) -> String:
	return _day_config(week, day).get("title", "Day %d" % day)


func get_day_scene(week: int, day: int) -> String:
	return _day_config(week, day).get("scene", "")


## The minigame id declared for this day (e.g. "malware"), or "" if none.
func get_day_game(week: int, day: int) -> String:
	return _day_config(week, day).get("game", "")


## The difficulty values for this day's minigame (see DAY_CONFIG), or {}.
func get_day_difficulty(week: int, day: int) -> Dictionary:
	return _day_config(week, day).get("difficulty", {})


func is_day_built(week: int, day: int) -> bool:
	return _day_config(week, day).has("scene")


func is_day_playable(week: int, day: int) -> bool:
	return get_day_status(week, day) != Status.LOCKED and is_day_built(week, day)


func get_current() -> Vector2i:
	return Vector2i(int(data.get("current_week", 1)), int(data.get("current_day", 1)))


## The first day the player still has to play (available or previously failed).
## Returns Vector2i.ZERO when everything has been cleared.
func get_next_unplayed() -> Vector2i:
	for w in range(1, TOTAL_WEEKS + 1):
		for d in range(1, DAYS_PER_WEEK + 1):
			var s := get_day_status(w, d)
			if s == Status.AVAILABLE or s == Status.FAILED:
				return Vector2i(w, d)
	return Vector2i.ZERO


# ------------------------------------------------------------------- mutation

func set_current(week: int, day: int) -> void:
	data["current_week"] = week
	data["current_day"] = day
	save_game()


## Call this when a day finishes. Updates its status/score, recomputes the week
## payment, unlocks the next day on a clear, advances the continue pointer, and
## writes the save to disk.
func record_day_result(week: int, day: int, cleared: bool, score: int) -> void:
	var day_dict := _day_dict(week, day)
	if day_dict.is_empty():
		return
	day_dict["status"] = Status.CLEARED if cleared else Status.FAILED
	if cleared:
		# Keep the best score across retries.
		day_dict["score"] = maxi(int(day_dict.get("score", 0)), score)
	_recompute_week_payment(week)
	if cleared:
		_unlock_after(week, day)
		var nxt := get_next_unplayed()
		if nxt != Vector2i.ZERO:
			data["current_week"] = nxt.x
			data["current_day"] = nxt.y
	save_game()
	progress_changed.emit()


func _recompute_week_payment(week: int) -> void:
	var total := 0
	for d in range(1, DAYS_PER_WEEK + 1):
		if get_day_status(week, d) == Status.CLEARED:
			total += get_day_score(week, d)
	var wd := _week_dict(week)
	if not wd.is_empty():
		wd["payment"] = total


func _unlock_after(week: int, day: int) -> void:
	var next_week := week
	var next_day := day + 1
	if next_day > DAYS_PER_WEEK:
		next_week += 1
		next_day = 1
	if next_week > TOTAL_WEEKS:
		return
	if get_day_status(next_week, next_day) == Status.LOCKED:
		var d := _day_dict(next_week, next_day)
		if not d.is_empty():
			d["status"] = Status.AVAILABLE

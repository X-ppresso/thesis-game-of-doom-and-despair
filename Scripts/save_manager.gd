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
const SAVE_VERSION := 3

const TOTAL_WEEKS := 2
const DAYS_PER_WEEK := 5

## Per-day completion status. Derived (not stored) — see get_day_status().
enum Status { LOCKED, AVAILABLE, CLEARED, FAILED }

## Every playable day runs through the one data-driven stage (Scenes/stage/day.gd),
## which reads the day's client list below and plays each client in order — a
## special NPC's authored dialogue + puzzle(s), or a faceless walk-in's template
## diagnosis + puzzle.
const DAY_RUNNER := "res://Scenes/stage/day.tscn"

# ---------------------------------------------------------------- schedule
#
# The whole week-by-week plan from the GDD calendar lives here. Each day has an
# ordered `clients` list. A client is either:
#   * SPECIAL — has "special": {diag, post} (authored timelines) and "chars"
#     (walk-sprite keys to stage). Its `problems` drive the puzzle sequence.
#   * FACELESS — has "fc": {problem, cause_q, cause, answer, success, leave}
#     (GDD template lines) and runs the shared walkin diagnosis before its puzzle.
# Common to both: problems[] (ordered puzzle types), device ("pc"/"phone"), and
# difficulty (a dict for one puzzle, or an array of dicts for a sequence).
# Key format "<week>_<day>" with day 1=Mon .. 5=Fri.
const DAY_CONFIG := {
	# ===================== Week 1 =====================
	"1_1": {
		"title": "Walk-in Client",
		"clients": [
			{"npc": "Random", "problems": ["bloat"], "device": "pc", "fc": {
				"problem": "I wanted to do some work, but I couldn't because the program wouldn't load my file.",
				"cause_q": "Did anything change before that?",
				"cause": "I haven't done anything in particular... but I do have a lot of files from work that I haven't cleaned up.",
				"answer": 1,
				"success": "Thank you!",
				"leave": "I'll take this thing elsewhere, if you don't mind.",
			}},
		],
	},
	"1_2": {
		"title": "The Highschool Girl",
		"clients": [
			{
				"npc": "The Highschool Girl", "problems": ["malware"], "device": "phone",
				"chars": ["hg1"],
				"special": {"diag": "highschooler_week1", "post": "highschooler_week1_post"},
				"difficulty": {
					"total_objects": 9, "bad_objects": 3, "good_click_penalty": 5,
					"scan_duration": 1.5, "scan_cooldown": 4.0,
				},
			},
		],
	},
	"1_3": {
		"title": "Walk-in Client",
		"clients": [
			{"npc": "Random", "problems": ["bloat"], "device": "phone", "fc": {
				"problem": "My storage says it's completely full, but I only have like fifty photos. There's something called 'Other Data' taking up 60GB.",
				"cause_q": "Any idea how that happened?",
				"cause": "Well, my kids like to install video games on my phone... games these days are ridiculous! Back in my day, they weren't even a single MB!",
				"answer": 1,
				"success": "Finally!",
				"leave": "Bah! I'll have it fixed in another place.",
			}},
		],
	},
	"1_4": {
		"title": "The Little Kid",
		"clients": [
			{
				"npc": "The Little Kid", "problems": ["system"], "device": "pc",
				"chars": ["lk"],
				"special": {"diag": "little_kid_week1", "post": "little_kid_week1_post"},
				"difficulty": {
					"total_lanes": 4, "hit_window": 0.13, "miss_penalty": 12, "marker_speed": 0.9,
				},
			},
		],
	},
	"1_5": {
		"title": "Walk-in Clients",
		"clients": [
			{"npc": "Random", "problems": ["malware"], "device": "pc", "fc": {
				"problem": "The laptop is burning hot near the hinges, and the battery drains from 100% to 10% in about forty minutes of just answering emails.",
				"cause_q": "Did you install anything recently?",
				"cause": "I did install some cool software that supposedly helps me answer those emails, but I couldn't figure out how to make it work yet. Nothing happens when I run it.",
				"answer": 0,
				"success": "This is so much better, thank you.",
				"leave": "I'll take this thing elsewhere, if you don't mind.",
			}},
			{"npc": "Random", "problems": ["bloat"], "device": "phone", "fc": {
				"problem": "This little box, the culmination of human intellect, is fully inanimate. Yet its performance has drastically dropped as of late. How vexing.",
				"cause_q": "Do you know anything that might've caused it?",
				"cause": "I have relied on it for a very long time since my arrival here.. Ah- nevermind. Anyway, perhaps it has built up more data than necessary.",
				"answer": 1,
				"success": "Excellent. You have prolonged its days.",
				"leave": "I may not be savvy, but I'm afraid this is going nowhere.",
			}},
		],
	},
	# ===================== Week 2 =====================
	"2_1": {
		"title": "The Highschool Girls",
		"clients": [
			{"npc": "Random", "problems": ["system"], "device": "pc", "fc": {
				"problem": "Y'know, I think I totally like, bricked it or something? This thing can barely turn on before randomly dying off again.",
				"cause_q": "How did you 'brick' it?",
				"cause": "Uuuuuuuuuuuh, drivers. I was updating them, I think.",
				"answer": 2,
				"success": "You're awesome, dude.",
				"leave": "Bro?",
			}},
			{
				"npc": "The Highschool Girls", "problems": ["system", "malware"], "device": "phone",
				"chars": ["hg1", "hg2"],
				"special": {"diag": "highschooler_week2", "post": "highschooler_week2_post"},
				"difficulty": [
					{"total_lanes": 4, "hit_window": 0.11, "miss_penalty": 12, "marker_speed": 1.1},
					{"total_objects": 10, "bad_objects": 4, "good_click_penalty": 6, "scan_duration": 1.2, "scan_cooldown": 4.5},
				],
			},
		],
	},
	"2_2": {
		"title": "Walk-in Clients",
		"clients": [
			{"npc": "Random", "problems": ["bloat"], "device": "pc", "fc": {
				"problem": "It's slow.",
				"cause_q": "Anything you did in particular prior?",
				"cause": "...",
				"answer": 1,
				"success": "...Thanks.",
				"leave": "...tch.",
			}},
			{"npc": "Random", "problems": ["malware"], "device": "pc", "fc": {
				"problem": "Every time I open a browser - doesn't matter which one - I get these aggressive 'System Alert' pop-ups telling me I have 43 viruses.",
				"cause_q": "Any suspect on what caused it?",
				"cause": "I was browsing a streaming site to watch a movie, and I had to click 'Allow' on a few permissions just to get the video player to work.",
				"answer": 0,
				"success": "Thank you!",
				"leave": "That's it, I'm out.",
			}},
			{"npc": "Random", "problems": ["bloat"], "device": "phone", "fc": {
				"problem": "I wanted to play a game but I couldn't install it...",
				"cause_q": "Why couldn't it install?",
				"cause": "It refuses to download because there's no space, but I can't find what's taking all that space.",
				"answer": 1,
				"success": "Much thanks!",
				"leave": "Yikes.",
			}},
		],
	},
	"2_3": {
		"title": "The Little Kid",
		"clients": [
			{
				"npc": "The Little Kid", "problems": ["malware"], "device": "pc",
				"chars": ["lk"],
				"special": {"diag": "little_kid_week2", "post": "little_kid_week2_post"},
				"difficulty": {
					"total_objects": 12, "bad_objects": 4, "good_click_penalty": 6,
					"scan_duration": 1.2, "scan_cooldown": 4.0,
				},
			},
			{"npc": "Random", "problems": ["system"], "device": "phone", "fc": {
				"problem": "I keep getting notifications that 'Goggle Play Services has stopped' every five seconds, and I can't even get into my settings to fix it.",
				"cause_q": "Did you do something before?",
				"cause": "I really didn't do anything, there were only automatic app updates.",
				"answer": 2,
				"success": "Thank you very much!",
				"leave": "I'll take this thing elsewhere, if you don't mind.",
			}},
			{"npc": "Random", "problems": ["system"], "device": "pc", "fc": {
				"problem": "I keep getting these blue screens every twenty minutes. It's completely unpredictable.",
				"cause_q": "Was there anything notable before it?",
				"cause": "I think there was an auto update that happened when I last turned it off before this happened.",
				"answer": 2,
				"success": "Thank you!",
				"leave": "Erm.. I'll just bring it to another place.",
			}},
		],
	},
	"2_4": {
		"title": "Walk-in Clients",
		"clients": [
			{"npc": "Random", "problems": ["bloat"], "device": "phone", "fc": {
				"problem": "I need you to delete stuff from my phone.",
				"cause_q": "Delete what stuff?",
				"cause": "Oh, I just bought this phone and it came with all these pre-installed apps, y'know the ones you can't really uninstall on your own?",
				"answer": 1,
				"success": "Awesome sauce.",
				"leave": "You good? I can come back another day if you're not ready.",
			}},
			{"npc": "Random", "problems": ["malware"], "device": "pc", "fc": {
				"problem": "It takes ten minutes just to reach the login screen. The whole computer just freezes for the first quarter-hour of my day.",
				"cause_q": "Any probable cause?",
				"cause": "I must've downloaded something awful and forgot about it. That, or my brother did - he tends to click on anything even remotely interesting.",
				"answer": 0,
				"success": "Thank you.",
				"leave": "I'll take this thing elsewhere, if you don't mind.",
			}},
			{"npc": "Random", "problems": ["malware"], "device": "phone", "fc": {
				"problem": "The whole thing feels sluggish. It's overheating in my pocket even when I'm not using it, and the camera app takes about ten seconds just to open. It was perfectly fine yesterday!",
				"cause_q": "Did you do something with it before?",
				"cause": "Well, I installed an app that saves battery life because my battery started draining.",
				"answer": 0,
				"success": "Thank you. My goodness.",
				"leave": "You know what? I'll just dump this thing.",
			}},
		],
	},
	"2_5": {
		"title": "The Office Worker",
		"clients": [
			{"npc": "Random", "problems": ["bloat"], "device": "pc", "fc": {
				"problem": "I can't edit my videos, it crashes mid-work with a warning.",
				"cause_q": "What does the warning say?",
				"cause": "The warning? Something about disk space, I'm not sure.",
				"answer": 1,
				"success": "Now I can get back to work.",
				"leave": "I've got a deadline, so.. I think I'll bring it to another place.",
			}},
			{"npc": "Random", "problems": ["system"], "device": "phone", "fc": {
				"problem": "It's stuck on the booting screen...",
				"cause_q": "Did you do anything to it?",
				"cause": "I was trying to jailbreak my phone... for reasons...",
				"answer": 2,
				"success": "Thanks, man.",
				"leave": "Is this thing beyond saving? What a bummer.",
			}},
			{
				"npc": "The Office Worker", "problems": ["bloat", "system"], "device": "pc",
				"chars": ["ow"],
				"special": {"diag": "office_worker_week2", "post": "office_worker_week2_post"},
				"difficulty": [
					{"total_items": 14, "bad_items": 6, "wrong_penalty": 10},
					{"total_lanes": 5, "hit_window": 0.11, "miss_penalty": 12, "marker_speed": 1.1},
				],
			},
		],
	},
}

## Maps a minigame id to the scene that plays it.
## "<game>" = laptop device, "<game>_phone" = same minigame in a phone frame.
const GAME_SCENES := {
	"malware": "res://Scenes/ui/laptop_malware.tscn",
	"malware_phone": "res://Scenes/ui/phone_malware.tscn",
	"bloat": "res://Scenes/ui/laptop_bloat.tscn",
	"bloat_phone": "res://Scenes/ui/phone_bloat.tscn",
	"system": "res://Scenes/ui/laptop_system.tscn",
	"system_phone": "res://Scenes/ui/phone_system.tscn",
}

## Maps a client's *problem* to the base minigame that fixes it.
const PROBLEM_GAMES := {
	"bloat": "bloat",
	"malware": "malware",
	"system": "system",
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


# ----------------------------------------------------------- schedule helpers

static func _key(week: int, day: int) -> String:
	return "%d_%d" % [week, day]


func _day_config(week: int, day: int) -> Dictionary:
	return DAY_CONFIG.get(_key(week, day), {})


func get_day_title(week: int, day: int) -> String:
	return _day_config(week, day).get("title", "Day %d" % day)


func get_day_clients(week: int, day: int) -> Array:
	return _day_config(week, day).get("clients", [])


## True if a client is a special NPC (authored dialogue), false if a faceless walk-in.
static func is_special(client: Dictionary) -> bool:
	return client.has("special")


## Resolves a client's ordered problems to playable puzzle steps:
## [{ "scene": <path>, "difficulty": <dict> }, ...]. A problem with no built
## minigame is skipped (and makes the day "not built" — see is_day_built).
func client_puzzle_scenes(client: Dictionary) -> Array:
	var problems: Array = client.get("problems", [])
	var device: String = client.get("device", "pc")
	var diff: Variant = client.get("difficulty", {})
	var out: Array = []
	for i in range(problems.size()):
		var base: String = PROBLEM_GAMES.get(str(problems[i]), "")
		if base == "":
			continue
		var game_key := base + ("_phone" if device == "phone" else "")
		var scene: String = GAME_SCENES.get(game_key, "")
		if scene == "":
			continue
		var d: Dictionary = {}
		if diff is Array:
			d = diff[i] if i < diff.size() else {}
		elif i == 0 and diff is Dictionary:
			d = diff
		out.append({"scene": scene, "difficulty": d})
	return out


## A day is "built" (playable) if it has clients and every client's every problem
## resolves to a built minigame. Special clients additionally need their authored
## timelines, which are assumed present when they declare a "special" block.
func is_day_built(week: int, day: int) -> bool:
	var clients := get_day_clients(week, day)
	if clients.is_empty():
		return false
	for c in clients:
		if not (c is Dictionary):
			return false
		var problems: Array = c.get("problems", [])
		if client_puzzle_scenes(c).size() != problems.size():
			return false
	return true


## The stage scene that runs this day (the one data-driven runner), or "" if the
## day isn't playable yet.
func get_day_scene(week: int, day: int) -> String:
	return DAY_RUNNER if is_day_built(week, day) else ""


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

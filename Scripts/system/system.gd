class_name SystemPuzzle
extends Node2D

## The system-failure minigame: a Deltarune/Undertale-style timing test (GDD
## "System failure -> Idea 1"). The screen shows several horizontal bars stacked
## top to bottom; each has a target marker (hitline) and a needle that sweeps
## back and forth. The player "reverts" each broken setting by stopping the
## needle on the target, working DOWN the list one bar at a time. A mistimed
## stop bleeds score (like a wrong click in the malware game), so enough bad
## timing fails the day.
##
## The press itself comes from the device's REVERT button (device_system.gd
## wires it to hit()) or the spacebar. Lane geometry is driven entirely by
## `play_rect` (set by the device controller from the device's on-screen rect)
## so it fits any device shape/scale — mirroring how malware/bloat derive their
## play areas.

signal puzzle_complete()

const TEX_BAR := preload("res://sprites/main_ui/gameplay/minigame assets/system_bar.png")
const TEX_NEEDLE := preload("res://sprites/main_ui/gameplay/minigame assets/system_bar_timer_vertical.png")
const TEX_HITLINE := preload("res://sprites/main_ui/gameplay/minigame assets/hitline.png")

const COLOR_ACTIVE := Color(1, 1, 1)
const COLOR_FUTURE := Color(0.5, 0.5, 0.58)
const COLOR_DONE := Color(0.45, 0.85, 0.45)
const COLOR_MISS := Color(0.95, 0.4, 0.4)

@export var total_lanes: int = 4
## Half-width of the acceptable hit zone, as a fraction of the track width.
@export var hit_window: float = 0.12
@export var miss_penalty: int = 10
## Needle traversals (one-way sweeps) per second. Higher = faster = harder.
@export var marker_speed: float = 1.0
## Where the bars are drawn (global coords). Set by the device controller.
@export var play_rect: Rect2 = Rect2(380, 100, 680, 320)

## On-screen height (px) of each bar, and a small lockout after each press so a
## single click can't register twice / mashing can't instantly drain the score.
const LANE_HEIGHT := 18.0
const HIT_LOCKOUT := 0.18

@onready var lanes_container: Node2D = $Lanes
@onready var score_label: Label = $UI/ScoreLabel
@onready var progress_label: Label = $UI/ProgressLabel

# Per lane: { bar, needle, hitline, target_x, left, right, phase, done }
var _lanes: Array = []
var _active: int = 0
var _cooldown: float = 0.0


func _ready() -> void:
	Global.day_score_changed.connect(_on_score_changed)
	_build_lanes()
	_refresh_score()
	_refresh_progress()


func _build_lanes() -> void:
	var n := maxi(1, total_lanes)
	var track_w := play_rect.size.x * 0.82
	var left := play_rect.position.x + (play_rect.size.x - track_w) * 0.5
	var right := left + track_w
	var slot_h := play_rect.size.y / float(n)

	for i in n:
		var cy := play_rect.position.y + slot_h * (float(i) + 0.5)

		var bar := Sprite2D.new()
		bar.texture = TEX_BAR
		bar.position = Vector2((left + right) * 0.5, cy)
		bar.scale = Vector2(track_w / TEX_BAR.get_width(), LANE_HEIGHT / TEX_BAR.get_height())
		lanes_container.add_child(bar)

		# Target sits away from the very edges so the needle always passes over it.
		var target_x := randf_range(left + track_w * 0.2, right - track_w * 0.2)
		var hitline := Sprite2D.new()
		hitline.texture = TEX_HITLINE
		hitline.position = Vector2(target_x, cy)
		hitline.scale = Vector2(6.0 / TEX_HITLINE.get_width(), (LANE_HEIGHT + 12.0) / TEX_HITLINE.get_height())
		lanes_container.add_child(hitline)

		var needle := Sprite2D.new()
		needle.texture = TEX_NEEDLE
		needle.position = Vector2(left, cy)
		needle.scale = Vector2(5.0 / TEX_NEEDLE.get_width(), (LANE_HEIGHT + 6.0) / TEX_NEEDLE.get_height())
		lanes_container.add_child(needle)

		_lanes.append({
			"bar": bar, "needle": needle, "hitline": hitline,
			"target_x": target_x, "left": left, "right": right,
			"phase": randf() * 2.0, "done": false,
		})
	_recolor()


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _active >= _lanes.size():
		return
	var lane: Dictionary = _lanes[_active]
	if lane["done"]:
		return
	# Triangle wave 0->1->0 gives a smooth back-and-forth sweep.
	lane["phase"] = fmod(float(lane["phase"]) + delta * marker_speed, 2.0)
	var t: float = lane["phase"]
	var frac: float = t if t <= 1.0 else 2.0 - t
	(lane["needle"] as Sprite2D).position.x = lerpf(lane["left"], lane["right"], frac)


# Called by the device's REVERT button and the spacebar.
func hit() -> void:
	if _cooldown > 0.0 or _active >= _lanes.size():
		return
	_cooldown = HIT_LOCKOUT
	var lane: Dictionary = _lanes[_active]
	var track_w: float = float(lane["right"]) - float(lane["left"])
	var nx: float = (lane["needle"] as Sprite2D).position.x
	if absf(nx - float(lane["target_x"])) <= hit_window * track_w:
		_lane_cleared(lane)
	else:
		_lane_missed(lane)


func _lane_cleared(lane: Dictionary) -> void:
	lane["done"] = true
	(lane["needle"] as Sprite2D).position.x = lane["target_x"]   # snap onto the target
	_active += 1
	_recolor()
	_refresh_progress()
	if _active >= _lanes.size():
		puzzle_complete.emit()


func _lane_missed(lane: Dictionary) -> void:
	Global.deduct_score(miss_penalty)
	# Brief red flash on the active bar so the miss reads clearly. A node-bound
	# tween is auto-killed if the puzzle is freed (e.g. the day fails on this
	# very deduction), so there's no access-after-free.
	var bar := lane["bar"] as Sprite2D
	bar.modulate = COLOR_MISS
	var tw := create_tween()
	tw.tween_property(bar, "modulate", COLOR_ACTIVE, 0.25)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		hit()
		get_viewport().set_input_as_handled()


func _recolor() -> void:
	for i in _lanes.size():
		var lane: Dictionary = _lanes[i]
		var c := COLOR_FUTURE
		if lane["done"]:
			c = COLOR_DONE
		elif i == _active:
			c = COLOR_ACTIVE
		(lane["bar"] as Sprite2D).modulate = c
		(lane["needle"] as Sprite2D).visible = (i == _active and not bool(lane["done"]))
		(lane["hitline"] as Sprite2D).modulate = COLOR_ACTIVE if i <= _active else COLOR_FUTURE


func _on_score_changed(_new_score: int) -> void:
	_refresh_score()


func _refresh_score() -> void:
	if score_label:
		score_label.text = "Score: %d" % Global.current_day_score


func _refresh_progress() -> void:
	if progress_label:
		progress_label.text = "Reverts left: %d" % maxi(0, _lanes.size() - _active)

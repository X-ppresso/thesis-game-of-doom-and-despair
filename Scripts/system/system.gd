class_name SystemPuzzle
extends Node2D

## The system-failure minigame: a Deltarune/Undertale-style timing test (GDD
## "System failure -> Idea 1"). Several bars; each has a fixed GREEN target marker
## and a WHITE needle that sweeps along it. The player "reverts" each bar by
## stopping the needle on the target, working through them one at a time. A
## mistimed press bleeds score (like a wrong click in the malware game).
##
## Two layouts, set by the device (see `vertical`):
##   * horizontal (phone)  -> bars stacked top-to-bottom, needle sweeps sideways
##   * vertical   (laptop) -> bars side by side, needle sweeps DOWN, left-to-right
## In both, the white needle crosses the track (perpendicular) and the green
## target sits along it. Lane geometry is driven entirely by `play_rect` (set by
## the device from its on-screen screen rect), so it fits any device shape/scale.
##
## The press comes from the device's button (device_system.gd wires it to hit())
## or the spacebar.

signal puzzle_complete()

const TEX_BAR := preload("res://sprites/main_ui/gameplay/minigame assets/system_bar.png")
# Green target markers (sit ALONG the track): horizontal bar uses the 8x1 sliver,
# vertical bar uses the 1x8 sliver.
const TEX_TARGET_H := preload("res://sprites/main_ui/gameplay/minigame assets/system_bar_timer.png")
const TEX_TARGET_V := preload("res://sprites/main_ui/gameplay/minigame assets/system_bar_timer_vertical.png")
# White needle (CROSSES the track, perpendicular): horizontal bar uses the 2x9
# vertical line, vertical bar uses the 9x2 horizontal line.
const TEX_NEEDLE_H := preload("res://sprites/main_ui/gameplay/minigame assets/hitline.png")
const TEX_NEEDLE_V := preload("res://sprites/main_ui/gameplay/minigame assets/hitline_horizontal.png")

const COLOR_TRACK := Color(1, 1, 1)               # system_bar is already dark
const COLOR_TRACK_DONE := Color(0.55, 0.95, 0.6)  # greenish tint once a bar is cleared
const COLOR_TRACK_MISS := Color(1.0, 0.5, 0.5)

# On-screen sizes (global px; play_rect is in screen coords). The bar thickness
# scales with the lane spacing so the big laptop gets chunky bars and the small
# phone gets thin ones; the others are derived from it.
const NEEDLE_THICK := 3.0
const HIT_LOCKOUT := 0.18

@export var total_lanes: int = 5
## Half-width of the acceptable hit zone, as a fraction of the track length.
@export var hit_window: float = 0.12
@export var miss_penalty: int = 10
## Needle traversals (one-way sweeps) per second. Higher = faster = harder.
@export var marker_speed: float = 1.0
## false = horizontal bars (phone); true = vertical bars, needle moves down (laptop).
@export var vertical: bool = false
## Where the bars are drawn (global coords). Set by the device controller.
@export var play_rect: Rect2 = Rect2(380, 100, 680, 320)

@onready var lanes_container: Node2D = $Lanes

# Per lane: { track, target, needle, amin, amax, cross, tval, nav, done, phase }
var _lanes: Array = []
var _active: int = 0
var _cooldown: float = 0.0


func _ready() -> void:
	_build_lanes()


# Maps an along-axis value + a cross-axis value to a screen point for this layout.
func _pos(along: float, cross: float) -> Vector2:
	return Vector2(cross, along) if vertical else Vector2(along, cross)


func _build_lanes() -> void:
	var n := maxi(1, total_lanes)
	# The bars run along one axis; lanes are spread along the other.
	var along_min: float
	var along_max: float
	var cross_step: float
	var cross_start: float
	if vertical:
		along_min = play_rect.position.y
		along_max = play_rect.position.y + play_rect.size.y
		cross_step = play_rect.size.x / float(n)
	else:
		along_min = play_rect.position.x
		along_max = play_rect.position.x + play_rect.size.x
		cross_step = play_rect.size.y / float(n)
	cross_start = (play_rect.position.x if vertical else play_rect.position.y) + cross_step * 0.5
	var length := along_max - along_min
	var track_thick := clampf(cross_step * 0.16, 7.0, 26.0)   # chunkier on the big laptop
	var needle_cross := track_thick + 10.0                    # needle sticks out past the bar
	var target_len := track_thick * 1.25                      # green marker length along the bar

	for i in n:
		var cross := cross_start + cross_step * float(i)

		var track := Sprite2D.new()
		track.texture = TEX_BAR
		track.position = _pos((along_min + along_max) * 0.5, cross)
		if vertical:
			track.rotation = PI * 0.5
		track.scale = Vector2(4.0, 4.0)
		lanes_container.add_child(track)

		var tval := randf_range(along_min + length * 0.18, along_max - length * 0.18)
		var target := Sprite2D.new()
		if vertical:
			target.texture = TEX_TARGET_V
			target.scale = Vector2(4.0, 4.0)
		else:
			target.texture = TEX_TARGET_H
			target.scale = Vector2(4.0, 4.0)
		target.position = _pos(tval, cross)
		lanes_container.add_child(target)

		var needle := Sprite2D.new()
		if vertical:
			needle.texture = TEX_NEEDLE_V
			needle.scale = Vector2(4.0, 4.0)
		else:
			needle.texture = TEX_NEEDLE_H
			needle.scale = Vector2(4.0, 4.0)
		needle.position = _pos(along_min, cross)
		lanes_container.add_child(needle)

		_lanes.append({
			"track": track, "target": target, "needle": needle,
			"amin": along_min, "amax": along_max, "cross": cross,
			"tval": tval, "nav": along_min, "done": false, "phase": randf() * 2.0,
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
	lane["nav"] = lerpf(lane["amin"], lane["amax"], frac)
	(lane["needle"] as Sprite2D).position = _pos(lane["nav"], lane["cross"])


# Called by the device's button and the spacebar.
func hit() -> void:
	if _cooldown > 0.0 or _active >= _lanes.size():
		return
	_cooldown = HIT_LOCKOUT
	var lane: Dictionary = _lanes[_active]
	var rng: float = float(lane["amax"]) - float(lane["amin"])
	if absf(float(lane["nav"]) - float(lane["tval"])) <= hit_window * rng:
		_lane_cleared(lane)
	else:
		_lane_missed(lane)


func _lane_cleared(lane: Dictionary) -> void:
	lane["done"] = true
	(lane["needle"] as Sprite2D).position = _pos(lane["tval"], lane["cross"])   # snap onto target
	_active += 1
	_recolor()
	if _active >= _lanes.size():
		puzzle_complete.emit()


func _lane_missed(lane: Dictionary) -> void:
	Global.deduct_score(miss_penalty)
	# Brief red flash on the active bar. A node-bound tween is auto-killed if the
	# puzzle is freed (e.g. the day fails on this deduction), so no access-after-free.
	var track := lane["track"] as Sprite2D
	track.modulate = COLOR_TRACK_MISS
	var tw := create_tween()
	tw.tween_property(track, "modulate", COLOR_TRACK, 0.25)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		hit()
		get_viewport().set_input_as_handled()


func _recolor() -> void:
	for i in _lanes.size():
		var lane: Dictionary = _lanes[i]
		(lane["track"] as Sprite2D).modulate = COLOR_TRACK_DONE if lane["done"] else COLOR_TRACK
		(lane["needle"] as Sprite2D).visible = (i == _active and not bool(lane["done"]))

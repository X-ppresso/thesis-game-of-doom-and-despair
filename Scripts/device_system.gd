extends Node2D

## The system-failure minigame presented inside a device (laptop or phone) that
## slides up from the bottom of the screen — the mirror of device_malware /
## device_bloat. The device's screen art already carries the title ("Reverting..."
## / "Recovering...") and divider; this only draws the timing bars in the area
## below it and a REVERT button along the bottom of the screen.
##
## The lane area + button are derived at runtime from the screen's on-screen rect
## (pane_fract / button fracts), so they auto-fit any device shape/scale. Laptop
## vs phone differ only in `vertical` + the cloned art, so both share this script.

signal puzzle_complete()

const SYSTEM := preload("res://Scenes/puzzle/system_puzzle/system.tscn")

## Lane area inside the screen, as fractions of the screen's rect (clear of the
## baked title at the top and the button along the bottom).
@export var pane_fract: Rect2 = Rect2(0.08, 0.22, 0.84, 0.56)
## false = horizontal bars (phone); true = vertical bars (laptop).
@export var vertical: bool = false
## Button placement: centre as a fraction of the screen rect, width as a fraction
## of the screen width.
@export var button_center_fract: Vector2 = Vector2(0.5, 0.9)
@export var button_width_fract: float = 0.82

@export var slide_time: float = 0.6
@export var slide_distance: float = 780.0   # how far below the rest position it starts
## Per-day difficulty values (see SaveManager.DAY_CONFIG). Empty = scene defaults.
@export var difficulty: Dictionary = {}

@onready var frame: Node2D = $Frame
@onready var screen: TextureRect = $Frame/Systembg
@onready var button: TextureButton = $Frame/system_button

var _rest_pos: Vector2
var _puzzle: SystemPuzzle = null


func _ready() -> void:
	_rest_pos = frame.position
	frame.position = _rest_pos + Vector2(0, slide_distance)   # start below the screen
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(frame, "position", _rest_pos, slide_time)
	tween.tween_callback(_start_puzzle)


func _start_puzzle() -> void:
	_puzzle = SYSTEM.instantiate() as SystemPuzzle
	_puzzle.vertical = vertical
	_puzzle.play_rect = _content_pane()
	_apply_difficulty()
	add_child(_puzzle)
	_puzzle.puzzle_complete.connect(_on_inner_complete)
	_place_button()
	button.pressed.connect(_puzzle.hit)


# Applies the per-day difficulty to the puzzle; missing keys keep scene defaults.
func _apply_difficulty() -> void:
	if difficulty.is_empty():
		return
	_puzzle.total_lanes = int(difficulty.get("total_lanes", _puzzle.total_lanes))
	_puzzle.hit_window = float(difficulty.get("hit_window", _puzzle.hit_window))
	_puzzle.miss_penalty = int(difficulty.get("miss_penalty", _puzzle.miss_penalty))
	_puzzle.marker_speed = float(difficulty.get("marker_speed", _puzzle.marker_speed))


# Maps the lane pane to global screen coordinates from the screen's actual
# on-screen rect, so it fits any device placement/scale.
func _content_pane() -> Rect2:
	var gr := screen.get_global_rect()
	return Rect2(
		gr.position.x + pane_fract.position.x * gr.size.x,
		gr.position.y + pane_fract.position.y * gr.size.y,
		pane_fract.size.x * gr.size.x,
		pane_fract.size.y * gr.size.y)


# Stretches the REVERT button across the bottom of the screen. The button lives
# under Frame (a scaled Node2D), so we divide out the frame's global scale to hit
# the wanted on-screen size.
func _place_button() -> void:
	var sr := screen.get_global_rect()
	var tex := button.texture_normal
	if tex == null:
		return
	button.scale = Vector2(2.0, 2.0)
	var rendered := tex.get_size() * 2.0   # actual on-screen size
	var center := sr.position + Vector2(button_center_fract.x * sr.size.x, button_center_fract.y * sr.size.y)
	button.global_position = center - rendered * 0.5


func _on_inner_complete() -> void:
	if _puzzle:
		_puzzle.queue_free()
		_puzzle = null
	# Slide the device back down, then report completion to the day.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(frame, "position", _rest_pos + Vector2(0, slide_distance), slide_time)
	tween.tween_callback(func() -> void: puzzle_complete.emit())

extends Node2D

## The system-failure minigame presented inside a device (laptop or phone) that
## slides up from the bottom of the screen — the mirror of device_malware /
## device_bloat. The device frame shows the system screen art; the REVERT button
## baked into the device drives the timing puzzle (SystemPuzzle.hit()).
##
## The puzzle's lane area is derived at runtime from the screen's actual on-screen
## rect (pane_fract), so it auto-fits any device shape/scale. Laptop vs phone
## differ only in the exported knobs below + the cloned art, so both share this
## one script.

signal puzzle_complete()

const SYSTEM := preload("res://Scenes/puzzle/system_puzzle/system.tscn")
const UI_FONT := preload("res://fonts/m3x6.ttf")
const UI_FONT_SIZE := 32

## Lane area inside the screen texture, as fractions of the screen's rect.
## Default = laptop (clear of the title labels on top and the hint at the bottom).
@export var pane_fract: Rect2 = Rect2(0.12, 0.22, 0.76, 0.56)

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
	_puzzle.play_rect = _content_pane()
	_apply_difficulty()
	add_child(_puzzle)
	_puzzle.puzzle_complete.connect(_on_inner_complete)
	button.pressed.connect(_puzzle.hit)
	_layout_ui()


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


# Score + "Reverts left" in the title bar (stacked on a narrow phone screen),
# hint along the bottom. Mirrors device_malware._layout_ui.
func _layout_ui() -> void:
	var sr := screen.get_global_rect()
	var bar_top := sr.position.y + 3.0
	var bar_h := 28.0
	var score := _puzzle.get_node("UI/ScoreLabel") as Label
	var prog := _puzzle.get_node("UI/ProgressLabel") as Label
	var hint := _puzzle.get_node("UI/HintLabel") as Label
	for label: Label in [score, prog]:
		var settings: LabelSettings = label.label_settings.duplicate() if label.label_settings else LabelSettings.new()
		settings.font = UI_FONT
		settings.font_size = UI_FONT_SIZE
		label.label_settings = settings
	var prog_w := UI_FONT.get_string_size(prog.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI_FONT_SIZE).x + 16.0
	var score_w := UI_FONT.get_string_size(score.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI_FONT_SIZE).x + 16.0
	if score_w + prog_w + 40.0 > sr.size.x:
		_place(score, sr.position.x + 12.0, bar_top, sr.size.x - 24.0, bar_h, HORIZONTAL_ALIGNMENT_LEFT)
		_place(prog, sr.position.x + 12.0, bar_top + bar_h, sr.size.x - 24.0, bar_h, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		var prog_x := sr.end.x - 16.0 - prog_w
		var score_x := prog_x - 24.0 - score_w
		_place(score, score_x, bar_top, score_w, bar_h, HORIZONTAL_ALIGNMENT_LEFT)
		_place(prog, prog_x, bar_top, prog_w, bar_h, HORIZONTAL_ALIGNMENT_LEFT)
	# Hint along the bottom of the screen, clear of the bars.
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_place(hint, sr.position.x + 12.0, sr.end.y - 52.0, sr.size.x - 24.0, 46.0, HORIZONTAL_ALIGNMENT_CENTER)


func _place(label: Label, x: float, y: float, w: float, h: float, align: int) -> void:
	label.offset_left = x
	label.offset_top = y
	label.offset_right = x + w
	label.offset_bottom = y + h
	label.horizontal_alignment = align


func _on_inner_complete() -> void:
	if _puzzle:
		_puzzle.queue_free()
		_puzzle = null
	# Slide the device back down, then report completion to the day.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(frame, "position", _rest_pos + Vector2(0, slide_distance), slide_time)
	tween.tween_callback(func() -> void: puzzle_complete.emit())

extends Node2D

## The bloat minigame presented inside a device (laptop or phone) that slides up
## from the bottom of the screen. The device frame is cloned from the matching
## device scene (Laptop.tscn / phone.tscn) showing the bloat elements (Bloatbg +
## Keep/Trash buttons) and hiding the malware ones — the mirror of device_malware.
##
## The puzzle (Scenes/puzzle/bloat_puzzle/bloat.tscn) is spawned once the device
## has slid in, with its card placed to fill the screen's baked card slot. The
## slot is derived at runtime from the screen's on-screen rect, so it auto-fits
## any device shape/scale. Laptop vs phone differ only in the exported knobs + art.

signal puzzle_complete()

const BLOAT := preload("res://Scenes/puzzle/bloat_puzzle/bloat.tscn")
const UI_FONT := preload("res://fonts/m3x6.ttf")
## Sizes to try (largest first) when fitting Score + "Apps left" on one line.
const UI_FONT_SIZES := [32, 28, 24, 20, 18]

## The baked card slot inside the screen texture, as fractions of the screen rect.
## Default = laptop slot (measured from laptop_bloat.png). Phone overrides this.
@export var card_fract: Rect2 = Rect2(0.341, 0.061, 0.318, 0.470)

@export var slide_time: float = 0.6
@export var slide_distance: float = 780.0   # how far below the rest position it starts
## Per-day difficulty values (see SaveManager.DAY_CONFIG). Empty = scene defaults.
@export var difficulty: Dictionary = {}

@onready var frame: Node2D = $Frame
@onready var screen: TextureRect = $Frame/Bloatbg
@onready var keep_button: TextureButton = $Frame/button_keep
@onready var trash_button: TextureButton = $Frame/button_trash

var _rest_pos: Vector2
var _puzzle: BloatPuzzle = null


func _ready() -> void:
	_rest_pos = frame.position
	frame.position = _rest_pos + Vector2(0, slide_distance)   # start below the screen
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(frame, "position", _rest_pos, slide_time)
	tween.tween_callback(_start_puzzle)


func _start_puzzle() -> void:
	_puzzle = BLOAT.instantiate() as BloatPuzzle
	_puzzle.card_rect = _card_rect()
	_apply_difficulty()
	add_child(_puzzle)
	_puzzle.puzzle_complete.connect(_on_inner_complete)
	keep_button.pressed.connect(_puzzle.keep)
	trash_button.pressed.connect(_puzzle.trash)
	_layout_ui()


# Applies the per-day difficulty to the puzzle; missing keys keep scene defaults.
func _apply_difficulty() -> void:
	if difficulty.is_empty():
		return
	_puzzle.total_items = int(difficulty.get("total_items", _puzzle.total_items))
	_puzzle.bad_items = int(difficulty.get("bad_items", _puzzle.bad_items))
	_puzzle.wrong_penalty = int(difficulty.get("wrong_penalty", _puzzle.wrong_penalty))


# Maps the baked card slot to global screen coordinates from the screen's
# on-screen rect, so it fits any device placement/scale.
func _card_rect() -> Rect2:
	var gr := screen.get_global_rect()
	return Rect2(
		gr.position.x + card_fract.position.x * gr.size.x,
		gr.position.y + card_fract.position.y * gr.size.y,
		card_fract.size.x * gr.size.x,
		card_fract.size.y * gr.size.y)


# Score (top-left) + "Apps left" (top-right) on one line in the screen's top
# strip — the font shrinks to whatever fits the device width so they never
# stack or overflow. The hint wraps across the bottom of the screen.
func _layout_ui() -> void:
	var sr := screen.get_global_rect()
	var score := _puzzle.get_node("UI/ScoreLabel") as Label
	var prog := _puzzle.get_node("UI/ProgressLabel") as Label
	var hint := _puzzle.get_node("UI/HintLabel") as Label

	var size := _fit_font_size(score.text, prog.text, sr.size.x - 24.0)
	for label: Label in [score, prog]:
		var settings: LabelSettings = label.label_settings.duplicate() if label.label_settings else LabelSettings.new()
		settings.font = UI_FONT
		settings.font_size = size
		label.label_settings = settings
	var bar_top := sr.position.y + 2.0
	var bar_h := float(size) + 6.0
	var half := sr.size.x * 0.5
	_place(score, sr.position.x + 10.0, bar_top, half - 12.0, bar_h, HORIZONTAL_ALIGNMENT_LEFT)
	_place(prog, sr.position.x + half + 2.0, bar_top, half - 12.0, bar_h, HORIZONTAL_ALIGNMENT_RIGHT)

	# Hint: wrap to as many lines as it needs, hugging the bottom of the screen.
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var hint_h := 96.0
	_place(hint, sr.position.x + 12.0, sr.end.y - hint_h - 6.0, sr.size.x - 24.0, hint_h, HORIZONTAL_ALIGNMENT_CENTER)


# Largest UI_FONT size at which "<score>  <prog>" fits within `max_w`.
func _fit_font_size(score_text: String, prog_text: String, max_w: float) -> int:
	for s: int in UI_FONT_SIZES:
		var w := UI_FONT.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x \
			+ UI_FONT.get_string_size(prog_text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x + 20.0
		if w <= max_w:
			return s
	return UI_FONT_SIZES[UI_FONT_SIZES.size() - 1]


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
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(frame, "position", _rest_pos + Vector2(0, slide_distance), slide_time)
	tween.tween_callback(func() -> void: puzzle_complete.emit())

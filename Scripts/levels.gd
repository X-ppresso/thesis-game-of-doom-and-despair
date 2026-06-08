extends Control

## Level select. The panel art (level_select_box.png) already has the five day
## tabs (Mon..Fri) baked in down the left side, so this script overlays, for each
## day: a status bar (colour = cleared / failed / available / locked), a selection
## arrow + outline, and a Start/Retry button that launches the chosen day.
##
## All of it is built in code on top of the existing scene so the layout stays
## data-driven and easy to retarget when the art is polished.

const TEX_BOX := preload("res://sprites/main_ui/level selector/level_box.png")
const TEX_BOX_OUTER := preload("res://sprites/main_ui/level selector/level_box_outer.png")
const TEX_ARROW := preload("res://sprites/main_ui/level selector/arrow.png")
const TEX_START := preload("res://sprites/main_ui/level selector/start.png")
const TEX_RETRY := preload("res://sprites/main_ui/level selector/retry.png")
const TEX_WK1_WHITE := preload("res://sprites/main_ui/level selector/level_select_week_num_1_white.png")
const TEX_WK1_YELLOW := preload("res://sprites/main_ui/level selector/level_select_week_num_1_yellow.png")
const TEX_WK2_WHITE := preload("res://sprites/main_ui/level selector/level_select_week_num_2_white.png")
const TEX_WK2_YELLOW := preload("res://sprites/main_ui/level selector/level_select_week_num_2_yellow.png")

# The panel (the "bg" node) sits at this screen position and is drawn at 2x, so
# native pixels inside level_select_box.png map to screen via origin + native*2.
const PANEL_ORIGIN := Vector2(30, 84)
const PANEL_SCALE := 2.0
# Vertical centre (in native panel pixels) of each of the five baked day tabs.
const TAB_CENTERS_NATIVE := [40.5, 94.5, 149.5, 204.5, 258.5]
# Left edge (native panel pixels) where the status bar starts, just past the tabs.
const STATUS_BOX_NATIVE_X := 55.0

const COLOR_CLEARED := Color(0.45, 0.85, 0.45)
const COLOR_FAILED := Color(0.92, 0.42, 0.42)
const COLOR_AVAILABLE := Color(0.56, 0.66, 0.96)
const COLOR_LOCKED := Color(0.3, 0.3, 0.36)

@onready var transition: AnimationPlayer = $Transition
@onready var week1_button: TextureButton = get_node("weeks/HBoxContainer/1")
@onready var week2_button: TextureButton = get_node("weeks/HBoxContainer/2")
@onready var mc: AnimatedSprite2D = $mc

var is_playing := false
var _target_scene := ""
var _current_week := 1
var _selected_day := 0          # 1..5, or 0 when nothing is selected
var _rows: Array = []           # one dict per row: {button, box, outer, arrow, label, day}
var _start_button: TextureButton
var _selected_label: Label


func _ready() -> void:
	_build_rows()
	_build_start_button()
	week1_button.pressed.connect(_show_week.bind(1))
	week2_button.pressed.connect(_show_week.bind(2))
	# Keep the fade overlay (Transition/ColorRect) drawing on top of the new rows.
	move_child($Transition, get_child_count() - 1)
	_current_week = SaveManager.get_current().x
	_show_week(_current_week)
	mc.play("default")               # idle/blink loop on entry
	transition.play("fade_in")


# ------------------------------------------------------------- build the rows

func _build_rows() -> void:
	var box_size := TEX_BOX.get_size() * PANEL_SCALE
	var outer_size := TEX_BOX_OUTER.get_size() * PANEL_SCALE
	var arrow_size := TEX_ARROW.get_size() * PANEL_SCALE
	var row_left := PANEL_ORIGIN.x + 8.0 * PANEL_SCALE

	for i in range(TAB_CENTERS_NATIVE.size()):
		var day := i + 1
		var center_y: float = PANEL_ORIGIN.y + TAB_CENTERS_NATIVE[i] * PANEL_SCALE
		var box_pos := Vector2(PANEL_ORIGIN.x + STATUS_BOX_NATIVE_X * PANEL_SCALE, center_y - box_size.y * 0.5)

		# Invisible button covering the whole row (tab + status bar) for clicks.
		var button := Button.new()
		button.flat = true
		var empty := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", empty)
		button.add_theme_stylebox_override("hover", empty)
		button.add_theme_stylebox_override("pressed", empty)
		button.add_theme_stylebox_override("focus", empty)
		button.position = Vector2(row_left, center_y - box_size.y * 0.5 - 8.0)
		button.size = Vector2((box_pos.x + box_size.x) - row_left, box_size.y + 16.0)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(button)

		# Selection outline (slightly larger, sits behind the status bar).
		var outer := TextureRect.new()
		outer.texture = TEX_BOX_OUTER
		outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer.size = outer_size
		outer.position = box_pos + (box_size - outer_size) * 0.5 - button.position
		outer.visible = false
		button.add_child(outer)

		# Status bar (modulated by the day's status).
		var box := TextureRect.new()
		box.texture = TEX_BOX
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.size = box_size
		box.position = box_pos - button.position
		button.add_child(box)

		# Selection arrow on the RIGHT side of the bar, flipped to point back at it.
		var arrow := TextureRect.new()
		arrow.texture = TEX_ARROW
		arrow.flip_h = true
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.size = arrow_size
		arrow.position = Vector2(box_pos.x + box_size.x + 6.0, center_y - arrow_size.y * 0.5) - button.position
		arrow.visible = false
		button.add_child(arrow)

		# Label describing the day (title / status) on top of the bar.
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = box_size
		label.position = box_pos - button.position
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		button.add_child(label)

		button.pressed.connect(_on_day_pressed.bind(day))
		_rows.append({"button": button, "box": box, "outer": outer, "arrow": arrow, "label": label, "day": day})


func _build_start_button() -> void:
	var size := TEX_START.get_size() * PANEL_SCALE

	_selected_label = Label.new()
	_selected_label.position = Vector2(875, 528)
	_selected_label.size = Vector2(size.x, 32)
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_label.add_theme_color_override("font_color", Color.WHITE)
	_selected_label.add_theme_constant_override("outline_size", 6)
	_selected_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_selected_label.visible = false
	add_child(_selected_label)

	_start_button = TextureButton.new()
	_start_button.ignore_texture_size = true
	_start_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_start_button.custom_minimum_size = size
	_start_button.size = size
	_start_button.position = Vector2(875, 568)
	_start_button.texture_normal = TEX_START
	_start_button.visible = false
	_start_button.pressed.connect(_on_start_pressed)
	add_child(_start_button)


# ------------------------------------------------------------- render a week

func _show_week(week: int) -> void:
	_current_week = week
	_selected_day = 0
	week1_button.texture_normal = TEX_WK1_YELLOW if week == 1 else TEX_WK1_WHITE
	week2_button.texture_normal = TEX_WK2_YELLOW if week == 2 else TEX_WK2_WHITE
	for r in _rows:
		var day: int = r["day"]
		var status := SaveManager.get_day_status(week, day)
		(r["box"] as TextureRect).modulate = _color_for_status(status)
		(r["label"] as Label).text = _label_for(week, day, status)
		(r["outer"] as TextureRect).visible = false
		(r["arrow"] as TextureRect).visible = false
	_update_start_button()


func _color_for_status(status: int) -> Color:
	match status:
		SaveManager.Status.CLEARED:
			return COLOR_CLEARED
		SaveManager.Status.FAILED:
			return COLOR_FAILED
		SaveManager.Status.AVAILABLE:
			return COLOR_AVAILABLE
		_:
			return COLOR_LOCKED


func _label_for(week: int, day: int, status: int) -> String:
	var title := SaveManager.get_day_title(week, day)
	# Days without a stage scene yet are shown as "coming soon" (they report a
	# LOCKED status, but the reason is "not built", not "gated").
	if not SaveManager.is_day_built(week, day):
		return "%s  (soon)" % title
	match status:
		SaveManager.Status.CLEARED:
			return "%s  (cleared: %d)" % [title, SaveManager.get_day_score(week, day)]
		SaveManager.Status.FAILED:
			return "%s  (failed)" % title
		SaveManager.Status.LOCKED:
			return "%s  (locked)" % title
		_:
			return title


# --------------------------------------------------------------- selection

func _on_day_pressed(day: int) -> void:
	if SaveManager.get_day_status(_current_week, day) == SaveManager.Status.LOCKED:
		return  # can't select a locked day
	_selected_day = day
	for r in _rows:
		var selected: bool = r["day"] == day
		(r["outer"] as TextureRect).visible = selected
		(r["arrow"] as TextureRect).visible = selected
	_update_start_button()


func _update_start_button() -> void:
	if _selected_day == 0:
		_start_button.visible = false
		_selected_label.visible = false
		return
	var status := SaveManager.get_day_status(_current_week, _selected_day)
	var built := SaveManager.is_day_built(_current_week, _selected_day)
	var attempted := status == SaveManager.Status.CLEARED or status == SaveManager.Status.FAILED
	_start_button.texture_normal = TEX_RETRY if attempted else TEX_START
	_start_button.visible = built
	_selected_label.visible = true
	_selected_label.text = SaveManager.get_day_title(_current_week, _selected_day) if built else "Not available yet"


func _on_start_pressed() -> void:
	if _selected_day == 0:
		return
	var scene := SaveManager.get_day_scene(_current_week, _selected_day)
	if scene == "":
		return
	mc.play("start")                 # MC perks up as the day launches
	SaveManager.set_current(_current_week, _selected_day)
	_go_to(scene)


# --------------------------------------------------------------- transitions

func _on_back_pressed() -> void:
	_go_to("res://Scenes/ui/menu.tscn")


func _go_to(scene_path: String) -> void:
	if is_playing:
		return                     # a transition is already running -> first click wins
	_target_scene = scene_path
	is_playing = true
	transition.play("fade_out")


func _on_transition_animation_finished(anim_name: StringName) -> void:
	# Only the fade-OUT leads to a scene change; the startup fade_in must not.
	if anim_name == &"fade_out" and is_playing:
		is_playing = false
		get_tree().change_scene_to_file(_target_scene if _target_scene != "" else "res://Scenes/ui/menu.tscn")

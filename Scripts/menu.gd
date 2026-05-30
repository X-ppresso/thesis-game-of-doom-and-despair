extends Control

@onready var transition: AnimationPlayer = $Transition
@onready var door: AnimatedSprite2D = $background
@onready var continue_button: TextureButton = $MarginContainer/HBoxContainer/Continue

var is_playing := false        # guards the fade-out -> change-scene step
var _target_scene := ""        # scene to load once the fade finishes
var _confirm_new_game: ConfirmationDialog


func _ready() -> void:
	transition.play("fade_in")
	_refresh_continue_button()


# Continue is only usable once a save exists; otherwise it is greyed out.
func _refresh_continue_button() -> void:
	var save_exists := SaveManager.has_save()
	continue_button.disabled = not save_exists
	continue_button.modulate = Color(1, 1, 1, 1) if save_exists else Color(1, 1, 1, 0.4)


# ------------------------------------------------------------------ buttons

func _on_new_game_pressed() -> void:
	# Starting fresh wipes existing progress, so confirm first when a save exists.
	if SaveManager.has_save():
		_ask_overwrite()
	else:
		_start_new_game()


func _start_new_game() -> void:
	SaveManager.new_game()
	_go_to("res://Scenes/ui/levels.tscn", true)   # door opens, then level select


func _on_continue_pressed() -> void:
	if not SaveManager.has_save():
		return
	var nxt := SaveManager.get_next_unplayed()
	var scene := ""
	if nxt != Vector2i.ZERO:
		scene = SaveManager.get_day_scene(nxt.x, nxt.y)
		if scene != "":
			SaveManager.set_current(nxt.x, nxt.y)
	# If the next day has no playable scene yet (or everything is cleared),
	# fall back to the level select so the player can choose.
	if scene == "":
		scene = "res://Scenes/ui/levels.tscn"
	_go_to(scene, true)


func _on_settings_pressed() -> void:
	_go_to("res://Scenes/ui/settings.tscn", false)   # no door, just a fade


func _on_exit_pressed() -> void:
	get_tree().quit()


# --------------------------------------------------------------- transitions

func _go_to(scene_path: String, use_door: bool) -> void:
	if is_playing:
		return                     # a transition is already running -> first click wins
	is_playing = true
	_target_scene = scene_path
	if use_door:
		door.play("open")          # plays the shop door opening animation first
	else:
		transition.play("fade_out")


func _on_background_animation_finished() -> void:
	# Door finished opening -> fade to black, then swap scenes.
	transition.play("fade_out")


func _on_transition_animation_finished(anim_name: StringName) -> void:
	# Only the fade-OUT leads to a scene change; the startup fade_in must not.
	if anim_name == &"fade_out" and is_playing:
		is_playing = false
		if _target_scene != "":
			get_tree().change_scene_to_file(_target_scene)


# ----------------------------------------------------- new-game confirmation

func _ask_overwrite() -> void:
	if _confirm_new_game == null:
		_confirm_new_game = ConfirmationDialog.new()
		_confirm_new_game.title = "New Game"
		_confirm_new_game.dialog_text = "Starting a new game will erase your current progress.\nAre you sure?"
		_confirm_new_game.confirmed.connect(_start_new_game)
		add_child(_confirm_new_game)
	_confirm_new_game.popup_centered()

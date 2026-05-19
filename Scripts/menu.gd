extends Control

@onready var transition = $Transition
@onready var animation = $background
var is_playing = false
#used as a condition so the transitions don't tweak out

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	transition.play("fade_in")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_new_game_pressed() -> void:
	animation.play("open")
	#opens the door

func _on_continue_pressed() -> void:
	pass # Replace with function body.

func _on_settings_pressed() -> void:
	pass # Replace with function body.
	
func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_background_animation_finished() -> void:
	transition.play("fade_out")
	is_playing = true

func _on_transition_animation_finished(anim_name: StringName) -> void:
	if is_playing == true:
		get_tree().change_scene_to_file("res://Scenes/ui/levels.tscn")
		is_playing = false

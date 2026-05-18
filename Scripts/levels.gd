extends Control

@onready var transition = $Transition

var is_playing = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	transition.play("fade_in")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_back_pressed() -> void:
	transition.play("fade_out")
	is_playing = true


func _on_transition_animation_finished(anim_name: StringName) -> void:
	if is_playing:
		get_tree().change_scene_to_file("res://Scenes/ui/menu.tscn")
		is_playing = false

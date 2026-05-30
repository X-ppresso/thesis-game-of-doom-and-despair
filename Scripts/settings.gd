extends Control

## Basic settings screen: master volume + fullscreen toggle.
## Reads/writes through the SettingsManager autoload (which persists to disk).

@onready var volume_slider: HSlider = $Center/Panel/Margin/VBox/VolumeRow/VolumeSlider
@onready var fullscreen_toggle: CheckButton = $Center/Panel/Margin/VBox/FullscreenRow/FullscreenToggle
@onready var back_button: Button = $Center/Panel/Margin/VBox/Back
@onready var fade: ColorRect = $Fade

var _is_leaving := false


func _ready() -> void:
	volume_slider.value = SettingsManager.master_volume
	fullscreen_toggle.button_pressed = SettingsManager.fullscreen
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back_pressed)
	# Fade up from black (the menu faded to black before changing to this scene).
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 0.4)


func _on_volume_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	SettingsManager.set_fullscreen(toggled_on)


func _on_back_pressed() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.4)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://Scenes/ui/menu.tscn"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

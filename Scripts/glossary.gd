extends Node2D

@onready var buttons_container: VBoxContainer = $MarginContainer/VBoxContainer
@onready var labels_container: Node = $MarginContainer2

func _ready() -> void:
	for btn in buttons_container.get_children():
		if btn is Button:
			btn.connect("pressed", Callable(self, "_on_button_pressed").bind(btn.text))
	# show default text at start
	_show_only("default")


func _on_button_pressed(category: String) -> void:
	_show_only(category)


func _show_only(category: String) -> void:
	var found: bool = false
	for child in labels_container.get_children():
		if child is RichTextLabel:
			var visible := child.name == category
			child.visible = visible
			if visible:
				found = true
	if not found:
		# fallback to default if no matching label
		for child in labels_container.get_children():
			if child is RichTextLabel:
				child.visible = child.name == "default"

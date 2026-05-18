extends Node2D

const MALWARE_PUZZLE := preload("res://Scenes/puzzle/malware_puzzle/malware.tscn")

const TIMELINE_HG_WEEK1 := "highschooler_week1"
const TIMELINE_HG_WEEK1_POST := "highschooler_week1_post"

# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	pass
	Dialogic.start(TIMELINE_HG_WEEK1)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

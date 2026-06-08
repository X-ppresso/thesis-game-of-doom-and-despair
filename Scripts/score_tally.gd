extends Control

## Weekly score-tally screen, shown after the player clears the last day (Friday)
## of a week — see Scenes/stage/day.gd. It reuses the level-select shop background
## and counter MC, swaps in score_box.png for the panel, counts the week's payment
## up toward the quota, then plays the MC clear or fail animation depending on
## whether the quota was met. Click (or press a key) afterwards to return.
##
## The MC frames are built in code from the counter sheets (128x200 frames):
## blink = idle, hapi = clear, cri = fail.

const HAPI := preload("res://sprites/main_ui/level selector/mc_counter_hapi-Sheet.png")
const CRI := preload("res://sprites/main_ui/level selector/mc_counter_cri-Sheet.png")
const BLINK := preload("res://sprites/main_ui/level selector/mc_counter_anims-blink.png")
const FRAME_W := 128
const FRAME_H := 200

@onready var mc: AnimatedSprite2D = $mc
@onready var number: Label = $Number
@onready var hint: Label = $Hint

var _can_continue := false


func _ready() -> void:
	var week := Global.last_completed_week
	var payment := SaveManager.get_week_payment(week)
	var quota := SaveManager.get_week_quota(week)
	var passed := payment >= quota

	mc.sprite_frames = _build_frames()
	mc.play("idle")
	hint.visible = false
	number.text = "0 / %d" % quota

	# Count the payment up, then react with the verdict animation.
	var tw := create_tween()
	tw.tween_method(_set_number.bind(quota), 0.0, float(payment), 1.5).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		mc.play("clear" if passed else "fail")
		hint.visible = true
		_can_continue = true)


func _set_number(value: float, quota: int) -> void:
	number.text = "%d / %d" % [int(round(value)), quota]


func _unhandled_input(event: InputEvent) -> void:
	if not _can_continue:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://Scenes/ui/levels.tscn")


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	_add_anim(sf, "idle", BLINK, 3, 6.0, true)
	_add_anim(sf, "clear", HAPI, 7, 8.0, false)
	_add_anim(sf, "fail", CRI, 6, 12.0, false)
	return sf


func _add_anim(sf: SpriteFrames, anim: String, sheet: Texture2D, count: int, speed: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, speed)
	sf.set_animation_loop(anim, loop)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		sf.add_frame(anim, at)

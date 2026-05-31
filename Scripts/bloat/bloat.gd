class_name BloatPuzzle
extends Node2D

## The bloat minigame: a Tinder-style swipe deck (from the GDD). Apps/files are
## shown one at a time on a card; the player Keeps (swipe right) or Trashes
## (swipe left) each one. Keeping bloat or trashing a legit app costs score.
## When the deck is empty the puzzle is complete.
##
## The Keep/Trash buttons live in the device scene (laptop_bloat / phone_bloat),
## which calls keep()/trash() here — mirroring how the malware scanner button
## lives in the device and drives the malware puzzle.

signal puzzle_complete()

@export var total_items: int = 10
@export var bad_items: int = 5
@export var wrong_penalty: int = 10
## Where the current card is shown (global coords). Set by the device controller.
@export var card_rect: Rect2 = Rect2(440, 160, 400, 320)

## App icons, dealt from a shuffled deck so the spread stays even.
const ICONS: Array[Texture2D] = [
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_1.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_2.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_3.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_4.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_5.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_6.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_7.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_8.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_9.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_10.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_11.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_12.png"),
	preload("res://sprites/main_ui/gameplay/minigame assets/icon_13.png"),
]

## Legit apps the player should KEEP.
const GOOD_APPS := [
	"Photos", "Messages", "Calendar", "Notes", "Camera", "Maps",
	"Music", "Bank", "Clock", "Browser", "Contacts", "Gallery",
]
## Bloat / adware the player should TRASH.
const BAD_APPS := [
	"MegaClean Pro", "FreeVPN Turbo", "Battery Saver X", "System Booster!",
	"AdBlitz Free", "PhoneCooler", "RAM Cleaner+", "Lucky Spin",
	"QR Scanner Pro", "Flashlight HD", "SpeedFix!", "Coupon Genie",
]

@onready var card: Control = $Card
@onready var icon: TextureRect = $Card/Icon
@onready var name_label: Label = $Card/Name
@onready var score_label: Label = $UI/ScoreLabel
@onready var progress_label: Label = $UI/ProgressLabel

var _deck: Array = []          # each: {name, is_bad, icon}
var _index: int = 0
var _busy: bool = false
var _card_base_pos: Vector2
var _icon_deck: Array[Texture2D] = []


func _ready() -> void:
	Global.day_score_changed.connect(_on_score_changed)
	_build_deck()
	_layout_card()
	_show_current()
	_refresh_score()


func _build_deck() -> void:
	var bad := clampi(bad_items, 0, total_items)
	var good := total_items - bad
	var goods := GOOD_APPS.duplicate(); goods.shuffle()
	var bads := BAD_APPS.duplicate(); bads.shuffle()
	for i in good:
		_deck.append({"name": goods[i % goods.size()], "is_bad": false, "icon": _next_icon()})
	for i in bad:
		_deck.append({"name": bads[i % bads.size()], "is_bad": true, "icon": _next_icon()})
	_deck.shuffle()


func _next_icon() -> Texture2D:
	if _icon_deck.is_empty():
		_icon_deck = ICONS.duplicate()
		_icon_deck.shuffle()
	return _icon_deck.pop_back()


func _layout_card() -> void:
	# Fill the device's baked card slot exactly (card_rect is that slot).
	card.position = card_rect.position
	card.size = card_rect.size
	card.pivot_offset = card.size * 0.5
	_card_base_pos = card.position


# --- public API, called by the device's Keep/Trash buttons -------------------

func keep() -> void:
	_decide(false)


func trash() -> void:
	_decide(true)


func _decide(trashed: bool) -> void:
	if _busy or _index >= _deck.size():
		return
	_busy = true
	var item: Dictionary = _deck[_index]
	var correct: bool = bool(item["is_bad"]) == trashed
	if not correct:
		Global.deduct_score(wrong_penalty)
	_swipe_out(trashed, correct)


func _swipe_out(trashed: bool, correct: bool) -> void:
	var dir := -1.0 if trashed else 1.0
	card.modulate = Color(0.5, 1.0, 0.5) if correct else Color(1.0, 0.5, 0.5)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "position:x", card.position.x + dir * 1000.0, 0.26).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "rotation_degrees", dir * 18.0, 0.26)
	tween.tween_property(card, "modulate:a", 0.0, 0.26)
	tween.chain().tween_callback(_advance)


func _advance() -> void:
	_index += 1
	_busy = false
	if _index >= _deck.size():
		puzzle_complete.emit()
	else:
		_show_current()


func _show_current() -> void:
	if _index >= _deck.size():
		return
	var item: Dictionary = _deck[_index]
	icon.texture = item["icon"]
	name_label.text = item["name"]
	card.position = _card_base_pos
	card.rotation_degrees = 0.0
	card.modulate = Color.WHITE
	_refresh_progress()


func _on_score_changed(_new_score: int) -> void:
	_refresh_score()


func _refresh_score() -> void:
	if score_label:
		score_label.text = "Score: %d" % Global.current_day_score


func _refresh_progress() -> void:
	if progress_label:
		progress_label.text = "Apps left: %d" % (_deck.size() - _index)

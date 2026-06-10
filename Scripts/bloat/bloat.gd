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

## App icons, each with its own pool of legit and bloat/adware names.
const ICON_PRESETS := [
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_1.png"),
		"good_names": ["Files", "My Files"],
		"bad_names": [],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_2.png"),
		"good_names": ["Dating app", "Binder"],
		"bad_names": [],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_3.png"),
		"good_names": ["Hollow Night", "Fighting the Sun!"],
		"bad_names": [],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_4.png"),
		"good_names": ["Music", "Music Player", "Tunes"],
		"bad_names": [],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_5.png"),
		"good_names": ["Documents", "Files", "Sheets"],
		"bad_names": ["NotVirus.apk"],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_6.png"),
		"good_names": ["Photos", "Gallery", "Pictures"],
		"bad_names": [],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_7.png"),
		"good_names": [],
		"bad_names": ["MegaClean Pro", "Battery Saver X", "RAM Cleaner+"],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_8.png"),
		"good_names": ["Contacts", "Chat", "Messages", "Forums"],
		"bad_names": [],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_9.png"),
		"good_names": [],
		"bad_names": ["Unlucky Patcher", "Coupon Genie", "Super Fixer"],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_10.png"),
		"good_names": [],
		"bad_names": ["Bouncy Friend", "Blooneys TD 10", "Gorilla Pal"],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_11.png"),
		"good_names": ["Mail", "Messages"],
		"bad_names": [],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_12.png"),
		"good_names": ["Games", "Game launcher", "Amogus"],
		"bad_names": [],
	},
	{
		"texture": preload("res://sprites/main_ui/gameplay/minigame assets/icon_13.png"),
		"good_names": ["Contacts", "Call", "Phone", "Whatsupp"],
		"bad_names": [],
	},
]

## Optional fallback names when an icon has no category-specific pool.
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
var _good_icon_deck: Array = []
var _bad_icon_deck: Array = []


func _ready() -> void:
	Global.day_score_changed.connect(_on_score_changed)
	_build_deck()
	_layout_card()
	_show_current()
	_refresh_score()


func _build_deck() -> void:
	var bad := clampi(bad_items, 0, total_items)
	var good := total_items - bad
	for i in good:
		var card := _next_icon(false)
		_deck.append({"name": card.name, "is_bad": false, "icon": card.texture})
	for i in bad:
		var card := _next_icon(true)
		_deck.append({"name": card.name, "is_bad": true, "icon": card.texture})
	_deck.shuffle()


func _next_icon(is_bad: bool) -> Dictionary:
	var deck: Array = _good_icon_deck if not is_bad else _bad_icon_deck
	if deck.is_empty():
		deck = []
		for preset in ICON_PRESETS:
			if is_bad and preset.get("bad_names", []).size() > 0:
				deck.append(preset)
			elif not is_bad and preset.get("good_names", []).size() > 0:
				deck.append(preset)
		deck.shuffle()
		if is_bad:
			_bad_icon_deck = deck
		else:
			_good_icon_deck = deck
	var icon_data: Dictionary = deck.pop_back() as Dictionary
	var names: Array
	if is_bad:
		names = icon_data.get("bad_names", []) as Array
	else:
		names = icon_data.get("good_names", []) as Array
	if names.is_empty():
		names = BAD_APPS if is_bad else GOOD_APPS
	var name: String = names[randi() % names.size()] as String
	return {"texture": icon_data.get("texture"), "name": name}


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

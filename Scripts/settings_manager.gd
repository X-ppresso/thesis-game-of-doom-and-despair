extends Node

## Loads, applies and persists basic game settings (master volume + fullscreen).
## Autoloaded as "SettingsManager" so the chosen settings are applied at startup
## and from any scene.

const PATH := "user://settings.cfg"

var master_volume: float = 0.4   # linear, 0..1
var fullscreen: bool = false


func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  # no settings file yet -> keep defaults
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)


func apply_all() -> void:
	_apply_volume()
	_apply_window()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	save_settings()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_window()
	save_settings()


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		bus = 0
	if master_volume <= 0.0:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))


func _apply_window() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

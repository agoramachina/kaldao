class_name EventBus
extends RefCounted

# Singleton event bus for decoupled communication
static var _instance: EventBus
static var _signal_connections: Dictionary = {}

static func get_instance() -> EventBus:
	if not _instance:
		_instance = EventBus.new()
	return _instance

# Event definitions
signal parameter_changed(param_name: String, value: float)
signal palette_changed(palette_data: Dictionary)
signal audio_level_changed(bass: float, mid: float, treble: float)
signal beat_detected(intensity: float)
signal screenshot_requested()
signal screenshot_completed(file_path: String)
signal audio_playback_toggled(is_playing: bool)
signal audio_reactive_toggled(is_reactive: bool)
signal checkpoint_reached(timestamp: float, name: String)
signal settings_saved(file_path: String)
signal settings_loaded(file_path: String)
signal menu_visibility_changed(is_visible: bool)
signal text_update_requested(text: String)

static func emit_parameter_changed(param_name: String, value: float):
	get_instance().parameter_changed.emit(param_name, value)

static func emit_palette_changed(palette_data: Dictionary):
	get_instance().palette_changed.emit(palette_data)

static func emit_audio_level_changed(bass: float, mid: float, treble: float):
	get_instance().audio_level_changed.emit(bass, mid, treble)

static func emit_beat_detected(intensity: float):
	get_instance().beat_detected.emit(intensity)

static func emit_screenshot_requested():
	get_instance().screenshot_requested.emit()

static func emit_screenshot_completed(file_path: String):
	get_instance().screenshot_completed.emit(file_path)

static func emit_audio_playback_toggled(is_playing: bool):
	get_instance().audio_playback_toggled.emit(is_playing)

static func emit_audio_reactive_toggled(is_reactive: bool):
	get_instance().audio_reactive_toggled.emit(is_reactive)

static func emit_checkpoint_reached(timestamp: float, name: String):
	get_instance().checkpoint_reached.emit(timestamp, name)

static func emit_settings_saved(file_path: String):
	get_instance().settings_saved.emit(file_path)

static func emit_settings_loaded(file_path: String):
	get_instance().settings_loaded.emit(file_path)

static func emit_menu_visibility_changed(is_visible: bool):
	get_instance().menu_visibility_changed.emit(is_visible)

static func emit_text_update_requested(text: String):
	get_instance().text_update_requested.emit(text)

# Helper methods for connecting to events
static func connect_to_parameter_changed(callable: Callable):
	get_instance().parameter_changed.connect(callable)

static func connect_to_palette_changed(callable: Callable):
	get_instance().palette_changed.connect(callable)

static func connect_to_audio_level_changed(callable: Callable):
	get_instance().audio_level_changed.connect(callable)

static func connect_to_beat_detected(callable: Callable):
	get_instance().beat_detected.connect(callable)

static func connect_to_screenshot_requested(callable: Callable):
	get_instance().screenshot_requested.connect(callable)

static func connect_to_screenshot_completed(callable: Callable):
	get_instance().screenshot_completed.connect(callable)

static func connect_to_audio_playback_toggled(callable: Callable):
	get_instance().audio_playback_toggled.connect(callable)

static func connect_to_audio_reactive_toggled(callable: Callable):
	get_instance().audio_reactive_toggled.connect(callable)

static func connect_to_checkpoint_reached(callable: Callable):
	get_instance().checkpoint_reached.connect(callable)

static func connect_to_settings_saved(callable: Callable):
	get_instance().settings_saved.connect(callable)

static func connect_to_settings_loaded(callable: Callable):
	get_instance().settings_loaded.connect(callable)

static func connect_to_menu_visibility_changed(callable: Callable):
	get_instance().menu_visibility_changed.connect(callable)

static func connect_to_text_update_requested(callable: Callable):
	get_instance().text_update_requested.connect(callable)

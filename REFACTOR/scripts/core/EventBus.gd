class_name EventBus
extends RefCounted

## EventBus - Global Event Communication System
##
## This class provides a centralized event system for decoupled communication
## between components. It implements the Observer pattern to allow components
## to communicate without direct references to each other.
##
## Usage:
##   # Connect to an event
##   EventBus.connect_to_parameter_changed(my_callback_function)
##   
##   # Emit an event
##   EventBus.emit_parameter_changed("zoom_level", 1.5)
##
## @tutorial: https://gameprogrammingpatterns.com/observer.html

# Singleton instance for global access
static var _instance: EventBus

## Get the singleton instance
static func get_instance() -> EventBus:
	if not _instance:
		_instance = EventBus.new()
	return _instance

#region Core Application Events

## Emitted when the application is starting up
signal application_starting()

## Emitted when the application is ready
signal application_ready()

## Emitted when the application is shutting down
signal application_shutting_down()

#endregion

#region Parameter Events

## Emitted when any parameter value changes
## @param param_name: The name of the parameter that changed
## @param value: The new value of the parameter
signal parameter_changed(param_name: String, value: float)

## Emitted when the current parameter selection changes
## @param param_name: The name of the newly selected parameter
signal current_parameter_changed(param_name: String)

## Emitted when all parameters are reset to defaults
signal all_parameters_reset()

## Emitted when parameters are randomized
signal parameters_randomized()

#endregion

#region Color Palette Events

## Emitted when the color palette changes
## @param palette_data: Dictionary containing palette information
signal palette_changed(palette_data: Dictionary)

## Emitted when colors are randomized
signal colors_randomized()

## Emitted when colors are reset to black and white
signal colors_reset_to_bw()

#endregion

#region Audio Events

## Emitted when audio levels change
## @param bass: Bass frequency level (0.0 - 1.0+)
## @param mid: Mid frequency level (0.0 - 1.0+)
## @param treble: Treble frequency level (0.0 - 1.0+)
signal audio_levels_changed(bass: float, mid: float, treble: float)

## Emitted when a beat is detected
## @param intensity: The intensity of the detected beat
signal beat_detected(intensity: float)

## Emitted when audio playback is toggled
## @param is_playing: True if audio is now playing, false if stopped
signal audio_playback_toggled(is_playing: bool)

## Emitted when audio reactivity is toggled
## @param is_reactive: True if audio reactivity is enabled
signal audio_reactive_toggled(is_reactive: bool)

## Emitted when audio seek position changes
## @param timestamp: The new playback position in seconds
signal audio_seek_requested(timestamp: float)

#endregion

#region Timeline Events

## Emitted when a checkpoint is reached during playback
## @param timestamp: The timestamp of the checkpoint
## @param name: The name/description of the checkpoint
signal checkpoint_reached(timestamp: float, name: String)

## Emitted when timeline scrubbing is requested
## @param timestamp: The target timestamp to seek to
signal timeline_seek_requested(timestamp: float)

## Emitted when play/pause is requested from timeline
signal timeline_play_pause_requested()

#endregion

#region UI Events

## Emitted when text should be displayed to the user
## @param text: The text to display
signal text_update_requested(text: String)

## Emitted when menu visibility changes
## @param is_visible: True if menu is now visible
signal menu_visibility_changed(is_visible: bool)

## Emitted when a screenshot is requested
signal screenshot_requested()

## Emitted when a screenshot is completed
## @param file_path: The path where the screenshot was saved
signal screenshot_completed(file_path: String)

## Emitted when a screenshot fails
## @param error_message: Description of the error
signal screenshot_failed(error_message: String)

#endregion

#region Settings Events

## Emitted when settings are saved
## @param file_path: The path where settings were saved
signal settings_saved(file_path: String)

## Emitted when settings are loaded
## @param file_path: The path from which settings were loaded
signal settings_loaded(file_path: String)

## Emitted when settings save fails
## @param error_message: Description of the error
signal settings_save_failed(error_message: String)

## Emitted when settings load fails
## @param error_message: Description of the error
signal settings_load_failed(error_message: String)

#endregion

#region Input Events

## Emitted when pause/resume is requested
signal pause_toggle_requested()

## Emitted when parameter increase is requested
signal parameter_increase_requested()

## Emitted when parameter decrease is requested
signal parameter_decrease_requested()

## Emitted when next parameter is requested
signal parameter_next_requested()

## Emitted when previous parameter is requested
signal parameter_previous_requested()

#endregion

#region Event Emission Methods

## Application Events
static func emit_application_starting():
	get_instance().application_starting.emit()

static func emit_application_ready():
	get_instance().application_ready.emit()

static func emit_application_shutting_down():
	get_instance().application_shutting_down.emit()

## Parameter Events
static func emit_parameter_changed(param_name: String, value: float):
	get_instance().parameter_changed.emit(param_name, value)

static func emit_current_parameter_changed(param_name: String):
	get_instance().current_parameter_changed.emit(param_name)

static func emit_all_parameters_reset():
	get_instance().all_parameters_reset.emit()

static func emit_parameters_randomized():
	get_instance().parameters_randomized.emit()

## Color Palette Events
static func emit_palette_changed(palette_data: Dictionary):
	get_instance().palette_changed.emit(palette_data)

static func emit_colors_randomized():
	get_instance().colors_randomized.emit()

static func emit_colors_reset_to_bw():
	get_instance().colors_reset_to_bw.emit()

## Audio Events
static func emit_audio_levels_changed(bass: float, mid: float, treble: float):
	get_instance().audio_levels_changed.emit(bass, mid, treble)

static func emit_beat_detected(intensity: float):
	get_instance().beat_detected.emit(intensity)

static func emit_audio_playback_toggled(is_playing: bool):
	get_instance().audio_playback_toggled.emit(is_playing)

static func emit_audio_reactive_toggled(is_reactive: bool):
	get_instance().audio_reactive_toggled.emit(is_reactive)

static func emit_audio_seek_requested(timestamp: float):
	get_instance().audio_seek_requested.emit(timestamp)

## Timeline Events
static func emit_checkpoint_reached(timestamp: float, name: String):
	get_instance().checkpoint_reached.emit(timestamp, name)

static func emit_timeline_seek_requested(timestamp: float):
	get_instance().timeline_seek_requested.emit(timestamp)

static func emit_timeline_play_pause_requested():
	get_instance().timeline_play_pause_requested.emit()

## UI Events
static func emit_text_update_requested(text: String):
	get_instance().text_update_requested.emit(text)

static func emit_menu_visibility_changed(is_visible: bool):
	get_instance().menu_visibility_changed.emit(is_visible)

static func emit_screenshot_requested():
	get_instance().screenshot_requested.emit()

static func emit_screenshot_completed(file_path: String):
	get_instance().screenshot_completed.emit(file_path)

static func emit_screenshot_failed(error_message: String):
	get_instance().screenshot_failed.emit(error_message)

## Settings Events
static func emit_settings_saved(file_path: String):
	get_instance().settings_saved.emit(file_path)

static func emit_settings_loaded(file_path: String):
	get_instance().settings_loaded.emit(file_path)

static func emit_settings_save_failed(error_message: String):
	get_instance().settings_save_failed.emit(error_message)

static func emit_settings_load_failed(error_message: String):
	get_instance().settings_load_failed.emit(error_message)

## Input Events
static func emit_pause_toggle_requested():
	get_instance().pause_toggle_requested.emit()

static func emit_parameter_increase_requested():
	get_instance().parameter_increase_requested.emit()

static func emit_parameter_decrease_requested():
	get_instance().parameter_decrease_requested.emit()

static func emit_parameter_next_requested():
	get_instance().parameter_next_requested.emit()

static func emit_parameter_previous_requested():
	get_instance().parameter_previous_requested.emit()

#endregion

#region Event Connection Methods

## Application Events
static func connect_to_application_starting(callable: Callable):
	get_instance().application_starting.connect(callable)

static func connect_to_application_ready(callable: Callable):
	get_instance().application_ready.connect(callable)

static func connect_to_application_shutting_down(callable: Callable):
	get_instance().application_shutting_down.connect(callable)

## Parameter Events
static func connect_to_parameter_changed(callable: Callable):
	get_instance().parameter_changed.connect(callable)

static func connect_to_current_parameter_changed(callable: Callable):
	get_instance().current_parameter_changed.connect(callable)

static func connect_to_all_parameters_reset(callable: Callable):
	get_instance().all_parameters_reset.connect(callable)

static func connect_to_parameters_randomized(callable: Callable):
	get_instance().parameters_randomized.connect(callable)

## Color Palette Events
static func connect_to_palette_changed(callable: Callable):
	get_instance().palette_changed.connect(callable)

static func connect_to_colors_randomized(callable: Callable):
	get_instance().colors_randomized.connect(callable)

static func connect_to_colors_reset_to_bw(callable: Callable):
	get_instance().colors_reset_to_bw.connect(callable)

## Audio Events
static func connect_to_audio_levels_changed(callable: Callable):
	get_instance().audio_levels_changed.connect(callable)

static func connect_to_beat_detected(callable: Callable):
	get_instance().beat_detected.connect(callable)

static func connect_to_audio_playback_toggled(callable: Callable):
	get_instance().audio_playback_toggled.connect(callable)

static func connect_to_audio_reactive_toggled(callable: Callable):
	get_instance().audio_reactive_toggled.connect(callable)

static func connect_to_audio_seek_requested(callable: Callable):
	get_instance().audio_seek_requested.connect(callable)

## Timeline Events
static func connect_to_checkpoint_reached(callable: Callable):
	get_instance().checkpoint_reached.connect(callable)

static func connect_to_timeline_seek_requested(callable: Callable):
	get_instance().timeline_seek_requested.connect(callable)

static func connect_to_timeline_play_pause_requested(callable: Callable):
	get_instance().timeline_play_pause_requested.emit()

## UI Events
static func connect_to_text_update_requested(callable: Callable):
	get_instance().text_update_requested.connect(callable)

static func connect_to_menu_visibility_changed(callable: Callable):
	get_instance().menu_visibility_changed.connect(callable)

static func connect_to_screenshot_requested(callable: Callable):
	get_instance().screenshot_requested.connect(callable)

static func connect_to_screenshot_completed(callable: Callable):
	get_instance().screenshot_completed.connect(callable)

static func connect_to_screenshot_failed(callable: Callable):
	get_instance().screenshot_failed.connect(callable)

## Settings Events
static func connect_to_settings_saved(callable: Callable):
	get_instance().settings_saved.connect(callable)

static func connect_to_settings_loaded(callable: Callable):
	get_instance().settings_loaded.connect(callable)

static func connect_to_settings_save_failed(callable: Callable):
	get_instance().settings_save_failed.connect(callable)

static func connect_to_settings_load_failed(callable: Callable):
	get_instance().settings_load_failed.connect(callable)

## Input Events
static func connect_to_pause_toggle_requested(callable: Callable):
	get_instance().pause_toggle_requested.connect(callable)

static func connect_to_parameter_increase_requested(callable: Callable):
	get_instance().parameter_increase_requested.connect(callable)

static func connect_to_parameter_decrease_requested(callable: Callable):
	get_instance().parameter_decrease_requested.connect(callable)

static func connect_to_parameter_next_requested(callable: Callable):
	get_instance().parameter_next_requested.connect(callable)

static func connect_to_parameter_previous_requested(callable: Callable):
	get_instance().parameter_previous_requested.connect(callable)

#endregion

#region Utility Methods

## Disconnect all connections for cleanup
static func disconnect_all():
	var instance = get_instance()
	
	# Get all signals and disconnect them
	var signal_list = instance.get_signal_list()
	for signal_info in signal_list:
		var signal_name = signal_info.name
		var connections = instance.get_signal_connection_list(signal_name)
		for connection in connections:
			instance.disconnect(signal_name, connection.callable)
	
	print("EventBus: Disconnected all signal connections")

## Get information about current connections (for debugging)
static func get_connection_info() -> Dictionary:
	var instance = get_instance()
	var info = {}
	
	var signal_list = instance.get_signal_list()
	for signal_info in signal_list:
		var signal_name = signal_info.name
		var connections = instance.get_signal_connection_list(signal_name)
		info[signal_name] = connections.size()
	
	return info

#endregion

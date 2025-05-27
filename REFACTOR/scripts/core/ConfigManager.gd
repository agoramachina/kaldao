class_name ConfigManager
extends RefCounted

## ConfigManager - Centralized Configuration Management System
##
## This class manages all application configuration with JSON persistence,
## default value fallbacks, and type-safe access methods. It provides a
## centralized way to manage settings that can be easily modified without
## code changes.
##
## Usage:
##   # Load configuration
##   ConfigManager.load_config()
##   
##   # Get a value
##   var bass_amp = ConfigManager.get_audio_bass_amplifier()
##   
##   # Set a value
##   ConfigManager.set_audio_bass_amplifier(20.0)
##   ConfigManager.save_config()

# Configuration file paths
const CONFIG_FILE_PATH = "res://REFACTOR/config/app_config.json"
const USER_CONFIG_PATH = "user://kaldao_config.json"
const SETTINGS_DIR = "res://data/config/"
const QUICK_SAVE_FILE = "fractal_settings_current.json"

# Configuration state
static var _config: Dictionary = {}
static var _is_loaded: bool = false
static var _config_version: String = "1.0"

## Default configuration structure with comprehensive settings
const DEFAULT_CONFIG = {
	"version": "1.0",
	"audio": {
		"default_file": "res://audio/SoS.wav",
		"amplifiers": {
			"bass": 15.0,
			"mid": 12.0,
			"treble": 10.0,
			"overall": 3.0
		},
		"beat_detection": {
			"threshold_multiplier": 1.3,
			"min_interval": 0.12,
			"duration": 0.4,
			"sensitivity": 0.8
		},
		"frequency_ranges": {
			"bass_min": 20.0,
			"bass_max": 200.0,
			"mid_min": 200.0,
			"mid_max": 3000.0,
			"treble_min": 3000.0,
			"treble_max": 20000.0
		},
		"analysis": {
			"fft_size": 2048,
			"spectrum_buffer_length": 2.0,
			"smoothing_factor": 0.08,
			"sample_rate": 44100.0
		}
	},
	"visual": {
		"shaders": {
			"default_shader": "res://shaders/kaldao.gdshader",
			"kaleidoscope_shader": "res://shaders/kaleidoscope.gdshader",
			"koch_shader": "res://shaders/koch.gdshader"
		},
		"effects": {
			"auto_fade_delay": 1.5,
			"startup_menu_duration": 8.0,
			"parameter_fade_duration": 1.0,
			"beat_effect_duration": 0.4
		},
		"colors": {
			"default_palette": "bw",
			"color_transition_speed": 0.5,
			"intensity_range": [0.1, 4.0]
		},
		"camera": {
			"default_position": [0.0, 0.0, 0.0],
			"movement_smoothing": 0.1,
			"rotation_smoothing": 0.05
		}
	},
	"input": {
		"debug_mode": false,
		"double_tap_threshold": 0.3,
		"key_repeat_delay": 0.1,
		"mouse_sensitivity": 1.0
	},
	"ui": {
		"timeline": {
			"height": 60,
			"margin": 20,
			"update_interval": 0.1,
			"scrub_sensitivity": 1.0
		},
		"menu": {
			"fade_duration": 1.0,
			"background_opacity": 0.8,
			"text_size": 12
		},
		"parameter_display": {
			"show_duration": 3.0,
			"fade_duration": 1.0,
			"position": "center"
		}
	},
	"performance": {
		"target_fps": 60,
		"vsync_enabled": true,
		"debug_print_interval": 30,
		"memory_pool_size": 1024,
		"max_audio_history": 180
	},
	"files": {
		"screenshot_dir": "res://data/screenshots/",
		"settings_dir": "res://data/config/",
		"audio_dir": "res://audio/",
		"shader_dir": "res://shaders/"
	}
}

#region Core Configuration Methods

## Load configuration from file with fallback to defaults
## @return: True if configuration was loaded successfully
static func load_config() -> bool:
	if _is_loaded:
		return true
	
	print("ConfigManager: Loading configuration...")
	
	# Try to load from user directory first (user preferences)
	var loaded = false
	var file = FileAccess.open(USER_CONFIG_PATH, FileAccess.READ)
	
	if file:
		loaded = _load_from_file(file, "user config")
		file.close()
	
	# Fallback to resource config if user config doesn't exist
	if not loaded:
		file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ)
		if file:
			loaded = _load_from_file(file, "resource config")
			file.close()
	
	# Use defaults if no config file exists
	if not loaded:
		print("ConfigManager: No config file found, using defaults")
		_config = DEFAULT_CONFIG.duplicate(true)
	
	# Ensure all default keys exist (merge with defaults)
	_merge_with_defaults()
	
	_is_loaded = true
	print("ConfigManager: Configuration loaded successfully")
	return true

## Save configuration to user directory
## @return: True if configuration was saved successfully
static func save_config() -> bool:
	if not _is_loaded:
		load_config()
	
	# Update version
	_config["version"] = _config_version
	
	var json_string = JSON.stringify(_config, "\t")
	var file = FileAccess.open(USER_CONFIG_PATH, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		print("ConfigManager: Configuration saved to %s" % USER_CONFIG_PATH)
		return true
	else:
		push_error("ConfigManager: Failed to save configuration to %s" % USER_CONFIG_PATH)
		return false

## Reset configuration to defaults
static func reset_to_defaults() -> void:
	_config = DEFAULT_CONFIG.duplicate(true)
	_is_loaded = true
	save_config()
	print("ConfigManager: Configuration reset to defaults")

#endregion

#region Private Helper Methods

## Load configuration from a file handle
static func _load_from_file(file: FileAccess, source_name: String) -> bool:
	var json_string = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result == OK:
		_config = json.data
		print("ConfigManager: Loaded configuration from %s" % source_name)
		return true
	else:
		push_error("ConfigManager: Failed to parse %s: %s" % [source_name, json.error_string])
		return false

## Merge loaded config with defaults to ensure all keys exist
static func _merge_with_defaults() -> void:
	_config = _deep_merge(DEFAULT_CONFIG, _config)

## Deep merge two dictionaries, with user_dict taking precedence
static func _deep_merge(default_dict: Dictionary, user_dict: Dictionary) -> Dictionary:
	var result = default_dict.duplicate(true)
	
	for key in user_dict:
		if key in result and typeof(result[key]) == TYPE_DICTIONARY and typeof(user_dict[key]) == TYPE_DICTIONARY:
			result[key] = _deep_merge(result[key], user_dict[key])
		else:
			result[key] = user_dict[key]
	
	return result

#endregion

#region Generic Configuration Access

## Get a configuration value using dot notation
## @param path: Configuration path (e.g., "audio.amplifiers.bass")
## @param default_value: Value to return if path doesn't exist
## @return: The configuration value or default_value
static func get_config_value(path: String, default_value = null):
	if not _is_loaded:
		load_config()
	
	var keys = path.split(".")
	var current = _config
	
	for key in keys:
		if typeof(current) == TYPE_DICTIONARY and key in current:
			current = current[key]
		else:
			return default_value
	
	return current

## Set a configuration value using dot notation
## @param path: Configuration path (e.g., "audio.amplifiers.bass")
## @param value: The value to set
static func set_config_value(path: String, value) -> void:
	if not _is_loaded:
		load_config()
	
	var keys = path.split(".")
	var current = _config
	
	# Navigate to the parent of the target key
	for i in range(keys.size() - 1):
		var key = keys[i]
		if not (key in current):
			current[key] = {}
		current = current[key]
	
	# Set the final value
	current[keys[-1]] = value

#endregion

#region Audio Configuration

## Get audio configuration section
static func get_audio_config() -> Dictionary:
	return get_config_value("audio", DEFAULT_CONFIG.audio)

## Audio file path
static func get_audio_file_path() -> String:
	return get_config_value("audio.default_file", "res://audio/SoS.wav")

static func set_audio_file_path(path: String) -> void:
	set_config_value("audio.default_file", path)

## Audio amplifiers
static func get_audio_bass_amplifier() -> float:
	return get_config_value("audio.amplifiers.bass", 15.0)

static func set_audio_bass_amplifier(value: float) -> void:
	set_config_value("audio.amplifiers.bass", value)

static func get_audio_mid_amplifier() -> float:
	return get_config_value("audio.amplifiers.mid", 12.0)

static func set_audio_mid_amplifier(value: float) -> void:
	set_config_value("audio.amplifiers.mid", value)

static func get_audio_treble_amplifier() -> float:
	return get_config_value("audio.amplifiers.treble", 10.0)

static func set_audio_treble_amplifier(value: float) -> void:
	set_config_value("audio.amplifiers.treble", value)

static func get_audio_overall_gain() -> float:
	return get_config_value("audio.amplifiers.overall", 3.0)

static func set_audio_overall_gain(value: float) -> void:
	set_config_value("audio.amplifiers.overall", value)

## Beat detection
static func get_beat_threshold() -> float:
	return get_config_value("audio.beat_detection.threshold_multiplier", 1.3)

static func set_beat_threshold(value: float) -> void:
	set_config_value("audio.beat_detection.threshold_multiplier", value)

static func get_beat_min_interval() -> float:
	return get_config_value("audio.beat_detection.min_interval", 0.12)

static func set_beat_min_interval(value: float) -> void:
	set_config_value("audio.beat_detection.min_interval", value)

static func get_beat_duration() -> float:
	return get_config_value("audio.beat_detection.duration", 0.4)

static func set_beat_duration(value: float) -> void:
	set_config_value("audio.beat_detection.duration", value)

## Audio analysis
static func get_fft_size() -> int:
	return get_config_value("audio.analysis.fft_size", 2048)

static func get_smoothing_factor() -> float:
	return get_config_value("audio.analysis.smoothing_factor", 0.08)

static func get_sample_rate() -> float:
	return get_config_value("audio.analysis.sample_rate", 44100.0)

#endregion

#region Visual Configuration

## Get visual configuration section
static func get_visual_config() -> Dictionary:
	return get_config_value("visual", DEFAULT_CONFIG.visual)

## Shader paths
static func get_default_shader_path() -> String:
	return get_config_value("visual.shaders.default_shader", "res://shaders/kaldao.gdshader")

static func get_kaleidoscope_shader_path() -> String:
	return get_config_value("visual.shaders.kaleidoscope_shader", "res://shaders/kaleidoscope.gdshader")

static func get_koch_shader_path() -> String:
	return get_config_value("visual.shaders.koch_shader", "res://shaders/koch.gdshader")

## Visual effects
static func get_auto_fade_delay() -> float:
	return get_config_value("visual.effects.auto_fade_delay", 1.5)

static func set_auto_fade_delay(value: float) -> void:
	set_config_value("visual.effects.auto_fade_delay", value)

static func get_startup_menu_duration() -> float:
	return get_config_value("visual.effects.startup_menu_duration", 8.0)

static func set_startup_menu_duration(value: float) -> void:
	set_config_value("visual.effects.startup_menu_duration", value)

static func get_parameter_fade_duration() -> float:
	return get_config_value("visual.effects.parameter_fade_duration", 1.0)

static func get_beat_effect_duration() -> float:
	return get_config_value("visual.effects.beat_effect_duration", 0.4)

## Color settings
static func get_default_palette() -> String:
	return get_config_value("visual.colors.default_palette", "bw")

static func get_color_transition_speed() -> float:
	return get_config_value("visual.colors.color_transition_speed", 0.5)

#endregion

#region UI Configuration

## Get UI configuration section
static func get_ui_config() -> Dictionary:
	return get_config_value("ui", DEFAULT_CONFIG.ui)

## Timeline settings
static func get_timeline_height() -> int:
	return get_config_value("ui.timeline.height", 60)

static func get_timeline_margin() -> int:
	return get_config_value("ui.timeline.margin", 20)

static func get_timeline_update_interval() -> float:
	return get_config_value("ui.timeline.update_interval", 0.1)

## Menu settings
static func get_menu_fade_duration() -> float:
	return get_config_value("ui.menu.fade_duration", 1.0)

static func get_menu_background_opacity() -> float:
	return get_config_value("ui.menu.background_opacity", 0.8)

static func get_menu_text_size() -> int:
	return get_config_value("ui.menu.text_size", 12)

## Parameter display settings
static func get_parameter_show_duration() -> float:
	return get_config_value("ui.parameter_display.show_duration", 3.0)

static func get_parameter_fade_duration() -> float:
	return get_config_value("ui.parameter_display.fade_duration", 1.0)

#endregion

#region Input Configuration

## Get input configuration section
static func get_input_config() -> Dictionary:
	return get_config_value("input", DEFAULT_CONFIG.input)

## Input settings
static func is_debug_mode() -> bool:
	return get_config_value("input.debug_mode", false)

static func set_debug_mode(enabled: bool) -> void:
	set_config_value("input.debug_mode", enabled)

static func get_double_tap_threshold() -> float:
	return get_config_value("input.double_tap_threshold", 0.3)

static func get_key_repeat_delay() -> float:
	return get_config_value("input.key_repeat_delay", 0.1)

static func get_mouse_sensitivity() -> float:
	return get_config_value("input.mouse_sensitivity", 1.0)

#endregion

#region Performance Configuration

## Get performance configuration section
static func get_performance_config() -> Dictionary:
	return get_config_value("performance", DEFAULT_CONFIG.performance)

## Performance settings
static func get_target_fps() -> int:
	return get_config_value("performance.target_fps", 60)

static func is_vsync_enabled() -> bool:
	return get_config_value("performance.vsync_enabled", true)

static func get_debug_print_interval() -> int:
	return get_config_value("performance.debug_print_interval", 30)

static func get_max_audio_history() -> int:
	return get_config_value("performance.max_audio_history", 180)

#endregion

#region File Paths Configuration

## Get file paths configuration section
static func get_files_config() -> Dictionary:
	return get_config_value("files", DEFAULT_CONFIG.files)

## File paths
static func get_screenshot_dir() -> String:
	return get_config_value("files.screenshot_dir", "res://data/screenshots/")

static func get_settings_dir() -> String:
	return get_config_value("files.settings_dir", "res://data/config/")

static func get_audio_dir() -> String:
	return get_config_value("files.audio_dir", "res://audio/")

static func get_shader_dir() -> String:
	return get_config_value("files.shader_dir", "res://shaders/")

#endregion

#region Batch Configuration Methods

## Set multiple audio amplifiers at once
static func set_audio_amplifiers(bass: float, mid: float, treble: float, overall: float) -> void:
	set_audio_bass_amplifier(bass)
	set_audio_mid_amplifier(mid)
	set_audio_treble_amplifier(treble)
	set_audio_overall_gain(overall)

## Set beat detection parameters
static func set_beat_detection_params(threshold: float, min_interval: float, duration: float) -> void:
	set_beat_threshold(threshold)
	set_beat_min_interval(min_interval)
	set_beat_duration(duration)

## Get all audio amplifiers as a dictionary
static func get_audio_amplifiers() -> Dictionary:
	return {
		"bass": get_audio_bass_amplifier(),
		"mid": get_audio_mid_amplifier(),
		"treble": get_audio_treble_amplifier(),
		"overall": get_audio_overall_gain()
	}

## Get all beat detection parameters as a dictionary
static func get_beat_detection_params() -> Dictionary:
	return {
		"threshold": get_beat_threshold(),
		"min_interval": get_beat_min_interval(),
		"duration": get_beat_duration()
	}

#endregion

#region Utility Methods

## Get the full configuration for debugging
static func get_full_config() -> Dictionary:
	if not _is_loaded:
		load_config()
	return _config.duplicate(true)

## Validate configuration integrity
static func validate_config() -> bool:
	if not _is_loaded:
		load_config()
	
	# Check version compatibility
	var config_version = get_config_value("version", "0.0")
	if config_version != _config_version:
		push_warning("ConfigManager: Configuration version mismatch. Expected %s, got %s" % [_config_version, config_version])
	
	# Validate required sections exist
	var required_sections = ["audio", "visual", "input", "ui", "performance", "files"]
	for section in required_sections:
		if not get_config_value(section):
			push_error("ConfigManager: Missing required configuration section: %s" % section)
			return false
	
	return true

## Export configuration to a specific file
static func export_config(file_path: String) -> bool:
	if not _is_loaded:
		load_config()
	
	var json_string = JSON.stringify(_config, "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		print("ConfigManager: Configuration exported to %s" % file_path)
		return true
	else:
		push_error("ConfigManager: Failed to export configuration to %s" % file_path)
		return false

## Import configuration from a specific file
static func import_config(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("ConfigManager: Cannot open file for import: %s" % file_path)
		return false
	
	var success = _load_from_file(file, "imported config")
	file.close()
	
	if success:
		_merge_with_defaults()
		_is_loaded = true
		print("ConfigManager: Configuration imported from %s" % file_path)
	
	return success

#endregion

class_name ConfigManager
extends RefCounted

# Configuration constants
const CONFIG_FILE_PATH = "res://data/config/app_config.json"
const SETTINGS_DIR = "res://data/config/"
const QUICK_SAVE_FILE = "fractal_settings_current.json"

# Default configuration values
const DEFAULT_CONFIG = {
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
			"duration": 0.4
		},
		"frequency_ranges": {
			"bass_min": 20.0,
			"bass_max": 200.0,
			"mid_min": 200.0,
			"mid_max": 3000.0,
			"treble_min": 3000.0,
			"treble_max": 20000.0
		}
	},
	"visual": {
		"default_shader": "res://shaders/kaldao.gdshader",
		"screenshot_dir": "res://data/screenshots/",
		"auto_fade_delay": 1.5,
		"startup_menu_duration": 8.0
	},
	"input": {
		"debug_mode": false,
		"double_tap_threshold": 0.3
	},
	"performance": {
		"fft_size": 2048,
		"spectrum_buffer_length": 2.0,
		"smoothing_factor": 0.08,
		"debug_print_interval": 30
	}
}

static var _config: Dictionary = {}
static var _is_loaded: bool = false

static func load_config() -> bool:
	if _is_loaded:
		return true
	
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			_config = json.data
			_merge_with_defaults()
			_is_loaded = true
			print("ConfigManager: Configuration loaded from file")
			return true
		else:
			print("ConfigManager: Error parsing config file, using defaults")
	else:
		print("ConfigManager: Config file not found, using defaults")
	
	# Use defaults if file doesn't exist or is invalid
	_config = DEFAULT_CONFIG.duplicate(true)
	_is_loaded = true
	save_config()  # Create the config file with defaults
	return true

static func save_config() -> bool:
	var json_string = JSON.stringify(_config, "\t")
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		print("ConfigManager: Configuration saved to file")
		return true
	else:
		print("ConfigManager: Error saving configuration file")
		return false

static func _merge_with_defaults():
	"""Merge loaded config with defaults to ensure all keys exist"""
	_config = _deep_merge(DEFAULT_CONFIG, _config)

static func _deep_merge(default_dict: Dictionary, user_dict: Dictionary) -> Dictionary:
	"""Deep merge two dictionaries, with user_dict taking precedence"""
	var result = default_dict.duplicate(true)
	
	for key in user_dict:
		if key in result and typeof(result[key]) == TYPE_DICTIONARY and typeof(user_dict[key]) == TYPE_DICTIONARY:
			result[key] = _deep_merge(result[key], user_dict[key])
		else:
			result[key] = user_dict[key]
	
	return result

# Getter methods for configuration values
static func get_audio_config() -> Dictionary:
	if not _is_loaded:
		load_config()
	return _config.get("audio", DEFAULT_CONFIG.audio)

static func get_visual_config() -> Dictionary:
	if not _is_loaded:
		load_config()
	return _config.get("visual", DEFAULT_CONFIG.visual)

static func get_input_config() -> Dictionary:
	if not _is_loaded:
		load_config()
	return _config.get("input", DEFAULT_CONFIG.input)

static func get_performance_config() -> Dictionary:
	if not _is_loaded:
		load_config()
	return _config.get("performance", DEFAULT_CONFIG.performance)

static func get_config_value(path: String, default_value = null):
	"""Get a config value using dot notation (e.g., 'audio.amplifiers.bass')"""
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

static func set_config_value(path: String, value):
	"""Set a config value using dot notation"""
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

# Convenience methods for common config values
static func get_audio_file_path() -> String:
	return get_config_value("audio.default_file", "res://audio/SoS.wav")

static func get_bass_amplifier() -> float:
	return get_config_value("audio.amplifiers.bass", 15.0)

static func get_mid_amplifier() -> float:
	return get_config_value("audio.amplifiers.mid", 12.0)

static func get_treble_amplifier() -> float:
	return get_config_value("audio.amplifiers.treble", 10.0)

static func get_overall_gain() -> float:
	return get_config_value("audio.amplifiers.overall", 3.0)

static func get_beat_threshold() -> float:
	return get_config_value("audio.beat_detection.threshold_multiplier", 1.3)

static func get_beat_min_interval() -> float:
	return get_config_value("audio.beat_detection.min_interval", 0.12)

static func get_beat_duration() -> float:
	return get_config_value("audio.beat_detection.duration", 0.4)

static func get_screenshot_dir() -> String:
	return get_config_value("visual.screenshot_dir", "res://data/screenshots/")

static func get_auto_fade_delay() -> float:
	return get_config_value("visual.auto_fade_delay", 1.5)

static func get_startup_menu_duration() -> float:
	return get_config_value("visual.startup_menu_duration", 8.0)

static func get_fft_size() -> int:
	return get_config_value("performance.fft_size", 2048)

static func get_smoothing_factor() -> float:
	return get_config_value("performance.smoothing_factor", 0.08)

static func is_debug_mode() -> bool:
	return get_config_value("input.debug_mode", false)

# Methods to update common config values
static func set_audio_amplifiers(bass: float, mid: float, treble: float, overall: float):
	set_config_value("audio.amplifiers.bass", bass)
	set_config_value("audio.amplifiers.mid", mid)
	set_config_value("audio.amplifiers.treble", treble)
	set_config_value("audio.amplifiers.overall", overall)

static func set_beat_detection_params(threshold: float, min_interval: float, duration: float):
	set_config_value("audio.beat_detection.threshold_multiplier", threshold)
	set_config_value("audio.beat_detection.min_interval", min_interval)
	set_config_value("audio.beat_detection.duration", duration)

static func set_debug_mode(enabled: bool):
	set_config_value("input.debug_mode", enabled)

# Reset configuration to defaults
static func reset_to_defaults():
	_config = DEFAULT_CONFIG.duplicate(true)
	save_config()
	print("ConfigManager: Configuration reset to defaults")

# Get the full configuration for debugging
static func get_full_config() -> Dictionary:
	if not _is_loaded:
		load_config()
	return _config.duplicate(true)

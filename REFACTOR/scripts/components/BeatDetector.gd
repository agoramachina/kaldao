class_name BeatDetector
extends RefCounted

## BeatDetector - Isolated Beat Detection Component
##
## This component handles beat detection using multiple algorithms and provides
## configurable sensitivity and timing. It's designed to work with the AudioAnalyzer
## but can operate independently with bass level input.
##
## Usage:
##   var detector = BeatDetector.new()
##   detector.initialize()
##   detector.process_bass_level(bass_level, delta)

# Signals for beat detection
signal beat_detected(intensity: float)

# Beat detection history and state
var _bass_history: Array[float] = []
var _last_beat_time: float = 0.0
var _beat_reset_timer: float = 0.0

# Configuration settings (loaded from ConfigManager)
var _detection_settings: Dictionary = {}
var _timing_settings: Dictionary = {}

# Debug settings
var _debug_enabled: bool = false
var _debug_frame_counter: int = 0

# Initialization state
var _is_initialized: bool = false

#region Initialization

## Initialize the beat detector with configuration
## @return: True if initialization was successful
func initialize() -> bool:
	if _is_initialized:
		print("BeatDetector: Already initialized")
		return true
	
	# Load configuration
	_load_configuration()
	
	_is_initialized = true
	print("BeatDetector: Initialized successfully")
	return true

## Load configuration from ConfigManager
func _load_configuration() -> void:
	print("BeatDetector: Loading configuration...")
	
	# Load detection settings
	_detection_settings = {
		"threshold_multiplier": ConfigManager.get_beat_threshold(),
		"sensitivity": ConfigManager.get_config_value("audio.beat_detection.sensitivity", 0.8),
		"dynamic_threshold": ConfigManager.get_config_value("audio.beat_detection.dynamic_threshold", true),
		"multiple_methods": ConfigManager.get_config_value("audio.beat_detection.multiple_methods", true),
		"variance_threshold": ConfigManager.get_config_value("audio.beat_detection.variance_threshold", 2.0)
	}
	
	# Load timing settings
	_timing_settings = {
		"min_interval": ConfigManager.get_beat_min_interval(),
		"duration": ConfigManager.get_beat_duration(),
		"history_size": ConfigManager.get_max_audio_history(),
		"recent_window": ConfigManager.get_config_value("audio.beat_detection.recent_window", 30),
		"medium_window": ConfigManager.get_config_value("audio.beat_detection.medium_window", 90)
	}
	
	# Load debug settings
	_debug_enabled = ConfigManager.is_debug_mode()
	
	print("BeatDetector: Configuration loaded")
	print("  Detection - Threshold: %.2f, Sensitivity: %.2f" % [_detection_settings.threshold_multiplier, _detection_settings.sensitivity])
	print("  Timing - Min Interval: %.3fs, Duration: %.2fs, History: %d" % [_timing_settings.min_interval, _timing_settings.duration, _timing_settings.history_size])

#endregion

#region Beat Detection Processing

## Process audio analysis for beat detection
## @param delta: Time elapsed since last frame
func process_audio(delta: float) -> void:
	if not _is_initialized:
		return
	
	# Update beat effect timer
	if _beat_reset_timer > 0.0:
		_beat_reset_timer -= delta

## Process bass level for beat detection
## @param bass_level: Current bass frequency level
## @param delta: Time elapsed since last frame
func process_bass_level(bass_level: float, delta: float) -> void:
	if not _is_initialized:
		return
	
	# Add to history
	_bass_history.append(bass_level)
	
	# Maintain history size
	if _bass_history.size() > _timing_settings.history_size:
		_bass_history.pop_front()
	
	# Detect beats
	_detect_beats()
	
	# Update timers
	if _beat_reset_timer > 0.0:
		_beat_reset_timer -= delta

## Main beat detection algorithm
func _detect_beats() -> void:
	# Need minimum history for reliable detection
	if _bass_history.size() < 10:
		return
	
	# Check timing constraints
	var current_time = _get_precise_time()
	var time_since_last_beat = current_time - _last_beat_time
	
	if time_since_last_beat < _timing_settings.min_interval:
		return
	
	# Calculate averages and statistics
	var stats = _calculate_bass_statistics()
	
	# Apply dynamic threshold adjustment
	var dynamic_threshold = _calculate_dynamic_threshold(stats)
	
	# Run multiple detection methods
	var detection_results = _run_detection_methods(stats, dynamic_threshold)
	
	# Determine if beat is detected
	var beat_triggered = _evaluate_detection_results(detection_results)
	
	if beat_triggered:
		var intensity = _calculate_beat_intensity(stats, detection_results)
		_trigger_beat(intensity, detection_results)

## Calculate bass level statistics for detection
## @return: Dictionary with statistical information
func _calculate_bass_statistics() -> Dictionary:
	var current_bass = _bass_history[-1]
	var history_size = _bass_history.size()
	
	# Calculate different window averages
	var recent_size = min(history_size, _timing_settings.recent_window)
	var medium_size = min(history_size, _timing_settings.medium_window)
	
	# Recent average (immediate context)
	var recent_avg = 0.0
	for i in range(history_size - recent_size, history_size):
		recent_avg += _bass_history[i]
	recent_avg /= recent_size
	
	# Medium-term average (broader context)
	var medium_avg = 0.0
	for i in range(history_size - medium_size, history_size):
		medium_avg += _bass_history[i]
	medium_avg /= medium_size
	
	# Overall average
	var overall_avg = 0.0
	for val in _bass_history:
		overall_avg += val
	overall_avg /= history_size
	
	# Calculate variance and standard deviation
	var variance = 0.0
	for val in _bass_history:
		variance += (val - overall_avg) * (val - overall_avg)
	variance /= history_size
	var std_dev = sqrt(variance)
	
	return {
		"current": current_bass,
		"recent_avg": recent_avg,
		"medium_avg": medium_avg,
		"overall_avg": overall_avg,
		"variance": variance,
		"std_dev": std_dev,
		"history_size": history_size
	}

## Calculate dynamic threshold based on audio content
## @param stats: Bass statistics dictionary
## @return: Adjusted threshold multiplier
func _calculate_dynamic_threshold(stats: Dictionary) -> float:
	var base_threshold = _detection_settings.threshold_multiplier
	
	if not _detection_settings.dynamic_threshold:
		return base_threshold
	
	var dynamic_threshold = base_threshold
	
	# Adjust based on audio dynamics
	if stats.std_dev > 0.1:
		# If audio is dynamic, lower threshold for better sensitivity
		dynamic_threshold *= 0.8
	elif stats.std_dev < 0.05:
		# If audio is quiet/static, raise threshold to avoid false positives
		dynamic_threshold *= 1.3
	
	# Apply sensitivity adjustment
	dynamic_threshold *= (2.0 - _detection_settings.sensitivity)
	
	return dynamic_threshold

## Run multiple beat detection methods
## @param stats: Bass statistics dictionary
## @param threshold: Dynamic threshold value
## @return: Dictionary with detection method results
func _run_detection_methods(stats: Dictionary, threshold: float) -> Dictionary:
	var results = {}
	
	# Method 1: Basic threshold detection
	results["basic"] = stats.current > stats.overall_avg * threshold
	
	# Method 2: Recent context detection
	results["recent"] = stats.current > stats.recent_avg * (threshold * 0.9)
	
	# Method 3: Variance-based detection
	results["variance"] = stats.current > (stats.overall_avg + stats.std_dev * _detection_settings.variance_threshold)
	
	# Method 4: Medium-term context detection
	results["medium"] = stats.current > stats.medium_avg * (threshold * 1.1)
	
	# Method 5: Relative intensity detection
	var relative_intensity = stats.current / max(stats.overall_avg, 0.01)
	results["intensity"] = relative_intensity > threshold
	
	return results

## Evaluate detection results to determine if beat is triggered
## @param results: Detection method results dictionary
## @return: True if beat should be triggered
func _evaluate_detection_results(results: Dictionary) -> bool:
	if not _detection_settings.multiple_methods:
		# Use only basic method if multiple methods disabled
		return results.get("basic", false)
	
	# Count positive detections
	var positive_count = 0
	var total_methods = results.size()
	
	for method in results:
		if results[method]:
			positive_count += 1
	
	# Require at least 2 out of 5 methods to agree (adjustable threshold)
	var required_agreement = max(2, int(total_methods * 0.4))
	return positive_count >= required_agreement

## Calculate beat intensity from detection results
## @param stats: Bass statistics dictionary
## @param results: Detection method results
## @return: Beat intensity value
func _calculate_beat_intensity(stats: Dictionary, results: Dictionary) -> float:
	# Base intensity from current level vs average
	var base_intensity = stats.current / max(stats.overall_avg, 0.01)
	
	# Boost intensity based on how many methods detected the beat
	var method_count = 0
	for method in results:
		if results[method]:
			method_count += 1
	
	var method_boost = 1.0 + (method_count - 1) * 0.2  # 20% boost per additional method
	
	# Factor in variance (more dynamic audio = higher intensity)
	var variance_factor = 1.0 + min(stats.std_dev * 2.0, 1.0)
	
	# Calculate final intensity
	var intensity = base_intensity * method_boost * variance_factor
	
	# Apply sensitivity scaling
	intensity *= _detection_settings.sensitivity
	
	return clamp(intensity, 0.1, 10.0)

## Trigger a beat detection event
## @param intensity: Beat intensity value
## @param results: Detection method results for debugging
func _trigger_beat(intensity: float, results: Dictionary) -> void:
	_last_beat_time = _get_precise_time()
	_beat_reset_timer = _timing_settings.duration
	
	# Emit beat detected signal
	beat_detected.emit(intensity)
	
	# Debug output
	if _debug_enabled:
		var method_names = []
		for method in results:
			if results[method]:
				method_names.append(method.to_upper())
		
		var stats = _calculate_bass_statistics()
		print("BeatDetector: BEAT [%s]! Intensity: %.2f, Bass: %.3f vs Avg: %.3f" % [
			" ".join(method_names),
			intensity,
			stats.current,
			stats.overall_avg
		])

## Get precise time for beat timing
## @return: Current time in seconds with sub-second precision
func _get_precise_time() -> float:
	var time_dict = Time.get_time_dict_from_system()
	return time_dict.hour * 3600 + time_dict.minute * 60 + time_dict.second + (Engine.get_process_frames() % 60) / 60.0

#endregion

#region Public API

## Check if a beat effect is currently active
## @return: True if beat effect is active
func is_beat_active() -> bool:
	return _beat_reset_timer > 0.0

## Get remaining beat effect time
## @return: Remaining time in seconds
func get_beat_time_remaining() -> float:
	return max(_beat_reset_timer, 0.0)

## Get beat effect progress (0.0 to 1.0)
## @return: Progress from 1.0 (just triggered) to 0.0 (finished)
func get_beat_progress() -> float:
	if _timing_settings.duration <= 0.0:
		return 0.0
	return clamp(_beat_reset_timer / _timing_settings.duration, 0.0, 1.0)

## Update detection sensitivity in real-time
## @param threshold: New threshold multiplier
## @param min_interval: New minimum interval between beats
## @param sensitivity: New sensitivity value (0.0-1.0)
func update_detection_settings(threshold: float, min_interval: float, sensitivity: float = 0.8) -> void:
	_detection_settings.threshold_multiplier = threshold
	_detection_settings.sensitivity = clamp(sensitivity, 0.0, 1.0)
	_timing_settings.min_interval = min_interval
	
	print("BeatDetector: Updated settings - Threshold: %.2f, Interval: %.3fs, Sensitivity: %.2f" % [threshold, min_interval, sensitivity])

## Update timing settings
## @param duration: Beat effect duration
## @param history_size: Maximum history size
## @param recent_window: Recent average window size
## @param medium_window: Medium average window size
func update_timing_settings(duration: float, history_size: int = 180, recent_window: int = 30, medium_window: int = 90) -> void:
	_timing_settings.duration = duration
	_timing_settings.history_size = history_size
	_timing_settings.recent_window = recent_window
	_timing_settings.medium_window = medium_window
	
	# Trim history if needed
	while _bass_history.size() > history_size:
		_bass_history.pop_front()
	
	print("BeatDetector: Updated timing - Duration: %.2fs, History: %d, Windows: %d/%d" % [duration, history_size, recent_window, medium_window])

## Enable or disable multiple detection methods
## @param enabled: Whether to use multiple methods
func set_multiple_methods_enabled(enabled: bool) -> void:
	_detection_settings.multiple_methods = enabled
	print("BeatDetector: Multiple detection methods %s" % ("enabled" if enabled else "disabled"))

## Enable or disable dynamic threshold adjustment
## @param enabled: Whether to use dynamic threshold
func set_dynamic_threshold_enabled(enabled: bool) -> void:
	_detection_settings.dynamic_threshold = enabled
	print("BeatDetector: Dynamic threshold %s" % ("enabled" if enabled else "disabled"))

## Get current beat detection statistics for debugging
## @return: Dictionary with detection statistics
func get_detection_stats() -> Dictionary:
	if _bass_history.size() == 0:
		return {"error": "No audio history"}
	
	var stats = _calculate_bass_statistics()
	var dynamic_threshold = _calculate_dynamic_threshold(stats)
	
	return {
		"current_bass": stats.current,
		"averages": {
			"recent": stats.recent_avg,
			"medium": stats.medium_avg,
			"overall": stats.overall_avg
		},
		"variance": stats.variance,
		"std_dev": stats.std_dev,
		"threshold": dynamic_threshold,
		"history_size": stats.history_size,
		"beat_active": is_beat_active(),
		"beat_progress": get_beat_progress(),
		"last_beat_time": _last_beat_time,
		"settings": {
			"detection": _detection_settings.duplicate(),
			"timing": _timing_settings.duplicate()
		}
	}

## Get detection information for debugging
## @return: Dictionary with detection information
func get_detection_info() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"detection_settings": _detection_settings.duplicate(),
		"timing_settings": _timing_settings.duplicate(),
		"history_size": _bass_history.size(),
		"beat_active": is_beat_active(),
		"debug_enabled": _debug_enabled
	}

## Check if the detector is properly initialized
## @return: True if initialized and ready
func is_ready() -> bool:
	return _is_initialized

## Enable or disable debug output
## @param enabled: Whether to enable debug output
func set_debug_enabled(enabled: bool) -> void:
	_debug_enabled = enabled
	print("BeatDetector: Debug output %s" % ("enabled" if enabled else "disabled"))

#endregion

#region Utility Methods

## Clear beat detection history
func clear_history() -> void:
	_bass_history.clear()
	_last_beat_time = 0.0
	_beat_reset_timer = 0.0
	print("BeatDetector: History cleared")

## Force trigger a beat (for testing)
## @param intensity: Beat intensity to use
func force_trigger_beat(intensity: float = 2.0) -> void:
	_trigger_beat(intensity, {"manual": true})
	print("BeatDetector: Manually triggered beat with intensity %.2f" % intensity)

## Get average bass level over a time window
## @param window_size: Number of recent samples to average
## @return: Average bass level
func get_average_bass_level(window_size: int = 30) -> float:
	if _bass_history.size() == 0:
		return 0.0
	
	var actual_window = min(window_size, _bass_history.size())
	var sum = 0.0
	
	for i in range(_bass_history.size() - actual_window, _bass_history.size()):
		sum += _bass_history[i]
	
	return sum / actual_window

## Get bass level variance over a time window
## @param window_size: Number of recent samples to analyze
## @return: Variance value
func get_bass_variance(window_size: int = 60) -> float:
	if _bass_history.size() < 2:
		return 0.0
	
	var actual_window = min(window_size, _bass_history.size())
	var avg = get_average_bass_level(actual_window)
	var variance = 0.0
	
	for i in range(_bass_history.size() - actual_window, _bass_history.size()):
		var diff = _bass_history[i] - avg
		variance += diff * diff
	
	return variance / actual_window

#endregion

#region Cleanup

## Clean up resources and reset state
func cleanup() -> void:
	print("BeatDetector: Cleaning up resources...")
	
	# Clear history and state
	_bass_history.clear()
	_last_beat_time = 0.0
	_beat_reset_timer = 0.0
	_debug_frame_counter = 0
	
	# Clear configuration
	_detection_settings.clear()
	_timing_settings.clear()
	
	_is_initialized = false
	print("BeatDetector: Cleanup complete")

#endregion

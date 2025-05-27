class_name AudioManager
extends AudioStreamPlayer

## AudioManager - Refactored Audio System with Clean Architecture
##
## This refactored AudioManager uses the new architecture with ConfigManager for settings,
## EventBus for communication, and separate components for beat detection and analysis.
## It maintains backward compatibility while providing a much cleaner interface.
##
## Usage:
##   var audio_manager = AudioManager.new()
##   audio_manager.initialize()
##   audio_manager.toggle_audio_playback()

# Core audio state
var _audio_enabled: bool = false
var _audio_reactive: bool = false
var _is_paused: bool = false
var _pause_position: float = 0.0

# Audio analysis components
var _audio_analyzer: AudioAnalyzer
var _beat_detector: BeatDetector
var _spectrum_analyzer: AudioEffectSpectrumAnalyzer
var _audio_effect: AudioEffectSpectrumAnalyzerInstance

# Parameter management
var _parameter_manager: ParameterManager
var _base_parameter_values: Dictionary = {}

# Audio reactivity settings (loaded from config)
var _reactivity_settings: Dictionary = {}

# Initialization state
var _is_initialized: bool = false

#region Initialization

## Initialize the audio manager with the new architecture
func initialize() -> bool:
	if _is_initialized:
		print("AudioManager: Already initialized")
		return true
	
	print("AudioManager: Initializing with new architecture...")
	
	# Load configuration
	_load_audio_configuration()
	
	# Load audio file
	if not _load_audio_file():
		push_error("AudioManager: Failed to load audio file")
		return false
	
	# Setup spectrum analyzer
	if not _setup_spectrum_analyzer():
		push_error("AudioManager: Failed to setup spectrum analyzer")
		return false
	
	# Create audio analysis components
	_create_audio_components()
	
	# Setup event connections
	_setup_event_connections()
	
	# Connect to parameter manager if available
	_connect_to_parameter_manager()
	
	_is_initialized = true
	print("AudioManager: Initialization complete")
	return true

## Load audio configuration from ConfigManager
func _load_audio_configuration() -> void:
	print("AudioManager: Loading audio configuration...")
	
	# Load reactivity settings
	_reactivity_settings = {
		"bass_intensity": ConfigManager.get_config_value("audio.reactivity.bass_intensity", 8.0),
		"mid_intensity": ConfigManager.get_config_value("audio.reactivity.mid_intensity", 3.0),
		"treble_intensity": ConfigManager.get_config_value("audio.reactivity.treble_intensity", 2.5),
		"beat_duration": ConfigManager.get_beat_duration(),
		"parameter_mappings": {
			"bass": ["truchet_radius"],
			"mid": ["rotation_speed"],
			"treble": ["zoom_level"],
			"beat": ["kaleidoscope_segments", "zoom_level", "color_intensity"]
		}
	}
	
	print("AudioManager: Audio configuration loaded")

## Load the audio file from configuration
func _load_audio_file() -> bool:
	var audio_file_path = ConfigManager.get_audio_file_path()
	var audio_stream = load(audio_file_path) as AudioStream
	
	if audio_stream:
		stream = audio_stream
		print("AudioManager: Loaded audio file: %s (%.1fs)" % [audio_file_path, audio_stream.get_length()])
		return true
	else:
		push_error("AudioManager: Could not load audio file: %s" % audio_file_path)
		return false

## Setup spectrum analyzer for audio analysis
func _setup_spectrum_analyzer() -> bool:
	print("AudioManager: Setting up spectrum analyzer...")
	
	_spectrum_analyzer = AudioEffectSpectrumAnalyzer.new()
	_spectrum_analyzer.fft_size = ConfigManager.get_fft_size()
	_spectrum_analyzer.buffer_length = ConfigManager.get_config_value("audio.analysis.spectrum_buffer_length", 2.0)
	
	var bus_index = AudioServer.get_bus_index("Master")
	
	# Remove existing spectrum analyzers
	_remove_existing_spectrum_analyzers(bus_index)
	
	# Add our spectrum analyzer
	AudioServer.add_bus_effect(bus_index, _spectrum_analyzer)
	
	# Get the effect instance
	var effect_index = AudioServer.get_bus_effect_count(bus_index) - 1
	_audio_effect = AudioServer.get_bus_effect_instance(bus_index, effect_index) as AudioEffectSpectrumAnalyzerInstance
	
	if _audio_effect:
		print("AudioManager: Spectrum analyzer setup complete")
		return true
	else:
		push_error("AudioManager: Failed to get spectrum analyzer instance")
		return false

## Remove any existing spectrum analyzers to avoid conflicts
func _remove_existing_spectrum_analyzers(bus_index: int) -> void:
	var effect_count = AudioServer.get_bus_effect_count(bus_index)
	for i in range(effect_count - 1, -1, -1):
		var effect = AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectSpectrumAnalyzer:
			AudioServer.remove_bus_effect(bus_index, i)
			print("AudioManager: Removed existing spectrum analyzer")

## Create audio analysis components
func _create_audio_components() -> void:
	print("AudioManager: Creating audio analysis components...")
	
	# Create audio analyzer
	_audio_analyzer = AudioAnalyzer.new()
	_audio_analyzer.initialize(_audio_effect)
	
	# Create beat detector
	_beat_detector = BeatDetector.new()
	_beat_detector.initialize()
	
	# Connect components
	_audio_analyzer.audio_levels_updated.connect(_on_audio_levels_updated)
	_beat_detector.beat_detected.connect(_on_beat_detected)
	
	print("AudioManager: Audio components created")

## Setup event connections with EventBus
func _setup_event_connections() -> void:
	print("AudioManager: Setting up event connections...")
	
	# Connect to EventBus events
	EventBus.connect_to_audio_playback_toggled(_on_audio_playback_toggled)
	EventBus.connect_to_audio_reactive_toggled(_on_audio_reactive_toggled)
	EventBus.connect_to_audio_seek_requested(_on_audio_seek_requested)
	
	# Connect to application lifecycle
	EventBus.connect_to_application_shutting_down(_on_application_shutdown)
	
	print("AudioManager: Event connections established")

## Connect to parameter manager through ServiceLocator
func _connect_to_parameter_manager() -> void:
	_parameter_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
	if _parameter_manager:
		print("AudioManager: Connected to parameter manager")
	else:
		push_warning("AudioManager: Parameter manager not available")

#endregion

#region Audio Playback Control

## Toggle audio playback on/off
## @return: True if audio is now playing
func toggle_audio_playback() -> bool:
	if not stream:
		push_warning("AudioManager: No audio file loaded")
		EventBus.emit_text_update_requested("No audio file loaded")
		return false
	
	var was_playing = playing and not _is_paused
	
	if was_playing:
		_pause_audio()
	elif _is_paused:
		_resume_audio()
	else:
		_start_audio()
	
	var is_now_playing = playing and not _is_paused
	_audio_enabled = is_now_playing
	
	# Emit events
	EventBus.emit_audio_playback_toggled(is_now_playing)
	EventBus.emit_text_update_requested("Audio Playback: %s" % ("ON" if is_now_playing else "OFF"))
	
	return is_now_playing

## Pause audio playback
func _pause_audio() -> void:
	_pause_position = get_playback_position()
	stream_paused = true
	_is_paused = true
	print("AudioManager: Audio paused at %.2fs" % _pause_position)

## Resume audio playback
func _resume_audio() -> void:
	stream_paused = false
	_is_paused = false
	print("AudioManager: Audio resumed from %.2fs" % _pause_position)

## Start audio playback
func _start_audio() -> void:
	if _pause_position > 0:
		play(_pause_position)
	else:
		play()
	_is_paused = false
	_audio_enabled = true
	print("AudioManager: Audio started")

## Seek to a specific position in the audio
## @param timestamp: Position in seconds to seek to
func seek(timestamp: float) -> void:
	if not stream:
		return
	
	timestamp = clamp(timestamp, 0.0, stream.get_length())
	
	if playing:
		play(timestamp)
	else:
		_pause_position = timestamp
	
	print("AudioManager: Seeked to %.2fs" % timestamp)

#endregion

#region Audio Reactivity

## Toggle audio reactivity on/off
## @return: True if audio reactivity is now enabled
func toggle_audio_reactive() -> bool:
	_audio_reactive = not _audio_reactive
	
	if _audio_reactive:
		_enable_audio_reactivity()
	else:
		_disable_audio_reactivity()
	
	# Emit events
	EventBus.emit_audio_reactive_toggled(_audio_reactive)
	var status_text = "Audio Reactive: %s" % ("ON" if _audio_reactive else "OFF")
	if _audio_reactive:
		status_text += "\nVisuals now respond to the music!"
	EventBus.emit_text_update_requested(status_text)
	
	return _audio_reactive

## Enable audio reactivity
func _enable_audio_reactivity() -> void:
	if not _parameter_manager:
		push_warning("AudioManager: Cannot enable reactivity - no parameter manager")
		return
	
	_store_base_parameter_values()
	print("AudioManager: Audio reactivity enabled")

## Disable audio reactivity
func _disable_audio_reactivity() -> void:
	if not _parameter_manager:
		return
	
	_restore_base_parameter_values()
	print("AudioManager: Audio reactivity disabled")

## Store current parameter values as base values for reactivity
func _store_base_parameter_values() -> void:
	if not _parameter_manager:
		return
	
	_base_parameter_values.clear()
	
	# Store values for all parameters that can be affected by audio
	var reactive_params = ["truchet_radius", "color_intensity", "rotation_speed", "zoom_level", "kaleidoscope_segments"]
	
	for param_name in reactive_params:
		_base_parameter_values[param_name] = _parameter_manager.get_parameter_value(param_name)
	
	print("AudioManager: Stored base parameter values for reactivity")

## Restore parameters to their base values
func _restore_base_parameter_values() -> void:
	if not _parameter_manager:
		return
	
	for param_name in _base_parameter_values:
		_parameter_manager.set_parameter_value(param_name, _base_parameter_values[param_name])
	
	print("AudioManager: Restored base parameter values")

#endregion

#region Audio Analysis Processing

## Main processing loop - called every frame
func _process(delta: float) -> void:
	if not _is_initialized or not _audio_enabled or not playing:
		return
	
	# Update audio analysis
	if _audio_analyzer:
		_audio_analyzer.process_audio(delta)
	
	# Update beat detection
	if _beat_detector:
		_beat_detector.process_audio(delta)

## Handle audio level updates from AudioAnalyzer
## @param bass: Bass frequency level
## @param mid: Mid frequency level  
## @param treble: Treble frequency level
func _on_audio_levels_updated(bass: float, mid: float, treble: float) -> void:
	# Emit to EventBus for other components
	EventBus.emit_audio_levels_changed(bass, mid, treble)
	
	# Feed bass level to beat detector
	if _beat_detector:
		_beat_detector.process_bass_level(bass, get_process_delta_time())
	
	# Apply audio reactivity if enabled
	if _audio_reactive and _parameter_manager:
		_apply_audio_reactivity(bass, mid, treble)

## Handle beat detection from BeatDetector
## @param intensity: Beat intensity value
func _on_beat_detected(intensity: float) -> void:
	# Emit to EventBus
	EventBus.emit_beat_detected(intensity)
	
	# Apply beat effects if reactivity is enabled
	if _audio_reactive and _parameter_manager:
		_apply_beat_effects(intensity)

## Apply audio reactivity to visual parameters
## @param bass: Bass frequency level
## @param mid: Mid frequency level
## @param treble: Treble frequency level
func _apply_audio_reactivity(bass: float, mid: float, treble: float) -> void:
	if not _parameter_manager or _base_parameter_values.is_empty():
		return
	
	# Bass affects truchet radius
	if "truchet_radius" in _base_parameter_values:
		var base_radius = _base_parameter_values["truchet_radius"]
		var pulse_amount = bass * _reactivity_settings.bass_intensity * 0.005
		var new_radius = clamp(base_radius + pulse_amount, 0.1, 0.9)
		_parameter_manager.set_parameter_value("truchet_radius", new_radius)
	
	# Mid frequencies affect rotation speed
	if "rotation_speed" in _base_parameter_values:
		var base_rotation = _base_parameter_values["rotation_speed"]
		var rotation_mod = mid * _reactivity_settings.mid_intensity * 0.1
		var new_rotation = clamp(base_rotation + rotation_mod, -2.0, 2.0)
		_parameter_manager.set_parameter_value("rotation_speed", new_rotation)
	
	# Treble affects zoom level
	if "zoom_level" in _base_parameter_values:
		var base_zoom = _base_parameter_values["zoom_level"]
		var zoom_mod = treble * _reactivity_settings.treble_intensity * 1.15
		var new_zoom = clamp(base_zoom + zoom_mod, 0.05, 1.5)
		_parameter_manager.set_parameter_value("zoom_level", new_zoom)

## Apply beat effects to visual parameters
## @param intensity: Beat intensity value
func _apply_beat_effects(intensity: float) -> void:
	if not _parameter_manager or _base_parameter_values.is_empty():
		return
	
	# Kaleidoscope segments beat effect
	if "kaleidoscope_segments" in _base_parameter_values:
		var original_segments = _base_parameter_values["kaleidoscope_segments"]
		var max_change_steps = 12
		var change_steps = randi_range(-max_change_steps, max_change_steps)
		var segment_change = change_steps * 2.0  # Ensure even values
		
		# Scale by intensity
		segment_change *= min(intensity / 2.0, 1.0)
		segment_change = round(segment_change / 2.0) * 2.0  # Keep even
		
		var new_segments = clamp(original_segments + segment_change, 4, 80)
		new_segments = round(new_segments / 2.0) * 2.0  # Force even integer
		
		_parameter_manager.set_parameter_value("kaleidoscope_segments", new_segments)
		
		# Schedule restoration
		_schedule_parameter_restoration("kaleidoscope_segments", original_segments)
	
	# Strong beat effects
	if intensity > 2.0:
		# Zoom burst
		if "zoom_level" in _base_parameter_values:
			var base_zoom = _base_parameter_values["zoom_level"]
			var zoom_burst = base_zoom + (intensity * 0.2)
			_parameter_manager.set_parameter_value("zoom_level", clamp(zoom_burst, 0.05, 2.0))
			_schedule_parameter_restoration("zoom_level", base_zoom)
		
		# Color intensity burst
		if "color_intensity" in _base_parameter_values:
			var base_color = _base_parameter_values["color_intensity"]
			var color_burst = base_color + (intensity * 0.3)
			_parameter_manager.set_parameter_value("color_intensity", clamp(color_burst, 0.5, 4.0))
			_schedule_parameter_restoration("color_intensity", base_color)

## Schedule parameter restoration after beat effects
## @param param_name: Name of parameter to restore
## @param original_value: Original value to restore to
func _schedule_parameter_restoration(param_name: String, original_value: float) -> void:
	# Create a timer for gradual restoration
	var timer = Timer.new()
	timer.wait_time = _reactivity_settings.beat_duration
	timer.one_shot = true
	timer.timeout.connect(_restore_parameter.bind(param_name, original_value, timer))
	add_child(timer)
	timer.start()

## Restore a parameter to its original value
## @param param_name: Name of parameter to restore
## @param original_value: Original value to restore to
## @param timer: Timer object to clean up
func _restore_parameter(param_name: String, original_value: float, timer: Timer) -> void:
	if _parameter_manager and _audio_reactive:
		# Ensure even integers for kaleidoscope segments
		if param_name == "kaleidoscope_segments":
			original_value = round(original_value / 2.0) * 2.0
		
		_parameter_manager.set_parameter_value(param_name, original_value)
	
	# Clean up timer
	timer.queue_free()

#endregion

#region Event Handlers

## Handle audio playback toggle events from EventBus
## @param is_playing: Whether audio should be playing
func _on_audio_playback_toggled(is_playing: bool) -> void:
	# This is called when other components request playback changes
	if is_playing != (playing and not _is_paused):
		toggle_audio_playback()

## Handle audio reactive toggle events from EventBus
## @param is_reactive: Whether audio reactivity should be enabled
func _on_audio_reactive_toggled(is_reactive: bool) -> void:
	# This is called when other components request reactivity changes
	if is_reactive != _audio_reactive:
		toggle_audio_reactive()

## Handle audio seek requests from EventBus
## @param timestamp: Position to seek to
func _on_audio_seek_requested(timestamp: float) -> void:
	seek(timestamp)

## Handle application shutdown
func _on_application_shutdown() -> void:
	cleanup()

#endregion

#region Public API

## Check if audio is currently playing
## @return: True if audio is playing and not paused
func is_playing() -> bool:
	return playing and not _is_paused

## Check if audio reactivity is enabled
## @return: True if audio reactivity is enabled
func is_audio_reactive() -> bool:
	return _audio_reactive

## Get current audio levels
## @return: Dictionary with current audio levels
func get_audio_levels() -> Dictionary:
	if _audio_analyzer:
		return _audio_analyzer.get_current_levels()
	else:
		return {"bass": 0.0, "mid": 0.0, "treble": 0.0, "overall": 0.0}

## Get comprehensive audio status information
## @return: Dictionary with detailed audio status
func get_status_info() -> Dictionary:
	var levels = get_audio_levels()
	var amplifiers = ConfigManager.get_audio_amplifiers()
	
	return {
		"enabled": _audio_enabled,
		"reactive": _audio_reactive,
		"file": ConfigManager.get_audio_file_path(),
		"playing": is_playing(),
		"position": get_playback_position(),
		"duration": stream.get_length() if stream else 0.0,
		"levels": levels,
		"amplifiers": amplifiers,
		"initialized": _is_initialized
	}

## Update audio amplifier settings
## @param bass: Bass amplifier value
## @param mid: Mid amplifier value
## @param treble: Treble amplifier value
## @param overall: Overall gain value
func set_audio_amplifiers(bass: float, mid: float, treble: float, overall: float = 3.0) -> void:
	ConfigManager.set_audio_amplifiers(bass, mid, treble, overall)
	
	# Update audio analyzer if available
	if _audio_analyzer:
		_audio_analyzer.update_amplifiers(bass, mid, treble, overall)
	
	print("AudioManager: Updated amplifiers - Bass: %.1f, Mid: %.1f, Treble: %.1f, Overall: %.1f" % [bass, mid, treble, overall])

## Connect to parameter manager (for backward compatibility)
## @param param_manager: ParameterManager instance
func connect_to_parameter_manager(param_manager: ParameterManager) -> void:
	_parameter_manager = param_manager
	print("AudioManager: Connected to parameter manager (legacy method)")

#endregion

#region Audio Looping

## Handle audio finished signal for looping
func _on_finished() -> void:
	if _audio_enabled:
		play()  # Loop the audio
		print("AudioManager: Audio looped")

#endregion

#region Cleanup

## Clean up resources and connections
func cleanup() -> void:
	print("AudioManager: Cleaning up resources...")
	
	# Stop audio
	if playing:
		stop()
	
	# Clean up components
	if _audio_analyzer:
		_audio_analyzer.cleanup()
		_audio_analyzer = null
	
	if _beat_detector:
		_beat_detector.cleanup()
		_beat_detector = null
	
	# Remove spectrum analyzer
	if _spectrum_analyzer:
		var bus_index = AudioServer.get_bus_index("Master")
		_remove_existing_spectrum_analyzers(bus_index)
		_spectrum_analyzer = null
		_audio_effect = null
	
	# Clear state
	_base_parameter_values.clear()
	_reactivity_settings.clear()
	_parameter_manager = null
	_is_initialized = false
	
	print("AudioManager: Cleanup complete")

#endregion

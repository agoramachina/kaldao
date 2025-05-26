extends RefCounted
class_name AudioReactivityManager

# Signals
signal audio_parameter_changed(param_name: String, value: float)

# Audio reactivity state
var audio_reactive = false
var base_values = {}
var bass_pulse_intensity = 1.0
var mid_rotation_intensity = 1.0
var treble_zoom_intensity = 1.0

# Parameter references
var parameter_manager: ParameterManager

# Smoothing for audio responsiveness
var current_bass_influence = 0.0
var current_mid_influence = 0.0
var current_treble_influence = 0.0
var smoothing_factor = 0.1

# Timer for beat effect reset
var beat_reset_timer = 0.0
var beat_duration = 0.2  # How long beat effects last
var original_segments = 10.0

func connect_to_parameter_manager(param_manager: ParameterManager):
	parameter_manager = param_manager
	print("AudioReactivityManager: Connected to parameter manager")

func toggle_audio_reactive():
	audio_reactive = !audio_reactive
	
	if not audio_reactive:
		# Reset to base values when turning off audio reactivity
		restore_base_values()
		print("AudioReactivityManager: Audio reactivity disabled")
	else:
		# Store base values when turning on audio reactivity
		store_base_values()
		print("AudioReactivityManager: Audio reactivity enabled")
	
	return audio_reactive

func store_base_values():
	if not parameter_manager:
		print("AudioReactivityManager: ERROR - No parameter manager!")
		return
		
	base_values["truchet_radius"] = parameter_manager.get_parameter_value("truchet_radius")
	base_values["color_intensity"] = parameter_manager.get_parameter_value("color_intensity")
	base_values["rotation_speed"] = parameter_manager.get_parameter_value("rotation_speed")
	base_values["zoom_level"] = parameter_manager.get_parameter_value("zoom_level")
	base_values["kaleidoscope_segments"] = parameter_manager.get_parameter_value("kaleidoscope_segments")
	
	print("AudioReactivityManager: Stored base values: ", base_values)

func restore_base_values():
	if not parameter_manager:
		return
		
	for param_name in base_values:
		parameter_manager.set_parameter_value(param_name, base_values[param_name])
	
	# Reset influence values
	current_bass_influence = 0.0
	current_mid_influence = 0.0
	current_treble_influence = 0.0
	
	print("AudioReactivityManager: Restored base values")

func on_bass_detected(intensity: float):
	if not audio_reactive or not parameter_manager:
		return
	
	print("DEBUG: AudioReactivity - Bass: %.3f (reactive: %s)" % [intensity, audio_reactive])
	
	# Smooth the bass influence
	current_bass_influence = lerp(current_bass_influence, intensity, smoothing_factor)
	
	# Bass affects truchet radius (center circle pulsing)
	var base_radius = base_values.get("truchet_radius", 0.35)
	var pulse_amount = current_bass_influence * bass_pulse_intensity * 0.2
	var new_value = base_radius + pulse_amount
	
	# Clamp to reasonable values
	new_value = clamp(new_value, 0.1, 0.8)
	parameter_manager.set_parameter_value("truchet_radius", new_value)
	
	# Bass also affects color intensity
	var base_color = base_values.get("color_intensity", 1.0)
	var color_boost = current_bass_influence * 0.5
	var new_color = base_color + color_boost
	new_color = clamp(new_color, 0.5, 2.0)
	parameter_manager.set_parameter_value("color_intensity", new_color)

func on_mid_detected(intensity: float):
	if not audio_reactive or not parameter_manager:
		return
	
	# Smooth the mid influence
	current_mid_influence = lerp(current_mid_influence, intensity, smoothing_factor)
	
	# Mid frequencies affect rotation speed
	var base_rotation = base_values.get("rotation_speed", 0.025)
	var rotation_mod = current_mid_influence * mid_rotation_intensity * 0.05
	var new_value = base_rotation + rotation_mod
	
	# Clamp to reasonable values
	new_value = clamp(new_value, -1.0, 1.0)
	parameter_manager.set_parameter_value("rotation_speed", new_value)

func on_treble_detected(intensity: float):
	if not audio_reactive or not parameter_manager:
		return
	
	# Smooth the treble influence
	current_treble_influence = lerp(current_treble_influence, intensity, smoothing_factor)
	
	# Treble affects zoom level for high-frequency sparkle effects
	var base_zoom = base_values.get("zoom_level", 0.3)
	var zoom_mod = current_treble_influence * treble_zoom_intensity * 0.1
	var new_value = base_zoom + zoom_mod
	
	# Clamp to reasonable values
	new_value = clamp(new_value, 0.1, 1.0)
	parameter_manager.set_parameter_value("zoom_level", new_value)

func on_beat_detected():
	if not audio_reactive or not parameter_manager:
		return
	
	# Store original segments value if not already stored
	if "kaleidoscope_segments" in base_values:
		original_segments = base_values["kaleidoscope_segments"]
	else:
		original_segments = parameter_manager.get_parameter_value("kaleidoscope_segments")
	
	# On beat detection, temporarily change kaleidoscope segments
	var segment_change = randf_range(-8, 8)  # More dramatic change
	var new_segments = original_segments + segment_change
	new_segments = clamp(new_segments, 3, 50)  # Keep within reasonable bounds
	
	parameter_manager.set_parameter_value("kaleidoscope_segments", new_segments)
	
	# Start the beat reset timer
	beat_reset_timer = beat_duration
	
	print("AudioReactivityManager: Beat detected! Changed segments from %.0f to %.0f" % [original_segments, new_segments])

func _process(delta: float):
	"""Handle beat effect timing"""
	if beat_reset_timer > 0.0:
		beat_reset_timer -= delta
		
		if beat_reset_timer <= 0.0:
			# Reset kaleidoscope segments to base value
			if audio_reactive and parameter_manager and "kaleidoscope_segments" in base_values:
				parameter_manager.set_parameter_value("kaleidoscope_segments", base_values["kaleidoscope_segments"])

func is_audio_reactive() -> bool:
	return audio_reactive

func set_intensity_multipliers(bass: float, mid: float, treble: float):
	"""Allow adjusting the intensity of audio effects"""
	bass_pulse_intensity = clamp(bass, 0.0, 3.0)
	mid_rotation_intensity = clamp(mid, 0.0, 3.0)
	treble_zoom_intensity = clamp(treble, 0.0, 3.0)

func get_current_influences() -> Dictionary:
	"""Get current audio influence values for debugging"""
	return {
		"bass": current_bass_influence,
		"mid": current_mid_influence,
		"treble": current_treble_influence,
		"beat_timer": beat_reset_timer
	}

extends RefCounted
class_name AudioReactivityManager

# Audio reactivity state
var audio_reactive = false
var base_values = {}

# Parameter references
var parameter_manager: ParameterManager

# Smoothing for audio responsiveness
var current_bass_influence = 0.0
var current_mid_influence = 0.0
var current_treble_influence = 0.0
var smoothing_factor = 0.15

# Intensity multipliers
var bass_pulse_intensity = 0.5
var mid_rotation_intensity = 1.0
var treble_zoom_intensity = 0.8

# Beat effect timing
var beat_reset_timer = 0.0
var beat_duration = 0.3
var original_segments = 10.0

func connect_to_parameter_manager(param_manager: ParameterManager):
	parameter_manager = param_manager
	print("AudioReactivityManager: Connected to parameter manager")

func toggle_audio_reactive() -> bool:
	audio_reactive = !audio_reactive
	
	if not audio_reactive:
		restore_base_values()
		print("AudioReactivityManager: Audio reactivity DISABLED")
	else:
		store_base_values()
		print("AudioReactivityManager: Audio reactivity ENABLED")
	
	return audio_reactive

func store_base_values():
	"""Store current parameter values as base values"""
	if not parameter_manager:
		print("AudioReactivityManager: ERROR - No parameter manager!")
		return
	
	# Store the parameters that audio will modify
	base_values["truchet_radius"] = parameter_manager.get_parameter_value("truchet_radius")
	base_values["color_intensity"] = parameter_manager.get_parameter_value("color_intensity")
	base_values["rotation_speed"] = parameter_manager.get_parameter_value("rotation_speed")
	base_values["zoom_level"] = parameter_manager.get_parameter_value("zoom_level")
	base_values["kaleidoscope_segments"] = parameter_manager.get_parameter_value("kaleidoscope_segments")
	
	print("AudioReactivityManager: Stored base values")

func restore_base_values():
	"""Restore parameters to their base values"""
	if not parameter_manager:
		return
	
	# Restore all modified parameters
	for param_name in base_values:
		parameter_manager.set_parameter_value(param_name, base_values[param_name])
	
	# Reset influence values
	current_bass_influence = 0.0
	current_mid_influence = 0.0
	current_treble_influence = 0.0
	beat_reset_timer = 0.0
	
	print("AudioReactivityManager: Restored base values")

func on_bass_detected(intensity: float):
	"""Handle bass frequency detection"""
	if not audio_reactive or not parameter_manager:
		return
	
	# Smooth the bass influence
	current_bass_influence = lerp(current_bass_influence, intensity, smoothing_factor)
	
	# Bass affects truchet radius (center circle pulsing)
	var base_radius = base_values.get("truchet_radius", 0.35)
	var pulse_amount = current_bass_influence * bass_pulse_intensity * 0.5
	var new_radius = clamp(base_radius + pulse_amount, 0.1, 0.8)
	parameter_manager.set_parameter_value("truchet_radius", new_radius)
	
	# Bass also affects color intensity
	var base_color = base_values.get("color_intensity", 1.0)
	var color_boost = current_bass_influence * 0.4
	var new_color = clamp(base_color + color_boost, 0.5, 2.0)
	parameter_manager.set_parameter_value("color_intensity", new_color)

func on_mid_detected(intensity: float):
	"""Handle mid frequency detection"""
	if not audio_reactive or not parameter_manager:
		return
	
	# Smooth the mid influence
	current_mid_influence = lerp(current_mid_influence, intensity, smoothing_factor)
	
	# Mid frequencies affect rotation speed
	var base_rotation = base_values.get("rotation_speed", 0.025)
	var rotation_mod = current_mid_influence * mid_rotation_intensity * 0.04
	var new_rotation = clamp(base_rotation + rotation_mod, -1.0, 1.0)
	parameter_manager.set_parameter_value("rotation_speed", new_rotation)

func on_treble_detected(intensity: float):
	"""Handle treble frequency detection"""
	if not audio_reactive or not parameter_manager:
		return
	
	# Smooth the treble influence
	current_treble_influence = lerp(current_treble_influence, intensity, smoothing_factor)
	
	# Treble affects zoom level for sparkle effects
	var base_zoom = base_values.get("zoom_level", 0.3)
	var zoom_mod = current_treble_influence * treble_zoom_intensity * 0.08
	var new_zoom = clamp(base_zoom + zoom_mod, 0.1, 1.0)
	parameter_manager.set_parameter_value("zoom_level", new_zoom)

func on_beat_detected():
	"""Handle beat detection - dramatic segment change"""
	if not audio_reactive or not parameter_manager:
		return
	
	# Store original if not already stored
	if "kaleidoscope_segments" in base_values:
		original_segments = base_values["kaleidoscope_segments"]
	else:
		original_segments = parameter_manager.get_parameter_value("kaleidoscope_segments")
	
	# On beat: dramatic kaleidoscope change
	var segment_change = randf_range(-12, 12)
	var new_segments = clamp(original_segments + segment_change, 3, 50)
	parameter_manager.set_parameter_value("kaleidoscope_segments", new_segments)
	
	# Start beat reset timer
	beat_reset_timer = beat_duration
	
	print("AudioReactivityManager: Beat! Segments: %.0f -> %.0f" % [original_segments, new_segments])

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

func get_current_influences() -> Dictionary:
	"""Get current audio influence values for debugging"""
	return {
		"bass": current_bass_influence,
		"mid": current_mid_influence,
		"treble": current_treble_influence,
		"beat_timer": beat_reset_timer,
		"reactive": audio_reactive
	}

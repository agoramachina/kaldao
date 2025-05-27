# Enhanced ParameterManager.gd with kaleidoscope segment protection

extends RefCounted
class_name ParameterManager

# Signals
signal parameter_changed(param_name: String, value: float)

# Parameters data
var parameters = {
	"fly_speed": {"min": -3.0, "max": 3.0, "current": 0.2, "step": 0.1, "description": "Fly Speed"},
	"contrast": {"min": 0.1, "max": 5.0, "current": 1.0, "step": 0.1, "description": "Contrast"},
	"kaleidoscope_segments": {"min": 4.0, "max": 80.0, "current": 10.0, "step": 2.0, "description": "Kaleidoscope Segments"},
	"truchet_radius": {"min": -1.0, "max": 1.0, "current": 0.35, "step": 0.01, "description": "Truchet Radius"},
	"rotation_speed": {"min": -6.0, "max": 6.0, "current": 0.025, "step": 0.01, "description": "Rotation Speed"},
	"zoom_level": {"min": -5.0, "max": 5.0, "current": 0.3, "step": 0.05, "description": "Zoom Level"},
	"color_intensity": {"min": 0.1, "max": 2.0, "current": 1.0, "step": 0.1, "description": "Color Intensity"},
	"plane_rotation_speed": {"min": -5.0, "max": 5.0, "current": 0.5, "step": 0.1, "description": "Plane Rotation Speed"},
	"camera_tilt_x": {"min": -10.0, "max": 10.0, "current": 0.0, "step": 1.0, "description": "Camera Tilt X"},
	"camera_tilt_y": {"min": -10.0, "max": 10.0, "current": 0.0, "step": 1.0, "description": "Camera Tilt Y"},
	"camera_roll": {"min": -3.14, "max": 3.14, "current": 0.0, "step": 0.1, "description": "Camera Roll"},
	"path_stability": {"min": -1.0, "max": 1.0, "current": 1.0, "step": 0.05, "description": "Path Stability"},
	"path_skew": {"min": -3.0, "max": 3.0, "current": 1.0, "step": 0.1, "description": "Path Skew"},
	"color_speed": {"min": 0.0, "max": 2.0, "current": 0.5, "step": 0.1, "description": "Color Speed"},
	"color_palette": {"min": 0, "max": 6, "current": 0, "step": 1, "description": "Color Palette"},
	"invert_colors": {"min": 0.0, "max": 1.0, "current": 0.0, "step": 1.0, "description": "Invert Colors"} 
}

# Default values for resetting - ENSURE kaleidoscope_segments is even
var default_values = {
	"fly_speed": 0.25,
	"contrast": 1.0,
	"kaleidoscope_segments": 10.0,  # EVEN number
	"truchet_radius": 0.35,
	"rotation_speed": 0.025,
	"zoom_level": 0.3,
	"color_intensity": 1.0,
	"camera_tilt_x": 0.0,
	"camera_tilt_y": 0.0,
	"camera_roll": 0.0,
	"path_stability": 1.0,
	"path_skew": 1.0,
	"color_speed": 0.5,
	"plane_rotation_speed": 0.5,
	"color_palette": 0,
	"invert_colors": 0.0
}

var current_param_index = 0
var param_names = []

# Pause functionality
var is_paused = false
var paused_values = {}

# List of parameters that control animation speed (these get set to 0 when paused)
var speed_parameters = ["fly_speed", "rotation_speed", "color_speed", "plane_rotation_speed"]

# Color-related parameters that should NOT be randomized by the "." key
var color_parameters = ["color_intensity", "color_speed", "color_palette", "invert_colors"]

func _init():
	param_names = parameters.keys()
	
	# FORCE kaleidoscope_segments to be even on initialization
	fix_kaleidoscope_segments()

func fix_kaleidoscope_segments():
	"""Ensure kaleidoscope_segments is always a valid even integer"""
	var current = parameters["kaleidoscope_segments"]["current"]
	var fixed = ensure_kaleidoscope_even(current)
	
	if current != fixed:
		print("ParameterManager: Fixed kaleidoscope_segments from %.6f to %.6f" % [current, fixed])
		parameters["kaleidoscope_segments"]["current"] = fixed
		# Don't emit signal during initialization

func ensure_kaleidoscope_even(value: float) -> float:
	"""Ensure kaleidoscope segments value is an even integer within valid range"""
	# Clamp to valid range
	value = clamp(value, 4.0, 80.0)
	
	# Round to nearest integer
	var rounded = round(value)
	
	# If odd, make it even (prefer rounding down for consistency)
	if int(rounded) % 2 == 1:
		rounded -= 1.0
		# If that puts us below minimum, round up instead
		if rounded < 4.0:
			rounded = 4.0
	
	return rounded

func increase_current_parameter():
	var param_name = param_names[current_param_index]
	var param = parameters[param_name]
	
	if param_name == "color_palette":
		# Handle color palette cycling in ColorPaletteManager instead
		return
	elif param_name == "invert_colors":
		# Handle boolean toggle for color inversion
		param["current"] = 1.0 if param["current"] == 0.0 else 0.0
	elif param_name == "kaleidoscope_segments":
		# PROTECTED: Always step by 2 and ensure even values
		var new_value = param["current"] + 2.0
		new_value = min(new_value, param["max"])
		new_value = ensure_kaleidoscope_even(new_value)
		param["current"] = new_value
	else:
		param["current"] = min(param["current"] + param["step"], param["max"])
	
	parameter_changed.emit(param_name, param["current"])

func decrease_current_parameter():
	var param_name = param_names[current_param_index]
	var param = parameters[param_name]
	
	if param_name == "color_palette":
		# Handle color palette cycling in ColorPaletteManager instead
		return
	elif param_name == "invert_colors":
		# Handle boolean toggle for color inversion
		param["current"] = 1.0 if param["current"] == 0.0 else 0.0
	elif param_name == "kaleidoscope_segments":
		# PROTECTED: Always step by 2 and ensure even values
		var new_value = param["current"] - 2.0
		new_value = max(new_value, param["min"])
		new_value = ensure_kaleidoscope_even(new_value)
		param["current"] = new_value
	else:
		param["current"] = max(param["current"] - param["step"], param["min"])
	
	parameter_changed.emit(param_name, param["current"])

func next_parameter():
	current_param_index = (current_param_index + 1) % param_names.size()

func previous_parameter():
	current_param_index = (current_param_index - 1) % param_names.size()
	if current_param_index < 0:
		current_param_index = param_names.size() - 1

func reset_current_parameter():
	var param_name = param_names[current_param_index]
	if param_name in default_values:
		var default_val = default_values[param_name]
		
		# PROTECTED: Ensure kaleidoscope default is even
		if param_name == "kaleidoscope_segments":
			default_val = ensure_kaleidoscope_even(default_val)
		
		parameters[param_name]["current"] = default_val
		parameter_changed.emit(param_name, default_val)

func reset_all_parameters():
	for param_name in default_values:
		var default_val = default_values[param_name]
		
		# PROTECTED: Ensure kaleidoscope default is even
		if param_name == "kaleidoscope_segments":
			default_val = ensure_kaleidoscope_even(default_val)
		
		parameters[param_name]["current"] = default_val
		parameter_changed.emit(param_name, default_val)

func randomize_non_color_parameters():
	print("DEBUG: Randomizing all non-color parameters...")
	
	var randomized_count = 0
	
	for param_name in parameters:
		# Skip color-related parameters
		if param_name in color_parameters:
			print("DEBUG: Skipping color parameter: ", param_name)
			continue
		
		var param = parameters[param_name]
		var min_val = param["min"]
		var max_val = param["max"]
		var step = param["step"]
		
		# Generate random value within the parameter's range
		var random_value: float
		
		if param_name == "kaleidoscope_segments":
			# PROTECTED: Special handling for kaleidoscope segments - ALWAYS even integers
			var min_steps = int(min_val / 2.0)  # 2 (for min 4)
			var max_steps = int(max_val / 2.0)  # 40 (for max 80)
			var random_steps = randi_range(min_steps, max_steps)
			random_value = float(random_steps * 2)  # This ensures even values: 4, 6, 8, 10, etc.
			print("DEBUG: Kaleidoscope segments randomized to steps: %d, value: %.0f" % [random_steps, random_value])
		else:
			# Regular parameters - generate random float and snap to step
			random_value = randf_range(min_val, max_val)
			# Snap to nearest step
			random_value = round(random_value / step) * step
		
		# Clamp to ensure it's within bounds
		random_value = clamp(random_value, min_val, max_val)
		
		# Final protection for kaleidoscope_segments
		if param_name == "kaleidoscope_segments":
			random_value = ensure_kaleidoscope_even(random_value)
		
		# Update the parameter
		param["current"] = random_value
		parameter_changed.emit(param_name, random_value)
		
		print("DEBUG: Randomized %s: %.3f (range: %.3f to %.3f)" % [param_name, random_value, min_val, max_val])
		randomized_count += 1
	
	print("DEBUG: Randomized %d parameters (skipped %d color parameters)" % [randomized_count, color_parameters.size()])

func toggle_pause():
	print("DEBUG: toggle_pause() called - current is_paused: ", is_paused)
	
	if is_paused:
		# Unpause - restore the saved speed values
		print("DEBUG: Unpausing - restoring speed values")
		is_paused = false
		
		for param_name in paused_values:
			var restored_value = paused_values[param_name]
			
			# PROTECTED: Ensure kaleidoscope value is even when restoring
			if param_name == "kaleidoscope_segments":
				restored_value = ensure_kaleidoscope_even(restored_value)
			
			parameters[param_name]["current"] = restored_value
			parameter_changed.emit(param_name, restored_value)
			print("DEBUG: Restored ", param_name, " to ", restored_value)
		
		paused_values.clear()
	else:
		# Pause - save current speed values and set them to 0
		print("DEBUG: Pausing - setting speed parameters to 0")
		is_paused = true
		paused_values.clear()
		
		for param_name in speed_parameters:
			# Save the current value
			paused_values[param_name] = parameters[param_name]["current"]
			# Set to 0
			parameters[param_name]["current"] = 0.0
			parameter_changed.emit(param_name, 0.0)
			print("DEBUG: Set ", param_name, " to 0, saved value: ", paused_values[param_name])
	
	print("DEBUG: toggle_pause() finished - new is_paused: ", is_paused)

func get_current_parameter_name() -> String:
	return param_names[current_param_index]

func get_current_parameter_display() -> String:
	"""Get display text for current parameter with special handling for invert_colors"""
	var param_name = param_names[current_param_index]
	var param = parameters[param_name]
	
	if param_name == "color_palette":
		# Special display for color palette - will be handled by ColorPaletteManager
		return ""
	elif param_name == "invert_colors":
		# Special display for boolean parameter
		var status = "ON" if param["current"] > 0.5 else "OFF"
		return "%s: %s\n[↑/↓] toggle\n[←/→] change parameter [r] reset [R] reset all" % [
			param["description"], status
		]
	else:
		return "%s: %.2f\n[↑/↓] adjust (%.2f to %.2f, step: %.2f)\n[←/→] change parameter [r] reset [R] reset all" % [
			param["description"], 
			param["current"],
			param["min"],
			param["max"],
			param["step"]
		]

func get_formatted_settings_text(audio_info: String = "") -> String:
	var settings_text = "=== CURRENT SETTINGS ===\n\n"
	
	if audio_info != "":
		settings_text += audio_info + "\n\n"
	
	# Add pause status to settings display
	if is_paused:
		settings_text += "STATUS: PAUSED\n\n"
	else:
		settings_text += "STATUS: RUNNING\n\n"
	
	# MOVEMENT & ANIMATION GROUP
	settings_text += "MOVEMENT & ANIMATION:\n"
	settings_text += "Zoom Level: %.3f\n" % parameters["zoom_level"]["current"]
	settings_text += "Fly Speed: %.3f\n" % parameters["fly_speed"]["current"]
	settings_text += "Rotation Speed: %.3f\n" % parameters["rotation_speed"]["current"]
	settings_text += "Plane Rotation: %.3f\n" % parameters["plane_rotation_speed"]["current"]
	settings_text += "Kaleidoscope Segments: %.0f\n" % parameters["kaleidoscope_segments"]["current"]
	settings_text += "Truchet Radius: %.3f\n\n" % parameters["truchet_radius"]["current"]
	
	# CAMERA & PATH GROUP
	settings_text += "CAMERA & PATH:\n"
	settings_text += "Path Stability: %.3f\n" % parameters["path_stability"]["current"]
	settings_text += "Path Skew: %.3f\n" % parameters["path_skew"]["current"]
	settings_text += "Camera Tilt X: %.1f\n" % parameters["camera_tilt_x"]["current"]
	settings_text += "Camera Tilt Y: %.1f\n" % parameters["camera_tilt_y"]["current"]
	settings_text += "Camera Roll: %.3f\n\n" % parameters["camera_roll"]["current"]
	
	# COLOR & VISUAL GROUP
	settings_text += "COLOR & VISUAL:\n"
	settings_text += "Contrast: %.3f\n" % parameters["contrast"]["current"]
	settings_text += "Color Speed: %.3f\n" % parameters["color_speed"]["current"]
	settings_text += "Color Intensity: %.3f\n" % parameters["color_intensity"]["current"]
	
	return settings_text

func get_parameter_value(param_name: String) -> float:
	if param_name in parameters:
		return parameters[param_name]["current"]
	return 0.0

func set_parameter_value(param_name: String, value: float):
	if param_name in parameters:
		# PROTECTED: Special handling for kaleidoscope_segments
		if param_name == "kaleidoscope_segments":
			value = ensure_kaleidoscope_even(value)
			# print("ParameterManager: Set kaleidoscope_segments to protected value: %.0f" % value)
		
		parameters[param_name]["current"] = value
		parameter_changed.emit(param_name, value)

func get_all_parameters() -> Dictionary:
	return parameters

func get_is_paused() -> bool:
	return is_paused

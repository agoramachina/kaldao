extends RefCounted
class_name ParameterManager

# Signals
signal parameter_changed(param_name: String, value: float)

# Parameters data
var parameters = {
	"fly_speed": {"min": -3.0, "max": 3.0, "current": 0.25, "step": 0.25, "description": "Fly Speed"},
	"contrast": {"min": 0.1, "max": 5.0, "current": 1.0, "step": 0.1, "description": "Contrast"},
	"kaleidoscope_segments": {"min": -300.0, "max": 300.0, "current": 10.0, "step": 2.0, "description": "Kaleidoscope Segments"},
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
	"color_palette": {"min": 0, "max": 6, "current": 0, "step": 1, "description": "Color Palette"}
}

# Default values for resetting
var default_values = {
	"fly_speed": 0.25,
	"contrast": 1.0,
	"kaleidoscope_segments": 10.0,
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
	"color_palette": 0
}

var current_param_index = 0
var param_names = []

# Pause functionality
var is_paused = false
var paused_values = {}

# List of parameters that control animation speed (these get set to 0 when paused)
var speed_parameters = ["fly_speed", "rotation_speed", "color_speed", "plane_rotation_speed"]

# NEW: Color-related parameters that should NOT be randomized by the "." key
var color_parameters = ["color_intensity", "color_speed", "color_palette"]

func _init():
	param_names = parameters.keys()

func increase_current_parameter():
	var param_name = param_names[current_param_index]
	var param = parameters[param_name]
	
	if param_name == "color_palette":
		# Handle color palette cycling in ColorPaletteManager instead
		return
	elif param_name == "kaleidoscope_segments":
		param["current"] = min(param["current"] + 2.0, param["max"])
	else:
		param["current"] = min(param["current"] + param["step"], param["max"])
	
	parameter_changed.emit(param_name, param["current"])

func decrease_current_parameter():
	var param_name = param_names[current_param_index]
	var param = parameters[param_name]
	
	if param_name == "color_palette":
		# Handle color palette cycling in ColorPaletteManager instead
		return
	elif param_name == "kaleidoscope_segments":
		param["current"] = max(param["current"] - 2.0, param["min"])
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
		parameters[param_name]["current"] = default_values[param_name]
		parameter_changed.emit(param_name, default_values[param_name])

func reset_all_parameters():
	for param_name in default_values:
		parameters[param_name]["current"] = default_values[param_name]
		parameter_changed.emit(param_name, default_values[param_name])

# NEW: Randomize all non-color parameters
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
			# Special handling for kaleidoscope segments - use integers and step by 2
			var steps = int((max_val - min_val) / 2.0)
			random_value = min_val + (randi() % (steps + 1)) * 2.0
		else:
			# Regular parameters - generate random float and snap to step
			random_value = randf_range(min_val, max_val)
			# Snap to nearest step
			random_value = round(random_value / step) * step
		
		# Clamp to ensure it's within bounds
		random_value = clamp(random_value, min_val, max_val)
		
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
			parameters[param_name]["current"] = paused_values[param_name]
			parameter_changed.emit(param_name, paused_values[param_name])
			print("DEBUG: Restored ", param_name, " to ", paused_values[param_name])
		
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
	var param_name = param_names[current_param_index]
	var param = parameters[param_name]
	
	if param_name == "color_palette":
		# Special display for color palette - will be handled by ColorPaletteManager
		return ""
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
		parameters[param_name]["current"] = value
		parameter_changed.emit(param_name, value)

func get_all_parameters() -> Dictionary:
	return parameters

# Add getter for pause status
func get_is_paused() -> bool:
	return is_paused

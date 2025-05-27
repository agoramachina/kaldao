class_name ParameterManager
extends RefCounted

## ParameterManager - Centralized Visual Parameter Management
##
## This class manages all visual parameters using the ParameterData structure.
## It provides a clean interface for parameter manipulation, validation, and
## persistence while maintaining backward compatibility with the existing system.
##
## Usage:
##   var param_manager = ParameterManager.new()
##   param_manager.set_parameter_value("zoom_level", 1.5)
##   var current_zoom = param_manager.get_parameter_value("zoom_level")

# Signals for parameter changes
signal parameter_changed(param_name: String, value: float)
signal current_parameter_changed(param_name: String)
signal all_parameters_reset()
signal parameters_randomized()

# Parameter storage
var _parameters: Dictionary = {}
var _parameter_order: Array[String] = []
var _current_parameter_index: int = 0

# Pause state management
var _is_paused: bool = false
var _paused_values: Dictionary = {}

# Parameter categories for organization
var _categories: Dictionary = {
	"movement": [],
	"visual": [],
	"camera": [],
	"color": [],
	"audio": []
}

#region Initialization

func _init():
	_create_default_parameters()
	_organize_parameters_by_category()
	print("ParameterManager: Initialized with %d parameters" % _parameters.size())

## Create all default parameters with proper ParameterData structures
func _create_default_parameters() -> void:
	# Movement & Animation Parameters
	_add_parameter("fly_speed", -3.0, 3.0, 0.2, 0.1, "Fly Speed", "Speed of movement through the fractal space", "movement", true)
	_add_parameter("rotation_speed", -6.0, 6.0, 0.025, 0.01, "Rotation Speed", "Speed of fractal rotation", "movement", true)
	_add_parameter("plane_rotation_speed", -5.0, 5.0, 0.5, 0.1, "Plane Rotation Speed", "Speed of plane rotation", "movement", true)
	
	# Visual Parameters
	_add_parameter("zoom_level", -5.0, 5.0, 0.3, 0.05, "Zoom Level", "Zoom level of the fractal view", "visual")
	_add_parameter("contrast", 0.1, 5.0, 1.0, 0.1, "Contrast", "Visual contrast adjustment", "visual")
	_add_parameter("truchet_radius", -1.0, 1.0, 0.35, 0.01, "Truchet Radius", "Radius of truchet patterns", "visual")
	
	# Special kaleidoscope parameter with even integer constraint
	var kaleidoscope_param = _add_parameter("kaleidoscope_segments", 4.0, 80.0, 10.0, 2.0, "Kaleidoscope Segments", "Number of kaleidoscope segments", "visual")
	kaleidoscope_param.is_integer = true
	kaleidoscope_param.is_even_integer = true
	kaleidoscope_param.ui_format = "%.0f"
	
	# Camera Parameters
	_add_parameter("camera_tilt_x", -10.0, 10.0, 0.0, 1.0, "Camera Tilt X", "Camera tilt on X axis", "camera")
	_add_parameter("camera_tilt_y", -10.0, 10.0, 0.0, 1.0, "Camera Tilt Y", "Camera tilt on Y axis", "camera")
	_add_parameter("camera_roll", -3.14, 3.14, 0.0, 0.1, "Camera Roll", "Camera roll rotation", "camera")
	_add_parameter("path_stability", -1.0, 1.0, 1.0, 0.05, "Path Stability", "Stability of the movement path", "camera")
	_add_parameter("path_skew", -3.0, 3.0, 1.0, 0.1, "Path Skew", "Skew of the movement path", "camera")
	
	# Color Parameters
	_add_parameter("color_intensity", 0.1, 2.0, 1.0, 0.1, "Color Intensity", "Intensity of colors", "color", false, true)
	_add_parameter("color_speed", 0.0, 2.0, 0.5, 0.1, "Color Speed", "Speed of color cycling", "color", true, true)
	
	# Special color palette parameter (handled differently)
	var palette_param = _add_parameter("color_palette", 0, 6, 0, 1, "Color Palette", "Current color palette", "color", false, true)
	palette_param.is_integer = true
	palette_param.ui_format = "%.0f"

## Helper function to add a parameter with ParameterData
func _add_parameter(name: String, min_val: float, max_val: float, default_val: float, step: float, 
					display: String, desc: String, category: String = "general", 
					is_speed: bool = false, is_color: bool = false) -> ParameterData:
	var param = ParameterData.new()
	param.setup(name, min_val, max_val, default_val, step, display, desc)
	param.category = category
	param.is_speed_parameter = is_speed
	param.is_color_parameter = is_color
	param.ui_order = _parameters.size()  # Set order based on creation order
	
	_parameters[name] = param
	_parameter_order.append(name)
	
	return param

## Organize parameters by category for UI display
func _organize_parameters_by_category() -> void:
	for param_name in _parameters:
		var param = _parameters[param_name] as ParameterData
		var category = param.category
		
		if category in _categories:
			_categories[category].append(param_name)
		else:
			_categories["general"] = _categories.get("general", [])
			_categories["general"].append(param_name)

#endregion

#region Parameter Access and Modification

## Get the current value of a parameter
## @param param_name: Name of the parameter
## @return: Current value, or 0.0 if parameter doesn't exist
func get_parameter_value(param_name: String) -> float:
	if param_name in _parameters:
		return _parameters[param_name].current_value
	else:
		push_warning("ParameterManager: Parameter '%s' not found" % param_name)
		return 0.0

## Set the value of a parameter with validation
## @param param_name: Name of the parameter
## @param value: New value to set
## @return: The actual value set after validation
func set_parameter_value(param_name: String, value: float) -> float:
	if not param_name in _parameters:
		push_warning("ParameterManager: Parameter '%s' not found" % param_name)
		return 0.0
	
	var param = _parameters[param_name] as ParameterData
	var old_value = param.current_value
	param.current_value = param.validate_value(value)
	
	# Emit signal if value actually changed
	if abs(param.current_value - old_value) > 0.001:
		parameter_changed.emit(param_name, param.current_value)
	
	return param.current_value

## Get a parameter's ParameterData object
## @param param_name: Name of the parameter
## @return: ParameterData object, or null if not found
func get_parameter_data(param_name: String) -> ParameterData:
	return _parameters.get(param_name, null)

## Get all parameter names
## @return: Array of all parameter names
func get_parameter_names() -> Array[String]:
	return _parameter_order.duplicate()

## Get parameters by category
## @param category: Category name
## @return: Array of parameter names in that category
func get_parameters_by_category(category: String) -> Array:
	return _categories.get(category, [])

## Get all categories
## @return: Array of category names
func get_categories() -> Array:
	return _categories.keys()

#endregion

#region Current Parameter Navigation

## Get the name of the currently selected parameter
## @return: Name of the current parameter
func get_current_parameter_name() -> String:
	if _current_parameter_index >= 0 and _current_parameter_index < _parameter_order.size():
		return _parameter_order[_current_parameter_index]
	return ""

## Get the currently selected parameter data
## @return: ParameterData of the current parameter
func get_current_parameter_data() -> ParameterData:
	var param_name = get_current_parameter_name()
	return get_parameter_data(param_name)

## Move to the next parameter in the list
func next_parameter() -> void:
	_current_parameter_index = (_current_parameter_index + 1) % _parameter_order.size()
	current_parameter_changed.emit(get_current_parameter_name())

## Move to the previous parameter in the list
func previous_parameter() -> void:
	_current_parameter_index = (_current_parameter_index - 1) % _parameter_order.size()
	if _current_parameter_index < 0:
		_current_parameter_index = _parameter_order.size() - 1
	current_parameter_changed.emit(get_current_parameter_name())

## Set the current parameter by name
## @param param_name: Name of the parameter to select
## @return: True if parameter was found and selected
func set_current_parameter(param_name: String) -> bool:
	var index = _parameter_order.find(param_name)
	if index >= 0:
		_current_parameter_index = index
		current_parameter_changed.emit(param_name)
		return true
	return false

#endregion

#region Parameter Manipulation

## Increase the current parameter by one step
## @return: The new value after increase
func increase_current_parameter() -> float:
	var param = get_current_parameter_data()
	if param:
		var new_value = param.increase()
		parameter_changed.emit(param.name, new_value)
		return new_value
	return 0.0

## Decrease the current parameter by one step
## @return: The new value after decrease
func decrease_current_parameter() -> float:
	var param = get_current_parameter_data()
	if param:
		var new_value = param.decrease()
		parameter_changed.emit(param.name, new_value)
		return new_value
	return 0.0

## Increase a specific parameter by name
## @param param_name: Name of the parameter to increase
## @return: The new value after increase
func increase_parameter(param_name: String) -> float:
	var param = get_parameter_data(param_name)
	if param:
		var new_value = param.increase()
		parameter_changed.emit(param_name, new_value)
		return new_value
	return 0.0

## Decrease a specific parameter by name
## @param param_name: Name of the parameter to decrease
## @return: The new value after decrease
func decrease_parameter(param_name: String) -> float:
	var param = get_parameter_data(param_name)
	if param:
		var new_value = param.decrease()
		parameter_changed.emit(param_name, new_value)
		return new_value
	return 0.0

#endregion

#region Reset and Randomization

## Reset the current parameter to its default value
## @return: The default value
func reset_current_parameter() -> float:
	var param = get_current_parameter_data()
	if param:
		var new_value = param.reset_to_default()
		parameter_changed.emit(param.name, new_value)
		return new_value
	return 0.0

## Reset a specific parameter to its default value
## @param param_name: Name of the parameter to reset
## @return: The default value
func reset_parameter(param_name: String) -> float:
	var param = get_parameter_data(param_name)
	if param:
		var new_value = param.reset_to_default()
		parameter_changed.emit(param_name, new_value)
		return new_value
	return 0.0

## Reset all parameters to their default values
func reset_all_parameters() -> void:
	print("ParameterManager: Resetting all parameters to defaults")
	
	for param_name in _parameters:
		var param = _parameters[param_name] as ParameterData
		param.reset_to_default()
		parameter_changed.emit(param_name, param.current_value)
	
	all_parameters_reset.emit()

## Randomize non-color parameters
func randomize_non_color_parameters() -> void:
	print("ParameterManager: Randomizing non-color parameters")
	
	var randomized_count = 0
	
	for param_name in _parameters:
		var param = _parameters[param_name] as ParameterData
		
		# Skip color parameters and readonly parameters
		if param.is_color_parameter or param.is_readonly:
			continue
		
		var new_value = param.randomize()
		parameter_changed.emit(param_name, new_value)
		randomized_count += 1
		
		print("ParameterManager: Randomized %s to %s" % [param_name, param.get_formatted_value()])
	
	print("ParameterManager: Randomized %d parameters" % randomized_count)
	parameters_randomized.emit()

## Randomize all parameters (including color)
func randomize_all_parameters() -> void:
	print("ParameterManager: Randomizing all parameters")
	
	for param_name in _parameters:
		var param = _parameters[param_name] as ParameterData
		
		# Skip readonly parameters
		if param.is_readonly:
			continue
		
		var new_value = param.randomize()
		parameter_changed.emit(param_name, new_value)
	
	parameters_randomized.emit()

#endregion

#region Pause Functionality

## Toggle pause state for speed parameters
func toggle_pause() -> void:
	print("ParameterManager: Toggling pause - current state: %s" % ("PAUSED" if _is_paused else "RUNNING"))
	
	if _is_paused:
		_unpause()
	else:
		_pause()

## Pause all speed parameters
func _pause() -> void:
	_is_paused = true
	_paused_values.clear()
	
	print("ParameterManager: Pausing speed parameters")
	
	for param_name in _parameters:
		var param = _parameters[param_name] as ParameterData
		
		if param.is_speed_parameter:
			# Save current value
			_paused_values[param_name] = param.current_value
			# Set to zero
			param.current_value = 0.0
			parameter_changed.emit(param_name, 0.0)
			print("ParameterManager: Paused %s (saved: %s)" % [param_name, param.get_formatted_value(_paused_values[param_name])])

## Unpause all speed parameters
func _unpause() -> void:
	_is_paused = false
	
	print("ParameterManager: Unpausing speed parameters")
	
	for param_name in _paused_values:
		var param = get_parameter_data(param_name)
		if param:
			var restored_value = param.validate_value(_paused_values[param_name])
			param.current_value = restored_value
			parameter_changed.emit(param_name, restored_value)
			print("ParameterManager: Restored %s to %s" % [param_name, param.get_formatted_value()])
	
	_paused_values.clear()

## Check if parameters are currently paused
## @return: True if paused
func get_is_paused() -> bool:
	return _is_paused

#endregion

#region Display and Formatting

## Get formatted display text for the current parameter
## @return: Formatted string for UI display
func get_current_parameter_display() -> String:
	var param = get_current_parameter_data()
	if not param:
		return "No parameter selected"
	
	var display_text = "%s: %s\n" % [param.display_name, param.get_formatted_value()]
	display_text += "[↑/↓] adjust (%s, %s)\n" % [param.get_range_string(), param.get_step_string()]
	display_text += "[←/→] change parameter [r] reset [R] reset all"
	
	if param.description != "":
		display_text += "\n%s" % param.description
	
	return display_text

## Get formatted settings text for all parameters
## @param audio_info: Optional audio information to include
## @return: Formatted string with all parameter values
func get_formatted_settings_text(audio_info: String = "") -> String:
	var settings_text = "=== CURRENT SETTINGS ===\n\n"
	
	if audio_info != "":
		settings_text += audio_info + "\n\n"
	
	# Add pause status
	if _is_paused:
		settings_text += "STATUS: PAUSED\n\n"
	else:
		settings_text += "STATUS: RUNNING\n\n"
	
	# Group parameters by category
	for category in _categories:
		if _categories[category].size() == 0:
			continue
		
		settings_text += "%s:\n" % category.to_upper()
		
		for param_name in _categories[category]:
			var param = _parameters[param_name] as ParameterData
			settings_text += "%s: %s\n" % [param.display_name, param.get_formatted_value()]
		
		settings_text += "\n"
	
	return settings_text

## Get parameter information for debugging
## @return: Dictionary with parameter debug information
func get_debug_info() -> Dictionary:
	var info = {
		"total_parameters": _parameters.size(),
		"current_parameter": get_current_parameter_name(),
		"is_paused": _is_paused,
		"paused_parameters": _paused_values.keys(),
		"categories": {}
	}
	
	for category in _categories:
		info.categories[category] = _categories[category].size()
	
	return info

#endregion

#region Serialization

## Get all parameters as a dictionary for saving
## @return: Dictionary containing all parameter data
func get_all_parameters() -> Dictionary:
	var params_dict = {}
	
	for param_name in _parameters:
		var param = _parameters[param_name] as ParameterData
		params_dict[param_name] = param.to_dict()
	
	return params_dict

## Load parameters from a dictionary
## @param params_dict: Dictionary containing parameter data
## @return: Number of parameters successfully loaded
func load_parameters(params_dict: Dictionary) -> int:
	var loaded_count = 0
	
	for param_name in params_dict:
		if param_name in _parameters:
			var param = _parameters[param_name] as ParameterData
			var param_data = params_dict[param_name]
			
			# Load current value if it's a simple float (legacy format)
			if typeof(param_data) == TYPE_FLOAT or typeof(param_data) == TYPE_INT:
				param.current_value = param.validate_value(param_data)
				loaded_count += 1
			# Load from dictionary format (new format)
			elif typeof(param_data) == TYPE_DICTIONARY:
				if "current_value" in param_data:
					param.current_value = param.validate_value(param_data.current_value)
					loaded_count += 1
				# Optionally load other parameter properties
				if "default_value" in param_data:
					param.default_value = param_data.default_value
			
			# Emit change signal
			parameter_changed.emit(param_name, param.current_value)
	
	print("ParameterManager: Loaded %d parameters" % loaded_count)
	return loaded_count

## Export parameters to a file
## @param file_path: Path to save the parameters
## @return: True if export was successful
func export_parameters(file_path: String) -> bool:
	var export_data = {
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system(),
		"parameters": get_all_parameters()
	}
	
	var json_string = JSON.stringify(export_data, "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		print("ParameterManager: Parameters exported to %s" % file_path)
		return true
	else:
		push_error("ParameterManager: Failed to export parameters to %s" % file_path)
		return false

## Import parameters from a file
## @param file_path: Path to load the parameters from
## @return: True if import was successful
func import_parameters(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("ParameterManager: Cannot open file for import: %s" % file_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result == OK:
		var import_data = json.data
		if "parameters" in import_data:
			load_parameters(import_data.parameters)
			print("ParameterManager: Parameters imported from %s" % file_path)
			return true
		else:
			push_error("ParameterManager: Invalid parameter file format")
			return false
	else:
		push_error("ParameterManager: Failed to parse parameter file: %s" % json.error_string)
		return false

#endregion

#region Cleanup

## Cleanup method for proper resource management
func cleanup() -> void:
	print("ParameterManager: Cleaning up resources")
	
	# Clear all data
	_parameters.clear()
	_parameter_order.clear()
	_paused_values.clear()
	_categories.clear()
	
	# Reset state
	_current_parameter_index = 0
	_is_paused = false

#endregion

class_name ParameterData
extends Resource

## ParameterData - Data structure for visual parameter definitions
##
## This resource defines the properties and constraints for a single visual parameter.
## It includes min/max values, step size, default value, and metadata for UI display.
##
## Usage:
##   var param = ParameterData.new()
##   param.setup("zoom_level", 0.05, 5.0, 0.3, 0.05, "Zoom Level", "Controls the zoom level of the fractal")

## Parameter identification
@export var name: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: String = "general"

## Value constraints
@export var min_value: float = 0.0
@export var max_value: float = 1.0
@export var default_value: float = 0.5
@export var step_size: float = 0.1

## Current runtime value (not exported - managed by ParameterManager)
var current_value: float

## Parameter behavior flags
@export var is_integer: bool = false
@export var is_even_integer: bool = false  # Special case for kaleidoscope segments
@export var is_speed_parameter: bool = false  # Affected by pause
@export var is_color_parameter: bool = false  # Excluded from randomization
@export var is_readonly: bool = false

## UI display properties
@export var ui_format: String = "%.2f"  # Format string for display
@export var ui_suffix: String = ""  # Unit suffix (e.g., "°", "%", "x")
@export var ui_order: int = 0  # Display order in UI

## Audio reactivity settings
@export var audio_reactive: bool = false
@export var audio_frequency_band: String = ""  # "bass", "mid", "treble"
@export var audio_intensity_multiplier: float = 1.0

## Validation and constraints
@export var custom_validation: bool = false
@export var validation_script: String = ""

## Initialize the parameter with all required values
## @param param_name: Unique identifier for the parameter
## @param min_val: Minimum allowed value
## @param max_val: Maximum allowed value
## @param default_val: Default value
## @param step: Step size for increments
## @param display: Human-readable name
## @param desc: Description for tooltips/help
func setup(param_name: String, min_val: float, max_val: float, default_val: float, step: float, display: String = "", desc: String = "") -> void:
	name = param_name
	min_value = min_val
	max_value = max_val
	default_value = default_val
	step_size = step
	current_value = default_val
	display_name = display if display != "" else param_name.capitalize()
	description = desc

## Validate and clamp a value to this parameter's constraints
## @param value: The value to validate
## @return: The clamped and validated value
func validate_value(value: float) -> float:
	# Clamp to min/max
	value = clamp(value, min_value, max_value)
	
	# Handle integer constraints
	if is_integer:
		value = round(value)
		
		# Special handling for even integers (kaleidoscope segments)
		if is_even_integer:
			var int_value = int(value)
			if int_value % 2 == 1:
				# If odd, prefer rounding down to stay even
				int_value -= 1
				# But ensure we don't go below minimum
				if int_value < min_value:
					int_value = int(min_value)
					# If minimum is odd, round up to next even
					if int_value % 2 == 1:
						int_value += 1
			value = float(int_value)
	else:
		# Snap to step size for non-integers
		if step_size > 0:
			value = round(value / step_size) * step_size
	
	# Final clamp after adjustments
	value = clamp(value, min_value, max_value)
	
	# Custom validation if enabled
	if custom_validation and validation_script != "":
		value = _apply_custom_validation(value)
	
	return value

## Apply custom validation logic
## @param value: The value to validate
## @return: The validated value
func _apply_custom_validation(value: float) -> float:
	# This could be extended to support custom validation scripts
	# For now, just return the value as-is
	return value

## Get the parameter value formatted for UI display
## @param value: The value to format (uses current_value if not provided)
## @return: Formatted string for display
func get_formatted_value(value: float = current_value) -> String:
	var formatted = ui_format % value
	if ui_suffix != "":
		formatted += ui_suffix
	return formatted

## Get the parameter's range as a string
## @return: String representation of the range
func get_range_string() -> String:
	return "%.2f to %.2f" % [min_value, max_value]

## Get the parameter's step information
## @return: String representation of the step size
func get_step_string() -> String:
	if is_integer:
		return "step: %d" % int(step_size)
	else:
		return "step: %.3f" % step_size

## Check if the current value is at minimum
## @return: True if at minimum value
func is_at_minimum() -> bool:
	return abs(current_value - min_value) < 0.001

## Check if the current value is at maximum
## @return: True if at maximum value
func is_at_maximum() -> bool:
	return abs(current_value - max_value) < 0.001

## Get the parameter value as a normalized 0-1 range
## @param value: The value to normalize (uses current_value if not provided)
## @return: Normalized value between 0 and 1
func get_normalized_value(value: float = current_value) -> float:
	if max_value == min_value:
		return 0.0
	return (value - min_value) / (max_value - min_value)

## Set the parameter value from a normalized 0-1 range
## @param normalized: Normalized value between 0 and 1
## @return: The actual parameter value
func set_from_normalized(normalized: float) -> float:
	normalized = clamp(normalized, 0.0, 1.0)
	var value = min_value + normalized * (max_value - min_value)
	current_value = validate_value(value)
	return current_value

## Increase the parameter by one step
## @return: The new value after increase
func increase() -> float:
	var new_value: float
	
	if is_even_integer:
		# Special handling for even integers - always step by 2
		new_value = current_value + 2.0
	else:
		new_value = current_value + step_size
	
	current_value = validate_value(new_value)
	return current_value

## Decrease the parameter by one step
## @return: The new value after decrease
func decrease() -> float:
	var new_value: float
	
	if is_even_integer:
		# Special handling for even integers - always step by 2
		new_value = current_value - 2.0
	else:
		new_value = current_value - step_size
	
	current_value = validate_value(new_value)
	return current_value

## Reset the parameter to its default value
## @return: The default value
func reset_to_default() -> float:
	current_value = validate_value(default_value)
	return current_value

## Generate a random value within the parameter's range
## @return: A random valid value
func randomize() -> float:
	var random_value: float
	
	if is_even_integer:
		# Generate random even integer
		var min_steps = int(min_value / 2.0)
		var max_steps = int(max_value / 2.0)
		var random_steps = randi_range(min_steps, max_steps)
		random_value = float(random_steps * 2)
	elif is_integer:
		# Generate random integer
		random_value = float(randi_range(int(min_value), int(max_value)))
	else:
		# Generate random float and snap to step
		random_value = randf_range(min_value, max_value)
		if step_size > 0:
			random_value = round(random_value / step_size) * step_size
	
	current_value = validate_value(random_value)
	return current_value

## Create a copy of this parameter data
## @return: A new ParameterData instance with the same settings
func duplicate_parameter() -> ParameterData:
	var copy = ParameterData.new()
	copy.name = name
	copy.display_name = display_name
	copy.description = description
	copy.category = category
	copy.min_value = min_value
	copy.max_value = max_value
	copy.default_value = default_value
	copy.step_size = step_size
	copy.current_value = current_value
	copy.is_integer = is_integer
	copy.is_even_integer = is_even_integer
	copy.is_speed_parameter = is_speed_parameter
	copy.is_color_parameter = is_color_parameter
	copy.is_readonly = is_readonly
	copy.ui_format = ui_format
	copy.ui_suffix = ui_suffix
	copy.ui_order = ui_order
	copy.audio_reactive = audio_reactive
	copy.audio_frequency_band = audio_frequency_band
	copy.audio_intensity_multiplier = audio_intensity_multiplier
	copy.custom_validation = custom_validation
	copy.validation_script = validation_script
	return copy

## Convert to dictionary for serialization
## @return: Dictionary representation of the parameter
func to_dict() -> Dictionary:
	return {
		"name": name,
		"display_name": display_name,
		"description": description,
		"category": category,
		"min_value": min_value,
		"max_value": max_value,
		"default_value": default_value,
		"step_size": step_size,
		"current_value": current_value,
		"is_integer": is_integer,
		"is_even_integer": is_even_integer,
		"is_speed_parameter": is_speed_parameter,
		"is_color_parameter": is_color_parameter,
		"is_readonly": is_readonly,
		"ui_format": ui_format,
		"ui_suffix": ui_suffix,
		"ui_order": ui_order,
		"audio_reactive": audio_reactive,
		"audio_frequency_band": audio_frequency_band,
		"audio_intensity_multiplier": audio_intensity_multiplier
	}

## Load from dictionary
## @param data: Dictionary containing parameter data
func from_dict(data: Dictionary) -> void:
	name = data.get("name", "")
	display_name = data.get("display_name", "")
	description = data.get("description", "")
	category = data.get("category", "general")
	min_value = data.get("min_value", 0.0)
	max_value = data.get("max_value", 1.0)
	default_value = data.get("default_value", 0.5)
	step_size = data.get("step_size", 0.1)
	current_value = data.get("current_value", default_value)
	is_integer = data.get("is_integer", false)
	is_even_integer = data.get("is_even_integer", false)
	is_speed_parameter = data.get("is_speed_parameter", false)
	is_color_parameter = data.get("is_color_parameter", false)
	is_readonly = data.get("is_readonly", false)
	ui_format = data.get("ui_format", "%.2f")
	ui_suffix = data.get("ui_suffix", "")
	ui_order = data.get("ui_order", 0)
	audio_reactive = data.get("audio_reactive", false)
	audio_frequency_band = data.get("audio_frequency_band", "")
	audio_intensity_multiplier = data.get("audio_intensity_multiplier", 1.0)

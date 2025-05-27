class_name ColorPaletteManager
extends RefCounted

## ColorPaletteManager - Refactored Color Palette Management System
##
## This refactored ColorPaletteManager uses the new architecture with ConfigManager for settings,
## EventBus for communication, and supports external palette definitions. It maintains backward
## compatibility while providing a much cleaner and more extensible interface.
##
## Usage:
##   var palette_manager = ColorPaletteManager.new()
##   palette_manager.initialize()
##   palette_manager.cycle_palette_forward()

# Signals for palette events
signal palette_changed(palette_data: Dictionary, use_palette: bool)

# Palette definitions and state
var _color_palettes: Array[Dictionary] = []
var _custom_random_palette: Dictionary = {}
var _current_palette_index: int = 0
var _using_random_color: bool = false

# Configuration settings
var _palette_settings: Dictionary = {}

# Initialization state
var _is_initialized: bool = false

#region Initialization

## Initialize the color palette manager
## @return: True if initialization was successful
func initialize() -> bool:
	if _is_initialized:
		print("ColorPaletteManager: Already initialized")
		return true
	
	print("ColorPaletteManager: Initializing...")
	
	# Load configuration
	_load_palette_configuration()
	
	# Load palette definitions
	_load_palette_definitions()
	
	# Setup event connections
	_setup_event_connections()
	
	# Initialize custom random palette
	_initialize_custom_random_palette()
	
	_is_initialized = true
	print("ColorPaletteManager: Initialization complete")
	return true

## Load palette configuration from ConfigManager
func _load_palette_configuration() -> void:
	print("ColorPaletteManager: Loading palette configuration...")
	
	_palette_settings = {
		"default_palette": ConfigManager.get_config_value("visual.colors.default_palette", "bw"),
		"transition_speed": ConfigManager.get_config_value("visual.colors.color_transition_speed", 0.5),
		"intensity_range": ConfigManager.get_config_value("visual.colors.intensity_range", [0.1, 4.0]),
		"random_generation": {
			"min_value": ConfigManager.get_config_value("visual.colors.random.min_value", 0.0),
			"max_value": ConfigManager.get_config_value("visual.colors.random.max_value", 2.0),
			"allow_negative": ConfigManager.get_config_value("visual.colors.random.allow_negative", false)
		}
	}
	
	print("ColorPaletteManager: Configuration loaded")

## Load palette definitions (built-in and external)
func _load_palette_definitions() -> void:
	print("ColorPaletteManager: Loading palette definitions...")
	
	# Load built-in palettes first
	_load_builtin_palettes()
	
	# Try to load external palette definitions
	_load_external_palettes()
	
	# Set initial palette based on configuration
	_set_initial_palette()
	
	print("ColorPaletteManager: Loaded %d palette definitions" % _color_palettes.size())

## Load built-in color palettes (backward compatibility)
func _load_builtin_palettes() -> void:
	_color_palettes = [
		# B&W (default/off)
		{
			"name": "B&W",
			"description": "Black and white (no color)",
			"a": Vector3(0.5, 0.5, 0.5),
			"b": Vector3(0.5, 0.5, 0.5),
			"c": Vector3(1.0, 1.0, 1.0),
			"d": Vector3(0.0, 0.0, 0.0),
			"is_default": true
		},
		# Rainbow
		{
			"name": "Rainbow",
			"description": "Full spectrum rainbow colors",
			"a": Vector3(0.5, 0.5, 0.5),
			"b": Vector3(0.5, 0.5, 0.5),
			"c": Vector3(1.0, 1.0, 1.0),
			"d": Vector3(0.0, 0.33, 0.67)
		},
		# Fire
		{
			"name": "Fire",
			"description": "Warm fire colors",
			"a": Vector3(0.5, 0.2, 0.1),
			"b": Vector3(0.5, 0.3, 0.2),
			"c": Vector3(2.0, 1.0, 0.5),
			"d": Vector3(0.0, 0.25, 0.5)
		},
		# Ocean
		{
			"name": "Ocean",
			"description": "Cool ocean blues",
			"a": Vector3(0.2, 0.5, 0.8),
			"b": Vector3(0.2, 0.3, 0.5),
			"c": Vector3(1.0, 1.5, 2.0),
			"d": Vector3(0.0, 0.2, 0.5)
		},
		# Purple Dreams
		{
			"name": "Purple Dreams",
			"description": "Dreamy purple tones",
			"a": Vector3(0.8, 0.5, 0.4),
			"b": Vector3(0.2, 0.4, 0.2),
			"c": Vector3(2.0, 1.0, 1.0),
			"d": Vector3(0.0, 0.25, 0.25)
		},
		# Neon
		{
			"name": "Neon",
			"description": "Bright neon colors",
			"a": Vector3(0.2, 0.2, 0.2),
			"b": Vector3(0.8, 0.8, 0.8),
			"c": Vector3(1.0, 2.0, 1.5),
			"d": Vector3(0.0, 0.5, 0.8)
		},
		# Sunset
		{
			"name": "Sunset",
			"description": "Warm sunset colors",
			"a": Vector3(0.7, 0.3, 0.2),
			"b": Vector3(0.3, 0.2, 0.1),
			"c": Vector3(1.5, 1.0, 0.8),
			"d": Vector3(0.0, 0.1, 0.3)
		}
	]

## Load external palette definitions from resources
func _load_external_palettes() -> void:
	# Try to load from resources directory
	var palette_dir = "res://resources/palettes/"
	
	# Check if directory exists (this would be implemented when we create the resource system)
	# For now, we'll just note that this is where external palettes would be loaded
	print("ColorPaletteManager: External palette loading not yet implemented")

## Set initial palette based on configuration
func _set_initial_palette() -> void:
	var default_palette = _palette_settings.default_palette
	
	# Find palette by name
	for i in range(_color_palettes.size()):
		var palette = _color_palettes[i]
		if palette.name.to_lower() == default_palette.to_lower():
			_current_palette_index = i
			break
	
	print("ColorPaletteManager: Set initial palette to '%s' (index %d)" % [get_current_palette_name(), _current_palette_index])

## Setup event connections with EventBus
func _setup_event_connections() -> void:
	print("ColorPaletteManager: Setting up event connections...")
	
	# Connect to palette control events
	EventBus.connect_to_palette_cycle_requested(_on_palette_cycle_requested)
	EventBus.connect_to_palette_randomize_requested(_on_palette_randomize_requested)
	EventBus.connect_to_palette_reset_requested(_on_palette_reset_requested)
	
	# Connect to application lifecycle
	EventBus.connect_to_application_shutting_down(_on_application_shutdown)
	
	print("ColorPaletteManager: Event connections established")

## Initialize custom random palette structure
func _initialize_custom_random_palette() -> void:
	_custom_random_palette = {
		"name": "Random",
		"description": "Randomly generated colors",
		"a": Vector3.ZERO,
		"b": Vector3.ZERO,
		"c": Vector3.ZERO,
		"d": Vector3.ZERO,
		"is_random": true
	}

#endregion

#region Palette Management

## Cycle to the next palette
func cycle_palette_forward() -> void:
	_using_random_color = false
	_current_palette_index = (_current_palette_index + 1) % _color_palettes.size()
	_emit_current_palette()
	
	print("ColorPaletteManager: Cycled forward to '%s'" % get_current_palette_name())

## Cycle to the previous palette
func cycle_palette_backward() -> void:
	_using_random_color = false
	_current_palette_index = (_current_palette_index - 1) % _color_palettes.size()
	if _current_palette_index < 0:
		_current_palette_index = _color_palettes.size() - 1
	_emit_current_palette()
	
	print("ColorPaletteManager: Cycled backward to '%s'" % get_current_palette_name())

## Set palette by name
## @param palette_name: Name of the palette to set
## @return: True if palette was found and set
func set_palette_by_name(palette_name: String) -> bool:
	for i in range(_color_palettes.size()):
		var palette = _color_palettes[i]
		if palette.name.to_lower() == palette_name.to_lower():
			_using_random_color = false
			_current_palette_index = i
			_emit_current_palette()
			print("ColorPaletteManager: Set palette to '%s'" % palette_name)
			return true
	
	push_warning("ColorPaletteManager: Palette '%s' not found" % palette_name)
	return false

## Set palette by index
## @param index: Index of the palette to set
## @return: True if index was valid and palette was set
func set_palette_by_index(index: int) -> bool:
	if index < 0 or index >= _color_palettes.size():
		push_warning("ColorPaletteManager: Invalid palette index %d" % index)
		return false
	
	_using_random_color = false
	_current_palette_index = index
	_emit_current_palette()
	print("ColorPaletteManager: Set palette to index %d ('%s')" % [index, get_current_palette_name()])
	return true

## Generate and apply random colors
func randomize_colors() -> void:
	var settings = _palette_settings.random_generation
	
	# Generate random values within configured ranges
	_custom_random_palette["a"] = _generate_random_vector3(settings)
	_custom_random_palette["b"] = _generate_random_vector3(settings)
	_custom_random_palette["c"] = _generate_random_vector3(settings, true)  # Allow higher values for 'c'
	_custom_random_palette["d"] = _generate_random_vector3(settings)
	
	_using_random_color = true
	_emit_current_palette()
	
	print("ColorPaletteManager: Generated random color palette")

## Generate a random Vector3 within configured constraints
## @param settings: Random generation settings
## @param allow_higher: Whether to allow higher values (for 'c' component)
## @return: Random Vector3
func _generate_random_vector3(settings: Dictionary, allow_higher: bool = false) -> Vector3:
	var min_val = settings.min_value
	var max_val = settings.max_value
	
	if allow_higher:
		max_val *= 2.0  # Allow higher values for 'c' component
	
	var x = randf_range(min_val, max_val)
	var y = randf_range(min_val, max_val)
	var z = randf_range(min_val, max_val)
	
	# Apply negative values if allowed
	if settings.allow_negative:
		if randf() < 0.3:  # 30% chance for negative values
			x *= -1
		if randf() < 0.3:
			y *= -1
		if randf() < 0.3:
			z *= -1
	
	return Vector3(x, y, z)

## Reset to default palette (B&W)
func reset_to_bw() -> void:
	_using_random_color = false
	_current_palette_index = 0  # B&W is index 0
	_emit_current_palette()
	
	print("ColorPaletteManager: Reset to B&W palette")

## Reset to configured default palette
func reset_to_default() -> void:
	_using_random_color = false
	_set_initial_palette()
	_emit_current_palette()
	
	print("ColorPaletteManager: Reset to default palette")

#endregion

#region Palette Information

## Get the name of the current palette
## @return: Name of the current palette
func get_current_palette_name() -> String:
	if _using_random_color:
		return "Random"
	elif _current_palette_index < _color_palettes.size():
		return _color_palettes[_current_palette_index]["name"]
	else:
		return "Unknown"

## Get the description of the current palette
## @return: Description of the current palette
func get_current_palette_description() -> String:
	if _using_random_color:
		return "Randomly generated colors"
	elif _current_palette_index < _color_palettes.size():
		return _color_palettes[_current_palette_index].get("description", "No description")
	else:
		return "Unknown palette"

## Get current palette display text for UI
## @return: Formatted display text
func get_current_palette_display() -> String:
	var palette_name = get_current_palette_name()
	var description = get_current_palette_description()
	
	return "Color Palette: %s\n%s\n[↑/↓] cycle palettes\n[←/→] change parameter [r] reset [R] reset all" % [palette_name, description]

## Get current palette data
## @return: Dictionary containing current palette data
func get_current_palette_data() -> Dictionary:
	if _using_random_color:
		return _custom_random_palette.duplicate()
	elif _current_palette_index < _color_palettes.size():
		return _color_palettes[_current_palette_index].duplicate()
	else:
		return {}

## Get all available palette names
## @return: Array of palette names
func get_available_palette_names() -> Array[String]:
	var names: Array[String] = []
	for palette in _color_palettes:
		names.append(palette["name"])
	names.append("Random")
	return names

## Get palette count
## @return: Number of available palettes (excluding random)
func get_palette_count() -> int:
	return _color_palettes.size()

## Check if currently using random colors
## @return: True if using random colors
func is_using_random_colors() -> bool:
	return _using_random_color

#endregion

#region Palette Emission

## Emit the current palette to listeners
func _emit_current_palette() -> void:
	var palette_data = get_current_palette_data()
	
	# B&W palette (index 0) and not using random means no color palette
	var use_palette = _current_palette_index > 0 or _using_random_color
	
	# Emit local signal
	palette_changed.emit(palette_data, use_palette)
	
	# Emit to EventBus for other components
	EventBus.emit_palette_changed(palette_data)
	
	# Update UI text
	var display_text = get_current_palette_display()
	EventBus.emit_text_update_requested(display_text)

## Force emit current palette (useful for initialization)
func emit_current_palette() -> void:
	_emit_current_palette()

#endregion

#region Event Handlers

## Handle palette cycle requests from EventBus
## @param direction: 1 for forward, -1 for backward
func _on_palette_cycle_requested(direction: int) -> void:
	if direction > 0:
		cycle_palette_forward()
	else:
		cycle_palette_backward()

## Handle palette randomization requests from EventBus
func _on_palette_randomize_requested() -> void:
	randomize_colors()

## Handle palette reset requests from EventBus
## @param to_default: Whether to reset to configured default or B&W
func _on_palette_reset_requested(to_default: bool = false) -> void:
	if to_default:
		reset_to_default()
	else:
		reset_to_bw()

## Handle application shutdown
func _on_application_shutdown() -> void:
	cleanup()

#endregion

#region Serialization

## Save palette state data
## @return: Dictionary containing palette state
func save_palette_data() -> Dictionary:
	return {
		"current_palette_index": _current_palette_index,
		"using_random_color": _using_random_color,
		"custom_random_palette": _custom_random_palette.duplicate()
	}

## Load palette state data
## @param data: Dictionary containing palette state
func load_palette_data(data: Dictionary) -> void:
	if "current_palette_index" in data:
		var index = data["current_palette_index"]
		if index >= 0 and index < _color_palettes.size():
			_current_palette_index = index
		else:
			push_warning("ColorPaletteManager: Invalid palette index in save data: %d" % index)
	
	if "using_random_color" in data:
		_using_random_color = data["using_random_color"]
	
	if "custom_random_palette" in data:
		var custom_palette = data["custom_random_palette"]
		if custom_palette is Dictionary:
			_custom_random_palette = custom_palette.duplicate()
	
	# Emit the loaded palette
	_emit_current_palette()
	
	print("ColorPaletteManager: Loaded palette data - Index: %d, Random: %s" % [_current_palette_index, _using_random_color])

#endregion

#region Palette Management (Advanced)

## Add a new palette definition
## @param palette_data: Dictionary containing palette definition
## @return: True if palette was added successfully
func add_palette(palette_data: Dictionary) -> bool:
	# Validate palette data
	if not _validate_palette_data(palette_data):
		push_error("ColorPaletteManager: Invalid palette data")
		return false
	
	# Check for duplicate names
	var name = palette_data.get("name", "")
	for existing_palette in _color_palettes:
		if existing_palette["name"] == name:
			push_warning("ColorPaletteManager: Palette with name '%s' already exists" % name)
			return false
	
	_color_palettes.append(palette_data.duplicate())
	print("ColorPaletteManager: Added new palette '%s'" % name)
	return true

## Remove a palette by name
## @param palette_name: Name of the palette to remove
## @return: True if palette was removed
func remove_palette(palette_name: String) -> bool:
	for i in range(_color_palettes.size()):
		var palette = _color_palettes[i]
		if palette["name"] == palette_name:
			# Don't allow removing the default B&W palette
			if palette.get("is_default", false):
				push_warning("ColorPaletteManager: Cannot remove default palette '%s'" % palette_name)
				return false
			
			_color_palettes.remove_at(i)
			
			# Adjust current index if necessary
			if _current_palette_index >= i:
				_current_palette_index = max(0, _current_palette_index - 1)
				_emit_current_palette()
			
			print("ColorPaletteManager: Removed palette '%s'" % palette_name)
			return true
	
	push_warning("ColorPaletteManager: Palette '%s' not found" % palette_name)
	return false

## Validate palette data structure
## @param palette_data: Dictionary to validate
## @return: True if valid
func _validate_palette_data(palette_data: Dictionary) -> bool:
	# Check required fields
	var required_fields = ["name", "a", "b", "c", "d"]
	for field in required_fields:
		if not field in palette_data:
			return false
	
	# Check Vector3 fields
	var vector_fields = ["a", "b", "c", "d"]
	for field in vector_fields:
		if not palette_data[field] is Vector3:
			return false
	
	return true

#endregion

#region Public API

## Get palette manager information for debugging
## @return: Dictionary with manager information
func get_palette_info() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"current_palette_index": _current_palette_index,
		"current_palette_name": get_current_palette_name(),
		"using_random_color": _using_random_color,
		"total_palettes": _color_palettes.size(),
		"available_palettes": get_available_palette_names(),
		"palette_settings": _palette_settings.duplicate()
	}

## Check if the manager is properly initialized
## @return: True if initialized and ready
func is_ready() -> bool:
	return _is_initialized

#endregion

#region Cleanup

## Clean up resources and connections
func cleanup() -> void:
	print("ColorPaletteManager: Cleaning up resources...")
	
	# Clear palette data
	_color_palettes.clear()
	_custom_random_palette.clear()
	_palette_settings.clear()
	
	# Reset state
	_current_palette_index = 0
	_using_random_color = false
	_is_initialized = false
	
	print("ColorPaletteManager: Cleanup complete")

#endregion

class_name ShaderManager
extends RefCounted

## ShaderManager - Centralized Shader Parameter Management
##
## This class manages shader parameters across multiple shaders, providing a unified
## interface for parameter updates, shader switching, and performance optimization.
## It integrates with the ParameterManager and EventBus for seamless operation.
##
## Usage:
##   var shader_manager = ShaderManager.new()
##   shader_manager.initialize(shader_material)
##   shader_manager.update_parameter("zoom_level", 1.5)

# Signals for shader events
signal shader_switched(shader_name: String)
signal parameter_updated(param_name: String, value: float)

# Shader materials and resources
var _current_material: ShaderMaterial
var _shader_resources: Dictionary = {}
var _current_shader_name: String = ""

# Parameter mappings for different shaders
var _parameter_mappings: Dictionary = {}

# Shader state and settings
var _shader_settings: Dictionary = {}
var _performance_settings: Dictionary = {}

# Initialization state
var _is_initialized: bool = false

#region Initialization

## Initialize the shader manager with a shader material
## @param material: ShaderMaterial to manage
## @return: True if initialization was successful
func initialize(material: ShaderMaterial) -> bool:
	if _is_initialized:
		print("ShaderManager: Already initialized")
		return true
	
	if not material:
		push_error("ShaderManager: Invalid shader material provided")
		return false
	
	_current_material = material
	
	# Load configuration
	_load_shader_configuration()
	
	# Load shader resources
	_load_shader_resources()
	
	# Setup parameter mappings
	_setup_parameter_mappings()
	
	# Setup event connections
	_setup_event_connections()
	
	# Set initial shader
	_set_initial_shader()
	
	_is_initialized = true
	print("ShaderManager: Initialized successfully")
	return true

## Load shader configuration from ConfigManager
func _load_shader_configuration() -> void:
	print("ShaderManager: Loading shader configuration...")
	
	# Load shader settings
	_shader_settings = {
		"default_shader": ConfigManager.get_default_shader_path(),
		"kaleidoscope_shader": ConfigManager.get_kaleidoscope_shader_path(),
		"koch_shader": ConfigManager.get_koch_shader_path(),
		"auto_switch": ConfigManager.get_config_value("visual.shaders.auto_switch", false),
		"transition_duration": ConfigManager.get_config_value("visual.shaders.transition_duration", 1.0)
	}
	
	# Load performance settings
	_performance_settings = {
		"update_frequency": ConfigManager.get_config_value("visual.shaders.update_frequency", 60.0),
		"batch_updates": ConfigManager.get_config_value("visual.shaders.batch_updates", true),
		"precision": ConfigManager.get_config_value("visual.shaders.precision", "highp")
	}
	
	print("ShaderManager: Configuration loaded")

## Load shader resources from file paths
func _load_shader_resources() -> void:
	print("ShaderManager: Loading shader resources...")
	
	# Load each shader
	for shader_name in ["default", "kaleidoscope", "koch"]:
		var shader_path = _shader_settings.get(shader_name + "_shader", "")
		if shader_path != "":
			var shader = load(shader_path) as Shader
			if shader:
				_shader_resources[shader_name] = shader
				print("ShaderManager: Loaded %s shader from %s" % [shader_name, shader_path])
			else:
				push_warning("ShaderManager: Failed to load %s shader from %s" % [shader_name, shader_path])
	
	print("ShaderManager: Loaded %d shader resources" % _shader_resources.size())

## Setup parameter mappings for different shaders
func _setup_parameter_mappings() -> void:
	print("ShaderManager: Setting up parameter mappings...")
	
	# Default shader (kaldao) parameter mappings
	_parameter_mappings["default"] = {
		"fly_speed": "fly_speed",
		"contrast": "contrast",
		"truchet_radius": "truchet_radius",
		"rotation_speed": "rotation_speed",
		"zoom_level": "zoom_level",
		"color_intensity": "color_intensity",
		"plane_rotation_speed": "plane_rotation_speed",
		"camera_tilt_x": "camera_tilt_x",
		"camera_tilt_y": "camera_tilt_y",
		"camera_roll": "camera_roll",
		"path_stability": "path_stability",
		"path_skew": "path_skew",
		"color_speed": "color_speed"
	}
	
	# Kaleidoscope shader parameter mappings
	_parameter_mappings["kaleidoscope"] = {
		"kaleidoscope_segments": "segments",
		"rotation_speed": "rotation_speed",
		"zoom_level": "zoom",
		"color_intensity": "color_intensity",
		"color_speed": "color_speed",
		"contrast": "contrast"
	}
	
	# Koch shader parameter mappings
	_parameter_mappings["koch"] = {
		"zoom_level": "zoom",
		"rotation_speed": "rotation",
		"color_intensity": "intensity",
		"contrast": "contrast",
		"fly_speed": "speed"
	}
	
	print("ShaderManager: Parameter mappings configured for %d shaders" % _parameter_mappings.size())

## Setup event connections with EventBus
func _setup_event_connections() -> void:
	print("ShaderManager: Setting up event connections...")
	
	# Connect to parameter changes
	EventBus.connect_to_parameter_changed(_on_parameter_changed)
	
	# Connect to palette changes
	EventBus.connect_to_palette_changed(_on_palette_changed)
	
	# Connect to application lifecycle
	EventBus.connect_to_application_shutting_down(_on_application_shutdown)
	
	print("ShaderManager: Event connections established")

## Set the initial shader based on configuration
func _set_initial_shader() -> void:
	var default_shader = _shader_settings.get("default_shader", "")
	if default_shader != "":
		# Extract shader name from path
		var shader_name = "default"
		if "kaleidoscope" in default_shader:
			shader_name = "kaleidoscope"
		elif "koch" in default_shader:
			shader_name = "koch"
		
		switch_shader(shader_name)
	else:
		print("ShaderManager: No default shader configured")

#endregion

#region Shader Management

## Switch to a different shader
## @param shader_name: Name of the shader to switch to ("default", "kaleidoscope", "koch")
## @return: True if shader was switched successfully
func switch_shader(shader_name: String) -> bool:
	if not _is_initialized:
		push_error("ShaderManager: Not initialized")
		return false
	
	if shader_name == _current_shader_name:
		print("ShaderManager: Already using %s shader" % shader_name)
		return true
	
	if not shader_name in _shader_resources:
		push_error("ShaderManager: Shader '%s' not found" % shader_name)
		return false
	
	var shader = _shader_resources[shader_name]
	_current_material.shader = shader
	_current_shader_name = shader_name
	
	# Update all current parameters for the new shader
	_update_all_parameters_for_shader()
	
	# Emit signal
	shader_switched.emit(shader_name)
	
	print("ShaderManager: Switched to %s shader" % shader_name)
	return true

## Get the currently active shader name
## @return: Name of the current shader
func get_current_shader() -> String:
	return _current_shader_name

## Get list of available shaders
## @return: Array of available shader names
func get_available_shaders() -> Array:
	return _shader_resources.keys()

## Check if a shader is available
## @param shader_name: Name of the shader to check
## @return: True if shader is available
func has_shader(shader_name: String) -> bool:
	return shader_name in _shader_resources

#endregion

#region Parameter Management

## Update a shader parameter
## @param param_name: Name of the parameter
## @param value: New value for the parameter
func update_parameter(param_name: String, value: float) -> void:
	if not _is_initialized or not _current_material:
		return
	
	# Get the shader-specific parameter name
	var shader_param_name = _get_shader_parameter_name(param_name)
	if shader_param_name == "":
		return  # Parameter not supported by current shader
	
	# Update the shader parameter
	_current_material.set_shader_parameter(shader_param_name, value)
	
	# Emit signal
	parameter_updated.emit(param_name, value)

## Update multiple parameters at once (batch update)
## @param parameters: Dictionary of parameter names and values
func update_parameters(parameters: Dictionary) -> void:
	if not _is_initialized or not _current_material:
		return
	
	for param_name in parameters:
		var value = parameters[param_name]
		var shader_param_name = _get_shader_parameter_name(param_name)
		if shader_param_name != "":
			_current_material.set_shader_parameter(shader_param_name, value)
			parameter_updated.emit(param_name, value)

## Get the shader-specific parameter name for a given parameter
## @param param_name: Generic parameter name
## @return: Shader-specific parameter name, or empty string if not supported
func _get_shader_parameter_name(param_name: String) -> String:
	if _current_shader_name == "":
		return ""
	
	var mappings = _parameter_mappings.get(_current_shader_name, {})
	return mappings.get(param_name, "")

## Update all parameters for the current shader
func _update_all_parameters_for_shader() -> void:
	if not _current_shader_name in _parameter_mappings:
		return
	
	# Get parameter manager
	var parameter_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
	if not parameter_manager:
		return
	
	# Update all mapped parameters
	var mappings = _parameter_mappings[_current_shader_name]
	for param_name in mappings:
		var value = parameter_manager.get_parameter_value(param_name)
		var shader_param_name = mappings[param_name]
		_current_material.set_shader_parameter(shader_param_name, value)

## Get supported parameters for the current shader
## @return: Array of parameter names supported by current shader
func get_supported_parameters() -> Array:
	if _current_shader_name == "":
		return []
	
	var mappings = _parameter_mappings.get(_current_shader_name, {})
	return mappings.keys()

## Check if a parameter is supported by the current shader
## @param param_name: Name of the parameter to check
## @return: True if parameter is supported
func is_parameter_supported(param_name: String) -> bool:
	return _get_shader_parameter_name(param_name) != ""

#endregion

#region Color Palette Management

## Update color palette for the shader
## @param palette_data: Dictionary containing palette information
func update_color_palette(palette_data: Dictionary) -> void:
	if not _is_initialized or not _current_material:
		return
	
	# Extract colors from palette data
	var colors = palette_data.get("colors", [])
	if colors.size() == 0:
		return
	
	# Update shader color parameters based on current shader
	match _current_shader_name:
		"default":
			_update_default_shader_colors(colors)
		"kaleidoscope":
			_update_kaleidoscope_shader_colors(colors)
		"koch":
			_update_koch_shader_colors(colors)

## Update colors for the default shader
## @param colors: Array of Color objects
func _update_default_shader_colors(colors: Array) -> void:
	# Set primary colors
	if colors.size() > 0:
		_current_material.set_shader_parameter("color1", colors[0])
	if colors.size() > 1:
		_current_material.set_shader_parameter("color2", colors[1])
	if colors.size() > 2:
		_current_material.set_shader_parameter("color3", colors[2])

## Update colors for the kaleidoscope shader
## @param colors: Array of Color objects
func _update_kaleidoscope_shader_colors(colors: Array) -> void:
	# Set kaleidoscope colors
	if colors.size() > 0:
		_current_material.set_shader_parameter("base_color", colors[0])
	if colors.size() > 1:
		_current_material.set_shader_parameter("accent_color", colors[1])

## Update colors for the koch shader
## @param colors: Array of Color objects
func _update_koch_shader_colors(colors: Array) -> void:
	# Set koch fractal colors
	if colors.size() > 0:
		_current_material.set_shader_parameter("fractal_color", colors[0])

#endregion

#region Event Handlers

## Handle parameter changes from EventBus
## @param param_name: Name of the changed parameter
## @param value: New parameter value
func _on_parameter_changed(param_name: String, value: float) -> void:
	update_parameter(param_name, value)

## Handle palette changes from EventBus
## @param palette_data: Dictionary containing palette information
func _on_palette_changed(palette_data: Dictionary) -> void:
	update_color_palette(palette_data)

## Handle application shutdown
func _on_application_shutdown() -> void:
	cleanup()

#endregion

#region Performance Optimization

## Set shader update frequency
## @param frequency: Updates per second (0 = every frame)
func set_update_frequency(frequency: float) -> void:
	_performance_settings.update_frequency = frequency
	print("ShaderManager: Update frequency set to %.1f Hz" % frequency)

## Enable or disable batch updates
## @param enabled: Whether to batch parameter updates
func set_batch_updates_enabled(enabled: bool) -> void:
	_performance_settings.batch_updates = enabled
	print("ShaderManager: Batch updates %s" % ("enabled" if enabled else "disabled"))

## Set shader precision
## @param precision: Shader precision ("lowp", "mediump", "highp")
func set_shader_precision(precision: String) -> void:
	_performance_settings.precision = precision
	print("ShaderManager: Shader precision set to %s" % precision)

#endregion

#region Public API

## Get current shader material
## @return: Current ShaderMaterial instance
func get_material() -> ShaderMaterial:
	return _current_material

## Get shader information for debugging
## @return: Dictionary with shader information
func get_shader_info() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"current_shader": _current_shader_name,
		"available_shaders": get_available_shaders(),
		"supported_parameters": get_supported_parameters(),
		"shader_settings": _shader_settings.duplicate(),
		"performance_settings": _performance_settings.duplicate()
	}

## Get parameter mappings for debugging
## @return: Dictionary with parameter mappings
func get_parameter_mappings() -> Dictionary:
	return _parameter_mappings.duplicate(true)

## Check if the manager is properly initialized
## @return: True if initialized and ready
func is_ready() -> bool:
	return _is_initialized and _current_material != null

## Reload shaders from disk
## @return: True if reload was successful
func reload_shaders() -> bool:
	print("ShaderManager: Reloading shaders...")
	
	var current_shader = _current_shader_name
	_shader_resources.clear()
	
	_load_shader_resources()
	
	if current_shader != "" and current_shader in _shader_resources:
		switch_shader(current_shader)
		print("ShaderManager: Shaders reloaded successfully")
		return true
	else:
		push_error("ShaderManager: Failed to reload current shader")
		return false

#endregion

#region Utility Methods

## Create a new shader material with the specified shader
## @param shader_name: Name of the shader to use
## @return: New ShaderMaterial instance, or null if failed
func create_material_with_shader(shader_name: String) -> ShaderMaterial:
	if not shader_name in _shader_resources:
		push_error("ShaderManager: Shader '%s' not found" % shader_name)
		return null
	
	var material = ShaderMaterial.new()
	material.shader = _shader_resources[shader_name]
	
	print("ShaderManager: Created material with %s shader" % shader_name)
	return material

## Copy current shader parameters to another material
## @param target_material: Material to copy parameters to
func copy_parameters_to_material(target_material: ShaderMaterial) -> void:
	if not _current_material or not target_material:
		return
	
	# Get all shader parameters from current material
	var shader_params = _current_material.get_property_list()
	for param in shader_params:
		if param.name.begins_with("shader_parameter/"):
			var param_name = param.name.substr(17)  # Remove "shader_parameter/" prefix
			var value = _current_material.get_shader_parameter(param_name)
			target_material.set_shader_parameter(param_name, value)
	
	print("ShaderManager: Copied parameters to target material")

## Get shader parameter value
## @param param_name: Name of the parameter
## @return: Current parameter value, or null if not found
func get_shader_parameter(param_name: String):
	if not _current_material:
		return null
	
	var shader_param_name = _get_shader_parameter_name(param_name)
	if shader_param_name == "":
		return null
	
	return _current_material.get_shader_parameter(shader_param_name)

#endregion

#region Cleanup

## Clean up resources and connections
func cleanup() -> void:
	print("ShaderManager: Cleaning up resources...")
	
	# Clear references
	_current_material = null
	_shader_resources.clear()
	_parameter_mappings.clear()
	_shader_settings.clear()
	_performance_settings.clear()
	
	# Reset state
	_current_shader_name = ""
	_is_initialized = false
	
	print("ShaderManager: Cleanup complete")

#endregion

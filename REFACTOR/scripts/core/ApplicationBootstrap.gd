class_name ApplicationBootstrap
extends RefCounted

## ApplicationBootstrap - Application Initialization and Lifecycle Management
##
## This class manages the proper initialization sequence of the application,
## ensuring all services are created and connected in the correct order.
## It also handles application shutdown and cleanup.
##
## Usage:
##   # Initialize the application
##   ApplicationBootstrap.initialize()
##   
##   # Check if initialized
##   if ApplicationBootstrap.is_initialized():
##       # Application is ready
##
## @tutorial: Initialization order is critical for proper dependency resolution

# Initialization state
static var _is_initialized: bool = false
static var _initialization_start_time: float = 0.0

# Required services for basic functionality
const REQUIRED_CORE_SERVICES = [
	ServiceLocator.CONFIG_MANAGER,
	ServiceLocator.PARAMETER_MANAGER,
	ServiceLocator.COLOR_PALETTE_MANAGER
]

# Optional services that can be registered later
const OPTIONAL_SERVICES = [
	ServiceLocator.AUDIO_MANAGER,
	ServiceLocator.SHADER_MANAGER,
	ServiceLocator.SCREENSHOT_MANAGER,
	ServiceLocator.TIMELINE_MANAGER,
	ServiceLocator.INPUT_MANAGER,
	ServiceLocator.MENU_MANAGER
]

#region Core Initialization

## Initialize the entire application in the correct order
## @return: True if initialization was successful
static func initialize() -> bool:
	if _is_initialized:
		print("ApplicationBootstrap: Already initialized")
		return true
	
	_initialization_start_time = Time.get_time_dict_from_system().hour * 3600 + \
								 Time.get_time_dict_from_system().minute * 60 + \
								 Time.get_time_dict_from_system().second
	
	print("ApplicationBootstrap: Starting application initialization...")
	EventBus.emit_application_starting()
	
	# Step 1: Load configuration first (everything depends on this)
	if not _initialize_configuration():
		push_error("ApplicationBootstrap: Failed to initialize configuration")
		return false
	
	# Step 2: Initialize core services that don't depend on scene nodes
	if not _initialize_core_services():
		push_error("ApplicationBootstrap: Failed to initialize core services")
		return false
	
	# Step 3: Setup initial event connections between core services
	_setup_core_event_connections()
	
	# Step 4: Validate that required services are available
	if not _validate_core_services():
		push_error("ApplicationBootstrap: Core service validation failed")
		return false
	
	_is_initialized = true
	
	var elapsed_time = Time.get_time_dict_from_system().hour * 3600 + \
					   Time.get_time_dict_from_system().minute * 60 + \
					   Time.get_time_dict_from_system().second - _initialization_start_time
	
	print("ApplicationBootstrap: Core initialization complete in %.3fs" % elapsed_time)
	EventBus.emit_application_ready()
	
	return true

## Complete initialization with scene-dependent services
## This should be called after the main scene is loaded
## @param main_scene: Reference to the main scene node
## @return: True if scene initialization was successful
static func initialize_scene_services(main_scene: Node) -> bool:
	if not _is_initialized:
		push_error("ApplicationBootstrap: Core initialization must be completed first")
		return false
	
	print("ApplicationBootstrap: Initializing scene-dependent services...")
	
	# Register scene-dependent services
	if not _register_scene_services(main_scene):
		push_error("ApplicationBootstrap: Failed to register scene services")
		return false
	
	# Setup connections between all services
	_setup_all_event_connections()
	
	# Final validation
	if not _validate_all_services():
		push_warning("ApplicationBootstrap: Some optional services are missing")
	
	print("ApplicationBootstrap: Scene initialization complete")
	return true

#endregion

#region Private Initialization Methods

## Initialize configuration system
static func _initialize_configuration() -> bool:
	print("ApplicationBootstrap: Loading configuration...")
	
	# Create and register config manager
	var config_manager = ConfigManager.new()
	ServiceLocator.register_service(ServiceLocator.CONFIG_MANAGER, config_manager)
	
	# Load configuration
	if not ConfigManager.load_config():
		push_error("ApplicationBootstrap: Failed to load configuration")
		return false
	
	# Validate configuration
	if not ConfigManager.validate_config():
		push_warning("ApplicationBootstrap: Configuration validation failed, using defaults")
	
	print("ApplicationBootstrap: Configuration loaded successfully")
	return true

## Initialize core services that don't depend on scene nodes
static func _initialize_core_services() -> bool:
	print("ApplicationBootstrap: Initializing core services...")
	
	# Create parameter manager
	var parameter_manager = ParameterManager.new()
	ServiceLocator.register_service(ServiceLocator.PARAMETER_MANAGER, parameter_manager)
	
	# Create color palette manager
	var color_palette_manager = ColorPaletteManager.new()
	ServiceLocator.register_service(ServiceLocator.COLOR_PALETTE_MANAGER, color_palette_manager)
	
	# Create screenshot manager
	var screenshot_manager = ScreenshotManager.new()
	ServiceLocator.register_service(ServiceLocator.SCREENSHOT_MANAGER, screenshot_manager)
	
	print("ApplicationBootstrap: Core services initialized")
	return true

## Setup event connections between core services
static func _setup_core_event_connections() -> void:
	print("ApplicationBootstrap: Setting up core event connections...")
	
	var parameter_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
	var color_palette_manager = ServiceLocator.get_service(ServiceLocator.COLOR_PALETTE_MANAGER)
	var screenshot_manager = ServiceLocator.get_service(ServiceLocator.SCREENSHOT_MANAGER)
	
	# Connect parameter manager to EventBus
	if parameter_manager and parameter_manager.has_signal("parameter_changed"):
		parameter_manager.parameter_changed.connect(EventBus.emit_parameter_changed)
	
	# Connect color palette manager to EventBus
	if color_palette_manager and color_palette_manager.has_signal("palette_changed"):
		color_palette_manager.palette_changed.connect(EventBus.emit_palette_changed)
	
	# Connect screenshot manager to EventBus
	if screenshot_manager:
		if screenshot_manager.has_signal("screenshot_taken"):
			screenshot_manager.screenshot_taken.connect(EventBus.emit_screenshot_completed)
		if screenshot_manager.has_signal("screenshot_failed"):
			screenshot_manager.screenshot_failed.connect(EventBus.emit_screenshot_failed)
	
	print("ApplicationBootstrap: Core event connections established")

## Validate that required core services are available
static func _validate_core_services() -> bool:
	return ServiceLocator.validate_required_services(REQUIRED_CORE_SERVICES)

## Register services that depend on scene nodes
static func _register_scene_services(main_scene: Node) -> bool:
	print("ApplicationBootstrap: Registering scene-dependent services...")
	
	# Find and register audio manager
	var audio_manager = _find_audio_manager(main_scene)
	if audio_manager:
		register_audio_manager(audio_manager)
	else:
		push_warning("ApplicationBootstrap: Audio manager not found in scene")
	
	# Find and register shader manager
	var shader_manager = _find_shader_manager(main_scene)
	if shader_manager:
		register_shader_manager(shader_manager)
	else:
		push_warning("ApplicationBootstrap: Shader manager not found in scene")
	
	# Create and register input manager
	var input_manager = InputManager.new()
	ServiceLocator.register_service(ServiceLocator.INPUT_MANAGER, input_manager)
	
	# Create and register menu manager
	var menu_manager = MenuManager.new()
	ServiceLocator.register_service(ServiceLocator.MENU_MANAGER, menu_manager)
	
	return true

## Find audio manager in the scene tree
static func _find_audio_manager(scene_root: Node) -> AudioManager:
	# Look for AudioStreamPlayer with AudioManager script
	var audio_players = _find_nodes_by_type(scene_root, AudioStreamPlayer)
	for player in audio_players:
		if player.get_script() and player.get_script().get_global_name() == "AudioManager":
			return player as AudioManager
	
	return null

## Find shader manager in the scene tree
static func _find_shader_manager(scene_root: Node) -> ShaderManager:
	# Look for ColorRect with shader material
	var color_rects = _find_nodes_by_type(scene_root, ColorRect)
	for rect in color_rects:
		if rect.material and rect.material is ShaderMaterial:
			# Create shader manager for this material
			return ShaderManager.new(rect.material)
	
	return null

## Helper function to find nodes by type
static func _find_nodes_by_type(root: Node, type: Variant) -> Array:
	var found_nodes = []
	
	func _recursive_find(node: Node):
		if node is type:
			found_nodes.append(node)
		
		for child in node.get_children():
			_recursive_find(child)
	
	_recursive_find(root)
	return found_nodes

## Setup all event connections after all services are registered
static func _setup_all_event_connections() -> void:
	print("ApplicationBootstrap: Setting up all event connections...")
	
	# Get all services
	var audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
	var parameter_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
	var shader_manager = ServiceLocator.get_service(ServiceLocator.SHADER_MANAGER)
	var input_manager = ServiceLocator.get_service(ServiceLocator.INPUT_MANAGER)
	
	# Connect audio manager if available
	if audio_manager and parameter_manager:
		audio_manager.connect_to_parameter_manager(parameter_manager)
		
		# Connect audio events to EventBus
		if audio_manager.has_signal("bass_detected"):
			audio_manager.bass_detected.connect(func(intensity): EventBus.emit_audio_levels_changed(intensity, 0.0, 0.0))
		if audio_manager.has_signal("beat_detected"):
			audio_manager.beat_detected.connect(func(): EventBus.emit_beat_detected(1.0))
	
	# Connect shader manager to parameter changes
	if shader_manager:
		EventBus.connect_to_parameter_changed(shader_manager.update_parameter)
		EventBus.connect_to_palette_changed(shader_manager.update_color_palette)
	
	# Connect input manager to EventBus
	if input_manager:
		_setup_input_connections(input_manager)
	
	print("ApplicationBootstrap: All event connections established")

## Setup input manager connections
static func _setup_input_connections(input_manager: InputManager) -> void:
	# Connect input events to EventBus
	if input_manager.has_signal("parameter_increase_requested"):
		input_manager.parameter_increase_requested.connect(EventBus.emit_parameter_increase_requested)
	if input_manager.has_signal("parameter_decrease_requested"):
		input_manager.parameter_decrease_requested.connect(EventBus.emit_parameter_decrease_requested)
	if input_manager.has_signal("parameter_next_requested"):
		input_manager.parameter_next_requested.connect(EventBus.emit_parameter_next_requested)
	if input_manager.has_signal("parameter_previous_requested"):
		input_manager.parameter_previous_requested.connect(EventBus.emit_parameter_previous_requested)
	if input_manager.has_signal("pause_toggle_requested"):
		input_manager.pause_toggle_requested.connect(EventBus.emit_pause_toggle_requested)

## Validate that all services are available (including optional ones)
static func _validate_all_services() -> bool:
	var all_services = REQUIRED_CORE_SERVICES + OPTIONAL_SERVICES
	var missing_services = []
	
	for service_name in all_services:
		if not ServiceLocator.has_service(service_name):
			missing_services.append(service_name)
	
	if missing_services.size() > 0:
		print("ApplicationBootstrap: Missing optional services: %s" % missing_services)
		return false
	
	return true

#endregion

#region Public Service Registration Methods

## Register an audio manager instance
## @param audio_manager: The AudioManager instance to register
static func register_audio_manager(audio_manager: AudioManager) -> void:
	if not audio_manager:
		push_error("ApplicationBootstrap: Cannot register null audio manager")
		return
	
	ServiceLocator.register_service(ServiceLocator.AUDIO_MANAGER, audio_manager)
	
	# Connect to parameter manager if available
	var parameter_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
	if parameter_manager:
		audio_manager.connect_to_parameter_manager(parameter_manager)
	
	print("ApplicationBootstrap: Audio manager registered and connected")

## Register a shader manager instance
## @param shader_manager: The ShaderManager instance to register
static func register_shader_manager(shader_manager: ShaderManager) -> void:
	if not shader_manager:
		push_error("ApplicationBootstrap: Cannot register null shader manager")
		return
	
	ServiceLocator.register_service(ServiceLocator.SHADER_MANAGER, shader_manager)
	
	# Connect to parameter and palette changes
	EventBus.connect_to_parameter_changed(shader_manager.update_parameter)
	EventBus.connect_to_palette_changed(shader_manager.update_color_palette)
	
	print("ApplicationBootstrap: Shader manager registered and connected")

## Register a timeline manager instance
## @param timeline_manager: The TimelineManager instance to register
static func register_timeline_manager(timeline_manager: TimelineManager) -> void:
	if not timeline_manager:
		push_error("ApplicationBootstrap: Cannot register null timeline manager")
		return
	
	ServiceLocator.register_service(ServiceLocator.TIMELINE_MANAGER, timeline_manager)
	
	# Connect timeline events
	if timeline_manager.has_signal("seek_requested"):
		timeline_manager.seek_requested.connect(EventBus.emit_timeline_seek_requested)
	if timeline_manager.has_signal("play_pause_requested"):
		timeline_manager.play_pause_requested.connect(EventBus.emit_timeline_play_pause_requested)
	
	print("ApplicationBootstrap: Timeline manager registered and connected")

#endregion

#region Application Lifecycle

## Shutdown the application cleanly
static func shutdown() -> void:
	if not _is_initialized:
		return
	
	print("ApplicationBootstrap: Shutting down application...")
	EventBus.emit_application_shutting_down()
	
	# Save configuration
	ConfigManager.save_config()
	
	# Cleanup all services
	ServiceLocator.clear_all_services()
	
	# Disconnect all event bus connections
	EventBus.disconnect_all()
	
	_is_initialized = false
	print("ApplicationBootstrap: Application shutdown complete")

## Check if the application is initialized
## @return: True if the application has been initialized
static func is_initialized() -> bool:
	return _is_initialized

## Get initialization status for debugging
## @return: Dictionary with detailed initialization information
static func get_initialization_status() -> Dictionary:
	return {
		"is_initialized": _is_initialized,
		"config_loaded": ConfigManager._is_loaded if ConfigManager else false,
		"services": ServiceLocator.get_service_info(),
		"event_connections": EventBus.get_connection_info(),
		"required_services_available": ServiceLocator.validate_required_services(REQUIRED_CORE_SERVICES),
		"all_services_available": _validate_all_services() if _is_initialized else false
	}

#endregion

#region Utility Methods

## Get all core managers in a single call (convenience method)
## @return: Dictionary with all core manager instances
static func get_core_managers() -> Dictionary:
	return {
		"parameter_manager": ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER),
		"color_palette_manager": ServiceLocator.get_service(ServiceLocator.COLOR_PALETTE_MANAGER),
		"shader_manager": ServiceLocator.get_service(ServiceLocator.SHADER_MANAGER),
		"audio_manager": ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER),
		"screenshot_manager": ServiceLocator.get_service(ServiceLocator.SCREENSHOT_MANAGER),
		"timeline_manager": ServiceLocator.get_service(ServiceLocator.TIMELINE_MANAGER),
		"input_manager": ServiceLocator.get_service(ServiceLocator.INPUT_MANAGER),
		"menu_manager": ServiceLocator.get_service(ServiceLocator.MENU_MANAGER)
	}

## Reinitialize the application (useful for testing or recovery)
## @return: True if reinitialization was successful
static func reinitialize() -> bool:
	if _is_initialized:
		shutdown()
	
	return initialize()

## Check if a specific service is available and ready
## @param service_name: The name of the service to check
## @return: True if the service is available and functional
static func is_service_ready(service_name: String) -> bool:
	var service = ServiceLocator.get_service(service_name)
	if not service:
		return false
	
	# Check if service has a ready state method
	if service.has_method("is_ready"):
		return service.is_ready()
	
	# If no ready method, assume it's ready if it exists
	return true

## Wait for a service to become ready (async)
## @param service_name: The name of the service to wait for
## @param timeout: Maximum time to wait in seconds
## @return: True if service became ready within timeout
static func wait_for_service(service_name: String, timeout: float = 5.0) -> bool:
	var start_time = Time.get_time_dict_from_system().hour * 3600 + \
					 Time.get_time_dict_from_system().minute * 60 + \
					 Time.get_time_dict_from_system().second
	
	while not is_service_ready(service_name):
		var current_time = Time.get_time_dict_from_system().hour * 3600 + \
						   Time.get_time_dict_from_system().minute * 60 + \
						   Time.get_time_dict_from_system().second
		
		if current_time - start_time > timeout:
			push_warning("ApplicationBootstrap: Timeout waiting for service '%s'" % service_name)
			return false
		
		await Engine.get_main_loop().process_frame
	
	return true

#endregion

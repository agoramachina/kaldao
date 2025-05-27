class_name ApplicationBootstrap
extends RefCounted

# Bootstrap class to initialize the application in the correct order
static var _is_initialized: bool = false

static func initialize() -> bool:
	if _is_initialized:
		print("ApplicationBootstrap: Already initialized")
		return true
	
	print("ApplicationBootstrap: Starting application initialization...")
	
	# Step 1: Load configuration
	if not ConfigManager.load_config():
		print("ApplicationBootstrap: ERROR - Failed to load configuration")
		return false
	
	# Step 2: Initialize core services
	_initialize_core_services()
	
	# Step 3: Setup event connections
	_setup_event_connections()
	
	_is_initialized = true
	print("ApplicationBootstrap: Application initialization complete")
	return true

static func _initialize_core_services():
	"""Initialize and register all core services"""
	print("ApplicationBootstrap: Initializing core services...")
	
	# Create and register parameter manager
	var parameter_manager = ParameterManager.new()
	ServiceLocator.register_service(ServiceLocator.PARAMETER_MANAGER, parameter_manager)
	
	# Create and register color palette manager
	var color_palette_manager = ColorPaletteManager.new()
	ServiceLocator.register_service(ServiceLocator.COLOR_PALETTE_MANAGER, color_palette_manager)
	
	# Create and register screenshot manager
	var screenshot_manager = ScreenshotManager.new()
	ServiceLocator.register_service(ServiceLocator.SCREENSHOT_MANAGER, screenshot_manager)
	
	# Create and register song settings
	var song_settings = SongSettings.new()
	ServiceLocator.register_service(ServiceLocator.SONG_SETTINGS, song_settings)
	
	print("ApplicationBootstrap: Core services initialized")

static func _setup_event_connections():
	"""Setup initial event connections between services"""
	print("ApplicationBootstrap: Setting up event connections...")
	
	var parameter_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
	var color_palette_manager = ServiceLocator.get_service(ServiceLocator.COLOR_PALETTE_MANAGER)
	var screenshot_manager = ServiceLocator.get_service(ServiceLocator.SCREENSHOT_MANAGER)
	
	# Connect parameter changes to event bus
	if parameter_manager and parameter_manager.has_signal("parameter_changed"):
		parameter_manager.parameter_changed.connect(EventBus.emit_parameter_changed)
	
	# Connect palette changes to event bus
	if color_palette_manager and color_palette_manager.has_signal("palette_changed"):
		color_palette_manager.palette_changed.connect(EventBus.emit_palette_changed)
	
	# Connect screenshot events
	if screenshot_manager:
		if screenshot_manager.has_signal("screenshot_taken"):
			screenshot_manager.screenshot_taken.connect(EventBus.emit_screenshot_completed)
		if screenshot_manager.has_signal("screenshot_failed"):
			screenshot_manager.screenshot_failed.connect(func(error): EventBus.emit_text_update_requested("Screenshot failed: " + error))
	
	print("ApplicationBootstrap: Event connections established")

static func register_audio_manager(audio_manager: AudioManager):
	"""Register the audio manager after it's created in the scene"""
	if not audio_manager:
		print("ApplicationBootstrap: ERROR - Null audio manager provided")
		return
	
	ServiceLocator.register_service(ServiceLocator.AUDIO_MANAGER, audio_manager)
	
	# Connect audio manager to parameter manager
	var parameter_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
	if parameter_manager:
		audio_manager.connect_to_parameter_manager(parameter_manager)
	
	# Connect audio signals to event bus
	if audio_manager.has_signal("bass_detected"):
		audio_manager.bass_detected.connect(func(intensity): pass)  # Can add specific bass handling
	if audio_manager.has_signal("mid_detected"):
		audio_manager.mid_detected.connect(func(intensity): pass)   # Can add specific mid handling
	if audio_manager.has_signal("treble_detected"):
		audio_manager.treble_detected.connect(func(intensity): pass) # Can add specific treble handling
	if audio_manager.has_signal("beat_detected"):
		audio_manager.beat_detected.connect(func(): EventBus.emit_beat_detected(1.0))
	
	print("ApplicationBootstrap: Audio manager registered and connected")

static func register_shader_controller(shader_controller: ShaderController):
	"""Register the shader controller after it's created"""
	if not shader_controller:
		print("ApplicationBootstrap: ERROR - Null shader controller provided")
		return
	
	ServiceLocator.register_service(ServiceLocator.SHADER_CONTROLLER, shader_controller)
	
	# Connect to parameter changes
	EventBus.connect_to_parameter_changed(shader_controller.update_parameter)
	EventBus.connect_to_palette_changed(shader_controller.update_color_palette)
	
	print("ApplicationBootstrap: Shader controller registered and connected")

static func setup_song_settings_connections():
	"""Setup connections for song settings after all managers are ready"""
	var song_settings = ServiceLocator.get_service(ServiceLocator.SONG_SETTINGS)
	var parameter_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
	var color_palette_manager = ServiceLocator.get_service(ServiceLocator.COLOR_PALETTE_MANAGER)
	var audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
	
	if song_settings and parameter_manager and color_palette_manager and audio_manager:
		song_settings.connect_managers(parameter_manager, color_palette_manager, audio_manager)
		
		# Connect checkpoint signals
		if song_settings.has_signal("checkpoint_reached"):
			song_settings.checkpoint_reached.connect(EventBus.emit_checkpoint_reached)
		
		print("ApplicationBootstrap: Song settings connections established")
	else:
		print("ApplicationBootstrap: WARNING - Not all managers available for song settings connections")

static func shutdown():
	"""Clean shutdown of the application"""
	print("ApplicationBootstrap: Shutting down application...")
	
	# Save configuration
	ConfigManager.save_config()
	
	# Clear all services
	ServiceLocator.clear_all_services()
	
	_is_initialized = false
	print("ApplicationBootstrap: Application shutdown complete")

static func is_initialized() -> bool:
	return _is_initialized

# Utility method to get commonly used service combinations
static func get_core_managers() -> Dictionary:
	"""Get all core managers in a single call"""
	return {
		"parameter_manager": ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER),
		"color_palette_manager": ServiceLocator.get_service(ServiceLocator.COLOR_PALETTE_MANAGER),
		"shader_controller": ServiceLocator.get_service(ServiceLocator.SHADER_CONTROLLER),
		"audio_manager": ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER),
		"screenshot_manager": ServiceLocator.get_service(ServiceLocator.SCREENSHOT_MANAGER),
		"song_settings": ServiceLocator.get_service(ServiceLocator.SONG_SETTINGS)
	}

# Debug method to check initialization status
static func get_initialization_status() -> Dictionary:
	"""Get detailed initialization status for debugging"""
	var services = {}
	var service_names = [
		ServiceLocator.PARAMETER_MANAGER,
		ServiceLocator.COLOR_PALETTE_MANAGER,
		ServiceLocator.SHADER_CONTROLLER,
		ServiceLocator.AUDIO_MANAGER,
		ServiceLocator.SCREENSHOT_MANAGER,
		ServiceLocator.SONG_SETTINGS
	]
	
	for service_name in service_names:
		var service = ServiceLocator.get_service(service_name)
		services[service_name] = {
			"registered": service != null,
			"type": service.get_class() if service else "null"
		}
	
	return {
		"is_initialized": _is_initialized,
		"config_loaded": ConfigManager._is_loaded,
		"services": services
	}

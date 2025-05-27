class_name KaldaoMain
extends Control

## KaldaoMain - Main Application Scene
##
## This is the main application scene that integrates all refactored components
## using the new architecture. It serves as the entry point and coordinator
## for the entire Kaldao application.
##
## Usage:
##   This scene should be set as the main scene in project settings.
##   All initialization and coordination happens automatically.

# Scene references
var _visual_canvas: ColorRect
var _ui_layer: CanvasLayer
var _audio_stream_player: AudioStreamPlayer

# Component references
var _timeline_component: TimelineComponent
var _parameter_display_component: ParameterDisplayComponent
var _audio_visualizer_component: AudioVisualizerComponent

# Manager references (accessed through ServiceLocator)
var _audio_manager: AudioManager
var _parameter_manager: ParameterManager
var _shader_manager: ShaderManager
var _color_palette_manager: ColorPaletteManager
var _input_manager: InputManager
var _menu_manager: MenuManager

# Application state
var _is_initialized: bool = false
var _is_shutting_down: bool = false

# Configuration settings
var _app_settings: Dictionary = {}

#region Initialization

## Called when the node enters the scene tree
func _ready() -> void:
	print("KaldaoMain: Starting application initialization...")
	
	# Initialize the application
	await _initialize_application()
	
	print("KaldaoMain: Application initialization complete")

## Initialize the entire application
func _initialize_application() -> void:
	# Load application configuration
	_load_application_configuration()
	
	# Initialize core systems first
	await _initialize_core_systems()
	
	# Create and setup the scene structure
	_create_scene_structure()
	
	# Initialize managers
	await _initialize_managers()
	
	# Initialize components
	await _initialize_components()
	
	# Setup connections between systems
	_setup_system_connections()
	
	# Setup input handling
	_setup_input_handling()
	
	# Perform final setup
	_finalize_initialization()
	
	_is_initialized = true

## Load application configuration
func _load_application_configuration() -> void:
	print("KaldaoMain: Loading application configuration...")
	
	_app_settings = {
		"window_title": ConfigManager.get_config_value("app.window.title", "Kaldao"),
		"target_fps": ConfigManager.get_config_value("app.performance.target_fps", 60),
		"vsync_enabled": ConfigManager.get_config_value("app.performance.vsync_enabled", true),
		"fullscreen_mode": ConfigManager.get_config_value("app.window.fullscreen_mode", false),
		"auto_save_interval": ConfigManager.get_config_value("app.auto_save_interval", 300.0)
	}
	
	# Apply window settings
	_apply_window_settings()
	
	print("KaldaoMain: Application configuration loaded")

## Apply window and performance settings
func _apply_window_settings() -> void:
	# Set window title
	get_window().title = _app_settings.window_title
	
	# Set target FPS
	Engine.max_fps = _app_settings.target_fps
	
	# Set VSync
	if _app_settings.vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	# Set fullscreen mode
	if _app_settings.fullscreen_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

## Initialize core systems
func _initialize_core_systems() -> void:
	print("KaldaoMain: Initializing core systems...")
	
	# Initialize ApplicationBootstrap (this handles ServiceLocator, EventBus, ConfigManager)
	var bootstrap = ApplicationBootstrap.new()
	var success = await bootstrap.initialize(self)
	
	if not success:
		push_error("KaldaoMain: Failed to initialize core systems")
		return
	
	print("KaldaoMain: Core systems initialized successfully")

## Create the scene structure
func _create_scene_structure() -> void:
	print("KaldaoMain: Creating scene structure...")
	
	# Set up main control properties
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name = "KaldaoMain"
	
	# Create visual canvas (for shader rendering)
	_visual_canvas = ColorRect.new()
	_visual_canvas.name = "VisualCanvas"
	_visual_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual_canvas.color = Color.BLACK
	add_child(_visual_canvas)
	
	# Create UI layer
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	_ui_layer.layer = 10  # Above the visual canvas
	add_child(_ui_layer)
	
	# Create audio stream player
	_audio_stream_player = AudioStreamPlayer.new()
	_audio_stream_player.name = "AudioStreamPlayer"
	add_child(_audio_stream_player)
	
	print("KaldaoMain: Scene structure created")

## Initialize managers
func _initialize_managers() -> void:
	print("KaldaoMain: Initializing managers...")
	
	# Get manager references from ServiceLocator
	_audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
	_parameter_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
	_shader_manager = ServiceLocator.get_service(ServiceLocator.SHADER_MANAGER)
	_color_palette_manager = ServiceLocator.get_service(ServiceLocator.COLOR_PALETTE_MANAGER)
	_input_manager = ServiceLocator.get_service(ServiceLocator.INPUT_MANAGER)
	_menu_manager = ServiceLocator.get_service(ServiceLocator.MENU_MANAGER)
	
	# Verify all managers are available
	var missing_managers = []
	if not _audio_manager: missing_managers.append("AudioManager")
	if not _parameter_manager: missing_managers.append("ParameterManager")
	if not _shader_manager: missing_managers.append("ShaderManager")
	if not _color_palette_manager: missing_managers.append("ColorPaletteManager")
	if not _input_manager: missing_managers.append("InputManager")
	if not _menu_manager: missing_managers.append("MenuManager")
	
	if missing_managers.size() > 0:
		push_warning("KaldaoMain: Missing managers: " + str(missing_managers))
	
	print("KaldaoMain: Managers initialized")

## Initialize components
func _initialize_components() -> void:
	print("KaldaoMain: Initializing components...")
	
	# Create and initialize timeline component
	_timeline_component = TimelineComponent.new()
	_timeline_component.name = "TimelineComponent"
	_ui_layer.add_child(_timeline_component)
	_timeline_component.initialize()
	
	# Create and initialize parameter display component
	_parameter_display_component = ParameterDisplayComponent.new()
	_parameter_display_component.name = "ParameterDisplayComponent"
	_ui_layer.add_child(_parameter_display_component)
	_parameter_display_component.initialize()
	
	# Create and initialize audio visualizer component
	_audio_visualizer_component = AudioVisualizerComponent.new()
	_audio_visualizer_component.name = "AudioVisualizerComponent"
	_ui_layer.add_child(_audio_visualizer_component)
	_audio_visualizer_component.initialize()
	
	print("KaldaoMain: Components initialized")

## Setup connections between systems
func _setup_system_connections() -> void:
	print("KaldaoMain: Setting up system connections...")
	
	# Connect audio manager to audio stream player
	if _audio_manager:
		_audio_manager.set_audio_stream_player(_audio_stream_player)
	
	# Connect shader manager to visual canvas
	if _shader_manager:
		_shader_manager.set_target_material(_visual_canvas)
	
	# Setup menu manager with UI elements
	if _menu_manager:
		var ui_elements = {
			"main_label": _create_main_label(),
			"settings_label": _create_settings_label(),
			"commands_label": _create_commands_label()
		}
		_menu_manager.initialize(ui_elements)
	
	print("KaldaoMain: System connections established")

## Create main label for menu system
func _create_main_label() -> RichTextLabel:
	var label = RichTextLabel.new()
	label.name = "MainLabel"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.size = Vector2(400, 100)
	label.fit_content = true
	label.scroll_active = false
	label.text = "[center]Kaldao Audio Visualizer[/center]"
	_ui_layer.add_child(label)
	return label

## Create settings label for menu system
func _create_settings_label() -> RichTextLabel:
	var label = RichTextLabel.new()
	label.name = "SettingsLabel"
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.size = Vector2(300, 400)
	label.fit_content = true
	label.scroll_active = false
	label.visible = false
	_ui_layer.add_child(label)
	return label

## Create commands label for menu system
func _create_commands_label() -> RichTextLabel:
	var label = RichTextLabel.new()
	label.name = "CommandsLabel"
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.size = Vector2(300, 400)
	label.fit_content = true
	label.scroll_active = false
	label.visible = false
	_ui_layer.add_child(label)
	return label

## Setup input handling
func _setup_input_handling() -> void:
	print("KaldaoMain: Setting up input handling...")
	
	# Connect to input events
	if _input_manager:
		# Input manager will handle all input through EventBus
		pass
	
	# Make sure this scene can receive input
	set_process_input(true)
	
	print("KaldaoMain: Input handling configured")

## Finalize initialization
func _finalize_initialization() -> void:
	print("KaldaoMain: Finalizing initialization...")
	
	# Load default audio file if specified
	_load_default_audio()
	
	# Apply initial shader and palette
	_apply_initial_visual_settings()
	
	# Show startup menu if configured
	_show_startup_menu()
	
	# Start auto-save timer if enabled
	_start_auto_save_timer()
	
	# Emit application ready event
	EventBus.emit_application_ready()
	
	print("KaldaoMain: Initialization finalized")

## Load default audio file
func _load_default_audio() -> void:
	var default_audio_path = ConfigManager.get_config_value("app.default_audio_file", "")
	if default_audio_path != "" and FileAccess.file_exists(default_audio_path):
		if _audio_manager:
			_audio_manager.load_audio_file(default_audio_path)
			print("KaldaoMain: Loaded default audio file: " + default_audio_path)

## Apply initial visual settings
func _apply_initial_visual_settings() -> void:
	# Set initial shader
	if _shader_manager:
		var default_shader = ConfigManager.get_config_value("visual.default_shader", "kaldao")
		_shader_manager.set_current_shader(default_shader)
	
	# Set initial palette
	if _color_palette_manager:
		_color_palette_manager.emit_current_palette()

## Show startup menu
func _show_startup_menu() -> void:
	var show_startup_menu = ConfigManager.get_config_value("ui.show_startup_menu", true)
	var startup_duration = ConfigManager.get_startup_menu_duration()
	
	if show_startup_menu and _menu_manager:
		_menu_manager.set_first_launch(true)
		# Menu will auto-hide after startup_duration
		var timer = Timer.new()
		timer.wait_time = startup_duration
		timer.one_shot = true
		timer.timeout.connect(_on_startup_menu_timeout.bind(timer))
		add_child(timer)
		timer.start()

## Start auto-save timer
func _start_auto_save_timer() -> void:
	var auto_save_interval = _app_settings.auto_save_interval
	if auto_save_interval > 0:
		var timer = Timer.new()
		timer.wait_time = auto_save_interval
		timer.timeout.connect(_on_auto_save_timeout)
		add_child(timer)
		timer.start()
		print("KaldaoMain: Auto-save enabled with %.1fs interval" % auto_save_interval)

#endregion

#region Input Handling

## Handle input events
func _input(event: InputEvent) -> void:
	if not _is_initialized or _is_shutting_down:
		return
	
	# Pass input to input manager
	if _input_manager:
		var handled = _input_manager.handle_input(event)
		if handled:
			get_viewport().set_input_as_handled()

#endregion

#region Event Handlers

## Handle startup menu timeout
func _on_startup_menu_timeout(timer: Timer) -> void:
	if _menu_manager:
		_menu_manager.hide_menu()
	timer.queue_free()

## Handle auto-save timeout
func _on_auto_save_timeout() -> void:
	_perform_auto_save()

## Perform auto-save
func _perform_auto_save() -> void:
	print("KaldaoMain: Performing auto-save...")
	
	# Save current parameter state
	if _parameter_manager:
		var save_data = _parameter_manager.save_parameter_data()
		# Save to user config
		ConfigManager.save_user_config(save_data)
	
	print("KaldaoMain: Auto-save complete")

#endregion

#region Application Lifecycle

## Handle application shutdown
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown_application()

## Shutdown the application gracefully
func _shutdown_application() -> void:
	if _is_shutting_down:
		return
	
	_is_shutting_down = true
	print("KaldaoMain: Shutting down application...")
	
	# Emit shutdown event
	EventBus.emit_application_shutting_down()
	
	# Save current state
	_perform_auto_save()
	
	# Cleanup components
	_cleanup_components()
	
	# Cleanup managers (handled by ServiceLocator)
	ServiceLocator.cleanup()
	
	print("KaldaoMain: Application shutdown complete")
	
	# Quit the application
	get_tree().quit()

## Cleanup components
func _cleanup_components() -> void:
	if _timeline_component:
		_timeline_component.cleanup()
	if _parameter_display_component:
		_parameter_display_component.cleanup()
	if _audio_visualizer_component:
		_audio_visualizer_component.cleanup()

#endregion

#region Public API

## Get the visual canvas for shader rendering
## @return: The visual canvas ColorRect
func get_visual_canvas() -> ColorRect:
	return _visual_canvas

## Get the UI layer for adding UI elements
## @return: The UI CanvasLayer
func get_ui_layer() -> CanvasLayer:
	return _ui_layer

## Get the audio stream player
## @return: The AudioStreamPlayer
func get_audio_stream_player() -> AudioStreamPlayer:
	return _audio_stream_player

## Check if the application is fully initialized
## @return: True if initialized
func is_initialized() -> bool:
	return _is_initialized

## Check if the application is shutting down
## @return: True if shutting down
func is_shutting_down() -> bool:
	return _is_shutting_down

## Get application information for debugging
## @return: Dictionary with application information
func get_application_info() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"shutting_down": _is_shutting_down,
		"components_count": _ui_layer.get_child_count() if _ui_layer else 0,
		"app_settings": _app_settings.duplicate(),
		"scene_tree_ready": is_inside_tree()
	}

#endregion

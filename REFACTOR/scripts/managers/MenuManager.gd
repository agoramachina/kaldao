class_name MenuManager
extends RefCounted

## MenuManager - Refactored Menu System
##
## This refactored MenuManager uses the new architecture with ConfigManager for settings,
## EventBus for communication, and supports configurable layouts and smooth animations.
## It maintains backward compatibility while providing a much cleaner and more extensible interface.
##
## Usage:
##   var menu_manager = MenuManager.new()
##   menu_manager.initialize(ui_elements)
##   menu_manager.toggle_menu()

# Menu state definitions
enum MenuState {
	HIDDEN,
	SHOWING,
	VISIBLE,
	HIDING
}

# Menu section definitions
enum MenuSection {
	SETTINGS,
	COMMANDS,
	MAIN,
	STATUS
}

# UI element references
var _ui_elements: Dictionary = {}
var _background_elements: Dictionary = {}

# Menu state and configuration
var _current_state: MenuState = MenuState.HIDDEN
var _menu_visible: bool = false
var _first_launch: bool = true
var _menu_settings: Dictionary = {}

# Animation and timing
var _fade_tween: Tween
var _animation_settings: Dictionary = {}

# Content management
var _menu_content: Dictionary = {}
var _dynamic_content: Dictionary = {}

# Initialization state
var _is_initialized: bool = false

#region Initialization

## Initialize the menu manager with UI elements
## @param ui_elements: Dictionary containing UI element references
## @return: True if initialization was successful
func initialize(ui_elements: Dictionary) -> bool:
	if _is_initialized:
		print("MenuManager: Already initialized")
		return true
	
	print("MenuManager: Initializing...")
	
	# Store UI element references
	_ui_elements = ui_elements.duplicate()
	
	# Load configuration
	_load_menu_configuration()
	
	# Setup menu content
	_setup_menu_content()
	
	# Setup event connections
	_setup_event_connections()
	
	# Initialize animation system
	_initialize_animation_system()
	
	# Setup initial state
	_setup_initial_state()
	
	_is_initialized = true
	print("MenuManager: Initialization complete")
	return true

## Load menu configuration from ConfigManager
func _load_menu_configuration() -> void:
	print("MenuManager: Loading menu configuration...")
	
	# Load menu settings
	_menu_settings = {
		"fade_duration": ConfigManager.get_config_value("ui.menu.fade_duration", 1.0),
		"background_opacity": ConfigManager.get_config_value("ui.menu.background_opacity", 0.8),
		"text_size": ConfigManager.get_config_value("ui.menu.text_size", 12),
		"auto_hide_delay": ConfigManager.get_config_value("ui.menu.auto_hide_delay", 8.0),
		"startup_menu_duration": ConfigManager.get_startup_menu_duration(),
		"responsive_layout": ConfigManager.get_config_value("ui.menu.responsive_layout", true)
	}
	
	# Load animation settings
	_animation_settings = {
		"fade_in_curve": ConfigManager.get_config_value("ui.menu.animations.fade_in_curve", "ease_out"),
		"fade_out_curve": ConfigManager.get_config_value("ui.menu.animations.fade_out_curve", "ease_in"),
		"stagger_delay": ConfigManager.get_config_value("ui.menu.animations.stagger_delay", 0.1),
		"enable_animations": ConfigManager.get_config_value("ui.menu.animations.enabled", true)
	}
	
	print("MenuManager: Configuration loaded")

## Setup menu content templates
func _setup_menu_content() -> void:
	print("MenuManager: Setting up menu content...")
	
	# Commands content with improved formatting
	_menu_content[MenuSection.COMMANDS] = """=== COMMANDS ===

NAVIGATION:
↑/↓\t\t\tAdjust parameter
←/→\t\tSwitch parameter
r\t\t\tReset current
R\t\t\tReset all (confirm)

RANDOMIZATION:
C\t\t\tRandomize colors
.\t\t\tRandomize parameters
Shift+C\t\tReset to B&W

AUDIO:
Shift+A\t\tToggle audio playback
A\t\t\tToggle audio reactive

CAPTURE:
Space\t\tPause animation
P\t\t\tTake screenshot

FILES:
Ctrl+S\t\tSave settings
Ctrl+L\t\tLoad settings

MENU:
F1\t\t\tToggle this menu
ESC\t\t\tHide this menu"""
	
	# Status content template
	_menu_content[MenuSection.STATUS] = """=== STATUS ===

Audio: {audio_status}
Reactive: {reactive_status}
Palette: {palette_name}
Parameter: {current_parameter}
FPS: {fps}"""
	
	print("MenuManager: Menu content configured")

## Setup event connections with EventBus
func _setup_event_connections() -> void:
	print("MenuManager: Setting up event connections...")
	
	# Connect to menu control events
	EventBus.connect_to_menu_toggle_requested(_on_menu_toggle_requested)
	EventBus.connect_to_menu_show_requested(_on_menu_show_requested)
	EventBus.connect_to_menu_hide_requested(_on_menu_hide_requested)
	
	# Connect to content update events
	EventBus.connect_to_parameter_changed(_on_parameter_changed)
	EventBus.connect_to_audio_status_changed(_on_audio_status_changed)
	EventBus.connect_to_palette_changed(_on_palette_changed)
	
	# Connect to application lifecycle
	EventBus.connect_to_application_shutting_down(_on_application_shutdown)
	
	print("MenuManager: Event connections established")

## Initialize animation system
func _initialize_animation_system() -> void:
	if _animation_settings.enable_animations:
		print("MenuManager: Animation system enabled")
	else:
		print("MenuManager: Animation system disabled")

## Setup initial menu state
func _setup_initial_state() -> void:
	# Hide all menu elements initially
	_hide_all_elements_instant()
	
	# Show main label if available
	if "main_label" in _ui_elements:
		_ui_elements.main_label.visible = true
	if "main_background" in _ui_elements:
		_ui_elements.main_background.visible = true
	
	print("MenuManager: Initial state configured")

#endregion

#region Menu Control

## Toggle menu visibility
## @param settings_text: Optional settings text to display
## @return: True if menu is now visible
func toggle_menu(settings_text: String = "") -> bool:
	_first_launch = false  # No longer first launch after manual toggle
	
	if _menu_visible:
		hide_menu()
		return false
	else:
		show_menu(settings_text)
		return true

## Show the menu with optional settings text
## @param settings_text: Settings text to display
func show_menu(settings_text: String = "") -> void:
	if _current_state == MenuState.VISIBLE or _current_state == MenuState.SHOWING:
		return
	
	_current_state = MenuState.SHOWING
	_menu_visible = true
	
	# Update content
	_update_menu_content(settings_text)
	
	# Show menu elements
	if _animation_settings.enable_animations:
		_animate_show()
	else:
		_show_instant()
	
	# Emit visibility change event
	EventBus.emit_menu_visibility_changed(true)
	
	print("MenuManager: Menu shown")

## Hide the menu
func hide_menu() -> void:
	if _current_state == MenuState.HIDDEN or _current_state == MenuState.HIDING:
		return
	
	_current_state = MenuState.HIDING
	_menu_visible = false
	
	# Hide menu elements
	if _animation_settings.enable_animations:
		_animate_hide()
	else:
		_hide_instant()
	
	# Emit visibility change event
	EventBus.emit_menu_visibility_changed(false)
	
	print("MenuManager: Menu hidden")

## Show menu instantly without animation
func _show_instant() -> void:
	# Show settings and commands sections
	_show_element("settings_label")
	_show_element("settings_background")
	_show_element("commands_label")
	_show_element("commands_background")
	
	# Hide main section
	_hide_element("main_label")
	_hide_element("main_background")
	
	_current_state = MenuState.VISIBLE

## Hide menu instantly without animation
func _hide_instant() -> void:
	# Hide settings and commands sections
	_hide_element("settings_label")
	_hide_element("settings_background")
	_hide_element("commands_label")
	_hide_element("commands_background")
	
	# Show main section
	_show_element("main_label")
	_show_element("main_background")
	
	_current_state = MenuState.HIDDEN

## Hide all menu elements instantly
func _hide_all_elements_instant() -> void:
	for element_name in _ui_elements:
		_hide_element(element_name)

#endregion

#region Animation System

## Animate menu show with smooth transitions
func _animate_show() -> void:
	if not _fade_tween:
		_create_fade_tween()
	
	# Stop any existing animation
	_fade_tween.kill()
	
	# Show elements instantly but with 0 alpha
	var elements_to_show = ["settings_label", "settings_background", "commands_label", "commands_background"]
	for element_name in elements_to_show:
		if element_name in _ui_elements:
			var element = _ui_elements[element_name]
			element.visible = true
			element.modulate.a = 0.0
	
	# Hide main elements
	_hide_element("main_label")
	_hide_element("main_background")
	
	# Animate fade in with stagger
	var delay = 0.0
	for element_name in elements_to_show:
		if element_name in _ui_elements:
			var element = _ui_elements[element_name]
			_fade_tween.tween_method(
				_set_element_alpha.bind(element),
				0.0,
				1.0,
				_menu_settings.fade_duration
			).set_delay(delay)
			delay += _animation_settings.stagger_delay
	
	# Set state when animation completes
	_fade_tween.tween_callback(_on_show_animation_complete).set_delay(_menu_settings.fade_duration + delay)

## Animate menu hide with smooth transitions
func _animate_hide() -> void:
	if not _fade_tween:
		_create_fade_tween()
	
	# Stop any existing animation
	_fade_tween.kill()
	
	# Get elements to fade out
	var elements_to_hide = _get_visible_menu_elements()
	
	# Animate fade out
	var delay = 0.0
	for element_name in elements_to_hide:
		if element_name in _ui_elements:
			var element = _ui_elements[element_name]
			_fade_tween.tween_method(
				_set_element_alpha.bind(element),
				element.modulate.a,
				0.0,
				_menu_settings.fade_duration
			).set_delay(delay)
			delay += _animation_settings.stagger_delay
	
	# Set state when animation completes
	_fade_tween.tween_callback(_on_hide_animation_complete).set_delay(_menu_settings.fade_duration + delay)

## Create fade tween for animations
func _create_fade_tween() -> void:
	_fade_tween = Tween.new()
	# Note: In a real implementation, this would need to be added to a scene tree

## Set element alpha for animation
## @param element: UI element to modify
## @param alpha: Alpha value to set
func _set_element_alpha(element: Control, alpha: float) -> void:
	if element:
		element.modulate.a = alpha

## Get list of currently visible menu elements
## @return: Array of visible element names
func _get_visible_menu_elements() -> Array[String]:
	var visible_elements: Array[String] = []
	var menu_elements = ["settings_label", "settings_background", "commands_label", "commands_background"]
	
	for element_name in menu_elements:
		if element_name in _ui_elements and _ui_elements[element_name].visible:
			visible_elements.append(element_name)
	
	return visible_elements

## Handle show animation completion
func _on_show_animation_complete() -> void:
	_current_state = MenuState.VISIBLE
	print("MenuManager: Show animation complete")

## Handle hide animation completion
func _on_hide_animation_complete() -> void:
	_hide_instant()
	_current_state = MenuState.HIDDEN
	print("MenuManager: Hide animation complete")

#endregion

#region Content Management

## Update menu content with current information
## @param settings_text: Settings text to display
func _update_menu_content(settings_text: String = "") -> void:
	# Update settings content
	if "settings_label" in _ui_elements and settings_text != "":
		_ui_elements.settings_label.text = settings_text
	
	# Update commands content
	if "commands_label" in _ui_elements:
		_ui_elements.commands_label.text = _menu_content[MenuSection.COMMANDS]
	
	# Update status content if available
	_update_status_content()

## Update status content with dynamic information
func _update_status_content() -> void:
	if not "status_label" in _ui_elements:
		return
	
	var status_template = _menu_content.get(MenuSection.STATUS, "")
	if status_template == "":
		return
	
	# Get dynamic content
	var audio_status = _dynamic_content.get("audio_status", "Unknown")
	var reactive_status = _dynamic_content.get("reactive_status", "Unknown")
	var palette_name = _dynamic_content.get("palette_name", "Unknown")
	var current_parameter = _dynamic_content.get("current_parameter", "Unknown")
	var fps = Engine.get_frames_per_second()
	
	# Format status text
	var status_text = status_template.format({
		"audio_status": audio_status,
		"reactive_status": reactive_status,
		"palette_name": palette_name,
		"current_parameter": current_parameter,
		"fps": fps
	})
	
	_ui_elements.status_label.text = status_text

## Set dynamic content value
## @param key: Content key
## @param value: Content value
func set_dynamic_content(key: String, value: String) -> void:
	_dynamic_content[key] = value
	
	# Update status content if menu is visible
	if _menu_visible:
		_update_status_content()

#endregion

#region Element Management

## Show a UI element
## @param element_name: Name of the element to show
func _show_element(element_name: String) -> void:
	if element_name in _ui_elements:
		var element = _ui_elements[element_name]
		element.visible = true
		element.modulate.a = 1.0

## Hide a UI element
## @param element_name: Name of the element to hide
func _hide_element(element_name: String) -> void:
	if element_name in _ui_elements:
		var element = _ui_elements[element_name]
		element.visible = false
		element.modulate.a = 1.0

## Set background elements for menu sections
## @param backgrounds: Dictionary of background elements
func set_background_elements(backgrounds: Dictionary) -> void:
	_background_elements = backgrounds.duplicate()
	
	# Merge with main UI elements
	for bg_name in backgrounds:
		_ui_elements[bg_name] = backgrounds[bg_name]
	
	print("MenuManager: Background elements configured")

#endregion

#region Event Handlers

## Handle menu toggle requests from EventBus
func _on_menu_toggle_requested() -> void:
	toggle_menu()

## Handle menu show requests from EventBus
## @param settings_text: Settings text to display
func _on_menu_show_requested(settings_text: String = "") -> void:
	show_menu(settings_text)

## Handle menu hide requests from EventBus
func _on_menu_hide_requested() -> void:
	hide_menu()

## Handle parameter changes for dynamic content
## @param param_name: Name of changed parameter
## @param value: New parameter value
func _on_parameter_changed(param_name: String, value: float) -> void:
	set_dynamic_content("current_parameter", "%s: %.2f" % [param_name, value])

## Handle audio status changes
## @param is_playing: Whether audio is playing
func _on_audio_status_changed(is_playing: bool) -> void:
	set_dynamic_content("audio_status", "Playing" if is_playing else "Stopped")

## Handle palette changes
## @param palette_data: Palette information
func _on_palette_changed(palette_data: Dictionary) -> void:
	var palette_name = palette_data.get("name", "Unknown")
	set_dynamic_content("palette_name", palette_name)

## Handle application shutdown
func _on_application_shutdown() -> void:
	cleanup()

#endregion

#region Public API

## Check if menu is currently visible
## @return: True if menu is visible
func is_menu_visible() -> bool:
	return _menu_visible

## Check if this is the first launch
## @return: True if first launch
func is_first_launch() -> bool:
	return _first_launch

## Set first launch state
## @param value: First launch state
func set_first_launch(value: bool) -> void:
	_first_launch = value
	print("MenuManager: First launch set to %s" % value)

## Get current menu state
## @return: Current MenuState
func get_menu_state() -> MenuState:
	return _current_state

## Update menu settings
## @param settings: Dictionary of settings to update
func update_menu_settings(settings: Dictionary) -> void:
	for key in settings:
		if key in _menu_settings:
			_menu_settings[key] = settings[key]
	
	print("MenuManager: Settings updated")

## Get menu information for debugging
## @return: Dictionary with menu information
func get_menu_info() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"visible": _menu_visible,
		"state": _current_state,
		"first_launch": _first_launch,
		"ui_elements_count": _ui_elements.size(),
		"menu_settings": _menu_settings.duplicate(),
		"dynamic_content": _dynamic_content.duplicate()
	}

## Check if the manager is properly initialized
## @return: True if initialized and ready
func is_ready() -> bool:
	return _is_initialized

## Start fade out animation and return elements to fade
## @return: Dictionary of elements that need to be faded out
func start_fade_out() -> Dictionary:
	var fade_elements = {}
	
	var menu_elements = ["settings_label", "settings_background", "commands_label", "commands_background"]
	for element_name in menu_elements:
		if element_name in _ui_elements and _ui_elements[element_name].visible:
			fade_elements[element_name] = _ui_elements[element_name]
	
	return fade_elements

## Complete fade out animation
func complete_fade_out() -> void:
	_hide_instant()

#endregion

#region Cleanup

## Clean up resources and connections
func cleanup() -> void:
	print("MenuManager: Cleaning up resources...")
	
	# Stop any running animations
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	
	# Clear references
	_ui_elements.clear()
	_background_elements.clear()
	_menu_content.clear()
	_dynamic_content.clear()
	_menu_settings.clear()
	_animation_settings.clear()
	
	# Reset state
	_current_state = MenuState.HIDDEN
	_menu_visible = false
	_first_launch = true
	_is_initialized = false
	
	print("MenuManager: Cleanup complete")

#endregion

class_name ParameterDisplayComponent
extends Control

## ParameterDisplayComponent - Reusable Parameter Value Display
##
## This component provides a configurable display for parameter values with fade animations,
## multiple display modes, and validation feedback. It integrates with the new architecture
## using ConfigManager for settings and EventBus for communication.
##
## Usage:
##   var display = ParameterDisplayComponent.new()
##   display.initialize()
##   display.show_parameter("zoom_level", 1.25)

# Display mode definitions
enum DisplayMode {
	OVERLAY,        # Overlay on top of content
	SIDEBAR,        # Fixed sidebar display
	BOTTOM_BAR,     # Bottom status bar
	FLOATING,       # Floating window
	MINIMAL         # Minimal text-only display
}

# Animation state definitions
enum AnimationState {
	HIDDEN,
	FADING_IN,
	VISIBLE,
	FADING_OUT
}

# Signals for display events
signal parameter_display_shown(param_name: String, value: float)
signal parameter_display_hidden(param_name: String)
signal parameter_validation_failed(param_name: String, error: String)

# Display state and properties
var _current_parameter: String = ""
var _current_value: float = 0.0
var _display_mode: DisplayMode = DisplayMode.OVERLAY
var _animation_state: AnimationState = AnimationState.HIDDEN

# Configuration settings (loaded from ConfigManager)
var _display_settings: Dictionary = {}
var _animation_settings: Dictionary = {}
var _validation_settings: Dictionary = {}

# Visual elements and styling
var _background_panel: Panel
var _parameter_label: RichTextLabel
var _value_label: RichTextLabel
var _validation_label: RichTextLabel
var _progress_bar: ProgressBar

# Animation and timing
var _fade_tween: Tween
var _display_timer: Timer
var _validation_timer: Timer

# Visual styling
var _colors: Dictionary = {}
var _fonts: Dictionary = {}
var _sizes: Dictionary = {}

# Parameter data cache
var _parameter_data_cache: Dictionary = {}
var _parameter_manager: ParameterManager

# Initialization state
var _is_initialized: bool = false

#region Initialization

## Initialize the parameter display component
## @return: True if initialization was successful
func initialize() -> bool:
	if _is_initialized:
		print("ParameterDisplayComponent: Already initialized")
		return true
	
	print("ParameterDisplayComponent: Initializing...")
	
	# Load configuration
	_load_display_configuration()
	
	# Setup visual styling
	_setup_visual_styling()
	
	# Create UI elements
	_create_ui_elements()
	
	# Setup control properties
	_setup_control_properties()
	
	# Connect to managers
	_connect_to_managers()
	
	# Setup event connections
	_setup_event_connections()
	
	# Initialize animation system
	_initialize_animation_system()
	
	_is_initialized = true
	print("ParameterDisplayComponent: Initialization complete")
	return true

## Load display configuration from ConfigManager
func _load_display_configuration() -> void:
	print("ParameterDisplayComponent: Loading configuration...")
	
	# Load display settings
	_display_settings = {
		"show_duration": ConfigManager.get_config_value("ui.parameter_display.show_duration", 3.0),
		"fade_duration": ConfigManager.get_config_value("ui.parameter_display.fade_duration", 1.0),
		"position": ConfigManager.get_config_value("ui.parameter_display.position", "center"),
		"auto_hide": ConfigManager.get_config_value("ui.parameter_display.auto_hide", true),
		"show_progress_bar": ConfigManager.get_config_value("ui.parameter_display.show_progress_bar", true),
		"show_validation": ConfigManager.get_config_value("ui.parameter_display.show_validation", true)
	}
	
	# Load animation settings
	_animation_settings = {
		"fade_curve": ConfigManager.get_config_value("ui.parameter_display.animations.fade_curve", "ease_out"),
		"slide_distance": ConfigManager.get_config_value("ui.parameter_display.animations.slide_distance", 20),
		"bounce_effect": ConfigManager.get_config_value("ui.parameter_display.animations.bounce_effect", false),
		"scale_effect": ConfigManager.get_config_value("ui.parameter_display.animations.scale_effect", true)
	}
	
	# Load validation settings
	_validation_settings = {
		"show_constraints": ConfigManager.get_config_value("ui.parameter_display.validation.show_constraints", true),
		"highlight_invalid": ConfigManager.get_config_value("ui.parameter_display.validation.highlight_invalid", true),
		"validation_timeout": ConfigManager.get_config_value("ui.parameter_display.validation.timeout", 2.0)
	}
	
	print("ParameterDisplayComponent: Configuration loaded")

## Setup visual styling from configuration
func _setup_visual_styling() -> void:
	print("ParameterDisplayComponent: Setting up visual styling...")
	
	# Load colors from configuration
	_colors = {
		"background": Color(
			ConfigManager.get_config_value("ui.parameter_display.colors.background", [0.0, 0.0, 0.0, 0.8])
		),
		"border": Color(
			ConfigManager.get_config_value("ui.parameter_display.colors.border", [0.5, 0.5, 0.5, 1.0])
		),
		"parameter_text": Color(
			ConfigManager.get_config_value("ui.parameter_display.colors.parameter_text", [0.9, 0.9, 0.9, 1.0])
		),
		"value_text": Color(
			ConfigManager.get_config_value("ui.parameter_display.colors.value_text", [1.0, 1.0, 1.0, 1.0])
		),
		"validation_error": Color(
			ConfigManager.get_config_value("ui.parameter_display.colors.validation_error", [1.0, 0.3, 0.3, 1.0])
		),
		"validation_success": Color(
			ConfigManager.get_config_value("ui.parameter_display.colors.validation_success", [0.3, 1.0, 0.3, 1.0])
		),
		"progress_bar": Color(
			ConfigManager.get_config_value("ui.parameter_display.colors.progress_bar", [0.502, 0.0, 0.502, 1.0])
		)
	}
	
	# Load font settings
	_fonts = {
		"parameter": ThemeDB.fallback_font,
		"value": ThemeDB.fallback_font,
		"validation": ThemeDB.fallback_font
	}
	
	# Load size settings
	_sizes = {
		"parameter_font": ConfigManager.get_config_value("ui.parameter_display.fonts.parameter_size", 14),
		"value_font": ConfigManager.get_config_value("ui.parameter_display.fonts.value_size", 18),
		"validation_font": ConfigManager.get_config_value("ui.parameter_display.fonts.validation_size", 12),
		"panel_width": ConfigManager.get_config_value("ui.parameter_display.panel.width", 300),
		"panel_height": ConfigManager.get_config_value("ui.parameter_display.panel.height", 120),
		"border_width": ConfigManager.get_config_value("ui.parameter_display.panel.border_width", 2)
	}
	
	print("ParameterDisplayComponent: Visual styling configured")

## Create UI elements
func _create_ui_elements() -> void:
	print("ParameterDisplayComponent: Creating UI elements...")
	
	# Create background panel
	_background_panel = Panel.new()
	_background_panel.name = "BackgroundPanel"
	add_child(_background_panel)
	
	# Create parameter label
	_parameter_label = RichTextLabel.new()
	_parameter_label.name = "ParameterLabel"
	_parameter_label.fit_content = true
	_parameter_label.scroll_active = false
	_background_panel.add_child(_parameter_label)
	
	# Create value label
	_value_label = RichTextLabel.new()
	_value_label.name = "ValueLabel"
	_value_label.fit_content = true
	_value_label.scroll_active = false
	_background_panel.add_child(_value_label)
	
	# Create validation label
	_validation_label = RichTextLabel.new()
	_validation_label.name = "ValidationLabel"
	_validation_label.fit_content = true
	_validation_label.scroll_active = false
	_validation_label.visible = false
	_background_panel.add_child(_validation_label)
	
	# Create progress bar (if enabled)
	if _display_settings.show_progress_bar:
		_progress_bar = ProgressBar.new()
		_progress_bar.name = "ProgressBar"
		_progress_bar.show_percentage = false
		_background_panel.add_child(_progress_bar)
	
	print("ParameterDisplayComponent: UI elements created")

## Setup control properties and layout
func _setup_control_properties() -> void:
	# Set size and position based on configuration
	size = Vector2(_sizes.panel_width, _sizes.panel_height)
	
	# Set position based on configuration
	_set_display_position()
	
	# Set interaction properties
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	
	# Set visibility and layering
	visible = false
	modulate = Color.WHITE
	z_index = 200  # Above timeline and other UI
	
	# Layout UI elements
	_layout_ui_elements()
	
	print("ParameterDisplayComponent: Control properties configured")

## Set display position based on configuration
func _set_display_position() -> void:
	var position_setting = _display_settings.position
	
	match position_setting:
		"center":
			set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		"top_left":
			set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		"top_right":
			set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		"bottom_left":
			set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		"bottom_right":
			set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		"top_center":
			set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			size.y = _sizes.panel_height
		"bottom_center":
			set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			size.y = _sizes.panel_height

## Layout UI elements within the panel
func _layout_ui_elements() -> void:
	var margin = 10
	var current_y = margin
	
	# Layout parameter label
	_parameter_label.position = Vector2(margin, current_y)
	_parameter_label.size = Vector2(size.x - margin * 2, 20)
	current_y += 25
	
	# Layout value label
	_value_label.position = Vector2(margin, current_y)
	_value_label.size = Vector2(size.x - margin * 2, 30)
	current_y += 35
	
	# Layout progress bar (if enabled)
	if _progress_bar:
		_progress_bar.position = Vector2(margin, current_y)
		_progress_bar.size = Vector2(size.x - margin * 2, 20)
		current_y += 25
	
	# Layout validation label
	_validation_label.position = Vector2(margin, current_y)
	_validation_label.size = Vector2(size.x - margin * 2, 15)
	
	# Set background panel to fill the component
	_background_panel.position = Vector2.ZERO
	_background_panel.size = size

## Connect to managers through ServiceLocator
func _connect_to_managers() -> void:
	print("ParameterDisplayComponent: Connecting to managers...")
	
	# Get parameter manager
	_parameter_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
	if _parameter_manager:
		print("ParameterDisplayComponent: Connected to ParameterManager")
	else:
		push_warning("ParameterDisplayComponent: ParameterManager not available")
	
	print("ParameterDisplayComponent: Manager connections established")

## Setup event connections with EventBus
func _setup_event_connections() -> void:
	print("ParameterDisplayComponent: Setting up event connections...")
	
	# Connect to parameter events
	EventBus.connect_to_parameter_changed(_on_parameter_changed)
	EventBus.connect_to_parameter_validation_failed(_on_parameter_validation_failed)
	EventBus.connect_to_parameter_reset(_on_parameter_reset)
	
	# Connect to display control events
	EventBus.connect_to_parameter_display_requested(_on_parameter_display_requested)
	EventBus.connect_to_parameter_display_hide_requested(_on_parameter_display_hide_requested)
	
	# Connect to application lifecycle
	EventBus.connect_to_application_shutting_down(_on_application_shutdown)
	
	print("ParameterDisplayComponent: Event connections established")

## Initialize animation system
func _initialize_animation_system() -> void:
	# Create fade tween
	_fade_tween = Tween.new()
	add_child(_fade_tween)
	
	# Create display timer
	_display_timer = Timer.new()
	_display_timer.one_shot = true
	_display_timer.timeout.connect(_on_display_timeout)
	add_child(_display_timer)
	
	# Create validation timer
	_validation_timer = Timer.new()
	_validation_timer.one_shot = true
	_validation_timer.timeout.connect(_on_validation_timeout)
	add_child(_validation_timer)
	
	print("ParameterDisplayComponent: Animation system initialized")

#endregion

#region Display Control

## Show parameter with value
## @param param_name: Name of the parameter
## @param value: Current parameter value
## @param force_show: Whether to force show even if already visible
func show_parameter(param_name: String, value: float, force_show: bool = false) -> void:
	if not _is_initialized:
		return
	
	# Update current parameter info
	_current_parameter = param_name
	_current_value = value
	
	# Get parameter data
	var param_data = _get_parameter_data(param_name)
	
	# Update display content
	_update_display_content(param_data, value)
	
	# Show the display
	if _animation_state == AnimationState.HIDDEN or force_show:
		_show_display()
	elif _animation_state == AnimationState.VISIBLE:
		# Already visible, just restart the timer
		_restart_display_timer()
	
	# Emit signal
	parameter_display_shown.emit(param_name, value)

## Hide parameter display
## @param animate: Whether to animate the hide
func hide_parameter(animate: bool = true) -> void:
	if _animation_state == AnimationState.HIDDEN:
		return
	
	if animate:
		_hide_display_animated()
	else:
		_hide_display_instant()
	
	# Emit signal
	parameter_display_hidden.emit(_current_parameter)

## Show validation error
## @param param_name: Name of the parameter
## @param error_message: Error message to display
func show_validation_error(param_name: String, error_message: String) -> void:
	if not _validation_settings.show_validation:
		return
	
	# Update validation label
	_validation_label.text = "[color=%s]%s[/color]" % [_colors.validation_error.to_html(), error_message]
	_validation_label.visible = true
	
	# Highlight the display if it's the current parameter
	if param_name == _current_parameter and _validation_settings.highlight_invalid:
		_highlight_validation_error()
	
	# Start validation timer
	_validation_timer.wait_time = _validation_settings.validation_timeout
	_validation_timer.start()
	
	# Emit signal
	parameter_validation_failed.emit(param_name, error_message)

## Show validation success
## @param param_name: Name of the parameter
func show_validation_success(param_name: String) -> void:
	if not _validation_settings.show_validation:
		return
	
	# Update validation label
	_validation_label.text = "[color=%s]✓ Valid[/color]" % _colors.validation_success.to_html()
	_validation_label.visible = true
	
	# Clear any error highlighting
	_clear_validation_highlighting()
	
	# Start validation timer (shorter for success)
	_validation_timer.wait_time = _validation_settings.validation_timeout * 0.5
	_validation_timer.start()

#endregion

#region Display Animation

## Show display with animation
func _show_display() -> void:
	if _animation_state == AnimationState.FADING_IN or _animation_state == AnimationState.VISIBLE:
		return
	
	_animation_state = AnimationState.FADING_IN
	visible = true
	
	# Stop any existing animation
	_fade_tween.kill()
	
	# Set initial state
	modulate.a = 0.0
	if _animation_settings.scale_effect:
		scale = Vector2(0.8, 0.8)
	
	# Animate fade in
	_fade_tween.tween_method(_set_display_alpha, 0.0, 1.0, _display_settings.fade_duration)
	
	# Animate scale if enabled
	if _animation_settings.scale_effect:
		_fade_tween.parallel().tween_property(self, "scale", Vector2.ONE, _display_settings.fade_duration)
	
	# Set state when animation completes
	_fade_tween.tween_callback(_on_show_animation_complete)

## Hide display with animation
func _hide_display_animated() -> void:
	if _animation_state == AnimationState.FADING_OUT or _animation_state == AnimationState.HIDDEN:
		return
	
	_animation_state = AnimationState.FADING_OUT
	
	# Stop any existing animation
	_fade_tween.kill()
	
	# Animate fade out
	_fade_tween.tween_method(_set_display_alpha, modulate.a, 0.0, _display_settings.fade_duration)
	
	# Animate scale if enabled
	if _animation_settings.scale_effect:
		_fade_tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), _display_settings.fade_duration)
	
	# Set state when animation completes
	_fade_tween.tween_callback(_on_hide_animation_complete)

## Hide display instantly
func _hide_display_instant() -> void:
	_animation_state = AnimationState.HIDDEN
	visible = false
	modulate.a = 1.0
	scale = Vector2.ONE
	
	# Stop timers
	_display_timer.stop()
	_validation_timer.stop()

## Set display alpha for animation
## @param alpha: Alpha value to set
func _set_display_alpha(alpha: float) -> void:
	modulate.a = alpha

## Handle show animation completion
func _on_show_animation_complete() -> void:
	_animation_state = AnimationState.VISIBLE
	_restart_display_timer()

## Handle hide animation completion
func _on_hide_animation_complete() -> void:
	_animation_state = AnimationState.HIDDEN
	visible = false
	modulate.a = 1.0
	scale = Vector2.ONE

## Restart display timer
func _restart_display_timer() -> void:
	if _display_settings.auto_hide:
		_display_timer.wait_time = _display_settings.show_duration
		_display_timer.start()

#endregion

#region Content Management

## Update display content
## @param param_data: Parameter data dictionary
## @param value: Current parameter value
func _update_display_content(param_data: Dictionary, value: float) -> void:
	# Update parameter name
	var param_display_name = param_data.get("display_name", _current_parameter)
	var param_description = param_data.get("description", "")
	
	_parameter_label.text = "[font_size=%d][color=%s]%s[/color][/font_size]" % [
		_sizes.parameter_font,
		_colors.parameter_text.to_html(),
		param_display_name
	]
	
	# Update value display
	var formatted_value = _format_parameter_value(param_data, value)
	_value_label.text = "[font_size=%d][color=%s]%s[/color][/font_size]" % [
		_sizes.value_font,
		_colors.value_text.to_html(),
		formatted_value
	]
	
	# Update progress bar if enabled
	if _progress_bar and param_data.has("min_value") and param_data.has("max_value"):
		var min_val = param_data.min_value
		var max_val = param_data.max_value
		var progress = (value - min_val) / (max_val - min_val) if max_val > min_val else 0.0
		
		_progress_bar.min_value = 0.0
		_progress_bar.max_value = 1.0
		_progress_bar.value = clamp(progress, 0.0, 1.0)
		_progress_bar.visible = true
	elif _progress_bar:
		_progress_bar.visible = false
	
	# Clear validation display
	_validation_label.visible = false
	_clear_validation_highlighting()

## Format parameter value for display
## @param param_data: Parameter data dictionary
## @param value: Parameter value
## @return: Formatted value string
func _format_parameter_value(param_data: Dictionary, value: float) -> String:
	var format_type = param_data.get("format", "float")
	var precision = param_data.get("precision", 2)
	
	match format_type:
		"integer":
			return str(int(value))
		"percentage":
			return "%.1f%%" % (value * 100.0)
		"time":
			return _format_time_value(value)
		"angle":
			return "%.1f°" % value
		_:
			return "%.*f" % [precision, value]

## Format time value
## @param seconds: Time in seconds
## @return: Formatted time string
func _format_time_value(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

## Get parameter data from cache or parameter manager
## @param param_name: Name of the parameter
## @return: Parameter data dictionary
func _get_parameter_data(param_name: String) -> Dictionary:
	# Check cache first
	if param_name in _parameter_data_cache:
		return _parameter_data_cache[param_name]
	
	# Get from parameter manager
	var param_data = {}
	if _parameter_manager:
		param_data = _parameter_manager.get_parameter_info(param_name)
	
	# Cache the data
	_parameter_data_cache[param_name] = param_data
	
	return param_data

#endregion

#region Validation Highlighting

## Highlight validation error
func _highlight_validation_error() -> void:
	# Add red border or background tint
	if _background_panel:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = _colors.background
		style_box.border_color = _colors.validation_error
		style_box.border_width_left = _sizes.border_width
		style_box.border_width_right = _sizes.border_width
		style_box.border_width_top = _sizes.border_width
		style_box.border_width_bottom = _sizes.border_width
		_background_panel.add_theme_stylebox_override("panel", style_box)

## Clear validation highlighting
func _clear_validation_highlighting() -> void:
	# Reset to normal styling
	if _background_panel:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = _colors.background
		style_box.border_color = _colors.border
		style_box.border_width_left = _sizes.border_width
		style_box.border_width_right = _sizes.border_width
		style_box.border_width_top = _sizes.border_width
		style_box.border_width_bottom = _sizes.border_width
		_background_panel.add_theme_stylebox_override("panel", style_box)

#endregion

#region Event Handlers

## Handle parameter changes
## @param param_name: Name of changed parameter
## @param value: New parameter value
func _on_parameter_changed(param_name: String, value: float) -> void:
	# Show the parameter if it's different from current or if display is hidden
	if param_name != _current_parameter or _animation_state == AnimationState.HIDDEN:
		show_parameter(param_name, value)
	elif param_name == _current_parameter:
		# Update current parameter value
		_current_value = value
		var param_data = _get_parameter_data(param_name)
		_update_display_content(param_data, value)
		_restart_display_timer()

## Handle parameter validation failures
## @param param_name: Name of parameter that failed validation
## @param error_message: Error message
func _on_parameter_validation_failed(param_name: String, error_message: String) -> void:
	show_validation_error(param_name, error_message)

## Handle parameter reset
## @param param_name: Name of reset parameter
## @param value: Reset value
func _on_parameter_reset(param_name: String, value: float) -> void:
	show_parameter(param_name, value, true)
	show_validation_success(param_name)

## Handle parameter display requests
## @param param_name: Name of parameter to display
## @param value: Parameter value
func _on_parameter_display_requested(param_name: String, value: float) -> void:
	show_parameter(param_name, value, true)

## Handle parameter display hide requests
func _on_parameter_display_hide_requested() -> void:
	hide_parameter()

## Handle display timeout
func _on_display_timeout() -> void:
	hide_parameter()

## Handle validation timeout
func _on_validation_timeout() -> void:
	_validation_label.visible = false
	_clear_validation_highlighting()

## Handle application shutdown
func _on_application_shutdown() -> void:
	cleanup()

#endregion

#region Public API

## Set display mode
## @param mode: New display mode
func set_display_mode(mode: DisplayMode) -> void:
	_display_mode = mode
	_set_display_position()
	print("ParameterDisplayComponent: Display mode set to %d" % mode)

## Get current parameter being displayed
## @return: Current parameter name
func get_current_parameter() -> String:
	return _current_parameter

## Get current parameter value
## @return: Current parameter value
func get_current_value() -> float:
	return _current_value

## Check if display is currently visible
## @return: True if display is visible
func is_display_visible() -> bool:
	return _animation_state == AnimationState.VISIBLE or _animation_state == AnimationState.FADING_IN

## Get display information for debugging
## @return: Dictionary with display information
func get_display_info() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"current_parameter": _current_parameter,
		"current_value": _current_value,
		"display_mode": _display_mode,
		"animation_state": _animation_state,
		"visible": is_display_visible(),
		"display_settings": _display_settings.duplicate()
	}

## Check if the component is properly initialized
## @return: True if initialized and ready
func is_ready() -> bool:
	return _is_initialized

#endregion

#region Cleanup

## Clean up resources and connections
func cleanup() -> void:
	print("ParameterDisplayComponent: Cleaning up resources...")
	
	# Stop animations and timers
	if _fade_tween:
		_fade_tween.kill()
	if _display_timer:
		_display_timer.stop()
	if _validation_timer:
		_validation_timer.stop()
	
	# Clear references
	_parameter_manager = null
	
	# Clear data
	_parameter_data_cache.clear()
	_display_settings.clear()
	_animation_settings.clear()
	_validation_settings.clear()
	_colors.clear()
	_fonts.clear()
	_sizes.clear()
	
	# Reset state
	_current_parameter = ""
	_current_value = 0.0
	_display_mode = DisplayMode.OVERLAY
	_animation_state = AnimationState.HIDDEN
	_is_initialized = false
	
	print("ParameterDisplayComponent: Cleanup complete")

#endregion

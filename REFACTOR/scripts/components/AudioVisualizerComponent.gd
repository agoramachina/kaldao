class_name AudioVisualizerComponent
extends Control

## AudioVisualizerComponent - Real-time Audio Level Visualization
##
## This component provides real-time audio visualization with frequency spectrum display,
## beat detection indicators, and configurable visualization styles. It integrates with
## the new architecture using ConfigManager for settings and EventBus for communication.
##
## Usage:
##   var visualizer = AudioVisualizerComponent.new()
##   visualizer.initialize()
##   # Component will automatically connect to audio systems

# Visualization mode definitions
enum VisualizationMode {
	SPECTRUM,       # Frequency spectrum bars
	WAVEFORM,       # Audio waveform
	CIRCULAR,       # Circular spectrum
	BARS,           # Traditional bar graph
	PARTICLES,      # Particle-based visualization
	MINIMAL         # Minimal level indicators
}

# Display style definitions
enum DisplayStyle {
	CLASSIC,        # Traditional visualization
	MODERN,         # Modern flat design
	NEON,           # Neon glow effects
	RETRO,          # Retro/vintage style
	MINIMAL         # Clean minimal style
}

# Signals for visualization events
signal visualization_mode_changed(mode: VisualizationMode)
signal beat_detected(intensity: float)
signal frequency_peak_detected(frequency: float, magnitude: float)

# Visualization state and properties
var _current_mode: VisualizationMode = VisualizationMode.SPECTRUM
var _current_style: DisplayStyle = DisplayStyle.MODERN
var _is_active: bool = true

# Audio data and analysis
var _spectrum_data: PackedFloat32Array = []
var _waveform_data: PackedFloat32Array = []
var _frequency_bands: Array[float] = []
var _beat_intensity: float = 0.0
var _audio_level: float = 0.0

# Configuration settings (loaded from ConfigManager)
var _visualizer_settings: Dictionary = {}
var _spectrum_settings: Dictionary = {}
var _beat_settings: Dictionary = {}
var _performance_settings: Dictionary = {}

# Visual elements and styling
var _colors: Dictionary = {}
var _gradients: Array[Gradient] = []
var _bar_positions: Array[Vector2] = []
var _particle_systems: Array[Dictionary] = []

# Animation and effects
var _beat_flash_timer: float = 0.0
var _spectrum_smoothing: Array[float] = []
var _peak_hold_values: Array[float] = []
var _peak_hold_timers: Array[float] = []

# Manager references (accessed through ServiceLocator)
var _audio_manager: AudioManager
var _audio_analyzer: AudioAnalyzer
var _beat_detector: BeatDetector

# Performance tracking
var _frame_count: int = 0
var _update_frequency: float = 60.0
var _last_update_time: float = 0.0

# Initialization state
var _is_initialized: bool = false

#region Initialization

## Initialize the audio visualizer component
## @return: True if initialization was successful
func initialize() -> bool:
	if _is_initialized:
		print("AudioVisualizerComponent: Already initialized")
		return true
	
	print("AudioVisualizerComponent: Initializing...")
	
	# Load configuration
	_load_visualizer_configuration()
	
	# Setup visual styling
	_setup_visual_styling()
	
	# Setup control properties
	_setup_control_properties()
	
	# Connect to managers
	_connect_to_managers()
	
	# Setup event connections
	_setup_event_connections()
	
	# Initialize visualization data
	_initialize_visualization_data()
	
	# Setup performance tracking
	_setup_performance_tracking()
	
	_is_initialized = true
	print("AudioVisualizerComponent: Initialization complete")
	return true

## Load visualizer configuration from ConfigManager
func _load_visualizer_configuration() -> void:
	print("AudioVisualizerComponent: Loading configuration...")
	
	# Load visualizer settings
	_visualizer_settings = {
		"mode": ConfigManager.get_config_value("ui.audio_visualizer.mode", "spectrum"),
		"style": ConfigManager.get_config_value("ui.audio_visualizer.style", "modern"),
		"update_rate": ConfigManager.get_config_value("ui.audio_visualizer.update_rate", 60.0),
		"smoothing_factor": ConfigManager.get_config_value("ui.audio_visualizer.smoothing_factor", 0.8),
		"sensitivity": ConfigManager.get_config_value("ui.audio_visualizer.sensitivity", 1.0),
		"show_beat_flash": ConfigManager.get_config_value("ui.audio_visualizer.show_beat_flash", true),
		"show_peak_hold": ConfigManager.get_config_value("ui.audio_visualizer.show_peak_hold", true)
	}
	
	# Load spectrum settings
	_spectrum_settings = {
		"bar_count": ConfigManager.get_config_value("ui.audio_visualizer.spectrum.bar_count", 64),
		"frequency_range": ConfigManager.get_config_value("ui.audio_visualizer.spectrum.frequency_range", [20.0, 20000.0]),
		"logarithmic_scale": ConfigManager.get_config_value("ui.audio_visualizer.spectrum.logarithmic_scale", true),
		"bar_width": ConfigManager.get_config_value("ui.audio_visualizer.spectrum.bar_width", 8),
		"bar_spacing": ConfigManager.get_config_value("ui.audio_visualizer.spectrum.bar_spacing", 2),
		"min_height": ConfigManager.get_config_value("ui.audio_visualizer.spectrum.min_height", 2),
		"max_height": ConfigManager.get_config_value("ui.audio_visualizer.spectrum.max_height", 200)
	}
	
	# Load beat settings
	_beat_settings = {
		"flash_duration": ConfigManager.get_config_value("ui.audio_visualizer.beat.flash_duration", 0.2),
		"flash_intensity": ConfigManager.get_config_value("ui.audio_visualizer.beat.flash_intensity", 0.8),
		"pulse_effect": ConfigManager.get_config_value("ui.audio_visualizer.beat.pulse_effect", true),
		"color_change": ConfigManager.get_config_value("ui.audio_visualizer.beat.color_change", true)
	}
	
	# Load performance settings
	_performance_settings = {
		"max_fps": ConfigManager.get_config_value("ui.audio_visualizer.performance.max_fps", 60.0),
		"adaptive_quality": ConfigManager.get_config_value("ui.audio_visualizer.performance.adaptive_quality", true),
		"low_power_mode": ConfigManager.get_config_value("ui.audio_visualizer.performance.low_power_mode", false)
	}
	
	print("AudioVisualizerComponent: Configuration loaded")

## Setup visual styling from configuration
func _setup_visual_styling() -> void:
	print("AudioVisualizerComponent: Setting up visual styling...")
	
	# Load colors from configuration
	_colors = {
		"background": Color(
			ConfigManager.get_config_value("ui.audio_visualizer.colors.background", [0.0, 0.0, 0.0, 0.3])
		),
		"spectrum_low": Color(
			ConfigManager.get_config_value("ui.audio_visualizer.colors.spectrum_low", [0.0, 1.0, 0.0, 1.0])
		),
		"spectrum_mid": Color(
			ConfigManager.get_config_value("ui.audio_visualizer.colors.spectrum_mid", [1.0, 1.0, 0.0, 1.0])
		),
		"spectrum_high": Color(
			ConfigManager.get_config_value("ui.audio_visualizer.colors.spectrum_high", [1.0, 0.0, 0.0, 1.0])
		),
		"beat_flash": Color(
			ConfigManager.get_config_value("ui.audio_visualizer.colors.beat_flash", [1.0, 1.0, 1.0, 0.8])
		),
		"peak_hold": Color(
			ConfigManager.get_config_value("ui.audio_visualizer.colors.peak_hold", [1.0, 1.0, 1.0, 0.9])
		),
		"border": Color(
			ConfigManager.get_config_value("ui.audio_visualizer.colors.border", [0.5, 0.5, 0.5, 0.5])
		)
	}
	
	# Setup gradients for spectrum visualization
	_setup_gradients()
	
	print("AudioVisualizerComponent: Visual styling configured")

## Setup gradients for visualization
func _setup_gradients() -> void:
	# Create spectrum gradient
	var spectrum_gradient = Gradient.new()
	spectrum_gradient.add_point(0.0, _colors.spectrum_low)
	spectrum_gradient.add_point(0.5, _colors.spectrum_mid)
	spectrum_gradient.add_point(1.0, _colors.spectrum_high)
	_gradients.append(spectrum_gradient)
	
	# Create beat flash gradient
	var beat_gradient = Gradient.new()
	beat_gradient.add_point(0.0, Color.TRANSPARENT)
	beat_gradient.add_point(0.5, _colors.beat_flash)
	beat_gradient.add_point(1.0, Color.TRANSPARENT)
	_gradients.append(beat_gradient)

## Setup control properties and layout
func _setup_control_properties() -> void:
	# Set size and anchoring
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	size = Vector2(
		ConfigManager.get_config_value("ui.audio_visualizer.width", 300),
		ConfigManager.get_config_value("ui.audio_visualizer.height", 150)
	)
	
	# Set interaction properties
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	
	# Set visibility and layering
	visible = true
	modulate = Color.WHITE
	z_index = 150  # Above most UI but below menus
	
	print("AudioVisualizerComponent: Control properties configured")

## Connect to managers through ServiceLocator
func _connect_to_managers() -> void:
	print("AudioVisualizerComponent: Connecting to managers...")
	
	# Get audio manager
	_audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
	if _audio_manager:
		print("AudioVisualizerComponent: Connected to AudioManager")
	else:
		push_warning("AudioVisualizerComponent: AudioManager not available")
	
	# Get audio analyzer
	_audio_analyzer = ServiceLocator.get_service(ServiceLocator.AUDIO_ANALYZER)
	if _audio_analyzer:
		print("AudioVisualizerComponent: Connected to AudioAnalyzer")
	else:
		push_warning("AudioVisualizerComponent: AudioAnalyzer not available")
	
	# Get beat detector
	_beat_detector = ServiceLocator.get_service(ServiceLocator.BEAT_DETECTOR)
	if _beat_detector:
		print("AudioVisualizerComponent: Connected to BeatDetector")
	else:
		push_warning("AudioVisualizerComponent: BeatDetector not available")
	
	print("AudioVisualizerComponent: Manager connections established")

## Setup event connections with EventBus
func _setup_event_connections() -> void:
	print("AudioVisualizerComponent: Setting up event connections...")
	
	# Connect to audio events
	EventBus.connect_to_audio_spectrum_updated(_on_audio_spectrum_updated)
	EventBus.connect_to_audio_level_changed(_on_audio_level_changed)
	EventBus.connect_to_beat_detected(_on_beat_detected)
	
	# Connect to visualization control events
	EventBus.connect_to_visualizer_mode_changed(_on_visualizer_mode_changed)
	EventBus.connect_to_visualizer_toggle_requested(_on_visualizer_toggle_requested)
	
	# Connect to application lifecycle
	EventBus.connect_to_application_shutting_down(_on_application_shutdown)
	
	print("AudioVisualizerComponent: Event connections established")

## Initialize visualization data structures
func _initialize_visualization_data() -> void:
	var bar_count = _spectrum_settings.bar_count
	
	# Initialize spectrum data arrays
	_spectrum_data.resize(bar_count)
	_frequency_bands.resize(bar_count)
	_spectrum_smoothing.resize(bar_count)
	_peak_hold_values.resize(bar_count)
	_peak_hold_timers.resize(bar_count)
	
	# Initialize bar positions
	_calculate_bar_positions()
	
	# Set visualization mode from configuration
	_set_visualization_mode_from_config()
	
	print("AudioVisualizerComponent: Visualization data initialized")

## Calculate bar positions for spectrum visualization
func _calculate_bar_positions() -> void:
	_bar_positions.clear()
	
	var bar_count = _spectrum_settings.bar_count
	var bar_width = _spectrum_settings.bar_width
	var bar_spacing = _spectrum_settings.bar_spacing
	var total_width = size.x
	var available_width = total_width - (bar_count - 1) * bar_spacing
	var actual_bar_width = min(bar_width, available_width / bar_count)
	
	var start_x = (total_width - (bar_count * actual_bar_width + (bar_count - 1) * bar_spacing)) / 2
	
	for i in range(bar_count):
		var x = start_x + i * (actual_bar_width + bar_spacing)
		_bar_positions.append(Vector2(x, size.y))

## Set visualization mode from configuration
func _set_visualization_mode_from_config() -> void:
	var mode_string = _visualizer_settings.mode
	match mode_string.to_lower():
		"spectrum":
			_current_mode = VisualizationMode.SPECTRUM
		"waveform":
			_current_mode = VisualizationMode.WAVEFORM
		"circular":
			_current_mode = VisualizationMode.CIRCULAR
		"bars":
			_current_mode = VisualizationMode.BARS
		"particles":
			_current_mode = VisualizationMode.PARTICLES
		"minimal":
			_current_mode = VisualizationMode.MINIMAL
		_:
			_current_mode = VisualizationMode.SPECTRUM

## Setup performance tracking
func _setup_performance_tracking() -> void:
	_update_frequency = _performance_settings.max_fps
	_last_update_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second

#endregion

#region Visualization Rendering

## Custom drawing for the visualizer
func _draw() -> void:
	if not _is_initialized or not _is_active:
		return
	
	# Draw background
	_draw_background()
	
	# Draw visualization based on current mode
	match _current_mode:
		VisualizationMode.SPECTRUM:
			_draw_spectrum_visualization()
		VisualizationMode.WAVEFORM:
			_draw_waveform_visualization()
		VisualizationMode.CIRCULAR:
			_draw_circular_visualization()
		VisualizationMode.BARS:
			_draw_bars_visualization()
		VisualizationMode.PARTICLES:
			_draw_particles_visualization()
		VisualizationMode.MINIMAL:
			_draw_minimal_visualization()
	
	# Draw beat flash effect
	if _visualizer_settings.show_beat_flash and _beat_flash_timer > 0:
		_draw_beat_flash()
	
	# Draw border
	_draw_border()

## Draw background
func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _colors.background)

## Draw spectrum visualization
func _draw_spectrum_visualization() -> void:
	if _spectrum_data.size() == 0:
		return
	
	var bar_count = min(_spectrum_data.size(), _bar_positions.size())
	var bar_width = _spectrum_settings.bar_width
	var max_height = _spectrum_settings.max_height
	var min_height = _spectrum_settings.min_height
	
	for i in range(bar_count):
		var magnitude = _spectrum_data[i] * _visualizer_settings.sensitivity
		var smoothed_magnitude = _spectrum_smoothing[i]
		
		# Apply smoothing
		smoothed_magnitude = lerp(smoothed_magnitude, magnitude, 1.0 - _visualizer_settings.smoothing_factor)
		_spectrum_smoothing[i] = smoothed_magnitude
		
		# Calculate bar height
		var bar_height = max(min_height, smoothed_magnitude * max_height)
		var bar_pos = _bar_positions[i]
		
		# Get color from gradient based on frequency
		var frequency_ratio = float(i) / float(bar_count - 1)
		var bar_color = _gradients[0].sample(frequency_ratio)
		
		# Draw main bar
		var bar_rect = Rect2(
			bar_pos.x,
			bar_pos.y - bar_height,
			bar_width,
			bar_height
		)
		draw_rect(bar_rect, bar_color)
		
		# Draw peak hold if enabled
		if _visualizer_settings.show_peak_hold:
			_draw_peak_hold(i, bar_pos, bar_width, smoothed_magnitude, max_height)

## Draw peak hold indicators
## @param index: Bar index
## @param bar_pos: Bar position
## @param bar_width: Bar width
## @param current_magnitude: Current magnitude
## @param max_height: Maximum bar height
func _draw_peak_hold(index: int, bar_pos: Vector2, bar_width: float, current_magnitude: float, max_height: float) -> void:
	var peak_hold_time = 2.0  # Hold peaks for 2 seconds
	var current_height = current_magnitude * max_height
	
	# Update peak hold value
	if current_height > _peak_hold_values[index]:
		_peak_hold_values[index] = current_height
		_peak_hold_timers[index] = peak_hold_time
	else:
		_peak_hold_timers[index] -= get_process_delta_time()
		if _peak_hold_timers[index] <= 0:
			_peak_hold_values[index] = max(_peak_hold_values[index] - 50 * get_process_delta_time(), 0)
	
	# Draw peak hold line
	if _peak_hold_values[index] > 0:
		var peak_y = bar_pos.y - _peak_hold_values[index]
		draw_line(
			Vector2(bar_pos.x, peak_y),
			Vector2(bar_pos.x + bar_width, peak_y),
			_colors.peak_hold,
			2.0
		)

## Draw waveform visualization
func _draw_waveform_visualization() -> void:
	if _waveform_data.size() < 2:
		return
	
	var points = PackedVector2Array()
	var center_y = size.y / 2
	var amplitude_scale = size.y * 0.4
	
	for i in range(_waveform_data.size()):
		var x = (float(i) / float(_waveform_data.size() - 1)) * size.x
		var y = center_y + _waveform_data[i] * amplitude_scale
		points.append(Vector2(x, y))
	
	# Draw waveform line
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], _colors.spectrum_mid, 2.0)

## Draw circular visualization
func _draw_circular_visualization() -> void:
	if _spectrum_data.size() == 0:
		return
	
	var center = size / 2
	var radius = min(size.x, size.y) * 0.3
	var bar_count = _spectrum_data.size()
	
	for i in range(bar_count):
		var angle = (float(i) / float(bar_count)) * TAU
		var magnitude = _spectrum_data[i] * _visualizer_settings.sensitivity
		var bar_length = magnitude * radius
		
		var start_pos = center + Vector2(cos(angle), sin(angle)) * radius
		var end_pos = center + Vector2(cos(angle), sin(angle)) * (radius + bar_length)
		
		var frequency_ratio = float(i) / float(bar_count - 1)
		var bar_color = _gradients[0].sample(frequency_ratio)
		
		draw_line(start_pos, end_pos, bar_color, 3.0)

## Draw bars visualization
func _draw_bars_visualization() -> void:
	# Similar to spectrum but with different styling
	_draw_spectrum_visualization()

## Draw particles visualization
func _draw_particles_visualization() -> void:
	# Simplified particle visualization
	var center = size / 2
	var particle_count = min(50, _spectrum_data.size())
	
	for i in range(particle_count):
		if i < _spectrum_data.size():
			var magnitude = _spectrum_data[i] * _visualizer_settings.sensitivity
			if magnitude > 0.1:
				var angle = randf() * TAU
				var distance = magnitude * 100
				var pos = center + Vector2(cos(angle), sin(angle)) * distance
				
				var frequency_ratio = float(i) / float(_spectrum_data.size() - 1)
				var particle_color = _gradients[0].sample(frequency_ratio)
				
				draw_circle(pos, magnitude * 5, particle_color)

## Draw minimal visualization
func _draw_minimal_visualization() -> void:
	# Simple level indicator
	var level_width = size.x * _audio_level
	var level_rect = Rect2(0, size.y - 10, level_width, 10)
	draw_rect(level_rect, _colors.spectrum_mid)

## Draw beat flash effect
func _draw_beat_flash() -> void:
	var flash_alpha = (_beat_flash_timer / _beat_settings.flash_duration) * _beat_settings.flash_intensity
	var flash_color = _colors.beat_flash
	flash_color.a = flash_alpha
	
	draw_rect(Rect2(Vector2.ZERO, size), flash_color)

## Draw border
func _draw_border() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _colors.border, false, 1.0)

#endregion

#region Data Processing

## Process frame updates
## @param delta: Frame delta time
func _process(delta: float) -> void:
	if not _is_initialized or not _is_active:
		return
	
	# Update beat flash timer
	if _beat_flash_timer > 0:
		_beat_flash_timer -= delta
		queue_redraw()
	
	# Performance throttling
	var current_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	if current_time - _last_update_time < (1.0 / _update_frequency):
		return
	
	_last_update_time = current_time
	_frame_count += 1
	
	# Update visualization data
	_update_visualization_data()
	
	# Redraw if data changed
	queue_redraw()

## Update visualization data from audio systems
func _update_visualization_data() -> void:
	# Get spectrum data from audio analyzer
	if _audio_analyzer:
		var spectrum = _audio_analyzer.get_spectrum_data()
		if spectrum.size() > 0:
			_update_spectrum_data(spectrum)
	
	# Get audio level from audio manager
	if _audio_manager:
		_audio_level = _audio_manager.get_audio_level()

## Update spectrum data with frequency band mapping
## @param spectrum: Raw spectrum data
func _update_spectrum_data(spectrum: PackedFloat32Array) -> void:
	var bar_count = _spectrum_settings.bar_count
	var frequency_range = _spectrum_settings.frequency_range
	var logarithmic = _spectrum_settings.logarithmic_scale
	
	# Resize spectrum data if needed
	if _spectrum_data.size() != bar_count:
		_spectrum_data.resize(bar_count)
		_frequency_bands.resize(bar_count)
	
	# Map spectrum data to frequency bands
	for i in range(bar_count):
		var frequency_ratio = float(i) / float(bar_count - 1)
		
		# Calculate frequency for this band
		var frequency: float
		if logarithmic:
			frequency = frequency_range[0] * pow(frequency_range[1] / frequency_range[0], frequency_ratio)
		else:
			frequency = lerp(frequency_range[0], frequency_range[1], frequency_ratio)
		
		_frequency_bands[i] = frequency
		
		# Map to spectrum index
		var spectrum_index = int((frequency / 22050.0) * spectrum.size())
		spectrum_index = clamp(spectrum_index, 0, spectrum.size() - 1)
		
		_spectrum_data[i] = spectrum[spectrum_index]

#endregion

#region Event Handlers

## Handle audio spectrum updates
## @param spectrum: Updated spectrum data
func _on_audio_spectrum_updated(spectrum: PackedFloat32Array) -> void:
	_update_spectrum_data(spectrum)

## Handle audio level changes
## @param level: New audio level
func _on_audio_level_changed(level: float) -> void:
	_audio_level = level

## Handle beat detection
## @param intensity: Beat intensity
func _on_beat_detected(intensity: float) -> void:
	_beat_intensity = intensity
	
	# Trigger beat flash
	if _visualizer_settings.show_beat_flash:
		_beat_flash_timer = _beat_settings.flash_duration
	
	# Emit beat detected signal
	beat_detected.emit(intensity)

## Handle visualizer mode changes
## @param mode: New visualization mode
func _on_visualizer_mode_changed(mode: String) -> void:
	set_visualization_mode_by_name(mode)

## Handle visualizer toggle requests
func _on_visualizer_toggle_requested() -> void:
	toggle_visualizer()

## Handle application shutdown
func _on_application_shutdown() -> void:
	cleanup()

#endregion

#region Public API

## Set visualization mode
## @param mode: New visualization mode
func set_visualization_mode(mode: VisualizationMode) -> void:
	if _current_mode != mode:
		_current_mode = mode
		queue_redraw()
		visualization_mode_changed.emit(mode)
		print("AudioVisualizerComponent: Visualization mode set to %d" % mode)

## Set visualization mode by name
## @param mode_name: Name of the visualization mode
func set_visualization_mode_by_name(mode_name: String) -> void:
	match mode_name.to_lower():
		"spectrum":
			set_visualization_mode(VisualizationMode.SPECTRUM)
		"waveform":
			set_visualization_mode(VisualizationMode.WAVEFORM)
		"circular":
			set_visualization_mode(VisualizationMode.CIRCULAR)
		"bars":
			set_visualization_mode(VisualizationMode.BARS)
		"particles":
			set_visualization_mode(VisualizationMode.PARTICLES)
		"minimal":
			set_visualization_mode(VisualizationMode.MINIMAL)

## Toggle visualizer active state
func toggle_visualizer() -> void:
	_is_active = !_is_active
	visible = _is_active
	print("AudioVisualizerComponent: Visualizer %s" % ("enabled" if _is_active else "disabled"))

## Set visualizer active state
## @param active: Whether visualizer should be active
func set_active(active: bool) -> void:
	_is_active = active
	visible = active

## Get current visualization mode
## @return: Current visualization mode
func get_visualization_mode() -> VisualizationMode:
	return _current_mode

## Get current beat intensity
## @return: Current beat intensity
func get_beat_intensity() -> float:
	return _beat_intensity

## Get current audio level
## @return: Current audio level
func get_audio_level() -> float:
	return _audio_level

## Get visualizer information for debugging
## @return: Dictionary with visualizer information
func get_visualizer_info() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"active": _is_active,
		"mode": _current_mode,
		"style": _current_style,
		"spectrum_data_size": _spectrum_data.size(),
		"audio_level": _audio_level,
		"beat_intensity": _beat_intensity,
		"frame_count": _frame_count,
		"update_frequency": _update_frequency,
		"visualizer_settings": _visualizer_settings.duplicate()
	}

## Check if the component is properly initialized
## @return: True if initialized and ready
func is_ready() -> bool:
	return _is_initialized

## Check if visualizer is currently active
## @return: True if active
func is_active() -> bool:
	return _is_active

#endregion

#region Cleanup

## Clean up resources and connections
func cleanup() -> void:
	print("AudioVisualizerComponent: Cleaning up resources...")
	
	# Clear references
	_audio_manager = null
	_audio_analyzer = null
	_beat_detector = null
	
	# Clear data
	_spectrum_data.clear()
	_waveform_data.clear()
	_frequency_bands.clear()
	_bar_positions.clear()
	_particle_systems.clear()
	_spectrum_smoothing.clear()
	_peak_hold_values.clear()
	_peak_hold_timers.clear()
	
	# Clear settings
	_visualizer_settings.clear()
	_spectrum_settings.clear()
	_beat_settings.clear()
	_performance_settings.clear()
	_colors.clear()
	_gradients.clear()
	
	# Reset state
	_current_mode = VisualizationMode.SPECTRUM
	_current_style = DisplayStyle.MODERN
	_is_active = true
	_beat_intensity = 0.0
	_audio_level = 0.0
	_beat_flash_timer = 0.0
	_frame_count = 0
	_last_update_time = 0.0
	_is_initialized = false
	
	print("AudioVisualizerComponent: Cleanup complete")

#endregion

class_name TimelineComponent
extends Control

## TimelineComponent - Refactored Audio Timeline Scrubber and Visualizer
##
## This refactored TimelineComponent uses the new architecture with ConfigManager for settings,
## EventBus for communication, and ServiceLocator for manager access. It maintains backward
## compatibility while providing a much cleaner and more extensible interface.
##
## Usage:
##   var timeline = TimelineComponent.new()
##   timeline.initialize()
##   # Component will automatically connect to audio and song managers

# Signals for timeline events
signal seek_requested(timestamp: float)
signal play_pause_requested()
signal checkpoint_selected(checkpoint: Dictionary)

# Timeline state and properties
var _song_duration: float = 0.0
var _current_time: float = 0.0
var _is_dragging: bool = false
var _is_hovering_checkpoint: bool = false
var _hovered_checkpoint: Dictionary = {}

# Visual layout properties
var _timeline_rect: Rect2
var _playhead_position: Vector2
var _checkpoint_markers: Array[Dictionary] = []

# Configuration settings (loaded from ConfigManager)
var _timeline_settings: Dictionary = {}
var _visual_settings: Dictionary = {}
var _interaction_settings: Dictionary = {}

# Manager references (accessed through ServiceLocator)
var _audio_manager: AudioManager
var _song_settings: SongSettings

# Visual styling
var _colors: Dictionary = {}
var _font: Font
var _font_size: int = 12

# Initialization state
var _is_initialized: bool = false

#region Initialization

## Initialize the timeline component
## @return: True if initialization was successful
func initialize() -> bool:
	if _is_initialized:
		print("TimelineComponent: Already initialized")
		return true
	
	print("TimelineComponent: Initializing...")
	
	# Load configuration
	_load_timeline_configuration()
	
	# Setup visual styling
	_setup_visual_styling()
	
	# Setup control properties
	_setup_control_properties()
	
	# Connect to managers
	_connect_to_managers()
	
	# Setup event connections
	_setup_event_connections()
	
	# Connect input events
	_setup_input_handling()
	
	_is_initialized = true
	print("TimelineComponent: Initialization complete")
	return true

## Load timeline configuration from ConfigManager
func _load_timeline_configuration() -> void:
	print("TimelineComponent: Loading configuration...")
	
	# Load timeline settings
	_timeline_settings = {
		"height": ConfigManager.get_config_value("ui.timeline.height", 60),
		"margin": ConfigManager.get_config_value("ui.timeline.margin", 20),
		"update_interval": ConfigManager.get_config_value("ui.timeline.update_interval", 0.1),
		"scrub_sensitivity": ConfigManager.get_config_value("ui.timeline.scrub_sensitivity", 1.0),
		"show_time_markers": ConfigManager.get_config_value("ui.timeline.show_time_markers", true),
		"time_marker_interval": ConfigManager.get_config_value("ui.timeline.time_marker_interval", 10.0)
	}
	
	# Load visual settings
	_visual_settings = {
		"show_progress_percentage": ConfigManager.get_config_value("ui.timeline.show_progress_percentage", true),
		"show_play_indicator": ConfigManager.get_config_value("ui.timeline.show_play_indicator", true),
		"checkpoint_hover_threshold": ConfigManager.get_config_value("ui.timeline.checkpoint_hover_threshold", 10),
		"playhead_size": ConfigManager.get_config_value("ui.timeline.playhead_size", 6),
		"marker_line_width": ConfigManager.get_config_value("ui.timeline.marker_line_width", 2.0)
	}
	
	# Load interaction settings
	_interaction_settings = {
		"enable_scrubbing": ConfigManager.get_config_value("ui.timeline.enable_scrubbing", true),
		"enable_click_to_play": ConfigManager.get_config_value("ui.timeline.enable_click_to_play", true),
		"enable_checkpoint_tooltips": ConfigManager.get_config_value("ui.timeline.enable_checkpoint_tooltips", true)
	}
	
	print("TimelineComponent: Configuration loaded")

## Setup visual styling from configuration
func _setup_visual_styling() -> void:
	print("TimelineComponent: Setting up visual styling...")
	
	# Load colors from configuration
	_colors = {
		"background": Color(
			ConfigManager.get_config_value("ui.timeline.colors.background", [0.1, 0.1, 0.1, 0.8])
		),
		"timeline": Color(
			ConfigManager.get_config_value("ui.timeline.colors.timeline", [0.3, 0.3, 0.3, 1.0])
		),
		"progress": Color(
			ConfigManager.get_config_value("ui.timeline.colors.progress", [0.502, 0.0, 0.502, 1.0])
		),
		"playhead": Color(
			ConfigManager.get_config_value("ui.timeline.colors.playhead", [1.0, 1.0, 1.0, 1.0])
		),
		"checkpoint": Color(
			ConfigManager.get_config_value("ui.timeline.colors.checkpoint", [1.0, 0.8, 0.2, 1.0])
		),
		"time_marker": Color(
			ConfigManager.get_config_value("ui.timeline.colors.time_marker", [1.0, 1.0, 1.0, 0.7])
		),
		"text": Color(
			ConfigManager.get_config_value("ui.timeline.colors.text", [0.9, 0.9, 0.9, 1.0])
		)
	}
	
	# Load font settings
	_font = ThemeDB.fallback_font
	_font_size = ConfigManager.get_config_value("ui.timeline.font_size", 12)
	
	print("TimelineComponent: Visual styling configured")

## Setup control properties and layout
func _setup_control_properties() -> void:
	# Set anchors and size
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	size.y = _timeline_settings.height + _timeline_settings.margin * 2
	
	# Set interaction properties
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Set visibility and layering
	visible = true
	modulate = Color.WHITE
	z_index = 100  # Ensure it's on top
	
	print("TimelineComponent: Control properties configured")

## Connect to managers through ServiceLocator
func _connect_to_managers() -> void:
	print("TimelineComponent: Connecting to managers...")
	
	# Get audio manager
	_audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
	if _audio_manager:
		_update_song_duration()
		print("TimelineComponent: Connected to AudioManager")
	else:
		push_warning("TimelineComponent: AudioManager not available")
	
	# Get song settings (if available)
	# Note: SongSettings might not be in ServiceLocator yet, so we'll handle this gracefully
	print("TimelineComponent: Manager connections established")

## Setup event connections with EventBus
func _setup_event_connections() -> void:
	print("TimelineComponent: Setting up event connections...")
	
	# Connect to audio events
	EventBus.connect_to_audio_position_changed(_on_audio_position_changed)
	EventBus.connect_to_audio_duration_changed(_on_audio_duration_changed)
	EventBus.connect_to_audio_playback_toggled(_on_audio_playback_toggled)
	
	# Connect to checkpoint events
	EventBus.connect_to_checkpoints_updated(_on_checkpoints_updated)
	
	# Connect to application lifecycle
	EventBus.connect_to_application_shutting_down(_on_application_shutdown)
	
	print("TimelineComponent: Event connections established")

## Setup input handling
func _setup_input_handling() -> void:
	# Connect GUI input signal
	gui_input.connect(_on_gui_input)
	
	print("TimelineComponent: Input handling configured")

## Update song duration from audio manager
func _update_song_duration() -> void:
	if _audio_manager and _audio_manager.stream:
		_song_duration = _audio_manager.stream.get_length()
		print("TimelineComponent: Song duration updated to %.1fs" % _song_duration)
		queue_redraw()

#endregion

#region Drawing and Rendering

## Custom drawing for the timeline
func _draw() -> void:
	if _song_duration <= 0:
		return
	
	var rect = get_rect()
	_timeline_rect = Rect2(
		_timeline_settings.margin,
		_timeline_settings.margin - 25,
		rect.size.x - _timeline_settings.margin * 2,
		_timeline_settings.height
	)
	
	# Draw all timeline elements
	_draw_background(rect)
	_draw_timeline_bar()
	_draw_progress_bar()
	
	if _timeline_settings.show_time_markers:
		_draw_time_markers()
	
	_draw_checkpoint_markers()
	_draw_playhead()
	_draw_time_text()
	_draw_status_indicators()

## Draw background
## @param rect: Component rectangle
func _draw_background(rect: Rect2) -> void:
	draw_rect(Rect2(0, 0, rect.size.x, rect.size.y), _colors.background)

## Draw main timeline bar
func _draw_timeline_bar() -> void:
	draw_rect(_timeline_rect, _colors.timeline)

## Draw progress bar
func _draw_progress_bar() -> void:
	var progress_width = (_current_time / _song_duration) * _timeline_rect.size.x
	var progress_rect = Rect2(
		_timeline_rect.position.x,
		_timeline_rect.position.y,
		progress_width,
		_timeline_rect.size.y
	)
	draw_rect(progress_rect, _colors.progress)

## Draw time markers at regular intervals
func _draw_time_markers() -> void:
	var marker_interval = _timeline_settings.time_marker_interval
	var timeline_width = _timeline_rect.size.x
	
	for i in range(int(_song_duration / marker_interval) + 1):
		var marker_time = i * marker_interval
		if marker_time > _song_duration:
			break
		
		var x_pos = _timeline_rect.position.x + (marker_time / _song_duration) * timeline_width
		
		# Draw marker line
		draw_line(
			Vector2(x_pos, _timeline_rect.position.y - 5),
			Vector2(x_pos, _timeline_rect.position.y + _timeline_rect.size.y),
			_colors.time_marker,
			_visual_settings.marker_line_width
		)
		
		# Draw time label for major markers
		if i % 6 == 0:  # Every minute (6 * 10 seconds)
			var time_text = _format_time(marker_time)
			var text_size = _font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size)
			draw_string(
				_font,
				Vector2(x_pos - text_size.x / 2, _timeline_rect.position.y - 8),
				time_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				_font_size,
				_colors.text
			)

## Draw checkpoint markers
func _draw_checkpoint_markers() -> void:
	if _checkpoint_markers.size() == 0:
		return
	
	var timeline_width = _timeline_rect.size.x
	
	for checkpoint in _checkpoint_markers:
		var timestamp = checkpoint.get("timestamp", 0.0)
		if timestamp > _song_duration:
			continue
		
		var x_pos = _timeline_rect.position.x + (timestamp / _song_duration) * timeline_width
		var marker_y = _timeline_rect.position.y - 15
		
		# Highlight if hovered
		var marker_color = _colors.checkpoint
		if _is_hovering_checkpoint and _hovered_checkpoint == checkpoint:
			marker_color = marker_color.lightened(0.3)
		
		# Draw checkpoint diamond
		var points = PackedVector2Array([
			Vector2(x_pos, marker_y),
			Vector2(x_pos - 5, marker_y - 8),
			Vector2(x_pos + 5, marker_y - 8)
		])
		draw_colored_polygon(points, marker_color)
		
		# Draw checkpoint indicator dot
		draw_circle(Vector2(x_pos, marker_y - 12), 2, marker_color)
		
		# Draw tooltip if hovered and enabled
		if _interaction_settings.enable_checkpoint_tooltips and _is_hovering_checkpoint and _hovered_checkpoint == checkpoint:
			_draw_checkpoint_tooltip(checkpoint, Vector2(x_pos, marker_y - 20))

## Draw checkpoint tooltip
## @param checkpoint: Checkpoint data
## @param position: Tooltip position
func _draw_checkpoint_tooltip(checkpoint: Dictionary, position: Vector2) -> void:
	var name = checkpoint.get("name", "Checkpoint")
	var time_text = _format_time(checkpoint.get("timestamp", 0.0))
	var tooltip_text = "%s (%s)" % [name, time_text]
	
	var text_size = _font.get_string_size(tooltip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size)
	var tooltip_rect = Rect2(
		position.x - text_size.x / 2 - 5,
		position.y - text_size.y - 5,
		text_size.x + 10,
		text_size.y + 10
	)
	
	# Draw tooltip background
	draw_rect(tooltip_rect, Color(0.0, 0.0, 0.0, 0.8))
	draw_rect(tooltip_rect, _colors.checkpoint, false, 1.0)
	
	# Draw tooltip text
	draw_string(
		_font,
		Vector2(tooltip_rect.position.x + 5, tooltip_rect.position.y + text_size.y + 2),
		tooltip_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		_font_size,
		_colors.text
	)

## Draw playhead indicator
func _draw_playhead() -> void:
	var timeline_width = _timeline_rect.size.x
	var x_pos = _timeline_rect.position.x + (_current_time / _song_duration) * timeline_width
	
	_playhead_position = Vector2(x_pos, _timeline_rect.position.y)
	
	# Draw playhead line
	draw_line(
		Vector2(x_pos, _timeline_rect.position.y - 10),
		Vector2(x_pos, _timeline_rect.position.y + _timeline_rect.size.y),
		_colors.playhead,
		3.0
	)
	
	# Draw playhead handle
	var playhead_size = _visual_settings.playhead_size
	draw_circle(Vector2(x_pos, _timeline_rect.position.y - 5), playhead_size, _colors.playhead)
	draw_circle(Vector2(x_pos, _timeline_rect.position.y - 5), playhead_size - 2, Color.BLACK)

## Draw time text and information
func _draw_time_text() -> void:
	var current_text = _format_time(_current_time)
	var duration_text = _format_time(_song_duration)
	var time_display = "%s / %s" % [current_text, duration_text]
	
	var text_size = _font.get_string_size(time_display, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size)
	var text_pos = Vector2(
		_timeline_rect.position.x + _timeline_rect.size.x - text_size.x - 5,
		_timeline_rect.position.y + _timeline_rect.size.y - 55
	)
	
	# Draw time display
	draw_string(
		_font,
		text_pos,
		time_display,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		_font_size,
		_colors.text
	)
	
	# Draw progress percentage if enabled
	if _visual_settings.show_progress_percentage:
		var progress_percent = (_current_time / _song_duration) * 100.0 if _song_duration > 0 else 0.0
		var progress_display = "%.1f%%" % progress_percent
		
		draw_string(
			_font,
			Vector2(text_pos.x, text_pos.y + 15),
			progress_display,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			_font_size,
			_colors.progress
		)

## Draw status indicators
func _draw_status_indicators() -> void:
	if not _visual_settings.show_play_indicator:
		return
	
	# Draw play/pause indicator
	var is_playing = _audio_manager and _audio_manager.is_playing()
	var play_status = "▶" if is_playing else "■"
	
	draw_string(
		_font,
		Vector2(_timeline_rect.position.x - 15, _timeline_rect.position.y + 4),
		play_status,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		_font_size,
		_colors.text
	)

#endregion

#region Input Handling

## Handle GUI input events
## @param event: Input event
func _on_gui_input(event: InputEvent) -> void:
	if not _interaction_settings.enable_scrubbing:
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

## Handle mouse button events
## @param event: Mouse button event
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Check if click is within timeline area
			if _timeline_rect.has_point(event.position):
				_is_dragging = true
				_seek_to_mouse_position(event.position)
			elif _interaction_settings.enable_click_to_play:
				# Click outside timeline - toggle play/pause
				play_pause_requested.emit()
				EventBus.emit_audio_playback_toggle_requested()
		else:
			_is_dragging = false

## Handle mouse motion events
## @param event: Mouse motion event
func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# Handle scrubbing
	if _is_dragging:
		_seek_to_mouse_position(event.position)
	
	# Handle checkpoint hovering
	if _interaction_settings.enable_checkpoint_tooltips:
		_update_checkpoint_hover(event.position)

## Seek to mouse position
## @param mouse_pos: Mouse position
func _seek_to_mouse_position(mouse_pos: Vector2) -> void:
	if _song_duration <= 0:
		return
	
	var relative_x = mouse_pos.x - _timeline_rect.position.x
	var timeline_width = _timeline_rect.size.x
	
	# Clamp to timeline bounds
	relative_x = clamp(relative_x, 0, timeline_width)
	
	# Calculate timestamp
	var target_time = (relative_x / timeline_width) * _song_duration
	target_time = clamp(target_time, 0, _song_duration) * _interaction_settings.scrub_sensitivity
	
	# Emit seek request
	seek_requested.emit(target_time)
	EventBus.emit_audio_seek_requested(target_time)

## Update checkpoint hover state
## @param mouse_pos: Mouse position
func _update_checkpoint_hover(mouse_pos: Vector2) -> void:
	var hover_threshold = _visual_settings.checkpoint_hover_threshold
	var timeline_width = _timeline_rect.size.x
	var was_hovering = _is_hovering_checkpoint
	
	_is_hovering_checkpoint = false
	_hovered_checkpoint = {}
	
	for checkpoint in _checkpoint_markers:
		var timestamp = checkpoint.get("timestamp", 0.0)
		if timestamp > _song_duration:
			continue
		
		var x_pos = _timeline_rect.position.x + (timestamp / _song_duration) * timeline_width
		
		if abs(mouse_pos.x - x_pos) < hover_threshold:
			_is_hovering_checkpoint = true
			_hovered_checkpoint = checkpoint
			break
	
	# Redraw if hover state changed
	if was_hovering != _is_hovering_checkpoint:
		queue_redraw()

#endregion

#region Event Handlers

## Handle audio position changes
## @param position: New audio position
func _on_audio_position_changed(position: float) -> void:
	_update_time(position)

## Handle audio duration changes
## @param duration: New audio duration
func _on_audio_duration_changed(duration: float) -> void:
	_song_duration = duration
	queue_redraw()

## Handle audio playback toggle
## @param is_playing: Whether audio is playing
func _on_audio_playback_toggled(is_playing: bool) -> void:
	queue_redraw()  # Update play indicator

## Handle checkpoint updates
## @param checkpoints: Updated checkpoint list
func _on_checkpoints_updated(checkpoints: Array) -> void:
	_checkpoint_markers = checkpoints.duplicate()
	queue_redraw()

## Handle application shutdown
func _on_application_shutdown() -> void:
	cleanup()

#endregion

#region Public API

## Update current time and redraw
## @param new_time: New current time
func _update_time(new_time: float) -> void:
	var old_time = _current_time
	_current_time = clamp(new_time, 0, _song_duration)
	
	# Only redraw if significant change
	if abs(_current_time - old_time) > _timeline_settings.update_interval:
		queue_redraw()

## Set song duration
## @param duration: Song duration in seconds
func set_song_duration(duration: float) -> void:
	_song_duration = duration
	queue_redraw()

## Update checkpoint markers
## @param checkpoints: Array of checkpoint dictionaries
func update_checkpoint_markers(checkpoints: Array = []) -> void:
	_checkpoint_markers = checkpoints.duplicate()
	queue_redraw()

## Get checkpoint at position (for external tooltip handling)
## @param mouse_pos: Mouse position
## @return: Checkpoint dictionary or empty if none found
func get_checkpoint_at_position(mouse_pos: Vector2) -> Dictionary:
	var hover_threshold = _visual_settings.checkpoint_hover_threshold
	var timeline_width = _timeline_rect.size.x
	
	for checkpoint in _checkpoint_markers:
		var timestamp = checkpoint.get("timestamp", 0.0)
		if timestamp > _song_duration:
			continue
		
		var x_pos = _timeline_rect.position.x + (timestamp / _song_duration) * timeline_width
		
		if abs(mouse_pos.x - x_pos) < hover_threshold:
			return checkpoint
	
	return {}

## Get timeline information for debugging
## @return: Dictionary with timeline information
func get_timeline_info() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"song_duration": _song_duration,
		"current_time": _current_time,
		"is_dragging": _is_dragging,
		"checkpoint_count": _checkpoint_markers.size(),
		"timeline_settings": _timeline_settings.duplicate(),
		"visual_settings": _visual_settings.duplicate()
	}

## Check if the component is properly initialized
## @return: True if initialized and ready
func is_ready() -> bool:
	return _is_initialized

#endregion

#region Utility Methods

## Format time as MM:SS
## @param seconds: Time in seconds
## @return: Formatted time string
func _format_time(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

## Process timeline updates
## @param delta: Frame delta time
func _process(delta: float) -> void:
	if not _is_initialized:
		return
	
	# Update time from audio manager
	if _audio_manager:
		var new_time = _audio_manager.get_playback_position()
		_update_time(new_time)

#endregion

#region Cleanup

## Clean up resources and connections
func cleanup() -> void:
	print("TimelineComponent: Cleaning up resources...")
	
	# Clear references
	_audio_manager = null
	_song_settings = null
	
	# Clear data
	_checkpoint_markers.clear()
	_timeline_settings.clear()
	_visual_settings.clear()
	_interaction_settings.clear()
	_colors.clear()
	
	# Reset state
	_song_duration = 0.0
	_current_time = 0.0
	_is_dragging = false
	_is_hovering_checkpoint = false
	_hovered_checkpoint = {}
	_is_initialized = false
	
	print("TimelineComponent: Cleanup complete")

#endregion
